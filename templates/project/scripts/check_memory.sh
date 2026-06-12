#!/usr/bin/env bash
# ShareMemory lint — run after any memory write. Exits 1 on violations.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)/AI_MEMORY"
fail=0
err() { echo "✗ $1"; fail=1; }

[ -d "$DIR" ] || { echo "✗ AI_MEMORY/ missing — run init first"; exit 1; }

# -1. Protocol version match (CONFIG.md vs this script's expected protocol)
EXPECTED_PROTOCOL="v1.1"
if [ -f "$DIR/CONFIG.md" ]; then
  ver=$(grep -oE 'Protocol: v[0-9]+\.[0-9]+' "$DIR/CONFIG.md" | head -1 | awk '{print $2}')
  if [ -n "$ver" ] && [ "$ver" != "$EXPECTED_PROTOCOL" ]; then
    err "CONFIG.md protocol $ver != expected $EXPECTED_PROTOCOL — ask the share-memory skill to migrate"
  fi
fi

# 0. Required files
for f in CONFIG.md PROJECT.md DECISIONS.md TASKS.md LEARNINGS.md SYNC_LOG.md; do
  [ -f "$DIR/$f" ] || err "$f missing"
done

# 1. Entry caps (max 5 per file)
for f in DECISIONS.md LEARNINGS.md; do
  [ -f "$DIR/$f" ] || { err "$f missing"; continue; }
  n=$(grep -c '^### \[' "$DIR/$f" || true)
  [ "$n" -gt 5 ] && err "$f: $n entries (max 5) — distill oldest into Long-Term Memory or archive/"
done

# 2. TASKS.md Done section cap
if [ -f "$DIR/TASKS.md" ]; then
  n=$(awk '/^## Done/{d=1;next} /^## /{d=0} d && /^- \[x\]/' "$DIR/TASKS.md" | wc -l)
  [ "$n" -gt 5 ] && err "TASKS.md: $n done items (max 5) — archive older ones"
fi

# 3. SYNC_LOG daily blocks (max 7, one block per date)
if [ -f "$DIR/SYNC_LOG.md" ]; then
  n=$(grep -c '^## [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$' "$DIR/SYNC_LOG.md" || true)
  [ "$n" -gt 7 ] && err "SYNC_LOG.md: $n daily blocks (max 7) — move older whole-day blocks to archive/SYNC_LOG-YYYY-MM.md"
  dupes=$(grep '^## [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$' "$DIR/SYNC_LOG.md" | sort | uniq -d || true)
  [ -n "$dupes" ] && err "SYNC_LOG.md has duplicate date block(s):
$dupes"
  badlog=$(grep '^- ' "$DIR/SYNC_LOG.md" \
    | grep -vE '^- \[[0-9]{2}:[0-9]{2}\] \[[A-Za-z][A-Za-z0-9_-]*\] \[[^]]+\] .+' || true)
  [ -n "$badlog" ] && err "malformed SYNC_LOG bullet(s):
$badlog"
  heavy=$(awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}$/{if(d!="" && c>15) print d" ("c" bullets)"; d=$2; c=0; next} /^- /{c++} END{if(d!="" && c>15) print d" ("c" bullets)"}' "$DIR/SYNC_LOG.md")
  [ -n "$heavy" ] && err "SYNC_LOG.md block(s) over 15 bullets — condense them:
$heavy"
fi

# 4. Entry header format: ### [YYYY-MM-DD HH:MM] [Agent] Title
bad=$(grep -h '^### \[' "$DIR"/DECISIONS.md "$DIR"/LEARNINGS.md 2>/dev/null \
  | grep -vE '^### \[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\] \[[A-Za-z]+\] .+' || true)
[ -n "$bad" ] && err "malformed entry header(s):
$bad"

# 5. Secrets scan
hits=$(grep -rniE '(api[_-]?key|secret|passwd|password|credential)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9_/+-]{8,}|sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN .*PRIVATE KEY' \
  "$DIR" --include='*.md' 2>/dev/null || true)
[ -n "$hits" ] && err "possible secrets in memory — REMOVE them:
$hits"

# 6. PROJECT.md Long-Term Memory size (~30 lines)
if [ -f "$DIR/PROJECT.md" ]; then
  n=$(awk '/^## Long-Term Memory/{l=1;next} /^## /{l=0} l' "$DIR/PROJECT.md" | grep -vc '^\s*$' || true)
  [ "$n" -gt 30 ] && err "PROJECT.md Long-Term Memory: $n lines (max ~30) — rewrite more densely"
fi

# 7. Write lock shape (it is OK for the current writer to hold the lock while linting)
if [ -d "$DIR/.write.lock" ] && [ ! -f "$DIR/.write.lock/owner" ]; then
  err "AI_MEMORY/.write.lock exists without owner file"
fi

# 8. Boot layer health (required files + exactly one SHAREMEMORY block per boot file)
ROOT="$(dirname "$DIR")"
for f in MEMORY_PROTOCOL.md CLAUDE.md AGENTS.md scripts/check_memory.sh; do
  [ -e "$ROOT/$f" ] || err "$f missing — run 'repair memory'"
done
[ -x "$ROOT/scripts/check_memory.sh" ] || err "scripts/check_memory.sh is not executable — run 'chmod +x scripts/check_memory.sh'"
for f in CLAUDE.md AGENTS.md; do
  if [ -f "$ROOT/$f" ]; then
    s=$(grep -c 'SHAREMEMORY:START' "$ROOT/$f" || true)
    e=$(grep -c 'SHAREMEMORY:END' "$ROOT/$f" || true)
    [ "$s" != "$e" ] && err "$f: unbalanced SHAREMEMORY markers ($s START / $e END)"
    [ "$s" -gt 1 ] && err "$f: $s SHAREMEMORY blocks (max 1) — run 'repair memory'"
    [ "$s" -eq 0 ] && err "$f: no SHAREMEMORY block — run 'repair memory'"
  fi
done

# 9. CLAUDE.md must import AGENTS.md
if [ -f "$ROOT/CLAUDE.md" ] && ! grep -q '^@AGENTS\.md' "$ROOT/CLAUDE.md"; then
  err "CLAUDE.md missing the @AGENTS.md import — run 'repair memory'"
fi

[ "$fail" -eq 0 ] && echo "✓ memory OK"
exit "$fail"
