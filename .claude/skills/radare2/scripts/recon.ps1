param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [int]$StringsLimit = 40,

    [int]$ImportsLimit = 80,

    [switch]$RunAnalysis
)

# Force UTF-8 output to avoid mojibake in section titles.
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$ErrorActionPreference = 'Stop'

function Test-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    # Verify radare2 commands are available before running, to fail early.
    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        throw "Missing command: $Name"
    }
}

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
    [string]$Title
    )

    # Fixed section titles for readability and downstream grep.
    ""
    "=== $Title ==="
}

Test-Tool -Name 'rabin2'
if ($RunAnalysis) {
    Test-Tool -Name 'r2'
}

# Normalize to an absolute path to avoid r2/rabin2 ambiguity on relative paths.
$resolvedPath = Resolve-Path -LiteralPath $TargetPath
$target = $resolvedPath.Path

"Target: $target"

Write-Section -Title 'Basic Info'
& rabin2 -I -- "$target"

Write-Section -Title 'Sections'
& rabin2 -S -- "$target"

Write-Section -Title 'Imports'
& rabin2 -i -- "$target" | Select-Object -First $ImportsLimit

Write-Section -Title 'Exports'
& rabin2 -E -- "$target"

Write-Section -Title 'Strings'
& rabin2 -zz -- "$target" | Select-Object -First $StringsLimit

if ($RunAnalysis) {
    Write-Section -Title 'Functions & Entry Analysis'
    & r2 -A -q -c 's entry0;afl;iz;ii;q' -- "$target"
}
