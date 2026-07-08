#!/usr/bin/env bash
set -euo pipefail

# Launch a sandbox using this local kit checkout layered onto an agent kit.
# Usage: ./run.sh [sandbox-name] [extra sbx args...]
#   The kit is a mixin, so pair it with an agent kit of your choice.

kit_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sandbox="${1:-yt-transcript}"

if [[ $# -gt 0 ]]; then
  shift
fi

exec sbx run --kit "$kit_dir" --kit claude "$sandbox" "$@"
