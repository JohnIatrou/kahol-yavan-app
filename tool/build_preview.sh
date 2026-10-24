#!/usr/bin/env bash
# Builds the browser preview (phone + TV) into a checkout of JohnIatrou/kahol-yavan-preview,
# which GitHub Pages serves at https://johniatrou.github.io/kahol-yavan-preview/.
# Usage: tool/build_preview.sh <preview-checkout> [flutter]
set -euo pipefail
out=${1:?preview checkout}
flutter=${2:-flutter}
# Each build gets new script URLs, so browsers do not keep showing the previous one from their cache.
stamp=$(date +%s)
for v in phone tv; do
  extra=()
  [ "$v" = tv ] && extra=(--dart-define=FORCE_TV=true)
  rm -rf "$out/$v"
  "$flutter" build web --release --no-web-resources-cdn --base-href "/kahol-yavan-preview/$v/" \
    --dart-define=BASE_URL=https://leylotyavan.co.il "${extra[@]}" -o "$out/$v"
  # Only CanvasKit is used; the other renderers and debug symbols are 20 MB nobody downloads.
  rm -rf "$out/$v"/canvaskit/{skwasm*,wimp*,webparagraph,*.symbols} "$out/$v"/canvaskit/chromium/*.symbols
  sed -i 's|<title>[^<]*</title>|<title>רדיו כחול יוון</title>|; s|flutter_bootstrap.js"|flutter_bootstrap.js?v='"$stamp"'"|' "$out/$v/index.html"
  sed -i 's|"mainJsPath":"main.dart.js"|"mainJsPath":"main.dart.js?v='"$stamp"'"|' "$out/$v/flutter_bootstrap.js"
  grep -q "main.dart.js?v=$stamp" "$out/$v/flutter_bootstrap.js"
done
# The frame page points at this build too, so a refresh always shows it.
sed -i -E 's#src="(phone|tv)/[^"]*"#src="\1/?v='"$stamp"'"#' "$out/index.html"
