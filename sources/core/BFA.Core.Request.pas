unit BFA.Core.Request;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  FireDAC.Comp.Client,
  Data.DB,
  {$IF DEFINED (MSWINDOWS)}
    Vcl.Graphics,
  {$ENDIF}
  Web.HTTPApp;

type
  ERequestInvalid = class(Exception)
  private
    FStatus: Integer;
  public
    constructor Create(const AMessage: string; AStatus: Integer = 400);
    property Status: Integer read FStatus;
  end;

  THelperRequest = class(TPersistent)
  private
    class procedure ValidateJSON(AValue: TJSONValue; ADepth: Integer); static;
  public
    class function ParseJSON(const AText: string): TJSONValue; static;
    class function JSONObject(ARequest: TWebRequest; const AAllowed: array of string): TJSONObject; static;
    class function JSONString(AObject: TJSONObject; const AName: string; ARequired: Boolean;
      AMaximum: Integer): string; static;
    class function JSONInteger(AObject: TJSONObject; const AName: string; AMinimum, AMaximum, ADefault: Integer): Integer; static;
    class function Codepoints(const AText: string): Integer; static;
    class function StreamSizeSafe(AStream: TStream): Int64; static;
    class function SaveFile(const AFolder, AFileName: string; ARequest: TWebRequest; var AOutputMessage: string;
      AIndex: Integer = 0): Boolean; static;
    class function RequestFileToBase64(ARequest: TWebRequest; var AOutputMessage: string; AIndex: Integer = 0): string; static;
    {$IF DEFINED (MSWINDOWS)}
    class function RequestFileToBitmap(ARequest: TWebRequest; var AOutputMessage: string; AIndex: Integer): TBitmap; static;
    {$ENDIF}
    class function CreateDataset(AConnection: TFDConnection): TFDQuery; static;
  end;

implementation

uses
  System.NetEncoding,
  System.RegularExpressions,
  BFA.Core.Config;

constructor ERequestInvalid.Create(const AMessage: string; AStatus: Integer);
begin
  inherited Create(AMessage);
  FStatus := AStatus;
end;

class procedure THelperRequest.ValidateJSON(AValue: TJSONValue; ADepth: Integer);
var I, J: Integer; LObject: TJSONObject; LName: string;
begin
  if ADepth > 4 then raise ERequestInvalid.Create('JSON nesting exceeds limit.');
  if AValue is TJSONObject then begin
    LObject := TJSONObject(AValue);
    if LObject.Count > 32 then raise ERequestInvalid.Create('Too many request fields.');
    for I := 0 to LObject.Count - 1 do begin
      LName := LObject.Pairs[I].JsonString.Value;
      if (Codepoints(LName) = 0) or (Length(LName) > 64) then raise ERequestInvalid.Create('Invalid field name.');
      for J := 0 to I - 1 do begin
        if SameText(LName, LObject.Pairs[J].JsonString.Value) then raise ERequestInvalid.Create('Duplicate request field.');
      end;
      ValidateJSON(LObject.Pairs[I].JsonValue, ADepth + 1);
    end;
  end else if AValue is TJSONArray then begin
    if TJSONArray(AValue).Count > 1000 then raise ERequestInvalid.Create('Too many rows.');
    for I := 0 to TJSONArray(AValue).Count - 1 do ValidateJSON(TJSONArray(AValue).Items[I], ADepth + 1);
  end else if AValue is TJSONString then Codepoints(AValue.Value)
  else if AValue is TJSONNumber then begin
    if not TRegEx.IsMatch(AValue.Value, '^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$') then
      raise ERequestInvalid.Create('Invalid JSON number.');
  end;
end;

class function THelperRequest.ParseJSON(const AText: string): TJSONValue;
var I, LDepth: Integer; LQuoted, LEscaped: Boolean;
begin
  Result := nil;
  if TEncoding.UTF8.GetByteCount(AText) > 16384 then raise ERequestInvalid.Create('Request body exceeds limit.', 413);
  Codepoints(AText);
  LDepth := 0;
  LQuoted := False;
  LEscaped := False;
  for I := 1 to Length(AText) do begin
    if LQuoted then begin
      if Ord(AText[I]) < 32 then raise ERequestInvalid.Create('Invalid JSON string.');
      if LEscaped then LEscaped := False
      else if AText[I] = '\' then LEscaped := True
      else if AText[I] = '"' then LQuoted := False;
    end else begin
      if AText[I] = '"' then LQuoted := True
      else if CharInSet(AText[I], ['{','[']) then Inc(LDepth)
      else if CharInSet(AText[I], ['}',']']) then Dec(LDepth);
      if (LDepth < 0) or (LDepth > 4) then raise ERequestInvalid.Create('Invalid JSON structure.');
    end;
  end;
  if LQuoted or (LDepth <> 0) then raise ERequestInvalid.Create('Invalid JSON.');
  Result := TJSONObject.ParseJSONValue(AText, True, False);
  if not Assigned(Result) then raise ERequestInvalid.Create('Invalid JSON.');
  try
    ValidateJSON(Result, 0);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class function THelperRequest.Codepoints(const AText: string): Integer;
var I, LCode: Integer;
begin
  Result := 0;
  I := 1;
  while I <= Length(AText) do begin
    LCode := Ord(AText[I]);
    if LCode = 0 then raise ERequestInvalid.Create('Invalid string.');
    if (LCode >= $D800) and (LCode <= $DBFF) then begin
      Inc(I);
      if (I > Length(AText)) or (Ord(AText[I]) < $DC00) or (Ord(AText[I]) > $DFFF) then
        raise ERequestInvalid.Create('Invalid Unicode.');
    end else if (LCode >= $DC00) and (LCode <= $DFFF) then raise ERequestInvalid.Create('Invalid Unicode.');
    Inc(Result);
    Inc(I);
  end;
end;

class function THelperRequest.JSONObject(ARequest: TWebRequest; const AAllowed: array of string): TJSONObject;
var LValue: TJSONValue; LText, LName: string; I, J: Integer; LAllowed: Boolean;
begin
  Result := nil;
  if not Assigned(ARequest) then raise ERequestInvalid.Create('Invalid request.');
  if not SameText(ARequest.ContentType.Split([';'])[0].Trim, 'application/json') then
    raise ERequestInvalid.Create('Content-Type must be application/json.', 415);
  LText := ARequest.Content;
  if (ARequest.ContentLength > 16384) or (TEncoding.UTF8.GetByteCount(LText) > 16384) then
    raise ERequestInvalid.Create('Request body exceeds limit.', 413);
  LValue := ParseJSON(LText);
  if not (LValue is TJSONObject) then begin
    FreeAndNil(LValue);
    raise ERequestInvalid.Create('A single JSON object is required.');
  end;
  Result := TJSONObject(LValue);
  try
    if Result.Count > 32 then raise ERequestInvalid.Create('Too many request fields.');
    for I := 0 to Result.Count - 1 do begin
      LName := Result.Pairs[I].JsonString.Value;
      LAllowed := False;
      for J := 0 to High(AAllowed) do if LName = AAllowed[J] then LAllowed := True;
      if not LAllowed then raise ERequestInvalid.Create('Unknown request field.');
      for J := 0 to I - 1 do if LName = Result.Pairs[J].JsonString.Value then
        raise ERequestInvalid.Create('Duplicate request field.');
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class function THelperRequest.JSONString(AObject: TJSONObject; const AName: string; ARequired: Boolean;
  AMaximum: Integer): string;
var LValue: TJSONValue;
begin
  Result := '';
  LValue := AObject.GetValue(AName);
  if not Assigned(LValue) then begin
    if ARequired then raise ERequestInvalid.Create(AName + ' required.');
    Exit;
  end;
  if not (LValue is TJSONString) then raise ERequestInvalid.Create(AName + ' must be a string.');
  Result := LValue.Value;
  if (Codepoints(Result) > AMaximum) or (ARequired and (Result = '')) then
    raise ERequestInvalid.Create('Invalid ' + AName + ' length.');
end;

class function THelperRequest.JSONInteger(AObject: TJSONObject; const AName: string;
  AMinimum, AMaximum, ADefault: Integer): Integer;
var LValue: TJSONValue;
begin
  Result := ADefault;
  LValue := AObject.GetValue(AName);
  if not Assigned(LValue) then Exit;
  if not (LValue is TJSONNumber) or not TRegEx.IsMatch(LValue.Value, '^-?(0|[1-9][0-9]*)$') or
    not TryStrToInt(LValue.Value, Result) or (Result < AMinimum) or (Result > AMaximum) then
    raise ERequestInvalid.Create('Invalid ' + AName + '.');
end;

class function THelperRequest.CreateDataset(AConnection: TFDConnection): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := AConnection;
  Result.FetchOptions.RowsetSize := 1000;
end;

class function THelperRequest.RequestFileToBase64(ARequest: TWebRequest;
  var AOutputMessage: string; AIndex: Integer): string;
var
  LMemStream: TMemoryStream;
  LStream: TStream;
  LSize: Int64;
begin
  Result := '';
  AOutputMessage := '';

  if not Assigned(ARequest) or (ARequest.Files.Count = 0) then
  begin
    AOutputMessage := 'No file uploaded';
    Exit;
  end;

  if (AIndex < 0) or (AIndex >= ARequest.Files.Count) then
  begin
    AOutputMessage := 'Invalid file index';
    Exit;
  end;

  LStream := ARequest.Files[AIndex].Stream;
  if not Assigned(LStream) then
  begin
    AOutputMessage := 'Invalid file stream';
    Exit;
  end;

  LSize := StreamSizeSafe(LStream);
  if LSize <= 0 then
  begin
    AOutputMessage := 'Empty file';
    Exit;
  end;

  if LSize > TServerConfig.MAX_FILE_SIZE then
  begin
    AOutputMessage := 'File size exceeds limit';
    Exit;
  end;

  LMemStream := TMemoryStream.Create;
  try
    LStream.Position := 0;
    LMemStream.CopyFrom(LStream, LSize);
    LMemStream.Position := 0;

    Result := TNetEncoding.Base64.EncodeBytesToString(LMemStream.Memory, LMemStream.Size);
  finally
    FreeAndNil(LMemStream);
  end;
end;

{$IF DEFINED (MSWINDOWS)}
class function THelperRequest.RequestFileToBitmap(ARequest: TWebRequest;
  var AOutputMessage: string; AIndex: Integer): TBitmap;
var
  LStream: TStream;
  LSize: Int64;
  LBitmap: TBitmap;
begin
  Result := nil;
  AOutputMessage := '';

  if not Assigned(ARequest) or (ARequest.Files.Count = 0) then
  begin
    AOutputMessage := 'No file uploaded';
    Exit;
  end;

  if (AIndex < 0) or (AIndex >= ARequest.Files.Count) then
  begin
    AOutputMessage := 'Invalid file index';
    Exit;
  end;

  LStream := ARequest.Files[AIndex].Stream;
  if not Assigned(LStream) then
  begin
    AOutputMessage := 'Invalid file stream';
    Exit;
  end;

  LSize := StreamSizeSafe(LStream);
  if LSize <= 0 then
  begin
    AOutputMessage := 'Empty file';
    Exit;
  end;

  if LSize > TServerConfig.MAX_FILE_SIZE then
  begin
    AOutputMessage := 'File size exceeds limit';
    Exit;
  end;

  LStream.Position := 0;
  LBitmap := TBitmap.Create;
  try
    LBitmap.LoadFromStream(LStream);
    Result := LBitmap;
  except
    on E: Exception do
    begin
      FreeAndNil(LBitmap);
      AOutputMessage := 'Failed to load image';
    end;
  end;
end;
{$ENDIF}

class function THelperRequest.SaveFile(const AFolder, AFileName: string;
  ARequest: TWebRequest; var AOutputMessage: string; AIndex: Integer): Boolean;
var
  LStream: TStream;
  LSize: Int64;
  LContentFile: TStream;
  LFileUpload: TFileStream;
  LFileLocation: string;
begin
  Result := False;
  AOutputMessage := '';

  if AFileName = '' then
  begin
    AOutputMessage := 'Nama file kosong';
    Exit;
  end;

  if ARequest.Files.Count = 0 then
    Exit;

  LStream := ARequest.Files[AIndex].Stream;
  LSize := StreamSizeSafe(LStream);
  if LSize > TServerConfig.MAX_FILE_SIZE then
  begin
    AOutputMessage := 'File size exceeds limit';
    Exit;
  end;

  LFileLocation := AFolder + PathDelim + AFileName;

  LContentFile := ARequest.Files[AIndex].Stream;
  LContentFile.Position := 0;
  LFileUpload := TFileStream.Create(LFileLocation, fmCreate);
  try
    LFileUpload.CopyFrom(LContentFile, LContentFile.Size);
    Result := True;
  finally
    FreeAndNil(LFileUpload);
  end;
end;

class function THelperRequest.StreamSizeSafe(AStream: TStream): Int64;
var
  LPosition: Int64;
begin
  if not Assigned(AStream) then
    Exit(0);

  LPosition := AStream.Position;
  try
    Result := AStream.Size;
  finally
    AStream.Position := LPosition;
  end;
end;

end.
