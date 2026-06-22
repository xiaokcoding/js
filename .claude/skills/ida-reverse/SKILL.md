---
name: ida-reverse
description: |
  IDA Pro 逆向分析辅助技能。当用户提到逆向、反编译、分析二进制/PE/ELF/APK/DLL/SO、破解、找密码、漏洞分析、病毒分析、firmware 固件分析，或需要分析 exe/dll/so/elf/macho/sys 等文件时，务必使用此技能。

  Ensure to use this skill when the user wants to analyze any binary file, regardless of whether they explicitly mention "IDA" or "reverse engineering". This includes requests like "看看这个exe", "分析这个dll", "帮我破解", "找一下密码", "这个软件怎么注册", etc.

  本技能适配 ida-pro-mcp 1.4.0：MCP 服务器由 IDA GUI 插件托管（编辑 → 插件 → MCP，Ctrl+Alt+M），Claude Code 经项目 `.mcp.json` 的 stdio 桥调用 `idapro_*` 工具。用自带脚本 open.ps1 打开文件、start.ps1 检查连接，不要手写 PowerShell 启动服务器。
---

# IDA Pro 逆向分析技能（ida-pro-mcp 1.4.0）

## 架构（必读）

ida-pro-mcp 1.4.0 有三种运行形态：

| 形态 | 服务器在哪 | 端口 / 传输 | 适用 |
|------|-----------|------------|------|
| **GUI 插件**（主） | IDA GUI 内的 `mcp-plugin.py` | `127.0.0.1:13337` HTTP JSON-RPC | 交互式分析，推荐 |
| **stdio 桥** | `server.py`（Claude Code 经 `.mcp.json` 调起） | stdio → 转发到 13337 | Claude Code 调用工具的入口 |
| **headless idalib** | `idalib-mcp <file>` 独立进程 | `127.0.0.1:8745` SSE | 无 GUI 批处理，单文件 |

**数据流（GUI 主工作流）**：
```
Claude Code  --stdio-->  server.py  --HTTP JSON-RPC-->  IDA 插件(13337)  --idapro/idalib-->  打开的二进制
```

`server.py` 启动时解析 `mcp-plugin.py` 的 AST，把 59 个 `@jsonrpc` 函数注册为 MCP 工具，加上 `check_connection` 共 **60 个工具**。工具名**没有 `idapro_` 前缀**，Claude Code 侧按 MCP 服务器名 `idapro` 拼成 `mcp__idapro__<工具名>`（例如 `mcp__idapro__decompile_function`）。

## 已知问题与对策

1. **`idalib.dll` 加载失败 / `Cannot load IDA library`**
   - 子进程没继承 `IDADIR`。`open.ps1` / `idalib-headless.ps1` 会自动用 `$env:IDADIR`；手动跑 `idalib-mcp` 前先设 `$env:IDADIR = "<你的 IDA 安装目录>"`。

2. **`C:\Windows\System32\` 文件无权限打开**
   - IDA/idalib 无法直接读 System32。`open.ps1` 自动复制到 `%LOCALAPPDATA%\Temp\ida-mcp\` 再打开；headless 模式请先手动复制。

3. **`Failed to connect to IDA Pro!`（check_connection 返回）**
   - 插件没启动。在 IDA 里按 `Ctrl+Alt+M`（编辑 → 插件 → MCP），看到输出 `[MCP] Server started at http://127.0.0.1:13337` 即就绪。

4. **调试器工具（`dbg_*`）不可用**
   - 这 12 个工具被标记为 unsafe。headless 需 `-Unsafe`；GUI 插件需以 unsafe 模式启动。

5. **服务器名不能用横线**
   - 服务器名固定 `idapro`（无横线），工具前缀 `idapro` 由 Claude Code 侧拼。

6. **headless 模式反编译不可用（本机实测）**
   - ida-pro-mcp 1.4.0 在 IDA 9.3 + Python 3.13 + idalib headless 下，`decompile_function` / `disassemble_function` / `rename_local_variable` / `set_local_variable_type` 抛 `NotImplementedError: Can't import PySide6. Are you trying to use Qt without GUI?`。设 `QT_QPA_PLATFORM=offscreen` 无效（系统已装 PySide6，但 idalib 内部 Qt 检查仍拒绝）。
   - 这些工具依赖 Hex-Rays 反编译器，idalib headless 无 GUI 上下文时不可用。
   - **解法**：用 GUI 插件工作流（`open.ps1` 打开 IDA → `Ctrl+Alt+M` 起插件 → IDA 自带 Qt，反编译可用）。headless 仅用于列举/读取/结构/重命名/patch/进制转换等不依赖反编译器的批量任务。
   - `get_current_address` / `get_current_function` 在 headless 返回 `0xffffffffffffffff`（无光标），GUI 模式返回真实光标位置。

## 工作流程

| 步骤 | 做什么 | 用什么 |
|------|--------|--------|
| 1 | 在 IDA 打开目标二进制 | `scripts/open.ps1 -Path "xxx.exe"` |
| 2 | 等自动分析完成，启动 MCP 插件 | 在 IDA 里 `Ctrl+Alt+M`（编辑 → 插件 → MCP） |
| 3 | 确认 Claude 能连上 | `scripts/start.ps1`（应输出 `OK:<模块名>`） |
| 4 | 调用 60 个 MCP 工具分析 | 直接调 `mcp__idapro__<工具名>` |

## 脚本资源

### `scripts/open.ps1` — 用 IDA GUI 打开文件

- 用 `$env:IDADIR\ida.exe` 定位 IDA（IDA 不走 PATH，必须设 `IDADIR`）
- System32 文件自动复制到 `%LOCALAPPDATA%\Temp\ida-mcp\` 后打开
- 成功输出 `OK:opened`（含 `(temp copy)` 标记表示用了临时副本）

```
powershell -File "scripts\open.ps1" -Path "C:\path\to\file.exe"
```

打开后**还需在 IDA 里按 `Ctrl+Alt+M` 启动插件**，脚本会提示。

### `scripts/start.ps1` — 检查 MCP 插件是否在线

- 探测 `127.0.0.1:13337/mcp` 的 `get_metadata`
- 在线输出 `OK:<当前打开的模块名>`，离线输出 `ERR:not_running` + 提示按 `Ctrl+Alt+M`
- **不启动任何进程**

```
powershell -File "scripts\start.ps1"
```

### `scripts/idalib-headless.ps1` — 无 GUI 批处理（可选）

- 后台跑 `idalib-mcp <file>`，SSE 端口默认 8745
- 自动设 `IDADIR`，用 PATH 上的 `idalib-mcp` 或 pip 脚本回退路径
- 前台常驻，单独终端跑；`-Unsafe` 启用调试器工具

```
pwsh -File "scripts\idalib-headless.ps1" -Path "sample.exe"
pwsh -File "scripts\idalib-headless.ps1" -Path "sample.exe" -Port 8745 -Unsafe
```

连接方式：在 `.mcp.json` 加一个 SSE 服务器
```json
"idapro-headless": { "type": "sse", "url": "http://127.0.0.1:8745/sse" }
```

## 核心工具列表（共 60）

工具名调用时前缀 `mcp__idapro__`。`dbg_*` 为 unsafe，需开启 unsafe 模式。

### 连接
- `check_connection()` — 验证 IDA 插件是否在跑，返回当前打开的文件

### 元数据与导航
- `get_metadata()` — 路径/模块名/基址/大小/md5/sha256
- `get_function_by_name(name)` — 按函数名定位，返回地址/大小
- `get_function_by_address(addr)` — 按地址定位所在函数
- `get_current_address()` — IDA 当前光标地址（headless 返回 0xffffffffffffffff）
- `get_current_function()` — IDA 当前光标所在函数
- `get_entry_points()` — 列出入口点

### 列举（均分页：offset 起始、count 数量，0 表示剩余全部）
- `list_functions(offset, count)` — 函数列表
- `list_imports(offset, count)` — 导入表
- `list_strings(offset, count)` — 字符串列表
- `list_strings_filter(offset, count, filter)` — 按过滤词匹配字符串（支持 /regex/）
- `list_globals(offset, count)` — 全局变量列表
- `list_globals_filter(offset, count, filter)` — 按过滤词匹配全局
- `list_local_types()` — 列出本地类型

### 反编译与反汇编（headless 不可用，见已知问题 6）
- `decompile_function(addr)` — Hex-Rays 伪代码
- `disassemble_function(start_address)` — 反汇编指定函数

### 交叉引用与调用图
- `get_xrefs_to(addr)` — 谁引用了该地址（数据/代码）
- `get_xrefs_to_field(struct_name, field_name)` — 谁引用了某结构体字段
- `get_callers(function_address)` — 谁调用了该函数
- `get_callees(function_address)` — 该函数调用了谁

### 内存读取
- `read_memory_bytes(memory_address, size)` — 读原始字节
- `data_read_byte(addr)` — 读 1 字节整数
- `data_read_word(addr)` — 读 2 字节整数
- `data_read_dword(addr)` — 读 4 字节整数
- `data_read_qword(addr)` — 读 8 字节整数
- `data_read_string(addr)` — 读字符串

### 全局变量
- `get_global_variable_value_at_address(addr)` — 按地址读全局变量值（优先于 data_read_*）
- `get_global_variable_value_by_name(name)` — 按名读全局变量值

### 结构体
- `get_defined_structures()` — 列出所有已定义结构体
- `search_structures(filter)` — 按名搜索结构体
- `get_struct_info_simple(name)` — 结构体基本信息（大小/成员）
- `get_struct_at_address(addr, struct_name)` — 按地址解析某结构体实例的各字段值
- `analyze_struct_detailed(name)` — 结构体详细分析（全部字段+偏移+类型）
- `declare_c_type(c_declaration)` — 声明 C 结构体/枚举（如 `struct foo { int a; };`）

### 栈帧
- `get_stack_frame_variables(function_address)` — 查看函数栈帧变量（名称/偏移/大小/类型）
- `create_stack_frame_variable(function_address, offset, variable_name, type_name)` — 在指定偏移声明一个栈变量
- `delete_stack_frame_variable(function_address, variable_name)` — 删除栈变量

### 重命名
- `rename_function(function_address, new_name)` — 重命名函数
- `rename_global_variable(old_name, new_name)` — 重命名全局变量
- `rename_local_variable(function_address, old_name, new_name)` — 重命名局部变量（headless 不可用）
- `rename_stack_frame_variable(function_address, old_name, new_name)` — 重命名栈变量

### 注释
- `set_comment(address, comment)` — 加注释（反汇编+反编译双向同步）

### 类型
- `set_function_prototype(function_address, prototype)` — 设置函数原型
- `set_global_variable_type(variable_name, new_type)` — 设置全局变量类型
- `set_local_variable_type(function_address, variable_name, new_type)` — 设置局部变量类型（headless 不可用）
- `set_stack_frame_variable_type(function_address, variable_name, type_name)` — 设置栈变量类型

### Patch
- `patch_address_assembles(address, instructions)` — Patch 汇编指令，多条用 `;` 分隔（默认可用，非 unsafe）

### 进制转换
- `convert_number(text, size?)` — **进制转换必须用这个，不要自己算**（text 如 `0x401000`，size 可选）

### 调试器（unsafe，需 `--unsafe` 或 unsafe 插件模式）
- `dbg_start_process()` — 启动调试器，返回当前指令指针
- `dbg_exit_process()` — 退出被调试进程
- `dbg_continue_process()` — 继续运行
- `dbg_step_into()` — 单步进入
- `dbg_step_over()` — 单步跨过
- `dbg_run_to(addr)` — 运行到地址
- `dbg_set_breakpoint(addr)` — 设置断点
- `dbg_delete_breakpoint(addr)` — 删除断点
- `dbg_enable_breakpoint(addr, enable)` — 启用/禁用断点
- `dbg_list_breakpoints()` — 列出断点
- `dbg_get_registers()` — 读全部寄存器
- `dbg_get_call_stack()` — 读调用栈

## 完整工作流

### Step 1: 打开文件
```
powershell -File "scripts\open.ps1" -Path "C:\目标.exe"
```
输出 `OK:opened`。System32 文件会输出 `OK:opened (temp copy)`。

### Step 2: 在 IDA 里启动插件
等自动分析跑完，按 `Ctrl+Alt+M`（编辑 → 插件 → MCP），IDA 控制台出现 `[MCP] Server started at http://127.0.0.1:13337`。

### Step 3: 确认连接
```
powershell -File "scripts\start.ps1"
```
输出 `OK:目标.exe` 表示 Claude 可调用工具。

### Step 4: 全局概览
```
mcp__idapro__get_metadata()
mcp__idapro__list_functions()       # 分页/过滤
mcp__idapro__list_imports()
mcp__idapro__list_strings_filter(filter="http|error|key")
```
关注：架构、入口点、可疑字符串（URL/路径/报错）、导入分类（加密/网络/文件IO）。

### Step 5: 深入关键函数
```
mcp__idapro__decompile_function(addr="main")
mcp__idapro__disassemble_function(addr="0x140001000")
```

### Step 6: 数据流与交叉引用
```
mcp__idapro__get_xrefs_to(addr="关键字符串地址")
mcp__idapro__get_callers(addr="关键函数")
mcp__idapro__get_callees(addr="关键函数")
```

### Step 7: 记录与优化
```
mcp__idapro__set_comment(addr="0x140001000", comment="你的理解")
mcp__idapro__rename_function(addr="sub_140001000", name="check_license")
```

### Step 8: 输出报告
生成 `report.md` 记录发现与步骤。

## Prompt 工程准则

1. **不要手动算进制** — 用 `convert_number`
2. **先 metadata/list 后深入** — 先概况再针对性分析
3. **持续加注释和重命名** — 提升后续分析准确性
4. **跟踪交叉引用** — 有趣的字符串/数据用 `get_xrefs_to` 看谁引用
5. **遇到混淆** — 先做字符串解密、导入哈希去除、控制流平坦化去除等预处理
6. **C++ STL** — 用 FLIRT/Lumina 识别库函数后再分析业务逻辑
7. **遇到 "Failed to connect"** — 插件没起，回 IDA 按 `Ctrl+Alt+M`（编辑 → 插件 → MCP）
8. **遇到 "Cannot load IDA library"** — `IDADIR` 没设或路径不对，把它设成你的 IDA 安装目录（如 `C:\Program Files\IDA Professional 9.3`）
9. **headless 卡住** — `idalib-mcp` 是前台常驻进程，分析大文件会先静默分析再开 SSE，看终端日志判断进度

## MCP 配置（项目 `.mcp.json`，已配好，可移植）

```json
"idapro": {
  "type": "stdio",
  "command": "python",
  "args": ["-m", "ida_pro_mcp"],
  "timeout": 1800
}
```

`python` 从 PATH 解析，`-m ida_pro_mcp` 跑包内 server（默认 stdio transport）。换机器无需改此配置，只要 `python` 在 PATH 且 `pip install ida-pro-mcp`。

headless 可选追加（需先跑 `scripts/idalib-headless.ps1` 起 SSE 服务器）：
```json
"idapro-headless": { "type": "sse", "url": "http://127.0.0.1:8745/sse" }
```
