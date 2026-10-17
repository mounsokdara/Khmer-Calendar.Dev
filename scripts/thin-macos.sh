#!/usr/bin/env bash
# Reduce a universal macOS .app to a single architecture (every Mach-O inside the bundle),
# so we can ship one package for Apple Silicon (arm64) and one for Intel (x86_64).
# Run it BEFORE codesign: thinning changes the binaries and invalidates any signature.
#
# Usage: thin-macos.sh <App.app> <arm64|x86_64>
set -euo pipefail
APP="${1:?path to the .app bundle}"; ARCH="${2:?arm64 or x86_64}"
case "$ARCH" in arm64|x86_64) ;; *) echo "arch must be arm64 or x86_64" >&2; exit 1;; esac
[ -d "$APP" ] || { echo "app bundle not found: $APP" >&2; exit 1; }

thinned=0
while IFS= read -r -d '' f; do
  archs=$(lipo -archs "$f" 2>/dev/null) || continue          # not a Mach-O file
  case " $archs " in
    *" $ARCH "*) ;;
    *) echo "::error::$f has no $ARCH slice (has: $archs)"; exit 1;;
  esac
  [ "$archs" = "$ARCH" ] && continue                          # already single-arch
  lipo -thin "$ARCH" "$f" -output "$f.thin"
  cat "$f.thin" > "$f"                                         # keeps the file mode (executable bit)
  rm -f "$f.thin"
  thinned=$((thinned + 1))
done < <(find "$APP" -type f -print0)
echo "thinned $thinned file(s) to $ARCH"

# Verify: every Mach-O left must be exactly $ARCH.
bad=0
while IFS= read -r -d '' f; do
  archs=$(lipo -archs "$f" 2>/dev/null) || continue
  if [ "$archs" != "$ARCH" ]; then echo "::error::$f is still: $archs"; bad=1; fi
done < <(find "$APP" -type f -print0)
[ "$bad" = 0 ] || exit 1
echo "OK: $APP is $ARCH only"
