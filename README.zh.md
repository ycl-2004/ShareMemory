<div align="center">

# ShareMemory

[English](README.md) | [中文](README.zh.md)

> *你的 Agent 每次开新会话都会失忆；而且它们彼此从来没见过。*

**给 Claude Code + Codex 共用的项目级共享记忆协议。**

[![CI](https://github.com/ycl-2004/ShareMemory/actions/workflows/ci.yml/badge.svg)](https://github.com/ycl-2004/ShareMemory/actions/workflows/ci.yml) [![skills.sh](https://skills.sh/b/ycl-2004/ShareMemory)](https://skills.sh/ycl-2004/ShareMemory/share-memory) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Claude Code](https://img.shields.io/badge/Claude%20Code-supported-blue?logo=claude&logoColor=white)](https://code.claude.com/docs/en/skills) [![Codex](https://img.shields.io/badge/Codex-supported-10a37f?logo=openai&logoColor=white)](https://developers.openai.com/codex/skills) [![Protocol](https://img.shields.io/badge/protocol-v1.1-informational)](templates/project/MEMORY_PROTOCOL.md) [![Dependencies](https://img.shields.io/badge/dependencies-none-success)](#要求)

**一个 `AI_MEMORY/` 文件夹，让 Claude Code 和 Codex 在同一个项目里读同一份状态、交接同一批决策。**

[看 Demo](#看-demo) · [30 秒安装](#30-秒安装) · [Codex--Claude-Code-安装说明](#codex--claude-code-安装说明) · [日常用法](#日常用法) · [项目详解](项目详解.md) · [验证](#验证) · [安全规则](#冲突与安全规则)

</div>

---

Claude Code 和 Codex 默认不共享上下文。一个 Agent 刚做完架构决策，另一个 Agent 打开同一个仓库时仍然像从零开始。ShareMemory 解决的是这个交接问题：它在项目里创建一套可读、可 lint、可恢复的 `AI_MEMORY/` 文件，让两个 Agent 启动时必须读、完成工作后必须写。

ShareMemory 不是数据库，也不是聊天记录归档。它是一套小而硬的项目协议：启动规则、每日交接、写锁、记忆压缩、冲突修复、迁移检查，全都放在普通 Markdown 和一个 bash lint 脚本里。

## 看 Demo

<div align="center">
<img src="assets/demo.gif" width="760" alt="终端回放：ShareMemory 初始化 demo 项目，写入 Claude 交接记录，运行 memory lint，然后展示 Codex 读取最新交接。">
</div>

这个 GIF 来自真实本地回放：[`assets/demo.sh`](assets/demo.sh) 会从模板创建临时项目，写入一条 Claude handoff，然后运行 `scripts/check_memory.sh`，最后展示 Codex 启动时读到什么。用 VHS 可重录 [`assets/demo.tape`](assets/demo.tape)，macOS 上也可以用 `swift assets/render-demo-gif.swift` 重新生成 GIF。

## 30 秒安装

推荐方式：在目标项目里放一份 repo-local skill，让 Codex 和 Claude Code 共用同一份 ShareMemory 代码。

```bash
# 在你想让两个 Agent 共用记忆的项目根目录运行
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
mkdir -p .claude/skills
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

然后在 Claude Code 或 Codex 里打开这个项目，说：

```text
init memory
```

初始化后，再让任意一个 Agent 运行：

```text
memory status
```

预期结果：它会显示协议版本、语言、git 设置，以及最近的 `SYNC_LOG.md` 交接记录。

## Codex / Claude Code 安装说明

### 为什么推荐 repo-local

ShareMemory 的目标是“这个仓库里的 Agent 共享这个仓库的状态”。所以默认不要装成全局 skill，也就是不要加 `--global`。项目内安装的好处是：

| 路径 | 给谁读 | 适合什么 |
|---|---|---|
| `.agents/skills/share-memory` | Codex | 这个项目的 Codex skill |
| `.claude/skills/share-memory` | Claude Code | 这个项目的 Claude Code skill |
| `AI_MEMORY/` | 两者都读写 | 这个项目的共享记忆 |

官方路径上，Codex 会扫描 repo 里的 `.agents/skills`；Claude Code 会扫描项目里的 `.claude/skills`。所以最稳的方式是：把真实代码放在 `.agents/skills/share-memory`，再让 `.claude/skills/share-memory` 指向它。

不建议把 ShareMemory 作为默认 `--global` 安装路径。这个项目解决的是 repo/project 里的跨 Agent 交接，项目内安装能让 skill 版本、boot 文件和 `AI_MEMORY/` 协议跟着这个 repo 一起被审查。global 可以作为个人机器上的临时便利，但团队和另一个 Agent 环境不一定有同一份全局副本，容易产生漂移。

### 可选：个人 global 安装

如果你只是自己在很多项目里反复用 ShareMemory，可以把 skill 放到全局 skills folder。注意：global 的只是 skill 本体；它初始化出来的 `AI_MEMORY/` 仍然是每个项目各自一套。

```bash
mkdir -p ~/.claude/skills ~/.agents/skills
git clone https://github.com/ycl-2004/ShareMemory ~/.claude/skills/share-memory
ln -sfn ~/.claude/skills/share-memory ~/.agents/skills/share-memory
```

之后在任意项目里说：

> init memory

ShareMemory 会在当前项目创建 `AI_MEMORY/`、`MEMORY_PROTOCOL.md`、`AGENTS.md`、`CLAUDE.md` 和 `scripts/check_memory.sh`。更新 global 安装时执行：

```bash
git -C ~/.claude/skills/share-memory pull --ff-only
```

### 同一个项目同时给 Codex + Claude Code

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
mkdir -p .claude/skills
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

结果：

```text
.agents/skills/share-memory/SKILL.md    # Codex 读取这里
.claude/skills/share-memory -> ../../.agents/skills/share-memory
```

两个 Agent 读的是同一份 ShareMemory skill，所以后续升级时只需要更新一处。

### 只给 Codex 用

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
```

结果：

```text
.agents/skills/share-memory/SKILL.md
```

之后在 Codex 中可以直接说 `init memory`，也可以显式输入 `$share-memory`；如果客户端提供 `/skills`，就在里面找精确 skill id：`share-memory`。

### 只给 Claude Code 用

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent claude-code --copy --yes
```

结果：

```text
.claude/skills/share-memory/SKILL.md
```

之后在 Claude Code 中直接说 `init memory`。Claude Code 会根据 skill 描述自动触发；如果你的客户端提供 skill 列表/斜杠入口，请找精确 skill id：`share-memory`，不要写成带空格的 `Share Memory`。

### 不想用 Node.js / npx

同项目共享一份：

```bash
mkdir -p .agents/skills .claude/skills
git clone https://github.com/ycl-2004/ShareMemory .agents/skills/share-memory
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

只给 Codex：

```bash
mkdir -p .agents/skills
git clone https://github.com/ycl-2004/ShareMemory .agents/skills/share-memory
```

只给 Claude Code：

```bash
mkdir -p .claude/skills
git clone https://github.com/ycl-2004/ShareMemory .claude/skills/share-memory
```

手动 `git clone` 安装时，升级就是进入对应目录执行 `git pull`。如果你是用 `npx skills add --copy` 安装，见下一节。

## 更新已安装的 ShareMemory

更新方式取决于你当初怎么安装。

### 如果用 `npx skills add --copy` 安装

`--copy` 会复制一份 skill 到当前项目里，不是 git checkout，所以不能直接 `git pull`。更新时，在目标 repo 里重新运行同一条安装命令即可；Claude Code 的 symlink 可以保留。

Codex + Claude Code 共用一份：

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
mkdir -p .claude/skills
ln -sfn ../../.agents/skills/share-memory .claude/skills/share-memory
```

只给 Codex：

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
```

只给 Claude Code：

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent claude-code --copy --yes
```

更新后可以问任意一个 Agent：

> memory status

它应该能显示当前协议版本、语言、git 设置和最近交接状态。

### 如果用 `git clone` 安装

推荐的共用安装只需要更新 canonical Codex copy：

```bash
git -C .agents/skills/share-memory pull --ff-only
```

如果 Codex 和 Claude Code 是两份独立 clone，就两个都更新：

```bash
git -C .agents/skills/share-memory pull --ff-only
git -C .claude/skills/share-memory pull --ff-only
```

## 它会写入什么

第一次说 `init memory` 时，ShareMemory 会在目标项目里创建或更新这些文件：

| 文件 | 作用 |
|---|---|
| `MEMORY_PROTOCOL.md` | 两个 Agent 共同遵守的记忆协议 |
| `AGENTS.md` | Agent 中立的启动规则；Codex 原生读取 |
| `CLAUDE.md` | Claude Code 的启动文件，包含 `@AGENTS.md` import |
| `scripts/check_memory.sh` | 记忆 lint + secret scan |
| `AI_MEMORY/CONFIG.md` | 语言、git 设置、协议版本 |
| `AI_MEMORY/PROJECT.md` | 项目概览和长期记忆 |
| `AI_MEMORY/DECISIONS.md` | 架构决策和依赖变更，最多 5 条 |
| `AI_MEMORY/TASKS.md` | 当前任务和最近完成任务 |
| `AI_MEMORY/LEARNINGS.md` | 可复用经验，最多 5 条 |
| `AI_MEMORY/SYNC_LOG.md` | 每日交接日志 |
| `AI_MEMORY/archive/` | 旧记忆归档 |

已有的 `AGENTS.md` / `CLAUDE.md` 不会被整文件覆盖。ShareMemory 只管理 `<!-- SHAREMEMORY:START/END -->` marker block，并在修改前生成备份。

## 日常用法

| 命令 | 什么时候用 |
|---|---|
| `init memory` | 第一次在项目里启用 ShareMemory |
| `memory status` | 查看当前记忆状态和另一个 Agent 最近改了什么 |
| `update memory` | 手动整理日常任务进展；交接关键状态会自动记录 |
| `consolidate memory` | 压缩旧记忆，保持启动成本稳定 |
| `repair memory` | 修复 marker、boot 文件、Claude import 等漂移 |
| `migrate memory` | 协议版本变化后迁移旧项目 |

典型流程：

```text
Claude Code: init memory
Claude Code: 做架构决策并写入 DECISIONS.md / SYNC_LOG.md
Codex: 启动后读取 AI_MEMORY/CONFIG.md、PROJECT.md、SYNC_LOG.md
Codex: 继续任务，不再重复问一遍背景
```

名字边界：`share-memory` 是 skill id；ShareMemory / Share Memory 是人类可读名称；`AI_MEMORY/` 只是 `init memory` 在每个项目里创建的共享记忆文件夹。

## 写入节奏

ShareMemory 把已有文件当成一套路由系统使用。普通项目工作不需要新增 memory 文件。

| 发生了什么变化 | 应该更新哪里 |
|---|---|
| 项目目标、范围、架构、工作流、安装路径或公开契约变化 | 立即更新 `PROJECT.md` 和/或 `DECISIONS.md` |
| Skill 行为、memory 协议、规则/schema、boot 模板、lint gate、安装/发布契约变化 | 写入 `DECISIONS.md`；如果启动摘要会过期，刷新 `PROJECT.md` |
| 依赖、工具链、发布、集成方案被正式决定 | 立即更新 `DECISIONS.md` |
| 当前任务需要下一步、阻塞点、负责人、延续状态或完成状态 | 交接前自动写入 `TASKS.md`；日常整理再用 `update memory` |
| 确认了 bug 原因、验证陷阱、发布踩坑或重复失败模式 | 会帮未来 Agent 省时间时，自动写入 `LEARNINGS.md` |
| 里程碑/发布完成、任务跨 session、旧事实被归档 | 刷新 `PROJECT.md` 的 Long-Term Memory |
| 只是今天交接状态变了 | 只写一条紧凑的 `SYNC_LOG.md` bullet |

如果都不符合，就不要升级成长期记忆。目标不是“记更多”，而是让下一个项目 Agent 不重复劳动、不漏掉当前约束。

## 为什么不用普通 prompt / 数据库

| | ShareMemory | 每次重新解释 | 向量数据库记忆框架 |
|---|---|---|---|
| 安装 | repo-local skill + `init memory` | 不用安装 | 服务、数据库、embedding、API key |
| 跨 Claude / Codex | 同一份 Markdown 文件 | 你手动同步 | 取决于框架 |
| 可审计 | git diff 可见 | 藏在聊天记录里 | 通常是黑盒存储 |
| 依赖 | 零运行依赖 | 零依赖 | 多服务依赖 |
| 适合场景 | 2-4 个 coding agents 交接 | 单次聊天 | 长期 agent 平台 |

ShareMemory 刻意保持小：它不是长期记忆平台，而是“项目交接协议”。

## 仓库源码 vs 初始化后的项目

这个仓库是 skill 包源码；运行 `init memory` 后，目标项目只会得到模板生成的项目状态。

```text
ShareMemory 仓库                     目标项目
────────────────────                 ─────────────────────
SKILL.md            skill 本体        不复制，留在 .agents/.claude/skills
templates/project/  模板       →      MEMORY_PROTOCOL.md
                                      AGENTS.md
                                      CLAUDE.md
                                      scripts/check_memory.sh
templates/memory/   模板       →      AI_MEMORY/*.md
assets/             demo/图片         不复制
examples/           示例             不复制
.claude-plugin/     marketplace       不复制
```

本仓库根目录里的 `AI_MEMORY/`、`AGENTS.md`、`CLAUDE.md`、`scripts/check_memory.sh` 是开发 ShareMemory 时的本地测试状态，不是发布包的一部分。

## 验证

本仓库的 CI 和本地验证覆盖这些风险：

| 检查 | 证明什么 |
|---|---|
| full template project | 新初始化项目 lint clean |
| 缺 `AGENTS.md` / `CLAUDE.md` | 启动层缺失会失败 |
| 重复 / 不平衡 marker | 重复 init 或半截写入能被抓出来 |
| 缺 `@AGENTS.md` import | Claude Code 不会悄悄脱离共享规则 |
| secret-like 内容 | API key / token 不应进入 `AI_MEMORY/` |
| protocol mismatch | 旧项目会被引导到 `migrate memory` |
| demo replay | Demo 创建真实文件并通过 lint |

本地运行：

```bash
bash assets/demo.sh
bash scripts/check_memory.sh
```

预期 demo 最后一行：

```text
Result: Codex starts with Claude handoff instead of a blank slate.
```

## 冲突与安全规则

- 用户指令永远优先于 memory，但 Agent 必须指出冲突，不能静默覆盖。
- 用户说“只读”“不要修改”“只写报告”时，自动写 memory 暂停。
- memory 不是日记，只写会改变未来 Agent 行为的事实。
- secrets、token、API key、私有 URL 禁止写入 memory。
- 不要同时让两个 Agent 并发写同一个项目；写锁只是防误操作，不是多人协作数据库。
- 关闭日期的 `SYNC_LOG.md` 不改历史；错误通过今天的 `[correction]` 记录修正。
- 公开仓库前，请确认是否应该把项目自己的 `AI_MEMORY/` 放进 `.gitignore`。

## 要求

ShareMemory 初始化后的项目只依赖这些系统工具：

| 依赖 | 用途 | 缺失时 |
|---|---|---|
| bash + coreutils | lint、时间戳、文件检查 | macOS/Linux 默认有；Windows 用 WSL 或 Git Bash |
| git，可选 | `AI_MEMORY/` 恢复层 | 不启用也能用，只是少一层恢复历史 |
| Node.js，可选 | `npx skills add` 安装 | 没有 Node 就用 git clone 安装 |

ShareMemory 不会自动安装依赖。初始化时如果要启用 git recovery layer，它会先问你。

## FAQ

<details>
<summary><b>它会不会把我的整个聊天记录写进仓库？</b></summary>

不会。协议明确禁止写 raw reasoning、聊天全文和大段日志。它只记录决策、任务状态、踩坑结论和每日交接摘要。

</details>

<details>
<summary><b>两个 Agent 同时运行会怎样？</b></summary>

不建议这么做。写入前会用 `AI_MEMORY/.write.lock` 做轻量锁；第二个写入者会停止并报告锁是谁持有、持有多久。它能防误写，但不是实时多人协作系统。

</details>

<details>
<summary><b>为什么要 project scoped，而不是全局安装？</b></summary>

因为 ShareMemory 记录的是项目状态。项目内安装可以让每个仓库有自己的协议版本、模板和记忆规则，也方便团队 review。全局安装适合个人通用工具，不适合项目交接协议。

</details>

<details>
<summary><b>可以加 Cursor / Gemini / Aider 吗？</b></summary>

可以。协议是 agent-neutral 的：给新 Agent 增加一个启动文件，让它声明自己的 `AGENT_NAME` 并指向 `MEMORY_PROTOCOL.md` 即可。`AI_MEMORY/`、写锁、lint 和 daily handoff 不需要重做。

</details>

## 参考

- [Codex skills 文档](https://developers.openai.com/codex/skills)：Codex skill 是带 `SKILL.md` 的目录，并会扫描 repo 中的 `.agents/skills`。
- [Claude Code skills 文档](https://code.claude.com/docs/en/skills)：Claude Code 支持项目内 `.claude/skills/<skill-name>/SKILL.md`。
- [`skills` CLI 文档](https://github.com/vercel-labs/skills#readme)：`--agent codex` 的项目路径是 `.agents/skills/`，`--agent claude-code` 的项目路径是 `.claude/skills/`。
- [skills.sh 文档](https://www.skills.sh/docs)：`npx skills add owner/repo` 是公开安装入口，README badge 使用 `https://skills.sh/b/owner/repo`。

## License

[MIT](LICENSE) © 2026 yc星辰
