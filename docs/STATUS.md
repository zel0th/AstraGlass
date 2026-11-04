# AstraGlass — continuation checkpoint

Updated: 4 November 2026 (Moscow). Version: **0.2.0**.

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
- Native tests and ZIP succeeded; final disk-image creation and GitHub publication are being completed in this milestone.
- In the restricted shell, hdiutil creation failed with device-not-configured; use the available native runtime for disk-image operations. This is an execution-environment issue, not a compiler failure.

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
