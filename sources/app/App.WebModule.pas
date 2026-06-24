unit App.WebModule;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, Web.HTTPApp,
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

uses Web.WebReq, BFA.Core.Rest, uDM,
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
  MemoryStream: TMemoryStream;
begin
  var LFileName := Request.QueryFields.Values['filename'];

  if FileExists(TGlobalFunction.LoadFile(LFileName)) then begin
    MemoryStream := TMemoryStream.Create;
    try
      MemoryStream.LoadFromFile(TGlobalFunction.LoadFile(LFileName));
      MemoryStream.Position := 0;
      Response.ContentStream := MemoryStream;
      Response.ContentType := 'image/jpeg';
      Response.SendResponse;
    finally
      Inc(COUNTER_HIT_REQUEST);
    end;
  end else begin
    Response.StatusCode := 404;
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

