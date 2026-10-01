unit User.Repository;

interface

uses System.JSON, FireDAC.Comp.Client, Auth.Repository, User.DTO;

type
  TUserRepository = class(TAuthRepository)
  public
    function FindUserByID(const AUserID: string): TFDQuery;
    function GetUsers(const AUserID: string; ALimit, AOffset: Integer): TJSONArray;
    function CreateUser(const AUserID: string; const ARequest: TUserCreateRequest; const AHash: string): Int64;
    procedure UpdateUser(const ARequest: TUserUpdateRequest);
    procedure SoftDeleteUser(AID: Int64);
  end;

implementation

uses System.SysUtils, System.Variants, Auth.Policy;

function TUserRepository.FindUserByID(const AUserID: string): TFDQuery;
begin
  Result := Query('SELECT * FROM users WHERE user_id=:id AND deleted_at IS NULL', ['id', AUserID]);
end;

function TUserRepository.GetUsers(const AUserID: string; ALimit, AOffset: Integer): TJSONArray;
begin
  Result := JSONRows('SELECT u.user_id,u.username,u.fullname,u.is_active,u.role_internal_id AS role_id,'
    + 'u.must_change_password,r.role_code FROM users u LEFT JOIN m_role r ON r.id=u.role_internal_id '
    + 'WHERE u.deleted_at IS NULL AND (:uid='''' OR u.user_id=:uid) ORDER BY u.id LIMIT :lim OFFSET :off',
    ['uid', AUserID, 'lim', ALimit, 'off', AOffset]);
end;

function TUserRepository.CreateUser(const AUserID: string; const ARequest: TUserCreateRequest; const AHash: string): Int64;
var LRole: Variant; LQuery: TFDQuery;
begin
  LRole := Null;
  if ARequest.RoleID > 0 then LRole := ARequest.RoleID;
  Execute('INSERT INTO users(user_id,username,password_hash,fullname,is_active,role_internal_id,must_change_password) '
    + 'VALUES(:uid,:username,:hash,:name,:active,:role,1)', ['uid', AUserID, 'username', ARequest.Username,
    'hash', AHash, 'name', ARequest.Fullname, 'active', ARequest.IsActive, 'role', LRole]);
  LQuery := Query('SELECT LAST_INSERT_ID()', []);
  try
    Result := LQuery.Fields[0].AsLargeInt;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TUserRepository.UpdateUser(const ARequest: TUserUpdateRequest);
var LRole: Variant; LRows: Integer;
begin
  if ARequest.HasFullname then begin
    LRows := Execute('UPDATE users SET fullname=:value WHERE user_id=:id',
    ['value', ARequest.Fullname, 'id', ARequest.UserID]);
    if (LRows < 0) or (LRows > 1) then raise EAuthPolicy.Create(409, 'Mutation conflict.');
  end;
  if ARequest.HasIsActive then begin
    LRows := Execute('UPDATE users SET is_active=:value WHERE user_id=:id',
    ['value', ARequest.IsActive, 'id', ARequest.UserID]);
    if (LRows < 0) or (LRows > 1) then raise EAuthPolicy.Create(409, 'Mutation conflict.');
  end;
  if ARequest.HasRoleID then begin
    LRole := Null;
    if ARequest.RoleID > 0 then LRole := ARequest.RoleID;
    LRows := Execute('UPDATE users SET role_internal_id=:value WHERE user_id=:id', ['value', LRole, 'id', ARequest.UserID]);
    if (LRows < 0) or (LRows > 1) then raise EAuthPolicy.Create(409, 'Mutation conflict.');
  end;
end;

procedure TUserRepository.SoftDeleteUser(AID: Int64);
begin
  if Execute('UPDATE users SET deleted_at=UTC_TIMESTAMP(6),is_active=0 WHERE id=:id AND deleted_at IS NULL', ['id', AID]) <> 1 then raise EAuthPolicy.Create(409, 'Mutation conflict.');
end;

end.
