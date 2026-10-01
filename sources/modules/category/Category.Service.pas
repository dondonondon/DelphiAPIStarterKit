unit Category.Service;

interface

uses
  System.Classes,
  FireDAC.Comp.Client,
  Web.HTTPApp,
  Category.Repository, Auth.Repository;

type
  TCategoryService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FRequest: TWebRequest;
    FSecurity: TAuthRepository;
    FData: TFDMemTable;
    FParts: TArray<string>;
    FRepository: TCategoryRepository;
    FStatusCode: Integer;

    function ExtractRouteCategoryID(out ACategoryID: string;
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
  Category.DTO,
  Category.Validator;

constructor TCategoryService.Create(AConnection: TFDConnection;
  AData: TFDMemTable; ARequest: TWebRequest; const AParts: TArray<string>);
begin
  inherited Create;
  FConnection := AConnection;
  FRequest := ARequest;
  FSecurity := TAuthRepository.Create(FConnection);
  FData := AData;
  FParts := AParts;
  FStatusCode := 500;
  FRepository := TCategoryRepository.Create(FConnection);
end;

function TCategoryService.Delete: string;
var LID, LMessage: string; LQuery: TFDQuery; LRows: Integer;
begin
  if not ExtractRouteCategoryID(LID, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  BeginMutation('category.delete');
  try
    LQuery := FRepository.FindCategoryByID(LID, True);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Category not found.');
    finally
      FreeAndNil(LQuery);
    end;
    if FRepository.HasProductReferences(LID) then raise EAuthPolicy.Create(409, 'Category is referenced by a product.');
    LRows := FRepository.SoftDeleteCategory(LID);
    if LRows <> 1 then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
  FStatusCode := 200;
  Result := THelperResponse.CreateResponse(200, 'Category deleted.');
end;

destructor TCategoryService.Destroy;
begin
  FreeAndNil(FRepository);
  FreeAndNil(FSecurity);
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
var LID, LMessage: string; LRequest: TCategoryCreateRequest; LRows: Integer;
begin
  if not TCategoryValidator.ValidateCreate(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  LID := TGlobalFunction.NewDatabaseUUID;
  BeginMutation('category.create');
  try
    LRows := FRepository.CreateCategory(LID, LRequest);
    if LRows <> 1 then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    Result := Reply(LID, 201, 'Category created.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
end;

procedure TCategoryService.BeginMutation(const APermission: string);
begin
  FSecurity.BeginAuthorizedTransaction(TSecurityToken.ExtractAccessToken(FRequest), APermission);
end;

function TCategoryService.Reply(const AID: string; AStatus: Integer; const AMessage: string): string;
var LQuery: TFDQuery;
begin
  LQuery := FRepository.GetCategories(AID);
  try
    if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Category not found.');
    FStatusCode := AStatus;
    Result := THelperResponse.CreateResponse(AStatus, AMessage, LQuery);
  finally
    FreeAndNil(LQuery);
  end;
end;

function TCategoryService.Update: string;
var LID, LMessage: string; LRequest: TCategoryUpdateRequest; LRows: Integer; LQuery: TFDQuery;
begin
  if not TCategoryValidator.ValidateUpdate(FData, FParts, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(400, LMessage));
  end;
  LID := LRequest.CategoryID;
  BeginMutation('category.update');
  try
    LQuery := FRepository.FindCategoryByID(LID, True);
    try
      if LQuery.IsEmpty then raise EAuthPolicy.Create(404, 'Category not found.');
    finally
      FreeAndNil(LQuery);
    end;
    LRows := FRepository.UpdateCategory(LRequest);
    if (LRows < 0) or (LRows > 1) then raise EAuthPolicy.Create(409, 'Mutation conflict.');
    Result := Reply(LID, 200, 'Category updated.');
    FConnection.Commit;
  except
    THelperTransaction.Rollback(FConnection);
    raise;
  end;
end;

end.