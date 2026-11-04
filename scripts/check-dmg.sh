#!/bin/bash
# Validate the exact disk image distributed to users, mounted read-only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="${1:?Usage: check-dmg.sh image.dmg [0|1]}"
INCLUDE="${2:-0}"
MOUNT="$(mktemp -d /tmp/AstraGlass-dmg-check.XXXXXX)"
cleanup() {
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rmdir "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$DMG" >/dev/null
APP="$MOUNT/AstraGlass.app"
codesign --verify --deep --strict "$APP"
test "$(readlink "$MOUNT/Applications")" = /Applications
if [[ "$INCLUDE" == 0 ]]; then
  test -z "$(find "$APP/Contents/Resources" -name 'interpretations*.json' -print)"
else
  test -s "$APP/Contents/Resources/interpretations.json"
fi
python3 "$ROOT/scripts/check-bundle.py" "$APP"
echo 'DMG verified: signature, Applications link, embedded Astrolog and relocated calculations.'
