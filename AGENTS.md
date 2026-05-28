# AGENTS.md — agent entry point for trust-boundary-protocol

This repository is the **v0.1-draft specification** for **TRUST-BOUNDARY-PROTOCOL — Layered
Invariant Mediating Epistemic Norms**. Humans read [`README.md`](README.md);
agents start **here**.

This file is **Tier 1**: a lightweight map. For anything it summarises, the
authoritative detail is one hop down, under [`docs/agents/`](docs/agents/).

## What this repo is

- A **design specification**, written in Markdown. Nothing here executes.
- **Design-phase, `v0.1-draft`.** Pre-implementation, pre-`/spec-init`.
- Licensed **Apache-2.0**. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
- The load-bearing artifact is [`specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md`](specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md).

## What this repo is NOT

- **Not a library.** There is no package, no runtime, no API to import.
- **Not implemented.** Do not invent code paths, modules, or call sites.
  TRUST-BOUNDARY-PROTOCOL names interfaces and types; no file here realises them.
- **Not a tracker.** There is no issue database in this repo. Open work lives
  in `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` §11, tracked in prose.

If a task asks you to "run" TRUST-BOUNDARY-PROTOCOL or "fix the build", stop — there is no
build. The only work this repo supports is editing the specification and
its supporting documents.

## File layout — agent reading order

| Read this | When you need to know |
|---|---|
| [`specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md`](specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md) | The spec — interfaces, shared types, exception hierarchy, correctness invariants (§8), domain mapping (§9), open questions (§11) |
| [`docs/pattern-report/trust-boundary-collector-synthesis.md`](docs/pattern-report/trust-boundary-collector-synthesis.md) | The empirical convergence evidence behind spec §2 |
| [`docs/TRUST-BOUNDARY-PROTOCOL-whitepaper.md`](docs/TRUST-BOUNDARY-PROTOCOL-whitepaper.md) | The white paper — TRUST-BOUNDARY-PROTOCOL in narrative form |
| [`docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md`](docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md) | How this spec was produced — the authoring pipeline |
| [`README.md`](README.md) | Human-facing overview and positioning |

Start at `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md`. The pattern report supplies the evidence; the
white paper gives the narrative overview; the workflow document records the
method.

## Conventions agents must follow

- **Default branch is `main`.** Never create or assume `master`.
- **Conventional Commits.** Subject `<type>(<scope>): <subject>`, imperative
  mood, ≤50 characters. Types: `feat`, `fix`, `docs`, `chore`, `refactor`.
  Scope is optional. Full rules: [`docs/agents/conventions.md`](docs/agents/conventions.md).
- **Branch naming for agent work: `<agent>/<scope>`** — e.g.
  `claude/fix-typo-adr-0001`, `codex/clarify-signal-type-enum`. Use your own
  agent name as the prefix; humans use `human/<scope>`.
- **Publishable docs require a PR.** Edits to `specs/**`, `docs/**`, and
  `README.md` go through a pull request. Edits to staging files (anything
  matched by `.gitignore`) can be made directly.
- **Never delete a file without explicit user permission** — including files
  you created yourself. Ask first; wait for an explicit yes.
- **Cite precisely.** Internal references use `file:line`; external
  references use a full bibliographic citation. See
  [`docs/agents/citation.md`](docs/agents/citation.md).

## Open questions — surface them

`specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` §11 carries **10 open questions** — OQ-1, OQ-2, OQ-4,
OQ-7, OQ-8, and OQ-9 through OQ-13. Three more — OQ-3, OQ-5, OQ-6 — are
already **RESOLVED** inline in the draft.

When you discuss or change the architecture, surface every open question
your change touches. A change that silently depends on an unresolved OQ is a
defect. Resolving an OQ means marking it **RESOLVED** in §11 — never deleting
the entry. See [`docs/agents/conventions.md`](docs/agents/conventions.md).

## Tier-2 documents

- [`docs/agents/conventions.md`](docs/agents/conventions.md) — Conventional
  Commits, branch naming, PR style, and how to phrase spec changes.
- [`docs/agents/citation.md`](docs/agents/citation.md) — how to cite TRUST-BOUNDARY-PROTOCOL
  (Apache-2.0 attribution, BibTeX).
- [`docs/agents/glossary.md`](docs/agents/glossary.md) — the load-bearing
  vocabulary: the five interfaces, `AdmissionVerdict`, `SignalType`, and the
  rest of the architecture's terms.
- [`docs/agents/enforcement.md`](docs/agents/enforcement.md) — how these
  conventions are enforced going forward.

Tier 1 is a table of contents. When in doubt, read the spec.
