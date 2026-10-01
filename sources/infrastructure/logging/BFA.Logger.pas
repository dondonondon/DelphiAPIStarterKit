unit BFA.Logger;

interface

uses System.SysUtils;

type
  THelperLogger = class
  public
    class procedure BeginRequest; static;
    class procedure EndRequest; static;
    class function CorrelationID: string; static;
    class procedure RollbackFailed(AException: Exception); static;
    class procedure Error(const ASource: string; AException: Exception); static;
  end;

implementation

uses System.Classes, System.IOUtils, System.JSON, System.SyncObjs, FireDAC.Stan.Error,
  BFA.Core.Config, BFA.Helper.Clock;

var LogLock: TCriticalSection;

threadvar
  RequestID: TGUID;
  HasRequestID: Boolean;
  RollbackClass: ShortString;

function SafeLabel(const AText: string): string;
var LChar: Char;
begin
  Result := '';
  for LChar in AText do begin
    if CharInSet(LChar, ['a'..'z','A'..'Z','0'..'9',' ','.','_','-']) then Result := Result + LChar;
    if Length(Result) >= 80 then Exit;
  end;
end;

function LogSetting(const AName, AEnv: string; ADefault, AMinimum, AMaximum: Integer): Integer;
begin
  if not TryStrToInt(TServerConfig.ReadValue('Logging', AName, AEnv, IntToStr(ADefault)), Result) or
    (Result < AMinimum) or (Result > AMaximum) then raise Exception.Create('Invalid logging setting.');
end;

procedure Rotate(const APath: string; AMaximum, ARetained: Integer; AIncoming: Integer);
var I: Integer; LName: string; LStream: TFileStream;
begin
  if not FileExists(APath) then Exit;
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    if LStream.Size + AIncoming <= AMaximum then Exit;
  finally
    FreeAndNil(LStream);
  end;
  LName := APath + '.' + IntToStr(ARetained);
  if FileExists(LName) then TFile.Delete(LName);
  for I := ARetained - 1 downto 1 do begin
    LName := APath + '.' + IntToStr(I);
    if FileExists(LName) then TFile.Move(LName, APath + '.' + IntToStr(I + 1));
  end;
  TFile.Move(APath, APath + '.1');
end;

class procedure THelperLogger.BeginRequest;
begin
  EndRequest;
  try
    HasRequestID := CreateGUID(RequestID) = 0;
  except
    HasRequestID := False;
  end;
end;

class procedure THelperLogger.EndRequest;
begin
  HasRequestID := False;
  RollbackClass := '';
end;

class function THelperLogger.CorrelationID: string;
begin
  if not HasRequestID then HasRequestID := CreateGUID(RequestID) = 0;
  Result := LowerCase(Copy(GUIDToString(RequestID), 2, 36));
end;

class procedure THelperLogger.RollbackFailed(AException: Exception);
begin
  if Assigned(AException) then RollbackClass := ShortString(SafeLabel(AException.ClassName));
end;

class procedure THelperLogger.Error(const ASource: string; AException: Exception);
var LPath, LLine: string; LEvent: TJSONObject; LMaximum, LRetained, I: Integer; LDB: EFDDBEngineException;
begin
  if not Assigned(AException) then Exit;
  LLine := 'Server error; diagnostic sink unavailable.';
  try
    LEvent := TJSONObject.Create;
    try
      LEvent.AddPair('utc', THelperClock.ISO8601UTC(THelperClock.UTCNow));
      LEvent.AddPair('correlation_id', CorrelationID);
      LEvent.AddPair('source', SafeLabel(ASource));
      LEvent.AddPair('exception_class', SafeLabel(AException.ClassName));
      LEvent.AddPair('exception_address', IntToHex(NativeUInt(ExceptAddr), SizeOf(Pointer) * 2));
      if RollbackClass <> '' then LEvent.AddPair('rollback_exception_class', string(RollbackClass));
      if AException is EFDDBEngineException then begin
        LDB := EFDDBEngineException(AException);
        LEvent.AddPair('db_kind', TJSONNumber.Create(Ord(LDB.Kind)));
        for I := 0 to LDB.ErrorCount - 1 do begin
          if I >= 4 then Break;
          LEvent.AddPair('db_code_' + IntToStr(I), TJSONNumber.Create(LDB.Errors[I].ErrorCode));
        end;
      end;
      LLine := LEvent.ToJSON;
    finally
      FreeAndNil(LEvent);
      RollbackClass := '';
    end;
    LogLock.Acquire;
    try
      LPath := TServerConfig.LogFile;
      LMaximum := LogSetting('MaxBytes', 'DELPHI_API_LOG_MAX_BYTES', 10485760, 1024, 1073741824);
      LRetained := LogSetting('RetainedFiles', 'DELPHI_API_LOG_RETAINED_FILES', 5, 1, 100);
      ForceDirectories(ExtractFilePath(LPath));
      Rotate(LPath, LMaximum, LRetained, TEncoding.UTF8.GetByteCount(LLine + sLineBreak));
      TFile.AppendAllText(LPath, LLine + sLineBreak, TEncoding.UTF8);
    finally
      LogLock.Release;
    end;
  except
    on E: Exception do begin
      try
        LogLock.Acquire;
        try
          Writeln(ErrOutput, LLine);
        finally
          LogLock.Release;
        end;
      except
        Exit;
      end;
    end;
  end;
end;

initialization
  LogLock := TCriticalSection.Create;
finalization
  FreeAndNil(LogLock);
end.
