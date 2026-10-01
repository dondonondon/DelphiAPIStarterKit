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
  DB.ConnectionFactory;

//function TWM.AllowServerFunctionInvoker: Boolean;
//begin
//  Result := (Request.RemoteAddr = '127.0.0.1') or
//    (Request.RemoteAddr = '0:0:0:0:0:0:0:1') or (Request.RemoteAddr = '::1');
//end;

function TWM.SendToCoreAPI(WebAction: TWebActionItem;
  Request: TWebRequest; Response: TWebResponse; ACheckHeader: Boolean): String;
var
  LPath: string;
  LParts: TArray<string>;

  LResponse : String;
  LCoreAPI : TClassHelper;
begin
  Response.StatusCode := 404;
  Response.ContentType := 'application/json';
  Response.ContentEncoding := 'utf-8';

  LPath := Request.PathInfo.Trim(['/']);
  LParts := LPath.Split(['/']);
  if (Length(LParts) < 3) or (not SameText(LParts[0], 'api')) or
    (Trim(LParts[1]) = '') or (Trim(LParts[2]) = '') then begin
    Response.StatusCode := 404;
    Response.Content := THelperResponse.CreateResponse(Response.StatusCode, 'API route not found');
    Exit(Response.Content);
  end;

  var LCon := TDBConnectionFactory.GetConnection;
  LCoreAPI := TClassHelper.Create;
  try
    LCoreAPI.Connection := LCon;
    LCoreAPI.APIVersion := LParts[1];
    LCoreAPI.RequestClass := LParts[2];

    if Request.ContentType.StartsWith('multipart/form-data') then
      LResponse := LCoreAPI.CallMethodAPI('', WebAction, Request, Response) else
      LResponse := LCoreAPI.CallMethodAPI(Request.Content, WebAction, Request, Response);

    Response.StatusCode := LCoreAPI.StatusCode;
    Response.Content := LResponse;

  finally
    LCon.Free;
    LCoreAPI.Free;
  end;
end;

procedure TWM.WebModule1DefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Response.Content :=
    '<html>' +
    '<head><title>DataSnap Server</title></head>' +
    '<body>DataSnap Server</body>' +
    '</html>';
end;

procedure TWM.WebModuleCreate(Sender: TObject);
begin
end;

procedure TWM.WMapiAction(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
begin
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
  Response.ContentEncoding := 'utf-8';

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
    if (LExtension = '.jpg') or (LExtension = '.jpeg') then
      Response.ContentType := 'image/jpeg'
    else if LExtension = '.png' then
      Response.ContentType := 'image/png'
    else
      Response.ContentType := 'image/bmp';

    Response.ContentStream := LStream;
    Response.SendResponse;
    Response.ContentStream := nil;
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

