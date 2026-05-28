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

## Glossary review cadence

Every change that resolves an open question or adds a CONSTRAINT to
`specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` MUST, in the same pull request, add or update the
[`glossary.md`](glossary.md) terms it introduces. A reviewer who sees new
load-bearing vocabulary with no glossary entry should block the pull request.
