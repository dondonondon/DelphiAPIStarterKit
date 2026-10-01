unit BFA.Security.Token;

interface

uses
  System.SysUtils,
  Web.HTTPApp;

type
  TSecurityToken = class
  public
    class function ExtractAccessToken(AWebRequest: TWebRequest): string;
  end;

implementation

{ TSecurityToken }

class function TSecurityToken.ExtractAccessToken(AWebRequest: TWebRequest): string;
begin
  Result := '';
  if not Assigned(AWebRequest) then
    Exit;

  Result := Trim(AWebRequest.GetFieldByName('x-api-token'));
  if Result = '' then
    Result := Trim(AWebRequest.GetFieldByName('access-token'));
  if Result = '' then
    Result := Trim(AWebRequest.Authorization);

  if Result.StartsWith('Bearer ', True) then
    Result := Trim(Copy(Result, 8, MaxInt));
end;

end.
