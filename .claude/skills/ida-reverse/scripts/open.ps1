<#
.SYNOPSIS
Open a binary file in the IDA Pro GUI, then prompt to start the MCP plugin.

.DESCRIPTION
ida-pro-mcp 1.4.0 is driven by a plugin running INSIDE the IDA GUI. This
script launches IDA with the target file and tells the user the next step
(Edit -> Plugins -> MCP / Ctrl+Alt+M). System32 files are auto-copied to
a Temp folder first, since IDA cannot read C:\Windows\System32 directly.

.PARAMETER Path
Binary file path (required).

.Outputs
  OK:opened               IDA launched with the file
  OK:opened (temp copy)   file copied to Temp before opening (System32)
  ERR:ida_not_found:<path>
  ERR:file_not_found
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

# Locate ida.exe via IDADIR (IDA is not PATH-resolvable; IDADIR is required).
function Get-IdaExe {
    if ($env:IDADIR -and (Test-Path -LiteralPath (Join-Path $env:IDADIR 'ida.exe'))) {
        return (Join-Path $env:IDADIR 'ida.exe')
    }
    return $null
}

$TempDir = Join-Path $env:LOCALAPPDATA 'Temp\ida-mcp'

$idaExe = Get-IdaExe
if (-not $idaExe) {
    Write-Output "ERR:ida_not_found"
    Write-Output "Hint: set IDADIR to your IDA install directory."
    exit 1
}

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Output "ERR:file_not_found"
    exit 1
}

# System32 -> Temp copy (IDA cannot read C:\Windows\System32 directly).
$isTempCopy = $false
if ($Path -match 'C:\\Windows\\System32') {
    if (-not (Test-Path -LiteralPath $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    }
    $name = [System.IO.Path]::GetFileName($Path)
    $tempPath = Join-Path $TempDir $name
    Copy-Item -LiteralPath $Path $tempPath -Force -ErrorAction SilentlyContinue
    if ($?) { $Path = $tempPath; $isTempCopy = $true }
}

Start-Process -FilePath $idaExe -ArgumentList "`"$Path`""
$tag = if ($isTempCopy) { ' (temp copy)' } else { '' }
Write-Output "OK:opened$tag"
Write-Output "Next: wait for auto-analysis, then press Ctrl+Alt+M (Edit -> Plugins -> MCP) to start the RPC server on 127.0.0.1:13337."