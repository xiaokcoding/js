# Modern Web CTF Skill Plan

## Summary

新建一个独立 skill，名称暂定 `modern-web-ctf`，定位为“现代前端/浏览器型 CTF 解题工作流”，不是泛化 Web 渗透手册，也不是企业逆向 SOP。  
它以现有 `js-reverse` 的 observe-first、hook-first、evidence-first 为骨架，补上更适合 CTF 的现代网页面：`source map`、`WebAssembly`、`service worker`、`GraphQL`、`storage/token`、`runtime hook`、`SSE/WebSocket`、前端框架产物识别与快速 flag 提取。

## Key Changes

- 产物形态：
  新建一个 skill 目录，而不是继续扩写现有 `js-reverse`；避免把“站点逆向/补环境复现”和“CTF 快速拿点”混成一个大而散的技能。
- 目录结构：
  `modern-web-ctf/SKILL.md`、`agents/openai.yaml`、`references/`、可选 `scripts/`。
- SKILL 触发词：
  覆盖“web ctf / 浏览器题 / 前端题 / wasm / source map / service worker / graphql / obfuscated js / js challenge / client-side flag / anti-bot challenge / next.js/react/vue bundle”等。
- 核心工作流改为 6 段：
  `Recon` → `Artifact Harvest` → `Runtime Trace` → `Deobfuscation` → `Specialized Checks` → `Flag/Proof Output`。
- `Recon` 要求默认检查：
  `Network`、`Sources`、`Application`、`Console`、框架指纹、`.map`、`.wasm`、`sw.js`、storage、cookies、indexedDB、cache storage。
- `Artifact Harvest` 要求默认收集：
  主 bundle、懒加载 chunk、source map、wasm、service worker 脚本、GraphQL endpoint、SSE/WebSocket、初始化配置对象、内联脚本。
- `Runtime Trace` 统一走 MCP：
  优先 `js-reverse` 风格 hook/initiator tracing；补充 `jshook` 的 `collect_code`、`search_in_scripts`、`source_map_extract`、`manage_hooks`、`js_bundle_search`、流式监控能力。
- `Specialized Checks` 细分为独立子剧本：
  `source-map recovery`、`wasm inspect/decompile`、`service-worker/cache analysis`、`GraphQL schema discovery`、`storage/token tracing`、`CSP/client restriction analysis`、`anti-bot/client fingerprint checks`。
- 输出契约改成 CTF 风格：
  必须输出“疑似 flag/验证路径/触发条件/关键证据/下一步动作”；如果没拿到 flag，也要给“最可能突破点”和“复现实验指令”。
- references 设计：
  用短文档拆分，不把全部规则塞进 `SKILL.md`。建议最少包括 `workflow.md`、`artifact-checklist.md`、`wasm.md`、`source-maps.md`、`service-workers.md`、`graphql.md`、`output-contract.md`。
- 可选 scripts：
  只放高复用、确定性强的辅助脚本，例如 bundle 关键词扫描模板、source map 提取包装、flag 关键词批量搜索模板；不放一次性示例堆砌。
- 与现有 `js-reverse` 的关系：
  在新 skill 中明确写“遇到签名链、补环境、复杂 hook 采样、VMP/深度 AST 去混淆时，回退读取现有 `js-reverse` references”，保持职责边界。

## Public Interfaces / Types

- `SKILL.md` frontmatter：
  `name: modern-web-ctf`
  `description:` 明确说明适用于现代浏览器型 CTF 与前端题，不覆盖传统纯后端 Web 漏洞利用。
- 统一任务输入模板：
  最少定义 `url`、`goal`、`known_keywords`、`suspected_artifacts`、`allowed_actions`、`auth_state`。
- 统一输出模板：
  最少定义 `target surface`、`collected artifacts`、`runtime findings`、`suspected flag path`、`proof/evidence`、`next step`、`confidence`。
- MCP 约定：
  默认工具组合写死为 `js-reverse + jshook + 自带 shell/js_repl`，并标注“优先浏览器观察，不先猜算法”。

## Test Plan

- 用 3 类题型做 skill 验证：
  `obfuscated bundle + source map`
  `wasm flag checker`
  `service worker / cache / storage` 类浏览器题
- 每类验证至少检查：
  skill 是否能把用户引导到正确的首轮侦察点；
  是否会优先收集关键 artifact；
  是否会产出明确下一步，而不是泛泛而谈。
- 验收标准：
  首轮响应能在 1 次技能调用内给出可执行的检查顺序；
  能覆盖 `source map / wasm / service worker` 三个现代面；
  输出中必须带证据导向字段，而不是只有策略口号。
- 负例验证：
  传统 SQLi/SSRF/文件上传类题不应强触发该 skill，避免误路由。

## Assumptions

- 默认新建 skill，不直接替换现有 `js-reverse`。
- 默认目标是 CTF/实验环境，不面向真实站点未授权利用。
- 默认优先“拿到 flag 或证明路径”，不优先做长期维护型本地补环境工程。
- 默认另一个 MCP 选 `jshook`，因为它对 bundle 搜索、source map、runtime hook、流量观测的覆盖更适合现代前端题。
- 默认保留 `js-reverse` 作为深度回退技能，而不是复制其全部内容。

## Source Anchors

- `js-reverse` 本地技能骨架：强调 observe-first / hook-first / evidence-first，并已有 references 可复用。
- Grok MCP 外部结论：现代浏览器型 CTF 高频面集中在 obfuscated JS、Wasm、source map、service worker、GraphQL、CSP、anti-bot。
- `jshook` MCP 工具面：已检出 `js_bundle_search`、`search_in_scripts`、`collect_code`、`source_map_extract`、`manage_hooks`、`ws_monitor_enable`、`sse_monitor_enable`，适合作为新 skill 的第二 MCP。

## External Links

- LA CTF 2025 writeups: https://sylvie.fyi/posts/lactf-2025/
- strellic CTF challenges: https://github.com/strellic/my-ctf-challenges
- Jorian Woltjer JavaScript notes: https://book.jorianwoltjer.com/languages/javascript
- HackTricks service worker abuse: https://hacktricks.wiki/en/pentesting-web/xss-cross-site-scripting/abusing-service-workers.html
- Tenable WebAssembly CTF challenge notes: https://medium.com/tenable-techblog/coding-a-webassembly-ctf-challenge-5560576e9cb7
