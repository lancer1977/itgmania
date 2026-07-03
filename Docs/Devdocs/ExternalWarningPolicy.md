# External Warning Policy

## Vendored CMake Warnings

ITGmania keeps external dependency warning handling scoped to the dependency
that emits the warning. Project warnings should remain visible unless the
warning originates from vendored code that is built through an external
subdirectory.

## ixwebsocket and mbedtls

`extern/CMakeProject-ixwebsocket.cmake` adds vendored `mbedtls` through
`add_subdirectory("mbedtls" EXCLUDE_FROM_ALL)`. Current CMake versions can emit
deprecated-policy warnings from that vendored tree even when ITGmania source is
warning-clean.

The CMake wrapper temporarily sets `CMAKE_WARN_DEPRECATED` to `OFF` around only
the `mbedtls` subdirectory, then restores or unsets the cache value to match the
caller state. This keeps dependency noise out of normal builds without changing
the global warning posture or editing the vendored dependency.

## Validation

Use the existing build tree when present:

```bash
cmake --build build --target ixwebsocket -- -j2
git diff --check
```

Linear tracking for this maintenance note: `CHA-16`.

2026-07-03 Steward validation: `./scripts/validate.sh` passed, including
`git diff --check` and `cmake --build build --target ixwebsocket -- -j2`.
