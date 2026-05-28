# Contributing to trust-boundary-protocol

Thanks for helping improve the TRUST-BOUNDARY-PROTOCOL specification. This is a documentation
repository — there is no code to build. Contributions change the
specification, the pattern report, the white paper, or the supporting docs.

Agents should start at [`AGENTS.md`](AGENTS.md). It and the files under
[`docs/agents/`](docs/agents/) are the authoritative source for every
convention summarized below.

## Before you start

- For anything beyond a typo, open an **issue** first using one of the
  [issue forms](.github/ISSUE_TEMPLATE) — defects, clarifications, amendment
  proposals, and integration questions each have a form.
- The default branch is `main`. Branch from it. Never commit to `main`
  directly, and never open a pull request from your fork's `main`.

## Branches and commits

- **Branch naming:** `<agent>/<scope>` for agent work (`claude/…`,
  `codex/…`); `feat/… fix/… docs/… chore/…` for human work. The edge cases
  are documented in [`docs/agents/conventions.md`](docs/agents/conventions.md).
- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org):
  `<type>(<scope>): <subject>`, imperative mood, subject ideally ≤ 50
  characters. `commitlint` enforces the Conventional Commits format as a hard
  CI gate.

## Validation

Before opening a pull request, run both gates:

```
bash scripts/check-structure.sh
bash scripts/check-sanitization.sh
```

Both must pass. CI additionally runs markdown lint and a link check. To run
the two gates automatically on every commit, install the hook with
`lefthook install` (optional but recommended).

## Semver policy

The specification is versioned with Semantic Versioning:

- **major** — a breaking change to an interface, a shared type, or a CONSTRAINT.
- **minor** — an additive, backward-compatible change.
- **patch** — a clarification or editorial change with no contract impact.

State the classification in your pull request; the PR template has a checklist.

## Pull request checklist

- [ ] Branched from `main`; the branch name follows the convention.
- [ ] Commit messages are valid Conventional Commits.
- [ ] `check-structure.sh` and `check-sanitization.sh` both pass.
- [ ] A change to a CONSTRAINT cites the CONSTRAINT number; a resolved open
      question is marked `RESOLVED` in `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` §11.
- [ ] New vocabulary is added to
      [`docs/agents/glossary.md`](docs/agents/glossary.md).
- [ ] The pull request template's five sections are filled in.

## Conduct

Be precise, cite your sources, and assume good faith. Discussion happens on
issues and pull requests.
