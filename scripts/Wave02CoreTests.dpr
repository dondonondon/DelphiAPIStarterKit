program Wave02CoreTests;
{$APPTYPE CONSOLE}

uses System.SysUtils, System.Classes, System.IOUtils, System.JSON, System.Generics.Collections, System.DateUtils,
  Data.DB, Data.FmtBcd, FireDAC.Stan.Option,
  Winapi.Windows, FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.ConsoleUI.Wait,
  BFA.Core.Config in '..\sources\core\BFA.Core.Config.pas',
  BFA.Helper.Clock in '..\sources\shared\helpers\BFA.Helper.Clock.pas',
  BFA.Logger in '..\sources\infrastructure\logging\BFA.Logger.pas',
  BFA.Helper.Transaction in '..\sources\shared\helpers\BFA.Helper.Transaction.pas',
  BFA.Core.Request in '..\sources\core\BFA.Core.Request.pas',
  BFA.Core.Response in '..\sources\core\BFA.Core.Response.pas',
  BFA.Core.Messages in '..\sources\core\BFA.Core.Messages.pas',
  BFA.Helper.Strings in '..\sources\shared\helpers\BFA.Helper.Strings.pas',
  BFA.Helper.Dataset in '..\sources\shared\helpers\BFA.Helper.Dataset.pas',
  BFA.Helper.Validator in '..\sources\shared\helpers\BFA.Helper.Validator.pas',
  Product.DTO in '..\sources\modules\products\Product.DTO.pas',
  Product.Validator in '..\sources\modules\products\Product.Validator.pas';

type
  TFailure = class
    procedure FailRollback(Sender: TObject);
  end;

procedure TFailure.FailRollback(Sender: TObject);
begin
  raise EInvalidOpException.Create('rollback payload must never be logged');
end;

procedure Check(AValue: Boolean; const ACase: string);
begin
  if not AValue then raise Exception.Create(ACase);
  Writeln('PASS ', ACase);
end;

procedure Emit;
begin
  THelperLogger.BeginRequest;
  try
    try
      raise EInvalidOpException.Create('password=secret-probe token=secret-probe raw SQL payload');
    except
      on E: Exception do THelperLogger.Error('core-test', E);
    end;
  finally
    THelperLogger.EndRequest;
  end;
end;

procedure LoggerTest(const ARoot: string);
var LThreads: TObjectList<TThread>; LThread: TThread; I, J, LCount: Integer; LLine, LFile, LPath: string;
  LJSON: TJSONValue; LIDs: TDictionary<string, Boolean>; LStream: TFileStream;
begin
  LPath := TPath.Combine(ARoot, 'concurrent.log');
  SetEnvironmentVariable('DELPHI_API_ERROR_FILE', PChar(LPath));
  SetEnvironmentVariable('DELPHI_API_LOG_MAX_BYTES', '65536');
  SetEnvironmentVariable('DELPHI_API_LOG_RETAINED_FILES', '20');
  LThreads := TObjectList<TThread>.Create;
  try
    for I := 1 to 20 do begin
      LThread := TThread.CreateAnonymousThread(procedure
      var K: Integer;
      begin
        try
          for K := 1 to 30 do Emit;
        except
          on E: Exception do THelperLogger.Error('core-test-thread', E);
        end;
      end);
      LThread.FreeOnTerminate := False;
      LThreads.Add(LThread);
      LThread.Start;
    end;
    for LThread in LThreads do LThread.WaitFor;
  finally
    FreeAndNil(LThreads);
  end;
  LCount := 0;
  LIDs := TDictionary<string, Boolean>.Create;
  try
    for LFile in TDirectory.GetFiles(ARoot, 'concurrent.log*') do begin
      for LLine in TFile.ReadAllLines(LFile, TEncoding.UTF8) do begin
        if LLine.Trim = '' then Continue;
        LJSON := TJSONObject.ParseJSONValue(LLine);
        try
          if not (LJSON is TJSONObject) then raise Exception.Create('Corrupt log line.');
          if LLine.Contains('secret-probe') or LLine.Contains('raw SQL') then raise Exception.Create('Secret log echo.');
          LIDs.Add(TJSONObject(LJSON).GetValue<string>('correlation_id'), True);
          Inc(LCount);
        finally
          FreeAndNil(LJSON);
        end;
      end;
    end;
    Check((LCount = 600) and (LIDs.Count = 600) and FileExists(LPath + '.1'), '600 concurrent errors / rotation / unique correlation / secret exclusion');
  finally
    FreeAndNil(LIDs);
  end;
  SetEnvironmentVariable('DELPHI_API_LOG_MAX_BYTES', '1024');
  SetEnvironmentVariable('DELPHI_API_LOG_RETAINED_FILES', '2');
  LPath := TPath.Combine(ARoot, 'retention.log');
  SetEnvironmentVariable('DELPHI_API_ERROR_FILE', PChar(LPath));
  for J := 1 to 30 do Emit;
  Check(FileExists(LPath + '.2') and not FileExists(LPath + '.3'), 'rotation bounded by configured retention');
  LStream := TFileStream.Create(LPath, fmOpenReadWrite or fmShareExclusive);
  try
    Emit;
    Check(True, 'locked sink falls back without throwing');
  finally
    FreeAndNil(LStream);
  end;
  SetFileAttributes(PChar(LPath), FILE_ATTRIBUTE_READONLY);
  try
    Emit;
    Check(True, 'read-only sink falls back without throwing');
  finally
    SetFileAttributes(PChar(LPath), FILE_ATTRIBUTE_NORMAL);
  end;
  SetEnvironmentVariable('DELPHI_API_ERROR_FILE', PChar(TPath.Combine(LPath, 'unavailable.log')));
  Emit;
  Check(True, 'unavailable parent falls back without throwing');
  SetEnvironmentVariable('DELPHI_API_ERROR_FILE', PChar(TPath.Combine(ARoot, 'rollback.log')));
end;

procedure RollbackTest;
var LConnection: TFDConnection; LFailure: TFailure;
begin
  LConnection := TFDConnection.Create(nil);
  LFailure := TFailure.Create;
  try
    LConnection.Params.Values['DriverID'] := 'SQLite';
    LConnection.Params.Values['Database'] := ':memory:';
    LConnection.LoginPrompt := False;
    LConnection.Connected := True;
    LConnection.StartTransaction;
    LConnection.BeforeRollback := LFailure.FailRollback;
    try
      try
        raise EArgumentException.Create('initial payload must never be logged');
      except
        THelperTransaction.Rollback(LConnection);
        raise;
      end;
    except
      on E: Exception do begin
        Check(E is EArgumentException, 'rollback fault preserves original exception');
        THelperLogger.Error('rollback-test', E);
      end;
    end;
    LConnection.BeforeRollback := nil;
    LConnection.Rollback;
  finally
    FreeAndNil(LFailure);
    FreeAndNil(LConnection);
  end;
end;

procedure JSONTest;
var LTable: TFDMemTable; LJSON: TJSONValue; LText, LLocale, LBad: string; LSaved: TFormatSettings;
  LUTC, LJakarta: TDateTime;
begin
  LTable := TFDMemTable.Create(nil);
  LSaved := FormatSettings;
  try
    for LLocale in ['en-US','id-ID'] do begin
      FormatSettings := TFormatSettings.Create(LLocale);
      Check(LTable.LoadFromJSON('{"phone":"+628123","numeric":"123","leading":"00123","exponent":"1e2",'
        + '"object":"{}","array":"[]","unicode":"Unicode \uD83D\uDE00","int":9007199254740993,'
        + '"max":9223372036854775807,"min":-9223372036854775808,"decimal":1234567890123.45,"nil":null,"flag":true}', False),
        'typed JSON parse ' + LLocale);
      Check((LTable.FieldByName('int').AsLargeInt = 9007199254740993) and
        (LTable.FieldByName('max').AsLargeInt = High(Int64)) and (LTable.FieldByName('min').AsLargeInt = Low(Int64)) and
        (LTable.FieldByName('nil').IsNull) and (LTable.FieldByName('decimal').DataType = ftFMTBcd), 'Int64 decimal null ownership ' + LLocale);
      LText := THelperResponse.CreateResponse(200, 'OK', LTable);
      LJSON := THelperRequest.ParseJSON(LText);
      try
        Check(LText.Contains('"phone":"+628123"') and LText.Contains('"object":"{}"') and
          LText.Contains('9007199254740993') and LText.Contains('1234567890123.45') and LText.Contains('"flag":true'),
          'typed JSON serialization invariant ' + LLocale);
      finally
        FreeAndNil(LJSON);
      end;
    end;
    for LBad in ['{"n":9223372036854775808}','{"n":-9223372036854775809}','{"n":1e2}',
      '{"n":1.123456789012345}','{"n":+1}','{"n":01}','{"a":1,"a":2}','{"a":1,"A":2}',
      '[1]','[{"a":1},{"a":"x"}]','[{"a":1},{"A":2}]','[{}]','[{},{}]',
      '[{"a":1,"a":2}]','{"a":"\uD800"}','{"a":"\u0000"}','{} {}','{"a":true,}'] do
      Check(not LTable.LoadFromJSON(LBad, False), 'invalid/unsupported JSON rejected without echo');
    Check(LTable.LoadFromJSON('[{"a":null,"b":"y"},{"b":"z","a":"x","additional":1}]', False), 'array union by field name / null-first');
    LTable.First;
    Check(LTable.FieldByName('a').IsNull and LTable.FieldByName('additional').IsNull, 'array missing remains null');
    LTable.Next;
    Check((LTable.FieldByName('a').AsString='x') and (LTable.FieldByName('b').AsString='z') and
      (LTable.FieldByName('additional').AsLargeInt=1), 'array reordering preserves values');
    Check(LTable.LoadFromJSON('[]', False) and not LTable.Active, 'empty helper array has zero rows / no fabricated schema');
    LTable.FieldDefs.Add('instant', ftDateTime);
    LTable.FieldDefs.Add('date_only', ftDate);
    LTable.CreateDataSet;
    LUTC := ISO8601ToDate('2026-10-02T00:00:00Z', True);
    LJakarta := ISO8601ToDate('2026-10-02T07:00:00+07:00', True);
    LTable.Append;
    LTable.FieldByName('instant').AsDateTime := LUTC;
    LTable.FieldByName('date_only').AsDateTime := EncodeDate(2026,10,2);
    LTable.Post;
    LText := THelperResponse.CreateResponse(200,'OK',LTable);
    Check((THelperClock.UnixUTC(LUTC)=THelperClock.UnixUTC(LJakarta)) and
      not LText.Contains('date_only_unix') and LText.Contains('2026-10-02T00:00:00.000Z'), 'UTC/Jakarta same instant / date-only no implicit epoch');
    Check(THelperClock.UnixUTC(ISO8601ToDate('2026-03-08T01:59:59-05:00', True))+1 =
      THelperClock.UnixUTC(ISO8601ToDate('2026-03-08T03:00:00-04:00', True)), 'explicit DST offsets avoid double timezone conversion');
  finally
    FormatSettings := LSaved;
    FreeAndNil(LTable);
  end;
end;

procedure MoneyTest;
var LTable: TFDMemTable; LRequest: TProductCreateRequest; LSaved: TFormatSettings;
  LLocale, LPrice, LMessage: string; LExpected: Boolean;
begin
  LTable := TFDMemTable.Create(nil);
  LSaved := FormatSettings;
  try
    for LLocale in ['en-US','id-ID'] do begin
      FormatSettings := TFormatSettings.Create(LLocale);
      for LPrice in ['0','9999999999999.99','10000000000000','-0.01','1.234','1.235','1.2300'] do begin
        Check(LTable.LoadFromJSON('{"product_name":"money","price":' + LPrice + '}', False), 'money token kept exact');
        LExpected := (LPrice = '0') or (LPrice = '9999999999999.99') or (LPrice = '1.2300');
        Check(TProductValidator.ValidateCreate(LTable, LRequest, LMessage) = LExpected,
          'DECIMAL15,2 domain boundary ' + LLocale + ' ' + LPrice);
        if LExpected then Check(LRequest.Price = StrToCurr(LPrice, TFormatSettings.Invariant), 'money no implicit rounding');
      end;
    end;
  finally
    FormatSettings := LSaved;
    FreeAndNil(LTable);
  end;
end;

procedure LimitTest;
var LTable: TFDMemTable; LText: string; I: Integer;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LText := '[';
    for I := 1 to 1001 do begin
      if I > 1 then LText := LText + ',';
      LText := LText + '{"a":1}';
    end;
    Check(not LTable.LoadFromJSON(LText + ']', False), 'helper row limit1000 before dataset allocation');
    LText := '{';
    for I := 1 to 33 do begin
      if I > 1 then LText := LText + ',';
      LText := LText + '"f' + IntToStr(I) + '":1';
    end;
    Check(not LTable.LoadFromJSON(LText + '}', False), 'field limit32');
    Check(not LTable.LoadFromJSON('{"' + StringOfChar('f',65) + '":1}', False), 'field name limit64');
    Check(not LTable.LoadFromJSON('{"a":"' + StringOfChar('x',16384) + '"}', False), 'UTF8 byte limit16384');
    Check(not LTable.LoadFromJSON('{"a":[[[[1]]]]}', False), 'preflight depth limit4');
  finally
    FreeAndNil(LTable);
  end;
end;

procedure FetchTest;
var LConnection: TFDConnection; LQuery: TFDQuery; LJSON: TJSONValue;
begin
  LConnection := TFDConnection.Create(nil);
  LQuery := TFDQuery.Create(nil);
  try
    LConnection.Params.Values['DriverID'] := 'SQLite';
    LConnection.Params.Values['Database'] := ':memory:';
    LConnection.LoginPrompt := False;
    LQuery.Connection := LConnection;
    LQuery.FetchOptions.RowsetSize := 7;
    LQuery.SQL.Text := 'WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<2500) SELECT x FROM n';
    LQuery.Open;
    LJSON := TJSONObject.ParseJSONValue(LQuery.ToJSON);
    try
      Check((LJSON is TJSONArray) and (TJSONArray(LJSON).Count=2500), 'typed serializer completes actual FireDAC rowset7 / 2500 rows without RecordCount');
    finally
      FreeAndNil(LJSON);
    end;
  finally
    FreeAndNil(LQuery);
    FreeAndNil(LConnection);
  end;
end;

begin
  try
    ForceDirectories(ParamStr(1));
    LoggerTest(ParamStr(1));
    RollbackTest;
    JSONTest;
    MoneyTest;
    LimitTest;
    FetchTest;
  except
    on E: Exception do begin
      Writeln('FAIL ', E.ClassName, ' ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
