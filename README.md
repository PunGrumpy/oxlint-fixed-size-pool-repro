# oxlint fixed-size pool repro

oxlint aborts before linting when JS plugins are configured and Linux refuses a single 4 GiB allocation. This repo reproduces it with oxlint 1.90.0 and a no-op JS plugin.

Upstream: oxc-project/oxc#20331. Proposed fix: oxc-project/oxc#27356.

GitHub runs: https://github.com/PunGrumpy/oxlint-fixed-size-pool-repro/actions/runs/40807872534

```
thread 'tokio-rt-worker' panicked at crates/oxc_allocator/src/pool/fixed_size.rs:112:67:
called `Result::unwrap()` on an `Err` value: ()
```

## Results

| Environment | `vm.overcommit_memory` | Native rules | JS plugin |
| --- | --- | --- | --- |
| Docker Desktop VM, 4 GB RAM, 1 GB swap | 1 | pass | pass |
| Docker Desktop VM, 4 GB RAM, 1 GB swap | 0 | pass | exit 134 |
| GitHub `ubuntu-slim`, 5 GB RAM, no swap | 0 | pass | exit 134 |
| GitHub `ubuntu-latest`, 16 GB RAM, 3 GB swap | 0 | pass | pass |
| Vercel CI task, 2 vCPU / 4 GB | 0 | | exit 134 |
| Vercel CI task, 4 vCPU / 8 GB | 0 | | pass |

`--threads=1` fails the same way, because the kernel checks each allocation on its own rather than the pool's total.

## Why

`FixedSizeAllocatorPool::new` creates one allocator per thread and unwraps each one. On Unix, each allocator asks `System` for `BLOCK_SIZE + 2 GiB` (about 4 GiB) with 2 GiB alignment. With `vm.overcommit_memory=0`, Linux refuses a single mapping larger than free RAM plus swap, so on a machine with about 4 GB the first allocator fails. Only JS plugins use the fixed-size pool, which is why native rules pass.

## Run it

Docker, on a machine whose Docker VM has under about 6 GB of RAM:

```sh
bun install
./repro.sh
```

`repro.sh` sets `vm.overcommit_memory` inside the Docker VM, which is VM-wide, and restores the original value on exit.

GitHub Actions: the `Repro` workflow runs on `ubuntu-latest` and `ubuntu-slim`. Per #20331, `ubuntu-slim` has heuristic overcommit, no swap and about 5 GB of RAM.

## Stack

- Bun for installs and scripts.
- [`tsc-ts`](https://github.com/vercel-labs/tsc-ts) for `bun run typecheck`.
- oxlint 1.90.0, pinned.
