#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extract.py — Pull translatable Japanese text out of the TyranoScript (.ks)
scenario files of "One in 20,000 raindrops" into per-file JSON worksheets.

The game directory is treated as READ-ONLY. Nothing is ever written into it.
All output goes under this project's --out folder.

Translatable units (one JSON entry each):
  type "text"   whole dialogue / narration line (keeps inline tags + [p])
  type "name"   speaker name line (#Name ...)
  type "ptext"  on-screen caption  [tb_ptext_show ... text="..."]

Skipped: [iscript]/[html] code blocks, ';' comments, '*' labels,
plain tag lines, furigana readings, and anything with no Japanese.

Usage:
  python extract.py  (auto-detects Steam installation)
  python extract.py --game "C:/path/to/game/resources/app/data/scenario" --out "./output"
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, OSError):
    pass

JP_RE = re.compile(r"[぀-ゟ゠-ヿ一-鿿々〆〻]")
PTEXT_TEXT_RE = re.compile(r'text="([^"]*)"')
TAG_RE = re.compile(r"\[[^\]]*\]")
# Tags whose only JP is an audio/asset filename in storage="..." -> never text.
AUDIO_TAG_RE = re.compile(r"\[(playse|playbgm|stopse|stopbgm|fadeinbgm|"
                          r"fadeoutbgm|movie|bg|chara_)\b")

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


def has_jp(s: str) -> bool:
    return bool(JP_RE.search(s))


def classify(core: str) -> tuple[str, str] | None:
    """Return (type, jp) for a translatable line, or None to skip.
    `core` is the line content without trailing newline / CR."""
    t = core.strip()
    if not t:
        return None
    if t.startswith(";"):
        return None
    if t.startswith("*"):
        return None

    if t.startswith("[") and "tb_ptext_show" in t:
        m = PTEXT_TEXT_RE.search(t)
        if m and has_jp(m.group(1)):
            return ("ptext", m.group(1))
        return None

    if t.startswith("#"):
        name = core.lstrip()[1:]
        if has_jp(name):
            return ("name", name)
        return None

    # A line may begin with inline tags such as [srb text="..."]漢字[erb],
    # so decide by whether Japanese remains OUTSIDE the [tags].
    # This skips [playse storage="雨.ogg"] (JP only inside a tag) while keeping ruby-led narration.
    outside = TAG_RE.sub("", core)
    if has_jp(outside):
        return ("text", core)
    return None


def extract_file(path: str) -> tuple[list[dict[str, str | int]], list[tuple[int, str]], int]:
    """Return (entries, review_lines, in_script_skipped)."""
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    lines = raw.split("\n")

    entries = []
    review = []
    in_script = False
    skipped_script = 0
    eid = 0

    for i, line in enumerate(lines, start=1):
        core = line[:-1] if line.endswith("\r") else line
        t = core.strip()

        # Track code/HTML blocks (only present in config.ks / system/*).
        if "[iscript]" in t or "[html]" in t:
            in_script = True
            continue
        if "[endscript]" in t or "[endhtml]" in t:
            in_script = False
            continue
        if in_script:
            if has_jp(core):
                skipped_script += 1
            continue

        result = classify(core)
        if result is None:
            # Safety net: log any skipped line that still has Japanese, so a
            # human can confirm nothing real was lost. Audio/scene tags carry
            # JP only inside storage="...ogg" filenames -> expected, not logged.
            if has_jp(core) and not AUDIO_TAG_RE.match(t):
                review.append((i, core))
            continue

        typ, jp = result
        entries.append({"id": eid, "line": i, "type": typ, "jp": jp, "zh": ""})
        eid += 1

    return entries, review, skipped_script


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser()
    default_game = _find_default_game_path()
    ap.add_argument("--game", default=default_game, required=(default_game is None),
                    help="path to the game's data/scenario folder" + 
                         (" (auto-detected)" if default_game else ""))
    ap.add_argument("--out", default=DEFAULT_OUT,
                    help="project output folder")
    return ap.parse_args()


def main() -> None:
    args = parse_args()

    game = os.path.abspath(args.game)
    out = os.path.abspath(args.out)
    if not os.path.isdir(game):
        print("ERROR: scenario folder not found:\n  " + game)
        sys.exit(1)

    jp_dir = os.path.join(out, "jp")
    os.makedirs(jp_dir, exist_ok=True)

    ks_files = []
    for root, _dirs, files in os.walk(game):
        for fn in files:
            if fn.lower().endswith(".ks"):
                ks_files.append(os.path.join(root, fn))
    ks_files.sort()

    total = 0
    total_script = 0
    names = {}              # name -> first file where seen
    review_all = []
    per_file = []

    for path in ks_files:
        rel = os.path.relpath(path, game).replace("\\", "/")
        entries, review, skipped = extract_file(path)
        total_script += skipped
        if not entries:
            continue
        total += len(entries)
        for e in entries:
            if e["type"] == "name":
                names.setdefault(e["jp"].strip(), rel)
        if review:
            review_all.append((rel, review))

        out_path = os.path.join(jp_dir, rel + ".json")
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"file": rel, "entries": entries}, f,
                      ensure_ascii=False, indent=1)
        per_file.append((rel, len(entries)))

    # Glossary / translator instructions
    write_glossary(out, names)

    # Review log
    if review_all:
        rp = os.path.join(out, "_review.txt")
        with open(rp, "w", encoding="utf-8") as f:
            f.write("JP-bearing tag lines that were SKIPPED (manual check):\n\n")
            for rel, review in review_all:
                f.write("== %s ==\n" % rel)
                for ln, core in review:
                    f.write("  L%d: %s\n" % (ln, core))
                f.write("\n")

    # Report
    print("Scanned %d .ks files." % len(ks_files))
    print("Files with translatable text: %d" % len(per_file))
    for rel, n in per_file:
        print("  %5d  %s" % (n, rel))
    print("-" * 40)
    print("Total entries:        %d" % total)
    print("Unique speaker names: %d" % len(names))
    print("Skipped JP in code:   %d (inside [iscript]/[html])" % total_script)
    if review_all:
        print("Review log written:   _review.txt")
    print("\nWorksheets -> %s" % jp_dir)
    print("Glossary   -> %s" % os.path.join(out, "_glossary.md"))


def write_glossary(out: str, names: dict[str, str]) -> None:
    p = os.path.join(out, "_glossary.md")
    with open(p, "w", encoding="utf-8") as f:
        f.write("# 翻譯術語表 / 譯者須知\n\n")
        f.write("## 給譯者（Opus 4.6）的規則\n\n")
        f.write("逐檔翻譯 `jp/` 下的 JSON：**只填每個 entry 的 `zh` 欄**，"
                "其餘欄位（id / line / type / jp）一律不要改。\n\n")
        f.write("標籤規則：\n")
        f.write("- `[...]` 中括號是引擎指令，**原樣保留**。最常見的 `[p]`（換頁）"
                "必須留在句尾。\n")
        f.write("- `[srb text=\"ふたば\"]双葉[erb]` 是日文振假名注音：翻成中文時"
                "**整段換成譯詞**即可（例：`雙葉`），不需要保留 srb/erb。\n")
        f.write("- `「」` 對白引號保留。`type=ptext` 的譯文保留 `-&nbsp; ... &nbsp;-` "
                "這類結構，只換中間的日文。\n")
        f.write("- `type=name` 的 `jp` 不含開頭的 `#`，直接給譯名即可。\n\n")
        f.write("- 統一使用**繁體中文**。空 `zh` 會在回填時保留日文原文，可分批翻、分批測試。\n\n")
        f.write("## 角色名 / 固定譯名（請先在此統一，再開始翻對白）\n\n")
        f.write("| 日文 | 中文譯名 | 首次出現 |\n")
        f.write("|------|----------|----------|\n")
        for name in sorted(names):
            f.write("| %s |  | %s |\n" % (name, names[name]))


if __name__ == "__main__":
    main()
