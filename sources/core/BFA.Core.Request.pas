unit BFA.Core.Request;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  Data.DB,
  {$IF DEFINED (MSWINDOWS)}
    Vcl.Graphics,
  {$ENDIF}
  Web.HTTPApp;

type
  THelperRequest = class(TPersistent)
  public
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
  BFA.Core.Config;

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
