param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required. Install Git or run from a shell where git is available.'
    }

    $gitRoot = & git -C $resolvedRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'RepositoryRoot must point to an existing Git checkout.'
    }
    if ([IO.Path]::GetFullPath($gitRoot) -ne $resolvedRoot) {
        throw 'RepositoryRoot must be the Git repository root.'
    }

    $skillNames = @('project-orchestrator', 'implement-feature', 'fix-bug', 'code-review', 'delphi-build')
    $requiredFiles = @(
        '.ai/ORCHESTRATOR.md',
        '.ai/RESUME.md',
        '.ai/TASK-INDEX.md',
        '.ai/templates/RUN-STATE.md',
        'docs/workflows/implement-feature.md',
        'docs/workflows/fix-bug.md',
        'docs/workflows/code-review.md',
        'project-map.md',
        'scripts/validate-orchestrator.ps1'
    )
    foreach ($skillName in $skillNames) {
        $requiredFiles += ".agents/skills/$skillName/SKILL.md"
        $requiredFiles += ".agents/skills/$skillName/agents/openai.yaml"
    }

    foreach ($relativeFile in $requiredFiles) {
        $absoluteFile = Join-Path $resolvedRoot $relativeFile
        if (-not (Test-Path -LiteralPath $absoluteFile -PathType Leaf)) {
            throw "Missing package file: $relativeFile"
        }
        if ([string]::IsNullOrWhiteSpace([IO.File]::ReadAllText($absoluteFile))) {
            throw "Empty package file: $relativeFile"
        }
    }

    $descriptions = @{}
    foreach ($skillName in $skillNames) {
        $skillFile = Join-Path $resolvedRoot ".agents/skills/$skillName/SKILL.md"
        $skillText = [IO.File]::ReadAllText($skillFile)
        $header = [regex]::Match($skillText, '\A---\r?\nname: ([a-z0-9-]+)\r?\ndescription: ([^\r\n]+)\r?\n---\r?\n')
        if (-not $header.Success -or $header.Groups[1].Value -ne $skillName) {
            throw "Invalid skill name/frontmatter: $skillName. Keep the package's flat name/description format."
        }
        $description = $header.Groups[2].Value.Trim()
        if ($description.Length -gt 1024 -or $description -match '[:<>]') {
            throw "Invalid description scalar: $skillName. Use concise plain YAML text without colon/angle brackets."
        }
        if ($descriptions.ContainsKey($description)) {
            throw "Duplicate skill description: $skillName"
        }
        $descriptions[$description] = $true
        if ($skillText -match '(?m)^\s*\[TODO:[^\r\n]*\]\s*$') {
            throw "Unfinished skill scaffold: $skillName"
        }

        $metadataFile = Join-Path $resolvedRoot ".agents/skills/$skillName/agents/openai.yaml"
        $metadata = [IO.File]::ReadAllText($metadataFile)
        $metadataMatch = [regex]::Match($metadata,
            '\Ainterface:\r?\n  display_name: "([^"\r\n]+)"\r?\n  short_description: "([^"\r\n]+)"\r?\n  default_prompt: "([^"\r\n]+)"\r?\n?\z')
        if (-not $metadataMatch.Success) {
            throw "Invalid skill UI metadata: $skillName"
        }
        $shortDescription = $metadataMatch.Groups[2].Value
        if ($shortDescription.Length -lt 25 -or $shortDescription.Length -gt 64) {
            throw "Skill UI short description must contain 25-64 characters: $skillName"
        }
        if (-not $metadataMatch.Groups[3].Value.Contains('$' + $skillName)) {
            throw "Skill UI prompt must invoke its skill: $skillName"
        }
    }

    $linkCount = 0
    $documentFiles = @($requiredFiles | Where-Object { $_.EndsWith('.md') })
    foreach ($relativeFile in $documentFiles) {
        $absoluteFile = Join-Path $resolvedRoot $relativeFile
        $content = [IO.File]::ReadAllText($absoluteFile)
        foreach ($link in [regex]::Matches($content, '!?\[[^\]\r\n]+\]\(([^)\r\n]+)\)')) {
            $target = $link.Groups[1].Value.Trim()
            if ($target -match '^(https?://|mailto:|#)') {
                continue
            }
            $target = [Uri]::UnescapeDataString(($target -split '#', 2)[0])
            $resolvedTarget = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $absoluteFile) $target))
            $rootPrefix = $resolvedRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            if (-not $resolvedTarget.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw ('Link leaves the repository in {0}: {1}' -f $relativeFile, $target)
            }
            if (-not (Test-Path -LiteralPath $resolvedTarget)) {
                throw ('Broken Markdown link in {0}: {1}' -f $relativeFile, $target)
            }
            $linkCount++
        }
    }

    $parserTokens = $null
    $parserErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $resolvedRoot 'scripts/validate-orchestrator.ps1'), [ref]$parserTokens, [ref]$parserErrors) | Out-Null
    if ($parserErrors.Count -gt 0) {
        throw ('PowerShell syntax error: ' + $parserErrors[0].Message)
    }

    $visibleProbes = $requiredFiles + @(
        'config.example.ini', 'bin/config.example.ini', '.env.example',
        'DelphiAPIStarterKit.deployproj', 'DelphiAPIStarterKit.res', 'Server.res',
        'sources/app/App.WebModule.dfm', 'assets/databases/demo_delphirest.sql',
        'docs/api/postman.collection.json'
    )
    $unexpectedIgnored = @(& git -C $resolvedRoot check-ignore --no-index -- $visibleProbes)
    if ($LASTEXITCODE -gt 1) {
        throw 'Git could not validate versionable package/source paths.'
    }
    if ($unexpectedIgnored.Count -gt 0) {
        throw ('Required package/source path is ignored: ' + $unexpectedIgnored[0])
    }

    $ignoredProbes = @(
        'Win32/Debug/DelphiAPIStarterKit.exe', 'Win64/Release/example.dcu',
        'Win64x/Debug/example.exe', 'Linux64/Release/DelphiAPIStarterKit',
        'bin/bin.rar', 'bin/logs/example.log', 'logs/example.log',
        '.ai/runs/example.md', '.ai/cache/example.json', '.env.local',
        'bin/config.ini', '__pycache__/example.pyc',
        'initialize-ai-agent-system-codex-copilot.md'
    )
    $actualIgnored = @(& git -C $resolvedRoot check-ignore --no-index -- $ignoredProbes)
    if ($LASTEXITCODE -gt 1) {
        throw 'Git could not validate local-output ignore rules.'
    }
    foreach ($probe in $ignoredProbes) {
        if ($actualIgnored -notcontains $probe) {
            throw "Local/generated path is not ignored: $probe"
        }
    }

    $trackedIgnored = @(& git -C $resolvedRoot ls-files --cached --ignored --exclude-standard)
    if ($LASTEXITCODE -ne 0) {
        throw 'Git could not check tracked ignored files.'
    }
    if ($trackedIgnored.Count -gt 0) {
        Write-Output ('NOTE: Already tracked ignored files remain tracked: ' + ($trackedIgnored -join ', '))
    }
    Write-Output "PASS: $($skillNames.Count) skills, $linkCount local links, PowerShell syntax, and Git ignore behavior."
    Write-Output 'Delphi compilation and remediation tasks were not executed.'
    exit 0
}
catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
    exit 1
}
