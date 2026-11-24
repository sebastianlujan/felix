# honk-fe

`honk_fe` writes the Fe verifier of a key that `bb` 6.0.0 wrote, as `bb write_solidity_verifier`
writes a Solidity one. It is Fe built for the native target, and takes the limits of the key from
`ultrahonk_key`, the ingot the verifier is built with.

```sh
(cd honk-fe && fe build --backend native --out-dir out)          # writes out/honk_fe
export HONK_FE_LIB=$PWD/ultrahonk/lib                            # new and demo need it
honk-fe/out/honk_fe new target my-verifier          # fe.toml, src/vk.fe, src/lib.fe
honk-fe/out/honk_fe gen-vk target/vk > my-verifier/src/vk.fe     # another key, same contract
honk-fe/out/honk_fe demo target                     # ultrahonk/scripts/demo_anvil.sh --key target
```

`target` is the directory of `bb write_vk -o target -t evm`, or its `vk` file. A key outside the
limits is refused with the errors of `ultrahonk/scripts/proof_to_fe.sh`, and nothing goes to
stdout. `ultrahonk/scripts/check.sh` compares the output with that script's.
