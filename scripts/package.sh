#!/bin/bash
# A public package never includes local author texts. Opt in for personal use.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:---public}"
case "$MODE" in
  --public) INCLUDE=0; SUFFIX="" ;;
  --with-corpus) INCLUDE=1; SUFFIX="-personal"
    if [[ ! -f "$ROOT/Resources/interpretations.json" ]]; then
      echo 'Personal packaging requires Resources/interpretations.json.' >&2
      exit 1
    fi ;;
  *) echo 'Usage: bash scripts/package.sh [--public|--with-corpus]' >&2; exit 1 ;;
esac
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")
STAGE=$(mktemp -d /tmp/AstraGlass-package.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
ASTRAGLASS_BUILD_DIR="$STAGE" ASTRAGLASS_INCLUDE_CORPUS="$INCLUDE" bash "$ROOT/scripts/build.sh"
APP="$STAGE/AstraGlass.app"
python3 - "$APP" "$INCLUDE" <<'PY'
import json, pathlib, sys
app = pathlib.Path(sys.argv[1])
resources = app / 'Contents' / 'Resources'
corpus = resources / 'interpretations.json'
assert not (resources / 'interpretations-txt3.json').exists(), 'Retired Txt3 corpus in package'
if sys.argv[2] == '1':
    for included in resources.glob('interpretations*.json'):
        data = json.loads(included.read_text())
        assert data.get('records') and data.get('sources'), 'Empty interpretation corpus: ' + included.name
else:
    assert not list(resources.glob('interpretations*.json')), 'Private texts in public package'
assert not (resources / 'profile-request.json').exists(), 'QA request in release'
assert not list(app.rglob('*.docx')), 'Source books in package'
PY
cp "$ROOT/docs/GETTING_STARTED.md" "$STAGE/READ-ME.md"
cp "$ROOT/docs/CORPUS.md" "$ROOT/docs/PERFORMANCE.md" "$STAGE/"
if [[ "$INCLUDE" == 1 ]]; then
  printf '%s\n' 'Личная сборка: содержит тексты из предоставленных вами документов. Публичный репозиторий содержит только исходный код; книги в него не входят.' > "$STAGE/PERSONAL.txt"
fi
mkdir -p "$ROOT/dist"
ARCHIVE="$ROOT/dist/AstraGlass-$VERSION-macOS-arm64$SUFFIX.zip"
ditto -c -k --sequesterRsrc "$STAGE" "$ARCHIVE"
python3 - "$ARCHIVE" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None, 'Damaged ZIP archive'
    assert 'AstraGlass.app/Contents/MacOS/AstraGlass' in archive.namelist()
    for executable in ['AstraGlass.app/Contents/MacOS/AstraGlass', 'AstraGlass.app/Contents/Helpers/astrolog']:
        assert archive.getinfo(executable).external_attr >> 16 & 0o111, 'Executable permission missing: ' + executable
PY
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$ARCHIVE")") > "$ARCHIVE.sha256"
# The helper and all runtime data are inside the signed app. Install by dragging
# the single app to Applications; no Homebrew or separate Astrolog is required.
ln -s /Applications "$STAGE/Applications"
DMG="$ROOT/dist/AstraGlass-$VERSION-macOS-arm64$SUFFIX.dmg"
hdiutil create -ov -format UDZO -fs HFS+ -volname "AstraGlass $VERSION" \
  -srcfolder "$STAGE" "$DMG"
hdiutil verify "$DMG"
bash "$ROOT/scripts/check-dmg.sh" "$DMG" "$INCLUDE"
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$DMG")") > "$DMG.sha256"
printf '%s\n' "$ARCHIVE" "$DMG"
