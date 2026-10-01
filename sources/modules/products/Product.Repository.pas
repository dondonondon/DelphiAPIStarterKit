unit Product.Repository;

interface

uses
  System.Variants,
  FireDAC.Comp.Client,
  Product.DTO;

type
  TProductRepository = class
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);

    function CreateProduct(const AProductID: string;
      const ARequest: TProductCreateRequest;
      const ACategoryInternalID: Variant): Integer;
    function FindCategoryByID(const ACategoryID: string): TFDQuery;
    function FindProductByID(const AProductID: string): TFDQuery;
    function GetProducts(const AProductID: string = ''): TFDQuery;
    function SoftDeleteProduct(const AProductID: string): Integer;
    function UpdateProduct(const ARequest: TProductUpdateRequest;
      const ACategoryInternalID: Variant): Integer;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  DB.Helper.Query;

constructor TProductRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TProductRepository.CreateProduct(const AProductID: string;
  const ARequest: TProductCreateRequest;
  const ACategoryInternalID: Variant): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'INSERT INTO product ' +
      '(product_id, product_name, description, price, stock, category_internal_id, is_active) ' +
      'VALUES (:product_id, :product_name, :description, :price, :stock, :category_internal_id, :is_active)',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'product_id', AProductID);
    TQueryFunction.SQLParamByName(LDataset, 'product_name', ARequest.ProductName);
    TQueryFunction.SQLParamByName(LDataset, 'description', ARequest.Description);
    TQueryFunction.SQLParamByName(LDataset, 'price', ARequest.Price);
    TQueryFunction.SQLParamByName(LDataset, 'stock', ARequest.Stock);
    TQueryFunction.SQLParamByName(LDataset, 'category_internal_id', ACategoryInternalID);
    TQueryFunction.SQLParamByName(LDataset, 'is_active', ARequest.IsActive);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TProductRepository.FindCategoryByID(const ACategoryID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT id, category_id, category_name FROM category ' +
      'WHERE category_id = :category_id AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'category_id', ACategoryID);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TProductRepository.FindProductByID(const AProductID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT p.product_id, p.product_name, p.description, p.price, p.stock, ' +
      'c.category_id, c.category_name, p.is_active, p.created_at ' +
      'FROM product p ' +
      'LEFT JOIN category c ON c.id = p.category_internal_id ' +
      'WHERE p.product_id = :product_id AND p.deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'product_id', AProductID);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TProductRepository.GetProducts(const AProductID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    if AProductID <> '' then begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT p.product_id, p.product_name, p.description, p.price, p.stock, ' +
        'c.category_id, c.category_name, p.is_active, p.created_at ' +
        'FROM product p ' +
        'LEFT JOIN category c ON c.id = p.category_internal_id ' +
        'WHERE p.product_id = :product_id AND p.deleted_at IS NULL',
        True
      );
      TQueryFunction.SQLParamByName(Result, 'product_id', AProductID);
    end else begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT p.product_id, p.product_name, p.description, p.price, p.stock, ' +
        'c.category_id, c.category_name, p.is_active, p.created_at ' +
        'FROM product p ' +
        'LEFT JOIN category c ON c.id = p.category_internal_id ' +
        'WHERE p.deleted_at IS NULL ORDER BY p.created_at DESC, p.product_name ASC',
        True
      );
    end;
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TProductRepository.SoftDeleteProduct(
  const AProductID: string): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE product SET is_active = 0, deleted_at = NOW() ' +
      'WHERE product_id = :product_id AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'product_id', AProductID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TProductRepository.UpdateProduct(
  const ARequest: TProductUpdateRequest; const ACategoryInternalID: Variant): Integer;
var
  I: Integer;
  LDataset: TFDQuery;
  LSetClauses: TStringList;
  LSetSQL: string;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  LSetClauses := TStringList.Create;
  try
    if ARequest.HasProductName then
      LSetClauses.Add('product_name = :product_name');

    if ARequest.HasDescription then
      LSetClauses.Add('description = :description');

    if ARequest.HasPrice then
      LSetClauses.Add('price = :price');

    if ARequest.HasStock then
      LSetClauses.Add('stock = :stock');

    if ARequest.HasCategoryID then
      LSetClauses.Add('category_internal_id = :category_internal_id');

    if ARequest.HasIsActive then
      LSetClauses.Add('is_active = :is_active');

    LSetSQL := '';
    for I := 0 to LSetClauses.Count - 1 do begin
      if LSetSQL <> '' then
        LSetSQL := LSetSQL + ', ';
      LSetSQL := LSetSQL + LSetClauses[I];
    end;

    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE product SET ' + LSetSQL +
      ' WHERE product_id = :product_id AND deleted_at IS NULL',
      True
    );

    if ARequest.HasProductName then
      TQueryFunction.SQLParamByName(LDataset, 'product_name', ARequest.ProductName);

    if ARequest.HasDescription then
      TQueryFunction.SQLParamByName(LDataset, 'description', ARequest.Description);

    if ARequest.HasPrice then
      TQueryFunction.SQLParamByName(LDataset, 'price', ARequest.Price);

    if ARequest.HasStock then
      TQueryFunction.SQLParamByName(LDataset, 'stock', ARequest.Stock);

    if ARequest.HasCategoryID then
      TQueryFunction.SQLParamByName(LDataset, 'category_internal_id', ACategoryInternalID);

    if ARequest.HasIsActive then
      TQueryFunction.SQLParamByName(LDataset, 'is_active', ARequest.IsActive);

    TQueryFunction.SQLParamByName(LDataset, 'product_id', ARequest.ProductID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LSetClauses);
    FreeAndNil(LDataset);
  end;
end;

end.
