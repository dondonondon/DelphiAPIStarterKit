unit Auth.Validator;

interface

uses
  FireDAC.Comp.Client,
  Auth.DTO;

type
  TAuthValidator = class
  public
    class function ValidateLogin(AData: TFDMemTable;
      out ARequest: TAuthLoginRequest; out AMessage: string): Boolean;
    class function ValidateSession(AData: TFDMemTable;
      out ARequest: TAuthSessionRequest; out AMessage: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  BFA.Helper.Validator;

{ TAuthValidator }

class function TAuthValidator.ValidateLogin(AData: TFDMemTable;
  out ARequest: TAuthLoginRequest; out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.Username := '';
  ARequest.Password := '';
  ARequest.DeviceID := '';
  ARequest.DeviceName := '';
  ARequest.UserAgent := '';
  ARequest.IPAddress := '';

  if not THelperValidator.GetRequiredString(AData, 'username', 'Username required',
    ARequest.Username, AMessage) then
    Exit;

  if not THelperValidator.GetRequiredString(AData, 'password', 'Password required',
    ARequest.Password, AMessage) then
    Exit;

  if not THelperValidator.GetRequiredString(AData, 'device_id', 'Device ID required',
    ARequest.DeviceID, AMessage) then
    Exit;

  ARequest.DeviceName := THelperValidator.GetOptionalString(AData, 'device_name');
  ARequest.UserAgent := THelperValidator.GetOptionalString(AData, 'user_agent');
  ARequest.IPAddress := THelperValidator.GetOptionalString(AData, 'ip_address');

  Result := True;
end;

class function TAuthValidator.ValidateSession(AData: TFDMemTable;
  out ARequest: TAuthSessionRequest; out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.SessionID := '';
  ARequest.DeviceID := '';

  if not THelperValidator.GetRequiredString(AData, 'session_id', 'Session ID and Device ID required',
    ARequest.SessionID, AMessage) then
    Exit;

  if not THelperValidator.GetRequiredString(AData, 'device_id', 'Session ID and Device ID required',
    ARequest.DeviceID, AMessage) then
    Exit;

  Result := True;
end;

end.
