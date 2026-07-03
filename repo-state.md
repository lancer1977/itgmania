# Repository State

## Current Shape

- CMake-based native application/game fork.
- Vendored dependencies live under `extern/`.
- Release, CI, CodeQL, clang-format, and XML validation workflows are present.
- `scripts/validate.sh` provides a lightweight local maintenance gate.

## Operational Assumptions

- Full builds require initialized submodules and platform dependencies from
  `BUILD.md`.
- Local maintenance can use the existing `build/` tree for targeted checks when
  available.
- Broad dependency updates should be handled separately from documentation or
  warning-policy slices.
- 2026-07-03 validation: `./scripts/validate.sh` passed, including
  `git diff --check` and the targeted `ixwebsocket` build from the existing
  `build/` tree.
