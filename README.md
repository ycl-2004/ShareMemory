<div align="center">

# ShareMemory

[English](README.md) | [中文](README.zh.md)

> *Your agents forget everything between sessions - and they have never met each other.*

**Project-scoped shared memory for AI coding agents,
packaged as a single skill that works in both Claude Code and Codex.**

[![CI](https://github.com/ycl-2004/ShareMemory/actions/workflows/ci.yml/badge.svg)](https://github.com/ycl-2004/ShareMemory/actions/workflows/ci.yml) [![skills.sh](https://skills.sh/b/ycl-2004/ShareMemory)](https://skills.sh/ycl-2004/ShareMemory/share-memory) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Claude Code](https://img.shields.io/badge/Claude%20Code-supported-blue?logo=claude&logoColor=white)](https://code.claude.com/docs/en/skills) [![Codex](https://img.shields.io/badge/Codex-supported-10a37f?logo=openai&logoColor=white)](https://developers.openai.com/codex/skills) [![Protocol](https://img.shields.io/badge/protocol-v1.1-informational)](templates/project/MEMORY_PROTOCOL.md) [![Dependencies](https://img.shields.io/badge/dependencies-none-success)](#requirements) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](#contributing)

**One `AI_MEMORY/` folder turns isolated Claude Code and Codex sessions into a shared, linted project handoff loop.**

[See it run](#see-it-in-action) · [Install](#30-second-quick-start) · [Use it daily](#daily-usage) · [Design details](PROJECT_DETAILS.md) · [Verify it](#verification) · [Safety](#conflict--safety-rules)

</div>

---

Claude Code and Codex do not share context. When both agents work in the same repository, each is blind to the other's decisions, and every new session starts from zero. ShareMemory solves this with a **file-based single source of truth** (`AI_MEMORY/`) inside each project: both agents are bound by the same protocol to read it on startup and write to it as they work — so each agent always sees what the other one did.

## See It in Action

<div align="center">
<img src="assets/demo.gif" width="760" alt="Terminal replay: ShareMemory initializes a demo project, writes Claude's handoff to AI_MEMORY, runs the memory lint, and shows Codex reading the latest handoff.">
</div>

This GIF is generated from a real local replay: [`assets/demo.sh`](assets/demo.sh) creates a throwaway project from the templates, writes a Claude handoff, then runs `scripts/check_memory.sh` before showing what Codex reads on startup. Re-record with [`assets/demo.tape`](assets/demo.tape) if you use VHS, or regenerate the checked-in GIF on macOS with `swift assets/render-demo-gif.swift`.

## 30-Second Quick Start

Recommended for this project: install one repo-local copy for Codex, then expose the same copy to Claude Code.

```bash
# Run inside the repo where you want both agents to use ShareMemory
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
mkdir -p .claude/skills
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

Codex reads repo skills from `.agents/skills/`. Claude Code reads project skills from `.claude/skills/`. The symlink keeps both agents on the same ShareMemory code in that repo.

Or install manually without Node.js:

```bash
mkdir -p .agents/skills .claude/skills
git clone https://github.com/ycl-2004/ShareMemory .agents/skills/share-memory
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

Then open that repo in Claude Code or Codex and say **`init memory`**. Open the same folder with the other agent and it will read the same `AI_MEMORY/` state instead of starting from zero.

**Verify it worked** — after `init memory`, paste this into either agent:

> memory status

Expected: a status report showing protocol version, language, git setting, and the init log entry.

MIT licensed. No runtime dependencies. One skills.sh-backed project install command, one git fallback. One shared memory per repo.

<details>
<summary><b>📄 What actually got written that Monday (click to expand)</b></summary>

```markdown
<!-- AI_MEMORY/DECISIONS.md -->
### [2026-06-12 14:32] [Claude] Next.js over Vite
SSR required for marketing pages; Vite SPA cannot provide it.

<!-- AI_MEMORY/SYNC_LOG.md -->
## 2026-06-12
- [14:32] [Claude] [DECISIONS.md] switched build to Next.js (SSR)
- [15:10] [Claude] [TASKS.md] scaffolded app router; auth pending
```

Tuesday's boot sequence reads exactly these lines — that's the entire trick. No server, no embeddings, no magic: just files both agents are bound to.

</details>

<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/architecture-dark.svg">
  <img src="assets/architecture-light.svg" alt="ShareMemory closed-loop architecture: the skill folder is the program, installed once per platform; each project holds exactly one AI_MEMORY shared brain that both agents read on boot and write to as they work." width="700">
</picture>
</div>

> **Design principle** — there is exactly **one** copy of the memory per project. No merging, no sync layer, no split brain: an entry written by one agent is, byte for byte, what the other agent reads.

## Features

| | Feature | Description |
|---|---|---|
| 🧠 | **One shared brain per project** | Both agents read/write the same `AI_MEMORY/` files — communication is guaranteed by "must read on boot, must update the daily handoff" |
| 🔁 | **Daily handoff loop** | Each day has one `SYNC_LOG.md` block; every boot reads the latest 1-2 blocks to see what changed |
| ✍️ | **Auto + manual writes** | Decisions, rule changes, handoff-critical task state, and confirmed reusable lessons are automatic; routine cleanup uses `"update memory"` |
| 🪶 | **Token-frugal by design** | Tiered startup (~a few hundred tokens), telegraphic entries (≤3 lines), 5-entry caps, progressive summarization into Long-Term Memory |
| 🔍 | **Built-in lint** | `check_memory.sh` validates entry caps, daily log shape, header format, and scans for leaked secrets |
| 🔒 | **Lightweight write lock** | `AI_MEMORY/.write.lock` prevents accidental overlapping memory writes without adding a database |
| 🗃️ | **Git recovery layer (opt-in)** | Asked once during init; commits `AI_MEMORY/` history so overwritten content is always recoverable |
| 🔌 | **Agent-agnostic protocol** | Adding a third agent = one boot file pointing at `MEMORY_PROTOCOL.md` |
| 📦 | **Zero dependencies** | Plain Markdown + one bash script; no downloads, no network access, never modifies your system |

## Why Not Just…

| | 🧠 ShareMemory | 📋 Re-explaining in every prompt | 🗄️ Vector-DB memory frameworks |
|---|---|---|---|
| Setup | `git clone` + `init memory` | nothing | server + embeddings + API keys |
| Cross-vendor (Anthropic + OpenAI) | ✅ same plain files | 😓 you are the sync layer | ⚠️ per-framework SDK |
| Dependencies | **zero** | zero | database, SDK, network |
| Token cost per session | ~a few hundred | grows with your patience | retrieval + prompt overhead |
| Human-readable & auditable | ✅ Markdown in your repo, git-diffable | ❌ lives in chat scrollback | ❌ opaque store |
| Decisions survive context loss | ✅ | ❌ | ✅ |
| Right-sized for 2–4 coding agents | ✅ built exactly for this | ❌ | overkill |

ShareMemory deliberately stays small: it's not a memory database, it's a **handoff protocol**. Files your agents are bound to, in the repo you already have.

## Install Options

The `skills` CLI installs to the current project by default. Do not pass `--global` for the recommended flow: ShareMemory is meant to be repo/project-scoped so the skill version, boot files, and `AI_MEMORY/` protocol are reviewed with that project.

Global install can be useful for a private machine where you want a personal default available everywhere, but it is not the documented path because collaborators and the other agent environment may not have the same global copy.

### Optional: personal global install

Use this when you personally want to run `init memory` in many projects without installing the skill into each repo first. The skill is global; the memory it creates is still local to each project.

```bash
mkdir -p ~/.claude/skills ~/.agents/skills
git clone https://github.com/ycl-2004/ShareMemory ~/.claude/skills/share-memory
ln -sfn ~/.claude/skills/share-memory ~/.agents/skills/share-memory
```

Then open any project and say:

> init memory

ShareMemory will initialize that current project by creating `AI_MEMORY/`, `MEMORY_PROTOCOL.md`, `AGENTS.md`, `CLAUDE.md`, and `scripts/check_memory.sh` there. Update the global install with:

```bash
git -C ~/.claude/skills/share-memory pull --ff-only
```

### Recommended: Codex + Claude Code in one repo

Install one canonical project copy for Codex, then point Claude Code at the same folder:

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
mkdir -p .claude/skills
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

Run it from the repo that should carry the skill. This uses the live skills.sh skill route for [`share-memory`](https://skills.sh/ycl-2004/ShareMemory/share-memory). `--skill` makes the target explicit, `--agent codex` writes the repo-local Codex path `.agents/skills/share-memory`, `--copy` avoids a dangling source symlink, and `--yes` keeps the install non-interactive.

The symlink exposes that same repo-local copy to Claude Code via `.claude/skills/share-memory`, so both agents read one installed skill inside the project.

### Codex only

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
```

This creates:

```text
.agents/skills/share-memory/SKILL.md
```

Codex also supports user-level skills under `$HOME/.agents/skills`, but ShareMemory is designed for project handoffs, so the repo-local path is the safer default.

### Claude Code only

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent claude-code --copy --yes
```

This creates:

```text
.claude/skills/share-memory/SKILL.md
```

Claude Code also supports personal skills under `~/.claude/skills/`, but this README uses project skills so every collaborator in the repo gets the same protocol.

### Manual install without Node.js

Shared copy for Codex + Claude Code:

```bash
mkdir -p .agents/skills .claude/skills
git clone https://github.com/ycl-2004/ShareMemory .agents/skills/share-memory
ln -s ../../.agents/skills/share-memory .claude/skills/share-memory
```

Prefer fully separate copies?

```bash
# Claude Code
git clone https://github.com/ycl-2004/ShareMemory .claude/skills/share-memory

# Codex
git clone https://github.com/ycl-2004/ShareMemory .agents/skills/share-memory
```

Remember to `git pull` both copies when updating. For a single Claude Code project only, clone into `.claude/skills/share-memory`.

## Updating ShareMemory

The update path depends on how the skill was installed.

### If you installed with `npx skills add --copy`

`--copy` creates a project-local copy of the skill, not a git checkout. To update it, rerun the same install command from the target repo. The Claude symlink can stay in place.

Codex + Claude Code shared copy:

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
mkdir -p .claude/skills
ln -sfn ../../.agents/skills/share-memory .claude/skills/share-memory
```

Codex only:

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
```

Claude Code only:

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent claude-code --copy --yes
```

After updating, ask either agent:

> memory status

It should report the current protocol version and recent handoff state.

### If you installed with `git clone`

Pull the cloned skill directory. For the recommended shared install, only the canonical Codex copy needs a pull:

```bash
git -C .agents/skills/share-memory pull --ff-only
```

If you cloned separate Codex and Claude Code copies, update both:

```bash
git -C .agents/skills/share-memory pull --ff-only
git -C .claude/skills/share-memory pull --ff-only
```

## Daily Usage

| Command | Use it when |
|---|---|
| `init memory` | First time in a project. Creates protocol files, boot files, lint script, and empty `AI_MEMORY/`. |
| `update memory` | Record task progress for the next agent. |
| `memory status` | See current project state and what the other agent changed recently. |
| `consolidate memory` | Compress stale or duplicated memory while keeping startup cost stable. |
| `repair memory` | Fix drift: missing `@AGENTS.md` import, duplicate/broken marker blocks, missing files. |

These phrases trigger the skill implicitly on both platforms. In Codex you can also invoke it explicitly by typing `$share-memory` (or by finding `share-memory` via `/skills`, depending on the client). Claude Code picks it up automatically from the skill description. `AI_MEMORY/` is only the per-project data folder created by init; the skill id is `share-memory`.

During init, the skill asks two questions: memory language (中文 / English / bilingual) and whether to enable the git recovery layer. Existing `CLAUDE.md` / `AGENTS.md` files are never overwritten — ShareMemory content lives in a bounded `<!-- SHAREMEMORY:START/END -->` marker block that init inserts or replaces (with a backup), so repeated runs stay clean. `CLAUDE.md` follows [Anthropic's recommended pattern](https://code.claude.com/docs/en/memory): one `@AGENTS.md` import plus Claude-specific notes, so the shared rules exist in exactly one place.

## Write Cadence

ShareMemory uses the existing files as a small routing system. Do not add new memory files for normal work.

| When this changes | Update |
|---|---|
| Project goal, scope, architecture, workflow, install path, or public contract | `PROJECT.md` and/or `DECISIONS.md` immediately |
| Skill behavior, memory protocol, rule/schema, boot template, lint gate, or install/publish contract | `DECISIONS.md`; refresh `PROJECT.md` if startup would be stale |
| Accepted dependency, tooling, publishing, or integration decision | `DECISIONS.md` immediately |
| Active task needs a next action, blocker, owner, continuation state, or completion state | `TASKS.md` automatically before handoff; routine cleanup via `update memory` |
| Confirmed bug cause, validation trap, release gotcha, or repeated failure mode | `LEARNINGS.md` automatically if it would save a future agent time |
| Milestone/release completed, task crossed sessions, or old facts were archived | Refresh `PROJECT.md` Long-Term Memory |
| Only today's handoff changed | One compact `SYNC_LOG.md` bullet |

If none of those apply, skip durable memory. The goal is not to remember more; it is to keep the next project agent from repeating work or missing current constraints.

## What `init` adds to your project

| File | Purpose | Written |
|---|---|---|
| `MEMORY_PROTOCOL.md` | The shared rule set both agents follow | once |
| `AGENTS.md` | Shared agent-neutral boot rules (Codex reads natively; Claude imports it) | managed marker block |
| `CLAUDE.md` | `@AGENTS.md` import + Claude-only notes (incl. auto-memory policy) | managed marker block |
| `scripts/check_memory.sh` | Post-write lint + secrets scan | once |
| `AI_MEMORY/CONFIG.md` | Language, git choice, protocol version | on init |
| `AI_MEMORY/PROJECT.md` | Overview, architecture, **Long-Term Memory** (distilled current state) | auto, on structural change |
| `AI_MEMORY/DECISIONS.md` | Decisions and dependency changes (max 5) | **auto** |
| `AI_MEMORY/TASKS.md` | Active and recently completed tasks | auto for handoff-critical state; manual cleanup |
| `AI_MEMORY/LEARNINGS.md` | Lessons worth keeping (max 5) | auto for confirmed reusable lessons; manual curation |
| `AI_MEMORY/SYNC_LOG.md` | Daily handoff blocks — how the agents see each other without noisy per-write logs | every write session |
| `AI_MEMORY/archive/` | Overflowed entries and old logs | on overflow |

Durable entries are signed `[YYYY-MM-DD HH:MM] [Claude|Codex]` with real system time. `SYNC_LOG.md` keeps at most one block per date, with compact bullets for that day's handoff. When a memory file exceeds its cap, the oldest content is distilled into Long-Term Memory or archived — the same progressive-summarization pattern used by agent-memory systems such as MemGPT/Letta.

## Repo Source vs. Project State

This repository contains the **skill package** (templates, protocol, scripts, assets). When you run `init memory` in a target project, only a subset is copied there:

```
ShareMemory repo (this repo)          Your project after init
─────────────────────────────         ────────────────────────
SKILL.md           ← skill itself     (not copied — stays installed)
templates/project/ ← master copies    MEMORY_PROTOCOL.md
                    copied on init →  AGENTS.md (marker block)
                                      CLAUDE.md (marker block)
                                      scripts/check_memory.sh
templates/memory/  ← master copies    AI_MEMORY/CONFIG.md
                    copied on init →  AI_MEMORY/PROJECT.md
                                      AI_MEMORY/DECISIONS.md
                                      AI_MEMORY/TASKS.md
                                      AI_MEMORY/LEARNINGS.md
                                      AI_MEMORY/SYNC_LOG.md
                                      AI_MEMORY/archive/
assets/            ← visuals          (not copied — repo-only)
examples/          ← examples         (not copied — repo-only)
.claude-plugin/    ← marketplace      (not copied — repo-only)
```

The `AI_MEMORY/`, `AGENTS.md`, `CLAUDE.md`, and `scripts/check_memory.sh` at the **root of this repository** are purely local test state from developing ShareMemory itself — they are NOT part of the published package. The real templates live under `templates/`.

## Verification

The public CI matrix is intentionally template-focused: it builds a throwaway project from `templates/`, runs the memory lint, then proves the lint catches the failure modes that matter most.

| Check | What it proves |
|---|---|
| Full template project | Fresh `init` output is lint-clean |
| Missing `AGENTS.md` / `CLAUDE.md` | Broken boot layers fail loudly |
| Duplicate or unbalanced markers | Repeated/partial marker edits are detected |
| Missing `@AGENTS.md` import | Claude cannot drift away from shared rules silently |
| Secret-like memory content | Credentials are blocked from `AI_MEMORY/` |
| Protocol mismatch | Older initialized projects are routed to `migrate memory` |
| Demo replay | The public demo creates real files and passes `check_memory.sh` |

Run the visible replay locally:

```bash
bash assets/demo.sh
```

Expected final line:

```text
Result: Codex starts with Claude handoff instead of a blank slate.
```

## Conflict & Safety Rules

- **User instructions always win** over memory, but the agent must point out the conflict and confirm before proceeding — then update memory. Neither side is ever silently overridden.
- **Read-only instructions pause auto-write** — if you say "do not modify anything", "read-only audit", or "only write the report", agents must not write `AI_MEMORY/` even when normal auto-write rules would apply. They should say memory was not updated because of your restriction.
- **Memory is not a diary** — write only facts that change what a future agent should do; raw reasoning, guesses, verbose logs, and obvious code details stay out.
- **Secrets never enter memory** — API keys, credentials, tokens, and private URLs are forbidden and linted for.
- **Do not run both agents simultaneously** on one project. A lightweight lock prevents accidental overlap, and the optional git layer recovers anything that still gets overwritten.
- **Corrections, not edits** — closed daily blocks are immutable; past mistakes are fixed by a `[correction]` bullet in today's block (plus a `supersedes` entry in current views), never by rewriting history.
- **Agent-private memory stays private** — Claude Code's machine-local auto memory is fine for its own learning, but cross-agent decisions must land in `AI_MEMORY/`; the Claude boot notes enforce this.
- **Publishing a public repository?** `AI_MEMORY/` contains your project's internal decisions and plans. Secrets are linted out, but consider adding `AI_MEMORY/` to `.gitignore` if that context should stay private.

## Requirements

**Nothing to install.** The skill is plain Markdown plus one bash script; `init` only copies template files.

| Dependency | Needed for | If missing |
|---|---|---|
| bash + coreutils (`grep`, `awk`, `wc`, `date`, `sort`, `uniq`) | lint script, timestamps | Preinstalled on macOS/Linux; Windows via WSL or Git Bash |
| git *(optional)* | recovery layer for `AI_MEMORY/` history | Everything still works; you lose overwrite recovery |

The skill never auto-installs software. During init it *asks* whether to enable git, records the choice in `CONFIG.md`, and only ever runs `git init` with explicit permission.

## Chinese README

中文说明、安装路径和日常用法见 [README.zh.md](README.zh.md)。

## FAQ

<details>
<summary><b>Why plain files instead of a database?</b></summary>

Because the agents already speak Markdown, your repo already versions files, and you can already read them. A database adds a dependency, hides the memory from code review, and solves a scale problem this use case doesn't have. At 2–4 agents on one project, the bottleneck is discipline, not storage — which is why ShareMemory is mostly *protocol* (admission rules, daily handoff blocks, write lock, lint) rather than infrastructure.

</details>

<details>
<summary><b>What happens if both agents write at the same time?</b></summary>

A lightweight lock (`AI_MEMORY/.write.lock`, atomic `mkdir`) prevents accidental overlap: the second writer stops, reports who holds the lock and for how long, and never deletes another agent's lock without your confirmation. It's a guardrail, not a parallel-collaboration system — the protocol still says don't run both agents on one project simultaneously, and the optional git layer recovers anything that slips through.

</details>

<details>
<summary><b>How much of my context window does this burn?</b></summary>

A few hundred tokens per session. Startup reads only three things: `CONFIG.md`, the ≤30-line Long-Term Memory section, and the latest 1–2 daily handoff blocks. Everything else loads on demand. Hard caps (5 entries per file, 15 bullets per day, 7 daily blocks) plus progressive summarization into Long-Term Memory keep that figure flat no matter how long the project runs.

</details>

<details>
<summary><b>Can I add Cursor or another agent?</b></summary>

Yes — the protocol is agent-agnostic. Add one boot file for the new agent (its equivalent of `CLAUDE.md`/`AGENTS.md`) that declares an `AGENT_NAME` and points at `MEMORY_PROTOCOL.md`. Everything else — entry format, locks, daily blocks, lint — already works. PRs adding boot files for other agents are very welcome.

</details>

<details>
<summary><b>What if an agent writes something wrong into memory?</b></summary>

History is never rewritten. Closed daily blocks are immutable; mistakes are fixed with a `[correction]` bullet in today's block pointing at the wrong entry, plus a `supersedes` entry in the current-view files. Wrong facts get explicitly corrected — never silently worked around — so the correction itself becomes part of the handoff.

</details>

## Contributing

Issues and pull requests are welcome — especially additional agent boot files (Cursor, etc.), migration helpers, stronger lockfile handling, and CI integration for `check_memory.sh`.

## Acknowledgements

ShareMemory builds on the plain-file agent-instructions pattern popularized by [AGENTS.md](https://agents.md/), Claude Code's [`CLAUDE.md` memory/import model](https://code.claude.com/docs/en/memory), and Codex's [skills packaging model](https://developers.openai.com/codex/skills). The memory discipline is intentionally much smaller than platform memory systems such as [Letta](https://github.com/letta-ai/letta): this project is a repo-local handoff protocol, not a database.

## License

[MIT](LICENSE) © 2026 yc星辰

---

<div align="center">

**⭐ If ShareMemory keeps your agents on the same page, consider a star — it helps other multi-agent developers find it.**

*Built for the day your second AI agent walked into the repo and broke everything the first one decided.*

</div>
