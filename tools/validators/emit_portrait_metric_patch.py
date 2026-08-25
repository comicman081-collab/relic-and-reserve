#!/usr/bin/env python3
"""Emit an apply_patch payload that normalizes compact portrait face metrics.

The script never writes production assets. It exists so the mechanical attribute
normalization remains reviewable through apply_patch instead of an opaque rewrite.
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PORTRAIT_DIR = ROOT / "assets" / "ui" / "portraits"
ROOT_MARKERS = (
    ' data-runtime-reference="220x250"'
    ' data-head-height-svg="164"'
    ' data-visible-face-skin-height-svg="108"'
    ' data-major-face-stroke-svg="3.5"'
    ' data-expression-geometry-version="2"'
)


def clamp_part_radius(line: str, part: str, maximum: float) -> str:
    pattern = re.compile(rf'(<(?:circle|ellipse) data-part="{part}"[^>]*\br=")([0-9.]+)(")')

    def replacement(match: re.Match[str]) -> str:
        value = float(match.group(2))
        return f"{match.group(1)}{maximum:g}{match.group(3)}" if value > maximum else match.group(0)

    return pattern.sub(replacement, line)


def normalize_face_line(line: str) -> str:
    line = re.sub(
        r'(<ellipse data-part="sclera"[^>]*\bry=")([0-9.]+)(")',
        lambda match: f'{match.group(1)}10{match.group(3)}'
        if float(match.group(2)) > 10.0 else match.group(0),
        line,
    )
    line = clamp_part_radius(line, "iris", 8.5)
    line = clamp_part_radius(line, "pupil", 4.4)
    line = clamp_part_radius(line, "highlight", 2.5)
    line = line.replace('stroke-width="6"', 'stroke-width="3.8"')
    line = line.replace('stroke-width="5"', 'stroke-width="3.5"')
    line = line.replace('stroke-width="4"', 'stroke-width="3.5"')
    return line


def normalize_expression_line(line: str) -> str:
    if "data-brow-shift-svg=" in line:
        return line
    metrics = {
        "NEUTRAL": (0, 0, 0),
        "POSITIVE": (-5, -3, -5),
        "NEGATIVE": (5, -3, 5),
    }
    for expression, (brow, eye, mouth) in metrics.items():
        marker = f'<path data-expression="{expression}"'
        replacement = (
            marker
            + f' data-brow-shift-svg="{brow}"'
            + f' data-eye-height-shift-svg="{eye}"'
            + f' data-mouth-corner-shift-svg="{mouth}"'
        )
        line = line.replace(marker, replacement)
    return line


def main() -> None:
    updates: list[tuple[Path, list[tuple[str, str]]]] = []
    for path in sorted(PORTRAIT_DIR.glob("*.svg")):
        changes: list[tuple[str, str]] = []
        for line in path.read_text(encoding="utf-8").splitlines():
            replacement = line
            if line.startswith("<svg ") and "data-runtime-reference=" not in line:
                replacement = line[:-1] + ROOT_MARKERS + ">"
            elif '<g data-layer="face">' in line:
                replacement = normalize_face_line(line)
            elif '<g data-layer="expression-anchors"' in line:
                replacement = normalize_expression_line(line)
            if replacement != line:
                changes.append((line, replacement))
        if changes:
            updates.append((path, changes))

    print("*** Begin Patch")
    for path, changes in updates:
        relative = path.relative_to(ROOT).as_posix()
        print(f"*** Update File: RELIC_AND_RESERVE_R3/{relative}")
        for old, new in changes:
            print("@@")
            print(f"-{old}")
            print(f"+{new}")
    print("*** End Patch")


if __name__ == "__main__":
    main()
