# Performance and validation — 0.2.0

Validated on 4 November 2026 on macOS 27.2 (26B123), Apple silicon, Swift 6.4.2, optimized builds. This is a short observation on one Mac, not a guarantee for other machines or long sessions.

## Current calculation benchmark

100 serial charts through the actual Swift adapter, each using a fresh Astrolog child process. Dates and UTC offsets vary.

| Metric | Result |
| --- | ---: |
| Total calculation time | 3.653 s |
| Mean / median | 36.53 / 35.18 ms |
| 95th percentile / maximum | 49.10 / 101.43 ms |
| User + system CPU | 0.588 + 0.846 s |
| Average CPU, one-core scale | 38.69% |
| Harness peak resident memory | 12.94 MiB |

CPU includes waited calculation children. Peak RSS is Darwin RUSAGE_CHILDREN from a fresh worker launching only the harness; it is not aggregate GUI plus helper memory. Raw evidence: `validation/benchmark.json`, `validation/benchmark-resources.json`. Reproduce with `bash scripts/test.sh` then `python3 scripts/benchmark.py`.

## Current GUI observation

The public 0.2.0 app was sampled for 30.48 seconds after a 10-second delay. The interval included dismissing the initial missing-library alert and UI inspection while a separate compilation ran. It is exploration, **not controlled idle**. That expected missing-corpus alert has since been removed from the public build; calculations and rendering are unchanged.

| Metric | Result |
| --- | ---: |
| Average CPU, one-core scale | 2.618% |
| Resident memory, first → last | 182.28 → 180.16 MiB |
| Maximum sampled resident memory | 182.28 MiB |
| Peak resident memory since launch | 202.47 MiB |

The in-app recorder samples every 0.5 seconds. CPU is the getrusage(RUSAGE_SELF) user+system delta divided by elapsed wall time; 100% means one occupied core. Resident bytes come from task_info(MACH_TASK_BASIC_INFO); peak RSS is ru_maxrss in bytes. This describes only the main GUI process, excludes Astrolog children, and cannot establish absence of leaks. Raw evidence: `validation/app-0.2.0-exploration.json`.

Historical 0.1.1 records remain in `validation/app-background-idle.json`, `app-interaction.json`, and `app-exploration.json`. Their earlier 0.194% background idle / 6.021% interaction results are not current 0.2.0 measurements and should not be treated as comparable controlled experiments.

## Native functional validation

- 17 core groups, 27 city/time-zone checks, 10 workspace groups passed.
- Six relocated-bundle checks cover natal calculations, synastry and graphics in both helper locations, with spaces in the app path and working directory /tmp.
- Six engine-preference groups cover all 24 aspect switches, node derivation, missing ephemerides and eleven graphics modes.
- Both localization catalogs have 299 matching keys; static-label checks passed.
- PDFKit verified 18 A4 pages, all 45 synthetic Cyrillic paragraphs, final marker, source attribution and deduplication. Pages 1, 2, 3 and 18 were rendered and visually inspected. This supersedes the old single-page PDF evidence in `validation/export-pdf.json`.
- Running GUI: natal chart and all three settings tabs observed. Full English UI walkthrough remains unverified.
- Distribution checks verify ad-hoc signatures, executable permissions, bundled resources and calculations after relocation. The DMG is mounted read-only and its app is checked again.

Commands: `bash scripts/test.sh`, `bash scripts/test-bundle-engine.sh`, `bash scripts/test-workspace.sh`, `bash scripts/test-pdf.sh`, `python3 scripts/check-localizations.py`, `python3 scripts/test-engine-preferences.py`, `bash scripts/package.sh --public`.

For GUI profiling launch with `--profile-output /absolute/path/result.json --profile-seconds 30 --profile-delay 10 --profile-label scenario`. Production bundles contain no profile-request.json and do not enable a profiling timer on ordinary launches.

## 0.3.0 corpus and feature check

The optional Txt3 collection contains 27,349 sections from 300 sources. The native resource harness loaded and indexed it in **3.013 seconds** (includes the few lookup assertions). After UI exploration with that collection selected, a single `ps` observation of the GUI reported **419.91 MiB RSS** and **0.0% CPU**. This is an observational snapshot, not an idle time-series or leak test; do not compare it directly with the controlled historical runs. The larger corpus explains additional retained text and search-index storage.

The 0.3.0 feature suite passed: 11 workspace groups including database relaunch/recalculation, 7 database scenarios, 17 synthetic Txt3 importer checks, actual CoreText glyph coverage, 40 nonempty house explanations and the existing 18-page PDF regression.
