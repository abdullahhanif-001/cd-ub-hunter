#!/usr/bin/env python3
"""Write BEAT_REPORT.md/json from VPS campaign artifacts."""
from __future__ import annotations

import json
import os
import pathlib
import subprocess
from datetime import datetime, timezone

ROOT = pathlib.Path(os.environ.get("CDUB_ROOT", "/opt/cd-ub"))


def read_text(path: pathlib.Path, default: str = "") -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except (OSError, FileNotFoundError):
        return default


def pm2_guard_line() -> str:
    try:
        out = subprocess.check_output(
            ["bash", str(ROOT / "deploy/contabo/pm2-guard.sh")],
            text=True,
            stderr=subprocess.STDOUT,
        )
        return out.strip().splitlines()[-1]
    except (subprocess.CalledProcessError, OSError) as exc:
        return str(exc)


def build_report(
    *,
    campaign: str,
    target_label: str,
    sha_path: pathlib.Path,
    title: str,
    claim_md: str,
    portfolio_note: str,
) -> None:
    out = ROOT / "reports" / "live" / campaign
    local = ROOT / "reports" / campaign
    local.mkdir(parents=True, exist_ok=True)

    sha = read_text(sha_path)
    beat_count = int(read_text(out / "BEAT_COUNT.txt", "0") or "0")
    summary = read_text(out / "confirm_summary.txt")
    hunt_status = read_text(out / "hunt_status.txt")
    base: dict = {}
    bp = out / "sanitizer_baseline.json"
    if bp.exists():
        base = json.loads(bp.read_text(encoding="utf-8"))

    fstats: dict[str, str] = {}
    sp = out / "findings/default/fuzzer_stats"
    if sp.exists():
        for line in sp.read_text(encoding="utf-8").splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                fstats[k.strip()] = v.strip()

    verdict = "BEAT_PASS" if beat_count >= 1 else "BEAT_HOLD"
    report = {
        "title": title,
        "verdict": verdict,
        "target": target_label,
        "sha": sha,
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
        "pm2": pm2_guard_line(),
        "confirm_summary": summary,
        "utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    payload = json.dumps(report, indent=2)
    (local / "BEAT_REPORT.json").write_text(payload, encoding="utf-8")
    (out / "BEAT_REPORT.json").write_text(payload, encoding="utf-8")

    claim_body = claim_md.format(sha=sha) if "{sha}" in claim_md else claim_md
    beats = read_text(out / "beats.txt")
    md = f"""# {title}

**Verdict: `{verdict}`**  
**MOCK_PCT: 0**

## Claim
{claim_body}

## Beat definition (strict)
1. CD-UB binaries disagree on input I  
2. ASan/UBSan(/MSan) silent on I  
3. Reproducible x3  
4. Triage not NOISE  
5. PM2 guard green on VPS

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
| Target SHA | `{sha}` |

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
- PM2: `{report["pm2"]}`
- UTC: {report["utc"]}

## Portfolio link
{portfolio_note}
"""
    (local / "BEAT_REPORT.md").write_text(md, encoding="utf-8")
    (out / "BEAT_REPORT.md").write_text(md, encoding="utf-8")
    print(verdict)
    print(f"BEAT_COUNT={beat_count}")
