#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/tests" "$ROOT/.build/ModuleCache"
bash "$ROOT/scripts/build-engine.sh"
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$ROOT/.build/ModuleCache" \
  "$ROOT/Sources/AstraCore/AstrologEngine.swift" "$ROOT/Sources/AstraCore/ChartPreferences.swift" \
  "$ROOT/Sources/AstraCore/Localization.swift" "$ROOT/Tests/BundleEngineTests.swift" \
  -o "$ROOT/.build/tests/BundleEngineTests"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/AstraGlass-bundle-tests.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
for LOCATION in Helpers Resources/Engine; do
  APP="$FIXTURE/Relocated app with spaces/AstraGlass.app"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Engine" "$APP/Contents/$LOCATION"
  cp "$ROOT/.build/tests/BundleEngineTests" "$APP/Contents/MacOS/BundleEngineTests"
  cp "$ROOT/Engine/bin/astrolog" "$APP/Contents/$LOCATION/astrolog"
  cp "$ROOT/Upstream/Astrolog/astrolog.as" "$ROOT/Upstream/Astrolog/seorbel.txt" "$ROOT/Upstream/Astrolog/sefstars.txt" "$APP/Contents/Resources/Engine/"
  chmod 755 "$APP/Contents/MacOS/BundleEngineTests" "$APP/Contents/$LOCATION/astrolog"
  (cd /tmp && "$APP/Contents/MacOS/BundleEngineTests")
  rm -f "$APP/Contents/$LOCATION/astrolog"
done
