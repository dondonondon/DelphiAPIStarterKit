unit Category.Repository;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  Category.DTO;

type
  TCategoryRepository = class
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);

    function CreateCategory(const ACategoryID: string;
      const ARequest: TCategoryCreateRequest): Integer;
    function FindCategoryByID(const ACategoryID: string; ALock: Boolean = False): TFDQuery;
    function FindCategoryByName(const ACategoryName: string;
      const AExcludeCategoryID: string = ''): TFDQuery;
    function HasProductReferences(const ACategoryID: string): Boolean;
    function GetCategories(const ACategoryID: string = ''): TFDQuery;
    function SoftDeleteCategory(const ACategoryID: string): Integer;
    function UpdateCategory(const ARequest: TCategoryUpdateRequest): Integer;
  end;

implementation

uses
  System.Classes,
  DB.Helper.Query;

constructor TCategoryRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TCategoryRepository.CreateCategory(const ACategoryID: string;
  const ARequest: TCategoryCreateRequest): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'INSERT INTO category ' +
      '(category_id, category_name, description, is_active) ' +
      'VALUES (:category_id, :category_name, :description, :is_active)',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'category_id', ACategoryID);
    TQueryFunction.SQLParamByName(LDataset, 'category_name', ARequest.CategoryName);
    TQueryFunction.SQLParamByName(LDataset, 'description', ARequest.Description);
    TQueryFunction.SQLParamByName(LDataset, 'is_active', ARequest.IsActive);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TCategoryRepository.FindCategoryByID(const ACategoryID: string; ALock: Boolean): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT category_id, category_name, description, is_active, created_at ' +
      'FROM category WHERE category_id = :category_id AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'category_id', ACategoryID);
    if ALock then Result.SQL.Add('FOR UPDATE');
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TCategoryRepository.FindCategoryByName(const ACategoryName,
  AExcludeCategoryID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    if AExcludeCategoryID <> '' then begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT category_id FROM category WHERE category_name = :category_name ' +
        'AND category_id <> :category_id',
        True
      );
      TQueryFunction.SQLParamByName(Result, 'category_id', AExcludeCategoryID);
    end else begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT category_id FROM category WHERE category_name = :category_name',
        True
      );
    end;

    TQueryFunction.SQLParamByName(Result, 'category_name', ACategoryName);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TCategoryRepository.GetCategories(const ACategoryID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    if ACategoryID <> '' then begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT category_id, category_name, description, is_active, created_at ' +
        'FROM category WHERE category_id = :category_id AND deleted_at IS NULL',
        True
      );
      TQueryFunction.SQLParamByName(Result, 'category_id', ACategoryID);
    end else begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT category_id, category_name, description, is_active, created_at ' +
        'FROM category WHERE deleted_at IS NULL ORDER BY created_at DESC, category_name ASC',
        True
      );
    end;
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TCategoryRepository.SoftDeleteCategory(
  const ACategoryID: string): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE category SET is_active = 0, deleted_at = UTC_TIMESTAMP(6) ' +
      'WHERE category_id = :category_id AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'category_id', ACategoryID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TCategoryRepository.UpdateCategory(
  const ARequest: TCategoryUpdateRequest): Integer;
var
  I: Integer;
  LDataset: TFDQuery;
  LSetClauses: TStringList;
  LSetSQL: string;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  LSetClauses := TStringList.Create;
  try
    if ARequest.HasCategoryName then
      LSetClauses.Add('category_name = :category_name');

    if ARequest.HasDescription then
      LSetClauses.Add('description = :description');

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
      'UPDATE category SET ' + LSetSQL +
      ' WHERE category_id = :category_id AND deleted_at IS NULL',
      True
    );

    if ARequest.HasCategoryName then
      TQueryFunction.SQLParamByName(LDataset, 'category_name', ARequest.CategoryName);

    if ARequest.HasDescription then
      TQueryFunction.SQLParamByName(LDataset, 'description', ARequest.Description);

    if ARequest.HasIsActive then
      TQueryFunction.SQLParamByName(LDataset, 'is_active', ARequest.IsActive);

    TQueryFunction.SQLParamByName(LDataset, 'category_id', ARequest.CategoryID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LSetClauses);
    FreeAndNil(LDataset);
  end;
end;

function TCategoryRepository.HasProductReferences(const ACategoryID: string): Boolean;
var LQuery: TFDQuery;
begin
  LQuery := THelperDatabase.CreateQuery(FConnection);
  try
    LQuery.SQL.Text := 'SELECT p.id FROM product p JOIN category c ON c.id=p.category_internal_id '
      + 'WHERE c.category_id=:id AND p.deleted_at IS NULL LIMIT 1';
    LQuery.ParamByName('id').AsWideString := ACategoryID;
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    FreeAndNil(LQuery);
  end;
end;

end.