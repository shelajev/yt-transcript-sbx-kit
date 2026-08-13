#!/usr/bin/env bash
# Extract one JPEG still per timestamp from a local video file.
#
# Usage: extract_frames.sh <video> <outdir> <timestamp1> [timestamp2 ...]
# Timestamps may be HH:MM:SS or MM:SS. Outputs are named f_<compact-time>.jpg.
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: extract_frames.sh <video> <outdir> <timestamp1> [timestamp2 ...]" >&2
  exit 2
fi

video="$1"
outdir="$2"
shift 2

if [ ! -f "$video" ]; then
  echo "Video file not found: $video" >&2
  exit 1
fi

mkdir -p "$outdir"

for timestamp in "$@"; do
  name="${timestamp//:/}"
  output="$outdir/f_${name}.jpg"
  ffmpeg -nostdin -y -ss "$timestamp" -i "$video" -frames:v 1 -q:v 2 \
    "$output" 2>/dev/null
  echo "$output  (t=$timestamp)"
done
