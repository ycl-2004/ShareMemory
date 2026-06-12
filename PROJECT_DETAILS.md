# ShareMemory Project Details

> This is the long-form English design note for ShareMemory. The Chinese version is `项目详解.md`. Public quick starts live in `README.md` and `README.zh.md`; executable agent rules live in `MEMORY_PROTOCOL.md`. This file is not loaded by agents at startup.

---

## 1. The Problem

Claude Code and Codex can both work inside the same repository, but they do not share state.

That creates three recurring failures:

1. **Agent-to-agent blindness**: Claude can choose an architecture, add a dependency, or hit a test trap, and Codex will not know unless the user repeats it.
2. **Session amnesia**: even one agent starts fresh across sessions unless it re-reads the repo or the user reconstructs context by hand.
3. **No shared source of truth**: prompt-only project rules drift, get forgotten in long sessions, and are not visible in code review.

ShareMemory does not try to build a platform-level memory system. It creates a small, repo-local source of truth that both agents can read and write.

## 2. Core Idea

ShareMemory is a project handoff protocol:

- `AI_MEMORY/` stores the shared project facts.
- `AGENTS.md` gives all agents the neutral boot rule.
- `CLAUDE.md` imports `AGENTS.md` with `@AGENTS.md` and adds Claude-only notes.
- `MEMORY_PROTOCOL.md` is the day-to-day rule source after init.
- `scripts/check_memory.sh` validates memory shape after writes.

Naming boundary: `share-memory` is the skill id; ShareMemory / Share Memory is the human-readable project name; `AI_MEMORY/` is only the per-project data folder created by `init memory`.

The key move is simple: both agents already know how to read project files. If they read and write the same small set of files, project handoff becomes explicit, reviewable, and recoverable.

## 3. Distribution Model

The repository itself is the skill package. The root `SKILL.md` is intentional; do not add a nested `skills/share-memory/SKILL.md`, because that creates multiple discovered skill roots and trips the Luban package check.

Recommended install is repo/project-scoped:

```bash
npx skills add ycl-2004/ShareMemory --skill share-memory --agent codex --copy --yes
mkdir -p .claude/skills
ln -sfn ../../.agents/skills/share-memory .claude/skills/share-memory
```

That gives one canonical project copy in `.agents/skills/share-memory` and exposes the same copy to Claude Code through `.claude/skills/share-memory`.

Global install is deliberately not the default. It can be convenient on one private machine, but ShareMemory is about a specific repository's handoff state. Project-local install keeps the skill version, boot files, and memory protocol reviewable with the project.

Personal global install is still supported as a convenience pattern: put one canonical copy under `~/.claude/skills/share-memory`, symlink `~/.agents/skills/share-memory` to it, then run `init memory` inside any project. In that mode the skill is global, but every initialized project's `AI_MEMORY/` remains project-local. The trade-off is reproducibility: collaborators and other machines will not automatically have the same global skill version.

## 4. Initialized Project Shape

Running `init memory` copies only the runtime layer into the target project:

```text
Target repo
├── AGENTS.md
├── CLAUDE.md
├── MEMORY_PROTOCOL.md
├── scripts/check_memory.sh
└── AI_MEMORY/
    ├── CONFIG.md
    ├── PROJECT.md
    ├── DECISIONS.md
    ├── TASKS.md
    ├── LEARNINGS.md
    ├── SYNC_LOG.md
    └── archive/
```

Existing `AGENTS.md` and `CLAUDE.md` files are not overwritten wholesale. ShareMemory manages only the bounded `<!-- SHAREMEMORY:START/END -->` marker block and creates timestamped backups before changing boot files.

## 5. Memory Files

| File | Role | Write cadence |
|---|---|---|
| `CONFIG.md` | Language, git recovery setting, created date, protocol version | Init / migration only |
| `PROJECT.md` | Overview, architecture, conventions, Long-Term Memory | Auto when project direction, structure, or durable state changes |
| `DECISIONS.md` | Accepted architecture, dependency, tooling, install, publish, protocol, schema, boot, and lint decisions | Auto immediately |
| `TASKS.md` | Active work and recent done items | Auto for handoff-critical state; manual cleanup via `update memory` |
| `LEARNINGS.md` | Confirmed reusable lessons | Auto for validated recurring traps; manual curation/dedup |
| `SYNC_LOG.md` | Daily handoff blocks | Every memory write session and completed task |
| `archive/` | Overflow and older daily logs | Consolidation only |

The system uses existing files first. New memory files should not be added unless the protocol version changes and the user explicitly chooses that migration.

## 6. Startup Read Path

Startup stays token-cheap:

1. Read `AI_MEMORY/CONFIG.md`.
2. Read the Long-Term Memory section of `AI_MEMORY/PROJECT.md` (full file on the first session).
3. Read the latest 1-2 daily blocks from `AI_MEMORY/SYNC_LOG.md`.

Other files are loaded on demand:

- Read `DECISIONS.md` before architecture, dependency, tooling, install, or publishing work.
- Read `TASKS.md` before starting or continuing work.
- Read `LEARNINGS.md` before debugging or revisiting known problem areas.

This gives a new agent the current project state quickly without loading the entire history.

## 7. Write Routing

The most important rule is: write only facts that change what a future project agent should do.

Automatic writes:

- Accepted architecture or dependency decision -> `DECISIONS.md`.
- Project goal, structure, workflow, or convention change -> `PROJECT.md`.
- Skill behavior, memory protocol, rule/schema, boot template, lint gate, install contract, or publishing contract change -> `DECISIONS.md`; refresh `PROJECT.md` if startup would otherwise be stale.
- Unfinished cross-session work, blocker, next action, owner/continuation state, or unclear completion state -> `TASKS.md`.
- Confirmed bug cause, validation trap, release gotcha, or repeated failure mode -> `LEARNINGS.md`.
- Completed task or memory write session -> compact bullet in today's `SYNC_LOG.md`.

Manual writes:

- Routine task cleanup in `TASKS.md`.
- Dedup/curation in `LEARNINGS.md`.
- Consolidation of old or duplicated memory.

This auto/manual split exists to avoid the exact failure mode ShareMemory is designed to prevent: the agent finishes important work but records only a vague daily log, leaving the next agent without the decision, blocker, or lesson it actually needs.

## 8. Size Control

ShareMemory deliberately stays small:

- `DECISIONS.md`, `LEARNINGS.md`, and `TASKS.md` Done: max 5 entries.
- `SYNC_LOG.md`: max 7 daily blocks, max 15 bullets per day.
- `PROJECT.md` Long-Term Memory: about 30 lines.

Overflow is handled by progressive summarization:

1. Distill durable facts into `PROJECT.md` Long-Term Memory.
2. Move older detail into `AI_MEMORY/archive/`.
3. Keep the startup path dense and stable.

## 9. Safety Model

ShareMemory is file-based, so safety comes from discipline plus linting:

- A write lock (`AI_MEMORY/.write.lock`) prevents accidental overlapping writes.
- Closed daily blocks are immutable; corrections go into today's block.
- Every memory write is signed with real system time.
- Secrets, tokens, credentials, and private URLs are forbidden.
- `scripts/check_memory.sh` validates caps, format, protocol version, boot files, Claude import, lock shape, and secret-like strings.
- Optional git recovery can be enabled during init, but the skill never silently runs `git init`.

The lock is not a full concurrency system. The protocol still says not to run two agents on the same project simultaneously.

## 10. Documentation and Publishing Boundary

Public package files:

- `README.md`
- `README.zh.md`
- `PROJECT_DETAILS.md`
- `项目详解.md`
- `SKILL.md`
- `LICENSE`
- `.claude-plugin/marketplace.json`
- `assets/`
- `examples/`
- `templates/`
- tracked CI files

Local/internal files:

- `AI_MEMORY/`
- root `AGENTS.md`, `CLAUDE.md`, `MEMORY_PROTOCOL.md`, and root `scripts/check_memory.sh`
- `docs/`
- `docs/internal/LUBAN_AUDIT_REPORT.md`

The internal docs folder is ignored by `.gitignore`. Luban reports are test/audit artifacts and should not be published to GitHub.

## 11. Current Release Candidate State

The current release candidate includes:

- English and Chinese READMEs.
- Repo/project-scoped npx install instructions for Codex and Claude Code.
- Manual git clone fallback and update instructions.
- Live skills.sh per-skill route in the README badge.
- Demo GIF generated from a real local replay.
- Template tests for boot contract, protocol mismatch, secrets, and routing rules.
- Luban baseline: repository and installed copy both target `14 PASS / 0 WARN / 0 FAIL`.
- Confirmed Codex and Claude skill environments resolve to the same installed copy in local validation.

## 12. Known Limits

- This is not a parallel editing system.
- The protocol is still agent-instruction-based; lint catches mistakes after the fact.
- Codex and Claude Code have different hook capabilities, so enforcement is asymmetric.
- `npx skills add --copy` installs a copy, not a git checkout; updates require rerunning the install command.
- Git clone installs can update with `git pull --ff-only`.

Those constraints are acceptable because ShareMemory is intentionally a small repo-local handoff protocol, not a memory database or multi-agent scheduler.
