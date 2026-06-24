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
  end;

implementation

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

end.