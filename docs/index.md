# ITGmania Maintenance Index

This local `docs/` directory is a Steward-facing index. The upstream project
documentation remains in `Docs/`.

## Primary References

- `README.md` explains the project, installation paths, resources, and licensing.
- `BUILD.md` documents CMake setup and platform-specific build instructions.
- `Docs/Userdocs/sm5_migration.md` covers migration from StepMania 5.1.
- `Docs/Devdocs/ExternalWarningPolicy.md` records local handling for vendored
  dependency warning suppression.

## Local Maintenance Gate

Run:

```bash
./scripts/validate.sh
```

This is a fast pre-handoff check. It is not a substitute for the full
multi-platform GitHub Actions build matrix.
