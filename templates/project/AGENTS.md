# AGENTS.md

<!-- SHAREMEMORY:START -->
## ShareMemory Boot (shared, agent-neutral)

This project uses `AI_MEMORY/` as the shared memory source for ALL coding agents.
You MUST read `MEMORY_PROTOCOL.md` and follow it before doing anything else.

Before work — tiered startup, budget ~700 tokens:

1. Read `AI_MEMORY/CONFIG.md` (memory language, git setting).
2. Read the **Long-Term Memory** section of `AI_MEMORY/PROJECT.md` (full file on first session).
3. Read the latest 1-2 daily blocks of `AI_MEMORY/SYNC_LOG.md` — note what the OTHER agent changed.

Read `DECISIONS.md` / `TASKS.md` / `LEARNINGS.md` on demand, before related work — not at startup.
If `AI_MEMORY/` is missing, run First-Time Init per protocol §3 (via the `share-memory` skill).

During work — protocol quick reference:

- **Auto-write**: decisions & dependency changes → `DECISIONS.md`; task completion → today's `SYNC_LOG.md` block. Task progress / learnings → only when the user says "update memory". If the user explicitly says read-only / do not modify / only write a report, pause ALL memory writes and say memory was not updated.
- **Every write**: acquire `AI_MEMORY/.write.lock` first (covers ALL writes; if held, report the lock's age — ~60min+ with no agent running = stale candidate). Sign `[YYYY-MM-DD HH:MM] [AGENT_NAME]` with real system time. Update today's `SYNC_LOG.md` block ("today" = system date at write time, even past midnight). Then run `scripts/check_memory.sh`.
- **Corrections**: closed daily blocks are immutable — fix past mistakes via a `[correction]` bullet in TODAY's block (+ `supersedes [date]` entry in current-view files). Never rewrite history or silently work around wrong memory.
- **Style**: entries ≤3 lines, telegraphic; write only facts that change what a future agent should do. NEVER write secrets, tokens, credentials, or private URLs.
- **Conflicts**: user instruction wins. Point out conflicts with memory and confirm; update memory only if the user's instruction permits writes.
- **Size**: max 5 entries per file; `SYNC_LOG.md` keeps 7 daily blocks, ≤15 bullets each. Commit `AI_MEMORY/` after write sessions if `Git: enabled` in `CONFIG.md`.

Agent-specific notes:

- If you are **Codex**: AGENT_NAME is `Codex`. You may invoke the skill explicitly with `$share-memory` when needed.
- If you are **Claude Code**: AGENT_NAME is `Claude`; see `CLAUDE.md` for Claude-specific behavior.
- Any other agent: use your product name as AGENT_NAME and follow this file.
<!-- SHAREMEMORY:END -->
