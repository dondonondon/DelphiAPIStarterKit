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
  private
    {$IF DEFINED(LINUX)}
    class function GetApplicationName: string;
    {$ENDIF}
    class function GetStorageBaseDirectory: string;
    class procedure EnsureDirectory(const APath: string);
    class function BuildStoragePath(const ASubDirectory, AFileName: string): string;
  public
    class procedure CreateBaseDirectory;
    class function GetBaseDirectory : String;
    class function LoadFile(AFileName : String) : String;

    class procedure SaveSettingString(Section, Name, Value: string);
    class function LoadSettingString(Section, Name, Value: string): string;
    class procedure SaveSettingStringDir(Section, Name, Value: string);
    class function LoadSettingStringDir(Section, Name, Value: string): string;

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

class function TGlobalFunction.BuildStoragePath(const ASubDirectory,
  AFileName: string): string;
begin
  Result := TPath.Combine(
    TPath.Combine(GetBaseDirectory, 'files'),
    TPath.Combine(ASubDirectory, AFileName)
  );
end;

class procedure TGlobalFunction.CreateBaseDirectory;
var
  BaseDir: string;
begin
  BaseDir := GetStorageBaseDirectory;

  EnsureDirectory(BaseDir);
  EnsureDirectory(TPath.Combine(BaseDir, 'files'));
  EnsureDirectory(TPath.Combine(TPath.Combine(BaseDir, 'files'), 'image'));
  EnsureDirectory(TPath.Combine(TPath.Combine(TPath.Combine(BaseDir, 'files'), 'image'), 'original'));
  EnsureDirectory(TPath.Combine(TPath.Combine(TPath.Combine(BaseDir, 'files'), 'image'), 'cropped'));
  EnsureDirectory(TPath.Combine(TPath.Combine(BaseDir, 'files'), 'doc'));
  EnsureDirectory(TPath.Combine(TPath.Combine(BaseDir, 'files'), 'video'));
  EnsureDirectory(TPath.Combine(TPath.Combine(BaseDir, 'files'), 'music'));
  EnsureDirectory(TPath.Combine(TPath.Combine(BaseDir, 'files'), 'other'));
  EnsureDirectory(TPath.Combine(TPath.Combine(BaseDir, 'files'), 'log'));
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

class procedure TGlobalFunction.EnsureDirectory(const APath: string);
begin
  if not DirectoryExists(APath) then
    ForceDirectories(APath);
end;

class function TGlobalFunction.GetBaseDirectory: String;
begin
  CreateBaseDirectory;
  Result := IncludeTrailingPathDelimiter(GetStorageBaseDirectory);
end;

{$IF DEFINED(LINUX)}
class function TGlobalFunction.GetApplicationName: string;
begin
  Result := ChangeFileExt(ExtractFileName(ParamStr(0)), '');

  if Result = '' then
    Result := 'application';
end;
{$ENDIF}

class function TGlobalFunction.GetStorageBaseDirectory: string;
begin
  {$IF DEFINED(IOS) or DEFINED(ANDROID)}
  Result := TPath.GetDocumentsPath;
  {$ELSEIF DEFINED(MSWINDOWS)}
  Result := ExpandFileName(GetCurrentDir);
  {$ELSEIF DEFINED(LINUX)}
  Result := TPath.Combine('/var/lib', GetApplicationName);
  {$ELSE}
  Result := ExpandFileName(GetCurrentDir);
  {$ENDIF}
end;

class function TGlobalFunction.HashHMAC256(AText: String): String;
begin
  Result := THashSHA2.GetHMAC(AText, SIGNATUREAPPS, SHA256);
end;

class function TGlobalFunction.LoadFile(AFileName: String): String;
var
  FExtension: String;
begin
  FExtension := LowerCase(ExtractFileExt(AFileName));

  if (FExtension = '.jpg') or (FExtension = '.jpeg') or (FExtension = '.png') or (FExtension = '.bmp') then
    Result := BuildStoragePath('image', AFileName)

  else if (FExtension = '.doc') or (FExtension = '.pdf') or (FExtension = '.csv') or (FExtension = '.txt') or (FExtension = '.xls') then
    Result := BuildStoragePath('doc', AFileName)

  else if (FExtension = '.mp4') or (FExtension = '.avi') or (FExtension = '.wmv') or (FExtension = '.flv') or (FExtension = '.mov') or (FExtension = '.mkv') or (FExtension = '.3gp') then
    Result := BuildStoragePath('video', AFileName)

  else if (FExtension = '.log') then
    Result := BuildStoragePath('log', AFileName)

  else if (FExtension = '.mp3') or (FExtension = '.wav') or (FExtension = '.wma') or (FExtension = '.aac') or (FExtension = '.flac') or (FExtension = '.m4a') then
    Result := BuildStoragePath('music', AFileName)
  else
    Result := BuildStoragePath('other', AFileName);
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

class function TGlobalFunction.LoadSettingStringDir(Section, Name,
  Value: string): string;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(TPath.Combine(GetBaseDirectory, 'config.ini'));
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

class procedure TGlobalFunction.SaveSettingStringDir(Section, Name,
  Value: string);
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(TPath.Combine(GetBaseDirectory, 'config.ini'));
  try
    ini.WriteString(Section, Name, Value);
  finally
    FreeAndNil(ini);
  end;
end;

end.
