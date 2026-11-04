#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/tests" "$ROOT/.build/ModuleCache"
swiftc -O -swift-version 6 -parse-as-library -module-cache-path "$ROOT/.build/ModuleCache" \
 "$ROOT/Sources/AstraCore/"*.swift "$ROOT/Sources/AstraApp/AstroStyle.swift" \
 "$ROOT/Sources/AstraApp/ChartWheelGeometry.swift" \
 "$ROOT/Sources/AstraApp/CalculationHelp.swift" "$ROOT/Tests/ResourceTests.swift" \
 -o "$ROOT/.build/tests/ResourceTests" -framework SwiftUI -framework AppKit
"$ROOT/.build/tests/ResourceTests" "$ROOT"
