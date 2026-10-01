unit App.WebModule;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, Web.HTTPApp,
  System.IOUtils, System.SyncObjs,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client;

type
  TWM = class(TWebModule)
    procedure WebModule1DefaultHandlerAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WMHelloWorldAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
    procedure WebModuleCreate(Sender: TObject);
    procedure WebModuleException(Sender: TObject; E: Exception; var Handled: Boolean);
    procedure WMimageAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
    procedure WMtestAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
    procedure WMapiAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  private
//    FServerFunctionInvokerAction: TWebActionItem;
//    function AllowServerFunctionInvoker: Boolean;
    { Private declarations }
    function SendToCoreAPI(WebAction : TWebActionItem; Request: TWebRequest; Response: TWebResponse; ACheckHeader : Boolean = True) : String;
  public
    { Public declarations }
  end;

var
  WebModuleClass: TComponentClass = TWM;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

uses Web.WebReq, BFA.Core.Rest, BFA.Core.Response, uDM,
  BFA.Helper.Strings, BFA.Core.Config, BFA.Core.Request,
  DB.ConnectionFactory, BFA.Core.Helper, BFA.Security.Transport, BFA.Security.Token, BFA.Core.Endpoint,
  BFA.Logger, Auth.Policy;

//function TWM.AllowServerFunctionInvoker: Boolean;
//begin
//  Result := (Request.RemoteAddr = '127.0.0.1') or
//    (Request.RemoteAddr = '0:0:0:0:0:0:0:1') or (Request.RemoteAddr = '::1');
//end;

function TWM.SendToCoreAPI(WebAction: TWebActionItem; Request: TWebRequest;
  Response: TWebResponse; ACheckHeader: Boolean): string;
var LParts: TArray<string>; LAction, LAllow: string; LStatus: Integer;
  LCon: TFDConnection; LCoreAPI: TClassHelper;
begin
  THelperLogger.BeginRequest;
  try
    Response.SetCustomHeader('X-Correlation-ID', THelperLogger.CorrelationID);
  Result := '';
  Response.SetCustomHeader('Cache-Control', 'no-store');
  try
    if TSecurityTransport.CORS(Request, Response) then Exit;
    if not THelperCore.InspectRoute(Request.PathInfo, Request.Method, LAction, LStatus, LAllow) then begin
      if LAllow <> '' then Response.SetCustomHeader('Allow', LAllow);
      Result := THelperResponse.CreateResponse(LStatus, 'Route or method not allowed.');
      TSecurityTransport.JSONResponse(Response, LStatus, Result);
      Exit;
    end;
    if (SameText(Request.Method, 'GET') or SameText(Request.Method, 'DELETE')) and (Request.Content <> '') then
      raise ERequestInvalid.Create('This method does not accept a request body.');
    TSecurityToken.ExtractAccessToken(Request);
    LParts := Request.PathInfo.Trim(['/']).Split(['/']);
    LCon := TDBConnectionFactory.GetConnection;
    try
      LCoreAPI := TClassHelper.Create;
      try
        LCoreAPI.Connection := LCon;
        LCoreAPI.APIVersion := 'v1';
        LCoreAPI.RequestClass := LParts[2];
        Result := LCoreAPI.CallMethodAPI(Request.Content, WebAction, Request, Response);
        TSecurityTransport.JSONResponse(Response, LCoreAPI.StatusCode, Result);
        if LCoreAPI.StatusCode = 429 then Response.SetCustomHeader('Retry-After', '60');
      finally
        FreeAndNil(LCoreAPI);
      end;
    finally
      FreeAndNil(LCon);
    end;
  except
    on E: EAuthPolicy do begin
      Result := THelperResponse.CreateResponse(E.Status, E.Message);
      TSecurityTransport.JSONResponse(Response, E.Status, Result);
    end;
    on E: ERequestInvalid do begin
      Result := THelperResponse.CreateResponse(E.Status, E.Message);
      TSecurityTransport.JSONResponse(Response, E.Status, Result);
    end;
    on E: Exception do begin
      THelperLogger.Error('HTTP dispatch', E);
      Result := THelperResponse.CreateResponse(500, 'Internal server error.');
      TSecurityTransport.JSONResponse(Response, 500, Result);
    end;
  end;
  finally
    THelperLogger.EndRequest;
  end;
end;

procedure TWM.WebModuleException(Sender: TObject; E: Exception; var Handled: Boolean);
begin
  Handled := True;
  THelperLogger.Error('WebModule', E);
  Response.SetCustomHeader('Cache-Control', 'no-store');
  TSecurityTransport.JSONResponse(Response, 500, THelperResponse.CreateResponse(500, 'Internal server error.'));
end;

procedure TWM.WebModule1DefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Handled := True;
  SendToCoreAPI(nil, Request, Response);
end;

procedure TWM.WebModuleCreate(Sender: TObject);
begin
end;

procedure TWM.WMapiAction(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
begin
  Handled := True;
  SendToCoreAPI(TWebActionItem(Sender), Request, Response, False);
end;

procedure TWM.WMHelloWorldAction(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
begin
  SendToCoreAPI(TWebActionItem(Sender), Request, Response, False);
  Handled := True;
end;

procedure TWM.WMimageAction(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
var
  LExtension: string;
  LFileName: string;
  LFilePath: string;
  LStream: TFileStream;
begin
  Handled := True;
  Response.ContentType := 'application/json';
  Response.ContentEncoding := '';

  if Request.MethodType <> mtGet then begin
    Response.StatusCode := 405;
    Response.Content := THelperResponse.CreateResponse(Response.StatusCode, 'Method Not Allowed');
    Exit;
  end;

  LFileName := Trim(Request.QueryFields.Values['filename']);
  if (LFileName = '') or (ExtractFileName(LFileName) <> LFileName) then begin
    Response.StatusCode := 400;
    Response.Content := THelperResponse.CreateResponse(Response.StatusCode, 'Invalid filename');
    Exit;
  end;

  LExtension := LowerCase(ExtractFileExt(LFileName));
  if not MatchText(LExtension, ['.jpg', '.jpeg', '.png', '.bmp']) then begin
    Response.StatusCode := 400;
    Response.Content := THelperResponse.CreateResponse(Response.StatusCode, 'Unsupported image type');
    Exit;
  end;

  LFilePath := TGlobalFunction.LoadFile(LFileName);
  if not FileExists(LFilePath) then begin
    Response.StatusCode := 404;
    Response.Content := THelperResponse.CreateResponse(Response.StatusCode, 'File not found');
    Exit;
  end;

  LStream := TFileStream.Create(LFilePath, fmOpenRead or fmShareDenyWrite);
  try
    if (LExtension = '.jpg') or (LExtension = '.jpeg') then Response.ContentType := 'image/jpeg'
    else if LExtension = '.png' then Response.ContentType := 'image/png'
    else Response.ContentType := 'image/bmp';
    Response.ContentStream := LStream;
    LStream := nil;
    TInterlocked.Increment(COUNTER_HIT_REQUEST);
  finally
    FreeAndNil(LStream);
  end;
end;

procedure TWM.WMtestAction(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
var
  LFileName : String;
  LFolderOriginal : String;
  LOutputMessage : String;
begin
  Writeln('Oke Oce');
  if Request.MethodType = mtGet then
    Response.Content := Request.RawPathInfo + sLineBreak + Request.QueryFields.Values['param'];
//    else Response.Content := Request.RawPathInfo + sLineBreak + Request.ContentFields.Values['param'];  //post multipart

  if Request.MethodType = mtPost then begin
    if Request.Files.Count > 0 then begin
      LFileName := TGlobalFunction.NewUUIDCompact + ExtractFileExt(Request.Files[0].FileName);
      LFolderOriginal := ExtractFilePath(TGlobalFunction.LoadFile(LFileName));
      THelperRequest.SaveFile(LFolderOriginal, LFileName, Request, LOutputMessage);
      Response.Content := LOutputMessage;
    end else
      Response.Content := 'No File';
  end;
end;

initialization
finalization
  Web.WebReq.FreeWebModules;

end.

