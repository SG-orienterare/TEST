#!/usr/bin/env python3
"""Create folder structure from a Windows dir listing (struktur file)."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

DIR_PATTERN = re.compile(r"<DIR>\s+(.+)$")


def parse_dir_listing(path: Path) -> list[str]:
    folders: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = DIR_PATTERN.search(line)
        if match:
            folders.append(match.group(1).strip())
    return folders


def create_folders(
    listing_path: Path,
    output_root: Path,
    *,
    add_gitkeep: bool = True,
) -> int:
    names = parse_dir_listing(listing_path)
    if not names:
        raise SystemExit(f"No <DIR> entries found in {listing_path}")

    output_root.mkdir(parents=True, exist_ok=True)
    for name in names:
        folder = output_root / name
        folder.mkdir(parents=True, exist_ok=True)
        if add_gitkeep:
            (folder / ".gitkeep").touch(exist_ok=True)

    return len(names)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "listing",
        type=Path,
        help="Path to struktur/dir listing file",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("215c"),
        help="Root directory for created folders (default: 215c)",
    )
    parser.add_argument(
        "--no-gitkeep",
        action="store_true",
        help="Do not add .gitkeep files",
    )
    args = parser.parse_args()

    count = create_folders(
        args.listing,
        args.output,
        add_gitkeep=not args.no_gitkeep,
    )
    print(f"Created {count} folders under {args.output.resolve()}")


if __name__ == "__main__":
    main()
