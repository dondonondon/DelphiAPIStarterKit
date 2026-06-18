unit RestAPI.User;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp;

type
  [APIResource('User')]
  TRestClassV1User = class(TPersistent)
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
  User.Service;

function TRestClassV1User.Route(AConnection: TFDConnection; AData: TFDMemTable;
  AWebAction: TWebActionItem; ARequest: TWebRequest; AResponse: TWebResponse;
  out AStatusCode: Integer): String;
begin
  Result := THelperEndpoint.ExecuteRoute(
    AData,
    ARequest,
    TUserService,
    ['ChangePassword', 'ResetPassword'],
    function(const AActionName: string; const AParts: TArray<string>;
      out ARouteStatusCode: Integer): string
    var
      LService: TUserService;
    begin
      LService := TUserService.Create(AConnection, AData, ARequest, AParts);
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
    'User route error'
  );
end;

end.
