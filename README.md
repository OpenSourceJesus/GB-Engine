# GB Engine build system (ZGB + optional LDtk)

This repository is a reusable Game Boy build system based on ZGB. It can build a ROM with plain C sources, or optionally generate map/tiles data from LDtk and a PNG tileset.

## Build modes

- Default build (no LDtk generation):
  - compiles all root-level `*.c` project files
  - compiles ZGB engine sources from `ZGB/common/src`
  - writes ROM as `game.gbc` (or `<PROJECT_NAME>.gbc` if overridden)
- LDtk build (`USE_LDTK=1`):
  - runs `Tools/ldtk_to_zgb.py`
  - generates `Generated/ldtk_map.c` and `Generated/ldtk_map.h`
  - ensures a `tiles` symbol exists by generating `Generated/tiles.c`:
    - from `png2asset` when `USE_PNG2ASSET=1`
    - otherwise from `Tools/placeholder_tiles.c`

## Common commands

```bash
# default build
make

# LDtk map generation enabled
make USE_LDTK=1 LDTK_FILE="Tiles/Grasslands/Level_0.ldtkl"

# LDtk map + png2asset tileset conversion
make USE_LDTK=1 USE_PNG2ASSET=1 \
  LDTK_FILE="Tiles/Grasslands/Level_0.ldtkl" \
  TILESET_PNG="Tiles/Grasslands/Grasslands.png"
```

## Useful overrides

- `PROJECT_NAME` (default: `game`)
- `PROJECT_SRCS` (default: all root `*.c`)
- `ZGB_PATH` (default: `ZGB/common`; falls back to local `ZGB/common` when present)
- `LDTK_FILE`, `LDTK_LAYER`
- `USE_PNG2ASSET`, `TILESET_PNG`
- `GENERATED_DIR`, `BUILD_DIR`
