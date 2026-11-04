#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/tests" "$ROOT/.build/swift-cache" "$ROOT/.build/clang-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-cache"
swiftc -O -swift-version 6 -parse-as-library -D ASTRAGLASS_WORKSPACE_TESTS \
  -target arm64-apple-macos27.0 -module-cache-path "$ROOT/.build/swift-cache" \
  "$ROOT"/Sources/AstraCore/*.swift "$ROOT"/Sources/AstraApp/*.swift \
  "$ROOT/Tests/PDFExportTests.swift" -o "$ROOT/.build/tests/PDFExportTests" \
  -framework SwiftUI -framework AppKit -framework PDFKit
"$ROOT/.build/tests/PDFExportTests" "$ROOT"
