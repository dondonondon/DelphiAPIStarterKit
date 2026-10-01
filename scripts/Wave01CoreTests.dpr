program Wave01CoreTests;
{$APPTYPE CONSOLE}

uses System.SysUtils, System.Diagnostics, System.JSON, Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.MySQL, FireDAC.Stan.Intf, FireDAC.ConsoleUI.Wait,
  BFA.Core.Config in 'sources\core\BFA.Core.Config.pas',
  DB.ConnectionFactory in 'sources\infrastructure\database\DB.ConnectionFactory.pas',
  BFA.Security.Crypto in 'sources\infrastructure\security\BFA.Security.Crypto.pas',
  BFA.Helper.Strings in 'sources\shared\helpers\BFA.Helper.Strings.pas';

function LiveBytes: NativeUInt;
var LState: TMemoryManagerState; LBlock: TSmallBlockTypeState;
begin
  GetMemoryManagerState(LState);
  Result := LState.TotalAllocatedMediumBlockSize + LState.TotalAllocatedLargeBlockSize;
  for LBlock in LState.SmallBlockTypeStates do Inc(Result, LBlock.AllocatedBlockCount * LBlock.UseableBlockSize);
end;

procedure FailureBatch(ACount: Integer);
var I: Integer; LConnection: TFDConnection;
begin
  for I := 1 to ACount do begin
    LConnection := nil;
    try
      try
        LConnection := TDBConnectionFactory.GetConnection;
        raise Exception.Create('Expected acquisition failure.');
      except
        on E: Exception do
          if Assigned(LConnection) then raise;
      end;
    finally
      FreeAndNil(LConnection);
    end;
  end;
end;

procedure FailureMemory(const ACase: string);
var LBefore, LAfter: NativeUInt;
begin
  FailureBatch(20);
  LBefore := LiveBytes;
  FailureBatch(300);
  LAfter := LiveBytes;
  if LAfter > LBefore + 65536 then raise Exception.Create('Live allocation increased.');
  Writeln('PASS ', ACase, ' 300 acquisition failures; allocated delta=', Int64(LAfter)-Int64(LBefore));
end;

var LDriver: TFDPhysMySQLDriverLink; LConnection: TFDConnection; LDatabase, LHash, LOther: string;
  LClock: TStopwatch; I: Integer;
begin
  try
    try
      TSecurityCrypto.Initialize;
    except
      on E: Exception do begin
        for LOther in ['pinned absolute','integrity check','could not be loaded','entry points','known-answer','random provider','Password provider'] do
          if E.Message.Contains(LOther) then Writeln('FAIL provider stage: ', LOther);
        raise;
      end;
    end;
    LHash := TSecurityCrypto.HashPassword('Unicode whitespace 😀  ');
    LOther := TSecurityCrypto.HashPassword('Unicode whitespace 😀  ');
    if (LHash = LOther) or not TSecurityCrypto.VerifyPassword('Unicode whitespace 😀  ', LHash) or
      TSecurityCrypto.VerifyPassword('wrong', LHash) then raise Exception.Create('Argon2 regression.');
    Writeln('PASS actual Argon2 provider vector / salts / Unicode / wrong password');
    LClock := TStopwatch.StartNew;
    for I := 1 to 20 do TSecurityCrypto.VerifyPassword('Unicode whitespace 😀  ', LHash);
    Writeln('PASS Argon2 verification benchmark mean milliseconds=', LClock.ElapsedMilliseconds / 20:0:2);
    LDriver := TFDPhysMySQLDriverLink.Create(nil);
    try
      LDriver.VendorLib := TServerConfig.ReadValue('Database','VendorLib','DELPHI_API_DB_VENDOR_LIB','');
      SetEnvironmentVariable('DELPHI_API_DB_POOL_MAXIMUM_ITEMS', '1');
      TDBConnectionFactory.Initialize;
      LDatabase := FDManager.ConnectionDefs.ConnectionDefByName('MyDB').Params.Values['Database'];
      FDManager.ConnectionDefs.ConnectionDefByName('MyDB').Params.Values['Database'] := 'wave01_unavailable_schema';
      FailureMemory('Unavailable schema');
      FDManager.CloseConnectionDef('MyDB');
      FDManager.ConnectionDefs.ConnectionDefByName('MyDB').Params.Values['Database'] := LDatabase;
      LConnection := TDBConnectionFactory.GetConnection;
      try
        Writeln('PASS DB recovery / actual native library');
        FailureMemory('Pool exhausted');
      finally
        FreeAndNil(LConnection);
      end;
      LConnection := TDBConnectionFactory.GetConnection;
      FreeAndNil(LConnection);
      Writeln('PASS pool recovery');
    finally
      FDManager.Close;
      FreeAndNil(LDriver);
    end;
  except
    on E: Exception do begin
      Writeln('FAIL ', E.ClassName);
      ExitCode := 1;
    end;
  end;
end.

