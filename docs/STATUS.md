# AstraGlass — continuation checkpoint

Updated: 5 November 2026 (Moscow). Version **0.3.3**.

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

## 0.3.3 requested changes
- Conjunctions have separate visible blue ☌ buttons in the inner aspect field, with collision avoidance and leaders.
- Exact conjunctions and the 359°/1° boundary remain selectable; button opens the existing aspect inspector.
- Shared aspect palette: conjunction blue, trine green, square/opposition/semisquare/sesquisquare red, sextile teal.
- Subtle annular house fills follow actual cusps; natural house elements repeat fire/earth/air/water (index % 4).
- Editor month/day/hour use menu pickers; year/minute stay manual. Days use engine-compatible Julian/Gregorian leap rules.
- Changing month/year clamps the day; imported invalid input is still rejected, never silently normalized.
- Editor “Из библиотеки…” searches saved JSON records by title/place/date and loads every field into the draft.
- Cancel leaves workspace/database untouched. Apply updates the explicitly loaded UUID rather than the previously open chart.
- The saved-record chooser also works for the secondary chart. Loading an existing record is editing it, not cloning it.

## Validation this milestone
- Core: 18 groups with real engine; atlas: 27 checks. Workspace: 14 groups, including loaded UUID and primary/secondary isolation.
- Resources: font/glyphs/colors, 10 independently spaced conjunctions at three chart sizes, 12 sectors including 0° wrap, calendar transitions, Podvodny 823/4.
- PDF: 18 A4 pages, all 45 synthetic paragraphs and final Cyrillic marker, attribution/deduplication.
- Localization: 302 matching keys, no missing static labels. git diff --check passed.
- GUI: conjunction opens correct interpretation; house fills and colors visible; month/day/hour dropdowns, February 2000→2001 clamp, manual minutes checked.
- GUI: saved-chart search and Enter load restore automatic UTC; Cancel restores previous chart without applying draft.
- Both DMG/ZIP packages passed signatures, readonly mount and relocated engine checks; public corpus absent, personal Podvodny only.
- Evidence: docs/validation/distribution-0.3.3.json. Release target: https://github.com/zel0th/AstraGlass/releases/tag/v0.3.3

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
