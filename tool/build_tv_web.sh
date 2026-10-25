#!/usr/bin/env bash
# Builds the TV app as a web app and packs it for Samsung (Tizen, .wgt) and LG (webOS, .ipk).
# Usage: tool/build_tv_web.sh [flutter] [ares-package]
# Output: build/tv-web/kahol-yavan.wgt (unsigned: sign it with the Samsung certificate) and build/tv-web/*.ipk
set -euo pipefail
flutter=${1:-flutter}
ares=${2:-ares-package}
cd "$(dirname "$0")/.."
version=$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)
out=build/tv-web
rm -rf "$out"
"$flutter" build web --release --no-web-resources-cdn --dart-define=FORCE_TV=true -o "$out/app"
app=$out/app
# Only CanvasKit is used (see build_preview.sh).
rm -rf "$app"/canvaskit/{skwasm*,wimp*,webparagraph,*.symbols} "$app"/canvaskit/chromium/*.symbols "$app"/flutter_service_worker.js
# The TVs open the app from a local folder, not from the site root.
sed -i 's|<base href="/">|<base href="./">|; s|<title>[^<]*</title>|<title>רדיו כחול יוון</title>|' "$app/index.html"
cp tv-web/tv-boot.js "$app/"
sed -i 's|</head>|  <script src="tv-boot.js"></script>\n</head>|' "$app/index.html"
grep -q tv-boot.js "$app/index.html"

# Samsung
cp -r "$app" "$out/tizen"
sed "s/@VERSION@/$version/" tv-web/tizen/config.xml > "$out/tizen/config.xml"
cp tv-web/icons/icon-512.png "$out/tizen/icon.png"
(cd "$out/tizen" && zip -qr ../kahol-yavan.wgt .)

# LG
cp -r "$app" "$out/webos"
sed "s/@VERSION@/$version/" tv-web/webos/appinfo.json > "$out/webos/appinfo.json"
cp tv-web/icons/icon-80.png "$out/webos/icon.png"
cp tv-web/icons/icon-130.png "$out/webos/largeIcon.png"
"$ares" -o "$out" "$out/webos"
ls -la "$out"/*.wgt "$out"/*.ipk
