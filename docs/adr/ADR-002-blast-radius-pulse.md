---
title: "ADR-002 — Blast-radius pulse: deterministic impact analysis for the conformance authority"
status: Proposed
date: 2026-05-22
---

## Context

The repository is the conformance authority for the OSS governance library.
Its frozen content lives in three locked directories — `conformance/`, `template/`,
`scripts/` — and the conformance policy itself runs an explicit self-tamper check
(`conformance/conformance.rego:264-279`).
The recently landed trust-dial system (`docs/adr/ADR-001-trust-dial-dependabot.md:46-55`)
demonstrated the house pattern for governed, observable loops: a pure Rego function,
an append-only JSONL trace, two GitHub Actions workflows, and a templatized mirror
under `template/_files/`.
The complement is missing.
Trust-dial governs *who is allowed to merge a change*; nothing today governs
*which other files must move when a change is made*.

The concrete precipitating failure mode is gap **G-05**, a triplicated source of
truth that no machine check covers.
The artifact-type set is declared three times — in the manifest at
`conformance/data.json:51-56`, in the bootstrap case statement at
`scripts/bootstrap.sh:115-118`, and again in the per-type defaults at
`scripts/bootstrap.sh:157-162`, with the workflow_call input description at
`.github/workflows/conformance.yml:18-21` documenting the same set a fourth time.
An editor who adds a new artifact type to `data.json` and forgets the
`bootstrap.sh` case statement will pass `opa test`, pass `opa check`, pass
lefthook, pass CI, push to `main`, and then break every bootstrap call thereafter
with a one-line `die "--artifact-type must be one of..."` exit.
The conformance system that exists to prevent silent drift cannot today detect
its own most obvious silent drift.

The same shape recurs across the repo.
Editing `conformance/conformance.rego` without refreezing
`conformance/data.json:policy_integrity.expected_digest` is caught by the
policy-integrity rule — but the *requirement to also document the change* in
`docs/agents/enforcement.md` is enforced only by reviewer attention.
Adding a new required file to `conformance/data.json:schema.required_files`
without adding a `template/_files/` copy is caught only when somebody runs
bootstrap and the self-check at `scripts/bootstrap.sh:241-258` trips.
A new `*.rego` file without its sibling `*_test.rego` is caught by no rule at all
— the convention exists only in `AGENTS.md` prose.

These are the same class of failure: a change in file A requires
acknowledged action on file B, and the requirement lives only in human memory.

A decision is needed now because trust-dial just established the architectural
pattern and the operational machinery (JSONL trace, OPA-driven verdict, pinned-SHA
workflows, templatized mirrors).
A second policy in the same shape is cheaper to build now, while the pattern is
fresh, than later.
Skipping it leaves the repository unable to detect the next G-05 — and there
are at least eight more pairs in the seed manifest below.

## Considered options

| Option | Notes |
| ------ | ----- |
| **A — CODEOWNERS-based reviewer routing** | Add `.github/CODEOWNERS` rules that route PRs touching `conformance/conformance.rego` to a reviewer who knows to ask about the digest refreeze. Cheap. Already partially exists. But it routes *attention*, not *enforcement*: a reviewer must remember the cross-file requirement and apply it manually. Provides no trace, no `opa test`-provable determinism, no machine check for the G-05 case across three files. Rejected — relies on the human memory the system is supposed to replace. |
| **B — `actions/labeler` path-based labels** | Use `.github/labeler.yml` to attach labels like `touches:policy` or `touches:bootstrap` to PRs. Labels are queryable, lightweight, and well-supported by the GitHub Actions ecosystem. But labels are *signals*, not *checks*: a labeled PR with no follow-through still merges, and the labeler config is itself a fourth source of truth no rule covers. No required-action ledger, no commit-time block, no audit trace. Rejected — same enforcement-vs-documentation failure as Option A. |
| **C — Nx-style affected-graph** | Adopt an Nx-style project graph and `affected:*` commands that compute downstream effects from a typed dependency model. Industry-proven in monorepos (Nx, Bazel, Turborepo). But it imports a heavyweight runtime (`node_modules`, a daemon, a project.json per package) that violates the zero-runtime-dependency invariant declared in the spec and inherited from ADR-001. The dependency model is also code-graph oriented (TS imports, Python imports) — not documentation/config-graph oriented, which is the actual problem here. Rejected — wrong tool, wrong invariants. |
| **D — OPA/Rego blast-radius pulse with declarative affects manifest** | A single `conformance/affects.json` declares every cross-file dependency. A pure Rego function (`conformance/blast_radius.rego`, package `conformance.blast_radius`) consumes the git-diff'd file set as `input` and the manifest as `data`, returning a verdict per changed file: the affected globs, the required actions, and a severity. Three surfaces — lefthook pre-commit (live), `scripts/pulse.sh --predict` (predictive), PR-comment workflow + JSONL trace (audited) — all share the same engine. A new `conformance.rego` deny family (`affects_manifest_complete`) forces the manifest to remain honest by denying when tracked files under `conformance/`, `template/`, `scripts/`, `docs/agents/` are not reachable from any affects entry. Higher up-front build cost; reuses every piece of trust-dial infrastructure (OPA binary, JSONL trace pattern, pinned workflows, templatized mirrors). |

## Decision

Adopt **Option D**: a deterministic blast-radius pulse implemented as the
`conformance.blast_radius` Rego package over a single declarative manifest
(`conformance/affects.json`), surfaced live via lefthook pre-commit, predictively
via `scripts/pulse.sh --predict`, and audited via
`.github/workflows/blast-radius-pulse.yml` + the committed append-only trace at
`audit/blast-radius.jsonl`.
Completeness is enforced by a new error-severity deny family
(`affects_manifest_complete`) added to `conformance/conformance.rego`.
The full design — manifest schema, Rego rules, surface invocations, CI guards,
phased build checklist — is specified in `blast-radius-pulse-spec.md`.

Option D won because it is the only option that satisfies *all four* invariants
the trust-dial precedent locked in:
(1) same engine — OPA/Rego, `opa test`-proven, zero new runtime dependencies;
(2) same observability pattern — append-only JSONL trace + per-run Actions artifact;
(3) same conformance enforcement pattern — a new deny family proves the manifest
is complete, mirroring how `trust_dial_wired` (`conformance.rego:246-257`) proves
the trust-dial gate is wired;
(4) same templatization shape — every artifact has a `template/_files/` copy so
bootstrapped repos inherit the pulse automatically.
Options A and B are documentation-as-control, the exact anti-pattern
`the-trust-dial.md:33` names.
Option C breaks the zero-runtime-dependency invariant and solves a different problem
(code graph, not documentation/config graph).

## Consequences

**Easier.** G-05 — the artifact-type triplicate — becomes a machine-checked
invariant: editing `conformance/data.json#schema.artifact_types` triggers
required actions on `scripts/bootstrap.sh:115-118` and `.github/workflows/conformance.yml`
before the commit lands. The same machinery covers eight other named pairs
(see `affects-manifest-seed.json`), and the `affects_manifest_complete` deny family
ensures new pairs cannot be silently omitted. Reviewer attention is no longer
the load-bearing member for cross-file consistency. The pulse trace makes
"why did this PR touch only those files?" a query against an append-only record.

**Harder.** The build touches frozen content again — `conformance/**`,
`template/**`, `scripts/**` — each change paired with a semver-classified
`CHANGELOG.md` entry. Adding `affects_manifest_complete` to
`conformance/conformance.rego` is an error-severity rule, so this is a **major**
bump. Editing `conformance.rego` mandates a policy-integrity digest refreeze
(`conformance.rego:264-279`, `conformance/data.json:93-96`) in the same commit
— and the pulse itself will assert this requirement via rule BR-001 once landed,
making the build a self-bootstrapping proof. The affects manifest is a new
artifact that must be kept honest; mitigation is the `affects_manifest_complete`
deny family plus the manifest's own entry in itself (BR-006, BR-008 transitive).
The pulse workflow writes a JSONL line per run, so CI write-back recursion guards
identical to trust-dial's (`paths-ignore: audit/**`, `[skip ci]` commit marker)
are mandatory.

**Closure of cross-discipline gaps.** This ADR closes **G-05** (artifact-type
triplicate detection), **G-08** (conformance/decision observability — extends
the JSONL trace pattern to a second policy), **G-09** (live commit-time
enforcement — the lefthook surface), and **G-10** (decision-traceability for
documentation-class changes). It partially advances **G-11** (audit trail of
policy-integrity refreezes — rule BR-001 records the requirement in the trace)
and **G-12** (templatization scope boundary — rule BR-008 enforces the
template/required-file coupling).

**Follow-up action items.**

- Implement per the phased build checklist in `blast-radius-pulse-spec.md` §7 —
  ten reviewable steps, mirroring the trust-dial ten-step format.
- Refreeze `conformance/data.json:policy_integrity.expected_digest` in the same
  commit as the `conformance.rego` edit that adds `affects_manifest_complete`.
- Record the policy-integrity refreeze in `audit/decision-trace.jsonl` (precedent:
  `audit/decision-trace.jsonl:1`).
- Resolve open questions OQ-1..OQ-5 (`blast-radius-pulse-spec.md` §9) before the
  predictive CLI is exposed to bootstrapped repos.
- Extend `docs/adoption-guide.md` with the migration path for already-bootstrapped
  repos (add `audit/blast-radius.jsonl` + the pulse workflow + the affects
  manifest, or fail the new `affects_manifest_complete` deny family).
