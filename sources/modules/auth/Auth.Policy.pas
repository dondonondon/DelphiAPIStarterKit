unit Auth.Policy;

interface

uses System.SysUtils;

type
  TAuthCatalog = class
  public
    class function Codes: TArray<string>; static;
  end;

  EAuthPolicy = class(Exception)
  private
    FStatus: Integer;
  public
    constructor Create(AStatus: Integer; const AMessage: string);
    property Status: Integer read FStatus;
  end;

  TAuthActor = record
    UserInternalID, SessionInternalID: Int64;
    UserID, SessionID, Username, Fullname, RoleCode: string;
    RoleID: Integer;
    Restricted, Recent: Boolean;
    Permissions: TArray<string>;
    function HasPermission(const ACode: string): Boolean;
    procedure RequirePermission(const ACode: string);
    procedure RequireRecent;
  end;

implementation

class function TAuthCatalog.Codes: TArray<string>;
begin
  Result := ['users.read','users.create','users.update','users.delete','users.reset_password','users.assign_role',
    'roles.read','roles.manage','products.read','products.create','products.update','products.delete',
    'customers.read','customers.create','customers.update','customers.delete',
    'category.read','category.create','category.update','category.delete'];
end;

constructor EAuthPolicy.Create(AStatus: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FStatus := AStatus;
end;

function TAuthActor.HasPermission(const ACode: string): Boolean;
var LCode: string;
begin
  Result := False;
  if Restricted or (UserInternalID = 0) then Exit;
  for LCode in Permissions do if LCode = ACode then Exit(True);
end;

procedure TAuthActor.RequirePermission(const ACode: string);
begin
  if not HasPermission(ACode) then raise EAuthPolicy.Create(403, 'Permission required.');
end;

procedure TAuthActor.RequireRecent;
begin
  if Restricted or not Recent then raise EAuthPolicy.Create(403, 'Recent authentication required.');
end;

end.
