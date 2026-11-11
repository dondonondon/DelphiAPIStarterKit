unit Customer.Service;

interface

uses
  System.Classes,
  System.SysUtils,
  FireDAC.Comp.Client,
  Web.HTTPApp,
  Customer.Repository;

type
  TCustomerService = class(TPersistent)
  private
    FConnection: TFDConnection;
    FData: TFDMemTable;
    FParts: TArray<string>;
    FRepository: TCustomerRepository;
    FStatusCode: Integer;

    function ExtractRouteCustomerID(out ACustomerID: string;
      out AMessage: string): Boolean;
    function InternalServerError(AException: Exception): string;
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
  System.Diagnostics,
  Data.DB,
  BFA.Core.Endpoint,
  BFA.Core.Response,
  BFA.Helper.Strings,
  BFA.Helper.Transaction,
  Customer.DTO,
  Customer.Validator;

type
  TCustomerFetchTiming = class
  private
    FFetchStartTicks: Int64;
    FFetchTicks: Int64;
    FFetchCount: Integer;
  public
    procedure BeforeFetch(Sender: TObject);
    procedure AfterFetch(Sender: TObject);
    procedure WriteTiming(AQueryOpenTicks, ASerializeTicks: Int64;
      ADataset: TFDQuery; AStatusCode: Integer; AIsDetail: Boolean;
      const AResponse: string);
  end;

var
  GCustomerTimingEnabled: Boolean;
  GCustomerTimingFormatSettings: TFormatSettings;

procedure TCustomerFetchTiming.BeforeFetch(Sender: TObject);
begin
  FFetchStartTicks := TStopwatch.GetTimeStamp;
end;

procedure TCustomerFetchTiming.AfterFetch(Sender: TObject);
begin
  Inc(FFetchTicks, TStopwatch.GetTimeStamp - FFetchStartTicks);
  Inc(FFetchCount);
end;

procedure TCustomerFetchTiming.WriteTiming(AQueryOpenTicks, ASerializeTicks: Int64;
  ADataset: TFDQuery; AStatusCode: Integer; AIsDetail: Boolean;
  const AResponse: string);
var
  LJSONTicks: Int64;
  LRoute: string;
begin
  try
    LJSONTicks := ASerializeTicks - FFetchTicks;
    if LJSONTicks < 0 then
      LJSONTicks := 0;
    LRoute := '/api/v1/Customer';
    if AIsDetail then
      LRoute := LRoute + '/{customer_id}';

    THelperEndpoint.WriteConsoleLog(Format(
      'Customer timing: route=%s status=%d query_open_ms=%.3f ' +
      'remaining_fetch_ms=%.3f json_ms=%.3f serialize_with_fetch_ms=%.3f ' +
      'fetched_rows=%d response_utf8_bytes=%d remaining_fetch_count=%d',
      [LRoute, AStatusCode, AQueryOpenTicks * 1000.0 / TStopwatch.Frequency,
       FFetchTicks * 1000.0 / TStopwatch.Frequency,
       LJSONTicks * 1000.0 / TStopwatch.Frequency,
       ASerializeTicks * 1000.0 / TStopwatch.Frequency, ADataset.RecordCount,
       TEncoding.UTF8.GetByteCount(AResponse), FFetchCount],
      GCustomerTimingFormatSettings));
  except
    // Diagnostics must not change the API response if console output fails.
  end;
end;

constructor TCustomerService.Create(AConnection: TFDConnection;
  AData: TFDMemTable; ARequest: TWebRequest; const AParts: TArray<string>);
begin
  inherited Create;
  FConnection := AConnection;
  FData := AData;
  FParts := AParts;
  FStatusCode := 500;
  FRepository := TCustomerRepository.Create(FConnection);
end;

function TCustomerService.Delete: string;
var
  LCustomerID: string;
  LMessage: string;
  LRowsAffected: Integer;
begin
  if not ExtractRouteCustomerID(LCustomerID, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  try
    FConnection.StartTransaction;
    try
      LRowsAffected := FRepository.SoftDeleteCustomer(LCustomerID);
      if LRowsAffected = 0 then begin
        THelperTransaction.Rollback(FConnection);
        FStatusCode := 404;
        Exit(THelperResponse.CreateResponse(FStatusCode, 'Customer not found', FData));
      end;
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError(E));
      end;
    end;

    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'Customer deleted', FData);
  except
    on E: Exception do
      Result := InternalServerError(E);
  end;
end;

destructor TCustomerService.Destroy;
begin
  FreeAndNil(FRepository);
  inherited;
end;

function TCustomerService.ExtractRouteCustomerID(out ACustomerID,
  AMessage: string): Boolean;
begin
  Result := False;
  ACustomerID := '';

  if Length(FParts) >= 4 then
    ACustomerID := Trim(FParts[3]);

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

function TCustomerService.Get: string;
var
  LCustomerID: string;
  LDataset: TFDQuery;
  LTiming: TCustomerFetchTiming;
  LQueryOpenTicks: Int64;
  LSerializeStartTicks: Int64;
  LSerializeTicks: Int64;
  LResponseReady: Boolean;
begin
  LCustomerID := '';
  if Length(FParts) >= 4 then
    LCustomerID := Trim(FParts[3]);

  LTiming := nil;
  LQueryOpenTicks := 0;
  LSerializeStartTicks := 0;
  LResponseReady := False;
  if GCustomerTimingEnabled then begin
    LTiming := TCustomerFetchTiming.Create;
    LQueryOpenTicks := TStopwatch.GetTimeStamp;
  end;

  try
    LDataset := FRepository.GetCustomers(LCustomerID);
    try
      if Assigned(LTiming) then begin
        LQueryOpenTicks := TStopwatch.GetTimeStamp - LQueryOpenTicks;
        LDataset.Command.BeforeFetch := LTiming.BeforeFetch;
        LDataset.Command.AfterFetch := LTiming.AfterFetch;
        LSerializeStartTicks := TStopwatch.GetTimeStamp;
      end;

      if LDataset.IsEmpty then begin
        FStatusCode := 404;
        Result := THelperResponse.CreateResponse(FStatusCode, 'Customer not found', FData);
        LResponseReady := True;
        Exit;
      end;

      FStatusCode := 200;
      Result := THelperResponse.CreateResponse(FStatusCode, 'OK', LDataset, FData);
      LResponseReady := True;
    finally
      if Assigned(LTiming) then begin
        LSerializeTicks := TStopwatch.GetTimeStamp - LSerializeStartTicks;
        LDataset.Command.BeforeFetch := nil;
        LDataset.Command.AfterFetch := nil;
        if LResponseReady then
          LTiming.WriteTiming(LQueryOpenTicks, LSerializeTicks, LDataset,
            FStatusCode, LCustomerID <> '', Result);
      end;
      FreeAndNil(LDataset);
    end;
  finally
    FreeAndNil(LTiming);
  end;
end;

function TCustomerService.Insert: string;
var
  LCustomerID: string;
  LMessage: string;
  LRequest: TCustomerCreateRequest;
  LResponseData: string;
begin
  if not TCustomerValidator.ValidateCreate(FData, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LCustomerID := TGlobalFunction.NewDatabaseUUID;

  try
    FConnection.StartTransaction;
    try
      FRepository.CreateCustomer(LCustomerID, LRequest);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError(E));
      end;
    end;

    LResponseData := TCustomerDTO.CreateCustomerResponse(
      LCustomerID,
      LRequest.CustomerName,
      LRequest.Email,
      LRequest.PhoneNumber,
      LRequest.AddressLine1,
      LRequest.AddressLine2,
      LRequest.City,
      LRequest.State,
      LRequest.PostalCode,
      LRequest.Country,
      LRequest.Notes,
      LRequest.IsActive
    );
    FStatusCode := 201;
    Result := THelperResponse.CreateResponse(FStatusCode, 'Customer created', LResponseData);
  except
    on E: Exception do
      Result := InternalServerError(E);
  end;
end;

function TCustomerService.InternalServerError(AException: Exception): string;
begin
  THelperEndpoint.WriteErrorLog('Customer service error', AException);
  FStatusCode := 500;
  Result := THelperResponse.CreateResponse(FStatusCode, 'Internal server error.', FData);
end;

function TCustomerService.Update: string;
var
  LAddressLine1: string;
  LAddressLine2: string;
  LCity: string;
  LCountry: string;
  LCustomerName: string;
  LDataset: TFDQuery;
  LEmail: string;
  LIsActive: Integer;
  LMessage: string;
  LNotes: string;
  LPhoneNumber: string;
  LPostalCode: string;
  LRequest: TCustomerUpdateRequest;
  LResponseData: string;
  LState: string;
begin
  if not TCustomerValidator.ValidateUpdate(FData, FParts, LRequest, LMessage) then begin
    FStatusCode := 400;
    Exit(THelperResponse.CreateResponse(FStatusCode, LMessage, FData));
  end;

  LDataset := FRepository.FindCustomerByID(LRequest.CustomerID);
  try
    if LDataset.IsEmpty then begin
      FStatusCode := 404;
      Exit(THelperResponse.CreateResponse(FStatusCode, 'Customer not found', FData));
    end;

    LCustomerName := LDataset.FieldByName('customer_name').AsString;
    LEmail := LDataset.FieldByName('email').AsString;
    LPhoneNumber := LDataset.FieldByName('phone_number').AsString;
    LAddressLine1 := LDataset.FieldByName('address_line1').AsString;
    LAddressLine2 := LDataset.FieldByName('address_line2').AsString;
    LCity := LDataset.FieldByName('city').AsString;
    LState := LDataset.FieldByName('state').AsString;
    LPostalCode := LDataset.FieldByName('postal_code').AsString;
    LCountry := LDataset.FieldByName('country').AsString;
    LNotes := LDataset.FieldByName('notes').AsString;
    if LDataset.FieldByName('is_active').DataType = ftBoolean then
      LIsActive := Ord(LDataset.FieldByName('is_active').AsBoolean)
    else
      LIsActive := LDataset.FieldByName('is_active').AsInteger;
  finally
    FreeAndNil(LDataset);
  end;

  try
    FConnection.StartTransaction;
    try
      FRepository.UpdateCustomer(LRequest);
      FConnection.Commit;
    except
      on E: Exception do begin
        THelperTransaction.Rollback(FConnection);
        Exit(InternalServerError(E));
      end;
    end;

    if LRequest.HasCustomerName then
      LCustomerName := LRequest.CustomerName;
    if LRequest.HasEmail then
      LEmail := LRequest.Email;
    if LRequest.HasPhoneNumber then
      LPhoneNumber := LRequest.PhoneNumber;
    if LRequest.HasAddressLine1 then
      LAddressLine1 := LRequest.AddressLine1;
    if LRequest.HasAddressLine2 then
      LAddressLine2 := LRequest.AddressLine2;
    if LRequest.HasCity then
      LCity := LRequest.City;
    if LRequest.HasState then
      LState := LRequest.State;
    if LRequest.HasPostalCode then
      LPostalCode := LRequest.PostalCode;
    if LRequest.HasCountry then
      LCountry := LRequest.Country;
    if LRequest.HasNotes then
      LNotes := LRequest.Notes;
    if LRequest.HasIsActive then
      LIsActive := LRequest.IsActive;

    LResponseData := TCustomerDTO.CreateCustomerResponse(
      LRequest.CustomerID,
      LCustomerName,
      LEmail,
      LPhoneNumber,
      LAddressLine1,
      LAddressLine2,
      LCity,
      LState,
      LPostalCode,
      LCountry,
      LNotes,
      LIsActive
    );
    FStatusCode := 200;
    Result := THelperResponse.CreateResponse(FStatusCode, 'Customer updated', LResponseData);
  except
    on E: Exception do
      Result := InternalServerError(E);
  end;
end;

initialization
  GCustomerTimingEnabled := Trim(GetEnvironmentVariable('DELPHI_API_CUSTOMER_TIMING')) = '1';
  GCustomerTimingFormatSettings := TFormatSettings.Invariant;

end.
