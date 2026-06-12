---
name: share-memory
description: Project-scoped shared memory between AI agents (Claude Code + Codex). Use when the user says "init memory", "update memory", "sync memory", "memory status", "consolidate memory", "repair memory", "migrate memory", "更新记忆", "共享记忆", when AI_MEMORY/ is missing in a project that should have shared memory, or when the user wants completed work recorded for the other agent to see.
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

Determine the operation from the user's intent: **init**, **update**, **status**, **consolidate**, **repair**, or **migrate**.

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

1. Update `AI_MEMORY/TASKS.md` — check off done items, add new active items.
2. Add a `LEARNINGS.md` entry only if there's a real lesson (≤3 lines, dedup first).
3. Update today's `SYNC_LOG.md` block with one compact bullet per file touched.
4. Run `scripts/check_memory.sh`; fix any violations (caps per protocol §8 — ask user before promoting entries to Long-Term Memory).
5. If `CONFIG.md` says `Git: enabled`: run `git add AI_MEMORY && git commit -m "memory: <summary>"`.

## status

1. Read all `AI_MEMORY/` files.
2. Report: current AGENT_NAME, last writer (from `SYNC_LOG.md`), project state, active tasks, latest 1-2 daily blocks, whether `.write.lock` is held (and its age), and lint result.
3. Compare the project's `CONFIG.md` protocol version against this skill's version (v1.1). If older, tell the user and offer **migrate** — never migrate silently.

## consolidate

Periodic compression pass (when memory feels bloated or check_memory.sh complains):

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

## Always

- Sign entries `### [YYYY-MM-DD HH:MM] [AGENT_NAME] Title` — timestamp from `date "+%Y-%m-%d %H:%M"`, never guessed.
- Telegraphic style, ≤3 lines per entry, language per `CONFIG.md`. Write only facts that change what a future agent should do. NEVER write secrets into memory.
- Cross-agent state lives in `AI_MEMORY/` only — never rely on Claude auto memory or any agent-private store for facts the other agent needs.
- Decisions / dependency changes / task-completion log bullets are AUTO-written per protocol §5 even when this skill isn't invoked.
