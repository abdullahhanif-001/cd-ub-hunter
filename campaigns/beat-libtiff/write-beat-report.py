#!/usr/bin/env python3
"""Write BEAT_REPORT for libtiff campaign."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "common"))
from write_beat_report import ROOT, build_report  # noqa: E402

build_report(
    campaign="beat-libtiff",
    target_label="libtiff v4.3.0 (OSS-Fuzz enrolled)",
    sha_path=ROOT / "campaigns/beat-libtiff/meta/libtiff.sha",
    title="CD-UB Beat Google Sanitizer Campaign — libtiff v4.3.0",
    claim_md=(
        "OSS-Fuzz-enrolled **libtiff v4.3.0**: on the same TIFF inputs, "
        "**Google sanitizers (ASan/UBSan[/MSan]) are silent**, while "
        "**CD-UB CompDiff speed-2** (`gcc -O0` vs `clang -O3`) reports "
        "**output-file disagreement** via `tiffcp -M -i @@ out.file`."
    ),
    portfolio_note="Campaign 3 of CD-UB hunter — see `reports/portfolio/PORTFOLIO.md`.",
)
