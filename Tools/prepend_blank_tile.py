#!/usr/bin/env python3
"""Prepend one blank 8x8 tile to png2asset tile arrays."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepend a blank tile to png2asset output")
    parser.add_argument("--source-c", required=True, help="Path to generated .c file")
    parser.add_argument("--source-h", required=True, help="Path to generated .h file")
    return parser.parse_args()


def rewrite_c(path: Path) -> tuple[str, int]:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"(const\s+uint8_t\s+)(?P<symbol>[A-Za-z_][A-Za-z0-9_]*)_tiles\[(?P<count>\d+)\]\s*=\s*\{(?P<body>.*?)\};",
        re.S,
    )
    match = pattern.search(text)
    if not match:
        raise ValueError(f"Could not find png2asset tiles array in {path}")

    body = match.group("body")
    values = re.findall(r"0x[0-9A-Fa-f]{2}", body)
    values = (["0x00"] * 16) + values
    new_count = len(values)
    symbol = match.group("symbol")

    rows = []
    row_size = 16
    for idx in range(0, new_count, row_size):
        chunk = values[idx : idx + row_size]
        rows.append("\t" + ",".join(chunk))
    new_decl = (
        f"const uint8_t {symbol}_tiles[{new_count}] = {{\n"
        + ",\n".join(rows)
        + "\n};"
    )

    updated = text[: match.start()] + new_decl + text[match.end() :]
    path.write_text(updated, encoding="utf-8")
    return symbol, new_count


def rewrite_h(path: Path, symbol: str, new_count: int) -> None:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(rf"(extern\s+const\s+uint8_t\s+{re.escape(symbol)}_tiles\[)\d+(\];)")
    updated, n = pattern.subn(rf"\g<1>{new_count}\2", text, count=1)
    if n != 0:
        path.write_text(updated, encoding="utf-8")


def main() -> int:
    args = parse_args()
    c_path = Path(args.source_c)
    h_path = Path(args.source_h)

    symbol, new_count = rewrite_c(c_path)
    rewrite_h(h_path, symbol, new_count)
    print(f"Prepended blank tile to {symbol}_tiles ({new_count} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
