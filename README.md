# TEST

Folder structure for **215c**, generated from a Windows directory listing.

## Layout

- `215c/` — 2,108 timestamp-named folders (e.g. `6_12_2022 9_14_11 AM`)
- `data/struktur_215c.txt` — source `dir` listing
- `scripts/create_folder_structure.py` — recreates the structure from the listing

## Recreate folders

```bash
python3 scripts/create_folder_structure.py data/struktur_215c.txt -o 215c
```
