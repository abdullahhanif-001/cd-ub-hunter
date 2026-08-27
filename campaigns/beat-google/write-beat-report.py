#!/usr/bin/env python3
"""Write BEAT_REPORT for jq campaign."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "common"))
from write_beat_report import ROOT, build_report  # noqa: E402

build_report(
    campaign="beat-google",
    target_label="jq (OSS-Fuzz enrolled)",
    sha_path=ROOT / "campaigns/beat-google/meta/jq.sha",
    title="CD-UB Beat Google Sanitizer Campaign",
    claim_md=(
        f"OSS-Fuzz-enrolled **jq** @ `{{sha}}`: on the same inputs, "
        "**Google sanitizers (ASan/UBSan[/MSan]) are silent**, while "
        "**CD-UB CompDiff speed-2** (`gcc -O0` vs `clang -O3`) reports a **semantic disagreement**."
    ),
    portfolio_note="Campaign 2 of CD-UB hunter — see `reports/portfolio/PORTFOLIO.md`.",
)
