#!/usr/bin/env python3
"""
Grupperar videomappar från Duplicate Cleaner Pro 5 efter datum.

Duplicate Cleaner skapar en mapp per film med namn som:
  "7_5_2013 9_08_38 AM"  (månad_dag_år timme_minut_sekund AM/PM)

Skriptet flyttar alla filer till mappar med formatet:
  "2013-07-05"
Alla filer från samma dag hamnar i samma mapp.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

VIDEO_EXTENSIONS = {
    ".mp4", ".mov", ".avi", ".mkv", ".m4v", ".wmv",
    ".mpg", ".mpeg", ".3gp", ".mts", ".m2ts",
}

FOLDER_PATTERN = re.compile(
    r"^(\d+)_(\d+)_(\d+)\s+(\d+)_(\d+)_(\d+)\s+(AM|PM)$"
)


def parse_folder_name(name: str) -> datetime | None:
    match = FOLDER_PATTERN.match(name)
    if not match:
        return None

    month, day, year, hour, minute, second, ampm = match.groups()
    hour = int(hour)
    if ampm == "PM" and hour != 12:
        hour += 12
    elif ampm == "AM" and hour == 12:
        hour = 0

    try:
        return datetime(int(year), int(month), int(day), hour, int(minute), int(second))
    except ValueError:
        return None


def unique_dest_path(directory: Path, filename: str) -> Path:
    target = directory / filename
    if not target.exists():
        return target

    stem = Path(filename).stem
    suffix = Path(filename).suffix
    counter = 1
    while True:
        candidate = directory / f"{stem}_{counter}{suffix}"
        if not candidate.exists():
            return candidate
        counter += 1


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Gruppera Duplicate Cleaner-videomappar efter datum (YYYY-MM-DD)."
    )
    parser.add_argument("source", type=Path, help="Rotmapp med Duplicate Cleaner-mappar")
    parser.add_argument(
        "-d", "--destination",
        type=Path,
        default=None,
        help="Vart datummapparna ska skapas (standard: samma som source)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Visa vad som skulle göras utan att flytta filer",
    )
    args = parser.parse_args()

    source = args.source.resolve()
    destination = (args.destination or args.source).resolve()

    if not source.is_dir():
        print(f"Fel: Källmappen finns inte: {source}", file=sys.stderr)
        return 1

    folders = [
        p for p in source.iterdir()
        if p.is_dir() and parse_folder_name(p.name) is not None
    ]

    print(f"Hittade {len(folders)} mappar att bearbeta.")
    if args.dry_run:
        print("*** TORRKÖRNING – inga filer flyttas ***\n")

    stats = defaultdict(int)

    for folder in sorted(folders):
        dt = parse_folder_name(folder.name)
        assert dt is not None
        target_name = dt.strftime("%Y-%m-%d")
        target_dir = destination / target_name

        videos = [
            f for f in folder.iterdir()
            if f.is_file() and f.suffix.lower() in VIDEO_EXTENSIONS
        ]

        if not videos:
            print(f"  HOPPAR ÖVER (ingen video): {folder.name}")
            stats["skipped"] += 1
            continue

        for video in videos:
            if not target_dir.exists():
                if args.dry_run:
                    print(f"  SKULLE SKAPA: {target_name}/")
                else:
                    target_dir.mkdir(parents=True, exist_ok=True)

            dest = unique_dest_path(target_dir, video.name)

            if args.dry_run:
                print(f"  SKULLE FLYTTA: {video.name}  <-  {folder.name}  ->  {target_name}/")
            else:
                shutil.move(str(video), str(dest))
                print(f"  FLYTTAD: {video.name}  <-  {folder.name}  ->  {target_name}/")

            stats["moved"] += 1

        remaining = list(folder.iterdir())
        if not remaining:
            if args.dry_run:
                print(f"  SKULLE TA BORT TOM MAPP: {folder.name}")
            else:
                folder.rmdir()
            stats["removed"] += 1

    print(f"\n=== SAMMANFATTNING ===")
    print(f"Filer flyttade:     {stats['moved']}")
    print(f"Tomma mappar borta: {stats['removed']}")
    print(f"Hoppade över:       {stats['skipped']}")

    if args.dry_run:
        print("\nKör utan --dry-run för att utföra ändringarna.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
