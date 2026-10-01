unit BFA.Core.Response;

interface

uses
  System.SysUtils, System.Classes,
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
  System.JSON, System.DateUtils, System.Generics.Collections,
  BFA.Helper.Strings, BFA.Core.Messages;

const
  STATUS_PROPERTY = 'status';
  MESSAGES_PROPERTY = 'messages';
  SERVER_TIME_PROPERTY = 'servertime';
  REQUEST_DETAIL_PROPERTY = 'request_detail';
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
    Result.AddPair(SERVER_TIME_PROPERTY, DateTimeToUnix(Now).ToString);
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

function TryParseNestedJSON(const AText: string; out AValue: TJSONValue): Boolean;
var
  LText: string;
begin
  Result := False;
  AValue := nil;
  LText := Trim(AText);

  if LText = '' then exit;
  if not (((LText.StartsWith('{')) and (LText.EndsWith('}'))) or
    ((LText.StartsWith('[')) and (LText.EndsWith(']')))) then exit;

  try
    AValue := TJSONObject.ParseJSONValue(LText);
    Result := Assigned(AValue);
  except
    FreeAndNil(AValue);
  end;
end;

function NormalizeJSONNode(ANode: TJSONValue): TJSONValue;
var
  I: Integer;
  LSourceObject: TJSONObject;
  LTargetObject: TJSONObject;
  LSourceArray: TJSONArray;
  LTargetArray: TJSONArray;
  LParsedValue: TJSONValue;
  LText: string;
begin
  Result := nil;
  if not Assigned(ANode) then exit;

  if ANode is TJSONObject then begin
    LSourceObject := TJSONObject(ANode);
    LTargetObject := TJSONObject.Create;
    try
      for I := 0 to LSourceObject.Count - 1 do begin
        LTargetObject.AddPair(LSourceObject.Pairs[I].JsonString.Value,
          NormalizeJSONNode(LSourceObject.Pairs[I].JsonValue));
      end;
      Result := LTargetObject;
    except
      FreeAndNil(LTargetObject);
      raise;
    end;
  end else if ANode is TJSONArray then begin
    LSourceArray := TJSONArray(ANode);
    LTargetArray := TJSONArray.Create;
    try
      for I := 0 to LSourceArray.Count - 1 do
        LTargetArray.AddElement(NormalizeJSONNode(LSourceArray.Items[I]));
      Result := LTargetArray;
    except
      FreeAndNil(LTargetArray);
      raise;
    end;
  end else if ANode is TJSONString then begin
    LText := TJSONString(ANode).Value;
    if TryParseNestedJSON(LText, LParsedValue) then begin
      try
        Result := NormalizeJSONNode(LParsedValue);
      finally
        FreeAndNil(LParsedValue);
      end;
    end else
      Result := TJSONString.Create(LText);
  end else if ANode is TJSONNumber then
    Result := TJSONNumber.Create(ANode.ToJSON)
  else if (ANode is TJSONTrue) or (ANode is TJSONFalse) then
    Result := TJSONBool.Create(ANode is TJSONTrue)
  else if ANode is TJSONNull then
    Result := TJSONNull.Create
  else
    Result := TJSONObject.ParseJSONValue(ANode.ToJSON);
end;

function JSONValueFromString(const AValue: string): TJSONValue;
var
  LJSONValue: TJSONValue;
begin
  if TryParseNestedJSON(AValue, LJSONValue) then begin
    try
      Result := NormalizeJSONNode(LJSONValue);
    finally
      FreeAndNil(LJSONValue);
    end;
    exit;
  end;

  if TValueValidator.IsNumber(AValue) then begin
    if (Length(AValue) > 1) and AValue.StartsWith('0') then
      Result := TJSONString.Create(AValue)
    else
      Result := TJSONNumber.Create(AValue);
  end else
    Result := TJSONString.Create(AValue);
end;

procedure AddJSONPairFromField(AObject: TJSONObject; const AName: string; AField: TField);
begin
  if AField.IsNull then begin
    AObject.AddPair(AName, TJSONNull.Create);
    exit;
  end;

  if AField.DataType = ftBoolean then
    AObject.AddPair(AName, TJSONBool.Create(AField.AsBoolean))
  else
    AObject.AddPair(AName, JSONValueFromString(AField.AsString));
end;

procedure AddResponseField(AObject: TJSONObject; AField: TField);
var
  LUnixTime: string;
begin
  if AField.IsNull then begin
    AObject.AddPair(AField.FieldName, TJSONNull.Create);
    exit;
  end;

  if AField.DataType = ftDateTime then begin
    AObject.AddPair(AField.FieldName, FormatDateTime('yyyy-mm-dd hh:nn:ss',
      AField.AsDateTime));
    LUnixTime := DateTimeToUnix(AField.AsDateTime).ToString;
    AObject.AddPair(AField.FieldName + '_unix', LUnixTime);
  end else if AField.DataType = ftDate then begin
    AObject.AddPair(AField.FieldName, FormatDateTime('yyyy-mm-dd', AField.AsDateTime));
    LUnixTime := DateTimeToUnix(AField.AsDateTime).ToString;
    AObject.AddPair(AField.FieldName + '_unix', LUnixTime);
  end else
    AddJSONPairFromField(AObject, AField.FieldName, AField);
end;

function CreateDatasetObject(ADataset: TDataset; AFormatResponseFields: Boolean): TJSONObject;
var
  I: Integer;
  LField: TField;
begin
  Result := TJSONObject.Create;
  try
    for I := 0 to ADataset.FieldDefs.Count - 1 do begin
      LField := ADataset.FieldByName(ADataset.FieldDefs[I].Name);
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
    for LRecordIndex := 0 to ADataset.RecordCount - 1 do begin
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
    if not Assigned(LParsedValue) then exit;

    try
      if LParsedValue is TJSONArray then begin
        for I := 0 to TJSONArray(LParsedValue).Count - 1 do
          Result.AddElement(TJSONArray(LParsedValue).Items[I].Clone as TJSONValue);
      end else if LParsedValue is TJSONObject then
        Result.AddElement(LParsedValue.Clone as TJSONValue);
    finally
      FreeAndNil(LParsedValue);
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function CreateQueryArray(AQuery: TFDQuery; AEncodeString: Boolean): TJSONArray;
var
  LData: TJSONObject;
  LField: TField;
  LValue: string;
begin
  Result := TJSONArray.Create;
  try
    if not Assigned(AQuery) or not AQuery.Active or AQuery.IsEmpty then exit;

    AQuery.First;
    while not AQuery.Eof do begin
      LData := TJSONObject.Create;
      try
        for LField in AQuery.Fields do begin
          if LField.IsNull then begin
            LData.AddPair(LField.FieldName, TJSONNull.Create);
            continue;
          end;

          case LField.DataType of
            ftSmallint, ftInteger, ftLargeint, ftFloat, ftCurrency, ftBCD, ftFMTBcd:
              LData.AddPair(LField.FieldName, TJSONNumber.Create(LField.AsString));
            ftBoolean:
              LData.AddPair(LField.FieldName, TJSONBool.Create(LField.AsBoolean));
          else
            LValue := LField.AsString;
            if AEncodeString then
              LData.AddPair(LField.FieldName, TGlobalFunction.EncodeBase64(LValue))
            else
              LData.AddPair(LField.FieldName, JSONValueFromString(LValue));
          end;
        end;
        Result.AddElement(LData);
        LData := nil;
      finally
        FreeAndNil(LData);
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

class function THelperResponse.CreateResponse(AStatusCode: Integer;
  AMessage: string; ADataResponse, ARequest: TDataSet): string;
var
  LResponse: TJSONObject;
  LRequestDetail: TJSONObject;
  LData: TJSONArray;
begin
  LResponse := CreateResponseEnvelope(AStatusCode, AMessage);
  try
    if Assigned(ARequest) and ARequest.Active and not ARequest.IsEmpty then begin
      ARequest.First;
      LRequestDetail := CreateDatasetObject(ARequest, False);
      LResponse.AddPair(REQUEST_DETAIL_PROPERTY, LRequestDetail);
    end;

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
    LData := CreateObjectDataArray;
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
