unit RestAPI.Product;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  BFA.Core.Helper,
  Web.HTTPApp;

type
  [APIResource('Product')]
  TRestClassV1Product = class(TPersistent)
  published
    function Route(AConnection: TFDConnection; AData: TFDMemTable;
      AWebAction: TWebActionItem; ARequest: TWebRequest;
      AResponse: TWebResponse; out AStatusCode: Integer): String;
  end;

implementation

uses
  BFA.Core.Endpoint,
  BFA.Core.Response,
  Product.Service;

function TRestClassV1Product.Route(AConnection: TFDConnection;
  AData: TFDMemTable; AWebAction: TWebActionItem; ARequest: TWebRequest;
  AResponse: TWebResponse; out AStatusCode: Integer): String;
begin
  Result := THelperEndpoint.ExecuteRoute(
    AData,
    ARequest,
    TProductService,
    [],
    function(const AActionName: string; const AParts: TArray<string>;
      out ARouteStatusCode: Integer): string
    var
      LService: TProductService;
    begin
      LService := TProductService.Create(AConnection, AData, ARequest, AParts);
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
    'Product route error'
  );
end;

end.
