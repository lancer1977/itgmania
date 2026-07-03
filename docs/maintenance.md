# Maintenance

## Routine Checks

1. Run `./scripts/validate.sh`.
2. For C++ source changes, run the relevant CMake configure/build path from
   `BUILD.md`.
3. For release workflow changes, inspect `.github/workflows/release.yml` and the
   shared setup action under `.github/actions/setup-env/`.

## Build Notes

- Submodules are required for a full build: `git submodule update --init --recursive`.
- The existing `build/` directory can be reused for targeted checks when it is
  present and current.
- Linux, macOS, and Windows packaging are covered by GitHub Actions.

## Risk Areas

- Vendored dependencies under `extern/` can produce warnings unrelated to local
  source quality.
- Fixed release branch behavior differs between `beta` and `release`.
- Asset and theme changes can affect runtime behavior without touching C++ code.
