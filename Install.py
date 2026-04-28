#!/usr/bin/env python3
"""Install project dependencies."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


def ensure_zgb() -> None:
    zgb_dir = Path("ZGB")
    if zgb_dir.exists():
        print("ZGB already exists, skipping clone.")
        return

    subprocess.run(
        ["git", "clone", "https://github.com/OpenSourceJesus/ZGB", "--depth=1"],
        check=True,
    )


def check_tool(name: str) -> bool:
    return shutil.which(name) is not None


def print_runtime_guidance() -> None:
    has_mgba_qt = check_tool("mgba-qt")
    has_mgba_sdl = check_tool("mgba-sdl")

    if has_mgba_qt or has_mgba_sdl:
        installed = []
        if has_mgba_qt:
            installed.append("mgba-qt")
        if has_mgba_sdl:
            installed.append("mgba-sdl")
        print("Found emulator frontend(s): " + ", ".join(installed))
    else:
        print("No mGBA frontend found in PATH.")
        print("Install one of:")
        print("  sudo pacman -S mgba-qt")
        print("  sudo pacman -S mgba-sdl")

    print("Default Makefile behavior: `make` builds and runs with EMULATOR=mgba-qt.")
    print("Override emulator: `make EMULATOR=mgba-sdl`")
    print("Build only (no auto-run): `make AUTO_RUN=0`")


def main() -> int:
    ensure_zgb()
    print_runtime_guidance()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
