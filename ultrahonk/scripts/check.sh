#!/usr/bin/env bash
# Builds and tests everything in the entry, and stops at the first failure.
#
#   ultrahonk/scripts/check.sh
#
# Needs `fe`, and for the steps after the three contracts `xxd`, `shasum` and `python3`. It
# needs neither `bb` nor `nargo`, and it writes nothing into the repository: the contracts are
# built, and the verifiers generated, in a temporary directory.
set -euo pipefail

cd "$(dirname "$0")/../.."

FE_VERSION=26.6.0     # the version every measurement in the READMEs was taken with
CODE_SIZE_LIMIT=24576 # EIP-170: the largest runtime a chain accepts

command -v fe >/dev/null || { echo "fe is not installed (https://fe-lang.org)" >&2; exit 1; }
case "$(fe --version)" in
    "fe $FE_VERSION"*) ;;
    *) echo "warning: $(fe --version) found; the entry was built and measured with fe $FE_VERSION" >&2 ;;
esac

step() { printf '\n== %s\n' "$*"; }

for ingot in ultrahonk/key ultrahonk/lib ultrahonk/relations ultrahonk/verifier ultrahonk/vault honk-toy; do
    step "$ingot: format"
    (cd "$ingot" && fe fmt --check)
    step "$ingot: test"
    (cd "$ingot" && fe test) | tail -n 1
done

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
# build DIR CONTRACT: builds the contract of an ingot at the three levels, prints the size of each
# runtime and fails if one exceeds the limit.
build() {
    local dir=$1 contract=$2 level size
    for level in 1 2 s; do
        (cd "$dir" && fe build --contract "$contract" -O "$level" --out-dir "$out/build/${dir##*/}/$level" >/dev/null)
        # The artifact is hex text: two characters per byte.
        size=$(($(tr -d '\n' <"$out/build/${dir##*/}/$level/$contract.runtime.bin" | wc -c) / 2))
        printf '%-14s -O %s  %6d bytes\n' "$contract" "$level" "$size"
        [ "$size" -le "$CODE_SIZE_LIMIT" ] || { echo "$contract exceeds the code size limit" >&2; exit 1; }
    done
}

step "contracts: build at -O 1, -O 2 and -O s, runtime size against $CODE_SIZE_LIMIT bytes"
for pair in relations:HonkRelations verifier:HonkVerifier vault:Vault; do
    build "ultrahonk/${pair%%:*}" "${pair##*:}"
done

step "generated verifier: the key of Garaga's recursive bundle, format, build and runtime size"
ultrahonk/scripts/proof_to_fe.sh --verifier ultrahonk/vectors/garaga/recursive "$out/garaga_recursive" >/dev/null
(cd "$out/garaga_recursive" && fe fmt --check)
build "$out/garaga_recursive" HonkVerifier

step "generated verifier: with the pinned key it is the committed HonkVerifier"
ultrahonk/scripts/proof_to_fe.sh --verifier ultrahonk/vectors "$out/pinned" >/dev/null
(cd "$out/pinned" && fe build --contract HonkVerifier -O 1 --out-dir "$out/build/pinned" >/dev/null)
cmp "$out/build/pinned/HonkVerifier.runtime.bin" "$out/build/verifier/1/HonkVerifier.runtime.bin"
echo "OK: the two runtimes at -O 1 are the same bytes"

step "generated verifier: a key with LOG_N outside 1 to 25 is refused"
for log_n in 0 26; do
    mkdir "$out/log_n_$log_n"
    { printf '%064x' "$log_n" | xxd -r -p; tail -c +33 ultrahonk/vectors/vk; } >"$out/log_n_$log_n/vk"
    cp ultrahonk/vectors/vk_hash "$out/log_n_$log_n/"
    if message=$(ultrahonk/scripts/proof_to_fe.sh --verifier "$out/log_n_$log_n" "$out/refused" 2>&1); then
        echo "a key with LOG_N = $log_n was accepted" >&2
        exit 1
    fi
    [[ $message == *"LOG_N is $log_n"* ]] || { echo "refused for another reason: $message" >&2; exit 1; }
    echo "OK: $message"
done
# A mistyped mode must not fall through to the default one, which prints and exits 0.
if ultrahonk/scripts/proof_to_fe.sh --verifer >/dev/null 2>&1; then
    echo "an unknown mode of proof_to_fe.sh was accepted" >&2
    exit 1
fi
echo "OK: an unknown mode is refused"

step "pinned vectors: the Fe constants equal the raw bb output"
ultrahonk/scripts/proof_to_fe.sh --check

step "toy vectors: the committed file is what the Python reference generates"
python3 honk-toy/reference/gen_vectors.py --check

printf '\nAll checks passed.\n'
