#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/tests" "$ROOT/.build/ModuleCache"
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$ROOT/.build/ModuleCache" \
 "$ROOT/Sources/AstraCore/AstrologEngine.swift" "$ROOT/Sources/AstraCore/ChartPreferences.swift" \
 "$ROOT/Sources/AstraCore/Localization.swift" "$ROOT/Sources/AstraCore/ChartDatabase.swift" \
 "$ROOT/Tests/DatabaseTests.swift" -o "$ROOT/.build/tests/DatabaseTests"
"$ROOT/.build/tests/DatabaseTests"
python3 "$ROOT/Tests/Txt3Tests.py"
