# Repository Guidance

## Scope

This repository is a CMake-based ITGmania fork with vendored external
dependencies, game assets, Lua scripts, and GitHub Actions release workflows.
Prefer narrow changes that keep upstream ITGmania behavior intact.

## Validation

Run the lightweight local gate before handing off maintenance changes:

```bash
./scripts/validate.sh
```

The script checks shell syntax, whitespace with `git diff --check`, and, when a
local `build/` tree exists, attempts the `ixwebsocket` target that exercises the
vendored mbedtls warning policy.

For full code changes, follow `BUILD.md` and run the relevant CMake configure
and build path for the target platform.

## External Dependencies

Avoid editing vendored dependency source unless the change is intentionally
carried in this fork. Wrapper-level CMake changes belong in `extern/` and should
be documented under `Docs/Devdocs/`.
