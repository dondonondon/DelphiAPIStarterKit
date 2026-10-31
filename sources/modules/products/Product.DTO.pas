unit Product.DTO;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TProductCreateRequest = record
    ProductName: string;
    Description: string;
    Price: Currency;
    Stock: Integer;
    CategoryID: string;
    IsActive: Integer;
    HasCategoryID: Boolean;
  end;

  TProductUpdateRequest = record
    ProductID: string;
    ProductName: string;
    Description: string;
    Price: Currency;
    Stock: Integer;
    CategoryID: string;
    IsActive: Integer;
    HasProductName: Boolean;
    HasDescription: Boolean;
    HasPrice: Boolean;
    HasStock: Boolean;
    HasCategoryID: Boolean;
    HasIsActive: Boolean;
  end;

  TProductDTO = class
  private
    class function CurrencyToText(const AValue: Currency): string; static;
  public
    class function CreateProductResponse(const AProductID, AProductName,
      ADescription: string; const APrice: Currency; AStock: Integer;
      const ACategoryID, ACategoryName: string; AIsActive: Integer): TStringList;
  end;

implementation

var
  GProductNumberFormatSettings: TFormatSettings;

class function TProductDTO.CreateProductResponse(const AProductID,
  AProductName, ADescription: string; const APrice: Currency; AStock: Integer;
  const ACategoryID, ACategoryName: string; AIsActive: Integer): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.AddPair('product_id', AProductID);
    Result.AddPair('product_name', AProductName);
    Result.AddPair('description', ADescription);
    Result.AddPair('price', CurrencyToText(APrice));
    Result.AddPair('stock', IntToStr(AStock));
    Result.AddPair('category_id', ACategoryID);
    Result.AddPair('category_name', ACategoryName);
    Result.AddPair('is_active', IntToStr(AIsActive));
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class function TProductDTO.CurrencyToText(const AValue: Currency): string;
begin
  Result := FormatFloat('0.00', AValue, GProductNumberFormatSettings);
end;

initialization
  GProductNumberFormatSettings := TFormatSettings.Create('en-US');

end.
