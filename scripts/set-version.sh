#!/usr/bin/env bash
# Single source of truth: version.txt
#
#   scripts/set-version.sh 1.0.6 7          # write version.txt and sync the rest
#   scripts/set-version.sh --apply          # read version.txt -> pubspec.yaml + theme.dart
#   scripts/set-version.sh --check          # fail if anything drifts
#   scripts/set-version.sh --tag            # create/move local tag v<versionName> at HEAD
#   scripts/set-version.sh --tag-push       # same + force-push the tag to origin
#   scripts/set-version.sh 1.0.6 7 --tag    # bump, then tag
#
# Files:
#   version.txt                         versionName= / versionCode=
#   khmer_calendar/pubspec.yaml         version: NAME+CODE
#   khmer_calendar/lib/theme.dart       appVersion + appBuildNumber (About screen)
#   fastlane/.../changelogs/CODE.txt    stub created if missing (only on bump)
set -euo pipefail
cd "$(dirname "$0")/.."

PUBSPEC=khmer_calendar/pubspec.yaml
THEME=khmer_calendar/lib/theme.dart
CHANGELOGS=fastlane/metadata/android/en-US/changelogs

read_txt() {
  TXT_NAME=$(sed -n 's/^versionName=//p' version.txt | head -1 | tr -d '\r')
  TXT_CODE=$(sed -n 's/^versionCode=//p' version.txt | head -1 | tr -d '\r')
  [ -n "$TXT_NAME" ] && [ -n "$TXT_CODE" ] || {
    echo "version.txt must contain versionName= and versionCode=" >&2
    exit 1
  }
}

read_state() {
  read_txt
  PUB_NAME=$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\)+.*/\1/p' "$PUBSPEC" | head -1)
  PUB_CODE=$(sed -n 's/^version:[[:space:]]*[0-9][0-9.]*+\([0-9]*\).*/\1/p' "$PUBSPEC" | head -1)
  APP_NAME=$(sed -n "s/^const appVersion = '\([^']*\)';.*/\1/p" "$THEME" | head -1)
  APP_CODE=$(sed -n "s/^const appBuildNumber = \([0-9]*\);.*/\1/p" "$THEME" | head -1)
}

apply_from_txt() {
  read_txt
  [[ "$TXT_NAME" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || { echo "versionName must look like 1.2.3" >&2; exit 1; }
  [[ "$TXT_CODE" =~ ^[0-9]+$ ]] || { echo "versionCode must be a number" >&2; exit 1; }

  if grep -qE '^version:[[:space:]]*[0-9]' "$PUBSPEC"; then
    sed -i.bak "s/^version:[[:space:]]*[0-9][0-9.]*+[0-9]*/version: $TXT_NAME+$TXT_CODE/" "$PUBSPEC"
    rm -f "$PUBSPEC.bak"
  else
    echo "no version: line in $PUBSPEC" >&2; exit 1
  fi

  if grep -q "const appVersion = " "$THEME"; then
    sed -i.bak "s/^const appVersion = '[^']*';/const appVersion = '$TXT_NAME';/" "$THEME"
    rm -f "$THEME.bak"
  else
    echo "no appVersion in $THEME" >&2; exit 1
  fi
  if grep -q "const appBuildNumber = " "$THEME"; then
    sed -i.bak "s/^const appBuildNumber = [0-9]*;/const appBuildNumber = $TXT_CODE;/" "$THEME"
    rm -f "$THEME.bak"
  else
    echo "no appBuildNumber in $THEME" >&2; exit 1
  fi

  echo "applied version.txt -> $TXT_NAME+$TXT_CODE"
}

check() {
  read_state
  echo "version.txt  : $TXT_NAME+$TXT_CODE"
  echo "pubspec.yaml : $PUB_NAME+$PUB_CODE"
  echo "theme.dart   : $APP_NAME+$APP_CODE"
  if [ "$PUB_NAME" != "$TXT_NAME" ] || [ "$PUB_CODE" != "$TXT_CODE" ] ||
     [ "$APP_NAME" != "$TXT_NAME" ] || [ "$APP_CODE" != "$TXT_CODE" ]; then
    echo "MISMATCH: edit version.txt then run scripts/set-version.sh --apply" >&2
    return 1
  fi
  echo "OK: all version files agree"
}

# Create (or move) local annotated tag v<versionName> at HEAD.
tag_local() {
  read_txt
  TAG="v${TXT_NAME}"
  MSG="Khmer Calendar ${TXT_NAME} (build ${TXT_CODE})"
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "moving existing tag $TAG -> $(git rev-parse --short HEAD)"
    git tag -d "$TAG" >/dev/null
  fi
  git tag -a "$TAG" -m "$MSG"
  echo "tagged $TAG at $(git rev-parse --short HEAD)"
}

# Force-push the tag so origin points at the same commit.
tag_push() {
  read_txt
  TAG="v${TXT_NAME}"
  git rev-parse "$TAG" >/dev/null 2>&1 || { echo "no local tag $TAG; run --tag first" >&2; exit 1; }
  git push -f origin "refs/tags/$TAG"
  echo "pushed $TAG to origin"
}

DO_TAG=0
DO_TAG_PUSH=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --tag) DO_TAG=1 ;;
    --tag-push) DO_TAG=1; DO_TAG_PUSH=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

case "${1:-}" in
  --check)
    check
    exit $?
    ;;
  --apply)
    apply_from_txt
    check
    if [ "$DO_TAG" = 1 ]; then tag_local; fi
    if [ "$DO_TAG_PUSH" = 1 ]; then tag_push; fi
    exit 0
    ;;
  "")
    if [ "$DO_TAG" = 1 ]; then
      # tag only, from current version.txt
      check || true
      tag_local
      if [ "$DO_TAG_PUSH" = 1 ]; then tag_push; fi
      exit 0
    fi
    echo "usage: set-version.sh <versionName> <versionCode> [--tag] [--tag-push]" >&2
    echo "       set-version.sh --apply [--tag] [--tag-push]" >&2
    echo "       set-version.sh --check" >&2
    echo "       set-version.sh --tag | --tag-push" >&2
    exit 1
    ;;
esac

NAME="$1"
CODE="${2:?usage: set-version.sh <versionName> <versionCode> [--tag] [--tag-push]}"
[[ "$NAME" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || { echo "versionName must look like 1.2.3" >&2; exit 1; }
[[ "$CODE" =~ ^[0-9]+$ ]] || { echo "versionCode must be a number" >&2; exit 1; }

printf 'versionName=%s\nversionCode=%s\n' "$NAME" "$CODE" > version.txt
apply_from_txt
mkdir -p "$CHANGELOGS"
[ -f "$CHANGELOGS/$CODE.txt" ] || printf 'Khmer Calendar %s\n- \n' "$NAME" > "$CHANGELOGS/$CODE.txt"
check
if [ "$DO_TAG" = 1 ]; then tag_local; fi
if [ "$DO_TAG_PUSH" = 1 ]; then tag_push; fi
echo "Remember: write the notes in .github/release-body.md and $CHANGELOGS/$CODE.txt"
