unit Category.Service;

interface

uses
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp,
  Category.Repository;

type
  TCategoryService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FData: TFDMemTable;
    FParts: TArray<string>;
    FRepository: TCategoryRepository;
    FStatusCode: Integer;

    function ExtractRouteCategoryID(out ACategoryID: string;
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
  Data.DB,
  BFA.Core.Response,
  BFA.Helper.Strings,
  BFA.Helper.Transaction,
  Category.DTO,
  Category.Validator;

constructor TCategoryService.Create(AConnection: TFDConnection;
  AData: TFDMemTable; ARequest: TWebRequest; const AParts: TArray<string>);
begin
  inherited Create;
  FConnection := AConnection;
  FData := AData;
  FParts := AParts;
  FStatusCode := 500;
  FRepository := TCategoryRepository.Create(FConnection);
end;

function TCategoryService.Delete: string;
var
  LCategoryID: string;
  LMessage: string;
  LRowsAffected: Integer;
begin
  if not ExtractRouteCategoryID(LCategoryID, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  try
    FConnection.StartTransaction;
    try
      LRowsAffected := FRepository.SoftDeleteCategory(LCategoryID);
      if LRowsAffected = 0 then begin
        THelperTransaction.Rollback(FConnection);
        FStatusCode := 404;
        Exit(THelperResponse.CreateResponse(FStatusCode, 'Category not found', FData));
      end;
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'Category deleted', FData);
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

destructor TCategoryService.Destroy;
begin
  FreeAndNil(FRepository);
  inherited;
end;

function TCategoryService.ExtractRouteCategoryID(out ACategoryID,
  AMessage: string): Boolean;
begin
  Result := False;
  ACategoryID := '';

  if Length(FParts) >= 4 then
    ACategoryID := Trim(FParts[3]);

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

function TCategoryService.Get: string;
var
  LCategoryID: string;
  LDataset: TFDQuery;
begin
  LCategoryID := '';
  if Length(FParts) >= 4 then
    LCategoryID := Trim(FParts[3]);

  LDataset := FRepository.GetCategories(LCategoryID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Category not found', FData));
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'OK', LDataset, FData);
  finally
    FreeAndNil(LDataset);
  end;
end;

function TCategoryService.Insert: string;
var
  LCategoryID: string;
  LDataset: TFDQuery;
  LMessage: string;
  LRequest: TCategoryCreateRequest;
  LResponseData: TStringList;
begin
  if not TCategoryValidator.ValidateCreate(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LDataset := FRepository.FindCategoryByName(LRequest.CategoryName);
  try
    if not LDataset.IsEmpty then begin
      FStatusCode := 409;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Category name already exists', FData));
    end;
  finally
    FreeAndNil(LDataset);
  end;

  LCategoryID := TGlobalFunction.NewDatabaseUUID;

  try
    FConnection.StartTransaction;
    try
      FRepository.CreateCategory(LCategoryID, LRequest);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    LResponseData := TCategoryDTO.CreateCategoryResponse(
      LCategoryID,
      LRequest.CategoryName,
      LRequest.Description,
      LRequest.IsActive
    );
    try
      FStatusCode := 201;
      Result := THelperResponse.CreateResponse(FStatusCode, 'Category created', LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

function TCategoryService.InternalServerError: string;
begin
  FStatusCode := 500;
  Result := THelperResponse.CreateResponse(FStatusCode, 'Internal server error.', FData);
end;

function TCategoryService.Update: string;
var
  LCategoryName: string;
  LDataset: TFDQuery;
  LDescription: string;
  LIsActive: Integer;
  LMessage: string;
  LRequest: TCategoryUpdateRequest;
  LResponseData: TStringList;
begin
  if not TCategoryValidator.ValidateUpdate(FData, FParts, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LDataset := FRepository.FindCategoryByID(LRequest.CategoryID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Category not found', FData));
    end;

    LCategoryName := LDataset.FieldByName('category_name').AsString;
    LDescription := LDataset.FieldByName('description').AsString;
    LIsActive := LDataset.FieldByName('is_active').AsInteger;
  finally
    FreeAndNil(LDataset);
  end;

  if LRequest.HasCategoryName then begin
    LDataset := FRepository.FindCategoryByName(LRequest.CategoryName, LRequest.CategoryID);
    try
      if not LDataset.IsEmpty then begin
        FStatusCode := 409;
        Exit(THelperResponse.CreateResponse(FStatusCode, 'Category name already exists', FData));
      end;
    finally
      FreeAndNil(LDataset);
    end;
  end;

  try
    FConnection.StartTransaction;
    try
      FRepository.UpdateCategory(LRequest);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError);
      end;
    end;

    if LRequest.HasCategoryName then
      LCategoryName := LRequest.CategoryName;
    if LRequest.HasDescription then
      LDescription := LRequest.Description;
    if LRequest.HasIsActive then
      LIsActive := LRequest.IsActive;

    LResponseData := TCategoryDTO.CreateCategoryResponse(
      LRequest.CategoryID,
      LCategoryName,
      LDescription,
      LIsActive
    );
    try
      FStatusCode := 200;
      Result := THelperResponse.CreateResponse(FStatusCode, 'Category updated', LResponseData);
    finally
      FreeAndNil(LResponseData);
    end;
  except
    on E: Exception do
      Result := InternalServerError;
  end;
end;

end.