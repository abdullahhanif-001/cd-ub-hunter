#!/usr/bin/env py -3
"""Fix incomplete [[ conversions from test -x lines."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fix_line(s: str) -> str:
    if not re.match(r"^\[\[ -[a-zA-Z]", s):
        return s
    if s.rstrip().endswith("]]"):
        return s
    if " && " in s or " || " in s:
        parts = re.split(r"(\s+&&\s+|\s+\|\|\s+)", s)
        fixed_parts = []
        for part in parts:
            if part.strip() in ("&&", "||"):
                fixed_parts.append(part)
                continue
            part = part.strip()
            if part.startswith("[[") and not part.endswith("]]"):
                part = part + " ]]"
            fixed_parts.append(part)
        return "".join(fixed_parts)
    return s.rstrip() + " ]]"


def main() -> None:
    fixed_files = 0
    for path in ROOT.rglob("*.sh"):
        if "vendor" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines(keepends=True)
        out: list[str] = []
        changed = False
        for line in lines:
            nl = "\n" if line.endswith("\n") else ""
            core = line[:-1] if nl else line
            new = fix_line(core)
            if new != core:
                changed = True
            out.append(new + nl)
        if changed:
            path.write_text("".join(out), encoding="utf-8")
            fixed_files += 1
            print(path.relative_to(ROOT))
    print(f"fixed_files={fixed_files}")


if __name__ == "__main__":
    main()
