<!-- SHAREMEMORY:START -->
@AGENTS.md

## Claude Code Notes

- AGENT_NAME: `Claude`. The shared rules above (imported from `AGENTS.md`) are the source of truth.
- **Cross-agent state lives in `AI_MEMORY/` only.** Claude Code's auto memory (machine-local, `~/.claude/projects/<project>/memory/`) is fine for your private learning, but any decision, dependency change, or task state that Codex needs to know MUST be written to `AI_MEMORY/` — never rely on Claude-only memory for shared facts.
- Optional strict mode (for testing ShareMemory in isolation): set `"autoMemoryEnabled": false` in `.claude/settings.local.json`. Not recommended as a default.
<!-- SHAREMEMORY:END -->
