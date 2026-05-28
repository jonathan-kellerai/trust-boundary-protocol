#!/usr/bin/env bash
# Primary artifact validation for trust-boundary-protocol, a documentation-only spec repo.
# Verifies that the canonical publishable file set is present and that the
# specification retains its load-bearing sections. Exits non-zero on failure.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0
fail() { echo "FAIL: $*"; status=1; }

required_files=(
  README.md
  LICENSE
  NOTICE
  AGENTS.md
  CLAUDE.md
  CONTRIBUTING.md
  SECURITY.md
  CHANGELOG.md
  CITATION.cff
  specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md
  docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md
  docs/TRUST-BOUNDARY-PROTOCOL-whitepaper.md
  docs/pattern-report/trust-boundary-protocol-collector-synthesis.md
  docs/agents/conventions.md
  docs/agents/citation.md
  docs/agents/glossary.md
  docs/agents/enforcement.md
)

for f in "${required_files[@]}"; do
  [ -f "$f" ] || fail "missing required file: $f"
done

spec="specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md"
if [ -f "$spec" ]; then
  for marker in "Correctness Invariants" "Open Questions" "Domain Mapping"; do
    grep -q -- "$marker" "$spec" || fail "specification is missing section: $marker"
  done
else
  fail "specification file not found: $spec"
fi

if [ "$status" -eq 0 ]; then
  echo "check-structure: OK — ${#required_files[@]} canonical files present, specification sections intact"
fi
exit "$status"
