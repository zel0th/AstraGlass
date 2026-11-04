#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build/AppIcon.iconset" "$ROOT/.build/swift-cache"
swiftc -module-cache-path "$ROOT/.build/swift-cache" "$ROOT/scripts/Icon.swift" -o "$ROOT/.build/make-icon" -framework AppKit
"$ROOT/.build/make-icon" "$ROOT/.build/AppIcon.iconset"
python3 "$ROOT/scripts/pack-icon.py" "$ROOT/.build/AppIcon.iconset" "$ROOT/Resources/AppIcon.icns"
