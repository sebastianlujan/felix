#!/usr/bin/env bash
# Prints the generated part of lib/src/vectors.fe: the pinned proof, its public inputs and the
# verification key, read from the raw bb output in vectors/. Needs only bash, xxd and shasum.
#
#   scripts/proof_to_fe.sh           print the generated part
#   scripts/proof_to_fe.sh --check   fail unless lib/src/vectors.fe starts with exactly that
#
# The values captured from the reference oracle follow the generated part in vectors.fe and are
# maintained by hand; a new proof needs both.
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET=lib/src/vectors.fe

# One 32-byte word per line, as 64 hex digits.
words() { xxd -c 32 -p "$1"; }

# array NAME WORD...
array() {
    local name=$1
    shift
    printf 'pub const %s: [u256; %d] = [\n' "$name" "$#"
    printf '    0x%s,\n' "$@"
    printf ']\n'
}

# A header word of the verification key, which must fit in 32 bits, in decimal.
small() {
    [[ $1 =~ ^0{56}[0-9a-f]{8}$ ]] || { echo "unexpected vk header word: $1" >&2; exit 1; }
    printf '%d' "0x${1:56}"
}

generate() {
    local proof=($(words vectors/proof))
    local inputs=($(words vectors/public_inputs))
    local vk=($(words vectors/vk))
    local vk_hash=($(words vectors/vk_hash))
    local log_n public_inputs
    log_n=$(small "${vk[0]}")
    public_inputs=$(small "${vk[1]}")

    # bb writes the key as 3 header words and 28 points; a proof has 82 + 12 * LOG_N words.
    [ "${#vk[@]}" -eq 59 ] || { echo "vectors/vk: expected 59 words, got ${#vk[@]}" >&2; exit 1; }
    [ "${#vk_hash[@]}" -eq 1 ] || { echo "vectors/vk_hash: expected 1 word" >&2; exit 1; }
    [ "${#proof[@]}" -eq $((82 + 12 * log_n)) ] || { echo "vectors/proof: wrong length" >&2; exit 1; }
    [ "${#inputs[@]}" -eq $((public_inputs - 8)) ] || { echo "vectors/public_inputs: wrong length" >&2; exit 1; }

    cat <<'EOF'
// Test vector of the vault circuit: verification key, pinned proof, public inputs, and the
// values the reference verifier computes for them.
//
// GENERATED PART. `scripts/proof_to_fe.sh` prints everything down to the line "END OF GENERATED
// PART" from the raw `bb` 6.0.0 output in `vectors/`, and `scripts/proof_to_fe.sh --check` fails
// if this file starts with anything else. Words are 32 bytes, big-endian.
//
EOF
    shasum -a 256 vectors/proof vectors/public_inputs vectors/vk vectors/vk_hash |
        while read -r line; do printf '//   %s\n' "$line"; done
    cat <<EOF
//
// \`vectors/vk\` is three header words (\`LOG_N\`, \`NUM_PUBLIC_INPUTS\`, the public-input offset)
// followed by 28 points, two words each, already in the order the reference verifier places
// them in its multi-scalar multiplication (slots 2-29 of \`docs/zk-verifier-reference.md\`).
pub const LOG_N: usize = $log_n
pub const N: usize = $((1 << log_n))

/// Public inputs of the circuit, counting the 8 pairing-point limbs carried in the proof.
pub const NUM_PUBLIC_INPUTS: usize = $public_inputs
pub const VK_HASH: u256 = 0x${vk_hash[0]}

/// \`s1..s4, id1..id4, lagrangeFirst, lagrangeLast, qLookup, t1..t4, qm, qr, qo, qc, ql, q4,
/// qArith, qDeltaRange, qElliptic, qMemory, qNnf, qPoseidon2External, qPoseidon2Internal\`,
/// as \`x, y\` pairs. \`(0, 0)\` is the commitment to a selector the circuit does not use.
EOF
    array VK_POINTS "${vk[@]:3}"
    printf '\n/// The public inputs the caller supplies: `y` and `recipient`.\n'
    array PUBLIC_INPUTS "${inputs[@]}"
    printf '\n/// `vectors/proof`, the pinned proof (ZK proving is randomized; see README).\n'
    array PROOF "${proof[@]}"
    printf '\n// END OF GENERATED PART\n'
}

if [ "${1:-}" = "--check" ]; then
    diff <(generate) <(head -n "$(generate | wc -l)" "$TARGET")
    echo "OK: $TARGET starts with the output of scripts/proof_to_fe.sh"
else
    generate
fi
