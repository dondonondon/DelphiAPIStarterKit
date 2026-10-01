unit Auth.Validator;

interface

uses System.SysUtils, System.JSON, Web.HTTPApp;

type
  TAuthValidator = class
  public
    class procedure Username(const AValue: string); static;
    class procedure Password(const AValue: string; ANew: Boolean); static;
    class procedure UUID(const AValue: string); static;
    class function PageValue(ARequest: TWebRequest; const AName: string; ADefault, AMaximum: Integer): Integer; static;
    class function Origin(ARequest: TWebRequest): string; static;
  end;

implementation

uses System.RegularExpressions, System.Classes, System.IOUtils, BFA.Core.Request, BFA.Core.Config;

class procedure TAuthValidator.Username(const AValue: string);
begin
  if not TRegEx.IsMatch(AValue, '^[A-Za-z0-9_.-]{1,50}$') then raise ERequestInvalid.Create('Invalid username.');
end;

class procedure TAuthValidator.UUID(const AValue: string);
begin
  if not TRegEx.IsMatch(AValue, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    raise ERequestInvalid.Create('Invalid public identifier.');
end;

class procedure TAuthValidator.Password(const AValue: string; ANew: Boolean);
var LCount: Integer; LPath, LEntry: string;
begin
  LCount := THelperRequest.Codepoints(AValue);
  if (LCount < 1) or (LCount > 128) or (TEncoding.UTF8.GetByteCount(AValue) > 512) then
    raise ERequestInvalid.Create('Invalid password length.');
  if not ANew then Exit;
  if LCount < 15 then raise ERequestInvalid.Create('Password requires 15 to 128 Unicode codepoints.');
  if TRegEx.IsMatch(LowerCase(AValue), '^(password|123456|qwerty|letmein|admin|welcome|changeme|correcthorsebatterystaple)[0-9 !@#$]*$') then
    raise ERequestInvalid.Create('Password is blocked.');
  LPath := TServerConfig.ReadValue('Security', 'PasswordBlocklist', 'DELPHI_API_PASSWORD_BLOCKLIST', '');
  if LPath = '' then Exit;
  if not TPath.IsPathRooted(LPath) or not FileExists(LPath) then
    raise Exception.Create('Password blocklist unavailable.');
  for LEntry in TFile.ReadAllLines(LPath, TEncoding.UTF8) do
    if SameText(AValue, LEntry) then raise ERequestInvalid.Create('Password is blocked.');
end;

class function TAuthValidator.PageValue(ARequest: TWebRequest; const AName: string; ADefault, AMaximum: Integer): Integer;
var LText: string;
begin
  LText := ARequest.QueryFields.Values[AName];
  Result := ADefault;
  if LText = '' then Exit;
  if not TRegEx.IsMatch(LText, '^[0-9]{1,7}$') or not TryStrToInt(LText, Result) or (Result < 0) or
    (Result > AMaximum) or ((AName = 'limit') and (Result = 0)) then raise ERequestInvalid.Create('Invalid pagination.');
end;

class function TAuthValidator.Origin(ARequest: TWebRequest): string;
begin
  Result := ARequest.RemoteAddr;
  if (Length(Result) > 45) or not TRegEx.IsMatch(Result, '^[0-9a-fA-F:.]{2,45}$') then
    raise ERequestInvalid.Create('Invalid observed origin.');
end;

end.
