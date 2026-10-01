unit Role.Service;

interface

uses System.Classes, System.SysUtils, FireDAC.Comp.Client, Web.HTTPApp, Role.Repository, Auth.Policy;

type
  TRoleService = class(TPersistent)
  private
    FRepository: TRoleRepository;
    FRequest: TWebRequest;
    FStatusCode: Integer;
    function Actor(const APermission: string): TAuthActor;
  public
    constructor Create(AConnection: TFDConnection; ARequest: TWebRequest);
    destructor Destroy; override;
    property StatusCode: Integer read FStatusCode;
  published
    function Get: string;
    function Permissions: string;
  end;

implementation

uses System.JSON, BFA.Core.Response, BFA.Security.Token, Auth.Validator, Role.Validator;

constructor TRoleService.Create(AConnection: TFDConnection; ARequest: TWebRequest);
begin
  inherited Create;
  FRequest := ARequest;
  FStatusCode := 500;
  FRepository := TRoleRepository.Create(AConnection);
end;

destructor TRoleService.Destroy;
begin
  FreeAndNil(FRepository);
  inherited;
end;

function TRoleService.Actor(const APermission: string): TAuthActor;
begin
  Result := FRepository.ResolveActor(TSecurityToken.ExtractAccessToken(FRequest));
  Result.RequirePermission(APermission);
end;

function TRoleService.Get: string;
var LActor: TAuthActor; LData: TJSONArray;
begin
  LActor := Actor('roles.read');
  LData := FRepository.Catalog(TAuthValidator.PageValue(FRequest, 'limit', 50, 100),
    TAuthValidator.PageValue(FRequest, 'offset', 0, 100000));
  try
    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(200, 'OK', LData);
  finally
    FreeAndNil(LData);
  end;
end;

function TRoleService.Permissions: string;
var LActor: TAuthActor; LCodes: TArray<string>; LCode, LTarget: string; LQuery: TFDQuery; LRole: Integer;
begin
  LActor := Actor('roles.manage');
  LActor.RequireRecent;
  LTarget := FRequest.PathInfo.Trim(['/']).Split(['/'])[3];
  TAuthValidator.UUID(LTarget);
  LCodes := TRoleValidator.PermissionCodes(FRequest);
  FRepository.BeginSecurityTransaction;
  try
    LActor := Actor('roles.manage');
    LActor.RequireRecent;
    FRepository.ValidatePermissionCodes(LCodes);
    LQuery := FRepository.FindRole(LTarget);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Role not found.');
      LRole := LQuery.Fields[0].AsInteger;
    finally
      FreeAndNil(LQuery);
    end;
    FRepository.RequireDelegation(LActor, LRole);
    for LCode in LCodes do LActor.RequirePermission(LCode);
    FRepository.ReplacePermissions(LRole, LCodes);
    FRepository.ProtectLastAdmin;
    FRepository.Audit('role_permissions_change', 'success', LActor, '', TAuthValidator.Origin(FRequest), LTarget);
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  FStatusCode := 200;
  Result := THelperResponse.CreateResponse(200, 'OK', TJSONArray(nil));
end;

end.
