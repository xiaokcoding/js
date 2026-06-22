## ida-reverse（IDA Pro 逆向）

部署步骤：

1. **IDA Pro 9.0+**，设环境变量 `IDADIR` 指向安装目录：
   ```powershell
   [Environment]::SetEnvironmentVariable('IDADIR', '<你的 IDA 安装目录>', 'User')
   ```
2. **Python 3.x** 加入 PATH。
3. **ida-pro-mcp**：
   ```powershell
   pip install ida-pro-mcp
   python -m ida_pro_mcp --install   # 装 IDA 插件，IDA 重启后生效
   ```
   装完 `idalib-mcp`、`ida-pro-mcp` 命令即在 PATH（headless 脚本靠它）。

日常用法（GUI 主工作流）：IDA 打开 exe → `Ctrl+Alt+M`（编辑 → 插件 → MCP）→ Claude Code 调 `mcp__idapro__*`。

## apk-reverse（Android APK 逆向）

脚本依赖（全部加 PATH）：

| 工具                     | 用途        | 安装方式                                                                                                           |
| ------------------------ | ----------- | ------------------------------------------------------------------------------------------------------------------ |
| `jadx`                   | Java 反编译 | [skylot/jadx](https://github.com/skylot/jadx) releases，解压后把 `bin` 加 PATH                                     |
| `apktool`                | 解包/重打包 | [iBotPeaches/Apktool](https://github.com/iBotPeaches/Apktool) releases，装 `apktool.bat` + `apktool.jar` 并加 PATH |
| `frida` / `frida-ps`     | 动态 Hook   | `pip install frida-tools`，Scripts 目录加 PATH                                                                     |
| `adb`                    | 设备操作    | Android platform-tools，加 PATH                                                                                    |
| `zipalign` / `apksigner` | 对齐/签名   | Android build-tools，加 PATH                                                                                       |
| `keytool` / `java`       | keystore    | JDK，加 PATH                                                                                                       |

脚本：`decode.ps1`（jadx+apktool 落盘）、`frida-run.ps1`、`rebuild-sign-install.ps1`、`manifest-summary.ps1`。

## radare2（CLI 二进制分析）

脚本：`recon.ps1`。

| 工具                                     | 安装                                                                                       |
| ---------------------------------------- | ------------------------------------------------------------------------------------------ |
| `r2` / `radare2` / `rabin2` / `rasm2` 等 | [radareorg/radare2](https://github.com/radareorg/radare2) releases，解压后把 `bin` 加 PATH |

## mcp-js-reverse-playbook（前端 JS 逆向）

**MCP 服务器**：`js-reverse`（项目 `.mcp.json`，`npx js-reverse-mcp`，无需本机装包）。

工具调用前缀 `mcp__js-reverse__*`，无本机路径依赖。

## reverse-engineering / llm-api-adapter

纯方法论文档，无脚本、无工具依赖，直接可用。

## .mcp.json（项目级，已配好）

```json
{
  "mcpServers": {
    "jshook":     { "type": "stdio", "command": "npx", "args": ["-y", "@jshookmcp/jshook@latest"] },
    "js-reverse": { "type": "stdio", "command": "npx", "args": ["js-reverse-mcp"] },
    "idapro":     { "type": "stdio", "command": "python", "args": ["-m", "ida_pro_mcp"], "timeout": 1800 },
    "playwright": { "type": "stdio", "command": "npx", "args": ["-y", "@playwright/mcp@latest"] }
  }
}
```
