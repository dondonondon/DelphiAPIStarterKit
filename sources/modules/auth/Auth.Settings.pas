unit Auth.Settings;

interface

type
  TAuthSettings = class
  public
    class var AccessSeconds, AbsoluteSeconds, IdleSeconds, RecoverySeconds, RecentSeconds: Integer;
    class var AccountLimit, OriginLimit, GlobalLimit, AdmissionLimit: Integer;
    class procedure Initialize; static;
  end;

implementation

uses System.SysUtils, BFA.Core.Config;

class procedure TAuthSettings.Initialize;
begin
  AccessSeconds := TServerConfig.ReadInteger('AccessSeconds', 'DELPHI_API_ACCESS_SECONDS', 900, 60, 3600);
  AbsoluteSeconds := TServerConfig.ReadInteger('AbsoluteSeconds', 'DELPHI_API_ABSOLUTE_SECONDS', 604800, 900, 2592000);
  IdleSeconds := TServerConfig.ReadInteger('IdleSeconds', 'DELPHI_API_IDLE_SECONDS', 86400, 900, AbsoluteSeconds);
  RecoverySeconds := TServerConfig.ReadInteger('RecoverySeconds', 'DELPHI_API_RECOVERY_SECONDS', 900, 60, 900);
  RecentSeconds := TServerConfig.ReadInteger('RecentSeconds', 'DELPHI_API_RECENT_SECONDS', 300, 30, 300);
  AccountLimit := TServerConfig.ReadInteger('AccountLimit', 'DELPHI_API_ACCOUNT_LIMIT', 10, 1, 100);
  OriginLimit := TServerConfig.ReadInteger('OriginLimit', 'DELPHI_API_ORIGIN_LIMIT', 60, 1, 1000);
  GlobalLimit := TServerConfig.ReadInteger('GlobalLimit', 'DELPHI_API_GLOBAL_LIMIT', 300, 1, 10000);
  AdmissionLimit := TServerConfig.ReadInteger('AdmissionLimit', 'DELPHI_API_ADMISSION_LIMIT', 4, 1, 16);
  if TServerConfig.ReadValue('Security', 'Profile', 'DELPHI_API_SECURITY_PROFILE', 'password-only') <> 'password-only' then
    raise Exception.Create('Selected security profile requires an integrated MFA provider.');
end;

end.
