[CmdletBinding()]
param(
    [string]$DelphiRoot = 'C:\Program Files (x86)\Embarcadero\Studio\37.0',
    [string]$ScratchParent = [System.IO.Path]::GetTempPath()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$compilerPath = Join-Path $DelphiRoot 'bin\dcc64.exe'
$rtlPath = Join-Path $DelphiRoot 'lib\win64\release'
if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
    throw "Delphi Win64 compiler not found: $compilerPath"
}
if (-not (Test-Path -LiteralPath $rtlPath -PathType Container)) {
    throw "Delphi Win64 RTL not found: $rtlPath"
}
if (-not (Test-Path -LiteralPath $ScratchParent -PathType Container)) {
    throw "Scratch parent must be an existing directory: $ScratchParent"
}

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$sourceRoot = Join-Path $projectRoot 'sources'
$unitPaths = @(
    $rtlPath
    (Join-Path $sourceRoot 'core')
    (Join-Path $sourceRoot 'shared\helpers')
    (Join-Path $sourceRoot 'infrastructure\database')
    (Join-Path $sourceRoot 'infrastructure\security')
    (Join-Path $sourceRoot 'modules\products')
) -join ';'
$scratchPath = Join-Path (Resolve-Path -LiteralPath $ScratchParent).Path (
    'DelphiAPI-CoreRegressions-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratchPath | Out-Null

foreach ($fixtureName in @('SerializerRegression', 'InfrastructureRegression')) {
    $fixturePath = Join-Path $PSScriptRoot "unit\$fixtureName.dpr"
    $fixtureOutput = Join-Path $scratchPath $fixtureName
    New-Item -ItemType Directory -Path $fixtureOutput | Out-Null
    $compilerArguments = @(
        '-B'
        '-Q'
        "-E$fixtureOutput"
        "-N0$fixtureOutput"
        "-U$unitPaths"
        '-NSSystem;Winapi;Data;Datasnap;Web;Soap;Xml'
        $fixturePath
    )
    & $compilerPath @compilerArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$fixtureName compilation failed with exit code $LASTEXITCODE"
    }

    $fixtureArguments = @()
    if ($fixtureName -eq 'InfrastructureRegression') {
        $fixtureArguments = @('--isolated-fixture')
    }
    & (Join-Path $fixtureOutput "$fixtureName.exe") @fixtureArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$fixtureName failed with exit code $LASTEXITCODE; outputs: $fixtureOutput"
    }
}

Write-Output "PASS: isolated Win64 core regressions. Outputs and fixture logs: $scratchPath"
Write-Output 'SQLite uses memory only; missing MyDB failures do not access a network database.'
