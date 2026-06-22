<#
.SYNOPSIS
Start idalib-mcp in headless mode (no IDA GUI) for a single binary.

.DESCRIPTION
ida-pro-mcp 1.4.0 ships `idalib-mcp <input_path>`: a standalone MCP server
that analyzes the file with idalib and exposes the same 59 tools over SSE.
Use this for batch / no-GUI workflows. Requires IDADIR pointing at IDA 9.0+.

NOTE (本机实测): headless 模式下 decompile_function / disassemble_function /
rename_local_variable / set_local_variable_type 不可用（idalib 无 GUI 上下文，
抛 PySide6/Qt 错误）。反编译请用 GUI 插件工作流（open.ps1 + Ctrl+Alt+M）。

The server runs in the FOREGROUND (it stays alive to serve tool calls).
Run it in a dedicated terminal, or background it and stop the process when
done. To let Claude Code talk to it, add an SSE MCP server in .mcp.json:

    "idapro-headless": { "type": "sse", "url": "http://127.0.0.1:8745/sse" }

.PARAMETER Path
Binary file to analyze (required).
.PARAMETER Port
SSE port, default 8745.
.PARAMETER Unsafe
Enable unsafe tools (patching, debugger control). DANGEROUS.

.Usage
  pwsh -File scripts\idalib-headless.ps1 -Path "sample.exe"
  pwsh -File scripts\idalib-headless.ps1 -Path "sample.exe" -Port 8745 -Unsafe
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$Port = 8745,

    [switch]$Unsafe
)

# idalib needs IDADIR to load idalib.dll — must point at your IDA install.
if (-not $env:IDADIR) {
    Write-Output "ERR:IDADIR_not_set"
    Write-Output "Hint: set IDADIR to your IDA install directory, e.g.:"
    Write-Output '  $env:IDADIR = "<path\to\IDA>"'
    exit 1
}

# Locate idalib-mcp via PATH (pip install ida-pro-mcp adds it).
$serverExe = (Get-Command idalib-mcp -ErrorAction SilentlyContinue).Source
if (-not $serverExe) {
    Write-Output "ERR:idalib_mcp_not_found"
    Write-Output "Hint: pip install ida-pro-mcp, then ensure its Scripts dir is on PATH (or run 'python -m ida_pro_mcp.idalib_server' directly)."
    exit 1
}

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Output "ERR:file_not_found"
    exit 1
}

$args = @($Path, '--port', $Port)
if ($Unsafe) { $args += '--unsafe' }

Write-Output "INFO:starting idalib-mcp on 127.0.0.1:$Port (IDADIR=$env:IDADIR)"
Write-Output "INFO:add this to .mcp.json to connect: { `"type`": `"sse`", `"url`": `"http://127.0.0.1:$Port/sse`" }"

& $serverExe @args
exit $LASTEXITCODE