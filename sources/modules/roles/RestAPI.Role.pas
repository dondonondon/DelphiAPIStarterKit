unit RestAPI.Role;

interface

uses System.SysUtils, System.Classes, FireDAC.Comp.Client, BFA.Core.Helper, Web.HTTPApp;

type
  [APIResource('Role')]
  TRestClassV1Role = class(TPersistent)
  published
    function Route(AConnection: TFDConnection; AData: TFDMemTable; AWebAction: TWebActionItem;
      ARequest: TWebRequest; AResponse: TWebResponse; out AStatusCode: Integer): string;
  end;

implementation

uses BFA.Core.Endpoint, Role.Service;

function TRestClassV1Role.Route(AConnection: TFDConnection; AData: TFDMemTable; AWebAction: TWebActionItem;
  ARequest: TWebRequest; AResponse: TWebResponse; out AStatusCode: Integer): string;
begin
  Result := THelperEndpoint.ExecuteRoute(AData, ARequest, TRoleService, [],
    function(const AActionName: string; const AParts: TArray<string>; out ARouteStatusCode: Integer): string
    var LService: TRoleService;
    begin
      LService := TRoleService.Create(AConnection, ARequest);
      try
        if AActionName = 'Get' then Result := LService.Get else Result := LService.Permissions;
        ARouteStatusCode := LService.StatusCode;
      finally
        FreeAndNil(LService);
      end;
    end, AStatusCode, 'Role route', AConnection, True);
end;

end.
