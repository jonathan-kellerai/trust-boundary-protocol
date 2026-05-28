# TRUST-BOUNDARY-PROTOCOL — Layered Invariant Mediating Epistemic Norms

A unified epistemic boundary layer specification — a confidence-state mediator that lets cooperating systems gate cross-domain actions on a shared view of every participant's epistemic readiness.

**Specification only. No implementation in this repository.**

---

TRUST-BOUNDARY-PROTOCOL is a design specification for a boundary layer that sits between independently-developed systems and mediates whether a cross-domain action may proceed.
It does not move data, transform content, or run business logic.
It answers one question, fail-closed: *given every participating domain's current epistemic state, is this action admissible right now?*

The specification is `v0.1-draft`.
It is published as a design artifact — to be read, cited, and critiqued — not as a released library.

---

## 1. What TRUST-BOUNDARY-PROTOCOL is

TRUST-BOUNDARY-PROTOCOL is an **epistemic boundary layer**: a confidence-state router, not a content filter.

It mediates the *epistemic readiness* of a domain to act — whether that domain currently holds enough well-founded confidence to be allowed into a cross-domain action — and it does not inspect, validate, or transform the content of the action itself.

The distinction matters.
A content filter asks "is this payload acceptable?"
TRUST-BOUNDARY-PROTOCOL asks "is the system proposing this action in a state where it should be trusted to act at all?"
Those are orthogonal concerns, and TRUST-BOUNDARY-PROTOCOL owns only the second.

Every decision TRUST-BOUNDARY-PROTOCOL makes is **ternary** — `ADMITTED`, `DENIED`, or `INDETERMINATE` — and every caller is required to treat `INDETERMINATE` identically to `DENIED`.
There is no fourth state, no retry-into-admission, no default-allow.

## 2. Why this exists — the convergent-evolution finding

TRUST-BOUNDARY-PROTOCOL was not designed top-down.
It is the formalization of a pattern that was *observed*.

Nine independently-developed systems — built by different efforts, at different times, for different purposes — were each analyzed for how they decide whether to act under uncertainty.
All nine had independently converged on the same abstract shape:

```
evidence → accumulate → compare_to_threshold → gate_action
```

Each system had reinvented some portion of: an append-only evidence log, a confidence score, a threshold, a fail-closed default, and a policy gate.
None of them shared infrastructure.
Each maintained its own version, with its own bugs, its own audit gaps, and no cross-system visibility.

TRUST-BOUNDARY-PROTOCOL is the unification of that convergence: one epistemically-aware boundary layer that the nine systems — and systems like them — can share instead of re-deriving.
The empirical evidence behind this claim is in [`docs/pattern-report/trust-boundary-collector-synthesis.md`](docs/pattern-report/trust-boundary-collector-synthesis.md).

## 3. Scope

| Dimension | Count |
|---|---|
| Interfaces | 5 |
| Methods | 14 (13 empirically derived + 1 from correctness analysis) |
| Correctness constraints | 14 (each with a stated testability criterion) |
| Fail-closed enforcement layers | 5 |
| Substrate | Dolt — bitemporal provenance ledger |

The specification fixes the contract — interfaces, types, exception hierarchy, and correctness invariants — and deliberately stops short of implementation.
Thirteen open questions are surfaced explicitly in `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` §11 rather than papered over; three of them (signal-type taxonomy, the no-confidence-mechanism adapter, and build phasing) are resolved in this draft.

## 4. The five interfaces

The interfaces form a dependency DAG, not a linear stack.
`UniversalProvenanceTrace` is the shared write substrate every layer audits into.

| Layer | Interface | Responsibility |
|---|---|---|
| L1 | `UniversalProvenanceTrace` | Append-only event substrate — the shared write sink for all layers |
| L2 | `TemporalQueryInterface` | Bitemporal query — valid-time and transaction-time axes |
| L3 | `EpistemicBoundaryProtocol` | Per-domain confidence inspection — the primary domain contract |
| L4 | `TrustAccumulationBus` | Signal accumulation and the authoritative 5-gate admission chain |
| L5 | `PolicyCompositionLayer` | OPA/Rego policy composition with self-validation |

The critical hot path is `TrustAccumulationBus.request_admission`: it touches all five layers, has a maximum call depth of four, and includes an external policy-engine dependency.
All five gates must pass.
The aggregation satisfies a **veto property** — a single registered domain below its threshold denies the action regardless of every other domain's confidence.

## 5. Integration targets

TRUST-BOUNDARY-PROTOCOL is designed for stacks composed of independently-developed domains that need to coordinate cross-domain actions under shared epistemic constraints.

It does not assume a particular language, framework, or deployment topology.
A domain participates by implementing `EpistemicBoundaryProtocol` and registering with the `TrustAccumulationBus`; the rest of the layer treats it uniformly.

See `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` §9 (Domain Mapping) for the nine reference systems whose convergence motivates the design, together with each system's current confidence mechanism, fail-closed posture, and gap analysis.
The §9 table is the empirical basis of the specification — this README declines to re-render it here, to avoid drift between the two documents.

## 6. Status

`v0.1-draft` — pre-`/spec-init`.

Open questions are tracked in `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` §11.
Three are resolved in this draft:

- **OQ-3 — Signal type taxonomy.** A closed, peer-level enumeration of five signal types — `GROUNDEDNESS`, `POLICY`, `SAFETY`, `STABILITY`, `AUTHORITY` — where no type overrides, supersedes, or escalates another.
- **OQ-5 — No-confidence-mechanism domains.** A domain with no native confidence source is given a stub adapter that returns `INDETERMINATE` for every query; it can be registered but never admitted until it ships a real confidence mechanism.
- **OQ-6 — Build phasing.** Full-stack bottom-up (`UPT → TQI → EBP → TAB → PCL`) is the only supported delivery order; phased delivery was evaluated and rejected.

Ten open questions remain — method-signature decisions, token TTL and presentation, payload encoding, constraint-snapshot versioning, domain lifecycle, distributed-deployment concurrency, signal normalization, and the policy bootstrap path.

## 7. Substrate

TRUST-BOUNDARY-PROTOCOL's provenance ledger is specified on **Dolt**, a version-controlled SQL database.

Provenance is **bitemporal**: every record carries both a valid-time interval (`valid_from`, `valid_to`) and a transaction-time stamp (`tx_time`), so the layer can answer both "what was true at time T" and "what did we *believe* was true at time T."

Append-only integrity is enforced in **five independent layers**, so that no single bypass defeats the guarantee:

1. SQL privilege grants
2. Dolt branch protection
3. Remote-side hooks
4. Signed commits
5. An application-level hash-chain

See `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` §7 for the bitemporal schema and the enforcement design.

## 8. Disciplines this specification exercises

This document is also a worked artifact for several engineering disciplines:

- **Mission Autonomy — Policy & Behavior.** Cross-domain, confidence-gated action selection: deciding *which* domain may act, and *whether* it may act, from a composite epistemic state rather than a single local score.
- **Staff Software Systems Safety.** A five-gate, fail-closed admission chain; fourteen testable correctness constraints; and the ternary `INDETERMINATE = DENIED` discipline that removes silent-allow failure modes.
- **Technical Program Management.** A five-interface decomposition with an explicit dependency DAG, thirteen open questions surfaced *before* implementation, and a documented phased-delivery analysis (OQ-6).
- **Senior Human-Machine Teaming Engineer.** At its core TRUST-BOUNDARY-PROTOCOL is human-machine teaming confidence handling: a shared, inspectable model of every participant's epistemic readiness, so that cooperating systems — and their operators — gate joint action on the same evidence.

## 9. License

This repository is licensed under the **Apache License, Version 2.0** (Apache-2.0).

It is a documentation-only repository — a Markdown specification, a pattern report, a white paper, and supporting docs.
You may use, share, and adapt the material, including for commercial purposes, under the terms of the license.
Full text in [`LICENSE`](LICENSE); the attribution and copyright notice is in [`NOTICE`](NOTICE).

## 10. How to navigate this repository

| Path | What it is |
|---|---|
| [`specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md`](specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md) | The specification — interfaces, shared types, exception hierarchy, correctness invariants, domain mapping, open questions |
| [`docs/pattern-report/trust-boundary-collector-synthesis.md`](docs/pattern-report/trust-boundary-collector-synthesis.md) | The empirical convergence evidence — how nine systems independently arrived at the same pattern |
| [`docs/TRUST-BOUNDARY-PROTOCOL-whitepaper.md`](docs/TRUST-BOUNDARY-PROTOCOL-whitepaper.md) | The white paper — TRUST-BOUNDARY-PROTOCOL explained in narrative form |
| [`docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md`](docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md) | The spec-authoring pipeline — how this specification was produced |

Start with `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md`.
The pattern report supplies the empirical evidence; the white paper gives the narrative overview; the workflow document records the method.

---

### For agents

Agents reading this repository should start at [AGENTS.md](AGENTS.md), not this README.
Claude Code users: see [CLAUDE.md](CLAUDE.md), which imports `AGENTS.md`.
The agent files document the conventions, vocabulary, and contribution discipline that agents are expected to follow.
