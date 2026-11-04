# AstraGlass — continuation checkpoint

Updated: 4 November 2026 (Moscow). Version: **0.3.1**.

## Repository and authorization
- Continue `Share/Projects/AstraGlass`, not the older AstrologMac project.
- Public repository: https://github.com/zel0th/AstraGlass
- The user explicitly requested full source publication and compiled app/DMG on GitHub in this session. This resolves the earlier publication-approval blocker.
- Recovered the latest 0.2.0 archive; previous local 0.1.1 modified files were backed up under /tmp/AstraGlass-before-0.2.0.
- Existing GitHub initial README/LICENSE history is retained as the parent of this source import.

## Native validation completed
- macOS 27.2 (26B123), Apple silicon, Swift 6.4.2; native app compiles and launches.
- 17 core groups, 27 atlas checks (33,702 cities), 10 workspace groups pass.
- Relocated bundle: natal, synastry, graphics pass from Helpers and legacy Resources/Engine paths.
- Six engine-preference groups pass, including all 24 aspect switches and 11 graphics modes.
- 299 localization keys match. Full manual English UI walkthrough remains unverified.
- PDFKit: 18 A4 pages, all 45 synthetic paragraphs and final Cyrillic marker, attribution and deduplication pass. Pages 1/2/3/18 rendered and inspected.
- Actual GUI: chart calculation and all three settings tabs inspected.
- New calculation benchmark: 100 charts, 3.653 s, mean 36.53 ms. See PERFORMANCE.md.
- New GUI profile is exploratory, not controlled idle: 2.618% one-core CPU, max sampled RSS 182.28 MiB. Do not compare directly with old 0.1.1 idle/interaction records.

## Distribution milestone
- Packaging emits public or personal DMG and ZIP with SHA-256 sidecars.
- Astrolog is inside `Contents/Helpers/astrolog`; runtime data, font and licenses are bundled. No separate Astrolog/Homebrew install.
- Both binaries target macOS 27.0 arm64. Engine build cache includes platform flags.
- DMG validation mounts read-only, verifies signature and Applications link, then tests relocated calculations/graphics.
- Public startup treats absent private books as the expected empty library; corrupt imports still report errors.
- Source and releases must exclude PrivateCorpus, interpretations.json, personal charts and personal packages.
- Full source published to main. Clean Git archive rebuilt successfully; DMG and ZIP passed all packaging checks.
- Release: https://github.com/zel0th/AstraGlass/releases/tag/v0.2.0 (DMG, ZIP, full source archive and SHA-256).
- Distribution evidence: docs/validation/distribution.json; binary dependencies are system-only.
- hdiutil requires the native runtime in this environment; the restricted shell cannot configure a disk-image device. Final native-runtime packaging exited 0.

## Reproduce
```sh
bash scripts/test.sh
bash scripts/test-bundle-engine.sh
bash scripts/test-workspace.sh
bash scripts/test-pdf.sh
python3 scripts/check-localizations.py
python3 scripts/test-engine-preferences.py
python3 scripts/benchmark.py
bash scripts/package.sh --public
```

## Product boundaries
- No full Astrolog UI parity; see FEATURES.md.
- Charon and some small bodies need optional ephemerides; unavailable positions are not fabricated.
- Native progressions, animation and Astrolog .as document import remain future work.
- Ad-hoc signing only; Developer ID and notarization are not configured.
- Keep this checkpoint under 100 lines and preserve evidence between continuations.

## 0.3.0 feature milestone (current)
- Added bundled Astronomicon-derived Unicode font, including traditional Pluto. All configured glyphs verified with CoreText.
- City popover filters from first character; keyboard selection and actual Helsinki/time-zone update verified. Row identity regression fixed.
- Two personal bundled corpora: Podvodny 823 sections / 4 sources; Txt3 27,349 sections / 300 sources, 7,887 natal bindings. Settings selection persists.
- Txt3 importer preserves full source text and section codes; unsupported/non-natal sections stay searchable without false natal bindings.
- Added 40 house-system explanations and tropical/sidereal help.
- Added atomic JSON database with backup, autosave on Apply, update, search, reopen, second-chart opening and deletion. GUI saved/reopened a clearly named Helsinki demonstration chart.
- Current checks: core 17, atlas 27, workspace 11, database 7, Txt3 importer 17; resource/font suite passed. PDF 18 pages with all 45 synthetic paragraphs passed. 302 locale keys match.
- Personal runtime with Txt3 was observed at 419.91 MiB RSS and ps 0.0% CPU after interaction; this is one sample, not a controlled memory/CPU benchmark. Corpus load in native resource harness: 3.013 s.
- Personal and public DMG/ZIP completed; signatures, readonly DMG mounts and relocated natal/synastry/graphics passed. Public packages contain no private corpora. Native runtime is required for hdiutil.
- Personal DMG saved for delivery; release URL: https://github.com/zel0th/AstraGlass/releases/tag/v0.3.0. Code commit: 41b7c5c. Distribution evidence: docs/validation/distribution-0.3.0.json.
- Additional tests: bash scripts/test-database.sh; bash scripts/test-resources.sh.

## 0.3.1 fixes
- Missing custom corpus no longer appears in the picker; stale selections preserve the existing library without an error.
- Txt3 display name is now «Сборник астрологических трактовок», retaining the persisted enum ID.
- Russian-language records only across chart lookups/search/PDF: 22,422 records / 244 sources from the supplied collection. Original indexes unchanged. English-only imports rejected.
- Explicit object palette in chart, table, inspector, settings and native PDF/PNG; Sun and Mars red, selection retains object color.
- Tests passed: core 18, atlas 27, workspace 12, resource/font/language/palette checks. GUI verified two installed choices and the user's Moon–Saturn opposition example without English passages.
- Both 0.3.1 DMG/ZIP packages passed signature, mount and relocated-engine checks. Personal archives retain both original corpora; public packages contain none.
- PDF color cover visually verified. Release URL: https://github.com/zel0th/AstraGlass/releases/tag/v0.3.1.
