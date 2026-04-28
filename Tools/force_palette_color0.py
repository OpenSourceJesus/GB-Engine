#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


def parse_rgb(raw: str) -> tuple[int, int, int]:
    parts = [p.strip() for p in raw.split(",")]
    if len(parts) != 3:
        raise ValueError("RGB must be in the form R,G,B")
    values = tuple(int(p) for p in parts)
    if any(v < 0 or v > 255 for v in values):
        raise ValueError("RGB values must be between 0 and 255")
    return values


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Force first entry of png2asset palette array"
    )
    parser.add_argument("--source-c", required=True, help="Path to generated tiles .c")
    parser.add_argument("--rgb", required=True, help="Target RGB triplet (R,G,B)")
    args = parser.parse_args()

    rgb = parse_rgb(args.rgb)
    path = Path(args.source_c)
    text = path.read_text(encoding="utf-8")

    replacement = f"RGB8({rgb[0]:3d},{rgb[1]:3d},{rgb[2]:3d})"
    updated, count = re.subn(
        r"(const\s+palette_color_t\s+\w+_palettes\[\d+\]\s*=\s*\{\s*)RGB8\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)",
        rf"\1{replacement}",
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise ValueError("Could not locate palette array first color entry")

    path.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
