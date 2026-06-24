unit Auth.Repository;

interface

uses
  Data.DB,
  FireDAC.Comp.Client;

type
  TAuthRepository = class
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);

    function FindUserForLogin(const AUsername: string): TFDQuery;
    function SessionExists(const ASessionID, ADeviceID: string;
      out ASessionInternalID: UInt64): Boolean;

    procedure RevokeActiveSessions(const AUserInternalID: UInt64; const ADeviceID: string);
    function CreateSession(const AUserInternalID: UInt64; const ASessionID, ADeviceID,
      ADeviceName, AUserAgent, AIPAddress: string): UInt64;
    procedure CreateAccessToken(const ATokenHash: string; const ASessionInternalID: UInt64);
    procedure RevokeSession(const ASessionID, ADeviceID: string);
  end;

implementation

uses
  System.SysUtils,
  DB.Helper.Query;

constructor TAuthRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TAuthRepository.CreateAccessToken(const ATokenHash: string;
  const ASessionInternalID: UInt64);
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'INSERT INTO access_token ' +
      '(token_hash, session_internal_id, expires_at) ' +
      'VALUES (:hash, :sid, DATE_ADD(NOW(), INTERVAL 30 MINUTE))',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'hash', ATokenHash);
    TQueryFunction.SQLParamByName(LDataset, 'sid', ASessionInternalID);
    TQueryFunction.ExecSQL(LDataset);
  finally
    FreeAndNil(LDataset);
  end;
end;

function TAuthRepository.CreateSession(const AUserInternalID: UInt64;
  const ASessionID, ADeviceID, ADeviceName, AUserAgent, AIPAddress: string): UInt64;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'INSERT INTO user_session ' +
      '(session_id, user_internal_id, device_id, device_name, user_agent, ip_address, expires_at) ' +
      'VALUES (:sid, :uid, :device, :device_name, :user_agent, :ip_address, DATE_ADD(NOW(), INTERVAL 7 DAY))',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'sid', ASessionID);
    TQueryFunction.SQLParamByName(LDataset, 'uid', AUserInternalID);
    TQueryFunction.SQLParamByName(LDataset, 'device', ADeviceID);
    TQueryFunction.SQLParamByName(LDataset, 'device_name', ADeviceName);
    TQueryFunction.SQLParamByName(LDataset, 'user_agent', AUserAgent);
    TQueryFunction.SQLParamByName(LDataset, 'ip_address', AIPAddress);
    TQueryFunction.ExecSQL(LDataset);

    LDataset.Close;
    TQueryFunction.SQLAdd(LDataset, 'SELECT LAST_INSERT_ID() AS new_id', True);
    TQueryFunction.SQLOpen(LDataset);
    Result := LDataset.FieldByName('new_id').AsLargeInt;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TAuthRepository.FindUserForLogin(const AUsername: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT id, user_id, password_hash, is_active ' +
      'FROM users WHERE username = :username AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'username', AUsername);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TAuthRepository.RevokeActiveSessions(const AUserInternalID: UInt64;
  const ADeviceID: string);
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE user_session ' +
      'SET revoked = 1 ' +
      'WHERE user_internal_id = :uid ' +
      'AND device_id = :device ' +
      'AND expires_at > NOW() ' +
      'AND revoked = 0',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'uid', AUserInternalID);
    TQueryFunction.SQLParamByName(LDataset, 'device', ADeviceID);
    TQueryFunction.ExecSQL(LDataset);
  finally
    FreeAndNil(LDataset);
  end;
end;

procedure TAuthRepository.RevokeSession(const ASessionID, ADeviceID: string);
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE user_session ' +
      'SET revoked = 1 ' +
      'WHERE session_id = :sid ' +
      'AND device_id = :device ' +
      'AND revoked = 0',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'sid', ASessionID);
    TQueryFunction.SQLParamByName(LDataset, 'device', ADeviceID);
    TQueryFunction.ExecSQL(LDataset);
  finally
    FreeAndNil(LDataset);
  end;
end;

function TAuthRepository.SessionExists(const ASessionID,
  ADeviceID: string; out ASessionInternalID: UInt64): Boolean;
var
  LDataset: TFDQuery;
begin
  ASessionInternalID := 0;
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'SELECT id ' +
      'FROM user_session ' +
      'WHERE session_id = :sid ' +
      'AND device_id = :device ' +
      'AND revoked = 0 ' +
      'AND expires_at > NOW() ' +
      'AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'sid', ASessionID);
    TQueryFunction.SQLParamByName(LDataset, 'device', ADeviceID);
    TQueryFunction.SQLOpen(LDataset);

    Result := not LDataset.IsEmpty;
    if Result then
      ASessionInternalID := LDataset.FieldByName('id').AsLargeInt;
  finally
    FreeAndNil(LDataset);
  end;
end;

end.
