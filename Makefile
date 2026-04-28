PROJECT_NAME ?= game
OUTPUT_ROM := $(PROJECT_NAME).gbc
CART_NAME ?= $(PROJECT_NAME)

# Adjust these for your environment/layout as needed.
ZGB_PATH ?= ZGB/common
ZGB_PATH_RESOLVED := $(if $(filter ~/%,$(ZGB_PATH)),$(HOME)/$(patsubst ~/%,%,$(ZGB_PATH)),$(ZGB_PATH))
ZGB_PATH_RESOLVED := $(patsubst %/,%,$(ZGB_PATH_RESOLVED))
ifneq ($(wildcard ZGB/common/include/main.h),)
ifeq ($(wildcard $(ZGB_PATH_RESOLVED)/include/main.h),)
ZGB_PATH_RESOLVED := ZGB/common
endif
endif
GBDK_HOME ?= /usr/share/gbdk-2020
PYTHON ?= python3
EMULATOR ?= mgba-qt
AUTO_RUN ?= 1
SMOKE_ROM ?= smoke.gbc

GENERATED_DIR ?= Generated
BUILD_DIR ?= Build

# Optional asset generation inputs (disabled by default).
USE_LDTK ?= 0
LDTK_FILE ?=
LDTK_LAYER ?=
LDTK_MAP_PREFIX ?= $(GENERATED_DIR)/ldtk_map
USE_PNG2ASSET ?= $(USE_LDTK)
TILESET_PNG ?=
TILESET_PREFIX ?= $(GENERATED_DIR)/tiles
TILE_ALPHA_BG ?= FFFFFF

LDTK_MAP_C := $(LDTK_MAP_PREFIX).c
LDTK_MAP_H := $(LDTK_MAP_PREFIX).h
TILESET_C := $(TILESET_PREFIX).c
TILESET_H := $(TILESET_PREFIX).h

PROJECT_SRCS ?= $(wildcard *.c)
GENERATED_SRCS ?=
ifeq ($(USE_LDTK),1)
GENERATED_SRCS += $(LDTK_MAP_C)
GENERATED_SRCS += $(TILESET_C)
endif
ifeq ($(USE_PNG2ASSET),1)
GENERATED_SRCS += $(TILESET_C)
endif
GENERATED_SRCS := $(sort $(GENERATED_SRCS))

ZGB_ENGINE_SRCS := $(wildcard $(ZGB_PATH_RESOLVED)/src/*.c)
ZGB_ENGINE_ASMS := $(wildcard $(ZGB_PATH_RESOLVED)/src/*.s)
ENGINE_DEFS := -DCGB -DMUSIC_DRIVER_GBT -DLCDCF_OBJDEFAULT=LCDCF_OBJ16
ifeq ($(USE_LDTK),1)
ENGINE_DEFS += -DUSE_LDTK_MAP
endif
COMMON_INCLUDES := -I"." -I"$(GENERATED_DIR)" -I"$(ZGB_PATH_RESOLVED)/include"
COMMON_FLAGS := -DUSE_SFR_FOR_REG $(ENGINE_DEFS)

VPATH := .:$(GENERATED_DIR):$(ZGB_PATH_RESOLVED)/src

PROJECT_OBJS := $(addprefix $(BUILD_DIR)/,$(notdir $(PROJECT_SRCS:.c=.o)))
GENERATED_OBJS := $(addprefix $(BUILD_DIR)/,$(notdir $(GENERATED_SRCS:.c=.o)))
ENGINE_C_OBJS := $(addprefix $(BUILD_DIR)/,$(notdir $(ZGB_ENGINE_SRCS:.c=.o)))
ENGINE_S_OBJS := $(addprefix $(BUILD_DIR)/,$(notdir $(ZGB_ENGINE_ASMS:.s=.o)))
ALL_OBJS := $(PROJECT_OBJS) $(GENERATED_OBJS) $(ENGINE_C_OBJS) $(ENGINE_S_OBJS)
LINK_IHX := $(BUILD_DIR)/rom.ihx

.PHONY: all run smoke smoke-run doctor clean check-zgb check-sources FORCE

all: check-zgb check-sources $(OUTPUT_ROM)
ifeq ($(AUTO_RUN),1)
	$(MAKE) run OUTPUT_ROM="$(OUTPUT_ROM)" EMULATOR="$(EMULATOR)"
endif

run: $(OUTPUT_ROM)
	@if ! command -v "$(EMULATOR)" >/dev/null 2>&1; then \
		echo "Error: emulator not found: $(EMULATOR)"; \
		echo "Tip: set EMULATOR=mgba-sdl or install mgba-qt/mgba-sdl"; \
		exit 1; \
	fi
	@echo "ROM: $(abspath $(OUTPUT_ROM))"
	@sha256sum "$(OUTPUT_ROM)"
	"$(EMULATOR)" "$(abspath $(OUTPUT_ROM))"

smoke: Tools/smoke_test.c
	lcc -DUSE_SFR_FOR_REG -o "$(SMOKE_ROM)" "Tools/smoke_test.c"

smoke-run: smoke
	@if ! command -v "$(EMULATOR)" >/dev/null 2>&1; then \
		echo "Error: emulator not found: $(EMULATOR)"; \
		echo "Tip: set EMULATOR=mgba-sdl or install mgba-qt/mgba-sdl"; \
		exit 1; \
	fi
	@echo "ROM: $(abspath $(SMOKE_ROM))"
	@sha256sum "$(SMOKE_ROM)"
	"$(EMULATOR)" "$(abspath $(SMOKE_ROM))"

doctor:
	@echo "ZGB_PATH=$(ZGB_PATH)"
	@echo "ZGB_PATH_RESOLVED=$(ZGB_PATH_RESOLVED)"
	@echo "GBDK_HOME=$(GBDK_HOME)"
	@echo "PWD=$$(pwd)"
	@echo "Checking: $(ZGB_PATH_RESOLVED)/include/main.h"
	@if [ -f "$(ZGB_PATH_RESOLVED)/include/main.h" ]; then echo "OK: main.h found"; else echo "FAIL: main.h missing"; fi

$(OUTPUT_ROM): check-zgb check-sources $(GENERATED_SRCS) $(ALL_OBJS)
	lcc -DUSE_SFR_FOR_REG $(ENGINE_DEFS) -o "$@" $(ALL_OBJS) -Wm-yoA -Wm-yt1 -Wm-yc -Wm-yn"$(CART_NAME)"

$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	lcc $(COMMON_INCLUDES) $(COMMON_FLAGS) -c -o "$@" "$<"

$(BUILD_DIR)/%.o: %.s | $(BUILD_DIR)
	lcc -c -o "$@" "$<"

$(LDTK_MAP_C) $(LDTK_MAP_H): $(LDTK_FILE) Tools/ldtk_to_zgb.py | $(GENERATED_DIR)
	@if [ -z "$(LDTK_FILE)" ]; then \
		echo "Error: set LDTK_FILE when USE_LDTK=1"; \
		exit 1; \
	fi
	$(PYTHON) "Tools/ldtk_to_zgb.py" --input "$(LDTK_FILE)" --layer "$(LDTK_LAYER)" --output-prefix "$(LDTK_MAP_PREFIX)"

$(TILESET_C) $(TILESET_H): FORCE | $(GENERATED_DIR)
	@set -e; \
	if [ "$(USE_PNG2ASSET)" = "1" ]; then \
		resolved_tileset_png="$(TILESET_PNG)"; \
		if [ -z "$$resolved_tileset_png" ] && [ "$(USE_LDTK)" = "1" ] && [ -n "$(LDTK_FILE)" ]; then \
			resolved_tileset_png="$$(python3 -c 'import json, os, sys, glob; p=sys.argv[1]; root=os.path.dirname(p); data=json.load(open(p, encoding="utf-8")); layers=data.get("layerInstances") or []; rel=next((l.get("__tilesetRelPath") for l in layers if l.get("__tilesetRelPath")), ""); base=os.path.basename(rel) if rel else ""; local=glob.glob(os.path.join(root, "**", base), recursive=True) if base else []; repo=glob.glob(os.path.join(".", "**", base), recursive=True) if base else []; matches=sorted(set(local + repo), key=lambda m: (0 if "/simplified/" in m.replace("\\\\", "/") else 1, len(m))); print(matches[0] if matches else "")' "$(LDTK_FILE)")"; \
		fi; \
		if [ -z "$(TILESET_PNG)" ]; then \
			if [ -z "$$resolved_tileset_png" ]; then \
				echo "Error: could not infer TILESET_PNG from LDtk. Set TILESET_PNG explicitly."; \
				exit 1; \
			fi; \
		else \
			resolved_tileset_png="$(TILESET_PNG)"; \
		fi; \
		if [ ! -f "$$resolved_tileset_png" ]; then \
			echo "Error: TILESET_PNG does not exist: $$resolved_tileset_png"; \
			exit 1; \
		fi; \
		asset_base="$$(basename "$${resolved_tileset_png%.*}")"; \
		prepared_png="$(GENERATED_DIR)/$${asset_base}_gb4.png"; \
		if command -v magick >/dev/null 2>&1; then \
			magick "$$resolved_tileset_png" -background "#$(TILE_ALPHA_BG)" -alpha remove -colors 4 -type Palette "$$prepared_png"; \
		else \
			cp "$$resolved_tileset_png" "$$prepared_png"; \
		fi; \
		prepared_base="$${prepared_png%.*}"; \
		prepared_symbol="$$(basename "$$prepared_base")"; \
		png2asset "$$prepared_png" -map -tiles_only -keep_duplicate_tiles -noflip -use_structs; \
		cp "$${prepared_base}.c" "$(TILESET_C)"; \
		cp "$${prepared_base}.h" "$(TILESET_H)"; \
		$(PYTHON) "Tools/force_palette_color0.py" --source-c "$(TILESET_C)" --rgb 255,255,255; \
		$(PYTHON) "Tools/prepend_blank_tile.py" --source-c "$(TILESET_C)" --source-h "$(TILESET_H)"; \
		printf "\n#include <gbdk/platform.h>\n#include \"TilesInfo.h\"\n\nBANKREF(tiles)\n\nconst struct TilesInfo tiles = {\n\t(sizeof(%s_tiles) / 16u),\n\t(unsigned char*)%s_tiles,\n\t((sizeof(%s_palettes) / sizeof(%s_palettes[0])) / 4u),\n\t(unsigned int*)%s_palettes,\n\t0\n};\n" "$$prepared_symbol" "$$prepared_symbol" "$$prepared_symbol" "$$prepared_symbol" "$$prepared_symbol" >> "$(TILESET_C)"; \
		printf "\n#include <gbdk/platform.h>\n#include \"TilesInfo.h\"\nBANKREF_EXTERN(tiles)\nextern const struct TilesInfo tiles;\n" >> "$(TILESET_H)"; \
	else \
		cp "Tools/placeholder_tiles.c" "$(TILESET_C)"; \
		cp "Tools/placeholder_tiles.h" "$(TILESET_H)"; \
	fi

$(GENERATED_DIR):
	mkdir -p "$(GENERATED_DIR)"

$(BUILD_DIR):
	mkdir -p "$(BUILD_DIR)"

FORCE:

check-zgb:
	@if [ ! -f "$(ZGB_PATH_RESOLVED)/include/main.h" ]; then \
		echo "Error: main.h not found."; \
		echo "  Expected at: $(ZGB_PATH_RESOLVED)/include/main.h"; \
		exit 1; \
	fi

check-sources:
	@if [ -z "$(strip $(PROJECT_SRCS))" ]; then \
		echo "Error: no project C sources found."; \
		echo "  Add .c files in the repo root or pass PROJECT_SRCS='file1.c file2.c'"; \
		exit 1; \
	fi

clean:
	rm -rf "$(GENERATED_DIR)" "$(BUILD_DIR)" "$(OUTPUT_ROM)" *.gb *.gbc *.ihx *.map *.noi *.sym