# felix

`felix` writes the Fe verifier of a key that `bb` 6.0.0 wrote, as `bb write_solidity_verifier`
writes a Solidity one, and takes a Noir package to its proof verified on chain in one command. It
is Fe built for the native target, and takes the limits of the key from `ultrahonk_key`, the ingot
the verifier is built with.

```sh
(cd felix && fe build --backend native --out-dir out)          # writes out/felix
felix/out/felix up path/to/noir_package                      # DIR defaults to .
```

`up` takes `bb` and `nargo` from `ultrahonk/.tools/`, as `ultrahonk/scripts/vectors.sh` does, or
from the directory in `FELIX_TOOLS` (same layout), and from `PATH` only when they are not there.
It first checks that they are `bb` 6.0.0 and `nargo` 1.0.0, and that `fe` 26.6.0, `anvil` and
`cast` are on `PATH`. In the package it then runs `nargo execute`, `bb write_vk`, `bb prove` and `bb verify`, all with
`-t evm`, writes the verifier ingot into `target/verifier`, and runs
`ultrahonk/scripts/demo_anvil.sh --key target`: `HonkRelations` and the verifier of the key are
deployed on anvil, the proof is verified, and the proof with one bit flipped is refused. It stops
at the first step that fails, with that step's exit status.

The steps one at a time:

```sh
felix/out/felix new target my-verifier          # fe.toml, src/vk.fe, src/lib.fe
felix/out/felix gen-vk target/vk > my-verifier/src/vk.fe     # another key, same contract
felix/out/felix demo target                     # ultrahonk/scripts/demo_anvil.sh --key target
```

`target` is the directory of `bb write_vk -o target -t evm`, or its `vk` file. A key outside the
limits is refused with the errors of `ultrahonk/scripts/proof_to_fe.sh`, and nothing goes to
stdout. `ultrahonk/scripts/check.sh` compares the output with that script's. `up`, `new` and
`demo` find `ultrahonk/lib` next to `felix/` when `felix` is run by its path; a copy elsewhere,
or one found by name on `PATH`, needs `FELIX_LIB` set to that directory.
