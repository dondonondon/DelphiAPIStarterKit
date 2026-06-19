unit Category.Validator;

interface

uses
  FireDAC.Comp.Client,
  Category.DTO;

type
  TCategoryValidator = class
  private
    class function ExtractRouteCategoryID(const AParts: TArray<string>;
      out ACategoryID: string; out AMessage: string): Boolean; static;
    class function ValidateCategoryName(const AValue: string;
      out AMessage: string): Boolean; static;
    class function ValidateDescription(const AValue: string;
      out AMessage: string): Boolean; static;
  public
    class function ValidateCreate(AData: TFDMemTable;
      out ARequest: TCategoryCreateRequest; out AMessage: string): Boolean;
    class function ValidateUpdate(AData: TFDMemTable; const AParts: TArray<string>;
      out ARequest: TCategoryUpdateRequest; out AMessage: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  BFA.Helper.Validator;

class function TCategoryValidator.ExtractRouteCategoryID(
  const AParts: TArray<string>; out ACategoryID: string;
  out AMessage: string): Boolean;
begin
  Result := False;
  ACategoryID := '';

  if Length(AParts) >= 4 then
    ACategoryID := Trim(AParts[3]);

  if ACategoryID = '' then begin
    AMessage := 'Category ID required';
    Exit;
  end;

  if Length(ACategoryID) > 36 then begin
    AMessage := 'Invalid category ID';
    Exit;
  end;

  Result := True;
end;

class function TCategoryValidator.ValidateCategoryName(const AValue: string;
  out AMessage: string): Boolean;
begin
  Result := False;

  if Trim(AValue) = '' then begin
    AMessage := 'Category name required';
    Exit;
  end;

  if Length(AValue) > 50 then begin
    AMessage := 'Category name too long';
    Exit;
  end;

  Result := True;
end;

class function TCategoryValidator.ValidateCreate(AData: TFDMemTable;
  out ARequest: TCategoryCreateRequest; out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.CategoryName := '';
  ARequest.Description := '';
  ARequest.IsActive := 1;

  if not THelperValidator.GetRequiredString(AData, 'category_name',
    'Category name required', ARequest.CategoryName, AMessage) then
    Exit;

  if not ValidateCategoryName(ARequest.CategoryName, AMessage) then
    Exit;

  ARequest.Description := THelperValidator.GetOptionalString(AData, 'description');
  if not ValidateDescription(ARequest.Description, AMessage) then
    Exit;

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

class function TCategoryValidator.ValidateDescription(const AValue: string;
  out AMessage: string): Boolean;
begin
  Result := False;

  if Length(AValue) > 150 then begin
    AMessage := 'Description too long';
    Exit;
  end;

  Result := True;
end;

class function TCategoryValidator.ValidateUpdate(AData: TFDMemTable;
  const AParts: TArray<string>; out ARequest: TCategoryUpdateRequest;
  out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.CategoryID := '';
  ARequest.CategoryName := '';
  ARequest.Description := '';
  ARequest.IsActive := 0;
  ARequest.HasCategoryName := False;
  ARequest.HasDescription := False;
  ARequest.HasIsActive := False;

  if not ExtractRouteCategoryID(AParts, ARequest.CategoryID, AMessage) then
    Exit;

  if Assigned(AData.FindField('category_id')) then begin
    AMessage := 'Category ID cannot be changed';
    Exit;
  end;

  if Assigned(AData.FindField('category_name')) then begin
    ARequest.CategoryName := Trim(AData.FieldByName('category_name').AsString);
    if not ValidateCategoryName(ARequest.CategoryName, AMessage) then
      Exit;
    ARequest.HasCategoryName := True;
  end;

  if Assigned(AData.FindField('description')) then begin
    ARequest.Description := Trim(AData.FieldByName('description').AsString);
    if not ValidateDescription(ARequest.Description, AMessage) then
      Exit;
    ARequest.HasDescription := True;
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

  if not (ARequest.HasCategoryName or ARequest.HasDescription or ARequest.HasIsActive) then begin
    AMessage := 'No data to update';
    Exit;
  end;

  Result := True;
end;

end.