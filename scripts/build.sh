#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then echo "AstraGlass requires macOS to build its SwiftUI application." >&2; exit 1; fi
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache"
export SWIFT_MODULECACHE_PATH="$ROOT/.build/swift-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"
bash "$ROOT/scripts/build-engine.sh"
BUILD_OUTPUT="${ASTRAGLASS_BUILD_DIR:-/tmp/AstraGlass-release}"
INCLUDE_CORPUS="${ASTRAGLASS_INCLUDE_CORPUS:-1}"
if [[ "$INCLUDE_CORPUS" != 0 && "$INCLUDE_CORPUS" != 1 ]]; then
  echo 'ASTRAGLASS_INCLUDE_CORPUS must be 0 or 1.' >&2
  exit 1
fi
APP="$BUILD_OUTPUT/AstraGlass.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources/Engine"
swiftc -O -swift-version 6 -parse-as-library -target arm64-apple-macos27.0 \
  -module-cache-path "$SWIFT_MODULECACHE_PATH" \
  "$ROOT"/Sources/AstraCore/*.swift "$ROOT"/Sources/AstraApp/*.swift \
  -o "$APP/Contents/MacOS/AstraGlass" -framework SwiftUI -framework AppKit
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Engine/bin/astrolog" "$APP/Contents/Helpers/astrolog"
chmod 755 "$APP/Contents/Helpers/astrolog" "$APP/Contents/MacOS/AstraGlass"
rm -f "$APP/Contents/Resources/Engine/astrolog"
cp -R "$ROOT/Resources/en.lproj" "$ROOT/Resources/ru.lproj" "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/Fonts"
cp "$ROOT/Resources/Fonts/DejaVuSans.ttf" "$ROOT/Resources/Fonts/LICENSE-DejaVu.txt" "$APP/Contents/Resources/Fonts/"
cp "$ROOT/Upstream/Astrolog/astrolog.as" "$ROOT/Upstream/Astrolog/atlas.as" "$ROOT/Upstream/Astrolog/timezone.as" "$ROOT/Upstream/Astrolog/sefstars.txt" "$ROOT/Upstream/Astrolog/seorbel.txt" "$APP/Contents/Resources/Engine/"
rm -rf "$APP/Contents/Resources/Engine/ephem"
if [[ -d "$ROOT/Upstream/Astrolog/ephem" ]]; then cp -R "$ROOT/Upstream/Astrolog/ephem" "$APP/Contents/Resources/Engine/"; fi
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
cp "$ROOT/Upstream/Astrolog/license.htm" "$APP/Contents/Resources/Astrolog-License.htm"
cp "$ROOT/Upstream/Astrolog/astrolog.htm" "$APP/Contents/Resources/Astrolog-Manual.htm"
if [[ "$INCLUDE_CORPUS" == 1 && -f "$ROOT/Resources/interpretations.json" ]]; then cp "$ROOT/Resources/interpretations.json" "$APP/Contents/Resources/interpretations.json"; else rm -f "$APP/Contents/Resources/interpretations.json"; fi
rm -f "$APP/Contents/Resources/profile-request.json"
if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then bash "$ROOT/scripts/make-icon.sh"; fi
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
xattr -cr "$APP"
test -x "$APP/Contents/Helpers/astrolog"
codesign --force --sign - "$APP/Contents/Helpers/astrolog"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
python3 "$ROOT/scripts/check-bundle.py" "$APP"
printf '%s\n' "$APP"
