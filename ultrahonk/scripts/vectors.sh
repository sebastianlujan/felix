#!/usr/bin/env bash
# Regenerates vectors/ from circuit/, and the local reference oracle in .oracle/.
# Uses only the project-local tools in .tools/ (see README "Regenerate the vector").
#
# Two proofs for the same verification key: vectors/proof from circuit/Prover.toml, and
# vectors/test_address/proof from circuit/Prover_test_address.toml, made for the address of
# the Fe test contract so a vault test can claim with it.
#
# Proving with the ZK target is randomized: every run writes different, valid proofs. The
# committed proofs are the pinned vectors; restore them with
# `git checkout -- vectors` unless the Fe constants are redone too. The script removes only the
# files it writes, so the Garaga bundles under `vectors/garaga/` are kept.
set -euo pipefail

cd "$(dirname "$0")/.."

BB=.tools/bb/bb
NARGO=.tools/nargo/bin/nargo
TARGET=evm # Keccak transcript with zero-knowledge masking (the ZK flavor)
ORACLE=.oracle # untracked: Barretenberg's Solidity verifier, used as a local reference only

for tool in "$BB" "$NARGO"; do
    [ -x "$tool" ] || { echo "missing $tool: install it as described in README.md" >&2; exit 1; }
done
[ "$("$BB" --version)" = "6.0.0" ] || { echo "bb 6.0.0 required" >&2; exit 1; }
"$NARGO" --version | rg -q '^nargo version = 1\.0\.0$' || { echo "nargo 1.0.0 required" >&2; exit 1; }

rm -rf circuit/target vectors/vk vectors/vk_hash vectors/proof vectors/public_inputs vectors/test_address \
    "$ORACLE/src/HonkVerifier.sol"
mkdir -p vectors/test_address "$ORACLE/src"

(cd circuit && "../$NARGO" execute)
(cd circuit && "../$NARGO" execute --prover-name Prover_test_address test_address)
"$BB" write_vk -b circuit/target/vault.json -o vectors -t "$TARGET"
"$BB" prove -b circuit/target/vault.json -w circuit/target/vault.gz -k vectors/vk -o vectors -t "$TARGET"
"$BB" prove -b circuit/target/vault.json -w circuit/target/test_address.gz -k vectors/vk -o vectors/test_address -t "$TARGET"
"$BB" write_solidity_verifier -k vectors/vk -o "$ORACLE/src/HonkVerifier.sol" -t "$TARGET"

# Compiler settings the expected values were captured with. They follow
# barretenberg/sol/foundry.toml at aztec-packages@b225653, except solc (0.8.37 there).
[ -e "$ORACLE/foundry.toml" ] || cat > "$ORACLE/foundry.toml" <<'EOF'
[profile.default]
src = "src"
out = "out"
test = "test"
libs = ["lib"]
solc = "0.8.34"
optimizer_runs = 1
bytecode_hash = "none"
evm_version = "osaka"
fs_permissions = [{ access = "read", path = "../vectors" }]
EOF

shasum -a 256 vectors/proof vectors/public_inputs vectors/vk vectors/vk_hash vectors/test_address/* \
    "$ORACLE/src/HonkVerifier.sol"

# Last step on purpose: with `set -e` the final line is printed only if bb accepted both proofs.
"$BB" verify -k vectors/vk -p vectors/proof -i vectors/public_inputs -t "$TARGET"
"$BB" verify -k vectors/vk -p vectors/test_address/proof -i vectors/test_address/public_inputs -t "$TARGET"
echo "OK: bb $("$BB" --version) verified vectors/proof and vectors/test_address/proof against vectors/vk (target $TARGET)"
