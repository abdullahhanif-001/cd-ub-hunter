#!/usr/bin/env py -3
"""Convert POSIX [ tests to [[ for Sonar shelldre:S7688 (shell lines only, skips heredocs)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIRS = ["campaigns", "config", "deploy", "portfolio", "scripts", "targets", "tests"]


def convert_line(line: str) -> str:
    if line.lstrip().startswith("#"):
        return line
    text = line.replace("[[", "\x00DB\x00").replace("]]", "\x00DE\x00")
    text = re.sub(r"(^|[\s;&|()])\[", r"\1[[", text)
    text = re.sub(r"\]([\s;&|)]|$)", r"]]\1", text)
    text = text.replace("\x00DB\x00", "[[").replace("\x00DE\x00", "]]")
    return text.replace("]]]", "]]").replace("[[[", "[[")


def process_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    out: list[str] = []
    in_heredoc = False
    heredoc_marker = ""
    changed = False
    for line in original.splitlines(keepends=True):
        if not in_heredoc:
            m = re.match(r"^\s*<<-?\s*['\"]?(\w+)['\"]?\s*$", line.rstrip())
            if m and ("python3" in line or "PY" in line or "UNIT" in line):
                in_heredoc = True
                heredoc_marker = m.group(1)
                out.append(line)
                continue
            new_line = convert_line(line)
            if new_line != line:
                changed = True
            out.append(new_line)
        else:
            out.append(line)
            if line.rstrip() == heredoc_marker:
                in_heredoc = False
    updated = "".join(out)
    if changed:
        path.write_text(updated, encoding="utf-8")
    return changed


def main() -> None:
    changed = 0
    for d in DIRS:
        base = ROOT / d
        if not base.exists():
            continue
        for path in base.rglob("*.sh"):
            if process_file(path):
                changed += 1
                print(f"updated {path.relative_to(ROOT)}")
    print(f"done: {changed} files")


if __name__ == "__main__":
    main()
