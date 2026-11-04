#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/tests" "$ROOT/.build/swift-cache" "$ROOT/.build/clang-cache" "$ROOT/docs/validation"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache"
bash "$ROOT/scripts/build-engine.sh"
swiftc -O -swift-version 6 -parse-as-library -D ASTRAGLASS_WORKSPACE_TESTS \
  -target arm64-apple-macos27.0 -module-cache-path "$ROOT/.build/swift-cache" \
  "$ROOT"/Sources/AstraCore/*.swift "$ROOT"/Sources/AstraApp/*.swift \
  "$ROOT/Tests/WorkspaceTests.swift" -o "$ROOT/.build/tests/WorkspaceTests" \
  -framework SwiftUI -framework AppKit
"$ROOT/.build/tests/WorkspaceTests" "$ROOT" > "$ROOT/.build/tests/workspace-tests.json"
cp "$ROOT/.build/tests/workspace-tests.json" "$ROOT/docs/validation/workspace-tests.json"
cat "$ROOT/docs/validation/workspace-tests.json"
