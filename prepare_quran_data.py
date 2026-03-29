#!/usr/bin/env python3
"""
Tilawa — Quran Data Preparation Script
---------------------------------------
Run this once before opening Xcode.

Input:  quran_with_transliteration.json  (from quran-json npm package)
Output: tilawa_quran.json                (bundled into Xcode project)

Usage:
  1. Download source data:
     curl -o quran_with_transliteration.json \
       https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/quran_with_transliteration.json

  2. Run this script:
     python3 prepare_quran_data.py

  3. Copy tilawa_quran.json into your Xcode project under Resources/
"""

import json
import sys
import os

# ── CONFIG ──────────────────────────────────────────────────────────────────

INPUT_FILE  = "quran_transliteration.json"
OUTPUT_FILE = "tilawa_quran.json"

# Seconds per Arabic word at a comfortable reading pace (not fast recitation)
# Calibrated against Al-Fatiha: 29 words, ~18 seconds at normal speed = 0.62s/word
SECONDS_PER_WORD = 0.65

# Minimum display time regardless of ayah length (covers 1-2 word ayahs like Ya-Seen)
MIN_DURATION_SECONDS = 3

# Target chunk duration in seconds — we add ayahs until we meet or exceed this
CHUNK_TARGET_SECONDS = 18

# ── HELPERS ─────────────────────────────────────────────────────────────────

def count_arabic_words(text: str) -> int:
    """Count words in Arabic text. Strip harakat (diacritics) before splitting."""
    # Arabic diacritic unicode range: 0x0610–0x061A, 0x064B–0x065F, 0x0670
    import re
    clean = re.sub(r'[\u0610-\u061A\u064B-\u065F\u0670]', '', text)
    words = [w for w in clean.split() if w.strip()]
    return max(1, len(words))


def estimate_duration(word_count: int) -> int:
    """Return estimated recitation duration in whole seconds."""
    raw = word_count * SECONDS_PER_WORD
    return max(MIN_DURATION_SECONDS, round(raw))


def build_chunks(verses: list) -> list:
    """
    Group verses into chunks targeting CHUNK_TARGET_SECONDS.

    Rules:
    - Never split an ayah across chunks
    - Keep adding ayahs until chunk meets or exceeds target
    - A single ayah that exceeds target is valid as its own chunk
    - Returns list of chunk dicts with start/end ayah ids and total duration
    """
    chunks = []
    current_chunk = []
    current_duration = 0

    for verse in verses:
        current_chunk.append(verse["id"])
        current_duration += verse["duration_seconds"]

        if current_duration >= CHUNK_TARGET_SECONDS:
            chunks.append({
                "ayah_ids": list(current_chunk),
                "duration_seconds": current_duration
            })
            current_chunk = []
            current_duration = 0

    # Flush any remaining ayahs as a final chunk (end of surah)
    if current_chunk:
        chunks.append({
            "ayah_ids": list(current_chunk),
            "duration_seconds": current_duration
        })

    return chunks


# ── MAIN ────────────────────────────────────────────────────────────────────

def main():
    # Load input
    if not os.path.exists(INPUT_FILE):
        print(f"Error: {INPUT_FILE} not found.")
        print("Download it with:")
        print("  curl -o quran_transliteration.json \\")
        print("    https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/quran_transliteration.json")
        sys.exit(1)

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        raw = json.load(f)

    print(f"Loaded {len(raw)} surahs from {INPUT_FILE}")

    output = []
    total_ayahs = 0
    total_chunks = 0

    for surah in raw:
        processed_verses = []

        for verse in surah["verses"]:
            word_count = count_arabic_words(verse["text"])
            duration   = estimate_duration(word_count)

            processed_verses.append({
                "id":              verse["id"],
                "text":            verse["text"],
                "transliteration": verse.get("transliteration", ""),
                "word_count":      word_count,
                "duration_seconds": duration
            })

        chunks = build_chunks(processed_verses)

        # quran_transliteration.json: name=Arabic, transliteration=Latin
        type_str = (surah.get("type") or "").capitalize()
        output.append({
            "id":              surah["id"],
            "name":            surah.get("transliteration", surah["name"]),
            "transliteration": surah.get("transliteration", surah["name"]),
            "name_arabic":     surah["name"],
            "type":            type_str,
            "total_verses":    surah["total_verses"],
            "verses":          processed_verses,
            "chunks":          chunks
        })

        total_ayahs  += len(processed_verses)
        total_chunks += len(chunks)

    # Write output
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    file_size_kb = os.path.getsize(OUTPUT_FILE) / 1024

    print(f"\nDone.")
    print(f"  Surahs:      {len(output)}")
    print(f"  Ayahs:       {total_ayahs}")
    print(f"  Chunks:      {total_chunks} (avg {total_ayahs/total_chunks:.1f} ayahs/chunk)")
    print(f"  Output file: {OUTPUT_FILE} ({file_size_kb:.0f} KB)")
    print(f"\nNext step: drag {OUTPUT_FILE} into your Xcode project under Resources/")


if __name__ == "__main__":
    main()
