program InfrastructureRegression;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  DB.ConnectionFactory,
  BFA.Core.Endpoint;

const
  THREAD_COUNT = 8;
  LINES_PER_THREAD = 60;
  CONNECTION_FAILURES = 200;

type
  TLogThread = class(TThread)
  private
    FIndex: Integer;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AIndex: Integer);
    property Failure: string read FFailure;
  end;

var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
  Inc(GChecks);
end;

function LogID(AThreadIndex, ALineIndex: Integer): string;
begin
  Result := IntToStr(AThreadIndex) + '-' + IntToStr(ALineIndex);
end;

function ErrorSuffix(const AID: string): string;
begin
  Result := 'fixture-error-' + AID + ': Exception: ' +
    StringOfChar('X', 768) + '-END-' + AID;
end;

function ConsoleLine(const AID: string): string;
begin
  Result := 'fixture-console-' + AID + ': ' + StringOfChar('Y', 768) + '-END-' + AID;
end;

constructor TLogThread.Create(AIndex: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIndex := AIndex;
end;

procedure TLogThread.Execute;
var
  I: Integer;
  LID: string;
  LError: Exception;
begin
  try
    for I := 1 to LINES_PER_THREAD do begin
      LID := LogID(FIndex, I);
      LError := Exception.Create(StringOfChar('X', 768) + '-END-' + LID);
      try
        THelperEndpoint.WriteErrorLog('fixture-error-' + LID, LError);
      finally
        LError.Free;
      end;
      THelperEndpoint.WriteConsoleLog(ConsoleLine(LID));
    end;
  except
    on E: Exception do
      FFailure := E.ClassName + ': ' + E.Message;
  end;
end;

procedure TestConnectionFailureCleanup;
var
  I: Integer;
  LBefore: Integer;
  LFailed: Boolean;
  LConnection: TFDConnection;
begin
  FDManager.ConnectionDefFileAutoLoad := False;
  FDManager.Active := True;
  Check(FDManager.ConnectionDefs.FindConnectionDef('MyDB') = nil,
    'Fixture requires no MyDB definition and never connects to a database');
  LBefore := FDManager.ConnectionCount;
  for I := 1 to CONNECTION_FAILURES do begin
    LFailed := False;
    try
      LConnection := TDBConnectionFactory.GetConnection;
      LConnection.Free;
    except
      on E: Exception do begin
        LFailed := True;
        Check(Pos('MyDB', E.Message) > 0, 'Expected missing MyDB definition');
      end;
    end;
    Check(LFailed, 'GetConnection must fail without a connection definition');
    Check(FDManager.ConnectionCount = LBefore,
      'Failed GetConnection must not retain a TFDConnection');
  end;
end;

procedure ReopenConsole;
begin
  AssignFile(Output, '');
  Rewrite(Output);
end;

procedure VerifyConcurrentLines(const AConsolePath, AErrorPath: string);
var
  LExpected: TDictionary<string, Integer>;
  LPair: TPair<string, Integer>;
  LLines: TArray<string>;
  LLine: string;
  LID: string;
  LKey: string;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  LExpected := TDictionary<string, Integer>.Create;
  try
    for I := 1 to THREAD_COUNT do
      for J := 1 to LINES_PER_THREAD do begin
        LID := LogID(I, J);
        LExpected.Add(ErrorSuffix(LID), 0);
        LExpected.Add(ConsoleLine(LID), 0);
      end;
    LLines := TFile.ReadAllLines(AConsolePath);
    Check(Length(LLines) = THREAD_COUNT * LINES_PER_THREAD * 2,
      'Concurrent console output has exactly one line per logger call');
    for LLine in LLines do begin
      if LLine.StartsWith('fixture-console-') then
        LKey := LLine
      else
        LKey := Copy(LLine, 25, MaxInt);
      Check(LExpected.TryGetValue(LKey, LCount),
        'Concurrent console line is complete and belongs to one request');
      LExpected[LKey] := LCount + 1;
    end;
    for LPair in LExpected do
      Check(LPair.Value = 1, 'Every console marker occurs once');

    LLines := TFile.ReadAllLines(AErrorPath, TEncoding.UTF8);
    Check(Length(LLines) = THREAD_COUNT * LINES_PER_THREAD,
      'Concurrent file output has exactly one line per error');
    for LLine in LLines do begin
      LKey := Copy(LLine, 25, MaxInt);
      Check(LExpected.TryGetValue(LKey, LCount),
        'Concurrent error-file line is complete and belongs to one request');
      Check(LKey.StartsWith('fixture-error-'), 'File receives errors only');
      LExpected[LKey] := LCount + 1;
    end;
    for LPair in LExpected do
      if LPair.Key.StartsWith('fixture-error-') then
        Check(LPair.Value = 2, 'Every error marker occurs once in console and file')
      else
        Check(LPair.Value = 1, 'Console-only marker was not added to the file');
  finally
    LExpected.Free;
  end;
end;

procedure TestLogger(const AScratchPath: string);
var
  LThreads: array[1..THREAD_COUNT] of TLogThread;
  LErrorPath: string;
  LConsolePath: string;
  LSavedErrorPath: string;
  LError: Exception;
  LLines: TArray<string>;
  I: Integer;
begin
  LErrorPath := TPath.Combine(AScratchPath, 'server-error.log');
  LConsolePath := TPath.Combine(AScratchPath, 'fixture-console.log');
  LSavedErrorPath := TPath.Combine(AScratchPath, 'fixture-errors-complete.log');
  Check(not TFile.Exists(LErrorPath) and not TDirectory.Exists(LErrorPath),
    'Refusing to modify an existing server-error.log sink');
  Check(not TFile.Exists(LConsolePath) and not TFile.Exists(LSavedErrorPath),
    'Fixture must run in a fresh scratch output directory');
  FillChar(LThreads, SizeOf(LThreads), 0);
  AssignFile(Output, LConsolePath);
  Rewrite(Output);
  try
    for I := 1 to THREAD_COUNT do
      LThreads[I] := TLogThread.Create(I);
    for I := 1 to THREAD_COUNT do
      LThreads[I].Start;
    for I := 1 to THREAD_COUNT do
      LThreads[I].WaitFor;
    for I := 1 to THREAD_COUNT do
      Check(LThreads[I].Failure = '', 'Logging thread completed without exception');
  finally
    for I := 1 to THREAD_COUNT do
      LThreads[I].Free;
    CloseFile(Output);
    ReopenConsole;
  end;
  VerifyConcurrentLines(LConsolePath, LErrorPath);
  TFile.Move(LErrorPath, LSavedErrorPath);

  // A directory at the file sink forces AppendAllText to fail.
  TDirectory.CreateDirectory(LErrorPath);
  LError := Exception.Create('file-sink-failure');
  try
    AssignFile(Output, TPath.Combine(AScratchPath, 'fixture-file-failure-console.log'));
    Rewrite(Output);
    try
      THelperEndpoint.WriteErrorLog('fixture-file-failure', LError);
    finally
      CloseFile(Output);
      ReopenConsole;
    end;
    LLines := TFile.ReadAllLines(
      TPath.Combine(AScratchPath, 'fixture-file-failure-console.log'));
    Check(Length(LLines) = 1, 'File failure leaves console logging available');
    Check(Pos('fixture-file-failure: Exception: file-sink-failure', LLines[0]) > 0,
      'File failure preserves the original error message');
  finally
    LError.Free;
    TDirectory.Delete(LErrorPath);
  end;

  // A closed Output raises EInOutError; the independent file sink must still run.
  LError := Exception.Create('console-sink-failure');
  try
    CloseFile(Output);
    try
      THelperEndpoint.WriteConsoleLog('fixture-closed-console');
      THelperEndpoint.WriteErrorLog('fixture-console-failure', LError);
    finally
      ReopenConsole;
    end;
    LLines := TFile.ReadAllLines(LErrorPath, TEncoding.UTF8);
    Check(Length(LLines) = 1, 'Console failure leaves file logging available');
    Check(Pos('fixture-console-failure: Exception: console-sink-failure', LLines[0]) > 0,
      'Console failure preserves the original error message');
  finally
    LError.Free;
  end;
end;

begin
  try
    Check(ParamStr(1) = '--isolated-fixture',
      'Run only a scratch-compiled executable with --isolated-fixture');
    TestConnectionFailureCleanup;
    TestLogger(ExtractFilePath(ExpandFileName(ParamStr(0))));
    Writeln('PASS: ', GChecks, ' infrastructure checks; ', CONNECTION_FAILURES,
      ' connection failures without retained connections; ',
      THREAD_COUNT * LINES_PER_THREAD * 2,
      ' complete concurrent console lines; file/console sink failures isolated.');
  except
    on E: Exception do begin
      Writeln('FAIL: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
