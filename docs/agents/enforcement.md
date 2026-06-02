# Enforcement

Tier-2 detail for [`../../AGENTS.md`](../../AGENTS.md). How the conventions in
this repository are enforced — what is automated, what is reviewed, and where
a convention lives when it changes.

## Automated gates

| Gate | Where it runs | What it checks |
|---|---|---|
| `scripts/check-structure.sh` | CI and the pre-commit hook | The canonical publishable files exist; the specification keeps its load-bearing sections. |
| `scripts/check-sanitization.sh` | CI and the pre-commit hook | No internal term from the denylist appears in the publishable tree. The denylist is base64-encoded inside the script so the script does not itself republish those terms. |
| Markdown lint | CI | `markdownlint-cli2` over every Markdown file. |
| Link check | CI | `lychee` resolves every link. |
| `commitlint` | CI, on every pull request | Every commit message is a valid Conventional Commit. |

The pre-commit hook is managed by `lefthook`. Install it once with
`lefthook install`; it then runs the structure and sanitization gates before
every commit. CI runs the same gates, so the hook is a convenience — not the
sole line of defence.

## Reviewed, not automated

- **`CODEOWNERS`** routes changes under `.github/`, `LICENSE`, `NOTICE`,
  `AGENTS.md`, `CLAUDE.md`, and `specs/` to the repository owner for review.
- The **pull-request template** requires a semver classification, the list of
  artifacts touched, and the validation-gate output. Reviewers confirm these.
- An **IP-leak audit** — a qualitative pass beyond the sanitization regex —
  is run before any machine-generated artifact is added to the publishable
  tree. The regex gate is necessary but not sufficient.

## Where a convention lives

`AGENTS.md` and the files under `docs/agents/` are canonical. When a
convention changes:

1. Change it in `docs/agents/conventions.md` (or the relevant Tier-2 file)
   first — that is the source of truth.
2. Update the `AGENTS.md` summary if the Tier-1 overview is now stale.
3. Propagate to `CONTRIBUTING.md` and `README.md` if either restates it.

`README.md`, `CONTRIBUTING.md`, and the issue and pull-request templates
restate conventions for convenience; they are downstream of `docs/agents/`.

## Blast-radius pulse gates

This repository ships a blast-radius pulse policy (`conformance/blast_radius.rego`) that
evaluates `conformance/affects.json` against the git diff on every pull request. Two entries
have `verifiable: true` and `severity: "error"`, meaning the CI gate hard-blocks until the
required actions are footer-declared DONE:

### BR-005 — CLAUDE.md invariants

**Trigger:** any edit to `CLAUDE.md`.

**Required actions (must be footer-declared in the commit):**

1. Verify `CLAUDE.md` line count is `<= content_assertions.claude_md_max_lines` (currently 80).
2. Verify `CLAUDE.md` first non-blank, non-comment line equals
   `content_assertions.claude_md_first_content_line` (`@AGENTS.md`).
3. If either invariant value is being changed, update `conformance/data.json` under
   `content_assertions` and document the rationale here.

**Current invariant values** (as of this entry, sourced from `conformance/affects.json:86-87`):

- `claude_md_max_lines`: 80
- `claude_md_first_content_line`: `@AGENTS.md`

Both invariant rules live at `conformance/blast_radius.rego` and are asserted against
`conformance/data.json`. Violations block CI.

### BR-011 — affects manifest self-coverage

**Trigger:** any edit to `conformance/affects.json`.

**Required actions (must be footer-declared in the commit):**

1. For each new or renamed manifest entry, add a positive test (entry fires on the correct
   trigger path and `verdict == "blocked"` or `"owed"` as appropriate) **and** a cleared test
   (all required actions footer-DONE, `verdict == "clear"`) in
   `conformance/blast_radius_test.rego`.
2. Document the new or changed manifest entry in this file (`docs/agents/enforcement.md`),
   including: entry id, trigger glob, severity, verifiable flag, and a one-sentence rationale.

**Rationale:** `conformance/affects.json` is the load-bearing cross-file relationship map. Every
entry must be covered by a sibling test case so the blast-radius function's determinism proof
is complete. An undocumented entry is unverifiable; an untested entry is unproven.

## Glossary review cadence

Every change that resolves an open question or adds a CONSTRAINT to
`specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` MUST, in the same pull request, add or update the
[`glossary.md`](glossary.md) terms it introduces. A reviewer who sees new
load-bearing vocabulary with no glossary entry should block the pull request.
