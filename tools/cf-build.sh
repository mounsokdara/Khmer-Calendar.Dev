#!/usr/bin/env bash
# Cloudflare Pages build. Runs on Cloudflare for every commit; the site is
# generated from source and nothing it produces is committed to the repo.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/khmer_calendar"

FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  # Same Flutter version the Release workflow uses; override with FLUTTER_VERSION.
  REF="${FLUTTER_VERSION:-3.47.4}"
  echo ">> Installing Flutter ($REF)"
  git clone --depth 1 --branch "$REF" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
git config --global --add safe.directory "$FLUTTER_DIR" >/dev/null 2>&1 || true
export PATH="$FLUTTER_DIR/bin:$PATH"
export CI=true
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version

cd "$APP"
flutter pub get
flutter build web --release --no-web-resources-cdn --base-href /

# version.txt (repo root) is served by the site so the web app can check for updates.
cp "$ROOT/version.txt" "$APP/build/web/version.txt"

# Inject the offline precache list into the service worker.
cd "$ROOT"
node scripts/offline-worker.mjs "$APP/build/web"

echo ">> Build done: $APP/build/web"
