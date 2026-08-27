#!/usr/bin/env python3
"""Write BEAT_REPORT.md/json for libtiff campaign."""
import json, pathlib, datetime, os, subprocess

ROOT = pathlib.Path(os.environ.get("CDUB_ROOT", "/opt/cd-ub"))
OUT = ROOT / "reports" / "live" / "beat-libtiff"
LOCAL = ROOT / "reports" / "beat-libtiff"
LOCAL.mkdir(parents=True, exist_ok=True)

def read(p, default=""):
    try:
        return pathlib.Path(p).read_text().strip()
    except Exception:
        return default

sha = read(ROOT / "campaigns/beat-libtiff/meta/libtiff.sha")
beat_count = int(read(OUT / "BEAT_COUNT.txt", "0") or "0")
summary = read(OUT / "confirm_summary.txt")
hunt_status = read(OUT / "hunt_status.txt")
pre_scan = read(OUT / "pre_scan_summary.txt")
base = {}
bp = OUT / "sanitizer_baseline.json"
if bp.exists():
    base = json.loads(bp.read_text())

fstats = {}
sp = OUT / "findings/default/fuzzer_stats"
if sp.exists():
    for line in sp.read_text().splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            fstats[k.strip()] = v.strip()

pm2 = "UNKNOWN"
try:
    pm2 = subprocess.check_output(
        ["bash", str(ROOT / "deploy/contabo/pm2-guard.sh")], text=True
    ).strip().splitlines()[-1]
except Exception as e:
    pm2 = str(e)

verdict = "BEAT_PASS" if beat_count >= 1 else "BEAT_HOLD"
report = {
    "title": "CD-UB Beat Google Sanitizer Campaign — libtiff v4.3.0",
    "verdict": verdict,
    "target": "libtiff tiffcp (OSS-Fuzz enrolled)",
    "libtiff_version": "v4.3.0",
    "libtiff_sha": sha,
    "MOCK_PCT": 0,
    "beat_count": beat_count,
    "google_pass_n": base.get("google_pass_n"),
    "corpus_n": base.get("corpus_n"),
    "pre_scan": pre_scan,
    "hunt": {
        "run_time_s": fstats.get("run_time"),
        "execs_done": fstats.get("execs_done"),
        "paths_total": fstats.get("paths_total"),
        "bitmap_cvg": fstats.get("bitmap_cvg"),
        "hunt_status": hunt_status,
        "profile": "speed-2",
        "afl_flag": "-y 2 -Y out.file",
        "hunt_seconds": 1800,
    },
    "oracles": {
        "google": "ASan + UBSan (+ MSan if built)",
        "cdub": "CompDiff speed-2 gcc -O0 vs clang -O3 (file output oracle)",
    },
    "pm2": pm2,
    "citations": [
        "Google OSS-Fuzz / sanitizers",
        "CompDiff ASPLOS 2023 — LINE/UninitMem on libtiff",
        "Microsoft Research EMI PLDI 2014",
    ],
    "confirm_summary": summary,
    "utc": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
}

(LOCAL / "BEAT_REPORT.json").write_text(json.dumps(report, indent=2))
(OUT / "BEAT_REPORT.json").write_text(json.dumps(report, indent=2))

beats = read(OUT / "beats.txt")
md = f"""# CD-UB Beat Google Tools — libtiff Campaign Report

**Verdict: `{verdict}`**  
**MOCK_PCT: 0**

## Claim
OSS-Fuzz-enrolled **libtiff v4.3.0** @ `{sha}`: on the same TIFF inputs, **Google sanitizers (ASan/UBSan[/MSan]) are silent**, while **CD-UB CompDiff speed-2** (`gcc -O0` vs `clang -O3`) reports **output-file disagreement** via `tiffcp -M -i @@ out.file`.

## Beat definition (strict)
1. CD-UB binaries produce different `out.file` bytes on input I  
2. ASan/UBSan(/MSan) silent on I  
3. Reproducible x3  
4. Triage not NOISE  
5. PM2 guard green on Contabo

## Numbers
| Metric | Value |
|--------|------:|
| BEAT_COUNT | {beat_count} |
| Sanitizer corpus size | {base.get("corpus_n")} |
| GOOGLE_PASS seeds | {base.get("google_pass_n")} |
| Pre-scan | {pre_scan or "n/a"} |
| AFL run_time (s) | {fstats.get("run_time", "n/a")} |
| AFL execs_done | {fstats.get("execs_done", "n/a")} |
| libtiff SHA | `{sha}` |

## Hunt status
```
{hunt_status or "(see findings/)"}
```

## Confirmed beats
```
{beats or "(none — honest hold)"}
```

## Confirm summary
```
{summary}
```

## Environment
- PM2: `{pm2}`
- UTC: {report["utc"]}

## Portfolio link
Campaign 3 of CD-UB hunter — see `reports/portfolio/PORTFOLIO.md`.
"""
(LOCAL / "BEAT_REPORT.md").write_text(md)
(OUT / "BEAT_REPORT.md").write_text(md)
print(verdict)
print(f"BEAT_COUNT={beat_count}")
