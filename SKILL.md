---
name: share-memory
description: |
  Project-scoped shared memory between AI agents (Claude Code + Codex). Use when the user says "init memory", "update memory", "sync memory", "memory status", "consolidate memory", "repair memory", "migrate memory", "更新记忆", "共享记忆", when AI_MEMORY/ is missing in a project that should have shared memory, or when the user wants completed work recorded for the other agent to see.
  Do NOT use for: general chat memory, non-project shared state, one-off summaries, cross-project personal preferences, writing-materials archiving, or read-only audit tasks. When the user explicitly forbids writing (e.g. "don't modify anything", "read-only audit", "only write the report"), auto-write is paused — do NOT write to AI_MEMORY/ and state at the end that memory was not updated per user restriction.
---

# ShareMemory Skill

Sets up and maintains a file-based shared memory (`AI_MEMORY/`) that Claude Code and Codex both read/write in the same project, so each agent sees the other's decisions and changes.

This skill is installable on both platforms (same folder, same SKILL.md):
- Claude Code: `~/.claude/skills/share-memory/` (personal) or `<project>/.claude/skills/share-memory/` (project)
- Codex: `~/.agents/skills/share-memory/`

AGENT_NAME: use `Claude` when running as Claude Code, `Codex` when running as Codex.
After init, the rules live in the project's `MEMORY_PROTOCOL.md` — that file (not this skill) is the source of truth for day-to-day behavior.

Memory model:
- `SYNC_LOG.md` + `archive/` are daily handoff history, with at most one block per date.
- `PROJECT.md`, `DECISIONS.md`, `TASKS.md`, and `LEARNINGS.md` are current views.
- Boot layer: `AGENTS.md` carries the shared agent-neutral rules; `CLAUDE.md` imports it via `@AGENTS.md` and adds Claude-only notes. All skill-managed boot content lives inside `<!-- SHAREMEMORY:START -->` / `<!-- SHAREMEMORY:END -->` marker blocks.
- Before ANY write inside `AI_MEMORY/` (incl. creating or archiving files), acquire `AI_MEMORY/.write.lock` per the protocol.
- Use the protocol's file-routing cadence before writing: prefer existing files, write only facts that help the next project agent, and refresh `PROJECT.md` / `LEARNINGS.md` when durable context would otherwise be missed.

Determine the operation from the user's intent: **init**, **update**, **status**, **consolidate**, **repair**, or **migrate**.

**Intent routing (first-trigger decision table):**

| User says / situation | Operation | Pre-check |
|---|---|---|
| "init memory", first time in project, `AI_MEMORY/` missing | **init** | If `AI_MEMORY/` already populated → status instead (idempotent) |
| "update memory", "更新记忆", record progress | **update** | Must have `AI_MEMORY/` initialized |
| "memory status", "状态", "what changed" | **status** | Read-only — never writes |
| "consolidate memory", "压缩记忆" | **consolidate** | Acquire write lock first |
| "repair memory", boot files broken, lint fails | **repair** | Acquire write lock; back up files before fixing |
| "migrate memory", protocol version mismatch | **migrate** | User must explicitly consent; acquire write lock |

**Mandatory stop points** (halt and ask user before proceeding):
- Creating or overwriting boot files (`AGENTS.md`, `CLAUDE.md`)
- Enabling git or running `git init`
- Removing a stale `.write.lock`
- Migrating protocol version
- Any publishing-channel operation

**Read-only vs auto-write rule:** When the user imposes a write restriction (e.g. "only write this report", "don't modify anything", "read-only audit"), auto-write of decisions / task-completion log bullets is PAUSED for the entire session. At the end, state: "Per user restriction, memory was not updated." The user can later lift the restriction by saying "update memory" explicitly.

**Project-helpfulness routing check** (run before `update`, after significant task completion, and before long handoff):

| If this changed | Write / refresh |
|---|---|
| Project goal, scope, architecture, workflow, install path, public contract | `PROJECT.md` and/or `DECISIONS.md` |
| Skill behavior, memory protocol, rule/schema, boot template, lint gate, or install/publish contract | `DECISIONS.md`; refresh `PROJECT.md` Long-Term Memory if startup would be stale |
| Active work now needs a next action, blocker, owner, continuation state, or completion mark | `TASKS.md` automatically if handoff would be incomplete; otherwise only on `update memory` |
| Confirmed bug cause, validation trap, release gotcha, repeated failure mode | `LEARNINGS.md` automatically if reusable; otherwise skip |
| Long-Term Memory would be stale for a fresh agent | rewrite `PROJECT.md` Long-Term Memory |
| Only today's handoff changed | one compact `SYNC_LOG.md` bullet |

Current protocol version shipped by this skill: **v1.1**.

## Marker block rules (used by init, repair, migrate)

For each boot file (`AGENTS.md`, `CLAUDE.md`):
- File doesn't exist → create it from this skill's `templates/project/`.
- File exists, no `SHAREMEMORY` block → back it up (`<file>.bak.YYYYMMDD-HHMMSS`), then INSERT the template's block (top of `CLAUDE.md` so the import loads first; end of `AGENTS.md`).
- File exists with a block → back it up, then REPLACE the block content with the template's. Never touch user content outside the markers.
- Never plain-append: repeated runs must never produce a second block.

## init

Run in the target project's root.

1. **Detect project state** — check which of these exist: `CLAUDE.md`, `AGENTS.md`, `MEMORY_PROTOCOL.md`, `AI_MEMORY/`, `scripts/check_memory.sh`. Classify:
   - A: fresh project (no boot files) · B: Claude-only (`CLAUDE.md` only) · C: Codex-only (`AGENTS.md` only) · D: both boot files · E: ShareMemory already initialized (`AI_MEMORY/` populated).
   - Case E → do NOT overwrite anything; report status instead (idempotent). Others → continue.
2. Deps: everything runs on bash built-ins — nothing to install, no network access.
3. Ask the user the memory language: 中文 / English / bilingual.
4. Ask the user whether to enable **git as the memory recovery layer**. Explain first: "memory 文件可能被另一个 agent 覆盖;启用后每次写入 session 会提交 AI_MEMORY/ 到 git,任何历史版本都能找回。" Then:
   - Run `git --version`. If git is not installed → tell the user, record `Git: disabled`.
   - If user says yes but the project has no repo → ask permission before running `git init` (NEVER run it silently).
5. Copy `MEMORY_PROTOCOL.md` and `scripts/check_memory.sh` (make executable) from `templates/project/`.
6. Set up `AGENTS.md` and `CLAUDE.md` per the Marker block rules above. Verify `CLAUDE.md` contains `@AGENTS.md`.
7. Copy this skill's `templates/memory/` into `<project>/AI_MEMORY/`; create `AI_MEMORY/archive/`.
8. Fill `AI_MEMORY/CONFIG.md`: language, git choice, today's date, protocol v1.1.
9. Briefly interview the user to fill `AI_MEMORY/PROJECT.md`. Skip what's obvious from the repo.
10. Create today's `SYNC_LOG.md` block with `- [HH:MM] [AGENT_NAME] [init] memory initialized`, then run `scripts/check_memory.sh`.

## update

Run when the user asks to record progress:

1. Run the project-helpfulness routing check above; decide which existing memory files truly need updates.
2. Update `AI_MEMORY/TASKS.md` only when task state changed. Active items must include a concrete next action or blocker.
3. Add a `LEARNINGS.md` entry only for confirmed lessons that would save a future agent time or prevent repeat breakage (≤3 lines, dedup first).
4. Refresh `PROJECT.md` Long-Term Memory when a milestone/release completed, durable project state changed, or recent logs contain context a fresh agent would otherwise miss.
5. Update `DECISIONS.md` immediately for accepted architecture, dependency, tooling, install, publishing, skill-rule, protocol, memory-schema, boot-template, or lint-gate decisions.
6. Update today's `SYNC_LOG.md` block with one compact bullet per file touched.
7. Run `scripts/check_memory.sh`; fix any violations (caps per protocol §9 — ask user before promoting entries to Long-Term Memory).
8. If `CONFIG.md` says `Git: enabled`: run `git add AI_MEMORY && git commit -m "memory: <summary>"`.

## status

1. Read all `AI_MEMORY/` files.
2. Report: current AGENT_NAME, last writer (from `SYNC_LOG.md`), project state, active tasks, latest 1-2 daily blocks, whether `.write.lock` is held (and its age), and lint result.
3. Compare the project's `CONFIG.md` protocol version against this skill's version (v1.1). If older, tell the user and offer **migrate** — never migrate silently.

## consolidate

Periodic compression pass (when memory feels bloated, `PROJECT.md` is stale, a milestone/release just finished, a task crossed sessions, or `check_memory.sh` complains):

1. Read all memory files fully.
2. Merge duplicate/overlapping entries; delete obsolete ones (superseded decisions → archive/).
3. Rewrite Long-Term Memory in `PROJECT.md` as the dense current state (≤30 lines) — re-read it first so the other agent's content isn't lost.
4. Move overflow to `archive/<FILE>-YYYY-MM.md`; trim `SYNC_LOG.md` to latest 7 daily blocks, moving older whole-day blocks to `archive/SYNC_LOG-YYYY-MM.md`.
5. Add the consolidation summary to today's `SYNC_LOG.md` block, run `scripts/check_memory.sh`; commit if `Git: enabled`.

## repair

Health check + auto-fix for a project that drifted (run under the write lock; back up with timestamped `.bak.YYYYMMDD-HHMMSS` files before fixing):

1. `CLAUDE.md` missing `@AGENTS.md` import → add it inside the block.
2. Boot files with zero, duplicate, or unbalanced `SHAREMEMORY` blocks → rebuild to exactly one block per file (keep user content outside markers).
3. Missing `AI_MEMORY/` files or `archive/` → recreate from `templates/memory/` (never overwrite existing ones).
4. Missing `MEMORY_PROTOCOL.md` or `scripts/check_memory.sh` → restore from `templates/project/`.
5. Stale `.write.lock` (with user confirmation) → remove.
6. Run `scripts/check_memory.sh`; report everything that was fixed and anything that still fails; log the repair to today's `SYNC_LOG.md` block.

## migrate

Upgrade a project whose `CONFIG.md` protocol version is older than this skill's (run only with user consent, under the write lock):

1. Read the project's `CONFIG.md` version and current memory files.
2. **From v1.0**: memory data is unchanged. Rebuild boot files into marker blocks: wrap/replace the old "ShareMemory Boot" sections with the new templates (back up first), convert `CLAUDE.md` to the `@AGENTS.md` import form, keep user content outside markers.
3. If `SYNC_LOG.md` is a flat line-log rather than daily blocks, regroup the last 7 days into `## YYYY-MM-DD` blocks and archive the rest.
4. Overwrite the project's `MEMORY_PROTOCOL.md` and `scripts/check_memory.sh` with this skill's `templates/project/` versions.
5. Update `CONFIG.md` to this skill's protocol version, record the migration in today's `SYNC_LOG.md` block, run `scripts/check_memory.sh`, commit if `Git: enabled`.

## Failure modes & recovery

| Trigger | Should stop or repair? | User-visible message | Forbidden actions |
|---|---|---|---|
| `.write.lock` held by another agent | **Stop**, report holder and age. If ≥60 min with no running agent → offer to remove (user must confirm) | "Write lock held by [AGENT_NAME] since [timestamp] (age: [N] min). Waiting for release or user confirmation to remove." | Do NOT delete lock without confirmation |
| Permission denied (can't write to `AI_MEMORY/`) | **Stop**, report path and error | "Cannot write to AI_MEMORY/[file]: permission denied. Check directory ownership." | Do NOT escalate privileges or write to alternate location |
| `git` missing but `CONFIG.md` says `Git: enabled` | **Degrade** — skip git commit, warn once, continue with write | "Git is enabled in CONFIG.md but `git` is not available. Skipping commit; memory written without versioning." | Do NOT toggle Git setting silently |
| User declines `git init` during init | **Accept** — record `Git: disabled` in CONFIG.md, continue | "Git recovery disabled. You can enable it later by editing AI_MEMORY/CONFIG.md and running `repair memory`." | Do NOT run git init anyway |
| Protocol version mismatch (`CONFIG.md` older than skill) | **Warn** — report versions, offer `migrate`; do NOT migrate silently | "Project protocol is v[X], skill is v1.1. Run 'migrate memory' to upgrade (backup first, user consent required)." | Do NOT auto-migrate |
| Template files missing from skill install | **Stop** — report which template is missing, suggest re-cloning the skill | "Template [name] not found in skill installation. Re-clone https://github.com/ycl-2004/ShareMemory and retry." | Do NOT fabricate templates from memory |
| Two agents writing simultaneously (lock race) | **Stop** — the loser reports lock, does NOT write | "Write lock already held by [AGENT_NAME]. Your changes are NOT written. Share them with the user or retry after the lock is released." | Do NOT bypass the lock |
| User explicitly forbids writing | **Pause auto-write** — read-only operations only; state at end that memory was not updated | "Per user restriction (read-only / write only X), memory was not updated. Say 'update memory' to record changes." | Do NOT write to AI_MEMORY/ even if auto-write rules would trigger |

## Always

- Sign entries `### [YYYY-MM-DD HH:MM] [AGENT_NAME] Title` — timestamp from `date "+%Y-%m-%d %H:%M"`, never guessed.
- Telegraphic style, ≤3 lines per entry, language per `CONFIG.md`. Write only facts that change what a future agent should do. NEVER write secrets into memory.
- Cross-agent state lives in `AI_MEMORY/` only — never rely on Claude auto memory or any agent-private store for facts the other agent needs.
- At the end of meaningful work, run the project-helpfulness routing check before deciding whether to update memory; avoid durable entries when a compact `SYNC_LOG.md` bullet is enough.
- Decisions, dependency changes, rule/protocol contract changes, handoff-critical task state, confirmed reusable lessons, and task-completion log bullets are AUTO-written per protocol §5 even when this skill isn't invoked.
