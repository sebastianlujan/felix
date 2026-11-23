#!/usr/bin/env bash
# Prints the generated part of lib/src/vectors.fe: the pinned proof, its public inputs and the
# verification key, read from the raw bb output in vectors/. Needs only bash, xxd and shasum.
#
#   scripts/proof_to_fe.sh                  print the generated part
#   scripts/proof_to_fe.sh --test-address   print lib/src/test_address_vectors.fe, the second
#                                           proof, from vectors/test_address/
#   scripts/proof_to_fe.sh --garaga NAME    print lib/src/garaga_NAME_proof.fe, a proof of another
#                                           circuit and its public inputs, from vectors/garaga/NAME/
#   scripts/proof_to_fe.sh --garaga-key NAME
#                                           print the generated part of lib/src/garaga_NAME.fe, the
#                                           verification key of that circuit
#   scripts/proof_to_fe.sh --check          fail unless lib/src/vectors.fe starts with exactly the
#                                           first, lib/src/test_address_vectors.fe is the second,
#                                           every lib/src/garaga_*_proof.fe is the third and every
#                                           other lib/src/garaga_*.fe starts with the fourth
#
# The values captured from the reference oracle follow the generated part in vectors.fe and are
# maintained by hand; a new proof needs both.
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET=lib/src/vectors.fe
TEST_ADDRESS_TARGET=lib/src/test_address_vectors.fe
GARAGA_COMMIT=86b6025567c5e2395947f9c6d40262c9ead2a54c # the commit vectors/garaga/ was copied from

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

# The second proof: same circuit and verification key, recipient = the Fe test address.
generate_test_address() {
    local proof=($(words vectors/test_address/proof))
    local inputs=($(words vectors/test_address/public_inputs))
    local vk=($(words vectors/vk))
    local log_n
    log_n=$(small "${vk[0]}")

    [ "${#proof[@]}" -eq $((82 + 12 * log_n)) ] || { echo "vectors/test_address/proof: wrong length" >&2; exit 1; }
    [ "${#inputs[@]}" -eq 2 ] || { echo "vectors/test_address/public_inputs: expected 2 words" >&2; exit 1; }

    cat <<'EOF'
// Second test vector of the vault circuit: a proof for the same verification key
// (`vectors/vk`), made for `recipient` = the address of every Fe test contract with `fe` 26.6.0,
// the caller of the calls a test makes itself. With it a test can claim from a vault in front of
// the real verifier.
//
// GENERATED FILE. `scripts/proof_to_fe.sh --test-address` prints it from the raw `bb` 6.0.0
// output in `vectors/test_address/`, and `scripts/proof_to_fe.sh --check` fails if this file is
// anything else. Words are 32 bytes, big-endian.
//
EOF
    shasum -a 256 vectors/test_address/proof vectors/test_address/public_inputs |
        while read -r line; do printf '//   %s\n' "$line"; done
    printf '\n/// The public inputs the proof was made for: `y` and `recipient`.\n'
    array TEST_ADDRESS_PUBLIC_INPUTS "${inputs[@]}"
    printf '\n/// `vectors/test_address/proof` (ZK proving is randomized; see README).\n'
    array TEST_ADDRESS_PROOF "${proof[@]}"
}

# Where the Garaga bundles come from, for the header of every file generated from them.
garaga_source() {
    cat <<EOF
// Source: https://github.com/keep-starknet-strange/garaga at commit
// $GARAGA_COMMIT, directory
// \`hydra/garaga/starknet/honk_contract_generator/examples/\`. Licence: MIT, Copyright (c) 2023
// Keep StarkNet Strange (\`vectors/garaga/LICENSE\`). Made with \`bb\` 6.0.0, flavor
// \`ultra_keccak_zk\`, target \`evm\`, and accepted by \`bb verify\` (\`vectors/garaga/README.md\`).
EOF
}

# A proof bundle copied from Garaga (vectors/garaga/README.md): the proof of another circuit
# and its public inputs. The key of the bundle gives the lengths both must have.
generate_garaga() {
    local name=$1
    local dir=vectors/garaga/$name
    local proof=($(words "$dir/proof"))
    local inputs=($(words "$dir/public_inputs"))
    local vk=($(words "$dir/vk"))
    local log_n public_inputs
    log_n=$(small "${vk[0]}")
    public_inputs=$(small "${vk[1]}")

    [ "${#vk[@]}" -eq 59 ] || { echo "$dir/vk: expected 59 words, got ${#vk[@]}" >&2; exit 1; }
    [ "${#proof[@]}" -eq $((82 + 12 * log_n)) ] || { echo "$dir/proof: wrong length" >&2; exit 1; }
    [ "${#inputs[@]}" -eq $((public_inputs - 8)) ] || { echo "$dir/public_inputs: wrong length" >&2; exit 1; }

    cat <<EOF
// The \`$name\` proof bundle of Garaga: a proof of a circuit with \`LOG_N = $log_n\`, and its public
// inputs. Its verification key is in \`garaga_$name.fe\`.
//
$(garaga_source)
//
// GENERATED FILE. \`scripts/proof_to_fe.sh --garaga $name\` prints it from \`$dir/\`,
// and \`scripts/proof_to_fe.sh --check\` fails if this file is anything else. Words are 32 bytes,
// big-endian.
//
EOF
    shasum -a 256 "$dir/proof" "$dir/public_inputs" |
        while read -r line; do printf '//   %s\n' "$line"; done
    printf '\n/// The public inputs the caller supplies.\n'
    array PUBLIC_INPUTS "${inputs[@]}"
    printf '\n/// `%s/proof`.\n' "$dir"
    array PROOF "${proof[@]}"
}

# The verification key of a Garaga bundle: the generated part of lib/src/garaga_NAME.fe, whose
# hand-written part holds the tests of the bundle.
generate_garaga_key() {
    local name=$1
    local dir=vectors/garaga/$name
    local vk=($(words "$dir/vk"))
    local vk_hash=($(words "$dir/vk_hash"))

    [ "${#vk[@]}" -eq 59 ] || { echo "$dir/vk: expected 59 words, got ${#vk[@]}" >&2; exit 1; }
    [ "${#vk_hash[@]}" -eq 1 ] || { echo "$dir/vk_hash: expected 1 word" >&2; exit 1; }
    # sumcheck.fe has the row of the first public input as a constant, not as a field of the key.
    [ "$(small "${vk[2]}")" -eq 5 ] || { echo "$dir/vk: the public-input offset is not 5" >&2; exit 1; }

    cat <<EOF
// The \`$name\` proof bundle of Garaga: its verification key, then the tests that verify the
// proof of \`garaga_${name}_proof.fe\` with it.
//
$(garaga_source)
//
// GENERATED PART. \`scripts/proof_to_fe.sh --garaga-key $name\` prints everything down to the line
// "END OF GENERATED PART" from \`$dir/\`, and \`scripts/proof_to_fe.sh --check\` fails
// if this file starts with anything else. Words are 32 bytes, big-endian.
//
EOF
    shasum -a 256 "$dir/vk" "$dir/vk_hash" |
        while read -r line; do printf '//   %s\n' "$line"; done
    cat <<EOF
//
// \`$dir/vk\` is laid out as \`vectors/vk\` (\`vectors.fe\`): three header words, then
// the 28 points in the order of \`vectors::VK_POINTS\`.
pub const LOG_N: usize = $(small "${vk[0]}")

/// Public inputs of the circuit, counting the 8 pairing-point limbs carried in the proof.
pub const NUM_PUBLIC_INPUTS: usize = $(small "${vk[1]}")
pub const VK_HASH: u256 = 0x${vk_hash[0]}

EOF
    array VK_POINTS "${vk[@]:3}"
    printf '\n// END OF GENERATED PART\n'
}

case "${1:-}" in
--check)
    diff <(generate) <(head -n "$(generate | wc -l)" "$TARGET")
    echo "OK: $TARGET starts with the output of scripts/proof_to_fe.sh"
    diff <(generate_test_address) "$TEST_ADDRESS_TARGET"
    echo "OK: $TEST_ADDRESS_TARGET is the output of scripts/proof_to_fe.sh --test-address"
    for target in lib/src/garaga_*.fe; do
        name=${target#lib/src/garaga_}
        name=${name%.fe}
        if [[ $name == *_proof ]]; then
            name=${name%_proof}
            diff <(generate_garaga "$name") "$target"
            echo "OK: $target is the output of scripts/proof_to_fe.sh --garaga $name"
        else
            diff <(generate_garaga_key "$name") <(head -n "$(generate_garaga_key "$name" | wc -l)" "$target")
            echo "OK: $target starts with the output of scripts/proof_to_fe.sh --garaga-key $name"
        fi
    done
    ;;
--test-address) generate_test_address ;;
--garaga) generate_garaga "${2:?usage: proof_to_fe.sh --garaga NAME}" ;;
--garaga-key) generate_garaga_key "${2:?usage: proof_to_fe.sh --garaga-key NAME}" ;;
*) generate ;;
esac
