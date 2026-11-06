#!/bin/bash
# Khmer Calendar dev updater for macOS (same job as update.dart, but the package is a .dmg with the .app inside).
#
# 1) Started by the app (About > Check for updates):
#   update-macos.sh --pid 123 --app-dir "/Applications/Khmer Calendar.app" --archive KhmerCalendar-macos-arm64.dmg \
#                   [--stamp <file> --built-at <iso time> --sha <commit>]
#
# 2) Standalone (download KhmerCalendar-Updater-macos.command from the release and open it, the app does not
#    need to be started). It finds the installed app (or asks), checks the installed version against the latest,
#    downloads the right .dmg, closes the app and updates it:
#   KhmerCalendar-Updater-macos.command [--app-dir "<path to .app>"] [--force-update 1]
#
# Waits for the app to quit, tells the user which program is still running from the app (Retry / Force close /
# Force as administrator / Cancel), replaces the .app bundle, writes the stamp file, opens the new app.
# If something fails the old app is opened again and <stamp folder>/update_result.json tells the app why.
# Log: $TMPDIR/khmer_update.log
set -u
LOG="${TMPDIR:-/tmp}/khmer_update.log"
REPO="mounsokdara/Khmer-Calendar.Dev"
TITLE="Khmer Calendar update"
say() { echo "$(date '+%Y-%m-%dT%H:%M:%S') $*" >> "$LOG"; echo "$*"; }

PID=""; APP=""; ARCHIVE=""; STAMP=""; BUILT_AT=""; SHA=""; FORCE_UPDATE=""
while [ $# -ge 2 ]; do
  case "$1" in
    --pid) PID="$2" ;; --app-dir) APP="$2" ;; --archive) ARCHIVE="$2" ;;
    --stamp) STAMP="$2" ;; --built-at) BUILT_AT="$2" ;; --sha) SHA="$2" ;;
    --force-update) FORCE_UPDATE="$2" ;;
  esac
  shift 2
done
STANDALONE=0
[ -z "$PID" ] && [ -z "$ARCHIVE" ] && STANDALONE=1

MNT=""
BLOCKED=""   # lines "pid|name" of programs that kept the update from running

# ---------------------------------------------------------------- dialogs
# dialog "<message>" <mode>  ->  prints retry | force | admin | cancel
# mode 0 = Retry / Cancel, 1 = adds Force close, 2 = adds Force as administrator (a normal force close failed)
dialog() {
  local out buttons
  case "${2:-0}" in
    1) buttons='{"Cancel", "Force close", "Retry"}' ;;
    2) buttons='{"Cancel", "Force as administrator", "Retry"}' ;;
    *) buttons='{"Cancel", "Retry"}' ;;
  esac
  out="$(osascript -e 'on run argv' \
    -e "button returned of (display dialog (item 1 of argv) with title (item 2 of argv) buttons $buttons default button \"Retry\" with icon caution)" \
    -e 'end run' "$1" "$TITLE" 2>/dev/null)" || { echo cancel; return; }
  case "$out" in Retry) echo retry ;; "Force close") echo force ;; "Force as administrator") echo admin ;; *) echo cancel ;; esac
}

# confirm "<message>"  ->  exit 0 for Reinstall, 1 for Cancel
confirm() {
  osascript -e 'on run argv' \
    -e 'display dialog (item 1 of argv) with title (item 2 of argv) buttons {"Cancel", "Reinstall"} default button "Cancel" with icon note' \
    -e 'end run' "$1" "$TITLE" >/dev/null 2>&1
}

notify() {
  osascript -e 'on run argv' \
    -e 'display dialog (item 1 of argv) with title (item 2 of argv) buttons {"OK"} default button "OK" with icon note' \
    -e 'end run' "$1" "$TITLE" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- failure report for the app
RESULT=""
[ -n "$STAMP" ] && RESULT="$(dirname "$STAMP")/update_result.json"

json_str() { printf '%s' "$1" | tr -d '"\\' | tr '\n\t' '  '; }

write_result() { # <reason: locked|error> <detail>
  [ -n "$RESULT" ] || return 0
  local procs="" line first=1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ $first -eq 1 ] || procs="$procs,"
    first=0
    procs="$procs\"$(json_str "${line#*|} (pid ${line%%|*})")\""
  done <<EOF
$BLOCKED
EOF
  mkdir -p "$(dirname "$RESULT")" 2>/dev/null
  printf '{"status":"failed","reason":"%s","files":[],"processes":[%s],"detail":"%s","at":"%s"}' \
    "$1" "$procs" "$(json_str "$2")" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$RESULT" 2>/dev/null
}

cleanup() { [ -n "$MNT" ] && hdiutil detach "$MNT" -quiet -force >/dev/null 2>&1; [ -n "$APP" ] && rm -rf "$APP.new"; }

fail() {
  say "update FAILED: $*"
  if [ -n "$BLOCKED" ]; then write_result locked "$*"; else write_result error "$*"; fi
  cleanup
  [ -n "$APP" ] && [ -d "$APP" ] && open "$APP" >/dev/null 2>&1
  [ "$STANDALONE" = "1" ] && notify "The update did not finish.

$*

Your current version is unchanged."
  exit 1
}

# ---------------------------------------------------------------- which program is using the app?
# Programs running from inside the app bundle (for example a second copy), never this script.
app_users() {
  local p name
  for p in $(pgrep -f "$APP/Contents/" 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    name="$(ps -o comm= -p "$p" 2>/dev/null | sed 's#.*/##')"
    [ -n "$name" ] && echo "$p|$name"
  done
}

# Wait until nothing runs from the app; otherwise show which program it is and let the user
# close it (Retry), have it closed (Force close, then Force as administrator if that was not
# enough) or stop (Cancel). Returns 1 when it gave up.
ensure_free() {
  local asked=0 users names choice p mode ids force_tried=0 stuck note
  while :; do
    users="$(app_users)"
    [ -z "$users" ] && return 0
    say "still running from the app: $(echo "$users" | tr '\n' ' ')"
    BLOCKED="$users"
    [ "$asked" -ge 5 ] && return 1
    names="$(echo "$users" | awk -F'|' '{printf "  - %s (pid %s)\n", $2, $1}')"
    mode=1; note=""
    if [ "$force_tried" = "1" ]; then
      mode=2
      note="

Force close could not close it. Click Force as administrator to try with administrator rights (macOS asks for your password)."
    fi
    choice="$(dialog "The update could not be installed because the app is still running.

Programs using the app files:
$names

Close it and click Retry, or have the updater close it for you (unsaved work in it is lost).$note" "$mode")"
    asked=$((asked + 1))
    ids="$(echo "$users" | cut -d'|' -f1 | tr '\n' ' ')"
    case "$choice" in
      retry) sleep 1 ;;
      force)
        for p in $ids; do say "force closing pid $p"; kill -9 "$p" 2>/dev/null; done
        force_tried=1; sleep 1.5 ;;
      admin)
        say "force closing as administrator: $ids"
        osascript -e 'on run argv' -e 'do shell script ("kill -9 " & (item 1 of argv)) with administrator privileges' -e 'end run' "$ids" >/dev/null 2>&1
        sleep 1.5 ;;
      *) return 1 ;;
    esac
  done
}

# ---------------------------------------------------------------- version check
# prints -1, 0 or 1 for "$1 compared with $2" (dotted versions)
vcmp() {
  [ "$1" = "$2" ] && { echo 0; return; }
  if [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | head -1)" = "$1" ]; then echo -1; else echo 1; fi
}

curl_text() { curl -fsSL --max-time 30 -A khmer-calendar-updater "$@"; }

# ---------------------------------------------------------------- standalone: find, check, download
standalone_prepare() {
  say "--- standalone update start"
  local c
  if [ -z "$APP" ]; then
    for c in "/Applications/Khmer Calendar.app" "$HOME/Applications/Khmer Calendar.app"; do
      [ -d "$c" ] && APP="$c" && break
    done
  fi
  [ -n "$APP" ] || APP="$(find /Applications "$HOME/Applications" -maxdepth 1 -iname 'khmer*calendar*.app' 2>/dev/null | head -1)"
  if [ -z "$APP" ]; then
    APP="$(osascript -e 'POSIX path of (choose file of type {"app"} with prompt "Select Khmer Calendar.app")' 2>/dev/null | sed 's#/$##')"
  fi
  if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    notify "Khmer Calendar was not found.

Open the updater again and select Khmer Calendar.app, or start it with --app-dir \"/path/to/Khmer Calendar.app\"."
    exit 2
  fi
  say "app: $APP"

  local bid
  bid="$(defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null)"
  [ -n "$bid" ] && STAMP="$HOME/Library/Application Support/$bid/updatebuild.json" && RESULT="$(dirname "$STAMP")/update_result.json"

  say "checking the latest version..."
  local vt ver code rel arch cand url="" got="" inst_v inst_c cmp
  vt="$(curl_text "https://raw.githubusercontent.com/$REPO/main/version.txt?cb=$(date +%s)")" || fail "Could not read version.txt (no internet?)."
  ver="$(printf '%s\n' "$vt" | sed -n 's/^[[:space:]]*versionName[[:space:]]*=[[:space:]]*//p' | head -1 | tr -d '\r ')"
  code="$(printf '%s\n' "$vt" | sed -n 's/^[[:space:]]*versionCode[[:space:]]*=[[:space:]]*//p' | head -1 | tr -d '\r ')"
  [ -n "$ver" ] || fail "version.txt has no versionName."

  # Is there anything newer than what is installed?
  inst_v="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
  inst_c="$(defaults read "$APP/Contents/Info" CFBundleVersion 2>/dev/null)"
  if [ -n "$inst_v" ] && [ -z "$FORCE_UPDATE" ]; then
    cmp="$(vcmp "$ver" "$inst_v")"
    if [ "$cmp" = "-1" ]; then
      notify "Your version (v$inst_v) is newer than the published one (v$ver). No update is needed."; exit 0
    elif [ "$cmp" = "0" ]; then
      if [ -n "$inst_c" ] && [ -n "$code" ] && [ "$code" -gt "$inst_c" ] 2>/dev/null; then :
      elif [ -n "$inst_c" ] && [ -n "$code" ] && [ "$code" -lt "$inst_c" ] 2>/dev/null; then
        notify "Your build ($inst_c) is newer than the published one ($code). No update is needed."; exit 0
      else
        # same version and build: ask before reinstalling
        say "same version (v$inst_v), asking to reinstall"
        confirm "You already have the latest version (v$inst_v).

Do you want to reinstall it anyway?" || { say "reinstall declined"; exit 0; }
      fi
    fi
  fi

  [ "$(uname -m)" = "arm64" ] && arch="arm64" || arch="x86_64"
  rel="$(curl_text -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/releases/tags/v$ver" 2>/dev/null)"
  for cand in "$arch" universal; do
    if [ -n "$rel" ]; then
      url="$(printf '%s' "$rel" | grep -o "\"browser_download_url\": *\"[^\"]*KhmerCalendar-macos-$cand\.dmg\"" | head -1 | sed 's/.*: *"//; s/"$//')"
    else
      url="https://github.com/$REPO/releases/download/v$ver/KhmerCalendar-macos-$cand.dmg" # API rate limited: direct link
    fi
    [ -n "$url" ] && got="$cand" && break
  done
  [ -n "$url" ] || fail "No macOS package in release v$ver yet. It may still be publishing, try again in a few minutes."

  local dl="${TMPDIR:-/tmp}/khmer_update_dl"
  rm -rf "$dl"; mkdir -p "$dl"
  ARCHIVE="$dl/KhmerCalendar-macos-$got.dmg"
  say "downloading KhmerCalendar-macos-$got.dmg (v$ver)..."
  curl -fL --max-time 900 -A khmer-calendar-updater -o "$ARCHIVE" "$url" || fail "Download failed. Check your internet connection and try again."
  BUILT_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  # Ask the app to quit nicely; ensure_free below handles anything still running.
  local appname
  appname="$(basename "$APP" .app)"
  if [ -n "$(app_users)" ]; then
    say "asking $appname to quit..."
    osascript -e "tell application \"$appname\" to quit" >/dev/null 2>&1
    for _ in $(seq 1 25); do [ -z "$(app_users)" ] && break; sleep 0.4; done
  fi
}

# ---------------------------------------------------------------- main
[ "$STANDALONE" = "1" ] && standalone_prepare
[ -n "$APP" ] && [ -n "$ARCHIVE" ] || { say "missing arguments"; exit 2; }
say "--- update start: pid=${PID:-none} app=$APP archive=$ARCHIVE"

if [ -n "$PID" ]; then
  for _ in $(seq 1 300); do kill -0 "$PID" 2>/dev/null || break; sleep 0.3; done
  kill -0 "$PID" 2>/dev/null && { BLOCKED="$PID|the app"; fail "the app (pid $PID) did not quit in time"; }
fi

ensure_free || fail "Another program is still using the app files."
BLOCKED=""

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
[ -n "$RESULT" ] && rm -f "$RESULT"
cleanup
rm -f "$ARCHIVE"
say "update ok"
open "$APP" && say "app restarted"
