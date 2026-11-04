#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/tests" "$ROOT/docs/validation"
swiftc -O -parse-as-library "$ROOT/Sources/AstraCore/AstrologEngine.swift" \
  "$ROOT/Sources/AstraCore/ChartPreferences.swift" "$ROOT/Sources/AstraCore/Localization.swift" \
  "$ROOT/Sources/AstraCore/CityAtlas.swift" "$ROOT/Tests/CityAtlasTests.swift" \
  -o "$ROOT/.build/tests/CityAtlasTests"
"$ROOT/.build/tests/CityAtlasTests" "$ROOT"
