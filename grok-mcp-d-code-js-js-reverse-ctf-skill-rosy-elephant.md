# Plan: `js-ctf` Skill — CTF-focused JS Reverse Engineering for Modern Websites

## Context

现有 `D:\Code\js\js-reverse` 是生产向 JS 逆向 skill（6 阶段工作流、evidence-heavy 输出契约、目标是算法复现 + 服务端验证），节奏与 CTF 不匹配：CTF 要速度、以 flag 为正确性 oracle、能利用就不复现、能静态读通就不补环境。

本次要新建一个独立同层 skill `D:\Code\js\js-ctf\`，专攻现代化网页 CTF 题目（crackme / Web challenge / WASM keycheck / anti-debug 阻断 / proto pollution / JWT 绕过 / postMessage 利用等），**共用 js-reverse 的 MCP 栈**，覆盖最大类目，深度算法还原场景走 handoff 回 js-reverse。

调用 grok-search 的成果：确认 2025–2026 的 JS 反混淆主链为 **webcrack → wakaru → obfuscator-io-deobfuscator → restringer → synchrony → js-beautify**，AST 兜底用 `jscodeshift`/`astexplorer.net`；在线可选 `deobfuscate.io`、`de4js`。这条链会直接写进 `references/toolchain-deobfuscation.md` 决策树。

## 已确认的设计决策

1. **Placement** — 独立新 skill `D:\Code\js\js-ctf\`，与 `js-reverse` 平级
2. **Scope** — 最大覆盖：deobf + 常见 Web 利用 + WASM + 反调试 + Service Worker + 客户端密码
3. **Runtime** — 沿用 js-reverse 的 MCP 栈：JSReverser-MCP + TMWebDriver + Playwright + screen_ocr + ljqCtrl

## 目录结构

```
D:\Code\js\js-ctf\
├── SKILL.md                                 # 入口 skill 文档（中文，frontmatter 模仿 js-reverse）
├── references\
│   ├── toolchain-deobfuscation.md           # webcrack→wakaru→obf-io-deobf→restringer→synchrony→js-beautify 决策树
│   ├── browser-first-workflow.md            # 纯 DevTools 路径（overrides/logpoints/blocking/Performance）
│   ├── mcp-routing-ctf.md                   # CTF 任务 → JSReverser-MCP 工具简化映射
│   ├── flag-heuristics.md                   # flag 正则、熵、base64/hex 签名、常见格式
│   ├── handoff-js-reverse.md                # 触发条件 + 交接清单，指向 js-reverse Phase 3–6
│   ├── output-contract.md                   # CTF writeup 模板（比 js-reverse 精简一半）
│   ├── task-input-template.md               # 轻量输入模板
│   ├── fallbacks.md                         # CTF 专用回退（tool 切换 / category 切换 / MCP 降级 / handoff）
│   ├── categories\                          # 10 个类目 playbook，按症状路由
│   │   ├── prototype-pollution.md
│   │   ├── dom-clobbering.md
│   │   ├── postmessage-abuse.md
│   │   ├── jwt-tricks.md
│   │   ├── csp-bypass.md
│   │   ├── service-worker-abuse.md
│   │   ├── wasm-puzzles.md
│   │   ├── anti-debug-escape.md
│   │   ├── client-side-crypto.md
│   │   └── vm-obfuscator.md
│   ├── cases\                               # 6 个端到端 case study
│   │   ├── case-obfuscator-io-crackme.md
│   │   ├── case-proto-pollution-gadget.md
│   │   ├── case-wasm-keycheck.md
│   │   ├── case-antidebug-sw-combo.md
│   │   ├── case-jwt-alg-confusion.md
│   │   └── case-clientside-crypto-leak.md
│   └── schemas\
│       ├── ctf-task-input.schema.json       # 去掉 verify/security，加 category/flagRegex/budget
│       └── ctf-task-input.example.json
```

合计约 **27 个文件**（1 SKILL.md + 8 顶层 references + 10 categories + 6 cases + 2 schemas）。

## SKILL.md 设计

### Frontmatter（中文 description，内嵌中英文触发词）

```yaml
---
name: js-ctf
description: 在前端 JS CTF/crackme/安全挑战中使用，适用于混淆代码快速解开、客户端漏洞利用、WASM 解谜、反调试绕过、flag 定位。触发：CTF、crackme、flag、prototype pollution、原型污染、DOM clobbering、postMessage、JWT、CSP bypass、WASM 解谜、反调试、service worker、client-side crypto、obfuscator.io、webcrack、wakaru、HTB、picoCTF、SekaiCTF、hxp、BountyCTF。
---
```

### 核心原则（与 js-reverse 的对照）

1. **Speed-over-rigor** — 证据够定位 flag 即可，**不**闭环服务端验证（↔ js-reverse 第 5 条）
2. **Exploit-not-emulate** — 能在浏览器内直接利用就不导出 Node 复现包（↔ js-reverse Phase 3）
3. **Flag-as-oracle** — flag 格式（`flag\{…\}` / `HTB\{…\}` / `CTF\{…\}` / `picoCTF\{…\}`）即最强正确性信号，匹配即停
4. **Read-compiled-bundle-not-sources** — 直接读 webpack/Vite 产物，不还原项目结构
5. **Observe-first**（保留）— 继承 js-reverse：先看网络、DOM、脚本清单

### 工作流（5 阶段，不是 6）

| Phase | 名称 | 出口条件 |
|-------|------|---------|
| 1 | **Triage** | 识别类目标签 + flag 格式假设 |
| 2 | **Deobfuscate** | 只在可读性阻碍时执行；目标代码可读 |
| 3 | **Locate** | 锁定单一 flag check / sink / WASM export |
| 4 | **Solve** | 按 category playbook 执行 → flag 或 PoC |
| 5 | **Report** | 按 `output-contract.md` 产出 writeup |

### 路由表（用户话 → 入口）

| 用户说 | 入口 |
|--------|------|
| "这个 crackme 的 flag 是多少" | Triage → `flag-heuristics.md` + `toolchain-deobfuscation.md` |
| "代码被 obfuscator.io 混淆了" | `toolchain-deobfuscation.md` → webcrack 链 |
| "有原型污染漏洞吗" | `categories/prototype-pollution.md` |
| "WASM 里有 flag" | `categories/wasm-puzzles.md` |
| "页面过不了反调试" | `categories/anti-debug-escape.md` + `browser-first-workflow.md` |
| "要移植到 Python 复现" | Handoff → js-reverse Phase 5–6 |

### 输出契约（CTF writeup，参考 js-reverse 精简版）

- flag (raw)
- category label
- solve path（3–6 条步骤）
- key observations（最多 3 条）
- tool chain used
- artifact path（可选）

对照 js-reverse `references/output-contract.md` 11 字段强约束，本契约只保留 5 必须 + 1 可选。

## references/ 文件清单与用途

| 路径 | 用途 | 是否复用 js-reverse |
|------|------|---------------------|
| `toolchain-deobfuscation.md` | 按症状选工具的决策树 | 新（`js-reverse/references/ast-deobfuscation.md` 只讲 pass 顺序，不讲工具） |
| `browser-first-workflow.md` | 纯 DevTools 路径 | 新 |
| `mcp-routing-ctf.md` | CTF 任务 → MCP 工具简化映射 | 新；末尾指向 `js-reverse/references/tool-catalog.md` |
| `flag-heuristics.md` | flag 正则 + 熵 + 签名 | 新 |
| `handoff-js-reverse.md` | 交接元文档 | 元文档 |
| `output-contract.md` | CTF writeup 模板 | 新（精简版） |
| `task-input-template.md` | 轻量输入模板 | 新（简化版） |
| `fallbacks.md` | CTF 专用回退表 | 新 |
| `categories/*.md` ×10 | 类目 playbook | 全新 |
| `schemas/ctf-task-input.*` | 任务输入 schema + example | 新（基于 js-reverse schema 改造） |

## cases/ 案例清单

| 文件 | 场景 | 技术焦点 |
|------|------|---------|
| `case-obfuscator-io-crackme.md` | obfuscator.io 全量混淆 crackme，密码比较硬编码 | webcrack → obf-io-deobf → js-beautify 静态出 flag |
| `case-proto-pollution-gadget.md` | `?__proto__[src]=...` 污染 config 触发 XSS 拿 `/admin/flag` | proto sink 发现 + gadget chain |
| `case-wasm-keycheck.md` | WASM `exports.check(input)` 字节级 XOR | wasm2wat + 常量表识别 + Z3 反解 |
| `case-antidebug-sw-combo.md` | SW 拦 `/flag` + setInterval 反调试跳转 | SW 卸载 + override 反调试脚本组合 |
| `case-jwt-alg-confusion.md` | RS256 → HS256 用公钥当 HMAC secret | jwks 读取 + 重签 + admin 提权 |
| `case-clientside-crypto-leak.md` | 自研 4 轮 Feistel，Hook 抓 round key | Hook sampling + 算法反转 |

## 与 js-reverse 的集成

### Handoff 触发（写在 `references/handoff-js-reverse.md`）

1. 题目要求 Node/Python 复现算法（不只拿 flag）→ js-reverse Phase 3–6
2. 需要服务端验证闭环 → js-reverse Phase 4
3. 需要生产级补环境 → js-reverse `local-rebuild.md`
4. VMP 深度插桩（超出 `categories/vm-obfuscator.md`）→ js-reverse `instrumentation.md`

### 跨引用，**严禁复制**（交叉引用而非重写）

- `js-reverse/references/ast-deobfuscation.md` — AST pass 顺序
- `js-reverse/references/tool-catalog.md` — MCP 完整工具参数
- `js-reverse/references/env-patching.md` — 补环境规则（仅 handoff 后用）
- `js-reverse/references/local-rebuild.md` + `node-env-rebuild.md` — 本地复现
- `js-reverse/references/instrumentation.md` — VMP 采样策略
- `js-reverse/references/cases/case-ast-deobfuscation.md` — AST 细节
- `js-reverse/references/cases/case-window-honeypot.md` — 反调试补充

js-ctf **不重写** `automation-entry.md`、`mcp-task-template.md`、`task-artifacts.md`、`tool-defaults.md`（全部交叉引用；仅在 `mcp-routing-ctf.md` 中改 `search_in_scripts` 默认关键词为 `flag|ctf|htb|pico|hxp`）。

## 风险与边界

- **Skill 触发歧义**：CTF 偏向词（CTF/crackme/flag/HTB/picoCTF/challenge）路由到 js-ctf；生产偏向词（签名/加密参数/补环境/h5st/x-bogus）路由到 js-reverse；模糊词（混淆/反调试/JS 逆向）默认 js-ctf（轻量、可降级），用户声明要复现/移植再升级
- **MCP 不可用**：`browser-first-workflow.md` 作为 MCP-free 路径兜底；`fallbacks.md` 给出 full MCP / JSReverser-only / 纯 DevTools 三档降级
- **CTF organizer 误用**：定位为"玩家 writeup 助手"，不写反滥用章节（用户确认范围）

## 实施分期（建议 MVP 先行）

### MVP（Phase A —— ~9 文件可跑通 skill 触发 + 一条主链）

1. `SKILL.md`
2. `references/toolchain-deobfuscation.md`
3. `references/flag-heuristics.md`
4. `references/mcp-routing-ctf.md`
5. `references/output-contract.md`
6. `references/handoff-js-reverse.md`
7. `references/categories/prototype-pollution.md`（作为类目模板样板）
8. `references/cases/case-obfuscator-io-crackme.md`（作为案例模板样板）
9. 其他 9 个 `categories/*.md` 和 5 个 `cases/*.md` 写标题 + 一段 TODO stub（避免 SKILL.md 引用断链）

### Phase B（完整铺开）

10–19. 填充其余 9 个 `categories/*.md`
20–24. 填充其余 5 个 `cases/*.md`
25. `references/browser-first-workflow.md`
26. `references/task-input-template.md`
27. `references/fallbacks.md`
28–29. `references/schemas/*`

## 实施约定

- 写 SKILL.md 时先调用 `superpowers:writing-skills` skill 获取最新 frontmatter 规范
- 所有新文件沿用 js-reverse 的 Markdown 风格（中文正文 + 表格路由 + 代码块命令）
- 引用 js-reverse 文件时用**绝对路径** `D:\Code\js\js-reverse\references\...`，避免后续移动产生断链
- MVP 完成后先做 §验证 的 5 个 sanity check，再铺 Phase B

## 验证计划

MVP 落盘后在新对话中跑以下 prompt，预期路由与行为：

1. **触发 + deobf 主链**：「这是一个包含 webcrack 可解 obfuscator.io 的 crackme，URL http://localhost:8000/chall.html，flag 格式 `flag\{.*?\}`」
   → 预期：js-ctf 激活，Phase 2 进 `toolchain-deobfuscation.md`，webcrack 一键输出 flag
2. **类目路由**：「这个页面好像有原型污染，`?__proto__[x]=y` 能污染 window」
   → 预期：进 `categories/prototype-pollution.md`，Phase 3 用 MCP 搜 sink
3. **Handoff 触发**：「帮我把这个 crackme 的加密算法移植到 Python」
   → 预期：识别 handoff 条件 1，返回「建议切换到 js-reverse Phase 5–6」
4. **MCP 降级**：「MCP 不可用，纯浏览器拿这个 flag」
   → 预期：跳过 `mcp-routing-ctf.md`，走 `browser-first-workflow.md`
5. **反调试阻断**：「页面打开 DevTools 就跳转」
   → 预期：先进 `categories/anti-debug-escape.md`，处理完回主流程

**Sanity baseline**：激活后第一回复若未提及 `flag-heuristics.md` 或未列候选 category，则 SKILL.md 的 Triage 指令不够明确，需加强。

## 关键文件（按实施顺序）

**Phase A**：
- `D:\Code\js\js-ctf\SKILL.md`
- `D:\Code\js\js-ctf\references\toolchain-deobfuscation.md`
- `D:\Code\js\js-ctf\references\flag-heuristics.md`
- `D:\Code\js\js-ctf\references\mcp-routing-ctf.md`
- `D:\Code\js\js-ctf\references\output-contract.md`
- `D:\Code\js\js-ctf\references\handoff-js-reverse.md`
- `D:\Code\js\js-ctf\references\categories\prototype-pollution.md`
- `D:\Code\js\js-ctf\references\cases\case-obfuscator-io-crackme.md`

**Phase B** 依上表继续铺开。
