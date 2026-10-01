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
    class function CreateProductJSONResponse(const AProductID, AProductName,
      ADescription: string; const APrice: Currency; AStock: Integer;
      const ACategoryID, ACategoryName: string; AIsActive: Integer): string;
  end;

implementation

uses System.JSON;

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
var
  LFormatSettings: TFormatSettings;
begin
  LFormatSettings := TFormatSettings.Create('en-US');
  Result := FormatCurr('0.00', AValue, LFormatSettings);
end;

class function TProductDTO.CreateProductJSONResponse(const AProductID, AProductName,
  ADescription: string; const APrice: Currency; AStock: Integer;
  const ACategoryID, ACategoryName: string; AIsActive: Integer): string;
var LObject: TJSONObject;
begin
  LObject := TJSONObject.Create;
  try
    LObject.AddPair('product_id', AProductID);
    LObject.AddPair('product_name', AProductName);
    LObject.AddPair('description', ADescription);
    LObject.AddPair('price', TJSONNumber.Create(CurrToStr(APrice, TFormatSettings.Invariant)));
    LObject.AddPair('stock', TJSONNumber.Create(AStock));
    if ACategoryID = '' then begin
      LObject.AddPair('category_id', TJSONNull.Create);
      LObject.AddPair('category_name', TJSONNull.Create);
    end else begin
      LObject.AddPair('category_id', ACategoryID);
      LObject.AddPair('category_name', ACategoryName);
    end;
    LObject.AddPair('is_active', TJSONBool.Create(AIsActive = 1));
    Result := LObject.ToJSON;
  finally
    FreeAndNil(LObject);
  end;
end;

end.
