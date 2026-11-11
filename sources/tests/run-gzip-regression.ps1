[CmdletBinding()]
param([string]$DelphiRoot = 'C:\Program Files (x86)\Embarcadero\Studio\37.0')

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$scratchRoot = Join-Path ([IO.Path]::GetTempPath()) ('DelphiAPI-Gzip-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratchRoot | Out-Null
$unitPaths = @(
    (Join-Path $DelphiRoot 'lib\win64\release'),
    (Join-Path $projectRoot 'sources\core'),
    (Join-Path $projectRoot 'sources\infrastructure\http')
) -join ';'
& (Join-Path $DelphiRoot 'bin\dcc64.exe') '-B' '-Q' ('-U' + $unitPaths) '-NSSystem;Winapi;Data;Datasnap;Web;Soap;Xml' ('-E' + $scratchRoot) ('-N0' + $scratchRoot) (Join-Path $PSScriptRoot 'integration\GzipFixture.dpr')
if ($LASTEXITCODE -ne 0) { throw 'Gzip fixture build failed.' }
& node (Join-Path $PSScriptRoot 'integration\gzip-regression.mjs') (Join-Path $scratchRoot 'GzipFixture.exe')
if ($LASTEXITCODE -ne 0) { throw 'Gzip HTTP regression failed.' }
Write-Output "Artifacts: $scratchRoot"
