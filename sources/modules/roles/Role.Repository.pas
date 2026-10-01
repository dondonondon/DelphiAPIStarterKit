unit Role.Repository;

interface

uses System.JSON, FireDAC.Comp.Client, Auth.Repository;

type
  TRoleRepository = class(TAuthRepository)
  public
    function Catalog(ALimit, AOffset: Integer): TJSONArray;
    function FindRole(const AID: string): TFDQuery;
    procedure ValidatePermissionCodes(const ACodes: TArray<string>);
    procedure ReplacePermissions(ARoleID: Integer; const ACodes: TArray<string>);
  end;

implementation

uses System.SysUtils, Auth.Policy;

function TRoleRepository.Catalog(ALimit, AOffset: Integer): TJSONArray;
var LRow: TJSONValue; LPermissions: TJSONArray; LQuery: TFDQuery;
begin
  Result := JSONRows('SELECT role_id,id AS legacy_role_id,role_code,role_name,is_active,is_superadmin '
    + 'FROM m_role WHERE deleted_at IS NULL ORDER BY id LIMIT :lim OFFSET :off', ['lim', ALimit, 'off', AOffset]);
  try
    for LRow in Result do begin
      LQuery := Query('SELECT p.permission_code FROM role_permission rp JOIN m_permission p ON p.id=rp.permission_internal_id '
        + 'WHERE rp.role_internal_id=:id AND p.is_active=1 ORDER BY p.permission_code LIMIT 100',
        ['id', TJSONObject(LRow).GetValue<Integer>('legacy_role_id')]);
      try
        LPermissions := TJSONArray.Create;
        TJSONObject(LRow).AddPair('permissions', LPermissions);
        while not LQuery.Eof do begin
          LPermissions.Add(LQuery.Fields[0].AsString);
          LQuery.Next;
        end;
      finally
        FreeAndNil(LQuery);
      end;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TRoleRepository.FindRole(const AID: string): TFDQuery;
begin
  Result := Query('SELECT id FROM m_role WHERE role_id=:id AND is_active=1 AND deleted_at IS NULL FOR UPDATE', ['id', AID]);
end;

procedure TRoleRepository.ReplacePermissions(ARoleID: Integer; const ACodes: TArray<string>);
var LCode: string; LQuery, LLocked: TFDQuery;
begin
  LQuery := Query('SELECT id FROM users WHERE role_internal_id=:role ORDER BY id', ['role', ARoleID]);
  try
    while not LQuery.Eof do begin
      LLocked := LockUser(LQuery.Fields[0].AsLargeInt);
      FreeAndNil(LLocked);
      RevokeUser(LQuery.Fields[0].AsLargeInt, 'role_permissions_change');
      RevokeRecovery(LQuery.Fields[0].AsLargeInt, 'role_permissions_change');
      LQuery.Next;
    end;
  finally
    FreeAndNil(LQuery);
  end;
  Execute('DELETE FROM role_permission WHERE role_internal_id=:role', ['role', ARoleID]);
  for LCode in ACodes do begin
    if Execute('INSERT INTO role_permission(role_internal_id,permission_internal_id) '
      + 'SELECT :role,id FROM m_permission WHERE permission_code=:code AND is_active=1',
      ['role', ARoleID, 'code', LCode]) <> 1 then raise EAuthPolicy.Create(400, 'Unknown or inactive permission.');
  end;
end;

procedure TRoleRepository.ValidatePermissionCodes(const ACodes: TArray<string>);
var LCode: string; LQuery: TFDQuery;
begin
  for LCode in ACodes do begin
    LQuery := Query('SELECT id FROM m_permission WHERE permission_code=:code AND is_active=1', ['code', LCode]);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(400, 'Unknown or inactive permission.');
    finally
      FreeAndNil(LQuery);
    end;
  end;
end;

end.
