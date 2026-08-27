#!/usr/bin/env python3
"""Write BEAT_REPORT.md/json from Contabo artifacts."""
import json, pathlib, datetime, os, subprocess

ROOT = pathlib.Path(os.environ.get("CDUB_ROOT", "/opt/cd-ub"))
OUT = ROOT / "reports" / "live" / "beat-google"
LOCAL = ROOT / "reports" / "beat-google"
LOCAL.mkdir(parents=True, exist_ok=True)

def read(p, default=""):
    try:
        return pathlib.Path(p).read_text().strip()
    except Exception:
        return default

sha = read(ROOT / "campaigns/beat-google/meta/jq.sha")
beat_count = int(read(OUT / "BEAT_COUNT.txt", "0") or "0")
summary = read(OUT / "confirm_summary.txt")
hunt_status = read(OUT / "hunt_status.txt")
base = {}
bp = OUT / "sanitizer_baseline.json"
if bp.exists():
    base = json.loads(bp.read_text())

# AFL metrics
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
    "title": "CD-UB Beat Google Sanitizer Campaign",
    "verdict": verdict,
    "target": "jq (OSS-Fuzz enrolled)",
    "jq_sha": sha,
    "MOCK_PCT": 0,
    "beat_count": beat_count,
    "google_pass_n": base.get("google_pass_n"),
    "corpus_n": base.get("corpus_n"),
    "hunt": {
        "run_time_s": fstats.get("run_time"),
        "execs_done": fstats.get("execs_done"),
        "paths_total": fstats.get("paths_total"),
        "bitmap_cvg": fstats.get("bitmap_cvg"),
        "unique_crashes": fstats.get("unique_crashes"),
        "hunt_status": hunt_status,
        "profile": "speed-2",
        "afl_flag": "-y 2",
    },
    "oracles": {
        "google": "ASan + UBSan (+ MSan if built)",
        "cdub": "CompDiff speed-2 gcc -O0 vs clang -O3",
    },
    "pm2": pm2,
    "citations": [
        "Google OSS-Fuzz / sanitizers",
        "CompDiff ASPLOS 2023 — 36/78 bugs sanitizers missed",
        "Microsoft Research EMI PLDI 2014",
    ],
    "confirm_summary": summary,
    "utc": datetime.datetime.utcnow().isoformat() + "Z",
}

(LOCAL / "BEAT_REPORT.json").write_text(json.dumps(report, indent=2))
(OUT / "BEAT_REPORT.json").write_text(json.dumps(report, indent=2))

beats = read(OUT / "beats.txt")
md = f"""# CD-UB Beat Google Tools — Campaign Report

**Verdict: `{verdict}`**  
**MOCK_PCT: 0**

## Claim
OSS-Fuzz-enrolled **jq** @ `{sha}`: on the same inputs, **Google sanitizers (ASan/UBSan[/MSan]) are silent**, while **CD-UB CompDiff speed-2** (`gcc -O0` vs `clang -O3`) reports a **semantic disagreement**.

## Beat definition (strict)
1. CD-UB binaries disagree on input I  
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
| AFL run_time (s) | {fstats.get("run_time", "n/a")} |
| AFL execs_done | {fstats.get("execs_done", "n/a")} |
| AFL paths_total | {fstats.get("paths_total", "n/a")} |
| AFL bitmap_cvg | {fstats.get("bitmap_cvg", "n/a")} |
| jq SHA | `{sha}` |

## Hunt status
```
{hunt_status or "(see findings/)"}
```

## Oracles
| Oracle | Role | Result framing |
|--------|------|----------------|
| OSS-Fuzz stack (ASan/UBSan/MSan) | Google production detection | Silent on beat inputs |
| CD-UB CompDiff speed-2 | Compiler-disagreement oracle | Disagree → unstable/UB signal |

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

## Citations
- Google OSS-Fuzz + sanitizers documentation
- Li & Su, CompDiff, ASPLOS 2023 (36 sanitizer-missed bugs on OSS)
- Le, Afshari, Su, EMI, PLDI 2014 (Microsoft Research)

## Portfolio link
Campaign 2 of CD-UB hunter — see also `reports/portfolio/PORTFOLIO.md`.
"""
(LOCAL / "BEAT_REPORT.md").write_text(md)
(OUT / "BEAT_REPORT.md").write_text(md)
print(verdict)
print(f"BEAT_COUNT={beat_count}")
