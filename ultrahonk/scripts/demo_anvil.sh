#!/usr/bin/env bash
# Runs the built contracts on a local node instead of the Fe test harness.
#
#   ultrahonk/scripts/demo_anvil.sh [-O 1|2|s] [--hardfork NAME] [--key DIR]
#                                                                    (default: -O 1, osaka)
#
# Without --key it builds HonkRelations, HonkVerifier and Vault with `fe build`, starts `anvil`,
# deploys the three artifacts, and then:
#   1. asks the verifier for the pinned proof (true) and for the same proof with one bit
#      flipped (a revert);
#   2. sends `verify` as a transaction, to read the gas a real transaction uses;
#   3. claims through the vault as 0xc0ffe, the recipient the pinned proof was made for,
#      after showing that another caller cannot claim with it.
#
# With --key DIR it runs the verifier of another circuit: DIR, relative to where the script is
# called from, holds the `vk`, `vk_hash`, `proof` and `public_inputs` that `bb` wrote. It
# generates a verifier ingot for that key with `scripts/proof_to_fe.sh --verifier`, builds it in
# place of the committed HonkVerifier, deploys it with HonkRelations, and does steps 1 and 2 with
# the proof of DIR. The vault is left out: it is bound to the pinned circuit.
#
# Needs `fe`, `anvil` and `cast` (Foundry) and `xxd`; --key also needs `shasum` and `python3`,
# through proof_to_fe.sh. The node keeps the real code-size limit. Nothing is written into the
# repository: the artifacts and the generated ingot go to a temporary directory.
set -euo pipefail

CALLER_PWD=$PWD # --key takes its directory relative to it
cd "$(dirname "$0")/.."

LEVEL=1
HARDFORK=osaka
KEY=""          # empty: the pinned circuit, with the vault
VECTORS=vectors # the directory of the proof and the public inputs
SUBJECT="the pinned proof"
while [ $# -gt 0 ]; do
    case "$1" in
        -O) LEVEL="$2"; shift 2 ;;
        --hardfork) HARDFORK="$2"; shift 2 ;;
        --key)
            KEY="$2"
            [[ $KEY == /* ]] || KEY=$CALLER_PWD/$KEY
            VECTORS=$KEY
            SUBJECT="the proof of $2"
            shift 2
            ;;
        *) echo "usage: $0 [-O 1|2|s] [--hardfork NAME] [--key DIR]" >&2; exit 2 ;;
    esac
done
[ -f "$VECTORS/proof" ] && [ -f "$VECTORS/public_inputs" ] ||
    { echo "$VECTORS: expected the files proof and public_inputs" >&2; exit 1; }

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
# build <ingot directory> <contract>
build() { (cd "$1" && fe build --contract "$2" -O "$LEVEL" --out-dir "$out" >/dev/null); }
build relations HonkRelations
if [ -n "$KEY" ]; then
    # The generated ingot stands in for verifier/: the committed HonkVerifier is not built.
    scripts/proof_to_fe.sh --verifier "$KEY" "$out/verifier"
    build "$out/verifier" HonkVerifier
else
    build verifier HonkVerifier
    build vault Vault
fi

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
[ -n "$KEY" ] || vault="$(deploy Vault "$(cast abi-encode 'constructor(uint256,address)' "$Y" "$verifier")")"
[ "$(cast call --rpc-url "$RPC" "$verifier" 'relations()(address)')" = "$relations" ] ||
    { echo "the verifier does not name the relations contract it was deployed with" >&2; exit 1; }
[ -n "$KEY" ] || [ "$(cast call --rpc-url "$RPC" "$vault" 'verifier()(address)')" = "$verifier" ] ||
    { echo "the vault does not name the verifier it was deployed with" >&2; exit 1; }

proof="0x$(xxd -p "$VECTORS/proof" | tr -d '\n')"
inputs="[$(xxd -p -c 32 "$VECTORS/public_inputs" | awk '{ printf "%s0x%s", (NR > 1 ? "," : ""), $1 }')]"

step "verify $SUBJECT"
answer="$(cast call --rpc-url "$RPC" "$verifier" 'verify(bytes,bytes32[])(bool)' "$proof" "$inputs")"
echo "verify: $answer"
[ "$answer" = true ] || { echo "$SUBJECT was not accepted" >&2; exit 1; }

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

if [ -n "$KEY" ]; then
    printf '\nThe verifier generated for %s ran on anvil (%s) at -O %s.\n' "$VECTORS" "$HARDFORK" "$LEVEL"
    exit 0
fi

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
