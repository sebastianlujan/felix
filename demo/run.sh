#!/usr/bin/env bash
# Builds the felix command-line tool, then proves a Noir circuit and verifies the proof on a
# local anvil node with the Fe verifier generated for it.
#
#   demo/run.sh [NOIR_PACKAGE]    # default: demo/age_check
#
# Needs fe 26.6.0 and Foundry; bb 6.0.0 and nargo 1.0.0 from ultrahonk/.tools, FELIX_TOOLS or PATH.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
package="$(cd "${1:-$repo/demo/age_check}" && pwd)"

(cd "$repo/felix" && fe build --backend native --out-dir out >/dev/null)
exec "$repo/felix/out/felix" up "$package"
