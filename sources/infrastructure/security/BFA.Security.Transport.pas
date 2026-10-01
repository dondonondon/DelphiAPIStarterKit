unit BFA.Security.Transport;

interface

uses System.SysUtils, IdContext, IdCustomHTTPServer, IdHTTPWebBrokerBridge, IdHeaderList, Web.HTTPApp;

type
  TSecurityHTTPBridge = class(TIdHTTPWebBrokerBridge)
  protected
    procedure Reject(ASender: TIdContext; AStatus: Integer; const AMessage, AOrigin: string);
    function DoHeadersAvailable(ASender: TIdContext; const AUri: string; AHeaders: TIdHeaderList): Boolean; override;
  end;

  TSecurityTransport = class
  public
    procedure ParseAuthentication(AContext: TIdContext; const AAuthType, AAuthData: string;
      var VUsername, VPassword: string; var VHandled: Boolean);
    procedure CommandError(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo; AException: Exception);
    class procedure JSONResponse(AResponse: TWebResponse; AStatus: Integer; const AJSON: string); static;
    class function AllowedOrigin(const AOrigin: string): Boolean; static;
    class function CORS(ARequest: TWebRequest; AResponse: TWebResponse): Boolean; static;
  end;

implementation

uses System.Classes, System.RegularExpressions, BFA.Core.Config, BFA.Core.Helper, BFA.Core.Response, BFA.Logger,
  Auth.Policy, IdException, IdExceptionCore, IdStack, IdURI;

type
  ETransportRejected = class(EAuthPolicy);

function TSecurityHTTPBridge.DoHeadersAvailable(ASender: TIdContext; const AUri: string; AHeaders: TIdHeaderList): Boolean;
var LLength: Int64; LLimit, I, LCount: Integer; LName, LUri: string;
begin
  LLimit := TServerConfig.MAX_FILE_SIZE;
  LUri := LowerCase(TIdURI.URLDecode(AUri));
  if LUri.StartsWith('/api/v1/auth') or LUri.StartsWith('/api/v1/user') or LUri.StartsWith('/api/v1/role') then
    LLimit := 16384;
  try
    for LName in ['Authorization','x-api-token','access-token','Content-Length','Transfer-Encoding','Host'] do begin
      LCount := 0;
      for I := 0 to AHeaders.Count - 1 do
        if SameText(AHeaders.Names[I], LName) then Inc(LCount);
      if LCount > 1 then raise ETransportRejected.Create(400, 'Duplicate credential or framing header.');
    end;
    if (AHeaders.Values['Transfer-Encoding'] <> '') or (AHeaders.Values['X-HTTP-Method-Override'] <> '') or
      (AHeaders.Values['X-HTTP-Method'] <> '') or (AHeaders.Values['X-METHOD-OVERRIDE'] <> '') then
      raise ETransportRejected.Create(400, 'Unsupported request framing or method override.');
    if AHeaders.Values['Content-Length'] <> '' then begin
      if not TRegEx.IsMatch(AHeaders.Values['Content-Length'], '^[0-9]{1,10}$') or
        not TryStrToInt64(AHeaders.Values['Content-Length'], LLength) or (LLength < 0) then
        raise ETransportRejected.Create(400, 'Invalid content length.');
      if LLength > LLimit then raise ETransportRejected.Create(413, 'Request body exceeds limit.');
    end;
  except
    on E: ETransportRejected do begin
      Reject(ASender, E.Status, E.Message, AHeaders.Values['Origin']);
      raise EIdClosedSocket.Create('Request terminated.');
    end;
    on E: Exception do begin
      THelperLogger.Error('HTTP headers', E);
      Reject(ASender, 500, 'Internal server error.', '');
      raise EIdClosedSocket.Create('Request terminated.');
    end;
  end;
  Result := inherited;
end;

procedure TSecurityHTTPBridge.Reject(ASender: TIdContext; AStatus: Integer; const AMessage, AOrigin: string);
var LJSON, LHeaders: string;
begin
  LJSON := THelperResponse.CreateResponse(AStatus, AMessage);
  LHeaders := '';
  if TSecurityTransport.AllowedOrigin(AOrigin) then
    LHeaders := 'Access-Control-Allow-Origin: ' + AOrigin + #13#10;
  ASender.Connection.IOHandler.Write('HTTP/1.1 ' + IntToStr(AStatus) + ' Request rejected' + #13#10
    + 'Content-Type: application/json; charset=utf-8' + #13#10 + 'Cache-Control: no-store' + #13#10
    + 'Vary: Origin' + #13#10 + LHeaders + 'Connection: close' + #13#10
    + 'Content-Length: ' + IntToStr(Length(LJSON)) + #13#10#13#10 + LJSON);
end;

class function TSecurityTransport.AllowedOrigin(const AOrigin: string): Boolean;
var LOrigins: string;
begin
  LOrigins := TServerConfig.ReadValue('HTTP', 'AllowedOrigins', 'DELPHI_API_ALLOWED_ORIGINS', '');
  Result := (AOrigin <> '') and (AOrigin <> 'null') and (AOrigin <> '*') and
    THelperCore.IsActionNameInList(AOrigin, LOrigins.Split([';']));
end;

procedure TSecurityTransport.ParseAuthentication(AContext: TIdContext; const AAuthType, AAuthData: string;
  var VUsername, VPassword: string; var VHandled: Boolean);
begin
  VUsername := '';
  VPassword := '';
  VHandled := True;
end;

procedure TSecurityTransport.CommandError(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo; AException: Exception);
begin
  THelperLogger.Error('HTTP transport', AException);
  AResponseInfo.ResponseNo := 500;
  AResponseInfo.ContentType := 'application/json; charset=utf-8';
  AResponseInfo.ContentEncoding := '';
  AResponseInfo.CharSet := 'utf-8';
  AResponseInfo.ContentText := THelperResponse.CreateResponse(500, 'Internal server error.');
  AResponseInfo.CustomHeaders.Values['Cache-Control'] := 'no-store';
end;

class procedure TSecurityTransport.JSONResponse(AResponse: TWebResponse; AStatus: Integer; const AJSON: string);
var LStream: TBytesStream;
begin
  AResponse.StatusCode := AStatus;
  AResponse.ContentType := 'application/json; charset=utf-8';
  AResponse.ContentEncoding := '';
  LStream := TBytesStream.Create(TEncoding.UTF8.GetBytes(AJSON));
  try
    AResponse.ContentStream := LStream;
    LStream := nil;
  finally
    FreeAndNil(LStream);
  end;
end;

class function TSecurityTransport.CORS(ARequest: TWebRequest; AResponse: TWebResponse): Boolean;
var LOrigin, LMethod, LAction, LAllow, LHeaders, LHeader: string; LStatus: Integer; LAllowed: Boolean;
begin
  Result := False;
  LOrigin := ARequest.GetFieldByName('Origin');
  LAllowed := AllowedOrigin(LOrigin);
  AResponse.SetCustomHeader('Vary', 'Origin');
  if LAllowed then begin
    AResponse.SetCustomHeader('Access-Control-Allow-Origin', LOrigin);
    AResponse.SetCustomHeader('Access-Control-Expose-Headers', 'Retry-After, Allow');
  end;
  if not SameText(ARequest.Method, 'OPTIONS') then Exit;
  Result := True;
  if not LAllowed then begin
    JSONResponse(AResponse, 403, THelperResponse.CreateResponse(403, 'Origin not allowed.'));
    Exit;
  end;
  LMethod := ARequest.GetFieldByName('Access-Control-Request-Method');
  if not THelperCore.InspectRoute(ARequest.PathInfo, LMethod, LAction, LStatus, LAllow) then begin
    AResponse.SetCustomHeader('Allow', LAllow);
    JSONResponse(AResponse, LStatus, THelperResponse.CreateResponse(LStatus, 'Route or method not allowed.'));
    Exit;
  end;
  LHeaders := ARequest.GetFieldByName('Access-Control-Request-Headers');
  for LHeader in LHeaders.Split([','], TStringSplitOptions.ExcludeEmpty) do
    if not THelperCore.IsActionNameInList(LHeader.Trim, ['Authorization','Content-Type','x-api-token','access-token']) then begin
      JSONResponse(AResponse, 403, THelperResponse.CreateResponse(403, 'Header not allowed.'));
      Exit;
    end;
  AResponse.SetCustomHeader('Access-Control-Allow-Methods', LAllow);
  AResponse.SetCustomHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, x-api-token, access-token');
  AResponse.SetCustomHeader('Access-Control-Max-Age', '300');
  AResponse.StatusCode := 204;
  AResponse.Content := '';
end;

end.


