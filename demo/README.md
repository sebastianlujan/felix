# Demo: prove an age is old enough, verify the proof in Fe

`age_check/` is a Noir circuit that proves a private age is at least a public minimum, without
revealing the age:

```noir
fn main(age: u8, minimum: pub u8) {
    assert(age >= minimum);
}
```

One command proves it with Barretenberg and verifies the proof on a local chain, with a verifier
written in Fe and generated for this circuit:

```sh
demo/run.sh
```

## What you need

- `fe` 26.6.0 and [Foundry](https://getfoundry.sh) (`anvil` and `cast`) on your `PATH`.
- `nargo` 1.0.0 and `bb` 6.0.0. `honk_fe` takes them from `ultrahonk/.tools` first (installed as
  in [`docs/ultrahonk.md`](../docs/ultrahonk.md)), then from the directory in `HONK_FE_TOOLS`,
  then from `PATH`. It stops if it finds other versions.

## What happens

`demo/run.sh` builds the command-line tool `honk_fe` with Fe's native backend, then runs
`honk_fe up demo/age_check`, which:

1. Checks the versions of the five tools.
2. Runs `nargo execute` with the inputs in `Prover.toml` (age 30, minimum 18), then
   `bb write_vk`, `bb prove` and `bb verify`, all with `-t evm`: a ZK UltraHonk proof with keccak
   transcripts.
3. Writes a Fe verifier ingot for this circuit's key into `age_check/target/verifier`: its key as
   Fe constants, and the `HonkVerifier` contract over the shared `ultrahonk` library.
4. Builds it, deploys `HonkRelations` and `HonkVerifier` on `anvil`, and calls
   `verify(bytes,bytes32[])` with the proof and its public inputs.

The end of the output, measured on 2026-11-24 on Osaka at `-O 1`:

```
HonkRelations  deployed with  1893267 gas,   8527 bytes of code
HonkVerifier   deployed with  3609341 gas,  16723 bytes of code

== verify the proof of .../demo/age_check/target
verify: true

== verify the same proof with its last bit flipped
reverted: ... custom error 0xa5d82e8a

== verify as a transaction
gas used by the transaction: 1480601
```

The circuit has `LOG_N` 7 and 9 public inputs: `minimum`, plus the 8 words of pairing points that
every proof carries. `0xa5d82e8a` is `ShpleminiFailed()`. The gas changes by a few hundred from run
to run, because every ZK proof is different.

## Try it

- **Too young.** Set `age = "17"` in `Prover.toml`. `nargo execute` stops with
  `Cannot satisfy constraint`: there is no witness, so there is no proof to verify.
- **The circuit's own tests.** `(cd demo/age_check && nargo test)` runs three: 30 and 18 pass, 17
  fails as expected.
- **Your own circuit.** `demo/run.sh path/to/your/noir/package` does the same for any Noir package
  with a `Prover.toml`. The steps one by one are in
  [Verify your own circuit](../ultrahonk/README.md#verify-your-own-circuit).

Everything the demo writes is under `age_check/target/`, which is not committed.
