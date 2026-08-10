#!/usr/bin/env python3
"""Convert WebVTT captions into timestamped, deduplicated paragraphs."""

from __future__ import annotations

import argparse
import html
import re
import sys
from pathlib import Path


TIMING = re.compile(
    r"^(?:(?P<hours>\d+):)?(?P<minutes>\d{2}):(?P<seconds>\d{2}(?:\.\d+)?)\s+-->"
)
TAG = re.compile(r"<[^>]+>")
METADATA_PREFIXES = ("WEBVTT", "Kind:", "Language:", "NOTE", "STYLE", "REGION")


def parse_seconds(match: re.Match[str]) -> float:
    return (
        int(match.group("hours") or 0) * 3600
        + int(match.group("minutes")) * 60
        + float(match.group("seconds"))
    )


def remove_rolling_overlap(previous: str, current: str) -> str:
    words = current.split()
    tail = previous.split()[-80:]
    for size in range(min(len(tail), len(words), 25), 0, -1):
        if tail[-size:] == words[:size]:
            return " ".join(words[size:])
    return current


def format_timestamp(seconds: float) -> str:
    whole = int(seconds)
    hours, remainder = divmod(whole, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours:
        return f"[{hours}:{minutes:02d}:{seconds:02d}]"
    return f"[{minutes:02d}:{seconds:02d}]"


def extract_cues(vtt: str) -> list[tuple[float, str]]:
    cues: list[tuple[float, str]] = []
    timestamp: float | None = None
    lines: list[str] = []

    def flush() -> None:
        if timestamp is None or not lines:
            return
        text = " ".join(lines)
        text = remove_rolling_overlap(cues[-1][1] if cues else "", text)
        if text:
            cues.append((timestamp, text))

    for raw_line in vtt.splitlines():
        line = raw_line.strip()
        match = TIMING.match(line)
        if match:
            flush()
            timestamp, lines = parse_seconds(match), []
            continue
        if timestamp is None or not line or line.startswith(METADATA_PREFIXES):
            continue
        # Numeric cue identifiers are not spoken text.
        if line.isdigit():
            continue
        text = html.unescape(TAG.sub("", line)).strip()
        if text:
            lines.append(text)
    flush()
    return cues


def compact(cues: list[tuple[float, str]], bucket_seconds: int) -> list[str]:
    paragraphs: list[str] = []
    bucket_start: float | None = None
    words: list[str] = []
    for timestamp, text in cues:
        if bucket_start is None:
            bucket_start = timestamp
        if timestamp - bucket_start >= bucket_seconds and words:
            paragraphs.append(f"{format_timestamp(bucket_start)} {' '.join(words)}")
            bucket_start, words = timestamp, []
        words.append(text)
    if bucket_start is not None and words:
        paragraphs.append(f"{format_timestamp(bucket_start)} {' '.join(words)}")
    return paragraphs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vtt", type=Path)
    parser.add_argument("--bucket-seconds", type=int, default=30)
    args = parser.parse_args()
    if args.bucket_seconds < 1:
        parser.error("--bucket-seconds must be positive")
    try:
        source = args.vtt.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        print(f"cannot read {args.vtt}: {error}", file=sys.stderr)
        return 1
    cues = extract_cues(source)
    if not cues:
        print("no caption cues found", file=sys.stderr)
        return 1
    print("\n".join(compact(cues, args.bucket_seconds)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
