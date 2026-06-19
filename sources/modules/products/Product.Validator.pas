unit Product.Validator;

interface

uses
  FireDAC.Comp.Client,
  Product.DTO;

type
  TProductValidator = class
  private
    class function ExtractRouteProductID(const AParts: TArray<string>;
      out AProductID: string; out AMessage: string): Boolean; static;
    class function ExtractCategoryID(AData: TFDMemTable; const ARequired: Boolean;
      out ACategoryID: string; out AHasCategoryID: Boolean;
      out AMessage: string): Boolean; static;
    class function ParseCurrencyField(AData: TFDMemTable; const AFieldName,
      AInvalidMessage: string; out AValue: Currency;
      out AMessage: string): Boolean; static;
    class function ValidateProductName(const AValue: string;
      out AMessage: string): Boolean; static;
  public
    class function ValidateCreate(AData: TFDMemTable;
      out ARequest: TProductCreateRequest; out AMessage: string): Boolean;
    class function ValidateUpdate(AData: TFDMemTable; const AParts: TArray<string>;
      out ARequest: TProductUpdateRequest; out AMessage: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  BFA.Helper.Validator;

class function TProductValidator.ExtractCategoryID(AData: TFDMemTable;
  const ARequired: Boolean; out ACategoryID: string; out AHasCategoryID: Boolean;
  out AMessage: string): Boolean;
begin
  Result := False;
  ACategoryID := '';
  AHasCategoryID := Assigned(AData.FindField('category_id'));

  if not AHasCategoryID then begin
    if ARequired then begin
      AMessage := 'Category ID required';
      Exit;
    end;

    Exit(True);
  end;

  ACategoryID := Trim(AData.FieldByName('category_id').AsString);
  if (ACategoryID <> '') and (Length(ACategoryID) > 36) then begin
    AMessage := 'Invalid category ID';
    Exit;
  end;

  Result := True;
end;

class function TProductValidator.ExtractRouteProductID(
  const AParts: TArray<string>; out AProductID: string;
  out AMessage: string): Boolean;
begin
  Result := False;
  AProductID := '';

  if Length(AParts) >= 4 then
    AProductID := Trim(AParts[3]);

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

class function TProductValidator.ParseCurrencyField(AData: TFDMemTable;
  const AFieldName, AInvalidMessage: string; out AValue: Currency;
  out AMessage: string): Boolean;
var
  LFormatSettings: TFormatSettings;
  LText: string;
begin
  Result := False;
  AValue := 0;

  if not Assigned(AData.FindField(AFieldName)) then
    Exit(True);

  LText := Trim(AData.FieldByName(AFieldName).AsString);
  LFormatSettings := TFormatSettings.Create('en-US');
  if not TryStrToCurr(LText, AValue, LFormatSettings) then begin
    if not TryStrToCurr(LText, AValue) then begin
      AMessage := AInvalidMessage;
      Exit;
    end;
  end;

  Result := True;
end;

class function TProductValidator.ValidateCreate(AData: TFDMemTable;
  out ARequest: TProductCreateRequest; out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.ProductName := '';
  ARequest.Description := '';
  ARequest.Price := 0;
  ARequest.Stock := 0;
  ARequest.CategoryID := '';
  ARequest.IsActive := 1;
  ARequest.HasCategoryID := False;

  if not THelperValidator.GetRequiredString(AData, 'product_name',
    'Product name required', ARequest.ProductName, AMessage) then
    Exit;

  if not ValidateProductName(ARequest.ProductName, AMessage) then
    Exit;

  ARequest.Description := THelperValidator.GetOptionalString(AData, 'description');

  if not ExtractCategoryID(AData, False, ARequest.CategoryID,
    ARequest.HasCategoryID, AMessage) then
    Exit;

  if Assigned(AData.FindField('price')) then begin
    if not ParseCurrencyField(AData, 'price', 'Invalid price value',
      ARequest.Price, AMessage) then
      Exit;

    if ARequest.Price < 0 then begin
      AMessage := 'Invalid price value';
      Exit;
    end;
  end;

  if Assigned(AData.FindField('stock')) then begin
    if not THelperValidator.ParseIntegerField(AData, 'stock', 'Invalid stock value',
      ARequest.Stock, AMessage) then
      Exit;

    if ARequest.Stock < 0 then begin
      AMessage := 'Invalid stock value';
      Exit;
    end;
  end;

  if Assigned(AData.FindField('is_active')) then begin
    if not THelperValidator.ParseIntegerField(AData, 'is_active',
      'Invalid is_active value', ARequest.IsActive, AMessage) then
      Exit;

    if not (ARequest.IsActive in [0, 1]) then begin
      AMessage := 'Invalid is_active value';
      Exit;
    end;
  end;

  Result := True;
end;

class function TProductValidator.ValidateProductName(const AValue: string;
  out AMessage: string): Boolean;
begin
  Result := False;

  if Trim(AValue) = '' then begin
    AMessage := 'Product name required';
    Exit;
  end;

  if Length(AValue) > 100 then begin
    AMessage := 'Product name too long';
    Exit;
  end;

  Result := True;
end;

class function TProductValidator.ValidateUpdate(AData: TFDMemTable;
  const AParts: TArray<string>; out ARequest: TProductUpdateRequest;
  out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.ProductID := '';
  ARequest.ProductName := '';
  ARequest.Description := '';
  ARequest.Price := 0;
  ARequest.Stock := 0;
  ARequest.CategoryID := '';
  ARequest.IsActive := 0;
  ARequest.HasProductName := False;
  ARequest.HasDescription := False;
  ARequest.HasPrice := False;
  ARequest.HasStock := False;
  ARequest.HasCategoryID := False;
  ARequest.HasIsActive := False;

  if not ExtractRouteProductID(AParts, ARequest.ProductID, AMessage) then
    Exit;

  if Assigned(AData.FindField('product_id')) then begin
    AMessage := 'Product ID cannot be changed';
    Exit;
  end;

  if Assigned(AData.FindField('product_name')) then begin
    ARequest.ProductName := Trim(AData.FieldByName('product_name').AsString);
    if not ValidateProductName(ARequest.ProductName, AMessage) then
      Exit;
    ARequest.HasProductName := True;
  end;

  if Assigned(AData.FindField('description')) then begin
    ARequest.Description := Trim(AData.FieldByName('description').AsString);
    ARequest.HasDescription := True;
  end;

  if not ExtractCategoryID(AData, False, ARequest.CategoryID,
    ARequest.HasCategoryID, AMessage) then
    Exit;

  if Assigned(AData.FindField('price')) then begin
    if not ParseCurrencyField(AData, 'price', 'Invalid price value',
      ARequest.Price, AMessage) then
      Exit;

    if ARequest.Price < 0 then begin
      AMessage := 'Invalid price value';
      Exit;
    end;
    ARequest.HasPrice := True;
  end;

  if Assigned(AData.FindField('stock')) then begin
    if not THelperValidator.ParseIntegerField(AData, 'stock', 'Invalid stock value',
      ARequest.Stock, AMessage) then
      Exit;

    if ARequest.Stock < 0 then begin
      AMessage := 'Invalid stock value';
      Exit;
    end;
    ARequest.HasStock := True;
  end;

  if Assigned(AData.FindField('is_active')) then begin
    if not THelperValidator.ParseIntegerField(AData, 'is_active',
      'Invalid is_active value', ARequest.IsActive, AMessage) then
      Exit;

    if not (ARequest.IsActive in [0, 1]) then begin
      AMessage := 'Invalid is_active value';
      Exit;
    end;
    ARequest.HasIsActive := True;
  end;

  if not (ARequest.HasProductName or ARequest.HasDescription or
    ARequest.HasPrice or ARequest.HasStock or ARequest.HasCategoryID or
    ARequest.HasIsActive) then begin
    AMessage := 'No data to update';
    Exit;
  end;

  Result := True;
end;

end.
