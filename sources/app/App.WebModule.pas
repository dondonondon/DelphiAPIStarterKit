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
    procedure WebModuleAfterDispatch(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
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

uses System.Diagnostics, Web.WebReq, BFA.Core.Rest, BFA.Core.Response, uDM,
  BFA.Helper.Strings, BFA.Core.Config, BFA.Core.Request,
  BFA.Core.Endpoint, BFA.HTTP.Compression,
  DB.ConnectionFactory;

var
  GRequestTimingEnabled: Boolean;
  GRequestTimingSequence: Int64;
  GRequestTimingFormatSettings: TFormatSettings;

function RequestTimingStamp: Int64;
begin
  Result := 0;
  try
    Result := TStopwatch.GetTimeStamp;
  except
    // Diagnostics must not interfere with request handling.
  end;
end;

function RequestTimingElapsed(AStartTicks: Int64): Int64;
begin
  Result := 0;
  try
    if AStartTicks > 0 then
      Result := TStopwatch.GetTimeStamp - AStartTicks;
    if Result < 0 then
      Result := 0;
  except
    Result := 0;
  end;
end;

function RequestTimingRoute(const AParts: TArray<string>): string;
const
  KNOWN_RESOURCES: array[0..5] of string =
    ('Auth', 'User', 'Product', 'Category', 'Customer', 'Sample');
var
  LVersion: string;
  LResource: string;
  LKnownResource: string;
begin
  LVersion := '{version}';
  LResource := '{resource}';
  if (Length(AParts) > 1) and SameText(AParts[1], 'v1') then
    LVersion := 'v1';
  if Length(AParts) > 2 then
    for LKnownResource in KNOWN_RESOURCES do
      if SameText(AParts[2], LKnownResource) then begin
        LResource := LKnownResource;
        Break;
      end;
  Result := '/api/' + LVersion + '/' + LResource;
  if Length(AParts) > 3 then
    Result := Result + '/{id}';
end;

procedure WriteRequestTiming(ARequestID, AConnectionTicks, ADispatchTicks,
  APrepareTicks, ATotalTicks: Int64; const AParts: TArray<string>;
  AResponse: TWebResponse; AFailed: Boolean);
var
  LStatusCode: Integer;
begin
  try
    if AFailed then
      LStatusCode := 500
    else
      LStatusCode := AResponse.StatusCode;
    THelperEndpoint.WriteConsoleLog(Format(
      'API request timing: request_id=%d route=%s status=%d connection_ms=%.3f ' +
      'dispatch_ms=%.3f response_prepare_ms=%.3f total_ms=%.3f',
      [ARequestID, RequestTimingRoute(AParts), LStatusCode,
       AConnectionTicks * 1000.0 / TStopwatch.Frequency,
       ADispatchTicks * 1000.0 / TStopwatch.Frequency,
       APrepareTicks * 1000.0 / TStopwatch.Frequency,
       ATotalTicks * 1000.0 / TStopwatch.Frequency], GRequestTimingFormatSettings));
  except
    // Formatting/logging failures must preserve the response and any active exception.
  end;
end;

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
  LTimingActive: Boolean;
  LRequestID: Int64;
  LStartTicks: Int64;
  LPhaseStartTicks: Int64;
  LConnectionTicks: Int64;
  LDispatchTicks: Int64;
  LPrepareTicks: Int64;
  LRequestFailed: Boolean;
begin
  LRequestID := 0;
  LStartTicks := 0;
  LPhaseStartTicks := 0;
  LConnectionTicks := 0;
  LDispatchTicks := 0;
  LPrepareTicks := 0;
  LRequestFailed := False;
  LTimingActive := GRequestTimingEnabled;
  if LTimingActive then begin
    try
      LRequestID := TInterlocked.Increment(GRequestTimingSequence);
      LStartTicks := RequestTimingStamp;
    except
      LTimingActive := False;
    end;
  end;

  try
    try
      Response.StatusCode := 404;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.ContentEncoding := '';

      LPath := Request.PathInfo.Trim(['/']);
      LParts := LPath.Split(['/']);
      if (Length(LParts) < 3) or (not SameText(LParts[0], 'api')) or
        (Trim(LParts[1]) = '') or (Trim(LParts[2]) = '') then begin
        if LTimingActive then
          LPhaseStartTicks := RequestTimingStamp;
        try
          Response.StatusCode := 404;
          Response.Content := THelperResponse.CreateResponse(Response.StatusCode, 'API route not found');
        finally
          if LTimingActive then
            LPrepareTicks := RequestTimingElapsed(LPhaseStartTicks);
        end;
        Exit(Response.Content);
      end;

      var LCon: TFDConnection;
      if LTimingActive then
        LPhaseStartTicks := RequestTimingStamp;
      try
        LCon := TDBConnectionFactory.GetConnection;
      finally
        if LTimingActive then
          LConnectionTicks := RequestTimingElapsed(LPhaseStartTicks);
      end;
      try
        LCoreAPI := TClassHelper.Create;
        try
          if LTimingActive then
            LPhaseStartTicks := RequestTimingStamp;
          try
            LCoreAPI.Connection := LCon;
            LCoreAPI.APIVersion := LParts[1];
            LCoreAPI.RequestClass := LParts[2];

            if Request.ContentType.StartsWith('multipart/form-data') then
              LResponse := LCoreAPI.CallMethodAPI('', WebAction, Request, Response) else
              LResponse := LCoreAPI.CallMethodAPI(Request.Content, WebAction, Request, Response);
          finally
            if LTimingActive then
              LDispatchTicks := RequestTimingElapsed(LPhaseStartTicks);
          end;

          if LTimingActive then
            LPhaseStartTicks := RequestTimingStamp;
          try
            Response.StatusCode := LCoreAPI.StatusCode;
            Response.Content := LResponse;
          finally
            if LTimingActive then
              LPrepareTicks := RequestTimingElapsed(LPhaseStartTicks);
          end;
        finally
          LCoreAPI.Free;
        end;
      finally
        LCon.Free;
      end;
    except
      if LTimingActive then
        LRequestFailed := True;
      raise;
    end;
  finally
    if LTimingActive then
      // Stops after cleanup, before console output; WebBroker HTTP send is outside this scope.
      WriteRequestTiming(LRequestID, LConnectionTicks, LDispatchTicks,
        LPrepareTicks, RequestTimingElapsed(LStartTicks), LParts, Response, LRequestFailed);
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

procedure TWM.WebModuleAfterDispatch(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
var
  LStartTicks: Int64;
  LRoute: string;
begin
  if not Handled then Exit;
  LStartTicks := 0;
  if GRequestTimingEnabled then
    LStartTicks := RequestTimingStamp;
  try
    THTTPCompression.Apply(Request, Response);
  except
    on E: Exception do
      THelperEndpoint.WriteErrorLog('HTTP compression error', E);
  end;
  if GRequestTimingEnabled then begin
    try
      LRoute := RequestTimingRoute(Request.PathInfo.Trim(['/']).Split(['/']));
      THelperEndpoint.WriteConsoleLog(Format(
        'HTTP compression timing: route=%s status=%d compression_ms=%.3f content_encoding=%s content_bytes=%d',
        [LRoute, Response.StatusCode,
         RequestTimingElapsed(LStartTicks) * 1000.0 / TStopwatch.Frequency,
         Response.ContentEncoding, Response.ContentLength], GRequestTimingFormatSettings));
    except
      // Diagnostics must not change the prepared response.
    end;
  end;
end;

procedure TWM.WMapiAction(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
begin
  try
    SendToCoreAPI(TWebActionItem(Sender), Request, Response, False);
  except
    on E: Exception do begin
      THelperEndpoint.WriteErrorLog('API request error: ' + Request.Method +
        ' ' + Request.PathInfo, E);
      Response.StatusCode := 500;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.ContentEncoding := '';
      Response.Content := THelperResponse.CreateResponse(Response.StatusCode,
        'Internal server error.');
      Handled := True;
    end;
  end;
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
  Response.ContentType := 'application/json; charset=utf-8';
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
  GRequestTimingEnabled := Trim(GetEnvironmentVariable('DELPHI_API_REQUEST_TIMING')) = '1';
  GRequestTimingFormatSettings := TFormatSettings.Invariant;

finalization
  Web.WebReq.FreeWebModules;

end.

