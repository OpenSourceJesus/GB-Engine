#!/usr/bin/env python3
"""Convert an LDtk tile layer into ZGB MapInfo-compatible C files."""

from __future__ import annotations

import argparse
import glob
import json
import os
import struct
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


def resolve_tileset_path(project_path: Path, layer: dict) -> Path:
    rel = str(layer.get("__tilesetRelPath") or "").strip()
    if not rel:
        raise ValueError("Layer has no __tilesetRelPath")

    base = os.path.basename(rel)
    search_roots = [str(project_path.parent), "."]
    matches: list[str] = []
    for root in search_roots:
        matches.extend(glob.glob(os.path.join(root, "**", base), recursive=True))

    if not matches:
        raise FileNotFoundError(f"Could not resolve tileset image '{rel}'")

    # Prefer simplified exports when present, otherwise shortest path.
    matches = sorted(
        set(matches),
        key=lambda m: (0 if "/simplified/" in m.replace("\\", "/") else 1, len(m)),
    )
    return Path(matches[0]).resolve()


def read_png_size(png_path: Path) -> tuple[int, int]:
    data = png_path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Invalid PNG file: {png_path}")
    width, height = struct.unpack(">II", data[16:24])
    return int(width), int(height)


def build_tile_map(project_path: Path, layer: dict) -> tuple[int, int, list[int]]:
    cell_width = int(layer["__cWid"])
    cell_height = int(layer["__cHei"])
    grid_size = int(layer["__gridSize"])
    if grid_size <= 0 or (grid_size % 8) != 0:
        raise ValueError(f"Unsupported LDtk grid size {grid_size}; must be multiple of 8")

    cell_to_bg_tile = grid_size // 8
    width = cell_width * cell_to_bg_tile
    height = cell_height * cell_to_bg_tile
    tile_map = [0] * (width * height)

    tileset_path = resolve_tileset_path(project_path, layer)
    tileset_w_px, _ = read_png_size(tileset_path)
    if (tileset_w_px % 8) != 0:
        raise ValueError(f"Tileset width must be multiple of 8: {tileset_path}")
    tileset_w_tiles = tileset_w_px // 8

    for tile in layer.get("gridTiles", []):
        px_x, px_y = tile["px"]
        x = int(px_x // grid_size)
        y = int(px_y // grid_size)
        if x < 0 or y < 0 or x >= cell_width or y >= cell_height:
            continue

        src_x, src_y = tile.get("src", [0, 0])
        src_tile_x = int(src_x // 8)
        src_tile_y = int(src_y // 8)
        base_index = src_tile_y * tileset_w_tiles + src_tile_x

        for oy in range(cell_to_bg_tile):
            for ox in range(cell_to_bg_tile):
                out_x = x * cell_to_bg_tile + ox
                out_y = y * cell_to_bg_tile + oy
                subtile_index = base_index + ox + (oy * tileset_w_tiles)
                if subtile_index >= 255:
                    raise ValueError(
                        f"Subtile index {subtile_index} exceeds supported range (max 254)"
                    )
                # Reserve map value 0 for empty cells; shift all painted tiles by +1.
                tile_map[out_y * width + out_x] = subtile_index + 1

    return width, height, tile_map


def write_header(path: Path, symbol: str, width: int, height: int) -> None:
    guard = f"{symbol.upper()}_H"
    lines = [
        f"#ifndef {guard}",
        f"#define {guard}",
        "",
        "#include <gb/gb.h>",
        "#include <gbdk/platform.h>",
        '#include "MapInfo.h"',
        "",
        f"#define {symbol.upper()}_WIDTH {width}",
        f"#define {symbol.upper()}_HEIGHT {height}",
        "",
        f"BANKREF_EXTERN({symbol})",
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
        "#include <gbdk/platform.h>",
        '#include "TilesInfo.h"',
        '#include "BankManager.h"',
        "",
        f"BANKREF({symbol})",
        "",
        "BANKREF_EXTERN(tiles)",
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
        "    BANK(tiles),",
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
    width, height, tile_map = build_tile_map(input_path, layer)

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
