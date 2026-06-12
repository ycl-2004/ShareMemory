# Claude Code — ShareMemory Boot

AGENT_NAME: `Claude`

You MUST read `MEMORY_PROTOCOL.md` and follow it before doing anything else in this project.

Quick reference:

1. **Mental model**: `SYNC_LOG.md` + archive are daily handoff history; `PROJECT.md` / `DECISIONS.md` / `TASKS.md` / `LEARNINGS.md` are current views.
2. **Startup (tiered)**: always read `AI_MEMORY/CONFIG.md`, the Long-Term Memory section of `PROJECT.md`, and the latest 1-2 daily blocks of `SYNC_LOG.md` (check for Codex's changes). Read `DECISIONS.md` / `TASKS.md` / `LEARNINGS.md` on demand, before related work.
3. **Missing memory**: if `AI_MEMORY/` doesn't exist, run First-Time Init per protocol §3. Ask the user for the memory language first.
4. **Auto-write**: decisions and dependency changes → memory immediately; task completion → today's `SYNC_LOG.md` block. Task progress / learnings → only when the user says "update memory".
5. **Every write**: acquire `AI_MEMORY/.write.lock` (covers ALL writes incl. archiving; if held, report the lock's age to the user — ~60min+ with no agent running = stale candidate), sign entries `[YYYY-MM-DD HH:MM] [Claude]` (real system time), update today's `SYNC_LOG.md` block ("today" = system date at write time, even past midnight), then run `scripts/check_memory.sh`.
5b. **Corrections**: closed date blocks are immutable — fix past mistakes via a `[correction]` bullet in TODAY's block pointing at the wrong entry (+ `supersedes [date]` entry in current-view files). Never edit history or silently work around a wrong memory entry.
6. **Write threshold**: write only facts that change what a future agent should do; no raw reasoning, guesses, verbose logs, or secrets.
7. **Style**: entries ≤3 lines, telegraphic. Dedup first; replacements marked `supersedes [date]`. NEVER write secrets into memory.
8. **Conflicts**: user instruction wins, but point out conflicts with memory and confirm; then update memory.
9. **Size**: max 5 entries per file; `SYNC_LOG.md` keeps latest 7 daily blocks. Overflow → Long-Term Memory in `PROJECT.md` (re-read before rewriting) or `archive/`. Commit `AI_MEMORY/` to git after write sessions if `Git: enabled` in `CONFIG.md`.
