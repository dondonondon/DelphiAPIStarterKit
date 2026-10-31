unit BFA.Core.Config;

interface

uses
  System.SysUtils;

type
  TExecFunctionRest = function: string of object;

  TServerConfig = class
  public
    const
      MAX_FILE_SIZE = 4 * 1024 * 1024;
    class procedure Initialize; static;
    class function ConfigFileName: string; static;
    class function HasExplicitConfig: Boolean; static;
    class function ReadString(const ASection, AName, ADefault: string): string; static;
    class function GzipEnabled: Boolean; static;
    class function GzipMinimumBytes: Integer; static;
    class function GzipLevel: Integer; static;
  end;

var
  COUNTER_HIT_REQUEST: Int64;

implementation

uses
  System.IniFiles, System.IOUtils, System.SyncObjs;

var
  GConfigLock: TCriticalSection;
  GConfigInitialized: Boolean;
  GConfigFileName: string;
  GExplicitConfig: Boolean;
  GGzipEnabled: Boolean;
  GGzipMinimumBytes: Integer;
  GGzipLevel: Integer;

function IsAbsoluteFileName(const AFileName: string): Boolean;
begin
  {$IF DEFINED(MSWINDOWS)}
  Result := ((Length(AFileName) >= 3) and (AFileName[2] = ':') and
    CharInSet(AFileName[3], ['\', '/'])) or AFileName.StartsWith('\\');
  {$ELSE}
  Result := AFileName.StartsWith('/');
  {$ENDIF}
end;

class procedure TServerConfig.Initialize;
var
  LFileName: string;
  LExplicit: Boolean;
  LIni: TIniFile;
  LEnabled: Boolean;
  LMinimumBytes: Integer;
  LLevel: Integer;

  function ReadHTTPSetting(const AName, ADefault: string): string;
  begin
    Result := ADefault;
    if Assigned(LIni) then
      Result := Trim(LIni.ReadString('HTTP', AName, ADefault));
  end;
begin
  GConfigLock.Enter;
  try
    if GConfigInitialized then
      Exit;

    LFileName := Trim(GetEnvironmentVariable('DELPHI_API_CONFIG'));
    LExplicit := LFileName <> '';
    if LExplicit then begin
      if not IsAbsoluteFileName(LFileName) then
        raise Exception.Create('DELPHI_API_CONFIG must be an absolute file path.');
      if not FileExists(LFileName) then
        raise Exception.Create('DELPHI_API_CONFIG must reference an existing configuration file.');
    end else begin
      LFileName := TPath.Combine(ExtractFilePath(ExpandFileName(ParamStr(0))), 'config.ini');
      if not FileExists(LFileName) then
        LFileName := TPath.Combine(ExpandFileName(GetCurrentDir), 'config.ini');
    end;

    LIni := nil;
    try
      if FileExists(LFileName) then
        LIni := TIniFile.Create(LFileName);
      if not TryStrToBool(ReadHTTPSetting('GzipEnabled', 'True'), LEnabled) then
        raise Exception.Create('[HTTP] GzipEnabled must be True or False.');
      if not TryStrToInt(ReadHTTPSetting('GzipMinimumBytes', '1024'), LMinimumBytes) or
        (LMinimumBytes < 0) then
        raise Exception.Create('[HTTP] GzipMinimumBytes must be a nonnegative integer.');
      if not TryStrToInt(ReadHTTPSetting('GzipLevel', '1'), LLevel) or
        (LLevel < 1) or (LLevel > 9) then
        raise Exception.Create('[HTTP] GzipLevel must be an integer from 1 to 9.');
    finally
      LIni.Free;
    end;

    GConfigFileName := ExpandFileName(LFileName);
    GExplicitConfig := LExplicit;
    GGzipEnabled := LEnabled;
    GGzipMinimumBytes := LMinimumBytes;
    GGzipLevel := LLevel;
    GConfigInitialized := True;
  finally
    GConfigLock.Leave;
  end;
end;

class function TServerConfig.GzipEnabled: Boolean;
begin
  if not GConfigInitialized then Initialize;
  Result := GGzipEnabled;
end;

class function TServerConfig.GzipMinimumBytes: Integer;
begin
  if not GConfigInitialized then Initialize;
  Result := GGzipMinimumBytes;
end;

class function TServerConfig.GzipLevel: Integer;
begin
  if not GConfigInitialized then Initialize;
  Result := GGzipLevel;
end;

class function TServerConfig.ConfigFileName: string;
begin
  if not GConfigInitialized then
    Initialize;
  Result := GConfigFileName;
end;

class function TServerConfig.HasExplicitConfig: Boolean;
begin
  if not GConfigInitialized then
    Initialize;
  Result := GExplicitConfig;
end;

class function TServerConfig.ReadString(const ASection, AName,
  ADefault: string): string;
var
  LIni: TIniFile;
begin
  Result := ADefault;
  if not FileExists(ConfigFileName) then
    Exit;

  LIni := TIniFile.Create(ConfigFileName);
  try
    Result := Trim(LIni.ReadString(ASection, AName, ADefault));
  finally
    LIni.Free;
  end;
end;

initialization
  GConfigLock := TCriticalSection.Create;

finalization
  GConfigLock.Free;

end.
