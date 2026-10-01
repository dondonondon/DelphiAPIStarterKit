unit Auth.Service;

interface

uses System.Classes, System.SysUtils, System.JSON, FireDAC.Comp.Client, Web.HTTPApp, Auth.Repository, Auth.Policy;

type
  TAuthService = class(TPersistent)
  private
    FRepository: TAuthRepository;
    FRequest: TWebRequest;
    FStatusCode: Integer;
    function Access: string;
    function Actor: TAuthActor;
    function Reply(AData: TJSONArray = nil): string;
    function Tokens(const AAccess, ARefresh, ASession: string; AAccessTTL, ARefreshTTL: Integer; ARestricted: Boolean): string;
    procedure Throttle(const AAccount: string);
    function Verify(const APassword, AHash: string): Boolean;
    function Hash(const APassword: string): string;
  public
    constructor Create(AConnection: TFDConnection; AData: TFDMemTable; AWebRequest: TWebRequest);
    destructor Destroy; override;
    property StatusCode: Integer read FStatusCode;
  published
    function Login: string;
    function Refresh: string;
    function Logout: string;
    function Reauthenticate: string;
    function LogoutAll: string;
    function Me: string;
    function Sessions: string;
    function RevokeOwnSession: string;
    function CompletePasswordReset: string;
    function ChangePassword: string;
  end;

implementation

uses Data.DB, BFA.Core.Request, BFA.Core.Response, BFA.Security.Crypto, BFA.Security.Token,
  BFA.Helper.Strings, Auth.Settings, Auth.Validator;

constructor TAuthService.Create(AConnection: TFDConnection; AData: TFDMemTable; AWebRequest: TWebRequest);
begin
  inherited Create;
  FRequest := AWebRequest;
  FStatusCode := 500;
  FRepository := TAuthRepository.Create(AConnection);
end;

destructor TAuthService.Destroy;
begin
  FreeAndNil(FRepository);
  inherited;
end;

function TAuthService.Access: string;
begin
  Result := TSecurityToken.ExtractAccessToken(FRequest);
end;

function TAuthService.Actor: TAuthActor;
begin
  Result := FRepository.ResolveActor(Access);
  if Result.Restricted then raise EAuthPolicy.Create(403, 'Password change required.');
end;

function TAuthService.Reply(AData: TJSONArray): string;
begin
  FStatusCode := 200;
  Result := THelperResponse.CreateResponse(200, 'OK', AData);
end;

function TAuthService.Tokens(const AAccess, ARefresh, ASession: string;
  AAccessTTL, ARefreshTTL: Integer; ARestricted: Boolean): string;
var LArray: TJSONArray; LObject: TJSONObject;
begin
  LArray := TJSONArray.Create;
  try
    LObject := TJSONObject.Create;
    LArray.AddElement(LObject);
    LObject.AddPair('access_token', AAccess);
    if not ARestricted then LObject.AddPair('refresh_token', ARefresh);
    LObject.AddPair('token_type', 'Bearer');
    LObject.AddPair('expires_in', TJSONNumber.Create(AAccessTTL));
    LObject.AddPair('refresh_expires_in', TJSONNumber.Create(ARefreshTTL));
    LObject.AddPair('session_id', ASession);
    LObject.AddPair('password_change_required', TJSONBool.Create(ARestricted));
    Result := Reply(LArray);
  finally
    FreeAndNil(LArray);
  end;
end;

procedure TAuthService.Throttle(const AAccount: string);
begin
  if not FRepository.Admit(AAccount, TAuthValidator.Origin(FRequest)) then
    raise EAuthPolicy.Create(429, 'Authentication rate limit exceeded.');
end;

function TAuthService.Verify(const APassword, AHash: string): Boolean;
var LSlot: string;
begin
  LSlot := FRepository.AcquireKDF;
  try
    Result := TSecurityCrypto.VerifyPassword(APassword, AHash);
  finally
    FRepository.ReleaseKDF(LSlot);
  end;
end;

function TAuthService.Hash(const APassword: string): string;
var LSlot: string;
begin
  LSlot := FRepository.AcquireKDF;
  try
    Result := TSecurityCrypto.HashPassword(APassword);
  finally
    FRepository.ReleaseKDF(LSlot);
  end;
end;

function TAuthService.Login: string;
var LBody: TJSONObject; LUser, LLocked: TFDQuery; LUsername, LPassword, LDevice, LName, LAgent, LIP: string;
  LHash, LNewHash, LAccess, LRefresh, LSession: string; LUserID, LSessionID, LRefreshID: Int64;
  LRestricted, LValid: Boolean; LAccessTTL, LRefreshTTL: Integer; LActor: TAuthActor;
begin
  LBody := THelperRequest.JSONObject(FRequest, ['username','password','device_id','device_name']);
  try
    LUsername := THelperRequest.JSONString(LBody, 'username', True, 50);
    TAuthValidator.Username(LUsername);
    LPassword := THelperRequest.JSONString(LBody, 'password', True, 128);
    TAuthValidator.Password(LPassword, False);
    LDevice := THelperRequest.JSONString(LBody, 'device_id', True, 100);
    LName := THelperRequest.JSONString(LBody, 'device_name', False, 100);
  finally
    FreeAndNil(LBody);
  end;
  LAgent := FRequest.GetFieldByName('User-Agent');
  if THelperRequest.Codepoints(LAgent) > 255 then raise ERequestInvalid.Create('User-Agent exceeds limit.');
  LIP := TAuthValidator.Origin(FRequest);
  Throttle(LUsername);
  LUserID := 0;
  LHash := TSecurityCrypto.DummyPasswordHash;
  LValid := False;
  LUser := FRepository.FindUserForLogin(LUsername);
  try
    if not LUser.IsEmpty then begin
      LUserID := LUser.FieldByName('id').AsLargeInt;
      LHash := LUser.FieldByName('password_hash').AsString;
      LValid := LUser.FieldByName('is_active').AsBoolean and LUser.FieldByName('deleted_at').IsNull;
    end;
  finally
    FreeAndNil(LUser);
  end;
  if not Verify(LPassword, LHash) or not LValid then raise EAuthPolicy.Create(401, 'Invalid username or password.');
  LNewHash := LHash;
  if TSecurityCrypto.NeedsRehash(LHash) then LNewHash := Hash(LPassword);
  LAccess := TSecurityCrypto.NewCredential;
  LRefresh := TSecurityCrypto.NewCredential;
  LSession := TGlobalFunction.NewDatabaseUUID;
  LActor := Default(TAuthActor);
  FRepository.BeginSecurityTransaction;
  try
    LLocked := FRepository.LockUser(LUserID);
    try
      if LLocked.IsEmpty or not LLocked.FieldByName('is_active').AsBoolean or
        not LLocked.FieldByName('deleted_at').IsNull or (LLocked.FieldByName('password_hash').AsString <> LHash) then
        raise EAuthPolicy.Create(401, 'Invalid username or password.');
      LRestricted := LLocked.FieldByName('must_change_password').AsBoolean;
      LActor.UserID := LLocked.FieldByName('user_id').AsString;
      LActor.UserInternalID := LUserID;
    finally
      FreeAndNil(LLocked);
    end;
    if LNewHash <> LHash then FRepository.RehashPassword(LUserID, LNewHash);
    LSessionID := FRepository.CreateSession(LUserID, LSession, LDevice, LName, LAgent, LIP, LRestricted);
    LActor.SessionID := LSession;
    FRepository.IssueTokens(LSessionID, LAccess, LRefresh, LRestricted, LAccessTTL, LRefreshTTL, LRefreshID);
    FRepository.Audit('login', 'success', LActor, LActor.UserID, LIP);
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  Result := Tokens(LAccess, LRefresh, LSession, LAccessTTL, LRefreshTTL, LRestricted);
end;

function TAuthService.Refresh: string;
var LBody: TJSONObject; LToken, LHash, LAccess, LRefresh, LSession: string; LQuery, LUser: TFDQuery;
  LUserID, LSessionID, LOldID, LNewID: Int64; LAccessTTL, LRefreshTTL: Integer; LActor: TAuthActor;
begin
  LBody := THelperRequest.JSONObject(FRequest, ['refresh_token']);
  try
    LToken := THelperRequest.JSONString(LBody, 'refresh_token', True, 43);
  finally
    FreeAndNil(LBody);
  end;
  LHash := TSecurityCrypto.TokenHash(LToken);
  if LHash = '' then raise EAuthPolicy.Create(401, 'Invalid credential.');
  LQuery := FRepository.FindRefresh(LHash);
  try
    if LQuery.IsEmpty then begin
      Throttle('unknown-refresh:' + LHash);
      raise EAuthPolicy.Create(401, 'Invalid credential.');
    end;
    Throttle(LQuery.FieldByName('username').AsString);
    LUserID := LQuery.FieldByName('user_internal_id').AsLargeInt;
    LSessionID := LQuery.FieldByName('session_internal_id').AsLargeInt;
    LOldID := LQuery.FieldByName('id').AsLargeInt;
  finally
    FreeAndNil(LQuery);
  end;
  LAccess := TSecurityCrypto.NewCredential;
  LRefresh := TSecurityCrypto.NewCredential;
  FRepository.BeginSecurityTransaction;
  try
    LUser := FRepository.LockUser(LUserID);
    try
      LActor := Default(TAuthActor);
      LActor.UserID := LUser.FieldByName('user_id').AsString;
      if LUser.IsEmpty or not LUser.FieldByName('is_active').AsBoolean or
        not LUser.FieldByName('deleted_at').IsNull or LUser.FieldByName('must_change_password').AsBoolean then
        raise EAuthPolicy.Create(401, 'Invalid credential.');
    finally
      FreeAndNil(LUser);
    end;
    FRepository.LockSession(LSessionID);
    LQuery := FRepository.RefreshState(LOldID);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(401, 'Invalid credential.');
      LSession := LQuery.FieldByName('session_id').AsString;
      LActor.SessionID := LSession;
      if not LQuery.FieldByName('consumed_at').IsNull then begin
        FRepository.RevokeSession(LSessionID, 'refresh_reuse');
        FRepository.Audit('refresh_reuse', 'denied', LActor, LActor.UserID, TAuthValidator.Origin(FRequest));
        FRepository.Commit;
        raise EAuthPolicy.Create(401, 'Invalid credential.');
      end;
      if LQuery.FieldByName('revoked').AsBoolean or (LQuery.FieldByName('valid').AsInteger = 0) then
        raise EAuthPolicy.Create(401, 'Invalid credential.');
    finally
      FreeAndNil(LQuery);
    end;
    FRepository.RotateSession(LSessionID);
    FRepository.IssueTokens(LSessionID, LAccess, LRefresh, False, LAccessTTL, LRefreshTTL, LNewID);
    FRepository.ConsumeRefresh(LOldID, LNewID);
    FRepository.Audit('refresh', 'success', LActor, LActor.UserID, TAuthValidator.Origin(FRequest));
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  Result := Tokens(LAccess, LRefresh, LSession, LAccessTTL, LRefreshTTL, False);
end;

function TAuthService.Logout: string;
var LToken, LHash, LTable: string; LBody: TJSONObject; LQuery, LUser: TFDQuery; LSession, LUserID: Int64;
begin
  LToken := Access;
  LTable := 'access_token';
  if FRequest.Content <> '' then begin
    LBody := THelperRequest.JSONObject(FRequest, ['refresh_token']);
    try
      var LRefresh := THelperRequest.JSONString(LBody, 'refresh_token', True, 43);
      if LToken <> '' then raise EAuthPolicy.Create(400, 'Conflicting credentials.');
      LToken := LRefresh;
      LTable := 'refresh_token';
    finally
      FreeAndNil(LBody);
    end;
  end;
  LHash := TSecurityCrypto.TokenHash(LToken);
  if LHash = '' then raise EAuthPolicy.Create(401, 'Invalid credential.');
  Throttle('logout:' + LHash);
  LQuery := FRepository.FindCredentialSession(LHash, LTable = 'refresh_token');
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(401, 'Invalid credential.');
    LSession := LQuery.FieldByName('session_internal_id').AsLargeInt;
    LUserID := LQuery.FieldByName('user_internal_id').AsLargeInt;
  finally
    FreeAndNil(LQuery);
  end;
  FRepository.BeginSecurityTransaction;
  try
    LUser := FRepository.LockUser(LUserID);
    FreeAndNil(LUser);
    FRepository.LockSession(LSession);
    FRepository.RevokeSession(LSession, 'logout');
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  Result := Reply;
end;

function TAuthService.Me: string;
var LActor: TAuthActor; LData, LPermissions: TJSONArray; LRow: TJSONObject; LCode: string;
begin
  LActor := Actor;
  LData := TJSONArray.Create;
  try
    LRow := TJSONObject.Create;
    LData.AddElement(LRow);
    LRow.AddPair('user_id', LActor.UserID);
    LRow.AddPair('username', LActor.Username);
    LRow.AddPair('fullname', LActor.Fullname);
    if LActor.RoleID = 0 then LRow.AddPair('role_id', TJSONNull.Create)
    else LRow.AddPair('role_id', TJSONNumber.Create(LActor.RoleID));
    LRow.AddPair('role_code', LActor.RoleCode);
    LPermissions := TJSONArray.Create;
    LRow.AddPair('permissions', LPermissions);
    for LCode in LActor.Permissions do LPermissions.Add(LCode);
    Result := Reply(LData);
  finally
    FreeAndNil(LData);
  end;
end;

function TAuthService.Sessions: string;
var LActor: TAuthActor; LData: TJSONArray; LLimit, LOffset: Integer;
begin
  LActor := Actor;
  LLimit := TAuthValidator.PageValue(FRequest, 'limit', 50, 100);
  LOffset := TAuthValidator.PageValue(FRequest, 'offset', 0, 100000);
  LData := FRepository.OwnedSessions(LActor.UserInternalID, LLimit, LOffset);
  try
    Result := Reply(LData);
  finally
    FreeAndNil(LData);
  end;
end;

function TAuthService.RevokeOwnSession: string;
var LActor: TAuthActor; LTarget: string; LUser, LQuery: TFDQuery;
begin
  LTarget := FRequest.PathInfo.Trim(['/']).Split(['/'])[4];
  TAuthValidator.UUID(LTarget);
  FRepository.BeginSecurityTransaction;
  try
    LActor := Actor;
    LUser := FRepository.LockUser(LActor.UserInternalID);
    FreeAndNil(LUser);
    LQuery := FRepository.FindOwnedSession(LActor.UserInternalID, LTarget);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Session not found.');
      FRepository.RevokeSession(LQuery.Fields[0].AsLargeInt, 'self_revoke');
    finally
      FreeAndNil(LQuery);
    end;
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  Result := Reply;
end;

function TAuthService.LogoutAll: string;
var LActor: TAuthActor; LUser: TFDQuery;
begin
  FRepository.BeginSecurityTransaction;
  try
    LActor := Actor;
    LActor.RequireRecent;
    LUser := FRepository.LockUser(LActor.UserInternalID);
    FreeAndNil(LUser);
    FRepository.RevokeUser(LActor.UserInternalID, 'logout_all');
    FRepository.Audit('logout_all', 'success', LActor, LActor.UserID, TAuthValidator.Origin(FRequest));
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  Result := Reply;
end;

function TAuthService.Reauthenticate: string;
var LActor: TAuthActor; LBody: TJSONObject; LPassword, LHash: string; LUser: TFDQuery;
begin
  LActor := Actor;
  LBody := THelperRequest.JSONObject(FRequest, ['password']);
  try
    LPassword := THelperRequest.JSONString(LBody, 'password', True, 128);
    TAuthValidator.Password(LPassword, False);
  finally
    FreeAndNil(LBody);
  end;
  Throttle(LActor.Username);
  LHash := FRepository.PasswordHash(LActor.UserInternalID);
  if not Verify(LPassword, LHash) then raise EAuthPolicy.Create(401, 'Invalid credential.');
  FRepository.BeginSecurityTransaction;
  try
    LUser := FRepository.LockUser(LActor.UserInternalID);
    try
      if LUser.FieldByName('password_hash').AsString <> LHash then raise EAuthPolicy.Create(401, 'Invalid credential.');
    finally
      FreeAndNil(LUser);
    end;
    LActor := Actor;
    FRepository.LockSession(LActor.SessionInternalID);
    FRepository.MarkReauthenticated(LActor.SessionInternalID);
    FRepository.Audit('reauthenticate', 'success', LActor, LActor.UserID, TAuthValidator.Origin(FRequest));
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  Result := Reply;
end;

function TAuthService.ChangePassword: string;
var LActor: TAuthActor; LBody: TJSONObject; LOld, LNew, LHash, LNewHash: string; LUser: TFDQuery;
begin
  LActor := FRepository.ResolveActor(Access);
  LBody := THelperRequest.JSONObject(FRequest, ['old_password','new_password']);
  try
    LOld := THelperRequest.JSONString(LBody, 'old_password', True, 128);
    LNew := THelperRequest.JSONString(LBody, 'new_password', True, 128);
    TAuthValidator.Password(LOld, False);
    TAuthValidator.Password(LNew, True);
  finally
    FreeAndNil(LBody);
  end;
  Throttle(LActor.Username);
  LHash := FRepository.PasswordHash(LActor.UserInternalID);
  if not Verify(LOld, LHash) then raise EAuthPolicy.Create(401, 'Invalid credential.');
  if LOld = LNew then raise ERequestInvalid.Create('New password must be different.');
  LNewHash := Hash(LNew);
  FRepository.BeginSecurityTransaction;
  try
    LUser := FRepository.LockUser(LActor.UserInternalID);
    try
      if LUser.FieldByName('password_hash').AsString <> LHash then raise EAuthPolicy.Create(401, 'Invalid credential.');
    finally
      FreeAndNil(LUser);
    end;
    LActor := FRepository.ResolveActor(Access);
    FRepository.SetPassword(LActor.UserInternalID, LNewHash);
    FRepository.RevokeUser(LActor.UserInternalID, 'password_change');
    FRepository.RevokeRecovery(LActor.UserInternalID, 'password_change');
    FRepository.Audit('password_change', 'success', LActor, LActor.UserID, TAuthValidator.Origin(FRequest));
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  Result := Reply;
end;

function TAuthService.CompletePasswordReset: string;
var LBody: TJSONObject; LToken, LNew, LHash, LNewHash: string; LQuery, LUser: TFDQuery; LUserID, LTokenID: Int64;
  LActor: TAuthActor;
begin
  LBody := THelperRequest.JSONObject(FRequest, ['reset_token','new_password']);
  try
    LToken := THelperRequest.JSONString(LBody, 'reset_token', True, 43);
    LNew := THelperRequest.JSONString(LBody, 'new_password', True, 128);
    TAuthValidator.Password(LNew, True);
  finally
    FreeAndNil(LBody);
  end;
  LHash := TSecurityCrypto.TokenHash(LToken);
  Throttle('recovery:' + LHash);
  if LHash = '' then raise EAuthPolicy.Create(401, 'Invalid credential.');
  LQuery := FRepository.FindRecovery(LHash);
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(401, 'Invalid credential.');
    LTokenID := LQuery.FieldByName('id').AsLargeInt;
    LUserID := LQuery.FieldByName('user_internal_id').AsLargeInt;
  finally
    FreeAndNil(LQuery);
  end;
  LNewHash := Hash(LNew);
  FRepository.BeginSecurityTransaction;
  try
    LUser := FRepository.LockUser(LUserID);
    try
      if LUser.IsEmpty or not LUser.FieldByName('is_active').AsBoolean or not LUser.FieldByName('deleted_at').IsNull then
        raise EAuthPolicy.Create(401, 'Invalid credential.');
      LActor := Default(TAuthActor);
      LActor.UserID := LUser.FieldByName('user_id').AsString;
    finally
      FreeAndNil(LUser);
    end;
    FRepository.RevokeUser(LUserID, 'password_recovery');
    LQuery := FRepository.LockRecovery(LTokenID);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(401, 'Invalid credential.');
    finally
      FreeAndNil(LQuery);
    end;
    FRepository.ConsumeRecovery(LTokenID);
    FRepository.SetPassword(LUserID, LNewHash);
    FRepository.RevokeRecovery(LUserID, 'password_recovery');
    FRepository.Audit('password_recovery', 'success', LActor, LActor.UserID, TAuthValidator.Origin(FRequest));
    FRepository.Commit;
  except
    FRepository.Rollback;
    raise;
  end;
  Result := Reply;
end;

end.
