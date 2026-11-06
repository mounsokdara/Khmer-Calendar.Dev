#!/bin/bash
# Khmer Calendar — macOS background service launcher (arch-independent).
# Lives at: Foo.app/Contents/MacOS/khmer-calendar-bg
# Starts the main app binary with --autostart (headless) and exits.
set -u

LOG="${TMPDIR:-/tmp}/khmer_calendar_bg.log"
say() { echo "$(date '+%Y-%m-%dT%H:%M:%S') $*" >> "$LOG" 2>/dev/null || true; }

SELF="${BASH_SOURCE[0]:-$0}"
DIR="$(cd "$(dirname "$SELF")" && pwd)"

# Prefer the main app executable in the same MacOS folder (not this script).
MAIN=""
for f in "$DIR"/*; do
  [ -f "$f" ] && [ -x "$f" ] || continue
  base="$(basename "$f")"
  case "$base" in
    khmer-calendar-bg|update-macos.sh) continue ;;
  esac
  # Skip if it looks like a shell script helper
  if head -1 "$f" 2>/dev/null | grep -q '^#!'; then
    continue
  fi
  MAIN="$f"
  break
done

if [ -z "$MAIN" ]; then
  say "main app binary not found in $DIR"
  exit 2
fi

say "starting headless: $MAIN --autostart"
exec "$MAIN" --autostart
