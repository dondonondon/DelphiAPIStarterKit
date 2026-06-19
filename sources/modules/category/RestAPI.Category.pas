unit RestAPI.Category;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  BFA.Core.Helper,
  Web.HTTPApp;

type
  [APIResource('Category')]
  TRestClassV1Category = class(TPersistent)
  published
    function Route(AConnection: TFDConnection; AData: TFDMemTable;
      AWebAction: TWebActionItem; ARequest: TWebRequest;
      AResponse: TWebResponse; out AStatusCode: Integer): String;
  end;

implementation

uses
  BFA.Core.Endpoint,
  BFA.Core.Response,
  Category.Service;

function TRestClassV1Category.Route(AConnection: TFDConnection;
  AData: TFDMemTable; AWebAction: TWebActionItem; ARequest: TWebRequest;
  AResponse: TWebResponse; out AStatusCode: Integer): String;
begin
  Result := THelperEndpoint.ExecuteRoute(
    AData,
    ARequest,
    TCategoryService,
    [],
    function(const AActionName: string; const AParts: TArray<string>;
      out ARouteStatusCode: Integer): string
    var
      LService: TCategoryService;
    begin
      LService := TCategoryService.Create(AConnection, AData, ARequest, AParts);
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
    'Category route error'
  );
end;

end.