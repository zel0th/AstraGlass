# AstraGlass — continuation checkpoint

Updated: 5 November 2026 (Moscow). Version **0.3.6**.

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

## 0.3.6 changes
- Planet/point leaders and colored dots now share the exact aspect vertex radius and longitude in natal and comparison wheels.
- Removed degrees beside glyphs; retained retrograde marks and precise positions in tables, tooltips and inspector.
- Glyph sizes reduced 25→22 pt (natal), 18→16 pt (comparison); proportional scaling and conservative collision spacing retained.
- Shared ChartWheel also updates native exports. No engine, corpus or chart-database changes.

## 0.3.5 delivered changes
- Native wheel: zodiac .84–1R, 360° scale .78–.84R, house annulus .68–.78R; numbers centered; planets inside .68R.
- Lilac opposition shared by native wheels, tables and natal exports; IC and selectable sectors preserved.
- Typed engine comparison serializes genuine FCreateGridRelation with directed pairs and same-body conjunctions.
- Synastry/transits: native biwheel or localized table. Primary zodiac/houses; secondary bodies have dashed outlines.
- Comparison clears on input/settings changes and cancellation; inspector identifies chart ①/② and generic interpretation scope.
- Core 19 groups and atlas 27 checks passed; GUI verified biwheels/tables, secondary Sun, transitions and lilac opposition.
- Explicit viewport sizing avoids layout feedback; 15 ps samples over 30 s: 0.0% CPU, GUI RSS 181.6–214.6 MiB.
- Final geometry tests pass for 22 clustered bodies in each row, full rectangles contained in the inner field.
- Workspace 16 groups, PDF 18 A4 pages / all 45 paragraphs, localization 302 keys passed. Both packages verified.

## 0.3.4 requested changes
- IC added at MC + 180°, in the shared native wheel and exports.
- Every painted house annulus is a button using the same Path for hit testing; actual unequal cusps and 0° wrap are preserved.
- Selecting a house opens its existing inspector with house/cusp-sign passages and highlights the sector, border and number.
- House buttons are below planets/signs/aspects; their content shape excludes the center and outer zodiac band. VoiceOver labels included.
- Previous 0.3.3: selectable conjunction badges, shared aspect colors, house tints, calendar pickers and saved-chart editor chooser remain.

## Validation this milestone
- Swift 6 optimized arm64 build and relocated natal/comparison/report/graphic checks passed.
- Resource suite passed: all glyphs/colors, 22 clustered labels per row, house hit regions, calendar and Podvodny corpus.
- GUI: natal and native synastry inspected; leaders meet aspect vertices, no degree labels, retrograde marks visible; cross-chart opposition selection works.
- Both DMGs verified: signatures, readonly mounts, relocated calculations, ZIP integrity; public no corpus, personal Podvodny only.
- Evidence: docs/validation/distribution-0.3.6.json. Release: https://github.com/zel0th/AstraGlass/releases/tag/v0.3.6
- Prior core/workspace/PDF/localization/performance evidence retained under docs/validation (0.3.5).

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
- Run packaging modes sequentially: both rebuild the same Engine/bin/astrolog output.
- Ad-hoc signing only, no Developer ID/notarization. No full Astrolog parity; see FEATURES.md.
- Some minor bodies need extra ephemerides; no fabricated positions. Progressions, animation and .as import remain future work.
- Previous performance: 100 calculations, mean 36.53 ms; GUI 182.28 MiB/2.618% CPU exploratory, not controlled idle. See PERFORMANCE.md.
