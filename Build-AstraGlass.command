#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != Darwin ]]; then echo 'Откройте этот файл на Mac с macOS 27 и Command Line Tools.'; exit 1; fi
bash scripts/test.sh
bash scripts/test-bundle-engine.sh
bash scripts/test-workspace.sh
bash scripts/test-pdf.sh
python3 scripts/check-localizations.py
if [[ -f Resources/interpretations.json ]]; then
  bash scripts/package.sh --with-corpus
else
  bash scripts/package.sh --public
fi
open dist
printf '\nСборка и проверки завершены. DMG и ZIP находятся в папке dist.\n'
