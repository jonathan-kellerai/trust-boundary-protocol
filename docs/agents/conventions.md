# Conventions

Tier-2 detail for [`../../AGENTS.md`](../../AGENTS.md). This is the
authoritative source for commit, branch, and citation conventions in this
repository. If a convention changes, it changes here first.

## Commits — Conventional Commits

Every commit subject follows:

```
<type>(<scope>): <subject>
```

- **`<type>`** is one of `feat`, `fix`, `docs`, `chore`, `refactor`, `ci`,
  `revert`. For a docs-only spec repo, `docs` covers most work.
- **`<scope>`** is optional and names the area touched — e.g. `spec`, `adr`,
  `agents`, `ci`. Omit it for repo-wide changes.
- **`<subject>`** is imperative mood, ≤50 characters, no trailing period.

Examples:

```
docs(spec): resolve OQ-4 — set admission token TTL
docs(adr): clarify three-phase research methodology
fix(spec): correct veto-property wording in CONSTRAINT 3
chore(ci): pin markdownlint action to a commit SHA
docs(agents): add bake-window term to the glossary
```

A commit body is optional. When present it explains *why*, wraps at 72
characters, and is separated from the subject by one blank line.

## Branches

- The default branch is **`main`**. Never `master`.
- Agent work uses **`<agent>/<scope>`** — the agent's own name, then a short
  kebab-case scope. Humans use **`human/<scope>`**.

Examples:

```
claude/fix-typo-adr-0001
codex/clarify-signal-type-enum
human/add-oq-14
```

Always branch; never open a pull request from your fork's `main`.

## Branch and commit edge cases

The cases below are logical but easy to get wrong — they are the usual source
of contribution mistakes.

- **Never work on `main` or a detached `HEAD`.** Always cut a branch first. If
  you find yourself on `main`, branch before committing.
- **Always base off the latest `main`.** Never branch from another in-flight
  feature branch.
- **Continuing another agent's branch:** keep the existing `<agent>/<scope>`
  name — do not rename it to your own agent. The branch reflects who opened
  the work.
- **Multi-scope changes:** prefer one scope per branch and PR. If a change
  genuinely spans scopes, omit `<scope>` rather than inventing a compound one.
- **`<scope>` casing:** lowercase, hyphen-separated (`pattern-report`, not
  `patternReport`).
- **Reverts and hotfixes:** branch `revert/<scope>`; commit type `revert`.
- **Commit `type` by area:** a CHANGELOG edit is `docs`; a `.github/` or CI
  change is `ci`; an edit to `AGENTS.md`, `CLAUDE.md`, or `docs/agents/**` is
  `docs(agents)`.
- **Subjects** are imperative mood with no trailing period; **bodies** wrap at
  72 characters.
- **Worktrees** are fine — the branch inside a worktree still follows the
  `<agent>/<scope>` convention.
- **Forks:** external contributors work from a fork and open a pull request
  against this repo's `main`; never from a fork's own `main` branch.

## Citations

- **Internal** references use `file:line` — e.g. `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md:188`
  for the rule that `INDETERMINATE` is treated as `DENIED`. Cite the absence
  of a thing as precisely as its presence.
- **External** references use a full bibliographic citation: author(s),
  title, venue, year. The spec draws on Snodgrass & Jensen (bitemporal data
  models), Dempster–Shafer belief theory, and PAC-Bayes generalisation
  bounds — each cited in full where it appears.
- Never cite from memory. Verify the file, line, or source first.

## Changing the specification

`specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` is the load-bearing artifact. When you change it:

- **A change to a correctness constraint MUST reference the CONSTRAINT
  number** it touches — the constraints are enumerated in §8. State the
  constraint number in both the commit subject and the PR body.
- **Resolving an open question MUST mark that OQ as `RESOLVED` in §11.** Do
  not delete the OQ entry — change its status and record the resolution
  inline, the way OQ-3, OQ-5, and OQ-6 are already recorded.
- **Adding a new term?** Add it to [`glossary.md`](glossary.md) in the same
  change.
- Keep normative keywords (`MUST`, `MUST NOT`, `SHOULD`, `MAY`) exact. They
  carry RFC-2119 weight in this document.

## Pull requests

Publishable files (`specs/**`, `docs/**`, `README.md`) change through a PR.
A PR states what changed, which spec sections or open questions it touches,
and how the change was verified. Staging files — anything matched by
`.gitignore` — need no PR and can be edited directly.
