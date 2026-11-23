# ADR-0002: Project-local `bb` and `nargo` instead of replacing the installed toolchain

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The pipeline needs `bb` 6.0.0 and `nargo` 1.0.0 (ADR-0001).
- The development machine has `bb` 0.84.0 and `nargo` beta.3 installed. Both are too old.
- A project rule forbids changes to global tools.
- The tools are needed only to regenerate the proof, the verification key and the local reference oracle. Running the tests needs none of them (ADR-0009).

## Decision

Download the official release binaries into `ultrahonk/.tools/`, which the root `.*` ignore rule keeps out of the repository. `~/.bb` and `~/.nargo` are not touched.

```sh
cd ultrahonk && mkdir -p .tools/bb .tools/nargo/bin
curl -sSfL https://github.com/AztecProtocol/aztec-packages/releases/download/v6.0.0/barretenberg-arm64-darwin.tar.gz | tar -xz -C .tools/bb
curl -sSfL https://github.com/noir-lang/noir/releases/download/v1.0.0/noir-aarch64-apple-darwin.tar.gz | tar -xz -C .tools/nargo/bin
.tools/bb/bb --version && .tools/nargo/bin/nargo --version   # expect 6.0.0 and 1.0.0
```

The asset names were verified for Darwin arm64.

## Outcome (2026-11-23)

Carried out as decided. `scripts/vectors.sh` calls the two binaries by path and exits unless they report `bb` 6.0.0 and `nargo` 1.0.0. The download commands are in `ultrahonk/README.md`, section "Regenerate the vector". No checksum of the archives is checked.

## Options Considered

### Option A: Project-local copies in `ultrahonk/.tools/` (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Two download commands and a version check |
| Cost | One download per checkout that regenerates vectors |
| Risk | Downloads and runs two official release binaries; asset names verified for Darwin arm64 only |
| Reproducibility | The versions are fixed in the commands |

**Pros:** The installed toolchain stays as it is. The required versions are visible in the project.  
**Cons:** The binaries are not in the repository. Other platforms need other asset names, which are not verified.

### Option B: Replace the installed toolchain

| Dimension | Assessment |
|-----------|------------|
| Complexity | Not detailed in the plan |
| Cost | Changes the machine-wide `bb` 0.84.0 / `nargo` beta.3 install |
| Risk | Breaks the project rule of no changes to global tools |
| Reproducibility | The version in use lives outside the project |

**Pros:** One toolchain on the machine.  
**Cons:** Rejected: it changes global tools.

### Option C: Use the installed versions as they are

| Dimension | Assessment |
|-----------|------------|
| Complexity | None |
| Cost | None |
| Risk | `bb` 0.84.0 and `nargo` beta.3 are too old for the pinned pipeline |
| Reproducibility | Does not produce the `bb` 6.0.0 verifier and proof that ADR-0001 pins |

**Pros:** No download.  
**Cons:** Rejected: it cannot produce the pinned artifacts.

## Trade-off Analysis

Option C does not meet ADR-0001. Between A and B, the rule against changing global tools decides: option A gives the pinned versions at the cost of two downloads, and leaves everything outside the project untouched.

## Consequences

- Easier: the pinned versions are explicit and local to the project.
- Easier: nothing outside the repository changes.
- Harder: a contributor who regenerates vectors must run the download step first.
- Harder: the commands cover Darwin arm64 only.
- Revisit: asset names for other platforms.
- Revisit: the plan specifies no integrity check (checksum) for the downloaded archives.

## Action Items

1. [x] Stage 0: confirm that `.tools/bb/bb --version` and `.tools/nargo/bin/nargo --version` print 6.0.0 and 1.0.0 before regenerating the ZK artifacts. `scripts/vectors.sh` checks both on every run.
2. [x] Stage 0: confirm the `bb` 6.0.0 flags and output file names for `-t evm`. They are the ones `scripts/vectors.sh` uses.
3. [x] Stage 8: put the download commands in the reproduce steps of `ultrahonk/README.md`.
