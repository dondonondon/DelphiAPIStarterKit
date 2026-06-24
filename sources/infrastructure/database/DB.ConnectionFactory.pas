unit DB.ConnectionFactory;

interface

uses
  FireDAC.Comp.Client, System.SysUtils, System.StrUtils, System.Classes;

type
  TDBConnectionFactory = class
  private
    class function ConfigFileName: string; static;
    class function ReadDatabaseSetting(const AEnvName, AName, ADefaultValue: string): string; static;
    class function RequireDatabaseSetting(const AEnvName, AName: string): string; static;
  public
    class procedure Initialize;
    class function GetConnection: TFDConnection;
  end;

implementation

uses
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Pool,
  FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Comp.UI,
  FireDAC.Stan.Param,
  FireDAC.DApt,
  System.IniFiles,
  System.IOUtils;

const
  DB_CONNECTION_NAME = 'MyDB';
  DB_CONFIG_SECTION = 'Database';
  DB_SERVER_ENV_NAME = 'DELPHI_API_DB_SERVER';
  DB_DATABASE_ENV_NAME = 'DELPHI_API_DB_DATABASE';
  DB_USER_ENV_NAME = 'DELPHI_API_DB_USER';
  DB_PASSWORD_ENV_NAME = 'DELPHI_API_DB_PASSWORD';
  DB_CHARACTER_SET_ENV_NAME = 'DELPHI_API_DB_CHARACTER_SET';
  DB_POOL_MAXIMUM_ITEMS_ENV_NAME = 'DELPHI_API_DB_POOL_MAXIMUM_ITEMS';
  DB_POOL_EXPIRE_TIMEOUT_ENV_NAME = 'DELPHI_API_DB_POOL_EXPIRE_TIMEOUT';
  DB_SERVER_NAME = 'Server';
  DB_DATABASE_NAME = 'Database';
  DB_USER_NAME = 'User_Name';
  DB_PASSWORD_NAME = 'Password';
  DB_CHARACTER_SET_NAME = 'CharacterSet';
  DB_POOL_MAXIMUM_ITEMS_NAME = 'POOL_MaximumItems';
  DB_POOL_EXPIRE_TIMEOUT_NAME = 'POOL_ExpireTimeout';

{ TDBConnectionFactory }

class function TDBConnectionFactory.ConfigFileName: string;
begin
  Result := TPath.Combine(ExpandFileName(GetCurrentDir), 'config.ini');
end;

class function TDBConnectionFactory.GetConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.ConnectionDefName := DB_CONNECTION_NAME;
  Result.LoginPrompt := False;
  Result.Connected := True;
end;

class procedure TDBConnectionFactory.Initialize;
var
  Params: TStringList;
begin
  if not FDManager.Active then FDManager.Active := True;

  if FDManager.ConnectionDefs.FindConnectionDef(DB_CONNECTION_NAME) = nil then begin
    Params := TStringList.Create;
    try
      Params.Values[DB_SERVER_NAME] := RequireDatabaseSetting(DB_SERVER_ENV_NAME, DB_SERVER_NAME);
      Params.Values[DB_DATABASE_NAME] := RequireDatabaseSetting(DB_DATABASE_ENV_NAME, DB_DATABASE_NAME);
      Params.Values[DB_USER_NAME] := RequireDatabaseSetting(DB_USER_ENV_NAME, DB_USER_NAME);
      Params.Values[DB_PASSWORD_NAME] := ReadDatabaseSetting(DB_PASSWORD_ENV_NAME, DB_PASSWORD_NAME, '');
      Params.Values[DB_CHARACTER_SET_NAME] := ReadDatabaseSetting(DB_CHARACTER_SET_ENV_NAME, DB_CHARACTER_SET_NAME, 'utf8mb4');

      Params.Values['Pooled'] := 'True';
      Params.Values[DB_POOL_MAXIMUM_ITEMS_NAME] := ReadDatabaseSetting(DB_POOL_MAXIMUM_ITEMS_ENV_NAME, DB_POOL_MAXIMUM_ITEMS_NAME, '50');
      Params.Values[DB_POOL_EXPIRE_TIMEOUT_NAME] := ReadDatabaseSetting(DB_POOL_EXPIRE_TIMEOUT_ENV_NAME, DB_POOL_EXPIRE_TIMEOUT_NAME, '300000');

      FDManager.AddConnectionDef(
        DB_CONNECTION_NAME,
        'MySQL',
        Params,
        False
      );
    finally
      Params.Free;
    end;
  end;
end;

class function TDBConnectionFactory.ReadDatabaseSetting(const AEnvName, AName,
  ADefaultValue: string): string;
var
  LConfigFileName: string;
  LIni: TIniFile;
begin
  Result := Trim(GetEnvironmentVariable(AEnvName));
  if Result <> '' then
    Exit;

  Result := ADefaultValue;
  LConfigFileName := ConfigFileName;
  if not FileExists(LConfigFileName) then
    Exit;

  LIni := TIniFile.Create(LConfigFileName);
  try
    Result := Trim(LIni.ReadString(DB_CONFIG_SECTION, AName, ADefaultValue));
  finally
    FreeAndNil(LIni);
  end;
end;

class function TDBConnectionFactory.RequireDatabaseSetting(const AEnvName,
  AName: string): string;
begin
  Result := ReadDatabaseSetting(AEnvName, AName, '');
  if Result <> '' then
    Exit;

  raise Exception.CreateFmt('%s environment variable or [%s] %s in config.ini is required.',
    [AEnvName, DB_CONFIG_SECTION, AName]);
end;

end.
