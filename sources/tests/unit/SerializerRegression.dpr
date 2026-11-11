program SerializerRegression;

{$APPTYPE CONSOLE}
{$ASSERTIONS ON}

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.DateUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Option,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.Intf,
  BFA.Core.Response,
  BFA.Helper.Strings,
  Product.DTO,
  Product.Validator;

const
  TEST_ROWS = 2305;

var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
  Inc(GChecks);
end;

procedure CheckRows(const AJSON: string; AEnvelope: Boolean;
  AEncoded: Boolean = False);
var
  LRoot: TJSONValue;
  LRows: TJSONArray;
  LRow: TJSONObject;
  I: Integer;
  LExpectedLabel: string;
begin
  LRoot := TJSONObject.ParseJSONValue(AJSON);
  try
    Check(Assigned(LRoot), 'JSON parses');
    if AEnvelope then
      LRows := TJSONObject(LRoot).GetValue<TJSONArray>('data')
    else
      LRows := LRoot as TJSONArray;
    Check(LRows.Count = TEST_ROWS, 'All on-demand rows are returned');
    for I := 0 to LRows.Count - 1 do begin
      LRow := LRows.Items[I] as TJSONObject;
      Check(LRow.Pairs[0].JsonString.Value = 'id', 'FieldDefs order: id');
      Check(LRow.Pairs[1].JsonString.Value = 'label', 'FieldDefs order: label');
      Check(LRow.Pairs[2].JsonString.Value = 'code', 'FieldDefs order: code');
      Check(LRow.Pairs[3].JsonString.Value = 'nullable', 'FieldDefs order: nullable');
      Check(LRow.Pairs[4].JsonString.Value = 'nested', 'FieldDefs order: nested');
      Check(LRow.GetValue<TJSONNumber>('id').AsInt = I + 1, 'Row order/id');
      LExpectedLabel := 'Unicode-' + Char($03A9) + '-' + IntToStr(I + 1);
      if AEncoded then
        LExpectedLabel := TGlobalFunction.EncodeBase64(LExpectedLabel);
      Check(LRow.GetValue<string>('label') = LExpectedLabel, 'Unicode value');
      Check(LRow.GetValue('nullable') is TJSONNull, 'Null remains JSON null');
      if not AEncoded then begin
        Check(LRow.GetValue('code') is TJSONString, 'Leading zero is string');
        Check(LRow.GetValue<string>('code') = '001', 'Leading zero preserved');
        Check(LRow.GetValue<TJSONObject>('nested').GetValue('a') is TJSONArray,
          'Nested JSON string normalized');
      end;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TestOnDemandRows;
var
  LConnection: TFDConnection;
  LQuery: TFDQuery;
begin
  LConnection := TFDConnection.Create(nil);
  try
    LConnection.DriverName := 'SQLite';
    LConnection.Params.Values['Database'] := ':memory:';
    LConnection.LoginPrompt := False;
    LConnection.Connected := True;
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := LConnection;
      LQuery.FetchOptions.Mode := fmOnDemand;
      LQuery.FetchOptions.RowsetSize := 1000;
      LQuery.SQL.Text :=
        'WITH RECURSIVE n(id) AS (SELECT 1 UNION ALL SELECT id+1 FROM n WHERE id<2305) ' +
        'SELECT id, ''Unicode-' + Char($03A9) + '-'' || id AS label, ''001'' AS code, ' +
        'CAST(NULL AS TEXT) AS nullable, ''{"a":"[1,2]"}'' AS nested FROM n';

      LQuery.Open;
      Check(LQuery.RecordCount < TEST_ROWS, 'Fixture must start partially fetched');
      CheckRows(LQuery.ToJSON, False);
      Check(LQuery.Eof, 'ToJSON ends at EOF');
      LQuery.Close;

      LQuery.Open;
      Check(LQuery.RecordCount < TEST_ROWS, 'ToJSONArray starts partially fetched');
      CheckRows(LQuery.ToJSONArray, False);
      LQuery.Close;

      LQuery.Open;
      CheckRows(LQuery.ToJSONArray(True), False, True);
      LQuery.Close;

      LQuery.Open;
      CheckRows(THelperResponse.CreateResponse(200, 'OK', LQuery), True);
      LQuery.Close;

      LQuery.Open;
      CheckRows(TJSONPayloadBuilder.FromDataset(LQuery), True);
    finally
      LQuery.Free;
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TestTypedContract;
var
  LData: TFDMemTable;
  LRequest: TFDMemTable;
  LRoot: TJSONObject;
  LRow: TJSONObject;
  LStamp: TDateTime;
  LDay: TDateTime;
begin
  LData := TFDMemTable.Create(nil);
  LRequest := TFDMemTable.Create(nil);
  try
    LData.FieldDefs.Add('text', ftWideString, 100);
    LData.FieldDefs.Add('amount', ftCurrency);
    LData.FieldDefs.Add('flag', ftBoolean);
    LData.FieldDefs.Add('code', ftString, 20);
    LData.FieldDefs.Add('nested', ftString, 100);
    LData.FieldDefs.Add('stamp', ftDateTime);
    LData.FieldDefs.Add('day', ftDate);
    LData.FieldDefs.Add('nothing', ftString, 10);
    LData.CreateDataSet;
    LStamp := EncodeDateTime(2026, 10, 26, 12, 34, 56, 0);
    LDay := EncodeDate(2026, 10, 26);
    LData.Append;
    LData.FieldByName('text').AsString := 'Unicode ' + Char($03A9) + Char($4E2D) +
      ' "quoted" \slash' + #13#10#9 + Char(1);
    LData.FieldByName('amount').AsCurrency := 12.5;
    LData.FieldByName('flag').AsBoolean := True;
    LData.FieldByName('code').AsString := '001';
    LData.FieldByName('nested').AsString := '{"a":"[1,2]"}';
    LData.FieldByName('stamp').AsDateTime := LStamp;
    LData.FieldByName('day').AsDateTime := LDay;
    LData.Post;
    LRequest.FieldDefs.Add('request_code', ftString, 20);
    LRequest.CreateDataSet;
    LRequest.AppendRecord(['0007']);
    LRoot := TJSONObject.ParseJSONValue(
      THelperResponse.CreateResponse(200, 'OK', LData, LRequest)) as TJSONObject;
    try
      LRow := LRoot.GetValue<TJSONArray>('data').Items[0] as TJSONObject;
      Check(LRow.Pairs[0].JsonString.Value = 'text', 'Typed field ordering');
      Check(LRow.GetValue<string>('text') = 'Unicode ' + Char($03A9) + Char($4E2D) +
        ' "quoted" \slash' + #13#10#9 + Char(1),
        'Typed Unicode preserved');
      Check(LRow.GetValue('amount') is TJSONNumber, 'Currency stays numeric');
      Check(LRow.GetValue<TJSONNumber>('amount').AsDouble = 12.5, 'Currency value');
      Check(LRow.GetValue('flag') is TJSONTrue, 'Boolean stays boolean');
      Check(LRow.GetValue('code') is TJSONString, 'Typed leading zero stays string');
      Check(LRow.GetValue<TJSONObject>('nested').GetValue('a') is TJSONArray,
        'Typed nested JSON normalized');
      Check(LRow.GetValue<string>('stamp') = '2026-10-26 12:34:56', 'DateTime format');
      Check(LRow.GetValue<string>('stamp_unix') = DateTimeToUnix(LStamp).ToString,
        'Existing DateTime Unix contract');
      Check(LRow.GetValue<string>('day') = '2026-10-26', 'Date format');
      Check(LRow.GetValue<string>('day_unix') = DateTimeToUnix(LDay).ToString,
        'Existing Date Unix contract');
      Check(LRow.GetValue('nothing') is TJSONNull, 'Typed null preserved');
      Check(LRoot.GetValue<TJSONObject>('request_detail').GetValue<string>('request_code') =
        '0007', 'Request detail contract');
    finally
      LRoot.Free;
    end;
    LRoot := TJSONObject.ParseJSONValue(
      THelperResponse.CreateResponse(400, 'Invalid request', LData, LRequest)) as TJSONObject;
    try
      Check(LRoot.GetValue<TJSONArray>('data').Count = 1, 'Error has one empty object');
      Check((LRoot.GetValue<TJSONArray>('data').Items[0] as TJSONObject).Count = 0,
        'Error never leaks populated response dataset');
      Check(LRoot.GetValue<TJSONObject>('request_detail').GetValue<string>('request_code') =
        '0007', 'Error retains request detail contract');
    finally
      LRoot.Free;
    end;
    LData.EmptyDataSet;
    LRoot := TJSONObject.ParseJSONValue(
      THelperResponse.CreateResponse(200, 'OK', LData)) as TJSONObject;
    try
      Check(LRoot.GetValue<TJSONArray>('data').Count = 0, 'Empty dataset returns empty array');
    finally
      LRoot.Free;
    end;
  finally
    LRequest.Free;
    LData.Free;
  end;
end;

procedure TestProductFormats;
var
  LData: TFDMemTable;
  LResponse: TStringList;
  LRequest: TProductCreateRequest;
  LMessage: string;
  LOriginalFormat: TFormatSettings;
begin
  LOriginalFormat := FormatSettings;
  LData := TFDMemTable.Create(nil);
  try
    FormatSettings.DecimalSeparator := ',';
    FormatSettings.ThousandSeparator := '.';
    LData.FieldDefs.Add('product_name', ftString, 100);
    LData.FieldDefs.Add('price', ftString, 30);
    LData.CreateDataSet;
    LData.AppendRecord(['Product', '12.50']);
    Check(TProductValidator.ValidateCreate(LData, LRequest, LMessage),
      'Product validator accepts invariant decimal under comma locale');
    Check(LRequest.Price = 12.5, 'Product validator currency value');
    LResponse := TProductDTO.CreateProductResponse('id', 'Product', '', 12.5,
      1, '', '', 1);
    try
      Check(LResponse.Values['price'] = '12.50', 'Product DTO uses invariant decimal');
    finally
      LResponse.Free;
    end;
  finally
    LData.Free;
    FormatSettings := LOriginalFormat;
  end;
end;

begin
  try
    FormatSettings.DecimalSeparator := '.';
    FormatSettings.ThousandSeparator := ',';
    TestOnDemandRows;
    TestTypedContract;
    TestProductFormats;
    Writeln('PASS: ', GChecks, ' serializer/product checks; ', TEST_ROWS,
      ' rows per on-demand serialization path.');
  except
    on E: Exception do begin
      Writeln('FAIL: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
