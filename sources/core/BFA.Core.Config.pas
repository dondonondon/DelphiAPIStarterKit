unit BFA.Core.Config;

interface

uses System.SysUtils;

type
  TExecFunctionRest = function: string of object;

  TServerConfig = class
  public
    const
      MAX_FILE_SIZE = 4 * 1024 * 1024;
    class function FileName: string; static;
    class function ReadValue(const ASection, AName, AEnv, ADefault: string; ASecret: Boolean = False): string; static;
    class function ReadInteger(const AName, AEnv: string; ADefault, AMinimum, AMaximum: Integer): Integer; static;
    class function LogFile: string; static;
  end;

var
  COUNTER_HIT_REQUEST: Int64;

implementation

uses System.IOUtils, System.IniFiles;

class function TServerConfig.LogFile: string;
var LRoot: string;
begin
  LRoot := ReadValue('Logging', 'Root', 'DELPHI_API_LOG_ROOT', 'logs');
  if not TPath.IsPathRooted(LRoot) then LRoot := TPath.Combine(ExtractFilePath(FileName), LRoot);
  LRoot := TPath.GetFullPath(LRoot);
  Result := ReadValue('Logging', 'ErrorFile', 'DELPHI_API_ERROR_FILE', 'server-error.log');
  if Result = '' then Result := 'server-error.log';
  if not TPath.IsPathRooted(Result) then Result := TPath.Combine(LRoot, Result);
  Result := TPath.GetFullPath(Result);
end;

class function TServerConfig.FileName: string;
begin
  Result := GetEnvironmentVariable('DELPHI_API_CONFIG');
  if Result <> '' then begin
    if not TPath.IsPathRooted(Result) then
      raise Exception.Create('DELPHI_API_CONFIG must be absolute.');
    Exit;
  end;
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'config.ini');
end;

class function TServerConfig.ReadValue(const ASection, AName, AEnv, ADefault: string; ASecret: Boolean): string;
var LIni: TMemIniFile; LLine, LSection: string; LSeparator: Integer;
begin
  Result := GetEnvironmentVariable(AEnv);
  if Result = '' then begin
    if ASecret then begin
      Result := ADefault;
      LSection := '';
      if not FileExists(FileName) then Exit;
      for LLine in TFile.ReadAllLines(FileName, TEncoding.UTF8) do begin
        if LLine.Trim.StartsWith('[') and LLine.Trim.EndsWith(']') then LSection := LLine.Trim.Trim(['[',']'])
        else if SameText(LSection, ASection) then begin
          LSeparator := Pos('=', LLine);
          if (LSeparator > 0) and SameText(Copy(LLine, 1, LSeparator - 1).Trim, AName) then
            Result := Copy(LLine, LSeparator + 1, MaxInt);
        end;
      end;
      Exit;
    end;
    LIni := TMemIniFile.Create(FileName, TEncoding.UTF8);
    try
      Result := LIni.ReadString(ASection, AName, ADefault);
    finally
      FreeAndNil(LIni);
    end;
  end;
  if not ASecret then Result := Trim(Result);
end;

class function TServerConfig.ReadInteger(const AName, AEnv: string; ADefault, AMinimum, AMaximum: Integer): Integer;
begin
  if not TryStrToInt(ReadValue('Security', AName, AEnv, IntToStr(ADefault)), Result) or
    (Result < AMinimum) or (Result > AMaximum) then
    raise Exception.CreateFmt('Invalid security setting: %s.', [AName]);
end;

end.
