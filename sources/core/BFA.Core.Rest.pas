unit BFA.Core.Rest;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp;

type
  TExecAPI = function(Connection: TFDConnection; AData: TFDMemTable; AWebAction: TWebActionItem;
    ARequest: TWebRequest; AResponse: TWebResponse; out AStatusCode: Integer): string of object;

  TClassHelper = class
  private
    FStatusCode: Integer;
    FConnection: TFDConnection;
    FRequestMethod: string;
    FRequestClass: string;
    FAPIVersion: string;

    function BuildClassName: string; inline;
    function LoadRequestData(const AJSON: string): TFDMemTable;
    function ResolveAPIClass(out AClass: TPersistentClass): Boolean;

    function InvokeRouteMethod(AInstance: TObject; AData: TFDMemTable; AWebAction: TWebActionItem;
      ARequest: TWebRequest; AResponse: TWebResponse; out AStatusCode: Integer): string;

    function DispatchAPICall(const AJSON: string; AWebAction: TWebActionItem; ARequest: TWebRequest;
      AResponse: TWebResponse; out AStatusCode: Integer): string;
  public
    function BuildErrorResponse(ACode: Integer; const AMessage: string): string;

    property Connection: TFDConnection read FConnection write FConnection;
    property APIVersion: string read FAPIVersion write FAPIVersion;
    property StatusCode: Integer read FStatusCode write FStatusCode;
    property RequestClass: string read FRequestClass write FRequestClass;
    property RequestMethod: string read FRequestMethod write FRequestMethod;

    constructor Create;
    destructor Destroy; override;

    function CallMethodAPI(const AJSON: string; AWebAction: TWebActionItem; ARequest: TWebRequest;
      AResponse: TWebResponse): string;
  end;

procedure RegisterClassAPI; overload;
procedure RegisterClassAPI(const AClasses: array of TPersistentClass); overload;

const
  STATUS_NOT_FOUND       = 404;
  STATUS_INTERNAL_ERROR  = 500;

  MSG_CLASS_NOT_FOUND    = 'Class not found!';
  MSG_METHOD_NOT_FOUND   = 'Method not found!';
  MSG_INTERNAL_ERROR     = 'Internal server error.';
  MSG_NO_MESSAGES        = 'No Messages';

  CLASS_PREFIX           = 'TRestClass';
  ROUTE_METHOD_NAME      = 'Route';

implementation

uses
  System.JSON,
  System.DateUtils,
  System.IOUtils,
  System.StrUtils,
  Data.DB,
  DBClient,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Phys.MSSQL,
  FireDAC.Phys.MSSQLDef,
  Web.ReqMulti,
  Web.WebFileDispatcher,
  Web.HTTPProd,
  BFA.Helper.Dataset,
  BFA.Core.Response,
  RestAPI.User,
  RestAPI.Auth,
  RestAPI.Product,
  RestAPI.Category,
  RestAPI.Customer;

procedure WriteCoreErrorLog(const ASource: string; AException: Exception);
var
  LFileName: string;
  LMessage: string;
begin
  LFileName := TPath.Combine(ExtractFilePath(ParamStr(0)), 'server-error.log');
  LMessage := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
    ' ' + ASource + ': ' + AException.ClassName + ': ' + AException.Message + sLineBreak;
  TFile.AppendAllText(LFileName, LMessage, TEncoding.UTF8);
end;

constructor TClassHelper.Create;
begin
end;

destructor TClassHelper.Destroy;
begin
  inherited;
end;

function TClassHelper.CallMethodAPI(const AJSON: string; AWebAction: TWebActionItem;
  ARequest: TWebRequest; AResponse: TWebResponse): string;
var
  LStatusCode: Integer;
begin
  LStatusCode := STATUS_NOT_FOUND;

  Result := DispatchAPICall(AJSON, AWebAction, ARequest, AResponse, LStatusCode);
  StatusCode := LStatusCode;
end;

function TClassHelper.BuildErrorResponse(ACode: Integer; const AMessage: string): string;
var
  LJSON: TJSONObject;
  LDataArray: TJSONArray;
begin
  StatusCode := ACode;

  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('status', TJSONNumber.Create(ACode));
    LJSON.AddPair('messages', AMessage);
    LJSON.AddPair('servertime', IntToStr(DateTimeToUnix(Now)));

    LDataArray := TJSONArray.Create;
    LDataArray.Add(TJSONObject.Create);
    LJSON.AddPair('data', LDataArray);

    Result := LJSON.ToJSON;
  finally
    FreeAndNil(LJSON);
  end;
end;

function TClassHelper.BuildClassName: string;
begin
  Result := CLASS_PREFIX + FAPIVersion + FRequestClass;
end;

function TClassHelper.LoadRequestData(const AJSON: string): TFDMemTable;
begin
  Result := TFDMemTable.Create(nil);
  try
    if AJSON <> '' then
      Result.LoadFromJSON(AJSON);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TClassHelper.ResolveAPIClass(out AClass: TPersistentClass): Boolean;
var
  LClassName: string;
begin
  LClassName := BuildClassName;
  AClass := FindClass(LClassName);
  Result := Assigned(AClass);
end;

function TClassHelper.InvokeRouteMethod(AInstance: TObject; AData: TFDMemTable;
  AWebAction: TWebActionItem; ARequest: TWebRequest; AResponse: TWebResponse;
  out AStatusCode: Integer): string;
var
  LRoutine: TMethod;
  LExec: TExecAPI;
begin

  LRoutine.Data := AInstance;
  LRoutine.Code := AInstance.MethodAddress(ROUTE_METHOD_NAME);

  if not Assigned(LRoutine.Code) then
  begin
    AStatusCode := STATUS_NOT_FOUND;
    Exit(BuildErrorResponse(AStatusCode, MSG_METHOD_NOT_FOUND));
  end;

  LExec := TExecAPI(LRoutine);
  Result := LExec(FConnection, AData, AWebAction, ARequest, AResponse, AStatusCode);
end;

function TClassHelper.DispatchAPICall(const AJSON: string; AWebAction: TWebActionItem;
  ARequest: TWebRequest; AResponse: TWebResponse; out AStatusCode: Integer): string;
var
  LDataRequest: TFDMemTable;
  LClass: TPersistentClass;
  LInstance: TObject;
begin
  AStatusCode := STATUS_NOT_FOUND;

  LDataRequest := nil;
  try
    try
      LDataRequest := LoadRequestData(AJSON);
    except
      on E: Exception do
      begin
        WriteCoreErrorLog('Core request data error', E);
        AStatusCode := STATUS_INTERNAL_ERROR;
        Exit(BuildErrorResponse(AStatusCode, MSG_INTERNAL_ERROR));
      end;
    end;

    try
      if not ResolveAPIClass(LClass) then
      begin
        AStatusCode := STATUS_NOT_FOUND;
        Exit(BuildErrorResponse(AStatusCode, MSG_CLASS_NOT_FOUND));
      end;

      LInstance := LClass.Create;
      try
        Result := InvokeRouteMethod(LInstance, LDataRequest, AWebAction, ARequest, AResponse, AStatusCode);
      finally
        FreeAndNil(LInstance);
      end;
    except
      on E: Exception do
      begin
        WriteCoreErrorLog('Core dispatch error', E);
        AStatusCode := STATUS_INTERNAL_ERROR;
        Result := BuildErrorResponse(AStatusCode, MSG_INTERNAL_ERROR);
      end;
    end;
  finally
    FreeAndNil(LDataRequest);
  end;
end;

procedure RegisterClassAPI;
begin
  RegisterClassAPI([TRestClassV1User, TRestClassV1Auth, TRestClassV1Product,
    TRestClassV1Category, TRestClassV1Customer]);
end;

procedure RegisterClassAPI(const AClasses: array of TPersistentClass);
begin
  RegisterClasses(AClasses);
end;

end.
