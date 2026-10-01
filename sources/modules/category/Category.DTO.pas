unit Category.DTO;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TCategoryCreateRequest = record
    CategoryName: string;
    Description: string;
    IsActive: Integer;
  end;

  TCategoryUpdateRequest = record
    CategoryID: string;
    CategoryName: string;
    Description: string;
    IsActive: Integer;
    HasCategoryName: Boolean;
    HasDescription: Boolean;
    HasIsActive: Boolean;
  end;

  TCategoryDTO = class
  public
    class function CreateCategoryResponse(const ACategoryID, ACategoryName,
      ADescription: string; AIsActive: Integer): TStringList;
    class function CreateCategoryJSONResponse(const ACategoryID, ACategoryName,
      ADescription: string; AIsActive: Integer): string;
  end;

implementation

uses System.JSON;

class function TCategoryDTO.CreateCategoryResponse(const ACategoryID,
  ACategoryName, ADescription: string; AIsActive: Integer): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.AddPair('category_id', ACategoryID);
    Result.AddPair('category_name', ACategoryName);
    Result.AddPair('description', ADescription);
    Result.AddPair('is_active', IntToStr(AIsActive));
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class function TCategoryDTO.CreateCategoryJSONResponse(const ACategoryID, ACategoryName,
  ADescription: string; AIsActive: Integer): string;
var LObject: TJSONObject;
begin
  LObject := TJSONObject.Create;
  try
    LObject.AddPair('category_id', ACategoryID);
    LObject.AddPair('category_name', ACategoryName);
    LObject.AddPair('description', ADescription);
    LObject.AddPair('is_active', TJSONBool.Create(AIsActive = 1));
    Result := LObject.ToJSON;
  finally
    FreeAndNil(LObject);
  end;
end;

end.
