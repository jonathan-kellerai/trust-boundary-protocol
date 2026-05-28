#!/usr/bin/env bash
# Sanitization regression gate for trust-boundary-protocol.
#
# The internal-term denylist is base64-encoded so this script does not itself
# republish the strings it exists to keep out — a plaintext denylist would be
# indexed by code search. It is decoded only at runtime, into a temp file.
#
# Every publishable file is scanned for every denied term. Files excluded from
# publication (matched by .gitignore: docs/adr/, .claude-tmp/, atlases/, the
# staging notes) are not scanned. Exits non-zero on any match.
set -euo pipefail

cd "$(dirname "$0")/.."

DENYLIST_B64='KD9pKSg/PCFqb25hdGhhbi0pa2VsbGVyYWkKKD9pKWtlbGxlci1wbGF0Zm9ybQooP2kpdGF4aW1pemVyCi9Vc2Vycy9qb25hdGhhbnNfbWFjYm9vawpDT05GSURFTlRJQUwKUFJPUFJJRVRBUlkKKD9pKUhvbHljcm9uCmJlYWRzX0ZTCmJlYWRzLWRvY3Rvci0KTmV3X1NwZWNfQ2hhdF9GbG93Cm9wdGltaXplZC1kcmlmdGluZy1kaWZmaWUK'

patterns_file="$(mktemp)"
trap 'rm -f "$patterns_file"' EXIT
printf '%s' "$DENYLIST_B64" | base64 -d > "$patterns_file"

list_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -z
  else
    find . \
      \( -path ./.git -o -path ./.claude -o -path ./.claude-tmp \
         -o -path ./atlases -o -path ./docs/adr -o -path ./node_modules \
         -o -path ./.venv \) -prune -o \
      -type f \
      ! -name 'STAGING-NOTES.md' ! -name 'KICKOFF-PROMPT.md' \
      ! -name 'FRESH-SESSION-PROMPT.md' ! -name 'NEXT-SESSION-PROMPT.md' \
      ! -name '*.bak' ! -name '*.bak.md' ! -name '.DS_Store' \
      -print0
  fi
}

if list_files | PATTERNS="$patterns_file" LC_ALL=C perl -0 -ne '
  BEGIN {
    open my $pf, "<", $ENV{PATTERNS} or die "cannot read patterns file\n";
    while (<$pf>) { chomp; next unless length; push @P, qr/$_/ }
    close $pf;
    $hit = 0;
  }
  my $file = $_;
  open my $fh, "<", $file or next;
  {
    local $/ = "\n";
    while (my $line = <$fh>) {
      for my $re (@P) {
        if ($line =~ $re) { printf "LEAK  %s:%d\n", $file, $.; $hit = 1; }
      }
    }
  }
  close $fh;
  END { exit($hit ? 1 : 0); }
'; then
  echo "check-sanitization: OK — no denied terms in the publishable tree"
else
  echo "check-sanitization: FAILED — denied terms found (see LEAK lines above)"
  exit 1
fi
