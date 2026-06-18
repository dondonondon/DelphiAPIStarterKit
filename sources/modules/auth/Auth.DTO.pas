unit Auth.DTO;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TAuthLoginRequest = record
    Username: string;
    Password: string;
    DeviceID: string;
    DeviceName: string;
    UserAgent: string;
    IPAddress: string;
  end;

  TAuthSessionRequest = record
    SessionID: string;
    DeviceID: string;
  end;

  TAuthTokenDTO = class
    class function CreateTokenResponse(const AAccessToken: string;
      AExpiresIn: Integer; const ASessionID: string = ''): TStringList;
  end;

implementation

{ TAuthTokenDTO }

class function TAuthTokenDTO.CreateTokenResponse(const AAccessToken: string;
  AExpiresIn: Integer; const ASessionID: string): TStringList;
begin
    Result := TStringList.Create;
  try
    Result.AddPair('access_token', AAccessToken);
    Result.AddPair('expires_in', IntToStr(AExpiresIn));
    if ASessionID <> '' then
      Result.AddPair('session_id', ASessionID);
  except
    Result.Free;
    raise;
  end;
end;

end.
