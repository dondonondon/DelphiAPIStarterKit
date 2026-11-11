program DelphiAPIStarterKit;
{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  IPPeerServer,
  IPPeerAPI,
  IdHTTPWebBrokerBridge,
  BFA.HTTP.Server in 'sources\infrastructure\http\BFA.HTTP.Server.pas',
  Web.WebReq,
  Web.WebBroker,
  App.WebModule in 'sources\app\App.WebModule.pas' {WM: TWebModule},
  BFA.Core.Constants in 'sources\core\BFA.Core.Constants.pas',
  BFA.Helper.Strings in 'sources\shared\helpers\BFA.Helper.Strings.pas',
  BFA.Helper.Validator in 'sources\shared\helpers\BFA.Helper.Validator.pas',
  BFA.Helper.Transaction in 'sources\shared\helpers\BFA.Helper.Transaction.pas',
  uDM in 'uDM.pas' {DM: TDataModule},
  BFA.Core.Request in 'sources\core\BFA.Core.Request.pas',
  RestAPI.Sample in 'sources\modules\sample\RestAPI.Sample.pas',
  RestAPI.Auth in 'sources\modules\auth\RestAPI.Auth.pas',
  BFA.Helper.Dataset in 'sources\shared\helpers\BFA.Helper.Dataset.pas',
  BFA.Core.Messages in 'sources\core\BFA.Core.Messages.pas',
  BFA.Core.Response in 'sources\core\BFA.Core.Response.pas',
  BFA.Core.Rest in 'sources\core\BFA.Core.Rest.pas',
  BFA.Core.Endpoint in 'sources\core\BFA.Core.Endpoint.pas',
  BFA.Core.Config in 'sources\core\BFA.Core.Config.pas',
  BFA.HTTP.Compression in 'sources\infrastructure\http\BFA.HTTP.Compression.pas',
  RestAPI.User in 'sources\modules\users\RestAPI.User.pas',
  DB.ConnectionFactory in 'sources\infrastructure\database\DB.ConnectionFactory.pas',
  DB.Helper.Query in 'sources\infrastructure\database\DB.Helper.Query.pas',
  Auth.DTO in 'sources\modules\auth\Auth.DTO.pas',
  Auth.Repository in 'sources\modules\auth\Auth.Repository.pas',
  Auth.Service in 'sources\modules\auth\Auth.Service.pas',
  Auth.Validator in 'sources\modules\auth\Auth.Validator.pas',
  User.DTO in 'sources\modules\users\User.DTO.pas',
  User.Repository in 'sources\modules\users\User.Repository.pas',
  User.Service in 'sources\modules\users\User.Service.pas',
  User.Validator in 'sources\modules\users\User.Validator.pas',
  RestAPI.Product in 'sources\modules\products\RestAPI.Product.pas',
  Product.DTO in 'sources\modules\products\Product.DTO.pas',
  Product.Repository in 'sources\modules\products\Product.Repository.pas',
  Product.Service in 'sources\modules\products\Product.Service.pas',
  Product.Validator in 'sources\modules\products\Product.Validator.pas',
  RestAPI.Category in 'sources\modules\category\RestAPI.Category.pas',
  Category.DTO in 'sources\modules\category\Category.DTO.pas',
  Category.Repository in 'sources\modules\category\Category.Repository.pas',
  Category.Service in 'sources\modules\category\Category.Service.pas',
  Category.Validator in 'sources\modules\category\Category.Validator.pas',
  RestAPI.Customer in 'sources\modules\customers\RestAPI.Customer.pas',
  Customer.DTO in 'sources\modules\customers\Customer.DTO.pas',
  Customer.Repository in 'sources\modules\customers\Customer.Repository.pas',
  Customer.Service in 'sources\modules\customers\Customer.Service.pas',
  Customer.Validator in 'sources\modules\customers\Customer.Validator.pas',
  BFA.Core.Helper in 'sources\core\BFA.Core.Helper.pas',
  BFA.Security.Token in 'sources\infrastructure\security\BFA.Security.Token.pas';

{$R *.res}

procedure TerminateThreads;
begin
end;

function BindPort(APort: Integer): Boolean;
var
  LTestServer: IIPTestServer;
begin
  Result := True;
  try
    LTestServer := PeerFactory.CreatePeer('', IIPTestServer) as IIPTestServer;
    LTestServer.TestOpenPort(APort, nil);
  except
    Result := False;
  end;
end;

function CheckPort(APort: Integer): Integer;
begin
  if BindPort(APort) then
    Result := APort
  else
    Result := 0;
end;

procedure SetPort(const AServer: TIdHTTPWebBrokerBridge; APort: String);
begin
  if not AServer.Active then
  begin
    APort := APort.Replace(cCommandSetPort, '').Trim;
    if CheckPort(APort.ToInteger) > 0 then
    begin
      AServer.DefaultPort := APort.ToInteger;
      Writeln(Format(sPortSet, [APort]));
    end
    else
      Writeln(Format(sPortInUse, [APort]));
  end
  else
    Writeln(sServerRunning);
  Write(cArrow);
end;

procedure StartServer(const AServer: TIdHTTPWebBrokerBridge);
begin
  if not AServer.Active then
  begin
    if CheckPort(AServer.DefaultPort) > 0 then
    begin
      Writeln(Format(sStartingServer, [AServer.DefaultPort]));
      AServer.Bindings.Clear;
      AServer.Active := True;
    end
    else
      Writeln(Format(sPortInUse, [AServer.DefaultPort.ToString]));
  end
  else
    Writeln(sServerRunning);
  Write(cArrow);
end;

procedure StopServer(const AServer: TIdHTTPWebBrokerBridge);
begin
  if AServer.Active then
  begin
    Writeln(sStoppingServer);
    TerminateThreads;
    AServer.Active := False;
    AServer.Bindings.Clear;
    Writeln(sServerStopped);
  end
  else
    Writeln(sServerNotRunning);
  Write(cArrow);
end;

procedure WriteCommands;
begin
  Writeln(sCommands);
  Write(cArrow);
end;

procedure WriteStatus(const AServer: TIdHTTPWebBrokerBridge);
begin
  Writeln(sIndyVersion + AServer.SessionList.Version);
  Writeln(sActive + AServer.Active.ToString(TUseBoolStrs.True));
  Writeln(sPort + AServer.DefaultPort.ToString);
  Writeln(sSessionID + AServer.SessionIDCookieName);
  Write(cArrow);
end;

//procedure RunServer(APort: Integer);
//var
//  LServer: TIdHTTPWebBrokerBridge;
//  LResponse: string;
//begin
//  WriteCommands;
//  LServer := TIdHTTPWebBrokerBridge.Create(nil);
//  try
//    LServer.DefaultPort := APort;
//    while True do
//    begin
//      Readln(LResponse);
//      LResponse := LowerCase(LResponse);
//      if LResponse.StartsWith(cCommandSetPort) then
//        SetPort(LServer, LResponse)
//      else if sametext(LResponse, cCommandStart) then
//        StartServer(LServer)
//      else if sametext(LResponse, cCommandStatus) then
//        WriteStatus(LServer)
//      else if sametext(LResponse, cCommandStop) then
//        StopServer(LServer)
//      else if sametext(LResponse, cCommandHelp) then
//        WriteCommands
//      else if sametext(LResponse, cCommandExit) then
//        if LServer.Active then
//        begin
//          StopServer(LServer);
//          break
//        end
//        else
//          break
//      else
//      begin
//        Writeln(sInvalidCommand);
//        Write(cArrow);
//      end;
//    end;
//    TerminateThreads();
//  finally
//    LServer.Free;
//  end;
//end;

procedure RunServer(APort: Integer);
var
  FormatBr: TFormatSettings;
  LServer: TBoundedHTTPWebBrokerBridge;
  LVendorLib: string;
  LVendorHome: string;
  LMaxConcurrentRequests: Integer;
//  LServer : TsgcWSHTTPWebBrokerBridgeServer;
begin

  FormatBr                     := TFormatSettings.Create;
  FormatBr.DecimalSeparator    := '.';
  FormatBr.ThousandSeparator   := ',';
  FormatBr.DateSeparator       := '-';
  FormatBr.TimeSeparator       := ':';
  FormatBr.ShortDateFormat     := 'yyyy-mm-dd';
  FormatBr.LongDateFormat      := 'yyyy-mm-dd hh:nn:ss';

  System.SysUtils.FormatSettings := FormatBr;

  TServerConfig.Initialize;
  if not TryStrToInt(TServerConfig.ReadString('HTTP', 'MaxConcurrentRequests', '64'),
    LMaxConcurrentRequests) or (LMaxConcurrentRequests < 1) then
    raise Exception.Create('HTTP MaxConcurrentRequests must be a positive integer.');
  if WebRequestHandler <> nil then
    WebRequestHandler.MaxConnections := LMaxConcurrentRequests;
  TGlobalFunction.InitializeSecurity;

  LServer := TBoundedHTTPWebBrokerBridge.Create(nil);
  DM := nil;
  try
    LServer.ConfigureRequestLimit(LMaxConcurrentRequests);
    DM := TDM.Create(nil);
    LServer.DefaultPort := APort;

    if CheckPort(APort) = 0 then
      raise Exception.CreateFmt('Port %d already in use', [APort]);

    TGlobalFunction.LoadFile('');
    {$IF DEFINED(LINUX)}
    LVendorHome := '';
    LVendorLib := '/usr/lib/x86_64-linux-gnu/libmysqlclient.so.21';
    if not FileExists(LVendorLib) then
      LVendorLib := '';
    {$ELSE}
    LVendorHome := ExtractFilePath(ExpandFileName(ParamStr(0)));
    LVendorLib := '';
    {$ENDIF}

    LVendorHome := TServerConfig.ReadString('Database', 'VendorHome', LVendorHome);
    LVendorLib := TServerConfig.ReadString('Database', 'VendorLib', LVendorLib);
    if Trim(GetEnvironmentVariable('DELPHI_API_DB_VENDOR_HOME')) <> '' then
      LVendorHome := Trim(GetEnvironmentVariable('DELPHI_API_DB_VENDOR_HOME'));
    if Trim(GetEnvironmentVariable('DELPHI_API_DB_VENDOR_LIB')) <> '' then
      LVendorLib := Trim(GetEnvironmentVariable('DELPHI_API_DB_VENDOR_LIB'));
    DM.FDPhysMySQLDriverLink.VendorHome := LVendorHome;
    DM.FDPhysMySQLDriverLink.VendorLib := LVendorLib;

    LServer.Bindings.Clear;
    LServer.Active := True;

    Writeln('Server started on port ', APort);
    Writeln('WebBroker concurrent request limit: ', LMaxConcurrentRequests);

    while True do
      Sleep(1000);

  finally
    TerminateThreads;
    LServer.Active := False;
    LServer.Free;
    DM.Free;
  end;
end;

begin
  try
    if WebRequestHandler <> nil then
      WebRequestHandler.WebModuleClass := WebModuleClass;
    RunServer(9999);
  except
    on E: Exception do begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end
end.
