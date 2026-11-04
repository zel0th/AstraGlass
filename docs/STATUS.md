# AstraGlass — continuation checkpoint

Updated: 5 November 2026 (Moscow). Version **0.3.5**.

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
- Core: 19 groups, including directed comparison grids, exact Astrolog orbs, same-object conjunctions and selection filters.
- Atlas: 27 checks. Workspace: 16 groups, including comparison cancellation and invalidation.
- Resources: all glyphs, lilac opposition, 22 clustered labels per row, sector centers, 12 exclusive house hit regions and 0° wrap.
- GUI final build: house 6, native synastry/transits, localized tables, secondary Sun and cross-chart opposition selection.
- PDF: 18 A4 pages / 45 paragraphs; localization: 302 keys; default bundle discovery tested in both helper locations.
- Both DMGs: signatures, readonly mount, relocated comparison/natal/report/graphic tests; public no corpus, personal Podvodny only.
- Evidence: docs/validation/distribution-0.3.5.json and gui-comparison-idle-0.3.5.json.
- Release: https://github.com/zel0th/AstraGlass/releases/tag/v0.3.5

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
