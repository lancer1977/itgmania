#!/usr/bin/env bash
set -euo pipefail

# Keep repository policy in step with this fork's actual integration branch.
# This intentionally checks small, security-sensitive workflow invariants
# without requiring a YAML parser in the local maintenance gate.

require_trigger_line() {
  local file="$1"
  local trigger="$2"
  local expected="$3"
  local description="$4"

  if ! awk -v trigger="$trigger" -v expected="$expected" '
    $0 == trigger { inside_trigger = 1; next }
    inside_trigger && /^[^[:space:]]/ { exit }
    inside_trigger && $0 == expected { found = 1; exit }
    END { exit !found }
  ' "$file"; then
    echo "Workflow contract failed: ${description}" >&2
    exit 1
  fi
}

require_trigger_line \
  .github/workflows/codeql.yml \
  '    pull_request:' \
  '        branches: [release, beta]' \
  'CodeQL pull-request analysis must cover release and beta.'

require_trigger_line \
  .github/workflows/catalog-manifest.yml \
  '  push:' \
  '    branches: [release]' \
  'Catalog manifest push validation must run on release.'

if grep -Fqx '    branches: [main]' .github/workflows/catalog-manifest.yml; then
  echo 'Workflow contract failed: catalog validation must not target inactive main.' >&2
  exit 1
fi

echo 'Workflow contract passed.'
