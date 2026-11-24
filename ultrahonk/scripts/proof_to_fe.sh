#!/usr/bin/env bash
# Prints Fe constants from the raw bb output in vectors/. Needs only bash, xxd and shasum;
# --verifier also needs python3.
#
#   scripts/proof_to_fe.sh                  print the generated part of lib/src/vectors.fe: the
#                                           pinned proof and its public inputs
#   scripts/proof_to_fe.sh --vk             print lib/src/vk.fe, the verification key the
#                                           verifier contract is built with, from vectors/vk and
#                                           vectors/vk_hash alone
#   scripts/proof_to_fe.sh --test-address   print lib/src/test_address_vectors.fe, the second
#                                           proof, from vectors/test_address/
#   scripts/proof_to_fe.sh --garaga NAME    print lib/src/garaga_NAME_proof.fe, a proof of another
#                                           circuit and its public inputs, from vectors/garaga/NAME/
#   scripts/proof_to_fe.sh --garaga-key NAME
#                                           print the generated part of lib/src/garaga_NAME.fe, the
#                                           verification key of that circuit
#   scripts/proof_to_fe.sh --bundle NAME    print lib/src/NAME_proof.fe, the same for a bundle made
#                                           here: vectors/NAME/, from the Noir package examples/NAME/
#   scripts/proof_to_fe.sh --bundle-key NAME
#                                           print the generated part of lib/src/NAME.fe, its key
#   scripts/proof_to_fe.sh --verifier KEY_DIR OUT_DIR
#                                           write a verifier ingot for the key bb wrote into
#                                           KEY_DIR (`vk` and `vk_hash`): OUT_DIR/fe.toml and
#                                           OUT_DIR/src/lib.fe, the key and the `HonkVerifier` of
#                                           verifier/src/lib.fe. Both directories are relative to
#                                           where the script is called from
#   scripts/proof_to_fe.sh --check          fail unless lib/src/vectors.fe starts with exactly the
#                                           first, lib/src/vk.fe is the second,
#                                           lib/src/test_address_vectors.fe the third, every
#                                           lib/src/garaga_*_proof.fe the fourth and every other
#                                           lib/src/garaga_*.fe starts with the fifth, and the same
#                                           for the two modules of the bundle `pedersen_commit`
#
# Every mode refuses a key whose LOG_N is outside 1 to 25, or with fewer than 8 public inputs.
#
# The values captured from the reference oracle follow the generated part in vectors.fe and are
# maintained by hand; a new proof needs both.
# Words are hex digits without spaces, so splitting them into arrays is intended (SC2207), and
# backticks inside single quotes are literal Fe documentation text (SC2016).
# shellcheck disable=SC2207,SC2016
set -euo pipefail

CALLER_PWD=$PWD # --verifier takes its two directories relative to it
cd "$(dirname "$0")/.."

TARGET=lib/src/vectors.fe
KEY_TARGET=lib/src/vk.fe
TEST_ADDRESS_TARGET=lib/src/test_address_vectors.fe
BB_VERSION=6.0.0 # the version of bb the keys are read as; scripts/vectors.sh checks it
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

# log_n FILE WORD: `LOG_N` of the key in FILE, its first word. The verifier sizes its arrays for
# `MAX_LOG_N = 25` (key/src/lib.fe), and its transcript underflows at 0. The explicit exits are
# for bash 3.2, which drops `set -e` inside `$(...)`.
log_n() {
    local n
    n=$(small "$2") || { echo "$1: LOG_N is outside 1 to 25" >&2; exit 1; }
    { [ "$n" -ge 1 ] && [ "$n" -le 25 ]; } || { echo "$1: LOG_N is $n, expected 1 to 25" >&2; exit 1; }
    printf '%d' "$n"
}

# num_public_inputs FILE WORD: `NUM_PUBLIC_INPUTS` of the key in FILE, its second word. It counts
# the 8 pairing-point limbs (`PAIRING_POINTS_SIZE`).
num_public_inputs() {
    local n
    n=$(small "$2") || { echo "$1: NUM_PUBLIC_INPUTS is not a 32-bit number" >&2; exit 1; }
    [ "$n" -ge 8 ] || { echo "$1: NUM_PUBLIC_INPUTS is $n, expected at least 8 (the pairing-point limbs)" >&2; exit 1; }
    printf '%d' "$n"
}

# key_constants VK VK_HASH: checks the key in the two files and prints its constants and `VK`.
# It runs inside `$(...)`, so that a refused key stops the caller before it prints anything.
key_constants() {
    local vk=($(words "$1"))
    local vk_hash=($(words "$2"))
    local log_n public_inputs

    # bb writes the key as 3 header words and 28 points.
    [ "${#vk[@]}" -eq 59 ] || { echo "$1: expected 59 words, got ${#vk[@]}" >&2; exit 1; }
    [ "${#vk_hash[@]}" -eq 1 ] || { echo "$2: expected 1 word" >&2; exit 1; }
    log_n=$(log_n "$1" "${vk[0]}") || exit 1
    public_inputs=$(num_public_inputs "$1" "${vk[1]}") || exit 1
    # key/src/lib.fe has the row of the first public input as a constant, not as a field of the key.
    [ "$(small "${vk[2]}")" -eq 5 ] || { echo "$1: the public-input offset is not 5" >&2; exit 1; }

    cat <<EOF
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
    cat <<'EOF'

/// A constant, not a function returning the struct: passed by reference, it is embedded once in
/// a contract that uses it, where the function form embedded the 56 point words three times
/// (measured, `fe build --emit sizes`).
pub const VK: VerificationKey = VerificationKey {
    log_n: LOG_N,
    num_public_inputs: NUM_PUBLIC_INPUTS,
    vk_hash: VK_HASH,
    points: VK_POINTS,
}
EOF
}

# The verification key of the vault circuit, from vectors/vk and vectors/vk_hash alone.
generate_vk() {
    local constants
    constants=$(key_constants vectors/vk vectors/vk_hash)

    cat <<'EOF'
// Verification key of the vault circuit: the key `HonkVerifier` is built with.
//
// GENERATED FILE. `scripts/proof_to_fe.sh --vk` prints it from `vectors/vk` and
// `vectors/vk_hash`, and `scripts/proof_to_fe.sh --check` fails if this file is anything else.
// Words are 32 bytes, big-endian.
//
EOF
    shasum -a 256 vectors/vk vectors/vk_hash |
        while read -r line; do printf '//   %s\n' "$line"; done
    cat <<'EOF'
//
// `vectors/vk` is three header words (`LOG_N`, `NUM_PUBLIC_INPUTS`, the public-input offset,
// which must be 5) followed by 28 points, two words each, already in the order the reference
// verifier places them in its multi-scalar multiplication (slots 2-29 of
// `docs/zk-verifier-reference.md`).
use super::types::VerificationKey

EOF
    printf '%s\n' "$constants"
}

# generate_verifier KEY_DIR OUT_DIR: an ingot with the verifier contract of one key, as
# `bb write_solidity_verifier` writes a Solidity one. The contract is copied from
# verifier/src/lib.fe, so it is the one the tests there cover.
generate_verifier() {
    local dir=$1 out=$2 constants lib
    [[ $dir == /* ]] || dir=$CALLER_PWD/$dir
    [[ $out == /* ]] || out=$CALLER_PWD/$out
    [ -f "$dir/vk" ] && [ -f "$dir/vk_hash" ] || { echo "$dir: expected the files vk and vk_hash" >&2; exit 1; }
    constants=$(key_constants "$dir/vk" "$dir/vk_hash")
    # Fe refuses an absolute dependency path. Both ends are resolved first: on macOS /var is a
    # link to /private/var.
    lib=$(python3 -c 'import os,sys;print(os.path.relpath(*map(os.path.realpath,sys.argv[1:])))' lib "$out")

    mkdir -p "$out/src"
    cat >"$out/fe.toml" <<EOF
[ingot]
name = "honk_verifier"
version = "0.1.0"

[dependencies]
ultrahonk = { path = "$lib" }
EOF
    {
        cat <<EOF
// UltraHonk verifier contract (ZK flavor) for one verification key: \`HonkVerifier\` of the
// \`ultrahonk\` library, with the key below. It is deployed with the address of a
// \`HonkRelations\` contract, which takes no key and serves every verifier.
//
// GENERATED FILE, do not edit. \`scripts/proof_to_fe.sh --verifier KEY_DIR OUT_DIR\` writes it
// from the \`vk\` and \`vk_hash\` that \`bb\` $BB_VERSION wrote into KEY_DIR; run it again for
// another key. Words are 32 bytes, big-endian.
//
EOF
        (cd "$dir" && shasum -a 256 vk vk_hash) |
            while read -r line; do printf '//   %s\n' "$line"; done
        cat <<'EOF'
use std::abi::Bytes32
use std::evm::Ctx
use ultrahonk::abi::{VerifierInfoMsg, VerifierMsg}
use ultrahonk::types::VerificationKey
use ultrahonk::verifier::verify_at

EOF
        printf '%s\n\n' "$constants"
        awk '/^pub contract HonkVerifier \{$/,/^}$/' verifier/src/lib.fe
    } >"$out/src/lib.fe"
    echo "wrote $out/fe.toml and $out/src/lib.fe"
}

generate() {
    local proof=($(words vectors/proof))
    local inputs=($(words vectors/public_inputs))
    local vk=($(words vectors/vk))
    local log_n public_inputs
    log_n=$(log_n vectors/vk "${vk[0]}")
    public_inputs=$(num_public_inputs vectors/vk "${vk[1]}")

    # A proof has 82 + 12 * LOG_N words.
    [ "${#proof[@]}" -eq $((82 + 12 * log_n)) ] || { echo "vectors/proof: wrong length" >&2; exit 1; }
    [ "${#inputs[@]}" -eq $((public_inputs - 8)) ] || { echo "vectors/public_inputs: wrong length" >&2; exit 1; }

    cat <<'EOF'
// Test vector of the vault circuit: pinned proof, public inputs, and the values the reference
// verifier computes for them. The verification key is in `vk.fe`, re-exported below.
//
// GENERATED PART. `scripts/proof_to_fe.sh` prints everything down to the line "END OF GENERATED
// PART" from the raw `bb` 6.0.0 output in `vectors/`, and `scripts/proof_to_fe.sh --check` fails
// if this file starts with anything else. Words are 32 bytes, big-endian.
//
EOF
    shasum -a 256 vectors/proof vectors/public_inputs |
        while read -r line; do printf '//   %s\n' "$line"; done
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
    log_n=$(log_n vectors/vk "${vk[0]}")

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

# bundle KIND NAME: sets, in the function that calls it, where a proof bundle is (`dir`), the
# module its key goes to (`module`) and how a generated file names its origin (`whose`,
# `source`). KIND is `garaga` for a bundle copied from Garaga (vectors/garaga/README.md), and
# `bundle` for one made here from the Noir package examples/NAME/ (vectors/NAME/README.md).
bundle() {
    if [ "$1" = garaga ]; then
        dir=vectors/garaga/$2 module=garaga_$2 whose=' of Garaga' source=$(garaga_source)
    else
        dir=vectors/$2 module=$2 whose=''
        source="// Source: the Noir package \`examples/$2/\` of this repository. Made with \`nargo\` 1.0.0
// and \`bb\` 6.0.0, target \`evm\`, and accepted by \`bb verify\` (\`$dir/README.md\`)."
    fi
}

# generate_bundle KIND NAME: the proof of another circuit and its public inputs, from a proof
# bundle. The key of the bundle gives the lengths both must have.
generate_bundle() {
    local kind=$1 name=$2 dir module whose source
    bundle "$kind" "$name"
    local proof=($(words "$dir/proof"))
    local inputs=($(words "$dir/public_inputs"))
    local vk=($(words "$dir/vk"))
    local log_n public_inputs
    log_n=$(log_n "$dir/vk" "${vk[0]}")
    public_inputs=$(num_public_inputs "$dir/vk" "${vk[1]}")

    [ "${#vk[@]}" -eq 59 ] || { echo "$dir/vk: expected 59 words, got ${#vk[@]}" >&2; exit 1; }
    [ "${#proof[@]}" -eq $((82 + 12 * log_n)) ] || { echo "$dir/proof: wrong length" >&2; exit 1; }
    [ "${#inputs[@]}" -eq $((public_inputs - 8)) ] || { echo "$dir/public_inputs: wrong length" >&2; exit 1; }

    cat <<EOF
// The \`$name\` proof bundle$whose: a proof of a circuit with \`LOG_N = $log_n\`, and its public
// inputs. Its verification key is in \`$module.fe\`.
//
$source
//
// GENERATED FILE. \`scripts/proof_to_fe.sh --$kind $name\` prints it from \`$dir/\`,
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

# generate_bundle_key KIND NAME: the verification key of a proof bundle, which is the generated
# part of its key module. The hand-written part of that module holds the tests of the bundle.
generate_bundle_key() {
    local kind=$1 name=$2 dir module whose source
    bundle "$kind" "$name"
    local vk=($(words "$dir/vk"))
    local vk_hash=($(words "$dir/vk_hash"))
    local log_n public_inputs
    log_n=$(log_n "$dir/vk" "${vk[0]}")
    public_inputs=$(num_public_inputs "$dir/vk" "${vk[1]}")

    [ "${#vk[@]}" -eq 59 ] || { echo "$dir/vk: expected 59 words, got ${#vk[@]}" >&2; exit 1; }
    [ "${#vk_hash[@]}" -eq 1 ] || { echo "$dir/vk_hash: expected 1 word" >&2; exit 1; }
    # key/src/lib.fe has the row of the first public input as a constant, not as a field of the key.
    [ "$(small "${vk[2]}")" -eq 5 ] || { echo "$dir/vk: the public-input offset is not 5" >&2; exit 1; }

    cat <<EOF
// The \`$name\` proof bundle$whose: its verification key, then the tests that verify the
// proof of \`${module}_proof.fe\` with it.
//
$source
//
// GENERATED PART. \`scripts/proof_to_fe.sh --$kind-key $name\` prints everything down to the line
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
pub const LOG_N: usize = $log_n

/// Public inputs of the circuit, counting the 8 pairing-point limbs carried in the proof.
pub const NUM_PUBLIC_INPUTS: usize = $public_inputs
pub const VK_HASH: u256 = 0x${vk_hash[0]}

EOF
    array VK_POINTS "${vk[@]:3}"
    printf '\n// END OF GENERATED PART\n'
}

case "${1:-}" in
--check)
    diff <(generate) <(head -n "$(generate | wc -l)" "$TARGET")
    echo "OK: $TARGET starts with the output of scripts/proof_to_fe.sh"
    diff <(generate_vk) "$KEY_TARGET"
    echo "OK: $KEY_TARGET is the output of scripts/proof_to_fe.sh --vk"
    diff <(generate_test_address) "$TEST_ADDRESS_TARGET"
    echo "OK: $TEST_ADDRESS_TARGET is the output of scripts/proof_to_fe.sh --test-address"
    for target in lib/src/garaga_*.fe lib/src/pedersen_commit*.fe; do
        name=${target#lib/src/}
        name=${name%.fe}
        kind=bundle
        [[ $name != garaga_* ]] || { kind=garaga name=${name#garaga_}; }
        if [[ $name == *_proof ]]; then
            name=${name%_proof}
            diff <(generate_bundle "$kind" "$name") "$target"
            echo "OK: $target is the output of scripts/proof_to_fe.sh --$kind $name"
        else
            diff <(generate_bundle_key "$kind" "$name") <(head -n "$(generate_bundle_key "$kind" "$name" | wc -l)" "$target")
            echo "OK: $target starts with the output of scripts/proof_to_fe.sh --$kind-key $name"
        fi
    done
    ;;
--vk) generate_vk ;;
--verifier) generate_verifier "${2:?usage: proof_to_fe.sh --verifier KEY_DIR OUT_DIR}" "${3:?usage: proof_to_fe.sh --verifier KEY_DIR OUT_DIR}" ;;
--test-address) generate_test_address ;;
--garaga | --bundle) generate_bundle "${1#--}" "${2:?usage: proof_to_fe.sh $1 NAME}" ;;
--garaga-key | --bundle-key)
    kind=${1#--}
    generate_bundle_key "${kind%-key}" "${2:?usage: proof_to_fe.sh $1 NAME}"
    ;;
"") generate ;;
*)
    echo "unknown mode $1: expected none, --check, --vk, --verifier, --test-address, --garaga, --garaga-key, --bundle or --bundle-key" >&2
    exit 2
    ;;
esac
