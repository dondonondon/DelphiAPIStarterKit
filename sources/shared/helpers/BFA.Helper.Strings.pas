unit BFA.Helper.Strings;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.NetEncoding,
  System.DateUtils,
  System.IniFiles,
  System.IOUtils,
  System.Hash;

type
  TGlobalFunction = class
    class procedure CreateBaseDirectory;
    class function GetBaseDirectory : String;
    class function LoadFile(AFileName : String) : String;

    class procedure SaveSettingString(Section, Name, Value: string);
    class function LoadSettingString(Section, Name, Value: string): string;

    class function ReplaceStr(strSource, strReplaceFrom, strReplaceWith: string; goTrim: Boolean = true): string;

    class function HashHMAC256(AText : String) : String;

    class function EncodeBase64 (AString : String) : String;
    class function DecodeBase64 (AString : String) : String;
    class function Encrypt(const s: String): String;
    class function Decrypt(const s: String): String;

    class function EncodeCrypt(const s : String) : String;
    class function DecodeCrypt(const s : String) : String;

    class function DownloadFile(AURL, ASaveFile : String) : Boolean;

    class function NewUUIDCompact: string;
    class function NewSequentialUUID: string;
    class function NewDatabaseUUID: string;

    class function FileToBase64(const FilePath: string): string;
    class function Base64ToFile(const Base64Str, OutputFilePath: string): Boolean;
  end;

const
  SIGNATUREAPPS = 'blangkonfa2025inventory';
  CTYNTCODE = 7269;

implementation

class function TGlobalFunction.Base64ToFile(const Base64Str,
  OutputFilePath: string): Boolean;
var
  Bytes: TBytes;
  FileStream: TFileStream;
begin
  try
    Bytes := TNetEncoding.Base64.DecodeStringToBytes(Base64Str);
    FileStream := TFileStream.Create(OutputFilePath, fmCreate);
    try
      FileStream.WriteBuffer(Bytes, Length(Bytes));
      Result := True;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
      raise Exception.CreateFmt('Gagal menyimpan file: %s', [E.Message]);
  end;
end;

class procedure TGlobalFunction.CreateBaseDirectory;
begin
  {$IF DEFINED(MSWINDOWS) OR DEFINED(LINUX)}
  if not DirectoryExists(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files') then
    CreateDir(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files');

  if not DirectoryExists(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'image') then
    CreateDir(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'image');

  if not DirectoryExists(ExpandFileName(GetCurrentDir) + PathDelim + 'files' + PathDelim + 'image' + PathDelim + 'original') then
    CreateDir(ExpandFileName(GetCurrentDir) + PathDelim + 'files' + PathDelim + 'image' + PathDelim + 'original');

  if not DirectoryExists(ExpandFileName(GetCurrentDir) + PathDelim + 'files' + PathDelim + 'image' + PathDelim + 'cropped') then
    CreateDir(ExpandFileName(GetCurrentDir) + PathDelim + 'files' + PathDelim + 'image' + PathDelim + 'cropped');

  if not DirectoryExists(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'doc') then
    CreateDir(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'doc');

  if not DirectoryExists(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'video') then
    CreateDir(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'video');

  if not DirectoryExists(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'music') then
    CreateDir(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'music');

  if not DirectoryExists(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'other') then
    CreateDir(ExpandFileName(GetCurrentDir) + System.SysUtils.PathDelim + 'files' + System.SysUtils.PathDelim + 'other');
  {$ENDIF}
end;

class function TGlobalFunction.DecodeBase64(AString: String): String;
begin
  Result := AString;
  try
    Result := TNetEncoding.Base64.Decode(AString);
  except on E: Exception do
    Result := AString;
  end;
end;

class function TGlobalFunction.DecodeCrypt(const s: String): String;
begin
  Result := Decrypt(DecodeBase64(s));
end;

class function TGlobalFunction.Decrypt(const s: String): String;
var
  i: integer;
  s2: string;
begin
  if not (Length(s) = 0) then
    for i := 1 to Length(s) do
      s2 := s2 + Chr(Ord(s[i]) - CTYNTCODE);
  Result := s2;
end;

class function TGlobalFunction.EncodeBase64(AString: String): String;
begin
  Result := TNetEncoding.Base64.Encode(AString);
end;

class function TGlobalFunction.EncodeCrypt(const s: String): String;
begin
  Result := EncodeBase64(Encrypt(s));
end;

class function TGlobalFunction.Encrypt(const s: String): String;
var
  i: integer;
  s2: string;
begin
  if not (Length(s) = 0) then
    for i := 1 to Length(s) do
      s2 := s2 + Chr(Ord(s[i]) + CTYNTCODE);
  Result := s2;
end;

class function TGlobalFunction.FileToBase64(const FilePath: string): string;
var
  Bytes: TBytes;
  FileStream: TFileStream;
begin
  if not FileExists(FilePath) then
    raise Exception.CreateFmt('File tidak ditemukan: %s', [FilePath]);

  FileStream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Bytes, FileStream.Size);
    FileStream.ReadBuffer(Bytes, FileStream.Size);
    Result := TNetEncoding.Base64.EncodeBytesToString(Bytes);
  finally
    FileStream.Free;
  end;
end;

class function TGlobalFunction.DownloadFile(AURL, ASaveFile: String): Boolean;
var
  HTTP : TNetHTTPClient;
  IHTTPResponses : IHTTPResponse;
  Stream : TMemoryStream;
begin
  Result := False;

  HTTP := TNetHTTPClient.Create(nil);
  try
    Stream := TMemoryStream.Create;
    try
      IHTTPResponses := HTTP.Get(AURL, Stream);
      if IHTTPResponses.StatusCode = 200 then begin
        Stream.SaveToFile(LoadFile(ASaveFile));

        Result := True;
      end;
    finally
      FreeAndNil(Stream);
    end;
  finally
    FreeAndNil(HTTP);
  end;
end;

class function TGlobalFunction.GetBaseDirectory: String;
begin
  CreateBaseDirectory;

  {$IF DEFINED(IOS) or DEFINED(ANDROID)}
    Result := TPath.GetDocumentsPath + PathDelim;
  {$ELSEIF DEFINED(MSWINDOWS) OR DEFINED(LINUX)}
    Result := ExpandFileName(GetCurrentDir) + PathDelim;
  {$ENDIF}
end;

class function TGlobalFunction.HashHMAC256(AText: String): String;
begin
  Result := THashSHA2.GetHMAC(AText, SIGNATUREAPPS, SHA256);
end;

class function TGlobalFunction.LoadFile(AFileName: String): String;
var
  FExtension, FPath : String;
begin
  FPath := GetBaseDirectory;
  FExtension := LowerCase(ExtractFileExt(AFileName));

  if (FExtension = '.jpg') or (FExtension = '.jpeg') or (FExtension = '.png') or (FExtension = '.bmp') then
    Result := FPath + 'files' + System.SysUtils.PathDelim + 'image' + System.SysUtils.PathDelim + AFileName

  else if (FExtension = '.doc') or (FExtension = '.pdf') or (FExtension = '.csv') or (FExtension = '.txt') or (FExtension = '.xls') then
    Result := FPath + 'files' + System.SysUtils.PathDelim + 'doc' + System.SysUtils.PathDelim + AFileName

  else if (FExtension = '.mp4') or (FExtension = '.avi') or (FExtension = '.wmv') or (FExtension = '.flv') or (FExtension = '.mov') or (FExtension = '.mkv') or (FExtension = '.3gp') then
    Result := FPath + 'files' + System.SysUtils.PathDelim + 'video' + System.SysUtils.PathDelim + AFileName

  else if (FExtension = '.mp3') or (FExtension = '.wav') or (FExtension = '.wma') or (FExtension = '.aac') or (FExtension = '.flac') or (FExtension = '.m4a') then
    Result := FPath + 'files' + System.SysUtils.PathDelim + 'music' + System.SysUtils.PathDelim + AFileName
  else
    Result := FPath + 'files' + System.SysUtils.PathDelim + 'other' + System.SysUtils.PathDelim + AFileName
end;

class function TGlobalFunction.LoadSettingString(Section, Name,
  Value: string): string;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(LoadFile('config.ini'));
  try
    Result := ini.ReadString(Section, Name, Value);
  finally
    FreeAndNil(ini);
  end;
end;

class function TGlobalFunction.NewSequentialUUID: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := LowerCase(
    IntToHex(DateTimeToUnix(Now), 8) +
    Copy(G.ToString, 2, 28)
  );
end;

class function TGlobalFunction.NewUUIDCompact: string;
begin
  Result := LowerCase(StringReplace(
    Copy(TGUID.NewGuid.ToString, 2, 36),
    '-', '',
    [rfReplaceAll]
  ));
end;

class function TGlobalFunction.NewDatabaseUUID: string;
begin
  Result := LowerCase(Copy(TGUID.NewGuid.ToString, 2, 36));
end;

class function TGlobalFunction.ReplaceStr(strSource, strReplaceFrom,
  strReplaceWith: string; goTrim: Boolean): string;
begin
  if goTrim then strSource := Trim(strSource);
  Result := StringReplace(strSource, StrReplaceFrom, StrReplaceWith, [rfReplaceAll, rfIgnoreCase]);
end;

class procedure TGlobalFunction.SaveSettingString(Section, Name, Value: string);
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(LoadFile('config.ini'));
  try
    ini.WriteString(Section, Name, Value);
  finally
    FreeAndNil(ini);
  end;
end;

end.
