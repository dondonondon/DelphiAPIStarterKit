unit Auth.Bootstrap;

interface

uses FireDAC.Comp.Client;

type
  TAuthBootstrap = class
  public
    class procedure Execute(AConnection: TFDConnection); static;
  end;

implementation

uses System.SysUtils, BFA.Core.Config, BFA.Helper.Strings, BFA.Security.Crypto, Auth.Repository,
  Auth.Policy, Auth.Validator;

class procedure TAuthBootstrap.Execute(AConnection: TFDConnection);
var LRepository: TAuthRepository; LQuery: TFDQuery; LUsername, LPassword, LHash, LCode, LID: string;
  LRole: Integer; LActor: TAuthActor;
begin
  LUsername := GetEnvironmentVariable('DELPHI_API_BOOTSTRAP_USERNAME');
  LPassword := GetEnvironmentVariable('DELPHI_API_BOOTSTRAP_PASSWORD');
  TAuthValidator.Username(LUsername);
  TAuthValidator.Password(LPassword, True);
  LHash := TSecurityCrypto.HashPassword(LPassword);
  LPassword := '';
  LRepository := TAuthRepository.Create(AConnection);
  try
    AConnection.StartTransaction;
    try
      for LCode in TAuthCatalog.Codes do LRepository.Execute('INSERT INTO m_permission(permission_code) VALUES(:code) '
        + 'ON DUPLICATE KEY UPDATE permission_code=VALUES(permission_code)', ['code', LCode]);
      LQuery := LRepository.Query('SELECT id FROM m_permission WHERE permission_code=''users.assign_role'' FOR UPDATE', []);
      FreeAndNil(LQuery);
      LQuery := LRepository.Query('SELECT COUNT(*) FROM users', []);
      try
        if LQuery.Fields[0].AsLargeInt <> 0 then raise Exception.Create('Offline bootstrap is only permitted before any user exists.');
      finally
        FreeAndNil(LQuery);
      end;
      LRepository.Execute('INSERT INTO m_role(role_id,role_code,role_name) VALUES(:id,''admin'',''Administrator'') '
        + 'ON DUPLICATE KEY UPDATE role_code=role_code', ['id', '11111111-1111-4111-8111-111111111111']);
      LQuery := LRepository.Query('SELECT id FROM m_role WHERE role_code=''admin'' AND is_active=1 AND deleted_at IS NULL', []);
      try
        if LQuery.IsEmpty then raise Exception.Create('Bootstrap admin role unavailable.');
        LRole := LQuery.Fields[0].AsInteger;
      finally
        FreeAndNil(LQuery);
      end;
      for LCode in TAuthCatalog.Codes do LRepository.Execute('INSERT INTO role_permission(role_internal_id,permission_internal_id) '
        + 'SELECT :role,id FROM m_permission WHERE permission_code=:code AND is_active=1 '
        + 'ON DUPLICATE KEY UPDATE role_internal_id=role_internal_id', ['role', LRole, 'code', LCode]);
      LID := TGlobalFunction.NewDatabaseUUID;
      LRepository.Execute('INSERT INTO users(user_id,username,password_hash,must_change_password,role_internal_id) '
        + 'VALUES(:id,:username,:hash,0,:role)', ['id', LID,
        'username', LUsername, 'hash', LHash, 'role', LRole]);
      LRepository.ProtectLastAdmin;
      LActor := Default(TAuthActor);
      LRepository.Audit('bootstrap_admin', 'success', LActor, LID, '');
      LRepository.Commit;
    except
      LRepository.Rollback;
      raise;
    end;
  finally
    FreeAndNil(LRepository);
  end;
end;

end.
