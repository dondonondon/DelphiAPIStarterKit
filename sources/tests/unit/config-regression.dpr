program ConfigRegression;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Hash,
  System.SyncObjs,
  BFA.Core.Config,
  BFA.Helper.Strings
  {$IF DEFINED(MSWINDOWS)}
  , Winapi.Windows
  {$ELSEIF DEFINED(LINUX)}
  , Posix.Stdlib
  {$ENDIF}
  ;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure SetTestEnvironment(const AName, AValue: string);
begin
  {$IF DEFINED(MSWINDOWS)}
  Require(Winapi.Windows.SetEnvironmentVariable(PChar(AName), PChar(AValue)),
    'Unable to update fixture environment');
  {$ELSEIF DEFINED(LINUX)}
  Require(Posix.Stdlib.setenv(PAnsiChar(UTF8String(AName)),
    PAnsiChar(UTF8String(AValue)), 1) = 0,
    'Unable to update fixture environment');
  {$ELSE}
  raise Exception.Create('Environment mutation fixture is unsupported on this target');
  {$ENDIF}
end;

procedure VerifyReady;
var
  LExpectedPath: string;
  LExpectedSecret: string;
  LExpectedHash: string;
begin
  TServerConfig.Initialize;
  TGlobalFunction.InitializeSecurity;
  LExpectedPath := GetEnvironmentVariable('CONFIG_TEST_EXPECTED_PATH');
  if LExpectedPath <> '' then
    Require(TServerConfig.ConfigFileName = LExpectedPath,
      'Unexpected selected config path')
  else
    Require(not FileExists(TServerConfig.ConfigFileName),
      'Environment-only fixture unexpectedly selected an existing config');

  Require(TServerConfig.HasExplicitConfig =
    (GetEnvironmentVariable('CONFIG_TEST_EXPECTED_EXPLICIT') = '1'),
    'Unexpected explicit-config flag');
  Require(TServerConfig.ReadString('Probe', 'Value', 'missing') =
    GetEnvironmentVariable('CONFIG_TEST_EXPECTED_VALUE'),
    'Config content did not match selected fixture');

  LExpectedSecret := GetEnvironmentVariable('CONFIG_TEST_EXPECTED_SECRET');
  Require(LExpectedSecret <> '', 'Expected fixture secret is required');
  LExpectedHash := THashSHA2.GetHMAC('fixture-payload', LExpectedSecret, SHA256);
  Require(TGlobalFunction.HashHMAC256('fixture-payload') = LExpectedHash,
    'HMAC did not use the expected configuration source');
end;

procedure VerifyRejected;
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    TServerConfig.Initialize;
    TGlobalFunction.InitializeSecurity;
  except
    on E: Exception do
      LRejected := True;
  end;
  Require(LRejected, 'Invalid configuration was accepted');
end;

procedure VerifyImmutableConcurrentHashing;
const
  THREAD_COUNT = 8;
  HASHES_PER_THREAD = 2000;
var
  LExpectedHash: string;
  LConfigPath: string;
  LFixtureRoot: string;
  LThreads: array[0..THREAD_COUNT - 1] of TThread;
  LThreadIndex: Integer;
  LFailureCount: Integer;
begin
  VerifyReady;
  LExpectedHash := TGlobalFunction.HashHMAC256('fixture-payload');
  LConfigPath := ExpandFileName(TServerConfig.ConfigFileName);
  LFixtureRoot := IncludeTrailingPathDelimiter(
    ExpandFileName(GetEnvironmentVariable('CONFIG_TEST_ROOT')));
  Require(GetEnvironmentVariable('CONFIG_TEST_ROOT') <> '',
    'Fixture root is required before changing a fixture file');
  Require(LConfigPath.StartsWith(LFixtureRoot),
    'Refusing to change a file outside the fixture root');

  TFile.WriteAllText(LConfigPath,
    '[Security]' + sLineBreak + 'HMACSecret=changed-fixture-file-secret' +
    sLineBreak, TEncoding.UTF8);
  SetTestEnvironment('DELPHI_API_HMAC_SECRET', 'changed-fixture-env-secret');
  SetTestEnvironment('DELPHI_API_CONFIG',
    TPath.Combine(LFixtureRoot, 'missing-after-initialization.ini'));
  TServerConfig.Initialize;
  TGlobalFunction.InitializeSecurity;
  Require(TServerConfig.ConfigFileName = LConfigPath,
    'Config path changed after initialization');

  LFailureCount := 0;
  for LThreadIndex := Low(LThreads) to High(LThreads) do begin
    LThreads[LThreadIndex] := TThread.CreateAnonymousThread(
      procedure
      var
        LHashIndex: Integer;
      begin
        try
          for LHashIndex := 1 to HASHES_PER_THREAD do
            if TGlobalFunction.HashHMAC256('fixture-payload') <> LExpectedHash then
              TInterlocked.Increment(LFailureCount);
        except
          on E: Exception do
            TInterlocked.Increment(LFailureCount);
        end;
      end);
    LThreads[LThreadIndex].FreeOnTerminate := False;
  end;
  try
    for LThreadIndex := Low(LThreads) to High(LThreads) do
      LThreads[LThreadIndex].Start;
    for LThreadIndex := Low(LThreads) to High(LThreads) do
      LThreads[LThreadIndex].WaitFor;
  finally
    for LThreadIndex := Low(LThreads) to High(LThreads) do
      LThreads[LThreadIndex].Free;
  end;
  Require(LFailureCount = 0,
    'Cached HMAC changed or concurrent hashing failed');
end;

begin
  try
    if ParamStr(1) = 'reject' then
      VerifyRejected
    else if ParamStr(1) = 'cache' then
      VerifyImmutableConcurrentHashing
    else if ParamStr(1) = 'ready' then
      VerifyReady
    else
      raise Exception.Create('Expected ready, reject, or cache fixture mode');
    Writeln('PASS');
  except
    on E: Exception do begin
      Writeln('FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
