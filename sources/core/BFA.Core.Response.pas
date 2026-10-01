unit BFA.Core.Response;

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  Data.DB,
  FireDAC.Comp.Client;

type
  TFDQueryJSONHelper = class helper for TFDQuery
    function ToJSON: string; overload;
    function ToJSONArray(AEncodeString: Boolean = False): string; overload;
    function ToJSONResponse(AStatusCode: Integer; AMessage: string): string; overload;
    function ToJSONResponse(AStatusCode: Integer; AMessage: string;
      AMemoryTable: TFDMemTable): string; overload;
  end;

  TJSONPayloadBuilder = class
    class function FromDataset(ADataset: TDataset): string;
    class function FromStringList(AValues: TStringList): string;
    class function FormatJSON(AJSON: string): string;
  end;

  THelperResponse = class
    class function FieldValue(AField: TField): TJSONValue; static;
    class function CreateResponse(AStatusCode: Integer; AMessage: string; ADataResponse: TJSONArray): string; overload;
    class function IsValidDateTime(const AText: string): Boolean;
    class function CreateResponse(AStatusCode: Integer; AMessage: string;
      ADataResponse: TDataset; ARequest: TDataSet = nil): string; overload;
    class function CreateResponse(AStatusCode: Integer; AMessage: string;
      ADataResponse: TStringList): string; overload;
    class function CreateResponse(AStatusCode: Integer; AMessage: string): string; overload;
    class function CreateResponse(AStatusCode: Integer): string; overload;
    class function CreateResponse(AStatusCode: Integer; AMessage: string;
      const AJSONData: string): string; overload;
    class function CreateResponse(AStatusCode: Integer; AMessage: string;
      const AKeyValues: TArray<string>): string; overload;
    class function CreateInternalServerError(AData: TFDMemTable): string; static;
  end;

  TValueValidator = class
    class function IsNumber(AValue: string): Boolean;
    class function IsFloat(AValue: string): Boolean;
    class function IsInteger(AValue: string): Boolean;
  end;

implementation

uses
  System.DateUtils, System.Generics.Collections,
  BFA.Helper.Strings, BFA.Core.Messages, BFA.Helper.Clock, Data.FmtBcd, System.Math;

const
  STATUS_PROPERTY = 'status';
  MESSAGES_PROPERTY = 'messages';
  SERVER_TIME_PROPERTY = 'servertime';
  DATA_PROPERTY = 'data';

function IsSuccessStatus(AStatusCode: Integer): Boolean;
begin
  Result := (AStatusCode >= 200) and (AStatusCode <= 299);
end;

function CreateResponseEnvelope(AStatusCode: Integer; const AMessage: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair(STATUS_PROPERTY, TJSONNumber.Create(AStatusCode));
    Result.AddPair(MESSAGES_PROPERTY, AMessage);
    Result.AddPair(SERVER_TIME_PROPERTY, THelperClock.UnixNow.ToString);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function CreateObjectDataArray: TJSONArray;
begin
  Result := TJSONArray.Create;
  try
    Result.AddElement(TJSONObject.Create);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function SerializeResponse(AResponse: TJSONObject; AStatusCode: Integer;
  AData: TJSONArray): string;
var
  LData: TJSONArray;
begin
  LData := AData;
  if not IsSuccessStatus(AStatusCode) then begin
    FreeAndNil(LData);
    LData := CreateObjectDataArray;
  end else if not Assigned(LData) then
    LData := TJSONArray.Create;

  AResponse.AddPair(DATA_PROPERTY, LData);
  Result := AResponse.ToJSON;
end;

function JSONValueFromString(const AValue: string): TJSONValue;
begin
  Result := TJSONString.Create(AValue);
end;

class function THelperResponse.FieldValue(AField: TField): TJSONValue;
var LNumber: string;
begin
  if AField.IsNull then Exit(TJSONNull.Create);
  case AField.DataType of
    ftSmallint, ftInteger, ftWord, ftLargeint, ftLongWord, ftShortint, ftByte, ftAutoInc:
      Result := TJSONNumber.Create(AField.AsLargeInt);
    ftBoolean: Result := TJSONBool.Create(AField.AsBoolean);
    ftFMTBcd: Result := TJSONNumber.Create(BcdToStr(TFMTBCDField(AField).AsBCD, TFormatSettings.Invariant));
    ftCurrency, ftBCD: Result := TJSONNumber.Create(CurrToStr(AField.AsCurrency, TFormatSettings.Invariant));
    ftFloat, ftSingle, ftExtended: begin
      if IsNan(AField.AsFloat) or IsInfinite(AField.AsFloat) then raise EConvertError.Create('Non-finite JSON number.');
      LNumber := FloatToStr(AField.AsFloat, TFormatSettings.Invariant);
      Result := TJSONNumber.Create(LNumber);
    end;
    ftDate: Result := TJSONString.Create(FormatDateTime('yyyy-mm-dd', AField.AsDateTime, TFormatSettings.Invariant));
    ftTime: Result := TJSONString.Create(FormatDateTime('hh:nn:ss', AField.AsDateTime, TFormatSettings.Invariant));
    ftDateTime, ftTimeStamp: Result := TJSONString.Create(THelperClock.ISO8601UTC(AField.AsDateTime));
  else Result := TJSONString.Create(AField.AsString);
  end;
end;

procedure AddJSONPairFromField(AObject: TJSONObject; const AName: string; AField: TField);
begin
  AObject.AddPair(AName, THelperResponse.FieldValue(AField));
end;

procedure AddResponseField(AObject: TJSONObject; AField: TField);
begin
  AddJSONPairFromField(AObject, AField.FieldName, AField);
  if not AField.IsNull and (AField.DataType in [ftDateTime, ftTimeStamp]) then
    AObject.AddPair(AField.FieldName + '_unix', THelperClock.UnixUTC(AField.AsDateTime).ToString);
end;

function CreateDatasetObject(ADataset: TDataset; AFormatResponseFields: Boolean): TJSONObject;
var
  I: Integer;
  LField: TField;
begin
  Result := TJSONObject.Create;
  try
    for LField in ADataset.Fields do begin
      if AFormatResponseFields then
        AddResponseField(Result, LField)
      else
        AddJSONPairFromField(Result, LField.FieldName, LField);
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function CreateDatasetArray(ADataset: TDataset; AFormatResponseFields: Boolean): TJSONArray;
var
  LRecordIndex: Integer;
begin
  Result := TJSONArray.Create;
  try
    if not Assigned(ADataset) or not ADataset.Active or ADataset.IsEmpty then exit;

    ADataset.First;
    while not ADataset.Eof do begin
      Result.AddElement(CreateDatasetObject(ADataset, AFormatResponseFields));
      ADataset.Next;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function CreateStringListObject(AValues: TStringList): TJSONObject;
var
  I: Integer;
  LKey: string;
begin
  Result := TJSONObject.Create;
  try
    if not Assigned(AValues) then exit;

    for I := 0 to AValues.Count - 1 do begin
      LKey := AValues.KeyNames[I];
      if LKey = '' then continue;
      Result.AddPair(LKey, JSONValueFromString(AValues.Values[LKey]));
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function CreateStringListArray(AValues: TStringList): TJSONArray;
begin
  Result := TJSONArray.Create;
  try
    if not Assigned(AValues) or (AValues.Count = 0) then Exit;
    Result.AddElement(CreateStringListObject(AValues));
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function CreateKeyValueArray(const AKeyValues: TArray<string>): TJSONArray;
var
  I: Integer;
  LData: TJSONObject;
begin
  Result := TJSONArray.Create;
  try
    LData := TJSONObject.Create;
    Result.AddElement(LData);
    I := 0;
    while I < Length(AKeyValues) - 1 do begin
      LData.AddPair(AKeyValues[I], JSONValueFromString(AKeyValues[I + 1]));
      Inc(I, 2);
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function CreateRawJSONDataArray(const AJSONData: string): TJSONArray;
var
  I: Integer;
  LParsedValue: TJSONValue;
begin
  Result := TJSONArray.Create;
  try
    LParsedValue := TJSONObject.ParseJSONValue(AJSONData);
    if not Assigned(LParsedValue) then raise EConvertError.Create('Invalid response JSON.');

    try
      if LParsedValue is TJSONArray then begin
        for I := 0 to TJSONArray(LParsedValue).Count - 1 do
          Result.AddElement(TJSONArray(LParsedValue).Items[I].Clone as TJSONValue);
      end else if LParsedValue is TJSONObject then
        Result.AddElement(LParsedValue.Clone as TJSONValue)
      else raise EConvertError.Create('Response JSON object or array required.');
    finally
      FreeAndNil(LParsedValue);
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function CreateQueryArray(AQuery: TFDQuery; AEncodeString: Boolean): TJSONArray;
var LRow: TJSONObject; LField: TField;
begin
  Result := TJSONArray.Create;
  try
    if not Assigned(AQuery) or not AQuery.Active or AQuery.IsEmpty then Exit;
    AQuery.First;
    while not AQuery.Eof do begin
      LRow := TJSONObject.Create;
      Result.AddElement(LRow);
      for LField in AQuery.Fields do begin
        if AEncodeString and not LField.IsNull and
          (LField.DataType in [ftString,ftWideString,ftMemo,ftWideMemo,ftFixedChar,ftFixedWideChar]) then
          LRow.AddPair(LField.FieldName, TGlobalFunction.EncodeBase64(LField.AsString))
        else AddJSONPairFromField(LRow, LField.FieldName, LField);
      end;
      AQuery.Next;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TFDQueryJSONHelper.ToJSONResponse(AStatusCode: Integer; AMessage: string): string;
begin
  Result := THelperResponse.CreateResponse(AStatusCode, AMessage, Self);
end;

function TFDQueryJSONHelper.ToJSONResponse(AStatusCode: Integer; AMessage: string;
  AMemoryTable: TFDMemTable): string;
begin
  Result := THelperResponse.CreateResponse(AStatusCode, AMessage, Self, AMemoryTable);
end;

function TFDQueryJSONHelper.ToJSONArray(AEncodeString: Boolean): string;
var
  LData: TJSONArray;
begin
  LData := CreateQueryArray(Self, AEncodeString);
  try
    Result := LData.ToJSON;
  finally
    FreeAndNil(LData);
  end;
end;

function TFDQueryJSONHelper.ToJSON: string;
var
  LData: TJSONArray;
begin
  LData := CreateDatasetArray(Self, False);
  try
    Result := LData.ToJSON;
  finally
    FreeAndNil(LData);
  end;
end;

class function THelperResponse.CreateResponse(AStatusCode: Integer; AMessage: string; ADataResponse: TJSONArray): string;
var LResponse: TJSONObject; LData: TJSONArray;
begin
  LResponse := CreateResponseEnvelope(AStatusCode, AMessage);
  try
    if Assigned(ADataResponse) then LData := TJSONArray(ADataResponse.Clone) else LData := TJSONArray.Create;
    Result := SerializeResponse(LResponse, AStatusCode, LData);
  finally
    FreeAndNil(LResponse);
  end;
end;

class function THelperResponse.CreateResponse(AStatusCode: Integer;
  AMessage: string; ADataResponse, ARequest: TDataSet): string;
var
  LResponse: TJSONObject;
  LData: TJSONArray;
begin
  LResponse := CreateResponseEnvelope(AStatusCode, AMessage);
  try
    LData := CreateDatasetArray(ADataResponse, True);
    Result := SerializeResponse(LResponse, AStatusCode, LData);
  finally
    FreeAndNil(LResponse);
  end;
end;

class function THelperResponse.CreateResponse(AStatusCode: Integer;
  AMessage: string; ADataResponse: TStringList): string;
var
  LResponse: TJSONObject;
  LData: TJSONArray;
begin
  LResponse := CreateResponseEnvelope(AStatusCode, AMessage);
  try
    LData := CreateStringListArray(ADataResponse);
    Result := SerializeResponse(LResponse, AStatusCode, LData);
  finally
    FreeAndNil(LResponse);
  end;
end;

class function THelperResponse.CreateResponse(AStatusCode: Integer;
  AMessage: string): string;
var
  LResponse: TJSONObject;
  LData: TJSONArray;
begin
  LResponse := CreateResponseEnvelope(AStatusCode, AMessage);
  try
    LData := TJSONArray.Create;
    Result := SerializeResponse(LResponse, AStatusCode, LData);
  finally
    FreeAndNil(LResponse);
  end;
end;

class function THelperResponse.CreateResponse(AStatusCode: Integer): string;
begin
  Result := CreateResponse(AStatusCode, TRestMessage.GetMessage(AStatusCode));
end;

class function THelperResponse.CreateResponse(AStatusCode: Integer;
  AMessage: string; const AJSONData: string): string;
var
  LResponse: TJSONObject;
  LData: TJSONArray;
begin
  LResponse := CreateResponseEnvelope(AStatusCode, AMessage);
  try
    LData := CreateRawJSONDataArray(AJSONData);
    Result := SerializeResponse(LResponse, AStatusCode, LData);
  finally
    FreeAndNil(LResponse);
  end;
end;

class function THelperResponse.CreateResponse(AStatusCode: Integer;
  AMessage: string; const AKeyValues: TArray<string>): string;
var
  LResponse: TJSONObject;
  LData: TJSONArray;
begin
  LResponse := CreateResponseEnvelope(AStatusCode, AMessage);
  try
    LData := CreateKeyValueArray(AKeyValues);
    Result := SerializeResponse(LResponse, AStatusCode, LData);
  finally
    FreeAndNil(LResponse);
  end;
end;

class function THelperResponse.CreateInternalServerError(
  AData: TFDMemTable): string;
begin
  Result := CreateResponse(500, 'Internal server error.', AData);
end;

class function THelperResponse.IsValidDateTime(const AText: string): Boolean;
var
  LDateTime: TDateTime;
begin
  Result := TryStrToDateTime(AText, LDateTime);
end;

class function TJSONPayloadBuilder.FormatJSON(AJSON: string): string;
var
  LJSONValue: TJSONValue;
begin
  Result := '';
  LJSONValue := TJSONObject.ParseJSONValue(AJSON);
  try
    if (LJSONValue is TJSONObject) or (LJSONValue is TJSONArray) then
      Result := LJSONValue.Format;
  finally
    FreeAndNil(LJSONValue);
  end;
end;

class function TJSONPayloadBuilder.FromDataset(ADataset: TDataset): string;
var
  LResult: TJSONObject;
  LData: TJSONArray;
begin
  Result := '';
  if not Assigned(ADataset) then exit;

  LResult := TJSONObject.Create;
  try
    LData := CreateDatasetArray(ADataset, False);
    LResult.AddPair(DATA_PROPERTY, LData);
    Result := LResult.ToJSON;
  finally
    FreeAndNil(LResult);
  end;
end;

class function TJSONPayloadBuilder.FromStringList(AValues: TStringList): string;
var
  LResult: TJSONObject;
begin
  Result := '';
  if not Assigned(AValues) or (AValues.Count = 0) then exit;

  LResult := CreateStringListObject(AValues);
  try
    Result := LResult.ToJSON;
  finally
    FreeAndNil(LResult);
  end;
end;

class function TValueValidator.IsFloat(AValue: string): Boolean;
var
  LDummy: Single;
begin
  Result := TryStrToFloat(AValue, LDummy);
end;

class function TValueValidator.IsInteger(AValue: string): Boolean;
var
  LDummy: Integer;
begin
  Result := TryStrToInt(AValue, LDummy);
end;

class function TValueValidator.IsNumber(AValue: string): Boolean;
var
  LDummy: Single;
  LFormatSettings: TFormatSettings;
begin
  LFormatSettings := TFormatSettings.Create('en-US');
  Result := (Pos(',', AValue) = 0) and TryStrToFloat(AValue, LDummy, LFormatSettings);
end;

end.
