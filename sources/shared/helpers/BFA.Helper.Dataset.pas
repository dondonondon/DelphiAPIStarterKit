unit BFA.Helper.Dataset;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB, FireDAC.Stan.Intf, FireDAC.Comp.Client,
  FireDAC.Comp.DataSet, System.JSON;

type
  TTypeJSON = (ArrayData, ObjectData, None);

  THelperMemoryTable = class
  private
    class function CalculateStringSize(AValue: TJSONValue): Integer; static;
    class function GetJSONFieldType(AValue: TJSONValue): TFieldType; static;
    class function IsNestedValue(AValue: TJSONValue): Boolean; static;
    class function ReadJSONValue(AValue: TJSONValue): string; static;
    class procedure AddFieldDef(ADataset: TFDMemTable; const AFieldName: string; AFieldType: TFieldType;
      ASize: Integer = 0); static;
    class procedure CloseAndClear(ADataset: TFDMemTable); static;
    class procedure WriteJSONField(AField: TField; AValue: TJSONValue; ADecodeString: Boolean); static;
  public
    class function GetType(AJSON: String): TTypeJSON;
    class function IsEmpty(ADataset: TFDMemTable; AJSON: String; AFillDataIfFail: Boolean = True): Boolean;

    class procedure FillErrorData(ADataset: TFDMemTable; AMessage: String; IsEmptyData: Boolean = False);

    class procedure CreateDataset(ADataset: TFDMemTable; AJSONData: TJSONObject); overload;
    class procedure CreateDataset(ADataset: TFDMemTable; AJSONData: TJSONArray); overload;

    class procedure FillDataset(ADataset: TFDMemTable; AJSONData: TJSONObject; ADecodeString: Boolean = False); overload;
    class procedure FillDataset(ADataset: TFDMemTable; AJSONData: TJSONArray; ADecodeString: Boolean = False); overload;
  end;

  TMemoryTableHelper = class helper for TFDMemTable
    function LoadFromJSON(AJSON: String; AFillDataIfFail: Boolean = True; ADecodeString: Boolean = False): Boolean;
    function LoadFromXML(AXML: String; AFillDataIfFail: Boolean = True): Boolean;
    function LoadFromJSONTest(AJSON: String): Boolean;

    function ToJSONResponse(AStatusCode: Integer; AMessage: String): String; overload;
    function ToJSONResponse(AStatusCode: Integer; AMessage: String; ADataRequest: TFDMemTable): String; overload;
  end;

implementation

uses BFA.Core.Response, Xml.XMLIntf, Xml.XMLDoc;

const
  DEFAULT_STRING_SIZE = 250000;

function TMemoryTableHelper.LoadFromJSON(AJSON: String;
  AFillDataIfFail: Boolean; ADecodeString: Boolean): Boolean;
var
  JObjectData: TJSONObject;
  JArrayData: TJSONArray;
  JSONType: TTypeJSON;
begin
  Result := False;
  JObjectData := nil;
  JArrayData := nil;

  if THelperMemoryTable.IsEmpty(Self, AJSON, AFillDataIfFail) then Exit;

  JSONType := THelperMemoryTable.GetType(AJSON);
  try
    if JSONType = None then begin
      THelperMemoryTable.FillErrorData(Self, 'Invalid JSON : ' + AJSON, AFillDataIfFail);
      Exit;
    end;

    if JSONType = ObjectData then begin
      JObjectData := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
      if not Assigned(JObjectData) then begin
        THelperMemoryTable.FillErrorData(Self, 'Invalid JSON : ' + AJSON, AFillDataIfFail);
        Exit;
      end;
      THelperMemoryTable.CreateDataset(Self, JObjectData);
    end;
    if JSONType = ArrayData then begin
      JArrayData := TJSONObject.ParseJSONValue(AJSON) as TJSONArray;
      if not Assigned(JArrayData) then begin
        THelperMemoryTable.FillErrorData(Self, 'Invalid JSON : ' + AJSON, AFillDataIfFail);
        Exit;
      end;
      THelperMemoryTable.CreateDataset(Self, JArrayData);
    end;

    try
      if JSONType = ArrayData then THelperMemoryTable.FillDataset(Self, JArrayData, ADecodeString)
      else if JSONType = ObjectData then THelperMemoryTable.FillDataset(Self, JObjectData, ADecodeString);

      Result := True;
    except on E: Exception do
      THelperMemoryTable.FillErrorData(Self, 'Error parse JSON : ' + E.Message, AFillDataIfFail);
    end;
  finally
    FreeAndNil(JArrayData);
    FreeAndNil(JObjectData);
    if not Self.IsEmpty then Self.First;
  end;
end;

function TMemoryTableHelper.ToJSONResponse(AStatusCode: Integer;
  AMessage: String): String;
begin
  Result := THelperResponse.CreateResponse(AStatusCode, AMessage, Self);
end;

function TMemoryTableHelper.LoadFromJSONTest(AJSON: String): Boolean;
var
  LStringStream: TStringStream;
begin
  Result := False;

  LStringStream := TStringStream.Create(AJSON, TEncoding.UTF8);
  try
    LStringStream.Position := 0;
    try
      Self.LoadFromStream(LStringStream, sfJSON);

      Result := Self.Active;
      if Result then Result := not Self.IsEmpty;
    except on E : Exception do
      THelperMemoryTable.FillErrorData(Self, 'Invalid JSON : ' + E.Message);
    end;
  finally
    FreeAndNil(LStringStream);
  end;
end;

function TMemoryTableHelper.LoadFromXML(AXML: String; AFillDataIfFail: Boolean): Boolean;
var
  LXMLDocument: IXMLDocument;
  LRootNode: IXMLNode;
  JObjectData: TJSONObject;
  JArrayData: TJSONArray;

  function HasElementChildren(ANode: IXMLNode): Boolean;
  begin
    Result := False;
    if not Assigned(ANode) then Exit;

    for var I := 0 to ANode.ChildNodes.Count - 1 do
      if ANode.ChildNodes[I].NodeType = ntElement then
        Exit(True);
  end;

  function FirstElementChildName(ANode: IXMLNode): String;
  begin
    Result := '';
    if not Assigned(ANode) then Exit;

    for var I := 0 to ANode.ChildNodes.Count - 1 do
      if ANode.ChildNodes[I].NodeType = ntElement then
        Exit(ANode.ChildNodes[I].NodeName);
  end;

  function ElementChildCount(ANode: IXMLNode): Integer;
  begin
    Result := 0;
    if not Assigned(ANode) then Exit;

    for var I := 0 to ANode.ChildNodes.Count - 1 do
      if ANode.ChildNodes[I].NodeType = ntElement then
        Inc(Result);
  end;

  function ElementChildNameCount(ANode: IXMLNode; ANodeName: String): Integer;
  begin
    Result := 0;
    if not Assigned(ANode) then Exit;

    for var I := 0 to ANode.ChildNodes.Count - 1 do
      if (ANode.ChildNodes[I].NodeType = ntElement) and
         SameText(ANode.ChildNodes[I].NodeName, ANodeName) then
        Inc(Result);
  end;

  function IsArrayRoot(ANode: IXMLNode): Boolean;
  var
    LFirstName: String;
    LElementCount: Integer;
  begin
    Result := False;
    if not Assigned(ANode) then Exit;

    LElementCount := ElementChildCount(ANode);
    if LElementCount = 0 then Exit;

    LFirstName := FirstElementChildName(ANode);
    for var I := 0 to ANode.ChildNodes.Count - 1 do
      if (ANode.ChildNodes[I].NodeType = ntElement) and
         (not SameText(ANode.ChildNodes[I].NodeName, LFirstName)) then
        Exit;

    Result := (LElementCount > 1) or HasElementChildren(ANode.ChildNodes.FindNode(LFirstName));
  end;

  function XMLNodeToJSONObject(ANode: IXMLNode): TJSONObject;
  begin
    Result := TJSONObject.Create;
    try
      if Assigned(ANode.AttributeNodes) then begin
        for var I := 0 to ANode.AttributeNodes.Count - 1 do
          Result.AddPair(ANode.AttributeNodes[I].NodeName, ANode.AttributeNodes[I].Text);
      end;

      if not HasElementChildren(ANode) then begin
        Result.AddPair(ANode.NodeName, ANode.Text);
        Exit;
      end;

      for var I := 0 to ANode.ChildNodes.Count - 1 do begin
        if ANode.ChildNodes[I].NodeType <> ntElement then Continue;

        if HasElementChildren(ANode.ChildNodes[I]) or
           (ElementChildNameCount(ANode, ANode.ChildNodes[I].NodeName) > 1) then
          Result.AddPair(ANode.ChildNodes[I].NodeName, ANode.ChildNodes[I].XML)
        else
          Result.AddPair(ANode.ChildNodes[I].NodeName, ANode.ChildNodes[I].Text);
      end;
    except
      Result.Free;
      raise;
    end;
  end;
begin
  Result := False;
  JObjectData := nil;
  JArrayData := nil;

  if THelperMemoryTable.IsEmpty(Self, AXML, AFillDataIfFail) then Exit;

  try
    try
      LXMLDocument := TXMLDocument.Create(nil);
      LXMLDocument.LoadFromXML(AXML);
      LXMLDocument.Active := True;
      LRootNode := LXMLDocument.DocumentElement;

      if not Assigned(LRootNode) then begin
        THelperMemoryTable.FillErrorData(Self, 'Invalid XML : ' + AXML, AFillDataIfFail);
        Exit;
      end;

      try
        if IsArrayRoot(LRootNode) then begin
          JArrayData := TJSONArray.Create;
          for var I := 0 to LRootNode.ChildNodes.Count - 1 do
            if LRootNode.ChildNodes[I].NodeType = ntElement then
              JArrayData.AddElement(XMLNodeToJSONObject(LRootNode.ChildNodes[I]));

          THelperMemoryTable.CreateDataset(Self, JArrayData);
          THelperMemoryTable.FillDataset(Self, JArrayData);
        end else begin
          JObjectData := XMLNodeToJSONObject(LRootNode);
          THelperMemoryTable.CreateDataset(Self, JObjectData);
          THelperMemoryTable.FillDataset(Self, JObjectData);
        end;

        Result := True;
      except on E : Exception do
        THelperMemoryTable.FillErrorData(Self, 'Error parse XML : ' + E.Message, AFillDataIfFail);
      end;
    except on E : Exception do
      THelperMemoryTable.FillErrorData(Self, 'Invalid XML : ' + E.Message, AFillDataIfFail);
    end;
  finally
    FreeAndNil(JArrayData);
    FreeAndNil(JObjectData);
    if not Self.IsEmpty then Self.First;
  end;
end;

function TMemoryTableHelper.ToJSONResponse(AStatusCode: Integer; AMessage: String;
  ADataRequest: TFDMemTable): String;
begin
  Result := THelperResponse.CreateResponse(AStatusCode, AMessage, Self, ADataRequest);
end;

class procedure THelperMemoryTable.AddFieldDef(ADataset: TFDMemTable;
  const AFieldName: string; AFieldType: TFieldType; ASize: Integer);
var
  LFieldDef: TFieldDef;
begin
  LFieldDef := ADataset.FieldDefs.AddFieldDef;
  LFieldDef.Name := AFieldName;
  LFieldDef.DataType := AFieldType;

  if AFieldType = ftString then begin
    if ASize <= 0 then ASize := DEFAULT_STRING_SIZE;
    LFieldDef.Size := ASize;
  end;
end;

class function THelperMemoryTable.CalculateStringSize(AValue: TJSONValue): Integer;
var
  LText: string;
begin
  Result := DEFAULT_STRING_SIZE;
  if not Assigned(AValue) then Exit;

  LText := ReadJSONValue(AValue);
  if LText = '' then Exit;

  Result := Length(LText) + Round(Length(LText) * 0.25);
end;

class procedure THelperMemoryTable.CloseAndClear(ADataset: TFDMemTable);
begin
  if not Assigned(ADataset) then
    raise EArgumentNilException.Create('Dataset is required.');

  ADataset.Active := False;
  ADataset.Close;
  ADataset.FieldDefs.Clear;
end;

class procedure THelperMemoryTable.CreateDataset(ADataset: TFDMemTable;
  AJSONData: TJSONArray);
var
  ArrFields : array of record
    FieldType : TFieldType;
    Size : Integer;
    Name : String;
  end;

  JObjectData: TJSONObject;
  LJSONPair: TJSONPair;
  Index: Integer;
  LSize: Integer;
begin
  CloseAndClear(ADataset);

  if not Assigned(AJSONData) then
    raise EArgumentNilException.Create('JSON array is required.');

  if AJSONData.Count = 0 then begin
    ADataset.Open;
    Exit;
  end;

  if not (AJSONData.Items[0] is TJSONObject) then
    raise EInvalidOperation.Create('JSON array must contain objects.');

  JObjectData := TJSONObject(AJSONData.Items[0]);
  SetLength(ArrFields, JObjectData.Count);

  for var i := 0 to AJSONData.Count - 1 do begin
    if not (AJSONData.Items[i] is TJSONObject) then
      raise EInvalidOperation.Create('JSON array must contain objects.');

    JObjectData := TJSONObject(AJSONData.Items[i]);

    Index := 0;
    for LJSONPair in JObjectData do begin
      if Index >= Length(ArrFields) then Break;

      ArrFields[Index].Name := LJSONPair.JsonString.Value;

      if ArrFields[Index].FieldType <> ftString then begin
        ArrFields[Index].FieldType := GetJSONFieldType(LJSONPair.JsonValue);
        if ArrFields[Index].FieldType = ftString then
          ArrFields[Index].Size := CalculateStringSize(LJSONPair.JsonValue);
      end else begin
        LSize := CalculateStringSize(LJSONPair.JsonValue);
        if ArrFields[Index].Size < LSize then ArrFields[Index].Size := LSize;
      end;

      if IsNestedValue(LJSONPair.JsonValue) then begin
        if ArrFields[Index].FieldType <> ftString then begin
          ArrFields[Index].FieldType := ftString;
          ArrFields[Index].Size := CalculateStringSize(LJSONPair.JsonValue);
        end;
      end;

      Inc(Index);
    end;
  end;

  for var i := 0 to Length(ArrFields) - 1 do begin
    LSize := ArrFields[i].Size;
    if LSize = 0 then LSize := DEFAULT_STRING_SIZE;
    AddFieldDef(ADataset, ArrFields[i].Name, ArrFields[i].FieldType, LSize);
  end;

  ADataset.Open;
end;

class procedure THelperMemoryTable.CreateDataset(ADataset: TFDMemTable;
  AJSONData: TJSONObject);
var
  LJSONPair: TJSONPair;
begin
  CloseAndClear(ADataset);

  if not Assigned(AJSONData) then
    raise EArgumentNilException.Create('JSON object is required.');

  for LJSONPair in AJSONData do begin
    AddFieldDef(ADataset, LJSONPair.JsonString.Value, GetJSONFieldType(LJSONPair.JsonValue),
      CalculateStringSize(LJSONPair.JsonValue));
  end;

  ADataset.Open;
end;

class procedure THelperMemoryTable.FillDataset(ADataset: TFDMemTable;
  AJSONData: TJSONArray; ADecodeString: Boolean);
var
  JObjectData: TJSONObject;
  LValue: TJSONValue;
begin
  if not Assigned(AJSONData) then
    raise EArgumentNilException.Create('JSON array is required.');

  for var i := 0 to AJSONData.Count - 1 do begin
    if not (AJSONData.Items[i] is TJSONObject) then
      raise EInvalidOperation.Create('JSON array must contain objects.');

    JObjectData := TJSONObject(AJSONData.Items[i]);
    ADataset.Append;
    try
      for var ii := 0 to ADataset.FieldDefs.Count - 1 do begin
        LValue := JObjectData.GetValue(ADataset.FieldDefs[ii].Name);
        WriteJSONField(ADataset.Fields[ii], LValue, ADecodeString);
      end;
      ADataset.Post;
    except
      if ADataset.State in dsEditModes then ADataset.Cancel;
      raise;
    end;
  end;
end;

class procedure THelperMemoryTable.FillDataset(ADataset: TFDMemTable;
  AJSONData: TJSONObject; ADecodeString: Boolean);
var
  LValue: TJSONValue;
begin
  if not Assigned(AJSONData) then
    raise EArgumentNilException.Create('JSON object is required.');

  ADataset.Append;
  try
    for var ii := 0 to ADataset.FieldDefs.Count - 1 do begin
      LValue := AJSONData.GetValue(ADataset.FieldDefs[ii].Name);
      WriteJSONField(ADataset.Fields[ii], LValue, ADecodeString);
    end;
    ADataset.Post;
  except
    if ADataset.State in dsEditModes then ADataset.Cancel;
    raise;
  end;
end;

class procedure THelperMemoryTable.FillErrorData(ADataset: TFDMemTable;
  AMessage: String; IsEmptyData: Boolean);
begin
  CloseAndClear(ADataset);

  ADataset.FieldDefs.Add('status', ftInteger);
  ADataset.FieldDefs.Add('messages', ftString, Length(AMessage) + 10, False);

  ADataset.CreateDataSet;
  ADataset.Active := True;
  ADataset.Open;

  if not IsEmptyData then begin
    ADataset.Append;
    ADataset.Fields[0].AsString := '400';
    ADataset.Fields[1].AsString := AMessage;
    ADataset.Post;
  end;
end;

class function THelperMemoryTable.GetJSONFieldType(AValue: TJSONValue): TFieldType;
begin
  Result := ftString;
  if not Assigned(AValue) then Exit;

  if AValue is TJSONNumber then
    Result := ftFloat
  else if (AValue is TJSONTrue) or (AValue is TJSONFalse) then
    Result := ftBoolean;
end;

class function THelperMemoryTable.GetType(AJSON: String): TTypeJSON;
var
  FCheck: TJSONValue;
begin
  Result := None;
  FCheck := TJSONObject.ParseJSONValue(AJSON);
  try
    if FCheck is TJSONObject then Result := ObjectData
    else if FCheck is TJSONArray then Result := ArrayData;
  finally
    FreeAndNil(FCheck);
  end;
end;

class function THelperMemoryTable.IsEmpty(ADataset: TFDMemTable;
  AJSON: String; AFillDataIfFail: Boolean = True): Boolean;
var
  TempJSON: String;
begin
  TempJSON := Trim(AJSON);
  Result := (TempJSON = '') or SameText(TempJSON, '[]') or SameText(TempJSON, '{}');

  if Result then FillErrorData(ADataset, 'No data found', AFillDataIfFail);
end;

class function THelperMemoryTable.IsNestedValue(AValue: TJSONValue): Boolean;
begin
  Result := (AValue is TJSONObject) or (AValue is TJSONArray);
end;

class function THelperMemoryTable.ReadJSONValue(AValue: TJSONValue): string;
begin
  Result := '';
  if not Assigned(AValue) then Exit;

  if IsNestedValue(AValue) then
    Result := AValue.ToJSON
  else
    Result := AValue.Value;
end;

class procedure THelperMemoryTable.WriteJSONField(AField: TField;
  AValue: TJSONValue; ADecodeString: Boolean);
var
  LJSONType: TTypeJSON;
begin
  if not Assigned(AField) then Exit;

  if not Assigned(AValue) then begin
    AField.Clear;
    Exit;
  end;

  LJSONType := GetType(AValue.ToJSON);

  if ADecodeString then begin
    if LJSONType = None then begin
      if AField.DataType = ftString then
        AField.AsString := AValue.Value;
    end else begin
      AField.AsString := AValue.ToJSON;
    end;
  end else begin
    if LJSONType = None then
      AField.AsString := AValue.Value
    else
      AField.AsString := AValue.ToJSON;
  end;
end;

end.
