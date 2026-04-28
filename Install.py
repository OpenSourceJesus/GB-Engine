#!/usr/bin/env python3
"""Install project dependencies."""

from __future__ import annotations

import subprocess
from pathlib import Path


def main() -> int:
    zgb_dir = Path("ZGB")
    if zgb_dir.exists():
        print("ZGB already exists, skipping clone.")
        return 0

    subprocess.run(
        ["git", "clone", "https://github.com/OpenSourceJesus/ZGB", "--depth=1"],
        check=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
