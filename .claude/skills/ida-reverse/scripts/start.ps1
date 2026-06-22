<#
.SYNOPSIS
Check whether the IDA Pro MCP plugin is live (RPC 127.0.0.1:13337).

.DESCRIPTION
ida-pro-mcp 1.4.0 hosts the MCP server INSIDE the IDA GUI via a plugin
(Edit -> Plugins -> MCP, shortcut Ctrl+Alt+M). This script does NOT start
anything — it only probes the plugin's JSON-RPC endpoint to verify a file
is open and the server is reachable from Claude Code's stdio bridge.

Outputs:
  OK:<module>      plugin running, currently-open module name
  ERR:not_running  nothing on 13337 -> open IDA + press Ctrl+Alt+M

Usage: run without parameters.
#>

$Port = 13337

try {
    $body = '{"jsonrpc":"2.0","id":1,"method":"get_metadata","params":[]}'
    $r = Invoke-RestMethod "http://127.0.0.1:$Port/mcp" -Method Post `
        -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
    if ($r.result -and $r.result.module) {
        Write-Output "OK:$($r.result.module)"
    } else {
        Write-Output "OK:unknown"
    }
} catch {
    Write-Output "ERR:not_running"
    Write-Output "Hint: open the binary in IDA, then press Ctrl+Alt+M (Edit -> Plugins -> MCP) to start the RPC server on 127.0.0.1:$Port."
}