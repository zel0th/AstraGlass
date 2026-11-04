# AstraGlass — continuation checkpoint

Updated: 5 November 2026 (Moscow). Version **0.3.4**.

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
- Atomic versioned JSON chart database with backup, autosave, reopen/edit/second-chart/delete and whole-database merge import/export.
- Local Podvodny corpus: 823 sections / 4 documents. Russian-only lookup/search/PDF; absent custom corpus hidden.
- Txt3 remains retired: hidden from settings, excluded by build whitelist and package validators; original kept only in PrivateCorpus.
- Responsive ChartDashboardLayout, proportional glyph scaling, bottom summary strip; inspector default 800, resizable 360–1200.

## 0.3.4 requested changes
- IC added at MC + 180°, in the shared native wheel and exports.
- Every painted house annulus is a button using the same Path for hit testing; actual unequal cusps and 0° wrap are preserved.
- Selecting a house opens its existing inspector with house/cusp-sign passages and highlights the sector, border and number.
- House buttons are below planets/signs/aspects; their content shape excludes the center and outer zodiac band. VoiceOver labels included.
- Previous 0.3.3: selectable conjunction badges, shared aspect colors, house tints, calendar pickers and saved-chart editor chooser remain.

## Validation this milestone
- Workspace: 15 groups with real engine, including all 12 house selections, matching passages and switching back to a planet.
- Resources: fonts/colors/conjunctions/calendar; exclusive hit regions for 12 unequal houses at multiple interior points, 0° wrap, center/zodiac exclusions; texts for all houses/signs.
- GUI: IC visible opposite MC; empty areas of houses 4 and 6 open matching texts and show sector selection; Sun, Gemini and conjunction still selectable.
- PDF: 18 A4 pages, all 45 paragraphs preserved; localization: 302 matching keys; diff check clean.
- Both packages passed signatures, readonly DMG mount and relocated engine checks; public corpus absent, personal Podvodny only.
- Evidence: docs/validation/distribution-0.3.4.json. Release target: https://github.com/zel0th/AstraGlass/releases/tag/v0.3.4

## Reproduce
```sh
bash scripts/test.sh
bash scripts/test-workspace.sh
bash scripts/test-resources.sh
bash scripts/test-pdf.sh
python3 scripts/check-localizations.py
bash scripts/package.sh --public
bash scripts/package.sh --with-corpus
```

## Distribution and boundaries
- Public source/release excludes PrivateCorpus, interpretations*.json, books, personal charts and personal packages.
- Personal DMG includes Podvodny; deliver privately. Both packages embed Astrolog, no Homebrew required.
- hdiutil requires native runtime here; restricted shell cannot configure disk-image device.
- Ad-hoc signing only, no Developer ID/notarization. No full Astrolog parity; see FEATURES.md.
- Some minor bodies need extra ephemerides; no fabricated positions. Progressions, animation and .as import remain future work.
- Previous performance: 100 calculations, mean 36.53 ms; GUI 182.28 MiB/2.618% CPU exploratory, not controlled idle. See PERFORMANCE.md.
