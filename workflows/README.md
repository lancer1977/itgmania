# Workflows

GitHub Actions live in `.github/workflows/`:

- `ci.yml` runs the cross-platform CMake build matrix.
- `release.yml` packages nightly and release artifacts.
- `codeql.yml` runs C++ CodeQL analysis.
- `clang-format.yml` checks changed source formatting.
- `validate-xml.yml` validates selected Lua documentation XML files.
