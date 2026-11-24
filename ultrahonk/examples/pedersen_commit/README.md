# pedersen_commit

A Noir circuit that commits to a secret with a salt. `main(secret, salt)` takes both as private
inputs and returns `std::hash::pedersen_hash([secret, salt])` as its one public output: a proof
shows that the prover knows two values that hash to it.

With the inputs of `Prover.toml`, `secret = 42` and `salt = 7`, the output is
`0x090d1d9d27a969472666023a558a40bc04e71be04da345a0b417cfa64637e004`.

The verification key of this circuit uses the elliptic-curve, lookup and range relations: its
`qElliptic`, `qLookup` and `qDeltaRange` commitments are not `(0, 0)`. `qElliptic` is `(0, 0)` in
the key of the vault circuit (`../../circuit/`) and in the three of `../../vectors/garaga/`.

## The proof bundle

`../../vectors/pedersen_commit/` was made from the files of this package on 2026-11-24, with
`nargo` 1.0.0 and `bb` 6.0.0. The package itself came from `nargo new pedersen_commit`. In its
directory:

```sh
nargo execute
bb write_vk -b target/pedersen_commit.json -o target -t evm
bb prove -b target/pedersen_commit.json -w target/pedersen_commit.gz -k target/vk -o target -t evm
bb verify -k target/vk -p target/proof -i target/public_inputs -t evm
```

They are steps 1 to 3 of "Verify your own circuit" in
[`../../README.md`](../../README.md#verify-your-own-circuit), then the check of `bb`, which
printed `Proof verified successfully`. `target/` is not committed: `proof`, `public_inputs`, `vk`
and `vk_hash` were copied from it, unchanged, into the bundle, whose
[`README.md`](../../vectors/pedersen_commit/README.md) has their sha256.
