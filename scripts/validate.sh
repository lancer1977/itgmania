#!/usr/bin/env bash
set -euo pipefail

bash -n Installer/setup.sh Utils/*.sh extern/libtomcrypt/*.sh extern/libtommath/*.sh extern/ogg/autogen.sh extern/vorbis/autogen.sh
./scripts/validate-workflow-contract.sh
git diff --check

if [[ -d build ]]; then
  cmake --build build --target ixwebsocket -- -j2
else
  echo "No build directory found; skipping ixwebsocket build check."
fi

echo "ITGmania validation passed."
