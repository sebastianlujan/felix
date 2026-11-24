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

## From a fresh machine

On macOS arm64, from an empty directory. Every tool except Foundry goes into the clone, under
`ultrahonk/.tools/`, which is not committed, so nothing installed on the machine is used or
changed:

```sh
# Foundry (anvil, cast), if you do not have it: https://getfoundry.sh
curl -L https://foundry.paradigm.xyz | bash && ~/.foundry/bin/foundryup
export PATH="$HOME/.foundry/bin:$PATH"

git clone https://github.com/sebastianlujan/felix.git && cd felix

# fe 26.6.0, bb 6.0.0 and nargo 1.0.0
mkdir -p ultrahonk/.tools/fe ultrahonk/.tools/bb ultrahonk/.tools/nargo/bin
curl -sSfL -o ultrahonk/.tools/fe/fe https://github.com/argotorg/fe/releases/download/v26.6.0/fe_mac_arm64
chmod +x ultrahonk/.tools/fe/fe
curl -sSfL https://github.com/AztecProtocol/aztec-packages/releases/download/v6.0.0/barretenberg-arm64-darwin.tar.gz | tar -xz -C ultrahonk/.tools/bb
curl -sSfL https://github.com/noir-lang/noir/releases/download/v1.0.0/noir-aarch64-apple-darwin.tar.gz | tar -xz -C ultrahonk/.tools/nargo/bin
export PATH="$PWD/ultrahonk/.tools/fe:$PATH"

demo/run.sh
```

- **Tested** on 2026-11-24, as written from `git clone` on, in a fresh clone with a `PATH` of
  only the system directories and Foundry (`anvil` 1.5.1-stable): the proof was verified. The
  Foundry installer was not run in that test, because Foundry was already installed.
- **On Linux x86-64**, use the files `fe_linux_amd64`, `barretenberg-amd64-linux.tar.gz` and
  `noir-x86_64-unknown-linux-gnu.tar.gz` of the same releases. Not run.
- **Also needed:** `git`, `curl`, `tar`, `python3` and `xxd`. On macOS they come with the Xcode
  Command Line Tools.
- **Other versions are refused.** `felix` takes `bb` and `nargo` from `ultrahonk/.tools` first,
  then from the directory in `FELIX_TOOLS`, then from `PATH`, and stops if their versions are not
  6.0.0 and 1.0.0.

## What happens

`demo/run.sh` builds the command-line tool `felix` with Fe's native backend, then runs
`felix up demo/age_check`, which:

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
