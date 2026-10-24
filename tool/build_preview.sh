#!/usr/bin/env bash
# Builds the browser preview (phone + TV) into a checkout of JohnIatrou/kahol-yavan-preview,
# which GitHub Pages serves at https://johniatrou.github.io/kahol-yavan-preview/.
# Usage: tool/build_preview.sh <preview-checkout> [flutter]
set -euo pipefail
out=${1:?preview checkout}
flutter=${2:-flutter}
for v in phone tv; do
  extra=()
  [ "$v" = tv ] && extra=(--dart-define=FORCE_TV=true)
  rm -rf "$out/$v"
  "$flutter" build web --release --no-web-resources-cdn --base-href "/kahol-yavan-preview/$v/" \
    --dart-define=BASE_URL=https://leylotyavan.co.il "${extra[@]}" -o "$out/$v"
  # Only CanvasKit is used; the other renderers and debug symbols are 20 MB nobody downloads.
  rm -rf "$out/$v"/canvaskit/{skwasm*,wimp*,webparagraph,*.symbols} "$out/$v"/canvaskit/chromium/*.symbols
  sed -i 's|<title>[^<]*</title>|<title>רדיו כחול יוון</title>|' "$out/$v/index.html"
done
