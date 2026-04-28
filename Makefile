PROJECT_NAME ?= game
OUTPUT_ROM := $(PROJECT_NAME).gbc

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

GENERATED_DIR ?= Generated
BUILD_DIR ?= Build

# Optional asset generation inputs (disabled by default).
USE_LDTK ?= 0
LDTK_FILE ?=
LDTK_LAYER ?=
LDTK_MAP_PREFIX ?= $(GENERATED_DIR)/ldtk_map
USE_PNG2ASSET ?= 0
TILESET_PNG ?=
TILESET_PREFIX ?= $(GENERATED_DIR)/tiles

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

.PHONY: all doctor clean check-zgb check-sources FORCE

all: check-zgb check-sources $(OUTPUT_ROM)

doctor:
	@echo "ZGB_PATH=$(ZGB_PATH)"
	@echo "ZGB_PATH_RESOLVED=$(ZGB_PATH_RESOLVED)"
	@echo "GBDK_HOME=$(GBDK_HOME)"
	@echo "PWD=$$(pwd)"
	@echo "Checking: $(ZGB_PATH_RESOLVED)/include/main.h"
	@if [ -f "$(ZGB_PATH_RESOLVED)/include/main.h" ]; then echo "OK: main.h found"; else echo "FAIL: main.h missing"; fi

$(OUTPUT_ROM): check-zgb check-sources $(GENERATED_SRCS) $(ALL_OBJS)
	sdldgb -n -m -j -w -i -k "$(GBDK_HOME)/lib/sm83/" -l sm83.lib -k "$(GBDK_HOME)/lib/gb/" -l gb.lib -g _shadow_OAM=0xC000 -g .STACK=0xDFFF "$(LINK_IHX)" "$(GBDK_HOME)/lib/gb/crt0.o" $(ALL_OBJS)
	makebin -Z -yo A -yt 1 -yc "$(LINK_IHX)" "$@"

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
	@if [ "$(USE_PNG2ASSET)" = "1" ]; then \
		if [ -z "$(TILESET_PNG)" ]; then \
			echo "Error: set TILESET_PNG when USE_PNG2ASSET=1"; \
			exit 1; \
		fi; \
		if [ ! -f "$(TILESET_PNG)" ]; then \
			echo "Error: TILESET_PNG does not exist: $(TILESET_PNG)"; \
			exit 1; \
		fi; \
		png2asset "$(TILESET_PNG)"; \
		cp "$(basename $(TILESET_PNG)).c" "$(TILESET_C)"; \
		cp "$(basename $(TILESET_PNG)).h" "$(TILESET_H)"; \
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