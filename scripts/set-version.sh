#!/usr/bin/env bash
# One command to bump the app version everywhere, so version.txt can never drift from the app again.
#
#   scripts/set-version.sh 1.0.5 6     # versionName 1.0.5, versionCode 6
#   scripts/set-version.sh --check     # fail if the files below disagree
#
# Files kept in sync:
#   version.txt                         (versionName / versionCode: read by the in-app update check,
#                                        the website and F-Droid UpdateCheckData)
#   khmer_calendar/pubspec.yaml         (version: NAME+CODE: used by Flutter and the Android build)
#   khmer_calendar/lib/theme.dart       (appVersion constant shown in About)
#   fastlane/.../changelogs/CODE.txt    (stub is created if missing)
set -euo pipefail
cd "$(dirname "$0")/.."

PUBSPEC=khmer_calendar/pubspec.yaml
THEME=khmer_calendar/lib/theme.dart
CHANGELOGS=fastlane/metadata/android/en-US/changelogs

read_state() {
  PUB_NAME=$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\)+.*/\1/p' "$PUBSPEC" | head -1)
  PUB_CODE=$(sed -n 's/^version:[[:space:]]*[0-9][0-9.]*+\([0-9]*\).*/\1/p' "$PUBSPEC" | head -1)
  TXT_NAME=$(sed -n 's/^versionName=//p' version.txt | head -1)
  TXT_CODE=$(sed -n 's/^versionCode=//p' version.txt | head -1)
  APP_NAME=$(sed -n "s/^const appVersion = '\([^']*\)';.*/\1/p" "$THEME" | head -1)
}

check() {
  read_state
  echo "pubspec.yaml : $PUB_NAME+$PUB_CODE"
  echo "version.txt  : $TXT_NAME+$TXT_CODE"
  echo "theme.dart   : $APP_NAME"
  if [ "$PUB_NAME" != "$TXT_NAME" ] || [ "$PUB_CODE" != "$TXT_CODE" ] || [ "$PUB_NAME" != "$APP_NAME" ]; then
    echo "MISMATCH: run scripts/set-version.sh <name> <code>" >&2
    return 1
  fi
  echo "OK: all version files agree"
}

if [ "${1:-}" = "--check" ]; then check; exit $?; fi

NAME="${1:?usage: set-version.sh <versionName> <versionCode> | --check}"
CODE="${2:?usage: set-version.sh <versionName> <versionCode> | --check}"
[[ "$NAME" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || { echo "versionName must look like 1.2.3" >&2; exit 1; }
[[ "$CODE" =~ ^[0-9]+$ ]] || { echo "versionCode must be a number" >&2; exit 1; }

printf 'versionName=%s\nversionCode=%s\n' "$NAME" "$CODE" > version.txt
sed -i "s/^version:[[:space:]]*[0-9][0-9.]*+[0-9]*/version: $NAME+$CODE/" "$PUBSPEC"
sed -i "s/^const appVersion = '[^']*';/const appVersion = '$NAME';/" "$THEME"
mkdir -p "$CHANGELOGS"
[ -f "$CHANGELOGS/$CODE.txt" ] || printf 'Khmer Calendar %s\n- \n' "$NAME" > "$CHANGELOGS/$CODE.txt"
check
echo "Remember: write the notes in .github/release-body.md and $CHANGELOGS/$CODE.txt"
