#!/usr/bin/env bash
# Regenerates vectors/ and oracle/src/HonkVerifier.sol from circuit/.
# Uses only the project-local tools in .tools/ (see README "Tooling").
set -euo pipefail

cd "$(dirname "$0")/.."

BB=.tools/bb/bb
NARGO=.tools/nargo/bin/nargo
TARGET=evm-no-zk # Keccak transcript, no zero-knowledge masking

for tool in "$BB" "$NARGO"; do
    [ -x "$tool" ] || { echo "missing $tool: install it as described in README.md" >&2; exit 1; }
done
[ "$("$BB" --version)" = "6.0.0" ] || { echo "bb 6.0.0 required" >&2; exit 1; }
"$NARGO" --version | rg -q '^nargo version = 1\.0\.0$' || { echo "nargo 1.0.0 required" >&2; exit 1; }

rm -rf circuit/target vectors oracle/src/HonkVerifier.sol
mkdir -p vectors oracle/src

(cd circuit && "../$NARGO" execute)
"$BB" write_vk -b circuit/target/vault.json -o vectors -t "$TARGET"
"$BB" prove -b circuit/target/vault.json -w circuit/target/vault.gz -k vectors/vk -o vectors -t "$TARGET"
"$BB" write_solidity_verifier -k vectors/vk -o oracle/src/HonkVerifier.sol -t "$TARGET"

shasum -a 256 vectors/*

# Last step on purpose: with `set -e` the final line is printed only if bb accepted the proof.
"$BB" verify -k vectors/vk -p vectors/proof -i vectors/public_inputs -t "$TARGET"
echo "OK: bb $("$BB" --version) verified vectors/proof against vectors/vk"
