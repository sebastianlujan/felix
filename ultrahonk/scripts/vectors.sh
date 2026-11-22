#!/usr/bin/env bash
# Regenerates vectors/ from circuit/, and the local reference oracle in .oracle/.
# Uses only the project-local tools in .tools/ (see README "Regenerate the vector").
#
# Proving with the ZK target is randomized: every run writes a different, valid
# vectors/proof. The committed proof is the pinned vector; restore it with
# `git checkout -- vectors/proof` unless the constants captured from it are redone too.
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

rm -rf circuit/target vectors "$ORACLE/src/HonkVerifier.sol"
mkdir -p vectors "$ORACLE/src"

(cd circuit && "../$NARGO" execute)
"$BB" write_vk -b circuit/target/vault.json -o vectors -t "$TARGET"
"$BB" prove -b circuit/target/vault.json -w circuit/target/vault.gz -k vectors/vk -o vectors -t "$TARGET"
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

shasum -a 256 vectors/* "$ORACLE/src/HonkVerifier.sol"

# Last step on purpose: with `set -e` the final line is printed only if bb accepted the proof.
"$BB" verify -k vectors/vk -p vectors/proof -i vectors/public_inputs -t "$TARGET"
echo "OK: bb $("$BB" --version) verified vectors/proof against vectors/vk (target $TARGET)"
