#!/usr/bin/env python3
"""Sample an already-running AstraGlass process; does not launch or interact.

Usage: python3 scripts/sample-app.py PID [seconds] [label]
RSS is process resident memory from ps in KiB, converted to MiB. ps %CPU is
an OS-reported historical estimate, not the CPU delta for each interval.
"""
import datetime
import json
import pathlib
import statistics
import subprocess
import sys
import time

if len(sys.argv) < 2:
    sys.exit(__doc__)
pid = int(sys.argv[1])
duration = float(sys.argv[2]) if len(sys.argv) > 2 else 30
label = sys.argv[3] if len(sys.argv) > 3 else "idle"
if duration <= 0 or duration > 300 or not label.replace("-", "").replace("_", "").isalnum():
    sys.exit("Use a duration from 1 to 300 seconds and an alphanumeric label.")
samples = []
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
start = time.perf_counter()
while time.perf_counter() - start < duration:
    process = subprocess.run(["ps", "-p", str(pid), "-o", "%cpu=,rss=,time="], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    fields = process.stdout.strip().split()
    if process.returncode or len(fields) < 3:
        sys.exit("Target process exited or ps access is unavailable: " + process.stderr)
    cpu, rss = float(fields[0]), int(fields[1])
    samples.append({"elapsed_seconds": time.perf_counter() - start, "cpu_percent_os_estimate": cpu, "resident_mib": rss / 1024, "cumulative_cpu_time": fields[2]})
    time.sleep(0.5)
result = {
    "label": label,
    "pid": pid,
    "timestamp_utc": started,
    "duration_seconds": time.perf_counter() - start,
    "samples": samples,
    "mean_cpu_percent_os_estimate": statistics.mean(s["cpu_percent_os_estimate"] for s in samples),
    "maximum_cpu_percent_os_estimate": max(s["cpu_percent_os_estimate"] for s in samples),
    "initial_resident_mib": samples[0]["resident_mib"],
    "final_resident_mib": samples[-1]["resident_mib"],
    "maximum_resident_mib": max(s["resident_mib"] for s in samples),
    "scope": "Main GUI process only; excludes Astrolog subprocesses. ps %CPU is an OS historical estimate. Resident memory is not total physical footprint. No leak inference from a brief sample.",
}
output = pathlib.Path(__file__).resolve().parents[1] / "docs" / "validation" / ("app-" + label + ".json")
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k: v for k, v in result.items() if k != "samples"}, ensure_ascii=False, indent=2))
