unit User.Repository;

interface

uses
  Data.DB,
  FireDAC.Comp.Client,
  User.DTO;

type
  TUserRepository = class
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);

    function FindActiveUserByID(const AUserID: string): TFDQuery;
    function FindAuthUserByTokenHash(const ATokenHash: string): TFDQuery;
    function FindUserByID(const AUserID: string): TFDQuery;
    function FindUserByUsername(const AUsername: string): TFDQuery;
    function GetUsers(const AUserID: string = ''): TFDQuery;

    function CreateUser(const AUserID: string;
      const ARequest: TUserCreateRequest; const APasswordHash: string): Integer;
    function SoftDeleteUser(const AUserID: string): Integer;
    function UpdatePassword(const AUserID, APasswordHash: string): Integer;
    function UpdateUser(const ARequest: TUserUpdateRequest;
      const APasswordHash: string): Integer;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  DB.Helper.Query;

constructor TUserRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TUserRepository.CreateUser(const AUserID: string;
  const ARequest: TUserCreateRequest; const APasswordHash: string): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    if ARequest.HasRoleID then begin
      TQueryFunction.SQLAdd(
        LDataset,
        'INSERT INTO users ' +
        '(user_id, username, password_hash, fullname, is_active, role_internal_id) ' +
        'VALUES (:user_id, :username, :password_hash, :fullname, :is_active, :role_id)',
        True
      );
      TQueryFunction.SQLParamByName(LDataset, 'role_id', ARequest.RoleID);
    end else begin
      TQueryFunction.SQLAdd(
        LDataset,
        'INSERT INTO users ' +
        '(user_id, username, password_hash, fullname, is_active) ' +
        'VALUES (:user_id, :username, :password_hash, :fullname, :is_active)',
        True
      );
    end;

    TQueryFunction.SQLParamByName(LDataset, 'user_id', AUserID);
    TQueryFunction.SQLParamByName(LDataset, 'username', ARequest.Username);
    TQueryFunction.SQLParamByName(LDataset, 'password_hash', APasswordHash);
    TQueryFunction.SQLParamByName(LDataset, 'fullname', ARequest.Fullname);
    TQueryFunction.SQLParamByName(LDataset, 'is_active', ARequest.IsActive);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TUserRepository.FindActiveUserByID(const AUserID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT user_id, password_hash FROM users ' +
      'WHERE user_id = :uid AND is_active = 1 AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'uid', AUserID);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TUserRepository.FindAuthUserByTokenHash(
  const ATokenHash: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT u.user_id ' +
      'FROM access_token at ' +
      'INNER JOIN user_session us ON us.id = at.session_internal_id ' +
      'INNER JOIN users u ON u.id = us.user_internal_id ' +
      'WHERE at.token_hash = :hash ' +
      'AND at.revoked = 0 ' +
      'AND at.expires_at > NOW() ' +
      'AND at.deleted_at IS NULL ' +
      'AND us.revoked = 0 ' +
      'AND us.expires_at > NOW() ' +
      'AND us.deleted_at IS NULL ' +
      'AND u.deleted_at IS NULL ' +
      'ORDER BY at.id DESC LIMIT 1',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'hash', ATokenHash);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TUserRepository.FindUserByID(const AUserID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT user_id, username, password_hash, fullname, is_active, role_internal_id ' +
      'FROM users WHERE user_id = :uid AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'uid', AUserID);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TUserRepository.FindUserByUsername(const AUsername: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT user_id FROM users WHERE username = :username AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'username', AUsername);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TUserRepository.GetUsers(const AUserID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    if AUserID <> '' then begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT user_id, username, fullname, is_active, role_internal_id, created_at ' +
        'FROM users WHERE user_id = :uid AND deleted_at IS NULL',
        True
      );
      TQueryFunction.SQLParamByName(Result, 'uid', AUserID);
    end else begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT user_id, username, fullname, is_active, role_internal_id, created_at ' +
        'FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC, username ASC',
        True
      );
    end;
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TUserRepository.SoftDeleteUser(const AUserID: string): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE users SET is_active = 0, deleted_at = NOW() WHERE user_id = :uid AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'uid', AUserID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TUserRepository.UpdatePassword(const AUserID,
  APasswordHash: string): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE users SET password_hash = :password_hash WHERE user_id = :uid AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'password_hash', APasswordHash);
    TQueryFunction.SQLParamByName(LDataset, 'uid', AUserID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TUserRepository.UpdateUser(const ARequest: TUserUpdateRequest;
  const APasswordHash: string): Integer;
var
  I: Integer;
  LDataset: TFDQuery;
  LSetSQL: string;
  LSetClauses: TStringList;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  LSetClauses := TStringList.Create;
  try
    if ARequest.HasPassword then
      LSetClauses.Add('password_hash = :password_hash');

    if ARequest.HasFullname then
      LSetClauses.Add('fullname = :fullname');

    if ARequest.HasIsActive then
      LSetClauses.Add('is_active = :is_active');

    if ARequest.HasRoleID then
      LSetClauses.Add('role_internal_id = :role_id');

    LSetSQL := '';
    for I := 0 to LSetClauses.Count - 1 do begin
      if LSetSQL <> '' then
        LSetSQL := LSetSQL + ', ';
      LSetSQL := LSetSQL + LSetClauses[I];
    end;

    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE users SET ' + LSetSQL + ' WHERE user_id = :uid AND deleted_at IS NULL',
      True
    );

    if ARequest.HasPassword then
      TQueryFunction.SQLParamByName(LDataset, 'password_hash', APasswordHash);

    if ARequest.HasFullname then
      TQueryFunction.SQLParamByName(LDataset, 'fullname', ARequest.Fullname);

    if ARequest.HasIsActive then
      TQueryFunction.SQLParamByName(LDataset, 'is_active', ARequest.IsActive);

    if ARequest.HasRoleID then
      TQueryFunction.SQLParamByName(LDataset, 'role_id', ARequest.RoleID);

    TQueryFunction.SQLParamByName(LDataset, 'uid', ARequest.UserID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LSetClauses);
    FreeAndNil(LDataset);
  end;
end;

end.
