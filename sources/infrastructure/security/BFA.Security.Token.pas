unit BFA.Security.Token;

interface

uses System.SysUtils, Web.HTTPApp;

type
  TSecurityToken = class
  public
    class function ExtractAccessToken(AWebRequest: TWebRequest): string; static;
  end;

implementation

uses Auth.Policy, BFA.Security.Crypto;

class function TSecurityToken.ExtractAccessToken(AWebRequest: TWebRequest): string;
var LAuthorization, LCustom, LLegacy, LBearer: string;
begin
  Result := '';
  if not Assigned(AWebRequest) then Exit;
  LAuthorization := Trim(AWebRequest.Authorization);
  LCustom := AWebRequest.GetFieldByName('x-api-token');
  LLegacy := AWebRequest.GetFieldByName('access-token');
  if LAuthorization <> '' then begin
    if not LAuthorization.StartsWith('Bearer ', True) then raise EAuthPolicy.Create(401, 'Invalid credential.');
    LBearer := Copy(LAuthorization, 8, MaxInt);
    if (LBearer = '') or (LBearer.Trim <> LBearer) then raise EAuthPolicy.Create(401, 'Invalid credential.');
    Result := LBearer;
  end;
  if LCustom <> '' then begin
    if (Result <> '') and (Result <> LCustom) then raise EAuthPolicy.Create(400, 'Conflicting credentials.');
    Result := LCustom;
  end;
  if LLegacy <> '' then begin
    if (Result <> '') and (Result <> LLegacy) then raise EAuthPolicy.Create(400, 'Conflicting credentials.');
    Result := LLegacy;
  end;
  if (Result <> '') and (TSecurityCrypto.TokenHash(Result) = '') then raise EAuthPolicy.Create(401, 'Invalid credential.');
end;

end.
