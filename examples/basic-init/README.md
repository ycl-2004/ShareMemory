# Example: Basic Init → Handoff

A minimal, sanitized walkthrough of what ShareMemory produces on first init and how the handoff looks.

All file contents below are real outputs from a test project; only the project name was changed.

## Before: Empty Project

```
my-app/
  package.json
  src/
    index.ts
  README.md
```

No `CLAUDE.md`, no `AGENTS.md`, no `AI_MEMORY/`.

## User Prompt (Claude Code)

> init memory

(Claude Code picks up the share-memory skill, runs `init`.)

## Agent-User Interaction

1. **Language question**: Agent asks "中文 / English / bilingual?" → User picks `English`
2. **Git question**: Agent asks about git recovery layer → User picks `enabled`

## After: Files Written

```
my-app/
  MEMORY_PROTOCOL.md          # shared rules both agents follow
  AGENTS.md                   # agent-neutral boot rules (marker block)
  CLAUDE.md                   # @AGENTS.md import + Claude notes (marker block)
  scripts/
    check_memory.sh           # post-write lint + secrets scan
  AI_MEMORY/
    CONFIG.md                 # language, git, protocol version
    PROJECT.md                # overview, architecture, long-term memory
    DECISIONS.md              # decisions (empty, ready)
    TASKS.md                  # active/done tasks
    LEARNINGS.md              # lessons (empty, ready)
    SYNC_LOG.md               # daily handoff blocks
    archive/                  # overflow archive
```

### `AI_MEMORY/CONFIG.md` (generated)
```markdown
# ShareMemory Config

- Language: English
- Git: enabled
- Created: 2026-06-12
- Protocol: v1.1
```

### `AI_MEMORY/SYNC_LOG.md` (generated)
```markdown
# Sync Log

## 2026-06-12
- [14:05] [Claude] [init] memory initialized
```

## Handoff: Next Day, Codex Opens the Project

Codex reads the boot sequence:
1. `AGENTS.md` → sees `MEMORY_PROTOCOL.md` reference
2. `AI_MEMORY/CONFIG.md` → knows language, protocol version, git setting
3. `AI_MEMORY/PROJECT.md` Long-Term Memory → knows the project
4. `AI_MEMORY/SYNC_LOG.md` latest block → sees "Claude initialized memory yesterday"

Codex now knows:
- This project uses ShareMemory protocol v1.1
- Claude was here yesterday and initialized
- No active tasks or pending decisions yet
- Git recovery is enabled — writes will be committed

## After a Week of Work

### `AI_MEMORY/DECISIONS.md`
```markdown
# Decisions

### [2026-06-13 10:22] [Codex] Use SQLite over PostgreSQL
Single-user CLI tool; no need for a separate server. Supersedes [2026-06-12].

### [2026-06-14 15:40] [Claude] Auth: JWT stored in HttpOnly cookie
SPA + API on same domain; refresh-token rotation every 7 days.
```

### `AI_MEMORY/SYNC_LOG.md` (latest blocks)
```markdown
## 2026-06-14
- [15:40] [Claude] [DECISIONS.md] JWT HttpOnly cookie auth; refresh rotation 7d
- [10:15] [Claude] [TASKS.md] auth endpoints done; dashboard WIP

## 2026-06-13
- [16:30] [Codex] [DECISIONS.md] SQLite chosen; migrated schema
- [10:22] [Codex] [TASKS.md] scaffolded CLI entry point
```
