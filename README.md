# ZGB + LDtk setup

This project is configured to build a Game Boy Color ROM (`.gbc`) with ZGB and level data exported from LDtk.

## What is wired up

- `tools/ldtk_to_zgb.py` converts an LDtk level file into:
  - `generated/ldtk_level0_map.h`
  - `generated/ldtk_level0_map.c`
- `GameState.c` loads that generated map in `Start_StateGame()`.
- `Makefile` builds:
  - your project files (`Main.c`, `GameState.c`)
  - generated LDtk map files
  - ZGB engine sources from `$(ZGB_PATH)/src/*.c`

## Expected inputs

- LDtk level file: `Tiles/Grasslands/Level_0.ldtkl`
- LDtk tile layer name: `Grasslands`
- Tileset PNG: `Tiles/Grasslands/Grasslands.png`

You can override these at build time:

```bash
make LDTK_FILE="path/to/level.ldtkl" LDTK_LAYER="LayerName" TILESET_PNG="path/to/tiles.png"
```

## Build

```bash
make
```

Output ROM: `SlimeJump.gbc`

If `TILESET_PNG` is missing, the build uses a one-tile placeholder so compilation can still proceed while you hook up art exports.
