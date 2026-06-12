# ShareMemory Protocol v1.1

Project-scoped shared memory for AI agents working in this repository. `AI_MEMORY/` is the source of truth.

Boot layers: `AGENTS.md` holds the shared, agent-neutral boot rules (all agents read it — Codex natively, Claude Code via the `@AGENTS.md` import in `CLAUDE.md`). `CLAUDE.md` adds Claude-only notes. Boot content lives inside `<!-- SHAREMEMORY:START/END -->` marker blocks managed by the share-memory skill — exactly one block per file.
AGENT_NAME: Claude Code → `Claude` · Codex → `Codex` · others → product name.

## 1. Memory Model

ShareMemory is not a chat transcript or a database. It is a project handoff layer with two kinds of memory:

- **Handoff history**: `AI_MEMORY/SYNC_LOG.md` + `AI_MEMORY/archive/SYNC_LOG-YYYY-MM.md` record daily handoff summaries. There is at most one block per date. Today's block may be updated/condensed under the write lock; closed dates are immutable and may only be moved whole to archive.
- **Current views**: `PROJECT.md`, `DECISIONS.md`, `TASKS.md`, and `LEARNINGS.md` summarize the current useful state. These files may be updated or rewritten, but only after re-reading the current file.

Goal: a new agent should understand the project state in under 2 minutes, avoid repeated work, preserve key decisions, and keep startup memory reads small.

## 2. Startup — tiered, to keep token cost low

Startup budget: target **under ~700 tokens**. Do not expand old logs or full detail files during boot; use `memory status` for deeper inspection.

ALWAYS read before any task (cheap core set):

1. `AI_MEMORY/CONFIG.md` — memory language.
2. `AI_MEMORY/PROJECT.md` — at minimum the **Long-Term Memory** section (full file on first session).
3. Latest 1-2 daily blocks in `AI_MEMORY/SYNC_LOG.md` — note what the OTHER agent changed.

READ ON DEMAND — not at startup, but BEFORE related work:

- `DECISIONS.md` → before any architectural or dependency work.
- `TASKS.md` → before starting or continuing tasks.
- `LEARNINGS.md` → before debugging / revisiting past problem areas.

If `AI_MEMORY/` is missing or empty → First-Time Init (§3). After loading, state once: "Memory loaded."

## 3. First-Time Init (idempotent — never overwrite existing memory)

1. Ask the user the memory language: 中文 / English / bilingual.
2. Ask the user whether to enable git as the memory recovery layer (explain what it does first; check `git --version`; never `git init` without explicit permission).
3. Create `AI_MEMORY/` + `archive/` from the share-memory skill’s `templates/memory/` (both agents use the same skill).
4. Set up boot files via marker blocks (never plain append): if a file has no `SHAREMEMORY` block → insert it; if it has one → replace it; if the file doesn't exist → create from template. Back up existing files before modifying as `<file>.bak.YYYYMMDD-HHMMSS`. Ensure `CLAUDE.md` contains `@AGENTS.md`.
5. Record language + git choice + date in `CONFIG.md`; fill `PROJECT.md` (ask the user if unclear).
6. Create/update today's `SYNC_LOG.md` block with the init summary.

## 4. Write Lock

Before ANY write operation inside `AI_MEMORY/` (modifying, creating, or archiving files), acquire a lightweight write lock:

1. Run `mkdir AI_MEMORY/.write.lock`.
2. If it succeeds, write `AI_MEMORY/.write.lock/owner` with `[YYYY-MM-DD HH:MM] [AGENT_NAME] purpose`.
3. If it fails because the lock exists, stop and read `AI_MEMORY/.write.lock/owner`. Do not write memory. **Report the lock's age to the user** (e.g. "lock held by Codex since 14:02, ~3h ago") so they can judge staleness.
4. Never delete another agent's lock unless the user confirms it is stale. A lock older than ~60 minutes with no other agent running is a stale candidate — say so when reporting.
5. Remove `AI_MEMORY/.write.lock` after the write session finishes or is abandoned.

The lock is an accident-prevention guardrail, not permission to run multiple agents in parallel.

## 5. Write Rules

Entry format: `### [YYYY-MM-DD HH:MM] [AGENT_NAME] Title` + body. Timestamp from system (`date "+%Y-%m-%d %H:%M"`) — never guessed. Content in the language set in `CONFIG.md`.

- **AUTO-WRITE** (immediately, unasked): architectural/technical decisions and dependency changes → `DECISIONS.md`; goal/structure changes → `PROJECT.md`; skill/protocol/rule/schema/boot-template/lint behavior changes count as architecture/workflow/public-contract changes; handoff-critical active task state (unfinished cross-session work, blocker, required next action, owner/continuation state, or completion mark) → `TASKS.md`; confirmed reusable bug cause / validation trap / release gotcha / repeated failure mode → `LEARNINGS.md`; on completing a task → update today's `SYNC_LOG.md` block.
- **READ-ONLY OVERRIDE**: if the user explicitly forbids writes (e.g. "don't modify anything", "read-only audit", "only write the report"), all auto-write rules are paused for that session. Do not write `AI_MEMORY/`; state at the end that memory was not updated because of the user restriction. The user can later say "update memory" to record progress.
- **MANUAL-WRITE** (only when user invokes the share-memory skill / says "update memory"): routine `TASKS.md` progress cleanup and non-critical `LEARNINGS.md` curation. Do not wait for explicit `update memory` when the auto-write cases above apply.
- **EVERY write session** also updates today's `SYNC_LOG.md` block with one compact bullet per touched file: `- [HH:MM] [AGENT_NAME] [filename] one-line summary`.
- **SYNC_LOG is daily, not per-event noise**: one `## YYYY-MM-DD` block per day. Keep today's block useful and concise. Do not edit closed date blocks; archive old blocks whole when trimming.
- **Updating today's block**: if today's `## YYYY-MM-DD` block does not exist, append it at the end. If it exists, edit only that block under the write lock; append or condense bullets so the day remains readable. Keep a block ≤15 bullets — condense before adding more.
- **Midnight boundary**: "today" is the system date AT THE MOMENT OF WRITING. A session that crosses midnight opens a new block for the new date; the previous block closes, even if this same agent created it minutes earlier.
- **CORRECTIONS — never edit history**: closed date blocks are immutable even when wrong. On discovering an error in a closed block or any past memory entry, write a correction in TODAY's block pointing at it: `- [HH:MM] [AGENT_NAME] [correction] <YYYY-MM-DD entry> was wrong: <what is actually true>`. For current-view files (DECISIONS etc.) additionally add a corrected entry marked `supersedes [date]`. Never silently work around a wrong memory entry — future agents will keep tripping on it.

Style: telegraphic — each entry ≤3 lines, no filler. Memory is a lookup table, not a diary.
Dedup: search the target file before writing. When replacing an old decision, mark the new entry `supersedes [date]` instead of adding a parallel one.
**SECURITY: never write secrets, API keys, credentials, tokens, or private URLs into memory.**

## 6. File Routing & Maintenance Cadence

Use the existing files first. Do not create new memory files unless the user explicitly asks and the protocol version is changed.

| File | Write when | Review cadence | Useful signal |
|---|---|---|---|
| `CONFIG.md` | Init or protocol migration only | During `status` / `migrate` | Language, git setting, protocol version are still true |
| `PROJECT.md` | Project goal/scope/architecture/conventions change; skill/protocol/rule schema changes; Long-Term Memory is stale | After a milestone/release, before a long handoff, or when recent logs contain durable state not captured there | A fresh agent can understand current project direction in <2 minutes |
| `DECISIONS.md` | Accepted architecture, dependency, tooling, install, publishing, skill-rule, protocol, memory-schema, boot-template, or lint-gate decision | Immediately after the decision | Future agents should follow this decision instead of re-litigating it |
| `TASKS.md` | Auto when unfinished work crosses sessions, a blocker/next action/owner is needed, or completion state would be unclear; manual for routine progress cleanup | At handoff and after completing a meaningful task | Active items include the next action or blocker, not just a vague title |
| `LEARNINGS.md` | Auto when a validated bug cause, test trap, release gotcha, or recurring failure mode is confirmed; manual for curation/dedup | After debugging, failed validation, or repair work | The note would save a future agent >10 minutes or prevent repeated breakage |
| `SYNC_LOG.md` | Every memory write session and every completed task | Daily; condense before >15 bullets | The other agent can see what changed today without reading a diary |
| `archive/` | Overflow or consolidation only | During `consolidate memory` | Old facts remain recoverable without bloating startup |

At the end of any significant task, run this quick usefulness check before writing:

1. Did project direction, architecture, workflow, install path, public contract, skill behavior, protocol, rule/schema, boot template, or lint gate change? → update `PROJECT.md` and/or `DECISIONS.md`.
2. Would the next agent need a concrete next step, blocker, owner, continuation state, or completion state? → update `TASKS.md` now, not later.
3. Was there a confirmed failure cause or gotcha likely to recur? → update `LEARNINGS.md` now, not later.
4. Would the boot summary be stale without this? → refresh `PROJECT.md` Long-Term Memory.
5. If none apply, avoid durable entries; use one compact `SYNC_LOG.md` bullet only when a handoff changed.

## 7. What Belongs in Memory

Write memory only when it would change what a future agent does.

**Must write**
- Accepted architecture or dependency decisions.
- Project goal, scope, workflow, or convention changes.
- Skill behavior, memory protocol, rule/schema, boot-template, lint-gate, install, or publishing contract changes.
- Completed task summaries that prevent duplicate work.
- Validated bug causes, fixes, and gotchas likely to recur.
- Project-specific user preferences or constraints.

**Do not write**
- Raw reasoning, chain-of-thought, or speculative guesses.
- Temporary errors with no reusable lesson.
- Obvious implementation details already visible in code.
- Large copied docs, logs, diffs, or chat transcripts.
- Secrets, credentials, tokens, private URLs, or personal data not needed for the project.

If unsure, prefer a short bullet in today's `SYNC_LOG.md` over adding durable long-term memory.

## 8. Conflict Rule

User instruction wins — BUT explicitly point out any conflict with memory and confirm before proceeding. If the instruction permits writes, then update memory. If the instruction forbids writes, follow the read-only override in §5 and do not update memory until the user explicitly lifts the restriction.

## 9. Size Control & Maintenance

- `DECISIONS.md`, `TASKS.md` (Done), `LEARNINGS.md`: **max 5 entries each**. Overflow → distill the oldest into **Long-Term Memory** in `PROJECT.md` (≤30 lines; rewrite, don't append — and RE-READ it first so the other agent's content isn't lost) or move to `archive/<FILE>-YYYY-MM.md`.
- `SYNC_LOG.md`: keep the latest 7 daily blocks → older whole-day blocks to `archive/SYNC_LOG-YYYY-MM.md`.
- Refresh `PROJECT.md` Long-Term Memory when a milestone/release completes, when a task crosses sessions and the durable state is not captured there, or when consolidation/archive moves older facts out of current views.
- Review `LEARNINGS.md` after debugging or validation failures; auto-write confirmed reusable lessons, never transient error output.
- Review `TASKS.md` before handoff; auto-write handoff-critical active state, and ensure every active item says the next action or blocker.
- After any memory write, run `scripts/check_memory.sh` and fix any violations it reports. The script also verifies that `CONFIG.md`'s protocol version matches this protocol.
- If `Git: enabled` in `CONFIG.md`: after each write session run `git add AI_MEMORY && git commit -m "memory: <summary>"` — git history is the recovery layer if content gets overwritten. The choice is made by the user during init; `Git: disabled` → skip, memory still works.
- Do not run both agents on this project simultaneously. The write lock prevents accidental overlap; it is not a full concurrency system.
