#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/tests" "$ROOT/.build/ModuleCache" "$ROOT/docs/validation"
bash "$ROOT/scripts/build-engine.sh"
RESULT="core-tests.json"
if [[ "$(uname -s)" != Darwin ]]; then RESULT="core-tests-linux.json"; fi
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$ROOT/.build/ModuleCache" \
  "$ROOT/Sources/AstraCore/AstrologEngine.swift" "$ROOT/Sources/AstraCore/ChartPreferences.swift" "$ROOT/Sources/AstraCore/Localization.swift" "$ROOT/Sources/AstraCore/InterpretationLibrary.swift" "$ROOT/Tests/CoreTests.swift" \
  -o "$ROOT/.build/tests/CoreTests"
"$ROOT/.build/tests/CoreTests" "$ROOT" | tee "$ROOT/docs/validation/$RESULT"
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$ROOT/.build/ModuleCache" \
  "$ROOT/Sources/AstraCore/AstrologEngine.swift" "$ROOT/Sources/AstraCore/ChartPreferences.swift" \
  "$ROOT/Sources/AstraCore/Localization.swift" "$ROOT/Sources/AstraCore/CityAtlas.swift" \
  "$ROOT/Tests/CityAtlasTests.swift" -o "$ROOT/.build/tests/CityAtlasTests"
CITY_RESULT="city-atlas.json"
if [[ "$(uname -s)" != Darwin ]]; then CITY_RESULT="city-atlas-linux.json"; fi
"$ROOT/.build/tests/CityAtlasTests" "$ROOT" | tee "$ROOT/docs/validation/$CITY_RESULT"
