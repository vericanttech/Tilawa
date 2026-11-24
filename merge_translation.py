"""Merge an English translation CSV from QuranEnc.com into tilawa_quran.json.

Usage:
    python merge_translation.py english_saheeh.csv tilawa_quran.json [more.json ...]

Download the CSV from https://quranenc.com/en/browse/english_saheeh
("Download" -> CSV). QuranEnc's terms: the text must not be modified, the
publisher and source must be credited with the version number, the info
header must be kept, and the app should be updated when a new version is
published. This script therefore copies the text and footnotes verbatim,
and writes the CSV's info header to translation_info.txt next to each
JSON file.
"""
import csv
import io
import json
import os
import sys


def main(csv_path, json_paths):
    raw = open(csv_path, encoding="utf-8").read()
    rows = list(csv.reader(io.StringIO(raw)))
    header_index = next(i for i, r in enumerate(rows) if r[:3] == ["id", "sura", "aya"])
    info = "\n".join(cell for row in rows[:header_index] for cell in row if cell).strip()
    by_verse = {(int(r[1]), int(r[2])): (r[3], r[4]) for r in rows[header_index + 1:]}

    for path in json_paths:
        surahs = json.load(open(path, encoding="utf-8"))
        for surah in surahs:
            for verse in surah["verses"]:
                text, footnotes = by_verse[(surah["id"], verse["id"])]
                verse["translation"] = text
                if footnotes.strip():
                    verse["footnotes"] = footnotes
                else:
                    verse.pop("footnotes", None)
        with open(path, "w", encoding="utf-8") as out:
            json.dump(surahs, out, ensure_ascii=False, separators=(",", ":"))
        info_path = os.path.join(os.path.dirname(path) or ".", "translation_info.txt")
        with open(info_path, "w", encoding="utf-8") as out:
            out.write(info + "\n")
        print(f"merged {len(by_verse)} verses into {path}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
