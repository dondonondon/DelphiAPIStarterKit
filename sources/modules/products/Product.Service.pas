unit Product.Service;

interface

uses
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp,
  Product.Repository, Auth.Repository;

type
  TProductService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FRequest: TWebRequest;
    FSecurity: TAuthRepository;
    FData: TFDMemTable;
    FParts: TArray<string>;
    FRepository: TProductRepository;
    FStatusCode: Integer;

    function ExtractRouteProductID(out AProductID: string;
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
  System.Variants,
  Data.DB,
  BFA.Core.Response,
  BFA.Helper.Strings,
  BFA.Helper.Transaction,
  Product.DTO,
  Product.Validator;

constructor TProductService.Create(AConnection: TFDConnection;
  AData: TFDMemTable; ARequest: TWebRequest; const AParts: TArray<string>);
begin
  inherited Create;
  FConnection := AConnection;
  FRequest := ARequest;
  FSecurity := TAuthRepository.Create(FConnection);
  FData := AData;
  FParts := AParts;
  FStatusCode := 500;
  FRepository := TProductRepository.Create(FConnection);
end;

function TProductService.Delete: string;
var LID, LMessage: string; LQuery: TFDQuery; LRows: Integer;
begin
  if not ExtractRouteProductID(LID, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  BeginMutation('products.delete');
  try
    LQuery := FRepository.FindProductByID(LID, True);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Product not found.');
    finally
      FreeAndNil(LQuery);
    end;
    LRows := FRepository.SoftDeleteProduct(LID);
    if LRows <> 1 then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
  FStatusCode := 200;
  Result := THelperResponse.CreateResponse(200, 'Product deleted.');
end;

destructor TProductService.Destroy;
begin
  FreeAndNil(FRepository);
  FreeAndNil(FSecurity);
  inherited;
end;

function TProductService.ExtractRouteProductID(out AProductID,
  AMessage: string): Boolean;
begin
  Result := False;
  AProductID := '';

  if Length(FParts) >= 4 then
    AProductID := Trim(FParts[3]);

  if AProductID = '' then begin
    AMessage := 'Product ID required';
    Exit;
  end;

  if Length(AProductID) > 36 then begin
    AMessage := 'Invalid product ID';
    Exit;
  end;

  Result := True;
end;

function TProductService.Get: string;
var
  LDataset: TFDQuery;
  LProductID: string;
begin
  LProductID := '';
  if Length(FParts) >= 4 then
    LProductID := Trim(FParts[3]);

  LDataset := FRepository.GetProducts(LProductID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Product not found', FData));
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'OK', LDataset, FData);
  finally
    FreeAndNil(LDataset);
  end;
end;

function TProductService.Insert: string;
var LID, LMessage: string; LRequest: TProductCreateRequest; LRows: Integer; LCategory: Variant; LQuery: TFDQuery;
begin
  if not TProductValidator.ValidateCreate(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  LID := TGlobalFunction.NewDatabaseUUID;
  BeginMutation('products.create');
  try
    LCategory := Null;
    if LRequest.HasCategoryID and (LRequest.CategoryID <> '') then begin
      LQuery := FRepository.FindCategoryByID(LRequest.CategoryID, True);
      try
        if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Active category not found.');
        LCategory := LQuery.FieldByName('id').AsLargeInt;
      finally
        FreeAndNil(LQuery);
      end;
    end;
    LRows := FRepository.CreateProduct(LID, LRequest, LCategory);
    if LRows <> 1 then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    Result := Reply(LID, 201, 'Product created.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
end;

procedure TProductService.BeginMutation(const APermission: string);
begin
  FSecurity.BeginAuthorizedTransaction(TSecurityToken.ExtractAccessToken(FRequest), APermission);
end;

function TProductService.Reply(const AID: string; AStatus: Integer; const AMessage: string): string;
var LQuery: TFDQuery;
begin
  LQuery := FRepository.GetProducts(AID);
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Product not found.');
    FStatusCode := AStatus;
    Result := THelperResponse.CreateResponse(AStatus, AMessage, LQuery);
  finally
    FreeAndNil(LQuery);
  end;
end;

function TProductService.Update: string;
var LID, LMessage: string; LRequest: TProductUpdateRequest; LRows: Integer; LQuery: TFDQuery; LCategory: Variant;
begin
  if not TProductValidator.ValidateUpdate(FData, FParts, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  LID := LRequest.ProductID;
  BeginMutation('products.update');
  try
    LQuery := FRepository.FindProductByID(LID, True);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Product not found.');
    finally
      FreeAndNil(LQuery);
    end;
    LCategory := Null;
    if LRequest.HasCategoryID and (LRequest.CategoryID <> '') then begin
      LQuery := FRepository.FindCategoryByID(LRequest.CategoryID, True);
      try
        if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Active category not found.');
        LCategory := LQuery.FieldByName('id').AsLargeInt;
      finally
        FreeAndNil(LQuery);
      end;
    end;
    LRows := FRepository.UpdateProduct(LRequest, LCategory);
    if (LRows < 0) or (LRows > 1) then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    Result := Reply(LID, 200, 'Product updated.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
end;

end.
