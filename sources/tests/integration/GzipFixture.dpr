program GzipFixture;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, Web.HTTPApp, Web.WebReq, Web.WebBroker,
  IdHTTPWebBrokerBridge, BFA.Core.Config, BFA.HTTP.Compression;

type
  TFixtureWebModule = class(TWebDispatcher)
  private
    procedure Handle(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
    procedure CompressResponse(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
  end;

constructor TFixtureWebModule.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  with Actions.Add do begin
    Default := True;
    OnAction := Handle;
  end;
  AfterDispatch := CompressResponse;
end;

procedure TFixtureWebModule.Handle(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
var
  I: Integer;
  LBody: TStringBuilder;
begin
  Handled := True;
  Response.StatusCode := 200;
  Response.ContentType := 'application/json; charset=utf-8';
  Response.ContentEncoding := '';
  LBody := TStringBuilder.Create;
  try
    LBody.Append('{"status":200,"messages":"OK","data":[');
    for I := 1 to 2305 do begin
      if I > 1 then LBody.Append(',');
      LBody.Append('{"customer_id":"fixture-').Append(I).Append(
        '","notes":"Pelanggan caf' + #$00E9 + ' ' + #$65E5#$672C#$8A9E +
        ' ' + #$2014 + ' alamat dan catatan fixture berulang."}');
    end;
    LBody.Append(']}');
    Response.Content := LBody.ToString;
  finally
    LBody.Free;
  end;

  if Request.PathInfo = '/small' then Response.Content := '{"message":"kecil"}';
  if Request.PathInfo = '/exact' then Response.Content := '{"text":"' + StringOfChar('A', 1013) + '"}';
  if Request.PathInfo = '/below' then Response.Content := '{"text":"' + StringOfChar('A', 1012) + '"}';
  if Request.PathInfo = '/unicode-threshold' then Response.Content := '{"text":"' + StringOfChar(#$00E9, 600) + '"}';
  if Request.PathInfo = '/empty' then Response.Content := '';
  if Request.PathInfo = '/error' then Response.StatusCode := 500;
  if Request.PathInfo = '/image' then Response.ContentType := 'image/png';
  if Request.PathInfo = '/already' then Response.ContentEncoding := 'br';
  if Request.PathInfo = '/no-transform' then Response.SetCustomHeader('Cache-Control', 'private, no-transform');
  if Request.PathInfo = '/etag' then Response.SetCustomHeader('ETag', '"fixture-original"');
  if Request.PathInfo = '/partial' then begin
    Response.StatusCode := 206;
    Response.SetCustomHeader('Content-Range', 'bytes 0-100/1000');
  end;
  if Request.PathInfo = '/no-content' then begin
    Response.StatusCode := 204;
    Response.Content := '';
  end;
  if Request.PathInfo = '/vary' then
    Response.SetCustomHeader('Vary', Request.GetFieldByName('X-Fixture-Vary'));
  if Request.PathInfo = '/stream' then begin
    Response.ContentStream := TStringStream.Create(Response.Content, TEncoding.UTF8);
    Response.FreeContentStream := True;
  end;
  if Request.PathInfo = '/sent' then Response.SendResponse;
end;

procedure TFixtureWebModule.CompressResponse(Sender: TObject; Request: TWebRequest;
  Response: TWebResponse; var Handled: Boolean);
begin
  if Handled then THTTPCompression.Apply(Request, Response);
end;

var
  LServer: TIdHTTPWebBrokerBridge;
  LCommand: string;
begin
  try
    if ParamStr(1) <> '--isolated-fixture' then
      raise Exception.Create('Use the isolated gzip test runner.');
    TServerConfig.Initialize;
    WebRequestHandler.WebModuleClass := TFixtureWebModule;
    LServer := TIdHTTPWebBrokerBridge.Create(nil);
    try
      LServer.DefaultPort := 0;
      with LServer.Bindings.Add do begin
        IP := '127.0.0.1';
        Port := 0;
      end;
      LServer.Active := True;
      Writeln('READY ', LServer.Bindings[0].Port);
      Flush(Output);
      Readln(LCommand);
    finally
      LServer.Free;
      Web.WebReq.FreeWebModules;
    end;
  except
    on E: Exception do begin
      Writeln('ERROR ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
