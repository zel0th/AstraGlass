#!/usr/bin/env python3
"""Measure the real Swift adapter and waited child processes on macOS.

Run scripts/test.sh first. resource.ru_maxrss is BYTES on Darwin, not KiB.
The benchmark is not a UI rendering or idle CPU measurement.
Writes docs/CALCULATION-BENCHMARK.md without replacing the combined report.
"""
import datetime
import json
import os
import pathlib
import platform
import resource
import signal
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "validation"
OUTPUT.mkdir(parents=True, exist_ok=True)

def command_text(command):
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return result.stdout.strip() if result.returncode == 0 else "Unavailable in execution sandbox"

def main():
    executable = ROOT / ".build" / "tests" / "CoreTests"
    if not executable.exists():
        sys.exit("Build the test harness first: bash scripts/test.sh")
    # Capture metadata before usage baseline; its child processes do not affect
    # reported CPU deltas. Max RSS is the maximum of waited children, so invoke
    # this script on its own for a reproducible measurement.
    metadata = {
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "os": command_text(["sw_vers"]),
        "architecture": platform.machine(),
        "cpu": command_text(["sysctl", "-n", "machdep.cpu.brand_string"]),
        "physical_memory_bytes": command_text(["sysctl", "-n", "hw.memsize"]),
        "python_version": platform.python_version(),
        "swift": command_text(["swift", "--version"]),
    }
    # The fresh Python worker has no earlier children: metadata commands cannot
    # contaminate its child RSS high-water mark. This also works where time -l
    # cannot access the system clockrate through sysctl.
    start = time.perf_counter()
    process = subprocess.Popen([sys.executable, str(pathlib.Path(__file__).resolve()), "--worker"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    (ROOT / ".build" / "tests" / "benchmark.pid").write_text(str(process.pid))
    try:
        stdout, stderr = process.communicate(timeout=90)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
        sys.exit("Benchmark exceeded 90 seconds; its test process group was stopped.")
    elapsed = time.perf_counter() - start
    if process.returncode:
        sys.exit(stderr or "Benchmark failed")
    measured = json.loads(stdout)
    benchmark = measured["benchmark"]
    max_rss = measured["peak_resident_bytes"]
    user_cpu = measured["user_cpu_seconds"]
    system_cpu = measured["system_cpu_seconds"]
    (OUTPUT / "benchmark-resources.json").write_text(json.dumps(measured, indent=2) + "\n")
    benchmark.update({
        "outer_wall_seconds": elapsed,
        "user_cpu_seconds": user_cpu,
        "system_cpu_seconds": system_cpu,
        "average_cpu_percent_of_one_core": (user_cpu + system_cpu) / elapsed * 100,
        "peak_resident_bytes": max_rss,
        "peak_resident_mib": None if max_rss is None else max_rss / 1024 / 1024,
        "rss_scope": "Darwin RUSAGE_CHILDREN peak RSS from an isolated worker that launches only the Swift harness; not simultaneous aggregate memory",
        "cpu_scope": "resource RUSAGE_CHILDREN delta for waited harness and its waited engine children",
        "metadata": metadata,
        "limitations": ["Measures calculation path only; GUI idle and interaction require separate app sampling.", "No statistical claim about all hardware or long sessions.", "Peak RSS is not a memory-leak test or total memory pressure."],
    })
    (OUTPUT / "benchmark.json").write_text(json.dumps(benchmark, ensure_ascii=False, indent=2) + "\n")
    report = f"""# Calculation benchmark

Measured on {metadata['timestamp_utc']} with the release-optimized Swift adapter and bundled Astrolog 8.0 executable.

| Scenario | Result |
| --- | ---: |
| Serial chart calculations | {benchmark['requests']} |
| Total calculation wall time | {benchmark['wall_seconds']:.3f} s |
| Mean / median calculation | {benchmark['mean_ms']:.2f} / {benchmark['median_ms']:.2f} ms |
| 95th percentile / maximum | {benchmark['p95_ms']:.2f} / {benchmark['max_ms']:.2f} ms |
| User + system CPU | {user_cpu:.3f} + {system_cpu:.3f} s |
| Average use of one CPU core | {benchmark['average_cpu_percent_of_one_core']:.1f}% |
| Harness peak resident memory | {benchmark['peak_resident_mib']:.2f} MiB |

The workload varies dates, times and UTC offsets and creates a fresh, isolated Astrolog process for each chart. CPU includes the waited calculation children. Peak RSS is macOS `getrusage(RUSAGE_CHILDREN).ru_maxrss` from a fresh worker that launches only the harness, in bytes converted to MiB; it is not the simultaneous aggregate of GUI and child processes. This benchmark measures calculation performance; it does not measure idle UI CPU, rendering performance or long-term memory leaks.

Environment: {metadata['os'].replace(chr(10), '; ')}, {metadata['architecture']}. CPU model: {metadata['cpu']}. Physical memory: {metadata['physical_memory_bytes']}.

Reproduce with `bash scripts/test.sh` followed by `python3 scripts/benchmark.py`. This script replaces only `docs/CALCULATION-BENCHMARK.md` and the calculation JSON results in `docs/validation/`. The combined report and historical GUI measurements are preserved in `docs/PERFORMANCE.md`.

To sample the GUI, launch the built executable with `--profile-output /absolute/path/app-idle.json --profile-seconds 30 --profile-delay 5 --profile-label idle`. The optional recorder uses `getrusage(RUSAGE_SELF)` CPU deltas and `task_info(MACH_TASK_BASIC_INFO)` resident bytes every half-second. It saves local JSON and leaves the app running. Normal app launches do not start the recorder. Repeat with label `interaction` while changing charts, reports and library selections. GUI measurements exclude Astrolog child processes and must be considered alongside the calculation benchmark.
"""
    (ROOT / "docs" / "CALCULATION-BENCHMARK.md").write_text(report)
    print(json.dumps(benchmark, ensure_ascii=False, indent=2))

def worker():
    executable = ROOT / ".build" / "tests" / "CoreTests"
    start = time.perf_counter()
    result = subprocess.run([str(executable), "--benchmark", "100", str(ROOT)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=80)
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    if result.returncode:
        sys.exit(result.stderr or "Benchmark harness failed")
    print(json.dumps({"benchmark": json.loads(result.stdout), "worker_wall_seconds": time.perf_counter() - start, "user_cpu_seconds": usage.ru_utime, "system_cpu_seconds": usage.ru_stime, "peak_resident_bytes": usage.ru_maxrss if sys.platform == "darwin" else usage.ru_maxrss * 1024}))

if __name__ == "__main__":
    worker() if "--worker" in sys.argv else main()
