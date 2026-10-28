#!/bin/bash
# Khmer Calendar dev updater for macOS (same job as update.dart, but the package is a .dmg with the .app inside).
#
#   update-macos.sh --pid 123 --app-dir "/Applications/Khmer Calendar.app" --archive KhmerCalendar-macos-arm64.dmg \
#                   [--stamp <file> --built-at <iso time> --sha <commit>]
#
# Waits for the app to quit, replaces the .app bundle, writes the stamp file, opens the new app.
# Log: $TMPDIR/khmer_update.log. If anything fails the old app is opened again.
set -u
LOG="${TMPDIR:-/tmp}/khmer_update.log"
say() { echo "$(date '+%Y-%m-%dT%H:%M:%S') $*" >> "$LOG"; }

PID=""; APP=""; ARCHIVE=""; STAMP=""; BUILT_AT=""; SHA=""
while [ $# -ge 2 ]; do
  case "$1" in
    --pid) PID="$2" ;; --app-dir) APP="$2" ;; --archive) ARCHIVE="$2" ;;
    --stamp) STAMP="$2" ;; --built-at) BUILT_AT="$2" ;; --sha) SHA="$2" ;;
  esac
  shift 2
done
[ -n "$PID" ] && [ -n "$APP" ] && [ -n "$ARCHIVE" ] || { say "missing arguments"; exit 2; }
say "--- update start: pid=$PID app=$APP archive=$ARCHIVE"

MNT=""
cleanup() { [ -n "$MNT" ] && hdiutil detach "$MNT" -quiet -force >/dev/null 2>&1; rm -rf "$APP.new"; }
fail() { say "update FAILED: $*"; cleanup; open "$APP" >/dev/null 2>&1; exit 1; }

for _ in $(seq 1 300); do kill -0 "$PID" 2>/dev/null || break; sleep 0.3; done
kill -0 "$PID" 2>/dev/null && fail "the app (pid $PID) did not quit in time"

MNT="$(mktemp -d /tmp/khmer_update_mnt.XXXXXX)"
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$ARCHIVE" -quiet || fail "could not open the disk image"
SRC="$(find "$MNT" -maxdepth 1 -name '*.app' | head -1)"
[ -n "$SRC" ] || fail "no .app inside the disk image"

ditto "$SRC" "$APP.new" || fail "could not copy the new app (is the folder writable?)"
xattr -dr com.apple.quarantine "$APP.new" >/dev/null 2>&1
rm -rf "$APP" && mv "$APP.new" "$APP" || fail "could not replace the old app"

if [ -n "$STAMP" ]; then
  mkdir -p "$(dirname "$STAMP")" && printf '{"builtAt":"%s","sha":"%s"}' "$BUILT_AT" "$SHA" > "$STAMP"
fi
cleanup
rm -f "$ARCHIVE"
say "update ok"
open "$APP" && say "app restarted"
