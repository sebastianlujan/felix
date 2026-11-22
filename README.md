# no_name_yet_but_zk_fe

A library ingot written in [Fe](https://fe-lang.org). It has no contract of its own; other ingots import it.

## Quick path

Requires the `fe` CLI (built with 26.6.0).

```sh
fe check   # type-check
fe test    # run the tests
fe fmt     # format the sources
```

`fe test` should end with `test result: ok`.

> `fe build` fails with "No contracts found to build". That is expected: a library produces no bytecode.

## Use it from another ingot

Add it to the consumer's `fe.toml`. The path must be relative.

```toml
[dependencies]
zk = { path = "../no-name-yet-but-zk-fe" }
```

Then import through the dependency name:

```fe
use zk::add
```

## Layout

| Path | Purpose |
|------|---------|
| `fe.toml` | Ingot name and version |
| `src/lib.fe` | Library entry point and tests |
