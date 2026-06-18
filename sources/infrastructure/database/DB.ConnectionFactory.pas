unit DB.ConnectionFactory;

interface

uses
  FireDAC.Comp.Client, System.SysUtils, System.StrUtils, System.Classes;

type
  TDBConnectionFactory = class
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
  FireDAC.DApt;

{ TDBConnectionFactory }

class function TDBConnectionFactory.GetConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.ConnectionDefName := 'MyDB';
  Result.LoginPrompt := False;
  Result.Connected := True;
end;

class procedure TDBConnectionFactory.Initialize;
var
  Params: TStringList;
begin
  if not FDManager.Active then FDManager.Active := True;

  if FDManager.ConnectionDefs.FindConnectionDef('MyDB') = nil then begin
    Params := TStringList.Create;
    try
      Params.Values['Server'] := 'localhost';
      Params.Values['Database'] := 'demo_delphirest';//'demo_delphirest';
      Params.Values['User_Name'] := 'root';
      Params.Values['Password'] := '';
      Params.Values['CharacterSet'] := 'utf8mb4';

      Params.Values['Pooled'] := 'True';
      Params.Values['POOL_MaximumItems'] := '50';
      Params.Values['POOL_ExpireTimeout'] := '300000';

      FDManager.AddConnectionDef(
        'MyDB',
        'MySQL',
        Params,
        False
      );
    finally
      Params.Free;
    end;
  end;
end;

end.
