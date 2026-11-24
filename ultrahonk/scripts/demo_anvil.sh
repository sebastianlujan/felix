#!/usr/bin/env bash
# Runs the built contracts on a local node instead of the Fe test harness.
#
#   ultrahonk/scripts/demo_anvil.sh [-O 1|2|s] [--hardfork NAME]     (default: -O 1, osaka)
#
# It builds HonkRelations, HonkVerifier and Vault with `fe build`, starts `anvil`, deploys the
# three artifacts, and then:
#   1. asks the verifier for the pinned proof (true) and for the same proof with one bit
#      flipped (a revert);
#   2. sends `verify` as a transaction, to read the gas a real transaction uses;
#   3. claims through the vault as 0xc0ffe, the recipient the pinned proof was made for,
#      after showing that another caller cannot claim with it.
#
# Needs `fe`, `anvil` and `cast` (Foundry) and `xxd`. The node keeps the real code-size limit.
# Nothing is written into the repository: artifacts go to a temporary directory.
set -euo pipefail

cd "$(dirname "$0")/.."

LEVEL=1
HARDFORK=osaka
while [ $# -gt 0 ]; do
    case "$1" in
        -O) LEVEL="$2"; shift 2 ;;
        --hardfork) HARDFORK="$2"; shift 2 ;;
        *) echo "usage: $0 [-O 1|2|s] [--hardfork NAME]" >&2; exit 2 ;;
    esac
done

for tool in fe anvil cast xxd; do
    command -v "$tool" >/dev/null || { echo "missing $tool" >&2; exit 1; }
done

PORT=8555
RPC="http://127.0.0.1:$PORT"
# anvil's first default account and the recipient of the pinned proof (vectors/public_inputs).
DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
CLAIMER=0x00000000000000000000000000000000000C0FfE
Y=9

out="$(mktemp -d)"
anvil_pid=""
cleanup() {
    [ -z "$anvil_pid" ] || kill "$anvil_pid" 2>/dev/null || true
    rm -rf "$out"
}
trap cleanup EXIT

step() { printf '\n== %s\n' "$*"; }
field() { awk -v key="$1" '$1 == key { print $2 }'; }

step "build at -O $LEVEL"
for pair in relations:HonkRelations verifier:HonkVerifier vault:Vault; do
    (cd "${pair%%:*}" && fe build --contract "${pair##*:}" -O "$LEVEL" --out-dir "$out" >/dev/null)
done

step "start anvil ($HARDFORK)"
anvil --hardfork "$HARDFORK" --port "$PORT" --silent &
anvil_pid=$!
for _ in $(seq 1 50); do
    cast block-number --rpc-url "$RPC" >/dev/null 2>&1 && break
    sleep 0.1
done
cast block-number --rpc-url "$RPC" >/dev/null

# deploy <contract> <abi-encoded constructor arguments, or nothing>: prints the address.
deploy() {
    local receipt
    receipt="$(cast send --rpc-url "$RPC" --unlocked --from "$DEPLOYER" \
        --create "0x$(tr -d '\n' <"$out/$1.bin")${2#0x}")" ||
        { echo "$1 could not be deployed on $HARDFORK" >&2; exit 1; }
    printf '%-14s deployed with %8s gas, %6s bytes of code\n' "$1" \
        "$(field gasUsed <<<"$receipt")" \
        "$(cast codesize --rpc-url "$RPC" "$(field contractAddress <<<"$receipt")")" >&2
    field contractAddress <<<"$receipt"
}

step "deploy"
relations="$(deploy HonkRelations "")"
verifier="$(deploy HonkVerifier "$(cast abi-encode 'constructor(address)' "$relations")")"
vault="$(deploy Vault "$(cast abi-encode 'constructor(uint256,address)' "$Y" "$verifier")")"
[ "$(cast call --rpc-url "$RPC" "$verifier" 'relations()(address)')" = "$relations" ] ||
    { echo "the verifier does not name the relations contract it was deployed with" >&2; exit 1; }
[ "$(cast call --rpc-url "$RPC" "$vault" 'verifier()(address)')" = "$verifier" ] ||
    { echo "the vault does not name the verifier it was deployed with" >&2; exit 1; }

proof="0x$(xxd -p vectors/proof | tr -d '\n')"
inputs="[$(xxd -p -c 32 vectors/public_inputs | awk '{ printf "%s0x%s", (NR > 1 ? "," : ""), $1 }')]"

step "verify the pinned proof"
answer="$(cast call --rpc-url "$RPC" "$verifier" 'verify(bytes,bytes32[])(bool)' "$proof" "$inputs")"
echo "verify: $answer"
[ "$answer" = true ] || { echo "the pinned proof was not accepted" >&2; exit 1; }

step "verify the same proof with its last bit flipped"
last="${proof: -1}"
tampered="${proof%?}$(printf '%x' $((0x$last ^ 1)))"
if reply="$(cast call --rpc-url "$RPC" "$verifier" 'verify(bytes,bytes32[])(bool)' "$tampered" "$inputs" 2>&1)"; then
    echo "the tampered proof was answered with: $reply" >&2
    exit 1
fi
echo "reverted: $(printf '%s' "$reply" | tail -n 1)"

step "verify as a transaction"
receipt="$(cast send --rpc-url "$RPC" --unlocked --from "$DEPLOYER" "$verifier" 'verify(bytes,bytes32[])' "$proof" "$inputs")"
[ "$(field status <<<"$receipt")" = 1 ] || { echo "the verify transaction failed" >&2; exit 1; }
echo "gas used by the transaction: $(field gasUsed <<<"$receipt")"

step "claim through the vault"
if reply="$(cast call --rpc-url "$RPC" --from "$DEPLOYER" "$vault" 'claim(bytes)(bool)' "$proof" 2>&1)"; then
    echo "another caller's claim was answered with: $reply" >&2
    exit 1
fi
echo "a caller the proof was not made for: reverted"
cast rpc --rpc-url "$RPC" anvil_impersonateAccount "$CLAIMER" >/dev/null
cast rpc --rpc-url "$RPC" anvil_setBalance "$CLAIMER" 0xde0b6b3a7640000 >/dev/null
receipt="$(cast send --rpc-url "$RPC" --unlocked --from "$CLAIMER" "$vault" 'claim(bytes)' "$proof")"
[ "$(field status <<<"$receipt")" = 1 ] || { echo "the claim transaction failed" >&2; exit 1; }
echo "gas used by the claim: $(field gasUsed <<<"$receipt")"
[ "$(cast call --rpc-url "$RPC" "$vault" 'claimed()(bool)')" = true ] ||
    { echo "the vault does not record the claim" >&2; exit 1; }
winner="$(cast call --rpc-url "$RPC" "$vault" 'winner()(address)')"
echo "claimed: true, winner: $winner"
[ "$(printf '%s' "$winner" | tr 'A-F' 'a-f')" = "$(printf '%s' "$CLAIMER" | tr 'A-F' 'a-f')" ] ||
    { echo "the winner is not the claimer" >&2; exit 1; }
again="$(cast call --rpc-url "$RPC" --from "$CLAIMER" "$vault" 'claim(bytes)(bool)' "$proof")"
echo "a second claim: $again"
[ "$again" = false ] || { echo "a second claim was accepted" >&2; exit 1; }

printf '\nThe built contracts ran on anvil (%s) at -O %s.\n' "$HARDFORK" "$LEVEL"
