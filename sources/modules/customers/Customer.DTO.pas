unit Customer.DTO;

interface

uses
  System.SysUtils,
  System.JSON;

type
  TCustomerCreateRequest = record
    CustomerName: string;
    Email: string;
    PhoneNumber: string;
    AddressLine1: string;
    AddressLine2: string;
    City: string;
    State: string;
    PostalCode: string;
    Country: string;
    Notes: string;
    IsActive: Integer;
  end;

  TCustomerUpdateRequest = record
    CustomerID: string;
    CustomerName: string;
    Email: string;
    PhoneNumber: string;
    AddressLine1: string;
    AddressLine2: string;
    City: string;
    State: string;
    PostalCode: string;
    Country: string;
    Notes: string;
    IsActive: Integer;
    HasCustomerName: Boolean;
    HasEmail: Boolean;
    HasPhoneNumber: Boolean;
    HasAddressLine1: Boolean;
    HasAddressLine2: Boolean;
    HasCity: Boolean;
    HasState: Boolean;
    HasPostalCode: Boolean;
    HasCountry: Boolean;
    HasNotes: Boolean;
    HasIsActive: Boolean;
  end;

  TCustomerDTO = class
  public
    class function CreateCustomerResponse(const ACustomerID, ACustomerName, AEmail, APhoneNumber,
      AAddressLine1, AAddressLine2, ACity, AState, APostalCode, ACountry, ANotes: string;
      AIsActive: Integer): string;
  end;

implementation

class function TCustomerDTO.CreateCustomerResponse(const ACustomerID, ACustomerName, AEmail,
  APhoneNumber, AAddressLine1, AAddressLine2, ACity, AState, APostalCode, ACountry,
  ANotes: string; AIsActive: Integer): string;
var
  LJSON: TJSONObject;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('customer_id', ACustomerID);
    LJSON.AddPair('customer_name', ACustomerName);
    LJSON.AddPair('email', AEmail);
    LJSON.AddPair('phone_number', APhoneNumber);
    LJSON.AddPair('address_line1', AAddressLine1);
    LJSON.AddPair('address_line2', AAddressLine2);
    LJSON.AddPair('city', ACity);
    LJSON.AddPair('state', AState);
    LJSON.AddPair('postal_code', APostalCode);
    LJSON.AddPair('country', ACountry);
    LJSON.AddPair('notes', ANotes);
    LJSON.AddPair('is_active', TJSONNumber.Create(AIsActive));
    Result := LJSON.ToJSON;
  finally
    FreeAndNil(LJSON);
  end;
end;

end.
