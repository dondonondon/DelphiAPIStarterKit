unit Product.Service;

interface

uses
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp,
  Product.Repository;

type
  TProductService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FData: TFDMemTable;
    FParts: TArray<string>;
    FRepository: TProductRepository;
    FStatusCode: Integer;

    function ExtractRouteProductID(out AProductID: string;
      out AMessage: string): Boolean;
    function InternalServerError: string;
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
  System.SysUtils,
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
  FData := AData;
  FParts := AParts;
  FStatusCode := 500;
  FRepository := TProductRepository.Create(FConnection);
end;

function TProductService.Delete: string;
var
  LMessage: string;
  LProductID: string;
  LRowsAffected: Integer;
begin
  if not ExtractRouteProductID(LProductID, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  try
    FConnection.StartTransaction;
    try
      LRowsAffected := FRepository.SoftDeleteProduct(LProductID);
      if LRowsAffected = 0 then begin
        THelperTransaction.Rollback(FConnection);
        FStatusCode := 404;
        Exit(THelperResponse.CreateResponse(FStatusCode, 'Product not found', FData));
      end;
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'Product deleted', FData);
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

destructor TProductService.Destroy;
begin
  FreeAndNil(FRepository);
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
var
  LCategoryID: string;
  LCategoryInternalID: Variant;
  LCategoryName: string;
  LDataset: TFDQuery;
  LMessage: string;
  LProductID: string;
  LRequest: TProductCreateRequest;
  LResponseData: TStringList;
begin
  if not TProductValidator.ValidateCreate(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LProductID := TGlobalFunction.NewDatabaseUUID;
  LCategoryInternalID := Null;
  LCategoryID := '';
  LCategoryName := '';

  if LRequest.HasCategoryID and (LRequest.CategoryID <> '') then begin
    LDataset := FRepository.FindCategoryByID(LRequest.CategoryID);
    try
      if LDataset.IsEmpty then begin
        FStatusCode := 404;
        Exit(THelperResponse.CreateResponse(FStatusCode, 'Category not found', FData));
      end;

      LCategoryInternalID := LDataset.FieldByName('id').Value;
      LCategoryID := LDataset.FieldByName('category_id').AsString;
      LCategoryName := LDataset.FieldByName('category_name').AsString;
    finally
      FreeAndNil(LDataset);
    end;
  end;

  try
    FConnection.StartTransaction;
    try
      FRepository.CreateProduct(LProductID, LRequest, LCategoryInternalID);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    LResponseData := TProductDTO.CreateProductResponse(
      LProductID,
      LRequest.ProductName,
      LRequest.Description,
      LRequest.Price,
      LRequest.Stock,
      LCategoryID,
      LCategoryName,
      LRequest.IsActive
    );
    try
      FStatusCode := 201;
      Result := THelperResponse.CreateResponse(FStatusCode, 'Product created', LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

function TProductService.InternalServerError: string;
begin
  FStatusCode := 500;
  Result := THelperResponse.CreateResponse(FStatusCode, 'Internal server error.', FData);
end;

function TProductService.Update: string;
var
  LCategoryID: string;
  LCategoryInternalID: Variant;
  LCategoryName: string;
  LDataset: TFDQuery;
  LDescription: string;
  LIsActive: Integer;
  LMessage: string;
  LPrice: Currency;
  LProductName: string;
  LRequest: TProductUpdateRequest;
  LResponseData: TStringList;
  LStock: Integer;
begin
  if not TProductValidator.ValidateUpdate(FData, FParts, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LDataset := FRepository.FindProductByID(LRequest.ProductID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Product not found', FData));
    end;

    LProductName := LDataset.FieldByName('product_name').AsString;
    LDescription := LDataset.FieldByName('description').AsString;
    LPrice := LDataset.FieldByName('price').AsCurrency;
    LStock := LDataset.FieldByName('stock').AsInteger;
    LCategoryID := LDataset.FieldByName('category_id').AsString;
    LCategoryName := LDataset.FieldByName('category_name').AsString;
    LIsActive := LDataset.FieldByName('is_active').AsInteger;
  finally
    FreeAndNil(LDataset);
  end;

  LCategoryInternalID := Null;
  if LRequest.HasCategoryID then begin
    if LRequest.CategoryID = '' then begin
      LCategoryID := '';
      LCategoryName := '';
    end else begin
      LDataset := FRepository.FindCategoryByID(LRequest.CategoryID);
      try
        if LDataset.IsEmpty then begin
          FStatusCode := 404;
          Exit(THelperResponse.CreateResponse(FStatusCode, 'Category not found', FData));
        end;

        LCategoryInternalID := LDataset.FieldByName('id').Value;
        LCategoryID := LDataset.FieldByName('category_id').AsString;
        LCategoryName := LDataset.FieldByName('category_name').AsString;
      finally
        FreeAndNil(LDataset);
      end;
    end;
  end;

  try
    FConnection.StartTransaction;
    try
      FRepository.UpdateProduct(LRequest, LCategoryInternalID);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    if LRequest.HasProductName then
      LProductName := LRequest.ProductName;
    if LRequest.HasDescription then
      LDescription := LRequest.Description;
    if LRequest.HasPrice then
      LPrice := LRequest.Price;
    if LRequest.HasStock then
      LStock := LRequest.Stock;
    if LRequest.HasIsActive then
      LIsActive := LRequest.IsActive;

    LResponseData := TProductDTO.CreateProductResponse(
      LRequest.ProductID,
      LProductName,
      LDescription,
      LPrice,
      LStock,
      LCategoryID,
      LCategoryName,
      LIsActive
    );
    try
      FStatusCode := 200;
      Result := THelperResponse.CreateResponse(FStatusCode, 'Product updated', LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

end.
