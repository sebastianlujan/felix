#!/usr/bin/env bash
# Builds and tests everything in the entry, and stops at the first failure.
#
#   ultrahonk/scripts/check.sh
#
# Needs `fe`, and for the last two steps `xxd`, `shasum` and `python3`. It needs neither
# `bb` nor `nargo`, and it writes nothing into the repository: the contracts are built into
# a temporary directory.
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

for ingot in ultrahonk/lib ultrahonk/relations ultrahonk/verifier ultrahonk/vault honk-toy; do
    step "$ingot: format"
    (cd "$ingot" && fe fmt --check)
    step "$ingot: test"
    (cd "$ingot" && fe test) | tail -n 1
done

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
step "contracts: build at -O 1, -O 2 and -O s, runtime size against $CODE_SIZE_LIMIT bytes"
for pair in relations:HonkRelations verifier:HonkVerifier vault:Vault; do
    ingot="${pair%%:*}"
    contract="${pair##*:}"
    for level in 1 2 s; do
        (cd "ultrahonk/$ingot" && fe build --contract "$contract" -O "$level" --out-dir "$out/$level" >/dev/null)
        # The artifact is hex text: two characters per byte.
        size=$(($(tr -d '\n' <"$out/$level/$contract.runtime.bin" | wc -c) / 2))
        printf '%-14s -O %s  %6d bytes\n' "$contract" "$level" "$size"
        [ "$size" -le "$CODE_SIZE_LIMIT" ] || { echo "$contract exceeds the code size limit" >&2; exit 1; }
    done
done

step "pinned vectors: the Fe constants equal the raw bb output"
ultrahonk/scripts/proof_to_fe.sh --check

step "toy vectors: the committed file is what the Python reference generates"
python3 honk-toy/reference/gen_vectors.py --check

printf '\nAll checks passed.\n'
