#!/usr/bin/env bash
# Regenerates the README and pub.dev imagery in ../../assets/readme/.
#
#   tool/readme_media/generate.sh                 # render screens, then compose everything
#   tool/readme_media/generate.sh --scenes        # also re-render the camera scenes first
#   tool/readme_media/generate.sh hero demo       # compose only these (hero, gallery, pubdev, demo)
#
# Environment (all optional):
#   FLUTTER          flutter executable            (default: flutter on PATH)
#   CWEBP, IMG2WEBP  libwebp encoders              (default: cwebp / img2webp on PATH)
#   CHROMIUM_PATH    a Chromium/Chrome binary to use instead of Playwright's own
#   PLAYWRIGHT_BROWSERS_PATH  where Playwright keeps its browsers (Playwright's default)
#   SKIP_BROWSER_INSTALL=1    don't run `npx playwright install chromium`
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

flutter_bin="${FLUTTER:-flutter}"
scenes=0
parts=()
for arg in "$@"; do
  case "$arg" in
    --scenes) scenes=1 ;;
    -h | --help) sed -n '2,15p' "$0"; exit 0 ;;
    *) parts+=("$arg") ;;
  esac
done

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: '$1' not found. $2" >&2
    exit 1
  fi
}
need "$flutter_bin" "Install Flutter or set FLUTTER=/path/to/flutter."
need node "Install Node.js 18 or newer."
need npm "Install Node.js 18 or newer."
need "${CWEBP:-cwebp}" "Install libwebp (brew install webp / apt install webp) or set CWEBP."
need "${IMG2WEBP:-img2webp}" "Install libwebp (brew install webp / apt install webp) or set IMG2WEBP."

echo "==> Installing compositor dependencies"
(
  cd compose
  if [ ! -d node_modules ]; then npm ci; fi
  if [ -z "${CHROMIUM_PATH:-}" ] && [ "${SKIP_BROWSER_INSTALL:-0}" != 1 ]; then
    npx --no-install playwright install chromium
  fi
)

if [ "$scenes" = 1 ]; then
  echo "==> Rendering camera scenes (assets/scene_*.jpg)"
  (cd compose && node scenes.mjs)
fi

echo "==> Rendering screens from the package's widgets (build/screens)"
"$flutter_bin" pub get
rm -rf build/screens
"$flutter_bin" test test/render_test.dart

echo "==> Composing images (assets/readme)"
(cd compose && node compose.mjs ${parts[@]+"${parts[@]}"})

echo "==> Done"
ls -l ../../assets/readme
