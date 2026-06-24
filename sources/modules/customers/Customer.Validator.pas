unit Customer.Validator;

interface

uses
  FireDAC.Comp.Client,
  Customer.DTO;

type
  TCustomerValidator = class
  private
    class function ExtractRouteCustomerID(const AParts: TArray<string>;
      out ACustomerID: string; out AMessage: string): Boolean; static;
    class function ValidateCustomerName(const AValue: string;
      out AMessage: string): Boolean; static;
    class function ValidateEmail(const AValue: string;
      out AMessage: string): Boolean; static;
    class function ValidateOptionalLength(const AValue: string; AMaxLength: Integer;
      const ATooLongMessage: string; out AMessage: string): Boolean; static;
  public
    class function ValidateCreate(AData: TFDMemTable;
      out ARequest: TCustomerCreateRequest; out AMessage: string): Boolean;
    class function ValidateUpdate(AData: TFDMemTable; const AParts: TArray<string>;
      out ARequest: TCustomerUpdateRequest; out AMessage: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  BFA.Helper.Validator;

class function TCustomerValidator.ExtractRouteCustomerID(
  const AParts: TArray<string>; out ACustomerID: string;
  out AMessage: string): Boolean;
begin
  Result := False;
  ACustomerID := '';

  if Length(AParts) >= 4 then
    ACustomerID := Trim(AParts[3]);

  if ACustomerID = '' then begin
    AMessage := 'Customer ID required';
    Exit;
  end;

  if Length(ACustomerID) > 36 then begin
    AMessage := 'Invalid customer ID';
    Exit;
  end;

  Result := True;
end;

class function TCustomerValidator.ValidateCreate(AData: TFDMemTable;
  out ARequest: TCustomerCreateRequest; out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.CustomerName := '';
  ARequest.Email := '';
  ARequest.PhoneNumber := '';
  ARequest.AddressLine1 := '';
  ARequest.AddressLine2 := '';
  ARequest.City := '';
  ARequest.State := '';
  ARequest.PostalCode := '';
  ARequest.Country := '';
  ARequest.Notes := '';
  ARequest.IsActive := 1;

  if not THelperValidator.GetRequiredString(AData, 'customer_name',
    'Customer name required', ARequest.CustomerName, AMessage) then
    Exit;

  if not ValidateCustomerName(ARequest.CustomerName, AMessage) then
    Exit;

  ARequest.Email := THelperValidator.GetOptionalString(AData, 'email');
  if not ValidateEmail(ARequest.Email, AMessage) then
    Exit;

  ARequest.PhoneNumber := THelperValidator.GetOptionalString(AData, 'phone_number');
  if not ValidateOptionalLength(ARequest.PhoneNumber, 30, 'Phone number too long', AMessage) then
    Exit;

  ARequest.AddressLine1 := THelperValidator.GetOptionalString(AData, 'address_line1');
  if not ValidateOptionalLength(ARequest.AddressLine1, 150, 'Address line 1 too long', AMessage) then
    Exit;

  ARequest.AddressLine2 := THelperValidator.GetOptionalString(AData, 'address_line2');
  if not ValidateOptionalLength(ARequest.AddressLine2, 150, 'Address line 2 too long', AMessage) then
    Exit;

  ARequest.City := THelperValidator.GetOptionalString(AData, 'city');
  if not ValidateOptionalLength(ARequest.City, 100, 'City too long', AMessage) then
    Exit;

  ARequest.State := THelperValidator.GetOptionalString(AData, 'state');
  if not ValidateOptionalLength(ARequest.State, 100, 'State too long', AMessage) then
    Exit;

  ARequest.PostalCode := THelperValidator.GetOptionalString(AData, 'postal_code');
  if not ValidateOptionalLength(ARequest.PostalCode, 20, 'Postal code too long', AMessage) then
    Exit;

  ARequest.Country := THelperValidator.GetOptionalString(AData, 'country');
  if not ValidateOptionalLength(ARequest.Country, 100, 'Country too long', AMessage) then
    Exit;

  ARequest.Notes := THelperValidator.GetOptionalString(AData, 'notes');

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

class function TCustomerValidator.ValidateCustomerName(const AValue: string;
  out AMessage: string): Boolean;
begin
  Result := False;

  if Trim(AValue) = '' then begin
    AMessage := 'Customer name required';
    Exit;
  end;

  if Length(AValue) > 100 then begin
    AMessage := 'Customer name too long';
    Exit;
  end;

  Result := True;
end;

class function TCustomerValidator.ValidateEmail(const AValue: string;
  out AMessage: string): Boolean;
begin
  Result := False;

  if Length(AValue) > 100 then begin
    AMessage := 'Email too long';
    Exit;
  end;

  if (AValue <> '') and
    (not TRegEx.IsMatch(AValue, '^[^@\s]+@[^@\s]+\.[^@\s]+$', [roIgnoreCase])) then begin
    AMessage := 'Invalid email value';
    Exit;
  end;

  Result := True;
end;

class function TCustomerValidator.ValidateOptionalLength(const AValue: string;
  AMaxLength: Integer; const ATooLongMessage: string;
  out AMessage: string): Boolean;
begin
  Result := False;

  if Length(AValue) > AMaxLength then begin
    AMessage := ATooLongMessage;
    Exit;
  end;

  Result := True;
end;

class function TCustomerValidator.ValidateUpdate(AData: TFDMemTable;
  const AParts: TArray<string>; out ARequest: TCustomerUpdateRequest;
  out AMessage: string): Boolean;
begin
  Result := False;
  ARequest.CustomerID := '';
  ARequest.CustomerName := '';
  ARequest.Email := '';
  ARequest.PhoneNumber := '';
  ARequest.AddressLine1 := '';
  ARequest.AddressLine2 := '';
  ARequest.City := '';
  ARequest.State := '';
  ARequest.PostalCode := '';
  ARequest.Country := '';
  ARequest.Notes := '';
  ARequest.IsActive := 0;
  ARequest.HasCustomerName := False;
  ARequest.HasEmail := False;
  ARequest.HasPhoneNumber := False;
  ARequest.HasAddressLine1 := False;
  ARequest.HasAddressLine2 := False;
  ARequest.HasCity := False;
  ARequest.HasState := False;
  ARequest.HasPostalCode := False;
  ARequest.HasCountry := False;
  ARequest.HasNotes := False;
  ARequest.HasIsActive := False;

  if not ExtractRouteCustomerID(AParts, ARequest.CustomerID, AMessage) then
    Exit;

  if Assigned(AData.FindField('customer_id')) then begin
    AMessage := 'Customer ID cannot be changed';
    Exit;
  end;

  if Assigned(AData.FindField('customer_name')) then begin
    ARequest.CustomerName := Trim(AData.FieldByName('customer_name').AsString);
    if not ValidateCustomerName(ARequest.CustomerName, AMessage) then
      Exit;
    ARequest.HasCustomerName := True;
  end;

  if Assigned(AData.FindField('email')) then begin
    ARequest.Email := Trim(AData.FieldByName('email').AsString);
    if not ValidateEmail(ARequest.Email, AMessage) then
      Exit;
    ARequest.HasEmail := True;
  end;

  if Assigned(AData.FindField('phone_number')) then begin
    ARequest.PhoneNumber := Trim(AData.FieldByName('phone_number').AsString);
    if not ValidateOptionalLength(ARequest.PhoneNumber, 30, 'Phone number too long', AMessage) then
      Exit;
    ARequest.HasPhoneNumber := True;
  end;

  if Assigned(AData.FindField('address_line1')) then begin
    ARequest.AddressLine1 := Trim(AData.FieldByName('address_line1').AsString);
    if not ValidateOptionalLength(ARequest.AddressLine1, 150, 'Address line 1 too long', AMessage) then
      Exit;
    ARequest.HasAddressLine1 := True;
  end;

  if Assigned(AData.FindField('address_line2')) then begin
    ARequest.AddressLine2 := Trim(AData.FieldByName('address_line2').AsString);
    if not ValidateOptionalLength(ARequest.AddressLine2, 150, 'Address line 2 too long', AMessage) then
      Exit;
    ARequest.HasAddressLine2 := True;
  end;

  if Assigned(AData.FindField('city')) then begin
    ARequest.City := Trim(AData.FieldByName('city').AsString);
    if not ValidateOptionalLength(ARequest.City, 100, 'City too long', AMessage) then
      Exit;
    ARequest.HasCity := True;
  end;

  if Assigned(AData.FindField('state')) then begin
    ARequest.State := Trim(AData.FieldByName('state').AsString);
    if not ValidateOptionalLength(ARequest.State, 100, 'State too long', AMessage) then
      Exit;
    ARequest.HasState := True;
  end;

  if Assigned(AData.FindField('postal_code')) then begin
    ARequest.PostalCode := Trim(AData.FieldByName('postal_code').AsString);
    if not ValidateOptionalLength(ARequest.PostalCode, 20, 'Postal code too long', AMessage) then
      Exit;
    ARequest.HasPostalCode := True;
  end;

  if Assigned(AData.FindField('country')) then begin
    ARequest.Country := Trim(AData.FieldByName('country').AsString);
    if not ValidateOptionalLength(ARequest.Country, 100, 'Country too long', AMessage) then
      Exit;
    ARequest.HasCountry := True;
  end;

  if Assigned(AData.FindField('notes')) then begin
    ARequest.Notes := Trim(AData.FieldByName('notes').AsString);
    ARequest.HasNotes := True;
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

  if not (ARequest.HasCustomerName or ARequest.HasEmail or ARequest.HasPhoneNumber or
    ARequest.HasAddressLine1 or ARequest.HasAddressLine2 or ARequest.HasCity or
    ARequest.HasState or ARequest.HasPostalCode or ARequest.HasCountry or
    ARequest.HasNotes or ARequest.HasIsActive) then begin
    AMessage := 'No data to update';
    Exit;
  end;

  Result := True;
end;

end.
