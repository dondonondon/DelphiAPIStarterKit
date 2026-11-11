param(
    [string]$DelphiRoot = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('delphi-config-regression-' + [Guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $fixtureRoot 'build'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$compiler = Join-Path $DelphiRoot 'bin\dcc64.exe'
$libPath = Join-Path $DelphiRoot 'lib\win64\release'
$unitPath = @(
    $libPath,
    (Join-Path $projectRoot 'sources\core'),
    (Join-Path $projectRoot 'sources\shared\helpers')
) -join ';'

& $compiler '-B' '-Q' ('-U' + $unitPath) ('-I' + $libPath) ('-E' + $buildRoot) ('-N0' + $buildRoot) (Join-Path $PSScriptRoot 'unit\config-regression.dpr')
if ($LASTEXITCODE -ne 0) { throw 'Config fixture build failed.' }
$compiledExe = Join-Path $buildRoot 'config-regression.exe'
if (-not (Test-Path -LiteralPath $compiledExe)) { throw 'Config fixture executable is missing.' }

function Write-FixtureConfig([string]$Path, [string]$Value, [string]$Secret) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, "[Probe]`r`nValue=$Value`r`n[Security]`r`nHMACSecret=$Secret`r`n", [Text.UTF8Encoding]::new($false))
}

function Invoke-ConfigCase {
    param(
        [string]$Name,
        [string]$Mode = 'ready',
        [bool]$Adjacent = $false,
        [bool]$CurrentDirectory = $false,
        [string]$Explicit = '',
        [string]$EnvironmentSecret = '',
        [string]$ExpectedSource = '',
        [string]$ExpectedSecret = '',
        [string]$ExplicitSecret = 'explicit-fixture-secret',
        [string]$ExplicitValue = 'explicit',
        [string]$ExpectedValue = ''
    )

    $caseRoot = Join-Path $fixtureRoot $Name
    $exeRoot = Join-Path $caseRoot 'app'
    $cwdRoot = Join-Path $caseRoot 'working-directory'
    [IO.Directory]::CreateDirectory($exeRoot) | Out-Null
    [IO.Directory]::CreateDirectory($cwdRoot) | Out-Null
    $caseExe = Join-Path $exeRoot 'config-regression.exe'
    Copy-Item -LiteralPath $compiledExe -Destination $caseExe
    $adjacentPath = Join-Path $exeRoot 'config.ini'
    $cwdPath = Join-Path $cwdRoot 'config.ini'
    $explicitPath = Join-Path $caseRoot 'selected\custom.ini'
    if ($Adjacent) { Write-FixtureConfig $adjacentPath 'adjacent' 'adjacent-fixture-secret' }
    if ($CurrentDirectory) { Write-FixtureConfig $cwdPath 'cwd' 'cwd-fixture-secret' }
    if ($Explicit -eq 'valid') { Write-FixtureConfig $explicitPath $ExplicitValue $ExplicitSecret }
    if ($Explicit -eq 'relative') { Write-FixtureConfig (Join-Path $cwdRoot 'relative.ini') 'relative' 'relative-fixture-secret' }

    $configVariable = switch ($Explicit) {
        'valid' { $explicitPath }
        'missing' { Join-Path $caseRoot 'missing.ini' }
        'relative' { 'relative.ini' }
        'drive-relative' { ([IO.Path]::GetPathRoot($caseRoot)).Substring(0, 2) + 'relative.ini' }
        'root-relative' { '\relative.ini' }
        default { '' }
    }
    $expectedPath = switch ($ExpectedSource) {
        'adjacent' { $adjacentPath }
        'cwd' { $cwdPath }
        'explicit' { $explicitPath }
        default { '' }
    }
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $caseExe
    $startInfo.Arguments = $Mode
    $startInfo.WorkingDirectory = $cwdRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($key in @('DELPHI_API_CONFIG', 'DELPHI_API_HMAC_SECRET')) {
        $startInfo.EnvironmentVariables.Remove($key)
    }
    if ($configVariable) { $startInfo.EnvironmentVariables['DELPHI_API_CONFIG'] = $configVariable }
    if ($EnvironmentSecret) { $startInfo.EnvironmentVariables['DELPHI_API_HMAC_SECRET'] = $EnvironmentSecret }
    $startInfo.EnvironmentVariables['CONFIG_TEST_ROOT'] = $fixtureRoot
    $startInfo.EnvironmentVariables['CONFIG_TEST_EXPECTED_PATH'] = $expectedPath
    $startInfo.EnvironmentVariables['CONFIG_TEST_EXPECTED_VALUE'] = $(if ($ExpectedValue) { $ExpectedValue } elseif ($ExpectedSource) { $ExpectedSource } else { 'missing' })
    $startInfo.EnvironmentVariables['CONFIG_TEST_EXPECTED_EXPLICIT'] = $(if ($Explicit -eq 'valid') { '1' } else { '0' })
    $startInfo.EnvironmentVariables['CONFIG_TEST_EXPECTED_SECRET'] = $ExpectedSecret
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "Unable to start fixture $Name." }
        $output = $process.StandardOutput.ReadToEnd().Trim()
        $errorOutput = $process.StandardError.ReadToEnd().Trim()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0 -or $output -ne 'PASS' -or $errorOutput) {
            throw "Fixture $Name failed (exit $($process.ExitCode)): $output $errorOutput"
        }
        Write-Output "PASS $Name"
    }
    finally { $process.Dispose() }
}

Invoke-ConfigCase -Name 'env-only' -EnvironmentSecret 'env-fixture-secret' -ExpectedSecret 'env-fixture-secret'
Invoke-ConfigCase -Name 'explicit-other-cwd' -Explicit 'valid' -Adjacent $true -CurrentDirectory $true -ExpectedSource 'explicit' -ExpectedSecret 'explicit-fixture-secret'
Invoke-ConfigCase -Name 'env-secret-precedence' -Explicit 'valid' -EnvironmentSecret 'env-fixture-secret' -ExpectedSource 'explicit' -ExpectedSecret 'env-fixture-secret'
Invoke-ConfigCase -Name 'missing-explicit-rejected' -Mode 'reject' -Explicit 'missing' -EnvironmentSecret 'env-fixture-secret'
Invoke-ConfigCase -Name 'relative-explicit-rejected' -Mode 'reject' -Explicit 'relative' -EnvironmentSecret 'env-fixture-secret'
Invoke-ConfigCase -Name 'drive-relative-explicit-rejected' -Mode 'reject' -Explicit 'drive-relative' -EnvironmentSecret 'env-fixture-secret'
Invoke-ConfigCase -Name 'root-relative-explicit-rejected' -Mode 'reject' -Explicit 'root-relative' -EnvironmentSecret 'env-fixture-secret'
Invoke-ConfigCase -Name 'adjacent-preferred' -Adjacent $true -CurrentDirectory $true -ExpectedSource 'adjacent' -ExpectedSecret 'adjacent-fixture-secret'
Invoke-ConfigCase -Name 'cwd-fallback' -CurrentDirectory $true -ExpectedSource 'cwd' -ExpectedSecret 'cwd-fixture-secret'
Invoke-ConfigCase -Name 'blank-explicit-secret-rejected' -Mode 'reject' -Explicit 'valid' -ExplicitSecret ''
Invoke-ConfigCase -Name 'quoted-secret-compatibility' -Explicit 'valid' -ExplicitSecret '"quoted-fixture-secret"' -ExpectedSource 'explicit' -ExpectedSecret 'quoted-fixture-secret'
Invoke-ConfigCase -Name 'quoted-value-compatibility' -Explicit 'valid' -ExplicitValue '"quoted-probe"' -ExpectedSource 'explicit' -ExpectedValue 'quoted-probe' -ExpectedSecret 'explicit-fixture-secret'
Invoke-ConfigCase -Name 'immutable-concurrent-hmac' -Mode 'cache' -Explicit 'valid' -ExpectedSource 'explicit' -ExpectedSecret 'explicit-fixture-secret'
Write-Output 'Config/HMAC regression: 13 cases passed; 16000 concurrent hashes verified.'
Write-Output "Artifacts: $fixtureRoot"
