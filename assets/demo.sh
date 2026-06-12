#!/usr/bin/env bash
# Reproducible ShareMemory demo used by assets/demo.tape and assets/demo.gif.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TODAY="${SHAREMEMORY_DEMO_DATE:-2026-06-12}"

if [ -n "${SHAREMEMORY_DEMO_DIR:-}" ]; then
  DEMO_DIR="$SHAREMEMORY_DEMO_DIR"
  case "$DEMO_DIR" in
    /tmp/sharememory-demo*|/private/tmp/sharememory-demo*)
      rm -rf "$DEMO_DIR"
      ;;
    *)
      if [ -e "$DEMO_DIR" ]; then
        echo "Refusing to overwrite existing non-demo path: $DEMO_DIR" >&2
        exit 1
      fi
      ;;
  esac
else
  DEMO_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sharememory-demo.XXXXXX")"
fi

mkdir -p "$DEMO_DIR/scripts" "$DEMO_DIR/AI_MEMORY/archive"
cp "$ROOT/templates/project/AGENTS.md" "$DEMO_DIR/AGENTS.md"
cp "$ROOT/templates/project/CLAUDE.md" "$DEMO_DIR/CLAUDE.md"
cp "$ROOT/templates/project/MEMORY_PROTOCOL.md" "$DEMO_DIR/MEMORY_PROTOCOL.md"
cp "$ROOT/templates/project/scripts/check_memory.sh" "$DEMO_DIR/scripts/check_memory.sh"
chmod +x "$DEMO_DIR/scripts/check_memory.sh"
cp "$ROOT/templates/memory/"*.md "$DEMO_DIR/AI_MEMORY/"

cat > "$DEMO_DIR/AI_MEMORY/CONFIG.md" <<CONFIG
# ShareMemory Config

- Language: English
- Git: disabled - demo replay
- Created: $TODAY
- Protocol: v1.1
CONFIG

cat > "$DEMO_DIR/AI_MEMORY/PROJECT.md" <<'PROJECT'
# Project Memory

## Overview
Tiny demo app used to show Claude -> Codex handoff.

## Architecture
Plain files only; no server, database, or API.

## Constraints & Conventions
Keep memory short and lintable.

## Long-Term Memory
- Demo project uses ShareMemory protocol v1.1.
PROJECT

cat > "$DEMO_DIR/AI_MEMORY/SYNC_LOG.md" <<SYNC
# Sync Log

Daily handoff summary, newest date last. Max 7 daily blocks - older whole-day blocks -> archive/SYNC_LOG-YYYY-MM.md.
Startup: read the latest 1-2 daily blocks to see what the other agent changed.

## $TODAY
- [09:00] [Claude] [init] memory initialized
- [09:05] [Codex] [status] read latest handoff; no writes needed
SYNC

printf 'ShareMemory demo: Claude initializes, Codex reads.\n'
printf 'project: %s\n\n' "$DEMO_DIR"

printf '$ init memory\n'
printf 'created: MEMORY_PROTOCOL.md AGENTS.md CLAUDE.md scripts/check_memory.sh AI_MEMORY/\n'
printf 'Claude wrote:\n'
printf '  - CONFIG.md: Language English, Git disabled, Protocol v1.1\n'
printf '  - SYNC_LOG.md: [09:00] [Claude] [init] memory initialized\n\n'

printf '$ bash scripts/check_memory.sh\n'
(cd "$DEMO_DIR" && bash scripts/check_memory.sh)
printf '\n'

printf '$ memory status (Codex startup read)\n'
printf 'AGENT_NAME: Codex\n'
printf 'CONFIG:\n'
grep -E '^- (Language|Git|Protocol):' "$DEMO_DIR/AI_MEMORY/CONFIG.md"
printf 'LATEST SYNC_LOG:\n'
sed -n "/^## $TODAY/,\$p" "$DEMO_DIR/AI_MEMORY/SYNC_LOG.md"
printf '\nResult: Codex starts with Claude handoff instead of a blank slate.\n'
