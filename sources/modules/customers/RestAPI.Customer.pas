unit RestAPI.Customer;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  BFA.Core.Helper,
  Web.HTTPApp;

type
  [APIResource('Customer')]
  TRestClassV1Customer = class(TPersistent)
  published
    function Route(AConnection: TFDConnection; AData: TFDMemTable;
      AWebAction: TWebActionItem; ARequest: TWebRequest;
      AResponse: TWebResponse; out AStatusCode: Integer): String;
  end;

implementation

uses
  BFA.Core.Endpoint,
  BFA.Core.Response,
  Customer.Service;

function TRestClassV1Customer.Route(AConnection: TFDConnection;
  AData: TFDMemTable; AWebAction: TWebActionItem; ARequest: TWebRequest;
  AResponse: TWebResponse; out AStatusCode: Integer): String;
begin
  Result := THelperEndpoint.ExecuteRoute(
    AData,
    ARequest,
    TCustomerService,
    [],
    function(const AActionName: string; const AParts: TArray<string>;
      out ARouteStatusCode: Integer): string
    var
      LService: TCustomerService;
    begin
      LService := TCustomerService.Create(AConnection, AData, ARequest, AParts);
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
    'Customer route error',
    AConnection,
    True
  );
end;

end.
