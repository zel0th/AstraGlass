# Calculation benchmark

Measured on 2026-11-04T19:03:58.796661+00:00 with the release-optimized Swift adapter and bundled Astrolog 8.0 executable.

| Scenario | Result |
| --- | ---: |
| Serial chart calculations | 100 |
| Total calculation wall time | 3.653 s |
| Mean / median calculation | 36.53 / 35.18 ms |
| 95th percentile / maximum | 49.10 / 101.43 ms |
| User + system CPU | 0.588 + 0.846 s |
| Average use of one CPU core | 38.7% |
| Harness peak resident memory | 12.94 MiB |

The workload varies dates, times and UTC offsets and creates a fresh, isolated Astrolog process for each chart. CPU includes the waited calculation children. Peak RSS is macOS `getrusage(RUSAGE_CHILDREN).ru_maxrss` from a fresh worker that launches only the harness, in bytes converted to MiB; it is not the simultaneous aggregate of GUI and child processes. This benchmark measures calculation performance; it does not measure idle UI CPU, rendering performance or long-term memory leaks.

Environment: ProductName:		macOS; ProductVersion:		27.2; BuildVersion:		26B123, arm64. CPU model: Unavailable in execution sandbox. Physical memory: Unavailable in execution sandbox.

Reproduce with `bash scripts/test.sh` followed by `python3 scripts/benchmark.py`. This script replaces only `docs/CALCULATION-BENCHMARK.md` and the calculation JSON results in `docs/validation/`. The combined report and historical GUI measurements are preserved in `docs/PERFORMANCE.md`.

To sample the GUI, launch the built executable with `--profile-output /absolute/path/app-idle.json --profile-seconds 30 --profile-delay 5 --profile-label idle`. The optional recorder uses `getrusage(RUSAGE_SELF)` CPU deltas and `task_info(MACH_TASK_BASIC_INFO)` resident bytes every half-second. It saves local JSON and leaves the app running. Normal app launches do not start the recorder. Repeat with label `interaction` while changing charts, reports and library selections. GUI measurements exclude Astrolog child processes and must be considered alongside the calculation benchmark.
