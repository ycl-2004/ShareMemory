# Sync Log

Daily handoff summary, newest date last. Max 7 daily blocks — older whole-day blocks → archive/SYNC_LOG-YYYY-MM.md.
Startup: read the latest 1-2 daily blocks to see what the other agent changed.

There is at most one block per date. Today's block may be updated/condensed under the write lock; closed dates are immutable.

<!-- Format:
## YYYY-MM-DD
  - [HH:MM] [Claude|Codex] [filename] one-line summary
-->
