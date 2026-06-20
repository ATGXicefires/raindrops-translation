#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
reinject.py — Write translated text from the jp/ JSON worksheets back into
copies of the .ks scenario files, producing the patch under patched/.

The game directory is READ-ONLY: originals are read but never modified.
Output goes to <out>/patched/<relpath>.ks, mirroring the scenario tree.

Safety:
  * Each entry is matched by LINE NUMBER, then VERIFIED against the stored
    `jp` before replacing. A mismatch is reported and skipped (never guessed).
  * Empty `zh` -> the original Japanese line is kept (partial translation OK).
  * Original line endings (\\r\\n vs \\n) and UTF-8 (no BOM) are preserved.

Tip: run a ROUND-TRIP TEST first — copy every `jp` into `zh`, reinject, then
diff patched/ against the originals; they must be byte-identical.

Usage:
  python reinject.py  (auto-detects Steam installation)
  python reinject.py --game "C:/path/to/game/resources/app/data/scenario" --out "./output"
"""
from __future__ import annotations

import argparse
import json
import os
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, OSError):
    pass

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.dirname(HERE)


def _find_default_game_path() -> str | None:
    """Attempt to find the game in common Steam installation paths."""
    game_subpath = "二万分の一の雨粒達 - One in 20,000 raindrops/resources/app/data/scenario"
    
    candidates = [
        os.path.join(os.environ.get("PROGRAMFILES(X86)", "C:\\Program Files (x86)"), "Steam", "steamapps", "common", game_subpath),
        os.path.join(os.environ.get("PROGRAMFILES", "C:\\Program Files"), "Steam", "steamapps", "common", game_subpath),
    ]
    
    for drive in "CDEFGHIJKLMNOPQRSTUVWXYZ":
        candidates.append(f"{drive}:\\SteamLibrary\\steamapps\\common\\{game_subpath}")
        candidates.append(f"{drive}:\\Steam\\steamapps\\common\\{game_subpath}")
        
    for path in candidates:
        if os.path.isdir(path):
            return os.path.abspath(path)
    return None


def split_cr(line: str) -> tuple[str, bool]:
    """Return (core, has_cr) for a line that may end with '\\r'."""
    if line.endswith("\r"):
        return line[:-1], True
    return line, False


def apply_entry(core: str, e: dict[str, str | int], warns: list[str], rel: str) -> str:
    """Apply one entry to the line `core`; return new core (unchanged on skip)."""
    cn = str(e.get("zh", ""))
    if cn == "":
        return core
    typ = e["type"]
    jp = e["jp"]
    ln = e["line"]

    if typ == "text":
        if core != jp:
            warns.append("%s L%d: text mismatch (kept original)" % (rel, ln))
            return core
        return cn

    if typ == "name":
        stripped = core.lstrip()
        indent = core[:len(core) - len(stripped)]
        if not stripped.startswith("#") or stripped[1:] != jp:
            warns.append("%s L%d: name mismatch (kept original)" % (rel, ln))
            return core
        return indent + "#" + cn

    if typ == "ptext":
        needle = 'text="%s"' % jp
        if needle not in core:
            warns.append("%s L%d: ptext mismatch (kept original)" % (rel, ln))
            return core
        return core.replace(needle, 'text="%s"' % cn, 1)

    warns.append("%s L%d: unknown type %r" % (rel, ln, typ))
    return core


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser()
    default_game = _find_default_game_path()
    ap.add_argument("--game", default=default_game, required=(default_game is None),
                    help="path to the game's data/scenario folder (read-only)" + 
                         (" (auto-detected)" if default_game else ""))
    ap.add_argument("--out", default=DEFAULT_OUT,
                    help="project folder containing jp/, output goes to patched/")
    return ap.parse_args()


def main() -> None:
    args = parse_args()

    game = os.path.abspath(args.game)
    out = os.path.abspath(args.out)
    jp_dir = os.path.join(out, "jp")
    patch_dir = os.path.join(out, "patched")

    if not os.path.isdir(jp_dir):
        print("ERROR: worksheets not found, run extract.py first:\n  " + jp_dir)
        sys.exit(1)

    json_files = []
    for root, _dirs, files in os.walk(jp_dir):
        for fn in files:
            if fn.lower().endswith(".json"):
                json_files.append(os.path.join(root, fn))
    json_files.sort()

    warns = []
    total_translated = 0
    total_entries = 0
    files_written = 0

    for jpath in json_files:
        with open(jpath, encoding="utf-8") as f:
            data = json.load(f)
        rel = data["file"]
        entries = data["entries"]

        src = os.path.join(game, rel)
        if not os.path.isfile(src):
            warns.append("source missing: %s" % rel)
            continue

        with open(src, encoding="utf-8") as f:
            raw = f.read()
        lines = raw.split("\n")

        for e in entries:
            total_entries += 1
            idx = e["line"] - 1
            if idx < 0 or idx >= len(lines):
                warns.append("%s L%d: line out of range" % (rel, e["line"]))
                continue
            core, has_cr = split_cr(lines[idx])
            new_core = apply_entry(core, e, warns, rel)
            if new_core != core:
                total_translated += 1
            lines[idx] = new_core + ("\r" if has_cr else "")

        dst = os.path.join(patch_dir, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8", newline="") as f:
            f.write("\n".join(lines))
        files_written += 1

    print("Worksheets processed: %d" % len(json_files))
    print("Patched files written: %d -> %s" % (files_written, patch_dir))
    print("Entries translated: %d / %d" % (total_translated, total_entries))
    if warns:
        print("\nWARNINGS (%d):" % len(warns))
        for w in warns[:50]:
            print("  " + w)
        if len(warns) > 50:
            print("  ... (%d more)" % (len(warns) - 50))
        wp = os.path.join(out, "_reinject_warnings.txt")
        with open(wp, "w", encoding="utf-8") as f:
            f.write("\n".join(warns))
        print("Full list -> %s" % wp)
    else:
        print("No warnings. All translated entries matched cleanly.")


if __name__ == "__main__":
    main()
