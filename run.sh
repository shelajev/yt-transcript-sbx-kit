#!/usr/bin/env bash
set -euo pipefail

# Launch an agent with this local mixin kit.
# Usage: SBX_AGENT=claude ./run.sh [workspace] [extra workspace args...]
#   Set SBX_AGENT to another built-in agent, such as codex.

kit_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
agent="${SBX_AGENT:-claude}"
workspace="${1:-.}"

if [[ $# -gt 0 ]]; then
  shift
fi

exec sbx run "$agent" --kit "$kit_dir" "$workspace" "$@"
