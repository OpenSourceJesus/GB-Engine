#!/usr/bin/env python3
"""Convert an LDtk tile layer into ZGB MapInfo-compatible C files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert LDtk layer to C map data for ZGB")
    parser.add_argument("--input", required=True, help="Path to LDtk file (.ldtk or .ldtkl)")
    parser.add_argument("--layer", default="", help="LDtk layer identifier (uses first tile layer if omitted)")
    parser.add_argument(
        "--output-prefix",
        required=True,
        help="Output file prefix without extension (writes .c and .h)",
    )
    return parser.parse_args()


def load_layer(project: dict, requested_layer: str) -> dict:
    layers = project.get("layerInstances") or []
    if not layers:
        raise ValueError("No layerInstances found in LDtk file")

    tile_layers = [layer for layer in layers if layer.get("__type") in ("Tiles", "AutoLayer")]
    if not tile_layers:
        raise ValueError("No tile layers found in LDtk file")

    if requested_layer:
        for layer in tile_layers:
            if layer.get("__identifier") == requested_layer:
                return layer
        raise ValueError(f"Layer '{requested_layer}' not found")

    return tile_layers[0]


def build_tile_map(layer: dict) -> tuple[int, int, list[int]]:
    width = int(layer["__cWid"])
    height = int(layer["__cHei"])
    grid_size = int(layer["__gridSize"])

    tile_map = [0] * (width * height)

    for tile in layer.get("gridTiles", []):
        px_x, px_y = tile["px"]
        x = int(px_x // grid_size)
        y = int(px_y // grid_size)
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        tile_id = int(tile["t"]) & 0xFF
        tile_map[y * width + x] = tile_id

    return width, height, tile_map


def write_header(path: Path, symbol: str, width: int, height: int) -> None:
    guard = f"{symbol.upper()}_H"
    lines = [
        f"#ifndef {guard}",
        f"#define {guard}",
        "",
        "#include <gb/gb.h>",
        '#include "MapInfo.h"',
        "",
        f"#define {symbol.upper()}_WIDTH {width}",
        f"#define {symbol.upper()}_HEIGHT {height}",
        "",
        f"extern const unsigned char {symbol}_data[{width * height}];",
        f"extern const struct MapInfo {symbol};",
        "",
        f"#endif /* {guard} */",
        "",
    ]
    path.write_text("\n".join(lines), encoding="ascii")


def write_source(path: Path, header_name: str, symbol: str, width: int, height: int, tile_map: list[int]) -> None:
    chunk_size = 16
    rows = []
    for idx in range(0, len(tile_map), chunk_size):
        chunk = tile_map[idx : idx + chunk_size]
        rows.append("    " + ", ".join(f"0x{value:02X}" for value in chunk))

    lines = [
        f'#include "{header_name}"',
        '#include "TilesInfo.h"',
        "",
        "extern const struct TilesInfo tiles;",
        "",
        f"const unsigned char {symbol}_data[{len(tile_map)}] = {{",
        ",\n".join(rows),
        "};",
        "",
        f"const struct MapInfo {symbol} = {{",
        f"    (unsigned char*){symbol}_data,",
        f"    {width},",
        f"    {height},",
        "    0,",
        "    0,",
        "    (struct TilesInfo*)&tiles",
        "};",
        "",
    ]
    path.write_text("\n".join(lines), encoding="ascii")


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    output_prefix = Path(args.output_prefix)

    if not input_path.exists():
        raise FileNotFoundError(f"LDtk file not found: {input_path}")

    project = json.loads(input_path.read_text(encoding="utf-8"))
    layer = load_layer(project, args.layer)
    width, height, tile_map = build_tile_map(layer)

    symbol = output_prefix.name
    header_path = output_prefix.with_suffix(".h")
    source_path = output_prefix.with_suffix(".c")

    output_prefix.parent.mkdir(parents=True, exist_ok=True)
    write_header(header_path, symbol, width, height)
    write_source(source_path, header_path.name, symbol, width, height, tile_map)

    print(
        f"Wrote {source_path} and {header_path} from layer "
        f"'{layer.get('__identifier', '<unknown>')}' ({width}x{height})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
