unit BFA.Security.Crypto;

interface

uses System.SysUtils;

type
  TSecurityCrypto = class
  public
    class var DummyPasswordHash: string;
    class procedure Initialize; static;
    class function RandomBytes(ACount: Integer): TBytes; static;
    class function NewCredential: string; static;
    class function TokenHash(const AToken: string): string; static;
    class function HashPassword(const APassword: string): string; static;
    class function VerifyPassword(const APassword, AHash: string): Boolean; static;
    class function NeedsRehash(const AHash: string): Boolean; static;
  end;

implementation

uses BFA.Helper.Clock, System.Classes, System.IOUtils, System.NetEncoding, System.Hash, System.RegularExpressions,
  System.DateUtils, BFA.Core.Config, BFA.Helper.Strings
  {$IFDEF MSWINDOWS}, Winapi.Windows{$ELSE}, Posix.Dlfcn{$ENDIF};

type
  TArgonHash = function(ATime, AMemory, AParallelism: Cardinal; APassword: Pointer; APasswordLength: NativeUInt;
    ASalt: Pointer; ASaltLength, AHashLength: NativeUInt; AEncoded: PAnsiChar; AEncodedLength: NativeUInt): Integer; cdecl;
  TArgonVerify = function(AEncoded: PAnsiChar; APassword: Pointer; APasswordLength: NativeUInt): Integer; cdecl;

var
  ArgonHash: TArgonHash;
  ArgonVerify: TArgonVerify;
  ProviderHandle: THandle;

{$IFDEF MSWINDOWS}
const
  SECURE_DLL_DIRECTORY_SEARCH = $00000100;
  SECURE_SYSTEM32_SEARCH = $00000800;

function BCryptGenRandom(AAlgorithm: Pointer; ABuffer: PByte; ACount, AFlags: Cardinal): LongInt; stdcall;
  external 'bcrypt.dll';
{$ENDIF}

class function TSecurityCrypto.RandomBytes(ACount: Integer): TBytes;
{$IFNDEF MSWINDOWS}
var LStream: TFileStream;
{$ENDIF}
begin
  if (ACount < 16) or (ACount > 1024) then raise Exception.Create('Invalid random byte count.');
  SetLength(Result, ACount);
  {$IFDEF MSWINDOWS}
  if BCryptGenRandom(nil, @Result[0], ACount, 2) <> 0 then
    raise Exception.Create('Secure random provider failed.');
  {$ELSE}
  LStream := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyNone);
  try
    LStream.ReadBuffer(Result[0], ACount);
  finally
    FreeAndNil(LStream);
  end;
  {$ENDIF}
end;

function HashBytes(const ABytes: TBytes): string;
var LHash: THashSHA2;
begin
  LHash := THashSHA2.Create;
  LHash.Update(ABytes);
  Result := LowerCase(LHash.HashAsString);
end;

function EncodeCredential(const ABytes: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(ABytes).Replace('+', '-').Replace('/', '_').Replace('=', '')
    .Replace(#13, '').Replace(#10, '');
end;

class function TSecurityCrypto.NewCredential: string;
begin
  Result := EncodeCredential(RandomBytes(32));
end;

class function TSecurityCrypto.TokenHash(const AToken: string): string;
var LBytes: TBytes;
begin
  Result := '';
  if not TRegEx.IsMatch(AToken, '^[A-Za-z0-9_-]{43}$') then Exit;
  LBytes := TNetEncoding.Base64.DecodeStringToBytes(AToken.Replace('-', '+').Replace('_', '/') + '=');
  if (Length(LBytes) <> 32) or (EncodeCredential(LBytes) <> AToken) then Exit;
  Result := HashBytes(LBytes);
end;

class procedure TSecurityCrypto.Initialize;
var LPath, LExpected: string; LBytes: TBytes; LPassword, LEncoded: UTF8String;
begin
  if Assigned(ArgonHash) and (DummyPasswordHash <> '') then Exit;
  LPath := TServerConfig.ReadValue('Security', 'Argon2Library', 'DELPHI_API_ARGON2_LIBRARY', '');
  LExpected := TServerConfig.ReadValue('Security', 'Argon2SHA256', 'DELPHI_API_ARGON2_SHA256', '');
  if not TPath.IsPathRooted(LPath) or not FileExists(LPath) or
    not TRegEx.IsMatch(LExpected, '^[a-f0-9]{64}$') then
    raise Exception.Create('A pinned absolute Argon2 provider is required.');
  LBytes := TFile.ReadAllBytes(LPath);
  if HashBytes(LBytes) <> LExpected then
    raise Exception.Create('Argon2 provider integrity check failed.');
  try
  {$IFDEF MSWINDOWS}
  ProviderHandle := LoadLibraryEx(PChar(LPath), 0, SECURE_DLL_DIRECTORY_SEARCH or SECURE_SYSTEM32_SEARCH);
  if ProviderHandle = 0 then raise Exception.Create('Argon2 provider could not be loaded.');
  ArgonHash := TArgonHash(GetProcAddress(ProviderHandle, 'argon2id_hash_encoded'));
  ArgonVerify := TArgonVerify(GetProcAddress(ProviderHandle, 'argon2id_verify'));
  {$ELSE}
  ProviderHandle := dlopen(MarshaledAString(UTF8String(LPath)), RTLD_NOW or RTLD_LOCAL);
  if ProviderHandle = 0 then raise Exception.Create('Argon2 provider could not be loaded.');
  ArgonHash := TArgonHash(dlsym(ProviderHandle, 'argon2id_hash_encoded'));
  ArgonVerify := TArgonVerify(dlsym(ProviderHandle, 'argon2id_verify'));
  {$ENDIF}
  if not Assigned(ArgonHash) or not Assigned(ArgonVerify) then
    raise Exception.Create('Argon2 provider entry points unavailable.');
  LPassword := 'password';
  LEncoded := '$argon2id$v=19$m=65536,t=2,p=1$c29tZXNhbHQ$'
    + 'CTFhFdXPJO1aFaMaO6Mm5c8y7cJHAph8ArZWb2GRPPc';
  if ArgonVerify(PAnsiChar(LEncoded), PAnsiChar(LPassword), Length(LPassword)) <> 0 then
    raise Exception.Create('Argon2 provider known-answer check failed.');
  RandomBytes(32);
  DummyPasswordHash := HashPassword(NewCredential);
  except
    ArgonHash := nil;
    ArgonVerify := nil;
    DummyPasswordHash := '';
    {$IFDEF MSWINDOWS}
    if ProviderHandle <> 0 then FreeLibrary(ProviderHandle);
    ProviderHandle := 0;
    {$ELSE}
    if ProviderHandle <> 0 then dlclose(ProviderHandle);
    ProviderHandle := 0;
    {$ENDIF}
    raise;
  end;
end;

class function TSecurityCrypto.HashPassword(const APassword: string): string;
var LBytes, LSalt: TBytes; LBuffer: array[0..255] of AnsiChar;
begin
  if not Assigned(ArgonHash) then raise Exception.Create('Argon2 provider not initialized.');
  LBytes := TEncoding.UTF8.GetBytes(APassword);
  LSalt := RandomBytes(16);
  if Length(LBytes) = 0 then raise Exception.Create('Password is empty.');
  try
    if ArgonHash(2, 19456, 1, @LBytes[0], Length(LBytes), @LSalt[0], Length(LSalt), 32, @LBuffer[0], 256) <> 0 then
      raise Exception.Create('Password provider failed.');
    Result := string(AnsiString(PAnsiChar(@LBuffer[0])));
  finally
    FillChar(LBytes[0], Length(LBytes), 0);
  end;
end;

class function TSecurityCrypto.NeedsRehash(const AHash: string): Boolean;
begin
  Result := not AHash.StartsWith('$argon2id$v=19$m=19456,t=2,p=1$');
end;

class function TSecurityCrypto.VerifyPassword(const APassword, AHash: string): Boolean;
var LBytes: TBytes; LHash, LStored: UTF8String; LDeadline: Int64; LLegacy, LDiff: Integer; I: Integer;
begin
  Result := False;
  if not Assigned(ArgonVerify) then raise Exception.Create('Argon2 provider not initialized.');
  if AHash.StartsWith('$argon2id$') then begin
    if not TRegEx.IsMatch(AHash,
      '^\$argon2id\$v=19\$m=(19456|32768|65536),t=[2-5],p=[1-4]\$[A-Za-z0-9+/]{22}\$[A-Za-z0-9+/]{43}$') then Exit;
    LBytes := TEncoding.UTF8.GetBytes(APassword);
    if Length(LBytes) = 0 then Exit;
    LHash := UTF8String(AHash);
    LLegacy := ArgonVerify(PAnsiChar(LHash), @LBytes[0], Length(LBytes));
    FillChar(LBytes[0], Length(LBytes), 0);
    if (LLegacy <> 0) and (LLegacy <> -35) then raise Exception.Create('Password verification provider failed.');
    Exit(LLegacy = 0);
  end;
  if not TRegEx.IsMatch(AHash, '^[a-fA-F0-9]{64}$') then Exit;
  if not TryStrToInt64(TServerConfig.ReadValue('Security', 'LegacyHashDeadline', 'DELPHI_API_LEGACY_HASH_DEADLINE', '0'),
    LDeadline) or (THelperClock.UnixNow >= LDeadline) then Exit;
  LHash := UTF8String(TGlobalFunction.HashHMAC256(APassword));
  LStored := UTF8String(LowerCase(AHash));
  LDiff := Length(LHash) xor Length(LStored);
  for I := 1 to Length(LStored) do LDiff := LDiff or (Ord(LHash[I]) xor Ord(LStored[I]));
  Result := LDiff = 0;
end;

initialization
finalization
  {$IFDEF MSWINDOWS}
  if ProviderHandle <> 0 then FreeLibrary(ProviderHandle);
  {$ELSE}
  if ProviderHandle <> 0 then dlclose(ProviderHandle);
  {$ENDIF}
end.
