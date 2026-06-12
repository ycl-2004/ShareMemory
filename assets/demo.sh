#!/usr/bin/env bash
# Reproducible ShareMemory demo used by assets/demo.tape and assets/demo.gif.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TODAY="${SHAREMEMORY_DEMO_DATE:-2026-06-12}"
TYPE_OUTPUT="${SHAREMEMORY_DEMO_TYPE:-0}"
TYPE_DELAY="${SHAREMEMORY_DEMO_TYPE_DELAY:-0.012}"

emit() {
  if [ "$TYPE_OUTPUT" = "1" ]; then
    local text="$1"
    local i char
    for ((i = 0; i < ${#text}; i++)); do
      char="${text:i:1}"
      printf '%s' "$char"
      case "$char" in
        $'\n')
          sleep 0.22
          ;;
        ' ')
          sleep 0.018
          ;;
        ':'|','|'.'|';'|')')
          sleep 0.045
          ;;
        '$')
          sleep 0.12
          ;;
        *)
          case $((i % 7)) in
            0) sleep "$TYPE_DELAY" ;;
            1) sleep 0.018 ;;
            2) sleep 0.026 ;;
            3) sleep 0.014 ;;
            4) sleep 0.034 ;;
            5) sleep 0.020 ;;
            6) sleep 0.030 ;;
          esac
          ;;
      esac
    done
  else
    printf '%s' "$1"
  fi
}

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

CHECK_OUTPUT="$(cd "$DEMO_DIR" && bash scripts/check_memory.sh)"
CONFIG_OUTPUT="$(grep -E '^- (Language|Git|Protocol):' "$DEMO_DIR/AI_MEMORY/CONFIG.md")"
SYNC_OUTPUT="$(sed -n "/^## $TODAY/,\$p" "$DEMO_DIR/AI_MEMORY/SYNC_LOG.md")"

TRANSCRIPT="$(cat <<TRANSCRIPT
ShareMemory demo: Claude initializes, Codex reads.
project: $DEMO_DIR

$ init memory
created: MEMORY_PROTOCOL.md AGENTS.md CLAUDE.md scripts/check_memory.sh AI_MEMORY/
Claude wrote:
  - CONFIG.md: Language English, Git disabled, Protocol v1.1
  - SYNC_LOG.md: [09:00] [Claude] [init] memory initialized

$ bash scripts/check_memory.sh
$CHECK_OUTPUT

$ memory status (Codex startup read)
AGENT_NAME: Codex
CONFIG:
$CONFIG_OUTPUT
LATEST SYNC_LOG:
$SYNC_OUTPUT

Result: Codex starts with Claude handoff instead of a blank slate.
TRANSCRIPT
)"

emit "$TRANSCRIPT"
printf '\n'
