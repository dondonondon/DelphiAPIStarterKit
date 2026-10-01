unit Customer.Repository;

interface

uses
  FireDAC.Comp.Client,
  Customer.DTO;

type
  TCustomerRepository = class
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);

    function CreateCustomer(const ACustomerID: string;
      const ARequest: TCustomerCreateRequest): Integer;
    function FindCustomerByID(const ACustomerID: string): TFDQuery;
    function GetCustomers(const ACustomerID: string = ''): TFDQuery;
    function SoftDeleteCustomer(const ACustomerID: string): Integer;
    function UpdateCustomer(const ARequest: TCustomerUpdateRequest): Integer;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  DB.Helper.Query;

constructor TCustomerRepository.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TCustomerRepository.CreateCustomer(const ACustomerID: string;
  const ARequest: TCustomerCreateRequest): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'INSERT INTO customer ' +
      '(customer_id, customer_name, email, phone_number, address_line1, address_line2, city, state, ' +
      'postal_code, country, notes, is_active) ' +
      'VALUES (:customer_id, :customer_name, :email, :phone_number, :address_line1, :address_line2, :city, ' +
      ':state, :postal_code, :country, :notes, :is_active)',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'customer_id', ACustomerID);
    TQueryFunction.SQLParamByName(LDataset, 'customer_name', ARequest.CustomerName);
    TQueryFunction.SQLParamByName(LDataset, 'email', ARequest.Email);
    TQueryFunction.SQLParamByName(LDataset, 'phone_number', ARequest.PhoneNumber);
    TQueryFunction.SQLParamByName(LDataset, 'address_line1', ARequest.AddressLine1);
    TQueryFunction.SQLParamByName(LDataset, 'address_line2', ARequest.AddressLine2);
    TQueryFunction.SQLParamByName(LDataset, 'city', ARequest.City);
    TQueryFunction.SQLParamByName(LDataset, 'state', ARequest.State);
    TQueryFunction.SQLParamByName(LDataset, 'postal_code', ARequest.PostalCode);
    TQueryFunction.SQLParamByName(LDataset, 'country', ARequest.Country);
    TQueryFunction.SQLParamByName(LDataset, 'notes', ARequest.Notes);
    TQueryFunction.SQLParamByName(LDataset, 'is_active', ARequest.IsActive);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TCustomerRepository.FindCustomerByID(const ACustomerID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      Result,
      'SELECT customer_id, customer_name, email, phone_number, address_line1, address_line2, city, state, ' +
      'postal_code, country, notes, is_active, created_at ' +
      'FROM customer WHERE customer_id = :customer_id AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(Result, 'customer_id', ACustomerID);
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TCustomerRepository.GetCustomers(const ACustomerID: string): TFDQuery;
begin
  Result := THelperDatabase.CreateQuery(FConnection);
  try
    if ACustomerID <> '' then begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT customer_id, customer_name, email, phone_number, address_line1, address_line2, city, state, ' +
        'postal_code, country, notes, is_active, created_at ' +
        'FROM customer WHERE customer_id = :customer_id AND deleted_at IS NULL',
        True
      );
      TQueryFunction.SQLParamByName(Result, 'customer_id', ACustomerID);
    end else begin
      TQueryFunction.SQLAdd(
        Result,
        'SELECT customer_id, customer_name, email, phone_number, address_line1, address_line2, city, state, ' +
        'postal_code, country, notes, is_active, created_at ' +
        'FROM customer WHERE deleted_at IS NULL ORDER BY created_at DESC, customer_name ASC',
        True
      );
    end;
    TQueryFunction.SQLOpen(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TCustomerRepository.SoftDeleteCustomer(
  const ACustomerID: string): Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  try
    TQueryFunction.SQLAdd(
      LDataset,
      'UPDATE customer SET is_active = 0, deleted_at = NOW() ' +
      'WHERE customer_id = :customer_id AND deleted_at IS NULL',
      True
    );
    TQueryFunction.SQLParamByName(LDataset, 'customer_id', ACustomerID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LDataset);
  end;
end;

function TCustomerRepository.UpdateCustomer(
  const ARequest: TCustomerUpdateRequest): Integer;
var
  I: Integer;
  LDataset: TFDQuery;
  LSetClauses: TStringList;
  LSetSQL: string;
begin
  LDataset := THelperDatabase.CreateQuery(FConnection);
  LSetClauses := TStringList.Create;
  try
    if ARequest.HasCustomerName then
      LSetClauses.Add('customer_name = :customer_name');

    if ARequest.HasEmail then
      LSetClauses.Add('email = :email');

    if ARequest.HasPhoneNumber then
      LSetClauses.Add('phone_number = :phone_number');

    if ARequest.HasAddressLine1 then
      LSetClauses.Add('address_line1 = :address_line1');

    if ARequest.HasAddressLine2 then
      LSetClauses.Add('address_line2 = :address_line2');

    if ARequest.HasCity then
      LSetClauses.Add('city = :city');

    if ARequest.HasState then
      LSetClauses.Add('state = :state');

    if ARequest.HasPostalCode then
      LSetClauses.Add('postal_code = :postal_code');

    if ARequest.HasCountry then
      LSetClauses.Add('country = :country');

    if ARequest.HasNotes then
      LSetClauses.Add('notes = :notes');

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
      'UPDATE customer SET ' + LSetSQL +
      ' WHERE customer_id = :customer_id AND deleted_at IS NULL',
      True
    );

    if ARequest.HasCustomerName then
      TQueryFunction.SQLParamByName(LDataset, 'customer_name', ARequest.CustomerName);

    if ARequest.HasEmail then
      TQueryFunction.SQLParamByName(LDataset, 'email', ARequest.Email);

    if ARequest.HasPhoneNumber then
      TQueryFunction.SQLParamByName(LDataset, 'phone_number', ARequest.PhoneNumber);

    if ARequest.HasAddressLine1 then
      TQueryFunction.SQLParamByName(LDataset, 'address_line1', ARequest.AddressLine1);

    if ARequest.HasAddressLine2 then
      TQueryFunction.SQLParamByName(LDataset, 'address_line2', ARequest.AddressLine2);

    if ARequest.HasCity then
      TQueryFunction.SQLParamByName(LDataset, 'city', ARequest.City);

    if ARequest.HasState then
      TQueryFunction.SQLParamByName(LDataset, 'state', ARequest.State);

    if ARequest.HasPostalCode then
      TQueryFunction.SQLParamByName(LDataset, 'postal_code', ARequest.PostalCode);

    if ARequest.HasCountry then
      TQueryFunction.SQLParamByName(LDataset, 'country', ARequest.Country);

    if ARequest.HasNotes then
      TQueryFunction.SQLParamByName(LDataset, 'notes', ARequest.Notes);

    if ARequest.HasIsActive then
      TQueryFunction.SQLParamByName(LDataset, 'is_active', ARequest.IsActive);

    TQueryFunction.SQLParamByName(LDataset, 'customer_id', ARequest.CustomerID);
    TQueryFunction.ExecSQL(LDataset);
    Result := LDataset.RowsAffected;
  finally
    FreeAndNil(LSetClauses);
    FreeAndNil(LDataset);
  end;
end;

end.
