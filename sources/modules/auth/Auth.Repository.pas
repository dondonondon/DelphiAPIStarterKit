unit Auth.Repository;

interface

uses System.SysUtils, System.Variants, System.JSON, Data.DB, FireDAC.Comp.Client, Auth.Policy;

type
  TAuthRepository = class
  private
    FConnection: TFDConnection;
    procedure Bind(AQuery: TFDQuery; const AParams: array of Variant);
  public
    constructor Create(AConnection: TFDConnection);
    function Query(const ASQL: string; const AParams: array of Variant): TFDQuery;
    function Execute(const ASQL: string; const AParams: array of Variant): Integer;
    procedure BeginSecurityTransaction;
    procedure BeginAuthorizedTransaction(const AToken, APermission: string);
    procedure Commit;
    procedure Rollback;
    function ResolveActor(const AToken: string): TAuthActor;
    function FindUserForLogin(const AUsername: string): TFDQuery;
    function PasswordHash(AUserID: Int64): string;
    function FindRefresh(const AHash: string): TFDQuery;
    function RefreshState(AID: Int64): TFDQuery;
    function FindCredentialSession(const AHash: string; ARefresh: Boolean): TFDQuery;
    function OwnedSessions(AUserID: Int64; ALimit, AOffset: Integer): TJSONArray;
    function FindOwnedSession(AUserID: Int64; const ASessionID: string): TFDQuery;
    function FindRecovery(const AHash: string): TFDQuery;
    function LockRecovery(AID: Int64): TFDQuery;
    procedure RehashPassword(AUserID: Int64; const AHash: string);
    procedure RotateSession(AID: Int64);
    procedure ConsumeRefresh(AID, ANewID: Int64);
    procedure ConsumeRecovery(AID: Int64);
    procedure SetPassword(AUserID: Int64; const AHash: string);
    procedure MarkReauthenticated(ASessionID: Int64);
    function LockUser(AID: Int64): TFDQuery;
    procedure LockSession(AID: Int64);
    procedure RevokeSession(AID: Int64; const AReason: string);
    procedure RevokeUser(AID: Int64; const AReason: string);
    procedure RevokeRecovery(AID: Int64; const AReason: string);
    function Permissions(ARoleID: Integer): TArray<string>;
    procedure RequireDelegation(const AActor: TAuthActor; ARoleID: Integer);
    procedure ValidateRoleReference(ARoleID: Integer);
    procedure RequireTarget(const AActor: TAuthActor; AUserID: Int64; ARoleID: Integer);
    procedure ProtectLastAdmin;
    procedure Audit(const AEvent, AOutcome: string; const AActor: TAuthActor; const ATarget, AIP: string; const ATargetRole: string = '');
    function Admit(const AAccount, AOrigin: string): Boolean;
    function AcquireKDF: string;
    procedure ReleaseKDF(const ASlot: string);
    function CreateSession(AUserID: Int64; const ASessionID, ADeviceID, ADeviceName, AAgent, AIP: string;
      ARestricted: Boolean): Int64;
    procedure IssueTokens(ASessionID: Int64; const AAccess, ARefresh: string; ARestricted: Boolean;
      out AAccessTTL, ARefreshTTL: Integer; out ARefreshID: Int64);
    function RecoveryToken(AUserID, AIssuer: Int64; const APurpose, AToken: string): Integer;
    function JSONRows(const ASQL: string; const AParams: array of Variant): TJSONArray;
    procedure Cleanup(ABatch: Integer);
  end;

implementation

uses System.Classes, System.Hash, FireDAC.Stan.Param, FireDAC.Stan.Option, BFA.Security.Crypto,
  BFA.Helper.Strings, BFA.Core.Response, Auth.Settings, BFA.Helper.Transaction, BFA.Logger, System.RegularExpressions, System.StrUtils;

function NullableText(const AText: string): Variant;
begin
  if AText = '' then Result := Null else Result := AText;
end;

constructor TAuthRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  if not Assigned(AConnection) then raise Exception.Create('Database connection unavailable.');
  FConnection := AConnection;
end;

procedure TAuthRepository.Bind(AQuery: TFDQuery; const AParams: array of Variant);
var I: Integer;
begin
  if Length(AParams) mod 2 <> 0 then raise Exception.Create('Invalid repository parameters.');
  I := 0;
  while I < Length(AParams) do begin
    if VarIsNull(AParams[I + 1]) then begin
      AQuery.ParamByName(string(AParams[I])).DataType := ftWideString;
      AQuery.ParamByName(string(AParams[I])).Clear;
    end else if (VarType(AParams[I + 1]) = varString) or (VarType(AParams[I + 1]) = varOleStr) or
      (VarType(AParams[I + 1]) = varUString) then
      AQuery.ParamByName(string(AParams[I])).AsWideString := VarToStr(AParams[I + 1])
    else AQuery.ParamByName(string(AParams[I])).Value := AParams[I + 1];
    Inc(I, 2);
  end;
end;

function TAuthRepository.Query(const ASQL: string; const AParams: array of Variant): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := FConnection;
    Result.FetchOptions.Mode := fmAll;
    Result.SQL.Text := ASQL;
    Bind(Result, AParams);
    Result.Open;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TAuthRepository.Execute(const ASQL: string; const AParams: array of Variant): Integer;
var LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := ASQL;
    Bind(LQuery, AParams);
    LQuery.ExecSQL;
    Result := LQuery.RowsAffected;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TAuthRepository.BeginSecurityTransaction;
var LQuery: TFDQuery;
begin
  FConnection.StartTransaction;
  try
    LQuery := Query('SELECT id FROM m_permission WHERE permission_code=''users.assign_role'' FOR UPDATE', []);
    try
      if LQuery.IsEmpty then raise Exception.Create('Auth policy catalog is not provisioned.');
    finally
      FreeAndNil(LQuery);
    end;
  except
    Rollback;
    raise;
  end;
end;

procedure TAuthRepository.BeginAuthorizedTransaction(const AToken, APermission: string);
var LActor: TAuthActor;
begin
  BeginSecurityTransaction;
  try
    LActor := ResolveActor(AToken);
    if LActor.Restricted then raise EAuthPolicy.Create(403, 'Password change required.');
    LActor.RequirePermission(APermission);
  except
    Rollback;
    raise;
  end;
end;

procedure TAuthRepository.Commit;
begin
  FConnection.Commit;
end;

procedure TAuthRepository.Rollback;
begin
  THelperTransaction.Rollback(FConnection);
end;

function TAuthRepository.Permissions(ARoleID: Integer): TArray<string>;
var LQuery: TFDQuery; LCount: Integer;
begin
  Result := nil;
  LQuery := Query('SELECT p.permission_code FROM m_permission p JOIN role_permission rp ON rp.permission_internal_id=p.id '
    + 'JOIN m_role r ON r.id=rp.role_internal_id WHERE r.id=:rid AND r.is_active=1 AND r.deleted_at IS NULL '
    + 'AND p.is_active=1 ORDER BY p.permission_code LIMIT 101', ['rid', ARoleID]);
  try
    while not LQuery.Eof do begin
      LCount := Length(Result);
      if LCount >= 100 then raise EAuthPolicy.Create(403, 'Permission catalog exceeds limit.');
      SetLength(Result, LCount + 1);
      Result[LCount] := LQuery.Fields[0].AsString;
      LQuery.Next;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TAuthRepository.ResolveActor(const AToken: string): TAuthActor;
var LQuery: TFDQuery; LHash: string; LCount: Integer;
begin
  Result := Default(TAuthActor);
  LHash := TSecurityCrypto.TokenHash(AToken);
  if LHash = '' then raise EAuthPolicy.Create(401, 'Invalid credential.');
  LQuery := Query('SELECT u.id,u.user_id,u.username,u.fullname,u.role_internal_id,u.must_change_password,'
    + 's.id AS sid,s.session_id,r.role_code,p.permission_code,'
    + 's.authenticated_at>=TIMESTAMPADD(SECOND,-:recent,UTC_TIMESTAMP(6)) AS recent '
    + 'FROM access_token a JOIN user_session s ON s.id=a.session_internal_id JOIN users u ON u.id=s.user_internal_id '
    + 'LEFT JOIN m_role r ON r.id=u.role_internal_id AND r.is_active=1 AND r.deleted_at IS NULL '
    + 'LEFT JOIN role_permission rp ON rp.role_internal_id=r.id '
    + 'LEFT JOIN m_permission p ON p.id=rp.permission_internal_id AND p.is_active=1 '
    + 'WHERE a.token_hash=:hash AND a.revoked=0 AND a.deleted_at IS NULL AND a.expires_at>UTC_TIMESTAMP(6) '
    + 'AND s.revoked=0 AND s.deleted_at IS NULL AND s.expires_at>UTC_TIMESTAMP(6) AND s.idle_expires_at>UTC_TIMESTAMP(6) '
    + 'AND u.is_active=1 AND u.deleted_at IS NULL ORDER BY p.permission_code LIMIT 101', ['recent', TAuthSettings.RecentSeconds, 'hash', LHash]);
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(401, 'Invalid credential.');
    Result.UserInternalID := LQuery.FieldByName('id').AsLargeInt;
    Result.UserID := LQuery.FieldByName('user_id').AsString;
    Result.Username := LQuery.FieldByName('username').AsString;
    Result.Fullname := LQuery.FieldByName('fullname').AsString;
    Result.RoleID := LQuery.FieldByName('role_internal_id').AsInteger;
    Result.RoleCode := LQuery.FieldByName('role_code').AsString;
    Result.SessionInternalID := LQuery.FieldByName('sid').AsLargeInt;
    Result.SessionID := LQuery.FieldByName('session_id').AsString;
    Result.Restricted := LQuery.FieldByName('must_change_password').AsBoolean;
    Result.Recent := LQuery.FieldByName('recent').AsInteger <> 0;
    while not LQuery.Eof do begin
      if not LQuery.FieldByName('permission_code').IsNull then begin
        LCount := Length(Result.Permissions);
        if LCount >= 100 then raise EAuthPolicy.Create(403, 'Permission catalog exceeds limit.');
        SetLength(Result.Permissions, LCount + 1);
        Result.Permissions[LCount] := LQuery.FieldByName('permission_code').AsString;
      end;
      LQuery.Next;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TAuthRepository.FindUserForLogin(const AUsername: string): TFDQuery;
begin
  Result := Query('SELECT * FROM users WHERE username=:username', ['username', AUsername]);
end;

function TAuthRepository.PasswordHash(AUserID: Int64): string;
var LQuery: TFDQuery;
begin
  LQuery := Query('SELECT password_hash FROM users WHERE id=:id', ['id', AUserID]);
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(401, 'Invalid credential.');
    Result := LQuery.Fields[0].AsString;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TAuthRepository.FindRefresh(const AHash: string): TFDQuery;
begin
  Result := Query('SELECT r.id,r.session_internal_id,s.user_internal_id,u.username FROM refresh_token r '
    + 'JOIN user_session s ON s.id=r.session_internal_id JOIN users u ON u.id=s.user_internal_id '
    + 'WHERE r.token_hash=:hash', ['hash', AHash]);
end;

function TAuthRepository.RefreshState(AID: Int64): TFDQuery;
begin
  Result := Query('SELECT r.consumed_at,r.revoked,s.session_id,'
    + '(r.expires_at>UTC_TIMESTAMP(6) AND s.expires_at>UTC_TIMESTAMP(6) AND s.idle_expires_at>UTC_TIMESTAMP(6) '
    + 'AND s.revoked=0 AND s.deleted_at IS NULL) AS valid FROM refresh_token r '
    + 'JOIN user_session s ON s.id=r.session_internal_id WHERE r.id=:id FOR UPDATE', ['id', AID]);
end;

function TAuthRepository.FindCredentialSession(const AHash: string; ARefresh: Boolean): TFDQuery;
var LTable: string;
begin
  if ARefresh then LTable := 'refresh_token' else LTable := 'access_token';
  Result := Query('SELECT t.session_internal_id,s.user_internal_id FROM ' + LTable
    + ' t JOIN user_session s ON s.id=t.session_internal_id WHERE t.token_hash=:hash', ['hash', AHash]);
end;

function TAuthRepository.OwnedSessions(AUserID: Int64; ALimit, AOffset: Integer): TJSONArray;
begin
  Result := JSONRows('SELECT session_id,device_id,device_name,user_agent,ip_address,authenticated_at,'
    + 'last_seen_at,idle_expires_at,expires_at,revoked,revoked_at,revocation_reason FROM user_session '
    + 'WHERE user_internal_id=:user AND deleted_at IS NULL ORDER BY id DESC LIMIT :lim OFFSET :off',
    ['user', AUserID, 'lim', ALimit, 'off', AOffset]);
end;

function TAuthRepository.FindOwnedSession(AUserID: Int64; const ASessionID: string): TFDQuery;
begin
  Result := Query('SELECT id FROM user_session WHERE session_id=:sid AND user_internal_id=:user '
    + 'AND deleted_at IS NULL FOR UPDATE', ['sid', ASessionID, 'user', AUserID]);
end;

function TAuthRepository.FindRecovery(const AHash: string): TFDQuery;
begin
  Result := Query('SELECT id,user_internal_id FROM password_reset_token '
    + 'WHERE token_hash=:hash AND revoked=0 AND consumed_at IS NULL AND expires_at>UTC_TIMESTAMP(6)', ['hash', AHash]);
end;

function TAuthRepository.LockRecovery(AID: Int64): TFDQuery;
begin
  Result := Query('SELECT id FROM password_reset_token WHERE id=:id AND revoked=0 AND consumed_at IS NULL '
    + 'AND purpose IN (''password_reset'',''account_setup'') AND expires_at>UTC_TIMESTAMP(6) FOR UPDATE', ['id', AID]);
end;

procedure TAuthRepository.RehashPassword(AUserID: Int64; const AHash: string);
begin
  Execute('UPDATE users SET password_hash=:hash WHERE id=:id', ['hash', AHash, 'id', AUserID]);
end;

procedure TAuthRepository.RotateSession(AID: Int64);
begin
  Execute('UPDATE user_session SET last_seen_at=UTC_TIMESTAMP(6),'
    + 'idle_expires_at=LEAST(expires_at,TIMESTAMPADD(SECOND,:idle,UTC_TIMESTAMP(6))) WHERE id=:id',
    ['idle', TAuthSettings.IdleSeconds, 'id', AID]);
  Execute('UPDATE access_token SET revoked=1,revoked_at=UTC_TIMESTAMP(6),revocation_reason=''refresh_rotation'' '
    + 'WHERE session_internal_id=:id AND revoked=0', ['id', AID]);
end;

procedure TAuthRepository.ConsumeRefresh(AID, ANewID: Int64);
begin
  if Execute('UPDATE refresh_token SET consumed_at=UTC_TIMESTAMP(6),replaced_by_internal_id=:new '
    + 'WHERE id=:id AND consumed_at IS NULL AND revoked=0', ['new', ANewID, 'id', AID]) <> 1 then
    raise EAuthPolicy.Create(401, 'Invalid credential.');
end;

procedure TAuthRepository.ConsumeRecovery(AID: Int64);
begin
  if Execute('UPDATE password_reset_token SET consumed_at=UTC_TIMESTAMP(6) WHERE id=:id '
    + 'AND consumed_at IS NULL AND revoked=0', ['id', AID]) <> 1 then raise EAuthPolicy.Create(401, 'Invalid credential.');
end;

procedure TAuthRepository.SetPassword(AUserID: Int64; const AHash: string);
begin
  if Execute('UPDATE users SET password_hash=:hash,must_change_password=0,password_changed_at=UTC_TIMESTAMP(6) '
    + 'WHERE id=:id AND is_active=1 AND deleted_at IS NULL', ['hash', AHash, 'id', AUserID]) <> 1 then
    raise EAuthPolicy.Create(401, 'Invalid credential.');
end;

procedure TAuthRepository.MarkReauthenticated(ASessionID: Int64);
begin
  Execute('UPDATE user_session SET authenticated_at=UTC_TIMESTAMP(6) WHERE id=:id', ['id', ASessionID]);
end;

function TAuthRepository.LockUser(AID: Int64): TFDQuery;
begin
  Result := Query('SELECT * FROM users WHERE id=:id FOR UPDATE', ['id', AID]);
end;

procedure TAuthRepository.LockSession(AID: Int64);
var LQuery: TFDQuery;
begin
  LQuery := Query('SELECT id FROM user_session WHERE id=:id FOR UPDATE', ['id', AID]);
  FreeAndNil(LQuery);
end;

procedure TAuthRepository.RevokeSession(AID: Int64; const AReason: string);
begin
  Execute('UPDATE user_session SET revoked=1,revoked_at=UTC_TIMESTAMP(6),revocation_reason=:reason '
    + 'WHERE id=:id AND revoked=0', ['reason', AReason, 'id', AID]);
  Execute('UPDATE access_token SET revoked=1,revoked_at=UTC_TIMESTAMP(6),revocation_reason=:reason '
    + 'WHERE session_internal_id=:id AND revoked=0', ['reason', AReason, 'id', AID]);
  Execute('UPDATE refresh_token SET revoked=1,revoked_at=UTC_TIMESTAMP(6),revocation_reason=:reason '
    + 'WHERE session_internal_id=:id AND revoked=0', ['reason', AReason, 'id', AID]);
end;

procedure TAuthRepository.RevokeUser(AID: Int64; const AReason: string);
var LQuery: TFDQuery;
begin
  LQuery := Query('SELECT id FROM user_session WHERE user_internal_id=:id ORDER BY id FOR UPDATE', ['id', AID]);
  try
    while not LQuery.Eof do begin
      RevokeSession(LQuery.Fields[0].AsLargeInt, AReason);
      LQuery.Next;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TAuthRepository.RevokeRecovery(AID: Int64; const AReason: string);
begin
  Execute('UPDATE password_reset_token SET revoked=1,revoked_at=UTC_TIMESTAMP(6),revocation_reason=:reason '
    + 'WHERE user_internal_id=:id AND revoked=0', ['reason', AReason, 'id', AID]);
end;

procedure TAuthRepository.ValidateRoleReference(ARoleID: Integer);
var LQuery: TFDQuery;
begin
  if ARoleID = 0 then Exit;
  if ARoleID < 0 then raise EAuthPolicy.Create(400, 'Invalid role_id.');
  LQuery := Query('SELECT id FROM m_role WHERE id=:id AND is_active=1 AND deleted_at IS NULL FOR UPDATE', ['id', ARoleID]);
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(400, 'Invalid role_id.');
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TAuthRepository.RequireDelegation(const AActor: TAuthActor; ARoleID: Integer);
var LCode: string;
begin
  if ARoleID = 0 then Exit;
  AActor.RequirePermission('users.assign_role');
  ValidateRoleReference(ARoleID);
  for LCode in Permissions(ARoleID) do
    if not AActor.HasPermission(LCode) then raise EAuthPolicy.Create(403, 'Delegation denied.');
end;

procedure TAuthRepository.RequireTarget(const AActor: TAuthActor; AUserID: Int64; ARoleID: Integer);
var LCode: string;
begin
  if AUserID = AActor.UserInternalID then raise EAuthPolicy.Create(403, 'Administrative self mutation denied.');
  for LCode in Permissions(ARoleID) do
    if not AActor.HasPermission(LCode) then raise EAuthPolicy.Create(403, 'Target delegation denied.');
end;

procedure TAuthRepository.ProtectLastAdmin;
var LQuery: TFDQuery;
begin
  LQuery := Query('SELECT COUNT(*) FROM users u JOIN m_role r ON r.id=u.role_internal_id '
    + 'WHERE u.is_active=1 AND u.deleted_at IS NULL AND u.must_change_password=0 AND r.is_active=1 AND r.deleted_at IS NULL '
    + 'AND (SELECT COUNT(*) FROM role_permission rp JOIN m_permission p ON p.id=rp.permission_internal_id '
    + 'WHERE rp.role_internal_id=r.id AND p.is_active=1 AND p.permission_code IN '
    + '(''roles.manage'',''users.assign_role'',''users.create'',''users.update'',''users.delete'',''users.read'',''users.reset_password''))=7', []);
  try
    if LQuery.Fields[0].AsInteger = 0 then raise EAuthPolicy.Create(409, 'Last administrator must remain active.');
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TAuthRepository.Audit(const AEvent, AOutcome: string; const AActor: TAuthActor; const ATarget, AIP: string; const ATargetRole: string);
var LValue: string;
begin
  if not MatchText(AEvent, ['bootstrap_admin','login','refresh','refresh_reuse','logout','logout_all','session_revoke',
    'reauthenticate','password_change','password_reset_issue','password_recovery','user_create','user_update','user_delete',
    'role_permissions_change','authorization_denied']) or
    not MatchText(AOutcome, ['success','denied','failure']) then raise Exception.Create('Invalid security audit event.');
  for LValue in [AActor.UserID, ATarget, ATargetRole, AActor.SessionID] do begin
    if (LValue <> '') and not TRegEx.IsMatch(LValue,
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
      raise Exception.Create('Invalid security audit identifier.');
  end;
  if (Length(AIP) > 45) or ((AIP <> '') and not TRegEx.IsMatch(AIP, '^[0-9a-fA-F:.]+$')) then
    raise Exception.Create('Invalid observed origin.');
  Execute('INSERT INTO auth_security_event(event_code,outcome,actor_user_id,target_user_id,target_role_id,session_id,correlation_id,'
    + 'observed_ip_address) VALUES(:event,:outcome,:actor,:target,:role,:session,:correlation,:ip)',
    ['event', AEvent, 'outcome', AOutcome, 'actor', NullableText(AActor.UserID), 'target', NullableText(ATarget),
    'role', NullableText(ATargetRole), 'session', NullableText(AActor.SessionID), 'correlation', THelperLogger.CorrelationID,
    'ip', NullableText(AIP)]);
end;

function TAuthRepository.Admit(const AAccount, AOrigin: string): Boolean;
var LKeys: TArray<string>; LLimits: TArray<Integer>; I: Integer; LQuery: TFDQuery; LHash: string;
begin
  Result := True;
  LKeys := ['global', 'origin:' + AOrigin, 'account:' + LowerCase(AAccount)];
  LLimits := [TAuthSettings.GlobalLimit, TAuthSettings.OriginLimit, TAuthSettings.AccountLimit];
  FConnection.StartTransaction;
  try
    for I := 0 to 2 do begin
      LHash := LowerCase(THashSHA2.GetHashString(LKeys[I]));
      Execute('INSERT INTO auth_rate_limit(bucket_hash,window_start,attempts) VALUES(:hash,FLOOR(UNIX_TIMESTAMP()/60),1) '
        + 'ON DUPLICATE KEY UPDATE attempts=IF(window_start=FLOOR(UNIX_TIMESTAMP()/60),LEAST(attempts+1,100000),1),'
        + 'window_start=FLOOR(UNIX_TIMESTAMP()/60)', ['hash', LHash]);
      LQuery := Query('SELECT attempts FROM auth_rate_limit WHERE bucket_hash=:hash', ['hash', LHash]);
      try
        if LQuery.Fields[0].AsInteger > LLimits[I] then Result := False;
      finally
        FreeAndNil(LQuery);
      end;
    end;
    Execute('DELETE FROM auth_rate_limit WHERE window_start<FLOOR(UNIX_TIMESTAMP()/60)-2 LIMIT 100', []);
    Commit;
  except
    Rollback;
    raise;
  end;
end;

function TAuthRepository.AcquireKDF: string;
var I: Integer; LQuery: TFDQuery;
begin
  Result := '';
  for I := 0 to TAuthSettings.AdmissionLimit - 1 do begin
    LQuery := Query('SELECT GET_LOCK(:name,0)', ['name', 'delphi.auth.kdf.' + IntToStr(I)]);
    try
      if LQuery.Fields[0].AsInteger = 1 then Exit('delphi.auth.kdf.' + IntToStr(I));
    finally
      FreeAndNil(LQuery);
    end;
  end;
  raise EAuthPolicy.Create(429, 'Authentication rate limit exceeded.');
end;

procedure TAuthRepository.ReleaseKDF(const ASlot: string);
var LQuery: TFDQuery;
begin
  if ASlot = '' then Exit;
  LQuery := Query('SELECT RELEASE_LOCK(:name)', ['name', ASlot]);
  FreeAndNil(LQuery);
end;

function TAuthRepository.CreateSession(AUserID: Int64; const ASessionID, ADeviceID, ADeviceName, AAgent, AIP: string;
  ARestricted: Boolean): Int64;
var LAbsolute, LIdle: Integer; LQuery: TFDQuery;
begin
  LAbsolute := TAuthSettings.AbsoluteSeconds;
  LIdle := TAuthSettings.IdleSeconds;
  if ARestricted then begin
    LAbsolute := 900;
    LIdle := 900;
  end;
  Execute('INSERT INTO user_session(session_id,user_internal_id,device_id,device_name,user_agent,ip_address,'
    + 'idle_expires_at,expires_at) VALUES(:session,:user,:device,:name,:agent,:ip,'
    + 'TIMESTAMPADD(SECOND,:idle,UTC_TIMESTAMP(6)),TIMESTAMPADD(SECOND,:absolute,UTC_TIMESTAMP(6)))',
    ['session', ASessionID, 'user', AUserID, 'device', ADeviceID, 'name', ADeviceName, 'agent', AAgent,
    'ip', AIP, 'idle', LIdle, 'absolute', LAbsolute]);
  LQuery := Query('SELECT LAST_INSERT_ID()', []);
  try
    Result := LQuery.Fields[0].AsLargeInt;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TAuthRepository.IssueTokens(ASessionID: Int64; const AAccess, ARefresh: string; ARestricted: Boolean;
  out AAccessTTL, ARefreshTTL: Integer; out ARefreshID: Int64);
var LQuery: TFDQuery;
begin
  LQuery := Query('SELECT FLOOR(TIMESTAMPDIFF(MICROSECOND,UTC_TIMESTAMP(6),LEAST(expires_at,idle_expires_at))/1000000) '
    + 'FROM user_session WHERE id=:id', ['id', ASessionID]);
  try
    ARefreshTTL := LQuery.Fields[0].AsInteger;
    if ARefreshTTL <= 0 then raise EAuthPolicy.Create(401, 'Invalid credential.');
    AAccessTTL := ARefreshTTL;
    if AAccessTTL > TAuthSettings.AccessSeconds then AAccessTTL := TAuthSettings.AccessSeconds;
  finally
    FreeAndNil(LQuery);
  end;
  Execute('INSERT INTO access_token(token_hash,session_internal_id,expires_at) '
    + 'VALUES(:hash,:session,TIMESTAMPADD(SECOND,:ttl,UTC_TIMESTAMP(6)))',
    ['hash', TSecurityCrypto.TokenHash(AAccess), 'session', ASessionID, 'ttl', AAccessTTL]);
  ARefreshID := 0;
  if ARestricted then begin
    ARefreshTTL := 0;
    Exit;
  end;
  Execute('INSERT INTO refresh_token(token_hash,session_internal_id,expires_at) '
    + 'VALUES(:hash,:session,TIMESTAMPADD(SECOND,:ttl,UTC_TIMESTAMP(6)))',
    ['hash', TSecurityCrypto.TokenHash(ARefresh), 'session', ASessionID, 'ttl', ARefreshTTL]);
  LQuery := Query('SELECT LAST_INSERT_ID()', []);
  try
    ARefreshID := LQuery.Fields[0].AsLargeInt;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TAuthRepository.RecoveryToken(AUserID, AIssuer: Int64; const APurpose, AToken: string): Integer;
begin
  Execute('UPDATE password_reset_token SET revoked=1,revoked_at=UTC_TIMESTAMP(6),revocation_reason=''superseded'' '
    + 'WHERE user_internal_id=:user AND purpose=:purpose AND revoked=0 AND consumed_at IS NULL',
    ['user', AUserID, 'purpose', APurpose]);
  Execute('INSERT INTO password_reset_token(token_hash,user_internal_id,issued_by_user_internal_id,purpose,expires_at) '
    + 'VALUES(:hash,:user,:issuer,:purpose,TIMESTAMPADD(SECOND,:ttl,UTC_TIMESTAMP(6)))',
    ['hash', TSecurityCrypto.TokenHash(AToken), 'user', AUserID, 'issuer', AIssuer,
    'purpose', APurpose, 'ttl', TAuthSettings.RecoverySeconds]);
  Result := TAuthSettings.RecoverySeconds;
end;

function TAuthRepository.JSONRows(const ASQL: string; const AParams: array of Variant): TJSONArray;
var LQuery: TFDQuery; LRow: TJSONObject; LField: TField;
begin
  Result := TJSONArray.Create;
  try
    LQuery := Query(ASQL, AParams);
    try
      while not LQuery.Eof do begin
        LRow := TJSONObject.Create;
        Result.AddElement(LRow);
        for LField in LQuery.Fields do LRow.AddPair(LField.FieldName, THelperResponse.FieldValue(LField));
        LQuery.Next;
      end;
    finally
      FreeAndNil(LQuery);
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TAuthRepository.Cleanup(ABatch: Integer);
var LQuery, LLocked: TFDQuery; LUser, LSession: Int64;
begin
  if (ABatch < 1) or (ABatch > 100) then raise EAuthPolicy.Create(400, 'Invalid maintenance batch.');
  BeginSecurityTransaction;
  try
    LQuery := Query('SELECT id,user_internal_id FROM user_session '
      + 'WHERE expires_at<TIMESTAMPADD(DAY,-7,UTC_TIMESTAMP(6)) ORDER BY expires_at,id LIMIT :batch', ['batch', ABatch]);
    try
      while not LQuery.Eof do begin
        LSession := LQuery.FieldByName('id').AsLargeInt;
        LUser := LQuery.FieldByName('user_internal_id').AsLargeInt;
        LLocked := LockUser(LUser);
        FreeAndNil(LLocked);
        LockSession(LSession);
        Execute('UPDATE refresh_token SET replaced_by_internal_id=NULL WHERE session_internal_id=:id', ['id', LSession]);
        Execute('DELETE FROM refresh_token WHERE session_internal_id=:id', ['id', LSession]);
        Execute('DELETE FROM access_token WHERE session_internal_id=:id', ['id', LSession]);
        Execute('DELETE FROM user_session WHERE id=:id', ['id', LSession]);
        LQuery.Next;
      end;
    finally
      FreeAndNil(LQuery);
    end;
    Execute('DELETE FROM password_reset_token WHERE expires_at<TIMESTAMPADD(DAY,-7,UTC_TIMESTAMP(6)) LIMIT :batch',
      ['batch', ABatch]);
    Commit;
  except
    Rollback;
    raise;
  end;
end;

end.
