unit User.Service;

interface

uses System.Classes, System.SysUtils, System.JSON, FireDAC.Comp.Client, Web.HTTPApp, User.Repository, Auth.Policy;

type
  TUserService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FRepository: TUserRepository;
    FRequest: TWebRequest;
    FData: TFDMemTable;
    FParts: TArray<string>;
    FStatusCode: Integer;
    function Actor(const APermission: string): TAuthActor;
    function Target: string;
    function UserReply(const AID: string; AStatus: Integer): string;
    function LockTarget(const AActor: TAuthActor; const AID: string): Int64;
  public
    constructor Create(AConnection: TFDConnection; AData: TFDMemTable; ARequest: TWebRequest; const AParts: TArray<string>);
    destructor Destroy; override;
    property StatusCode: Integer read FStatusCode;
  published
    function ChangePassword: string;
    function Delete: string;
    function Get: string;
    function Insert: string;
    function ResetPassword: string;
    function Update: string;
  end;

implementation

uses BFA.Core.Response, BFA.Core.Request, BFA.Security.Token, BFA.Security.Crypto, BFA.Helper.Strings,
  Auth.Service, Auth.Validator, Auth.Settings, User.Validator, User.DTO;

constructor TUserService.Create(AConnection: TFDConnection; AData: TFDMemTable;
  ARequest: TWebRequest; const AParts: TArray<string>);
begin
  inherited Create;
  FConnection := AConnection;
  FRequest := ARequest;
  FData := AData;
  FParts := AParts;
  FStatusCode := 500;
  FRepository := TUserRepository.Create(AConnection);
end;

destructor TUserService.Destroy;
begin
  FreeAndNil(FRepository);
  inherited;
end;

function TUserService.Actor(const APermission: string): TAuthActor;
begin
  Result := FRepository.ResolveActor(TSecurityToken.ExtractAccessToken(FRequest));
  Result.RequirePermission(APermission);
end;

function TUserService.Target: string;
begin
  if Length(FParts) < 4 then raise ERequestInvalid.Create('Target required.');
  Result := FParts[3];
  TAuthValidator.UUID(Result);
end;

function TUserService.LockTarget(const AActor: TAuthActor; const AID: string): Int64;
var LQuery, LLocked: TFDQuery;
begin
  LQuery := FRepository.FindUserByID(AID);
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'User not found.');
    Result := LQuery.FieldByName('id').AsLargeInt;
  finally
    FreeAndNil(LQuery);
  end;
  LLocked := FRepository.LockUser(Result);
  try
    if not LLocked.FieldByName('deleted_at').IsNull then raise EAuthPolicy.Create(404, 'User not found.');
    FRepository.RequireTarget(AActor, Result, LLocked.FieldByName('role_internal_id').AsInteger);
  finally
    FreeAndNil(LLocked);
  end;
end;

function TUserService.UserReply(const AID: string; AStatus: Integer): string;
var LData: TJSONArray;
begin
  LData := FRepository.GetUsers(AID, 1, 0);
  try
    FStatusCode := AStatus;
    Result := THelperResponse.CreateResponse(AStatus, 'OK', LData);
  finally
    FreeAndNil(LData);
  end;
end;

function TUserService.Get: string;
var LActor: TAuthActor; LID: string; LData: TJSONArray; LLimit, LOffset: Integer;
begin
  LActor := Actor('users.read');
  LID := '';
  if Length(FParts) = 4 then LID := Target;
  LLimit := TAuthValidator.PageValue(FRequest, 'limit', 50, 100);
  LOffset := TAuthValidator.PageValue(FRequest, 'offset', 0, 100000);
  LData := FRepository.GetUsers(LID, LLimit, LOffset);
  try
    if (LID <> '') and (LData.Count = 0) then raise EAuthPolicy.Create(404, 'User not found.');
    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(200, 'OK', LData);
  finally
    FreeAndNil(LData);
  end;
end;

function TUserService.Insert: string;
var LActor: TAuthActor; LRequest: TUserCreateRequest; LHash, LID, LSetup, LSlot: string; LInternalID: Int64;
  LData: TJSONArray;
begin
  LActor := Actor('users.create');
  LRequest := TUserValidator.ValidateCreate(FRequest);
  if LRequest.HasRoleID then begin
    LActor.RequireRecent;
    LActor.RequirePermission('users.assign_role');
    FRepository.RequireDelegation(LActor, LRequest.RoleID);
  end;
  if not FRepository.Admit(LActor.Username, TAuthValidator.Origin(FRequest)) then
    raise EAuthPolicy.Create(429, 'Authentication rate limit exceeded.');
  LSetup := '';
  if LRequest.Password = '' then begin
    LRequest.Password := TSecurityCrypto.NewCredential;
    LSetup := TSecurityCrypto.NewCredential;
  end;
  LSlot := FRepository.AcquireKDF;
  try
    LHash := TSecurityCrypto.HashPassword(LRequest.Password);
  finally
    FRepository.ReleaseKDF(LSlot);
  end;
  LID := TGlobalFunction.NewDatabaseUUID;
  FRepository.BeginSecurityTransaction;
  try
    LActor := Actor('users.create');
    if LRequest.HasRoleID then begin
      LActor.RequireRecent;
      FRepository.RequireDelegation(LActor, LRequest.RoleID);
    end;
    LInternalID := FRepository.CreateUser(LID, LRequest, LHash);
    if LSetup <> '' then FRepository.RecoveryToken(LInternalID, LActor.UserInternalID, 'account_setup', LSetup);
    FRepository.Audit('user_create', 'success', LActor, LID, TAuthValidator.Origin(FRequest));
    LData := FRepository.GetUsers(LID, 1, 0);
    try
      if LData.Count <> 1 then raise EAuthPolicy.Create(409, 'Mutation conflict.');
      if LSetup <> '' then begin
        TJSONObject(LData.Items[0]).AddPair('setup_token', LSetup);
        TJSONObject(LData.Items[0]).AddPair('expires_in', TJSONNumber.Create(TAuthSettings.RecoverySeconds));
      end;
      FStatusCode := 201;
      Result := THelperResponse.CreateResponse(201, 'User created.', LData);
    finally
      FreeAndNil(LData);
    end;
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
end;

function TUserService.Update: string;
var LActor: TAuthActor; LRequest: TUserUpdateRequest; LID: Int64;
begin
  LActor := Actor('users.update');
  LRequest := TUserValidator.ValidateUpdate(FRequest, Target);
  FRepository.BeginSecurityTransaction;
  try
    LActor := Actor('users.update');
    if LRequest.HasRoleID or LRequest.HasIsActive then LActor.RequireRecent;
    if LRequest.HasRoleID then begin
      LActor.RequirePermission('users.assign_role');
      FRepository.RequireDelegation(LActor, LRequest.RoleID);
    end;
    LID := LockTarget(LActor, LRequest.UserID);
    FRepository.UpdateUser(LRequest);
    if LRequest.HasRoleID or LRequest.HasIsActive then begin
      FRepository.RevokeUser(LID, 'user_security_change');
      FRepository.RevokeRecovery(LID, 'user_security_change');
      FRepository.ProtectLastAdmin;
    end;
    FRepository.Audit('user_update', 'success', LActor, LRequest.UserID, TAuthValidator.Origin(FRequest));
    Result := UserReply(LRequest.UserID, 200);
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
end;

function TUserService.Delete: string;
var LActor: TAuthActor; LTarget: string; LID: Int64;
begin
  LTarget := Target;
  FRepository.BeginSecurityTransaction;
  try
    LActor := Actor('users.delete');
    LActor.RequireRecent;
    LID := LockTarget(LActor, LTarget);
    FRepository.SoftDeleteUser(LID);
    FRepository.RevokeUser(LID, 'user_delete');
    FRepository.RevokeRecovery(LID, 'user_delete');
    FRepository.ProtectLastAdmin;
    FRepository.Audit('user_delete', 'success', LActor, LTarget, TAuthValidator.Origin(FRequest));
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  FStatusCode := 200;
  Result := THelperResponse.CreateResponse(200, 'OK', TJSONArray(nil));
end;

function TUserService.ResetPassword: string;
var LActor: TAuthActor; LTarget, LToken: string; LID: Int64; LTTL: Integer; LData: TJSONArray; LRow: TJSONObject;
begin
  LTarget := Target;
  TUserValidator.ValidateResetPassword(FRequest);
  LToken := TSecurityCrypto.NewCredential;
  FRepository.BeginSecurityTransaction;
  try
    LActor := Actor('users.reset_password');
    LActor.RequireRecent;
    LID := LockTarget(LActor, LTarget);
    LTTL := FRepository.RecoveryToken(LID, LActor.UserInternalID, 'password_reset', LToken);
    FRepository.Audit('password_reset_issue', 'success', LActor, LTarget, TAuthValidator.Origin(FRequest));
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  LData := TJSONArray.Create;
  try
    LRow := TJSONObject.Create;
    LData.AddElement(LRow);
    LRow.AddPair('user_id', LTarget);
    LRow.AddPair('reset_token', LToken);
    LRow.AddPair('expires_in', TJSONNumber.Create(LTTL));
    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(200, 'OK', LData);
  finally
    FreeAndNil(LData);
  end;
end;

function TUserService.ChangePassword: string;
var LService: TAuthService;
begin
  LService := TAuthService.Create(FConnection, FData, FRequest);
  try
    Result := LService.ChangePassword;
    FStatusCode := LService.StatusCode;
  finally
    FreeAndNil(LService);
  end;
end;

end.
