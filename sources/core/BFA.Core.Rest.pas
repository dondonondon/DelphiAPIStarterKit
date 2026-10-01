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
    function LoadRequestData(ARequest: TWebRequest): TFDMemTable;
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
  RestAPI.Customer, RestAPI.Role, BFA.Logger, BFA.Core.Request;

procedure WriteCoreErrorLog(const ASource: string; AException: Exception);
begin
  THelperLogger.Error(ASource, AException);
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
begin
  StatusCode := ACode;
  Result := THelperResponse.CreateResponse(ACode, AMessage);
end;

function TClassHelper.BuildClassName: string;
begin
  Result := CLASS_PREFIX + FAPIVersion + FRequestClass;
end;

function TClassHelper.LoadRequestData(ARequest: TWebRequest): TFDMemTable;
var LBody: TJSONObject; LPair: TJSONPair; LName: string;
begin
  Result := TFDMemTable.Create(nil);
  LBody := nil;
  try
    try
    if SameText(FRequestClass, 'Auth') or SameText(FRequestClass, 'User') or SameText(FRequestClass, 'Role') then Exit;
    if SameText(ARequest.Method, 'POST') or SameText(ARequest.Method, 'PUT') then begin
      if SameText(FRequestClass, 'Product') then
        LBody := THelperRequest.JSONObject(ARequest, ['product_name','description','price','stock','category_id','is_active'])
      else if SameText(FRequestClass, 'Category') then
        LBody := THelperRequest.JSONObject(ARequest, ['category_name','description','is_active'])
      else if SameText(FRequestClass, 'Customer') then
        LBody := THelperRequest.JSONObject(ARequest, ['customer_name','email','phone_number','address_line1','address_line2',
          'city','state','postal_code','country','notes','is_active'])
      else raise ERequestInvalid.Create('Unsupported request body.');
      for LPair in LBody do begin
        LName := LPair.JsonString.Value;
        if LName = 'price' then begin
          if not (LPair.JsonValue is TJSONNumber) then raise ERequestInvalid.Create('price must be a number.');
        end else if (LName = 'stock') or (LName = 'is_active') then begin
          if not (LPair.JsonValue is TJSONNumber) then raise ERequestInvalid.Create('Integer required.');
        end else if (LName = 'category_id') and (LPair.JsonValue is TJSONNull) then Continue
        else if not (LPair.JsonValue is TJSONString) then raise ERequestInvalid.Create('String required.');
      end;
      THelperMemoryTable.CreateDataset(Result, LBody);
      THelperMemoryTable.FillDataset(Result, LBody);
    end else if ARequest.Content <> '' then begin
      raise ERequestInvalid.Create('This method does not accept a request body.');
    end;
  except
    FreeAndNil(Result);
    raise;
    end;
  finally
    FreeAndNil(LBody);
  end;
end;

function TClassHelper.ResolveAPIClass(out AClass: TPersistentClass): Boolean;
var
  LClassName: string;
begin
  LClassName := BuildClassName;
  AClass := GetClass(LClassName);
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
      LDataRequest := LoadRequestData(ARequest);
    except
      on E: ERequestInvalid do begin
        AStatusCode := E.Status;
        Exit(BuildErrorResponse(E.Status, E.Message));
      end;
      on E: Exception do begin
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
    TRestClassV1Category, TRestClassV1Customer, TRestClassV1Role]);
end;

procedure RegisterClassAPI(const AClasses: array of TPersistentClass);
begin
  RegisterClasses(AClasses);
end;

end.
