unit Customer.Service;

interface

uses
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp,
  Customer.Repository, Auth.Repository;

type
  TCustomerService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FRequest: TWebRequest;
    FSecurity: TAuthRepository;
    FData: TFDMemTable;
    FParts: TArray<string>;
    FRepository: TCustomerRepository;
    FStatusCode: Integer;

    function ExtractRouteCustomerID(out ACustomerID: string;
      out AMessage: string): Boolean;
    procedure BeginMutation(const APermission: string);
    function Reply(const AID: string; AStatus: Integer; const AMessage: string): string;
  public
    constructor Create(AConnection: TFDConnection; AData: TFDMemTable;
      ARequest: TWebRequest; const AParts: TArray<string>);
    destructor Destroy; override;

    property StatusCode: Integer read FStatusCode;

  published
    function Delete: string;
    function Get: string;
    function Insert: string;
    function Update: string;
  end;

implementation

uses
  System.SysUtils, Auth.Policy, BFA.Security.Token,
  Data.DB,
  BFA.Core.Response,
  BFA.Helper.Strings,
  BFA.Helper.Transaction,
  Customer.DTO,
  Customer.Validator;

constructor TCustomerService.Create(AConnection: TFDConnection;
  AData: TFDMemTable; ARequest: TWebRequest; const AParts: TArray<string>);
begin
  inherited Create;
  FConnection := AConnection;
  FRequest := ARequest;
  FSecurity := TAuthRepository.Create(FConnection);
  FData := AData;
  FParts := AParts;
  FStatusCode := 500;
  FRepository := TCustomerRepository.Create(FConnection);
end;

function TCustomerService.Delete: string;
var LID, LMessage: string; LQuery: TFDQuery; LRows: Integer;
begin
  if not ExtractRouteCustomerID(LID, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  BeginMutation('customers.delete');
  try
    LQuery := FRepository.FindCustomerByID(LID, True);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Customer not found.');
    finally
      FreeAndNil(LQuery);
    end;
    LRows := FRepository.SoftDeleteCustomer(LID);
    if LRows <> 1 then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
  FStatusCode := 200;
  Result := THelperResponse.CreateResponse(200, 'Customer deleted.');
end;

destructor TCustomerService.Destroy;
begin
  FreeAndNil(FRepository);
  FreeAndNil(FSecurity);
  inherited;
end;

function TCustomerService.ExtractRouteCustomerID(out ACustomerID,
  AMessage: string): Boolean;
begin
  Result := False;
  ACustomerID := '';

  if Length(FParts) >= 4 then
    ACustomerID := Trim(FParts[3]);

  if ACustomerID = '' then begin
    AMessage := 'Customer ID required';
    Exit;
  end;

  if Length(ACustomerID) > 36 then begin
    AMessage := 'Invalid customer ID';
    Exit;
  end;

  Result := True;
end;

function TCustomerService.Get: string;
var
  LCustomerID: string;
  LDataset: TFDQuery;
begin
  LCustomerID := '';
  if Length(FParts) >= 4 then
    LCustomerID := Trim(FParts[3]);

  LDataset := FRepository.GetCustomers(LCustomerID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Customer not found', FData));
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'OK', LDataset, FData);
  finally
    FreeAndNil(LDataset);
  end;
end;

function TCustomerService.Insert: string;
var LID, LMessage: string; LRequest: TCustomerCreateRequest; LRows: Integer;
begin
  if not TCustomerValidator.ValidateCreate(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  LID := TGlobalFunction.NewDatabaseUUID;
  BeginMutation('customers.create');
  try
    LRows := FRepository.CreateCustomer(LID, LRequest);
    if LRows <> 1 then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    Result := Reply(LID, 201, 'Customer created.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
end;

procedure TCustomerService.BeginMutation(const APermission: string);
begin
  FSecurity.BeginAuthorizedTransaction(TSecurityToken.ExtractAccessToken(FRequest), APermission);
end;

function TCustomerService.Reply(const AID: string; AStatus: Integer; const AMessage: string): string;
var LQuery: TFDQuery;
begin
  LQuery := FRepository.GetCustomers(AID);
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Customer not found.');
    FStatusCode := AStatus;
    Result := THelperResponse.CreateResponse(AStatus, AMessage, LQuery);
  finally
    FreeAndNil(LQuery);
  end;
end;

function TCustomerService.Update: string;
var LID, LMessage: string; LRequest: TCustomerUpdateRequest; LRows: Integer; LQuery: TFDQuery;
begin
  if not TCustomerValidator.ValidateUpdate(FData, FParts, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  LID := LRequest.CustomerID;
  BeginMutation('customers.update');
  try
    LQuery := FRepository.FindCustomerByID(LID, True);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Customer not found.');
    finally
      FreeAndNil(LQuery);
    end;
    LRows := FRepository.UpdateCustomer(LRequest);
    if (LRows < 0) or (LRows > 1) then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    Result := Reply(LID, 200, 'Customer updated.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
end;

end.
