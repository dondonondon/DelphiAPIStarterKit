unit RestAPI.Auth;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp;

type
  [APIResource('Auth')]
  TRestClassV1Auth = class(TPersistent)
  published
    function Route(AConnection: TFDConnection; AData: TFDMemTable;
      AWebAction: TWebActionItem; ARequest: TWebRequest;
      AResponse: TWebResponse; out AStatusCode: Integer): String;
  end;

implementation

uses
  BFA.Core.Endpoint,
  BFA.Core.Helper,
  BFA.Core.Response,
  Auth.Service;

function TRestClassV1Auth.Route(AConnection: TFDConnection; AData: TFDMemTable;
  AWebAction: TWebActionItem; ARequest: TWebRequest; AResponse: TWebResponse;
  out AStatusCode: Integer): String;
begin
  Result := THelperEndpoint.ExecuteRoute(
    AData,
    ARequest,
    TAuthService,
    ['Login', 'Logout', 'Refresh'],
    function(const AActionName: string; const AParts: TArray<string>;
      out ARouteStatusCode: Integer): string
    var
      LService: TAuthService;
    begin
      LService := TAuthService.Create(AConnection, AData, ARequest);
      try
        if not THelperCore.ExecuteStringMethod(LService, AActionName, Result) then begin
          ARouteStatusCode := 405;
          Exit(THelperResponse.CreateResponse(ARouteStatusCode, 'Method Not Allowed', AData));
        end;

        ARouteStatusCode := LService.StatusCode;
      finally
        FreeAndNil(LService);
      end;
    end,
    AStatusCode,
    'Auth route error'
  );
end;

end.
