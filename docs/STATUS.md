# AstraGlass — continuation checkpoint

Updated: 5 November 2026 (Moscow). Version **0.3.2**.

## Repository and authorization
- Continue this repository, not the old AstrologMac project.
- Public repository: https://github.com/zel0th/AstraGlass
- User authorized full source and compiled public app/DMG publication; personal author texts stay private.
- No subagents unless explicitly requested. Keep this file below 100 lines.

## Current implementation
- Native macOS 27 SwiftUI app; Astrolog 8.0 in Contents/Helpers with runtime data and licenses.
- Offline atlas: 33,702 cities, filtering from first character, Russian aliases, historical UTC/DST.
- Bundled astrology font including traditional Pluto, explicit object colors (Sun/Mars red), 40 house-system explanations.
- Settings for language, objects/aspects, appearance and installed interpretation collections.
- Versioned atomic JSON chart database with backup, autosave on Apply, reopen/edit/second-chart/delete.
- Local Podvodny corpus: 823 sections / 4 documents. Russian-only lookup/search/PDF; absent custom corpus hidden.

## 0.3.2 requested changes
- ChartDashboardLayout measures actual header/footer and fills remaining viewport height; no 580-point cap.
- Circle and glyphs scale together; Sun/Moon/ASC strip stays at bottom as window grows; short windows scroll.
- Inspector default 800 points, resizable 360–1200; stable ZStack detail container preserves width across sections.
- Whole database import/export in My Charts and Chart menu; UUID merge, newer revision wins, equal date keeps local.
- Validate entire incoming file before writing; repeat imports are no-ops; preserve local-only records and backup.
- Txt3 removed from selectable packs and build resources. Old persisted txt3 selection falls back to Podvodny.
- Original Txt3 archive/index retained only in PrivateCorpus for future user cleanup; importer kept as preparation tool.
- Build uses explicit Podvodny whitelist; package/bundle validators reject retired interpretations-txt3.json.

## Validation this milestone
- Database CRUD/backup, full JSON round trip, repeat import, revision merge, local-only preservation, four invalid imports, empty export passed.
- Workspace: 13 groups passed with real engine, including imported-chart recalculation.
- Resources: font/glyphs/colors, house descriptions and Podvodny 823/4 passed.
- PDF: 18 A4 pages, all 45 synthetic paragraphs and final Cyrillic marker, attribution/deduplication passed.
- Localization: 302 keys match, no missing static labels.
- GUI: tall/short windows show proportional chart and moving lower strip; exported/reimported database reports 0 added / 0 updated / 1 unchanged.
- Final GUI verified: inspector retains 800-point width when switching Chart → My Charts → Chart; tall/short layouts confirmed.
- Core 18 groups and atlas 27 checks passed. Both DMG/ZIP packages passed signatures, readonly mounts and relocated engine checks.
- Public package has no private corpus; personal package has Podvodny only; Txt3 absent in both.
- Release URL: https://github.com/zel0th/AstraGlass/releases/tag/v0.3.2
- Personal DMG saved for private delivery; release evidence: docs/validation/distribution-0.3.2.json.

## Reproduce
```sh
bash scripts/test.sh
bash scripts/test-database.sh
bash scripts/test-workspace.sh
bash scripts/test-resources.sh
bash scripts/test-pdf.sh
python3 scripts/check-localizations.py
bash scripts/package.sh --public
bash scripts/package.sh --with-corpus
```

## Distribution and boundaries
- Public source/release assets exclude PrivateCorpus, interpretations*.json, books, personal charts and personal packages.
- Personal DMG includes Podvodny; deliver privately. Both packages embed Astrolog, no Homebrew required.
- hdiutil needs native runtime here; restricted shell cannot configure disk-image device.
- Ad-hoc signing only, no Developer ID/notarization. No full Astrolog parity; see FEATURES.md.
- Some minor bodies require extra ephemerides; no fabricated positions. Progressions, animation and .as import remain future work.
- Previous performance: 100 calculations, mean 36.53 ms; GUI 182.28 MiB/2.618% CPU exploratory profile, not controlled idle. See PERFORMANCE.md.
