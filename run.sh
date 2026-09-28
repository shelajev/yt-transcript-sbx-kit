#!/usr/bin/env bash
set -euo pipefail

# Launch a workload kit with this local mixin kit.
# Usage: SBX_WORKLOAD=docker.io/docker/sbx-kit-shell:1.0.0 ./run.sh [workspace] [extra workspace args...]
#   SBX_WORKLOAD names the workload kit this mixin composes onto. A composition
#   needs exactly one kind: workload kit, and the built-in agent names are not
#   kits, so they cannot stand in for one here.

kit_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workload="${SBX_WORKLOAD:-docker.io/docker/sbx-kit-shell:1.0.0}"
workspace="${1:-.}"

if [[ $# -gt 0 ]]; then
  shift
fi

exec sbx run "$workload" --kit "$kit_dir" "$workspace" "$@"
