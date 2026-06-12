---
name: share-memory
description: Project-scoped shared memory between AI agents (Claude Code + Codex). Use when the user says "init memory", "update memory", "sync memory", "memory status", "consolidate memory", "migrate memory", "更新记忆", "共享记忆", when AI_MEMORY/ is missing in a project that should have shared memory, or when the user wants completed work recorded for the other agent to see.
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
- Before ANY write inside `AI_MEMORY/` (incl. creating or archiving files), acquire `AI_MEMORY/.write.lock` per the protocol.

Determine the operation from the user's intent: **init**, **update**, **status**, **consolidate**, or **migrate**.

Current protocol version shipped by this skill: **v1.0**.

## init

Run in the target project's root. If `AI_MEMORY/` is missing or empty:

0. Deps: everything runs on bash built-ins — nothing to install, no network access.
1. Ask the user the memory language: 中文 / English / bilingual.
2. Ask the user whether to enable **git as the memory recovery layer**. Explain first: "memory 文件可能被另一个 agent 覆盖;启用后每次写入 session 会提交 AI_MEMORY/ 到 git,任何历史版本都能找回。" Then:
   - Run `git --version`. If git is not installed → tell the user, record `Git: disabled`.
   - If user says yes but the project has no repo → ask permission before running `git init` (NEVER run it silently).
3. Copy this skill's `templates/project/` into the project root: `MEMORY_PROTOCOL.md`, `CLAUDE.md`, `AGENTS.md`, `scripts/check_memory.sh` (make it executable).
   - If the project ALREADY has a `CLAUDE.md` or `AGENTS.md`: do NOT overwrite — append the template's content as a "## ShareMemory Boot" section at the end.
4. Copy this skill's `templates/memory/` into `<project>/AI_MEMORY/`; create `AI_MEMORY/archive/`.
5. Fill `AI_MEMORY/CONFIG.md`: language, git choice, today's date, protocol v1.0.
6. Briefly interview the user to fill `AI_MEMORY/PROJECT.md`. Skip what's obvious from the repo.
7. Create today's `SYNC_LOG.md` block and add `- [HH:MM] [AGENT_NAME] [init] memory initialized`.

If `AI_MEMORY/` already exists: do NOT overwrite — load it and report status instead (idempotent).

## update

Run when the user asks to record progress:

1. Update `AI_MEMORY/TASKS.md` — check off done items, add new active items.
2. Add a `LEARNINGS.md` entry only if there's a real lesson (≤3 lines, dedup first).
3. Update today's `SYNC_LOG.md` block with one compact bullet per file touched.
4. Run `scripts/check_memory.sh`; fix any violations (caps per protocol §8 — ask user before promoting entries to Long-Term Memory).
5. If `CONFIG.md` says `Git: enabled`: run `git add AI_MEMORY && git commit -m "memory: <summary>"`.

## status

1. Read all `AI_MEMORY/` files.
2. Report: project state, active tasks, latest 1-2 `SYNC_LOG.md` daily blocks, and specifically what the OTHER agent changed recently.
3. Compare the project's `CONFIG.md` protocol version against this skill's version (v1.0). If older, tell the user and offer **migrate** — never migrate silently.

## consolidate

Periodic compression pass (when memory feels bloated or check_memory.sh complains):

1. Read all memory files fully.
2. Merge duplicate/overlapping entries; delete obsolete ones (superseded decisions → archive/).
3. Rewrite Long-Term Memory in `PROJECT.md` as the dense current state (≤30 lines) — re-read it first so the other agent's content isn't lost.
4. Move overflow to `archive/<FILE>-YYYY-MM.md`; trim `SYNC_LOG.md` to latest 7 daily blocks, moving older whole-day blocks to `archive/SYNC_LOG-YYYY-MM.md`.
5. Add the consolidation summary to today's `SYNC_LOG.md` block, run `scripts/check_memory.sh`; commit if `Git: enabled`.

## migrate

Upgrade a project whose `CONFIG.md` protocol version is older than this skill's (run only with user consent, under the write lock):

1. Read the project's `CONFIG.md` version and current memory files.
2. Apply the data conversions listed for that version in `docs/changes/` (future releases will document them; v1.0 is the first release, so there is nothing older to convert yet). If `SYNC_LOG.md` is a flat line-log rather than daily blocks, regroup the last 7 days into `## YYYY-MM-DD` blocks and archive the rest.
3. Overwrite the project's `MEMORY_PROTOCOL.md` and `scripts/check_memory.sh` with this skill's `templates/project/` versions; refresh the ShareMemory sections of `CLAUDE.md`/`AGENTS.md` (do not touch user content outside those sections).
4. Update `CONFIG.md` to this skill's protocol version, record the migration in today's `SYNC_LOG.md` block, run `scripts/check_memory.sh`, commit if `Git: enabled`.

## Always

- Sign entries `### [YYYY-MM-DD HH:MM] [AGENT_NAME] Title` — timestamp from `date "+%Y-%m-%d %H:%M"`, never guessed.
- Telegraphic style, ≤3 lines per entry, language per `CONFIG.md`. Write only facts that change what a future agent should do. NEVER write secrets into memory.
- Decisions / dependency changes / task-completion log bullets are AUTO-written per protocol §5 even when this skill isn't invoked.
