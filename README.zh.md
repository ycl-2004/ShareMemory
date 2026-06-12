<div align="center">

# ShareMemory

[English](README.md) | [中文](README.zh.md)

> *你的 Agent 每次开新会话都会失忆；而且它们彼此从来没见过。*

**给 Claude Code + Codex 共用的项目级共享记忆协议。**

[![CI](https://github.com/ycl-2004/ShareMemory/actions/workflows/ci.yml/badge.svg)](https://github.com/ycl-2004/ShareMemory/actions/workflows/ci.yml) [![skills.sh](https://skills.sh/b/ycl-2004/ShareMemory)](https://skills.sh/ycl-2004/ShareMemory/share-memory) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Claude Code](https://img.shields.io/badge/Claude%20Code-supported-blue?logo=claude&logoColor=white)](https://code.claude.com/docs/en/skills) [![Codex](https://img.shields.io/badge/Codex-supported-10a37f?logo=openai&logoColor=white)](https://developers.openai.com/codex/skills) [![Protocol](https://img.shields.io/badge/protocol-v1.1-informational)](templates/project/MEMORY_PROTOCOL.md) [![Dependencies](https://img.shields.io/badge/dependencies-none-success)](#要求)

**一个 `AI_MEMORY/` 文件夹，让 Claude Code 和 Codex 在同一个项目里读同一份状态、交接同一批决策。**

[看 Demo](#看-demo) · [30 秒安装](#30-秒安装) · [安装](#安装) · [日常用法](#日常用法) · [项目详解](项目详解.md) · [验证](#验证) · [安全规则](#冲突与安全规则)

</div>

---

Claude Code 和 Codex 默认不共享上下文。一个 Agent 刚做完架构决策，另一个 Agent 打开同一个仓库时仍然像从零开始。ShareMemory 在项目里创建一套可读、可 lint、可恢复的 `AI_MEMORY/` 文件，让两个 Agent 启动时读同一份状态，完成工作后写同一份交接。

## 看 Demo

<div align="center">
<img src="assets/demo.gif" width="760" alt="终端回放：ShareMemory 初始化 demo 项目，写入 Claude 交接记录，运行 memory lint，然后展示 Codex 读取最新交接。">
</div>

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

## 安装

推荐 repo-local 安装：skill 代码在项目里，初始化后的 `AI_MEMORY/` 也在同一个项目里。

### Codex + Claude Code

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
mkdir -p .claude/skills
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

Codex 读 `.agents/skills/share-memory`；Claude Code 读 symlink 后的 `.claude/skills/share-memory`。两个 Agent 用同一份项目内 skill。

### Codex only

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
```

```text
.agents/skills/share-memory/SKILL.md
```

之后在 Codex 中可以直接说 `init memory`，也可以显式输入 `$share-memory`；如果客户端提供 `/skills`，就在里面找精确 skill id：`share-memory`。

### Claude Code only

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent claude-code --copy --yes
```

```text
.claude/skills/share-memory/SKILL.md
```

之后在 Claude Code 中直接说 `init memory`。Claude Code 会根据 skill 描述自动触发；如果你的客户端提供 skill 列表/斜杠入口，请找精确 skill id：`share-memory`，不要写成带空格的 `Share Memory`。

### 不用 Node.js / npx

同项目共享一份：

```bash
mkdir -p .agents/skills .claude/skills
git clone https://github.com/ycl-2004/ShareMemory .agents/skills/share-memory
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

### 可选：个人 global 安装

如果你只是在自己的机器上给很多项目反复 `init memory`，可以全局安装 skill。本体是 global；每个项目里的 `AI_MEMORY/` 仍然独立。

```bash
mkdir -p ~/.claude/skills ~/.agents/skills
git clone https://github.com/ycl-2004/ShareMemory ~/.claude/skills/share-memory
ln -sfn ~/.claude/skills/share-memory ~/.agents/skills/share-memory
```

更新 global 安装：

```bash
git -C ~/.claude/skills/share-memory pull --ff-only
```

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

## 自动写入哪些内容

- 架构、依赖、工具链、安装或发布契约变化 → `DECISIONS.md`。
- 项目方向、工作流或启动摘要变化 → `PROJECT.md`。
- 需要交接的任务状态 → `TASKS.md`。
- 已验证、以后还会踩到的坑 → `LEARNINGS.md`。
- 已完成工作 → 今天的 `SYNC_LOG.md` block。

不会改变未来 Agent 行为的内容，不应该写成长期记忆。

## 验证

| 检查 | 证明什么 |
|---|---|
| `bash assets/demo.sh` | Demo 创建真实文件并通过 memory lint |
| `bash scripts/check_memory.sh` | 当前项目 memory 有效 |
| CI | 模板、boot、协议和 secret scan 有效 |

本地运行：

```bash
bash assets/demo.sh
bash scripts/check_memory.sh
```

## 冲突与安全规则

- 用户指令永远优先于 memory，但 Agent 必须指出冲突，不能静默覆盖。
- 用户说“只读”“不要修改”“只写报告”时，自动写 memory 暂停。
- memory 不是日记：不写推理过程、聊天全文、大段日志、secrets、token、API key 或私有 URL。
- 不要同时让两个 Agent 并发写同一个项目；写锁只是防误操作，不是实时协作系统。
- 公开仓库前，请确认是否应该把项目自己的 `AI_MEMORY/` 放进 `.gitignore`。

## 要求

ShareMemory 初始化后的项目只依赖这些系统工具：

| 依赖 | 用途 | 缺失时 |
|---|---|---|
| bash + coreutils | lint、时间戳、文件检查 | macOS/Linux 默认有；Windows 用 WSL 或 Git Bash |
| git，可选 | `AI_MEMORY/` 恢复层 | 不启用也能用，只是少一层恢复历史 |
| Node.js，可选 | `npx skills add` 安装 | 没有 Node 就用 git clone 安装 |

ShareMemory 不会自动安装依赖。初始化时如果要启用 git recovery layer，它会先问你。

## 更多说明

完整设计和取舍见 [项目详解.md](项目详解.md)，英文版见 [PROJECT_DETAILS.md](PROJECT_DETAILS.md)。

## License

[MIT](LICENSE) © 2026 yc星辰
