---
title: "TRUST-BOUNDARY-PROTOCOL — Layered Invariant Mediating Epistemic Norms"
subtitle: "Whitepaper accompanying the v0.1-draft specification"
author: "jonathan-kellerai"
date: 2026-05-20
repo: https://github.com/jonathan-kellerai/trust-boundary-protocol
license: CC-BY-4.0
---

# TRUST-BOUNDARY-PROTOCOL — Layered Invariant Mediating Epistemic Norms

**A Confidence-State Mediator for Cross-Domain Action Admission**

- **Subtitle:** Whitepaper accompanying the v0.1-draft specification
- **Repository:** https://github.com/jonathan-kellerai/trust-boundary-protocol
- **License:** Creative Commons Attribution 4.0 International (CC-BY-4.0)
- **Date:** 2026-05-20
- **Status:** v0.1-draft (revised 2026-05-20 — Pass 5 synthesis edits applied)

---

## Abstract

Independently-developed systems that must cooperate on consequential actions today lack a shared layer for mediating epistemic readiness — whether any participating domain currently holds enough well-founded confidence to be allowed into a joint action.
In practice each system re-derives some local version of the same gating machinery, with its own bugs, its own audit gaps, and no cross-domain visibility (README.md §2; TRUST-BOUNDARY-PROTOCOL-SPEC.md §1).

The empirical basis for TRUST-BOUNDARY-PROTOCOL is a post-hoc analysis of nine independently-developed systems, each of which was found to implement the same abstract mechanism — `evidence → accumulate → compare_to_threshold → gate_action` — using different underlying mathematics (Dempster-Shafer intervals, ELO with Wilson confidence intervals, PAC-Bayes E-processes, OPA/Rego policy deny, narrative confidence scoring, and search relevance gating) (trust-boundary-collector-synthesis.md §1; TRUST-BOUNDARY-PROTOCOL-SPEC.md §2).
The Confidence-Gated Action pattern appears in 9/9 domains; the underlying graph contains 831 nodes and 1,104 edges (TRUST-BOUNDARY-PROTOCOL-SPEC.md front-matter; trust-boundary-collector-synthesis.md).

TRUST-BOUNDARY-PROTOCOL is the formalization of that convergence.
The specification fixes a five-interface dependency DAG (`UniversalProvenanceTrace`, `TemporalQueryInterface`, `EpistemicBoundaryProtocol`, `TrustAccumulationBus`, `PolicyCompositionLayer`), nineteen methods total, fourteen testable correctness constraints, a ternary `AdmissionVerdict` discipline in which `INDETERMINATE` must be treated identically to `DENIED`, and a five-layer append-only enforcement scheme over a Dolt bitemporal substrate (TRUST-BOUNDARY-PROTOCOL-SPEC.md §3, §6, §7, §8).
The artifact is published as a specification — no implementation ships in this repository — under CC-BY-4.0 (README.md §9; LICENSE).

---

## 1. Repository layout

The shipping tree of `trust-boundary-protocol`, depth 3, excluding ephemeral working directories (`.claude/`, `.claude-tmp/`):

```text
trust-boundary-protocol/
├── README.md
├── LICENSE
├── STAGING-NOTES.md
├── KICKOFF-PROMPT.md
├── specs/
│   └── TRUST-BOUNDARY-PROTOCOL-SPEC.md
└── docs/
    ├── TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md
    ├── adr/
    │   ├── TRUST-BOUNDARY-PROTOCOL-ADR-0001.md
    │   ├── TRUST-BOUNDARY-PROTOCOL-ADR-0001-v1-nightops.html
    │   ├── TRUST-BOUNDARY-PROTOCOL-ADR-0001-v2-blueprint.html
    │   ├── TRUST-BOUNDARY-PROTOCOL-ADR-0001-v3-launch.html
    │   └── TRUST-BOUNDARY-PROTOCOL-ADR-0001-v4-manifesto.html
    └── pattern-report/
        └── trust-boundary-collector-synthesis.md
```

File inventory enumerated via Glob over the repository root.
Each shipping file's role:

| Path | Role | Why it ships |
|---|---|---|
| `README.md` | Positioning document; ten-section repository tour. | First page a reader sees on GitHub; states scope, status, license, and navigation. |
| `LICENSE` | Verbatim CC-BY-4.0 legal code. | Establishes that the specification may be shared and adapted, including commercially, with attribution. |
| `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` | The specification of record — 1,258 lines covering problem statement, convergence finding, architecture, shared types, exception hierarchy, interface specifications, substrate, correctness invariants, domain mapping, non-goals, open questions. | This is the load-bearing artifact of the publication; everything else in the repository orbits it. |
| `docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md` | The spec-authoring pipeline: bottom-up build order, plugin-driven spec generation phases, TDD enforcement strategy, per-layer test acceptance criteria, integration testing plan. | Records the *method* by which the specification was produced and the method by which any implementation should be built. |
| `docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001.md` | The architecture decision record. Documents the three-phase research workflow (mechanical foundation → inversion analysis → alien-technology expansion → grand synthesis), the empirical validation phase against nine production systems, and the post-hoc finding of convergent evolution. | The reasoning trail behind the specification; explains *why* the design is shaped the way it is. |
| `docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001-v1-nightops.html` | HTML render of the ADR in the "night-ops" visual treatment. | Companion presentation artifact for the ADR's primary audience (operators). |
| `docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001-v2-blueprint.html` | HTML render of the ADR in the "blueprint" treatment. | Engineering-facing presentation of the ADR. |
| `docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001-v3-launch.html` | HTML render of the ADR in the "launch" treatment. | Outward-facing presentation of the ADR. |
| `docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001-v4-manifesto.html` | HTML render of the ADR in the "manifesto" treatment. | Stylistic counterpoint render of the ADR. |
| `docs/pattern-report/trust-boundary-collector-synthesis.md` | The empirical convergence report: Neo4j graph population counts, the ten cross-cutting patterns and their per-domain coverage, the five-interface API surface derived from the patterns, the dependency-stack ordering. | The evidence base. The specification's claim to be a *formalization* rather than an *invention* rests entirely on this document. |
| `STAGING-NOTES.md` | Repository-staging notes (operator-facing). | Records the publication preparation; not part of the canonical specification. |
| `KICKOFF-PROMPT.md` | Original session prompt that initiated the TRUST-BOUNDARY-PROTOCOL work. | Historical artifact; ships for provenance. |

The four HTML ADR variants share the same canonical source (`TRUST-BOUNDARY-PROTOCOL-ADR-0001.md`) and differ only in presentation (README.md §10).

## 2. Background: the convergent-evolution finding

TRUST-BOUNDARY-PROTOCOL was not designed top-down.
It is the formalization of a pattern that was *observed* in production systems already in operation (README.md §2; TRUST-BOUNDARY-PROTOCOL-ADR-0001.md, "The Convergent Evolution Finding").

Nine independently-developed systems — ArchangelMCP, son-of-anton, companion, SQ-BCP-ft-DGM (CASS-SICA), opa-rego, matryoshka, aegis-drop, sentinel-rag, and truth-jbt — were analyzed post-hoc by an automated pattern-extraction pipeline (the Codebase Cartographer and the Collector agents) that populated a Neo4j graph of 831 nodes and 1,104 edges across the nine repositories (trust-boundary-collector-synthesis.md front-matter; TRUST-BOUNDARY-PROTOCOL-ADR-0001.md "Phase 4").
All nine were found to implement the same abstract shape — `evidence → accumulate → compare_to_threshold → gate_action` — even though their underlying mechanisms were heterogeneous: Dempster-Shafer belief-plausibility intervals in `matryoshka` and `aegis-drop`, ELO with Wilson confidence intervals in `skunkworks-truth-jbt`, PAC-Bayes E-processes in `son-of-anton`, OPA policy evaluation in `opa-rego` and `ArchangelMCP`, outcome scoring in `SQ-BCP-ft-DGM`, narrative confidence scoring in `companion`, and search relevance gating in `skunkworks-sentinel-rag` (trust-boundary-collector-synthesis.md §1).

The Confidence-Gated Action pattern is present in 9/9 domains.
Eight further cross-cutting patterns recur at lower but still meaningful coverage: Fail-Closed Default (8/9), Append-Only Audit Trail (7/9), Baking and Hysteresis (5/9), OPA/Rego Policy-as-Code (5/9), Self-Referential Governance (4/9), Multi-Layered Admission Gate (4/9), Hash-Linked Provenance Chain (4/9), Exponential Decay (4/9), and Event Sourcing with Pure Function Computation (4/9) (TRUST-BOUNDARY-PROTOCOL-SPEC.md §2; trust-boundary-collector-synthesis.md §1–§10).

The wording matters.
The specification deliberately uses "independently arrived at" rather than "independently evolved": the systems were built by different efforts at different times for different purposes, and post-hoc analysis discovered they had each, separately, derived a portion of the same abstract machinery (README.md §2; TRUST-BOUNDARY-PROTOCOL-SPEC.md §2).
TRUST-BOUNDARY-PROTOCOL is the unification of that convergence — one epistemically-aware boundary layer that the nine systems, and systems like them, can share instead of re-deriving.

Every interface method in the specification is load-bearing for at least three of the nine domains (TRUST-BOUNDARY-PROTOCOL-SPEC.md §2).
The five-interface decomposition presented in §3 is the minimum that the cross-cutting patterns impose; nothing in it is speculative.

## 3. The five interfaces

TRUST-BOUNDARY-PROTOCOL's design surface is exactly five interfaces, nineteen methods, organized as a dependency DAG with `UniversalProvenanceTrace` as the shared write substrate (TRUST-BOUNDARY-PROTOCOL-SPEC.md §3.1, §6; front-matter `methods: 19 (UPT: 3, TQI: 3, EBP: 4, TAB: 5, PCL: 4)`).

| Layer | Interface | Methods | Responsibility |
|---|---|---|---|
| L1 | `UniversalProvenanceTrace` (UPT) | 3 | Append-only event substrate; the shared write sink every layer audits into. Methods: `emit_event`, `get_lineage`, `replay_from` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.1). |
| L2 | `TemporalQueryInterface` (TQI) | 3 | Bitemporal query layer — valid-time and transaction-time axes. Methods: `query_at`, `get_decay_weight`, `list_changes_since` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.2). |
| L3 | `EpistemicBoundaryProtocol` (EBP) | 4 | The primary per-domain contract. Methods: `query_confidence`, `is_action_ready`, `get_uncertainty_interval`, `get_evidence_basis` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.3). |
| L4 | `TrustAccumulationBus` (TAB) | 5 | Signal accumulation and the authoritative five-gate admission chain. Methods: `register_domain`, `submit_signal`, `get_trust_tier`, `check_bake_status`, `request_admission` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.4). |
| L5 | `PolicyCompositionLayer` (PCL) | 4 | OPA/Rego policy composition with self-validation. Methods: `evaluate_bundle`, `compose_policies`, `register_domain_policy`, `validate_self` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.5). |

The graph is not a linear stack.
UPT is a shared substrate written to by every layer above it; TAB calls upward into PCL at gate 3 of `request_admission`, which is the only upward call in the graph and the reason the full admission chain cannot be exercised until PCL is built (TRUST-BOUNDARY-PROTOCOL-SPEC.md §3.1).
The critical hot path is `TAB.request_admission`: it touches all five layers, has a maximum call depth of four, and includes an external OPA process dependency at gate 3 (TRUST-BOUNDARY-PROTOCOL-SPEC.md §3.1; README.md §4).

The aggregation in `TAB.request_admission` satisfies a **veto property** — any single registered domain whose most recent signal is below its `fail_closed_threshold` denies the action regardless of every other domain's confidence (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.4, CONSTRAINT 3 in §8).

## 4. Correctness posture

The specification fixes fourteen non-negotiable correctness constraints, each with an explicit testability criterion (TRUST-BOUNDARY-PROTOCOL-SPEC.md §8).
The original v0.1 draft carried thirteen; the Pass-5 synthesis revision added CONSTRAINT 14 (Action-Category Scoping) to require that gate 2 of `request_admission` evaluate only domains whose `declared_action_categories` contains the inbound `ActionSpec.action_category` (TRUST-BOUNDARY-PROTOCOL-SPEC.md front-matter `changes_from_v0.1`; TRUST-BOUNDARY-PROTOCOL-SPEC.md §8 CONSTRAINT 14).

The fourteen constraints in summary:

| # | Constraint | What it prohibits |
|---|---|---|
| 1 | Absent Signal = Deny | Treating a registered domain that has not submitted a signal in the evaluation window as an abstention. |
| 2 | Empty Set = Deny | Returning ADMITTED when zero domains are registered for the action's category. |
| 3 | Veto Property | Allowing high-confidence signals from other domains to compensate for a single below-threshold domain. |
| 4 | Evaluation Freeze | Removing a domain from the evaluation set while an evaluation is in flight. |
| 5 | Ternary Return | Converting `INDETERMINATE` to `ADMITTED` via retry, fallback, or default logic. |
| 6 | Last-Writer-Wins | Summing, averaging, or accumulating multiple signals from the same `(domain_id, signal_type)` within one evaluation window. |
| 7 | Signal Value Range | Silently clamping out-of-range signal values; values outside `[0.0, 1.0]` must raise `TrustBoundaryProtocolSignalRefused`. |
| 8 | Declared Signal Types | Accepting signal types not in the domain's `declared_signal_types`. |
| 9 | Admission Token Validity | Executing actions on `confidence_only` tokens, expired tokens, or tokens superseded by a signal change. |
| 10 | Token Revocation on Signal Change | Keeping outstanding tokens valid after any participating domain's signal has changed. |
| 11 | Signal Type Taxonomy | Open-ended signal type creation; signal types with override or escalation semantics. |
| 12 | ELO Decay | Static, non-decaying ELO weights. |
| 13 | Evaluation Snapshot | Evaluating `request_admission` against a constraint set being concurrently modified. |
| 14 | Action-Category Scoping | Applying gate 2 universally to all registered domains regardless of their declared action categories. |

The safety-vs-liveness posture is asymmetric and deliberate: every gate fails closed (TRUST-BOUNDARY-PROTOCOL-SPEC.md §8; LICENSE notwithstanding).
The `AdmissionVerdict` enum is ternary — `ADMITTED`, `DENIED`, `INDETERMINATE` — and every caller is required by CONSTRAINT 5 to treat `INDETERMINATE` identically to `DENIED` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §4 `class AdmissionVerdict`; §8 CONSTRAINT 5).
There is no fourth state, no retry-into-admission, and no default-allow.

Append-only integrity on the provenance substrate is enforced in five independent layers, so that no single bypass defeats the guarantee (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7.2; README.md §7):

1. SQL privilege grants (deny `UPDATE` and `DELETE` at the SQL level).
2. Dolt branch protection (reject force-push on the main provenance branch).
3. Remote-side `pre-receive` hooks (reject non-fast-forward pushes).
4. GPG-signed commits.
5. Application-level hash-chain verification on the `parent_hash` field of `emit_event`.

SQL grants alone are insufficient because Dolt's version-control layer permits history rewriting independently of SQL permissions (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7.2).

## 5. Substrate: Dolt and bitemporality

The substrate of record for `UniversalProvenanceTrace` is **Dolt**, a version-controlled SQL database (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7; README.md §7).
Dolt is the only TRUST-BOUNDARY-PROTOCOL component with an external runtime dependency.

Provenance in TRUST-BOUNDARY-PROTOCOL is **bitemporal**: every record carries both a valid-time interval (`valid_from`, `valid_to`) and a transaction-time stamp (`tx_time`), so the layer can answer both "what was true in the domain at time T" and "what did the system *believe* was true at time T" (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7.1).
The two axes have different implementations.
Dolt's native `AS OF` clause covers the transaction-time axis (table state at a given commit hash); valid-time is application-layer, modeled as schema columns and filtered via a `WHERE` clause (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7.1).
Implementors are explicitly required not to conflate the two axes.

Dolt is used as a strictly linear, append-only log on the main provenance branch.
Branches are permitted only as a read-only analysis tool — `PCL.validate_self` may branch from main, replay events, evaluate a proposed bundle, then discard the branch; `TQI.query_at` may branch for what-if analysis (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7.4).
Forbidden on provenance tables: `dolt merge --squash`, `dolt rebase`, any non-fast-forward merge, and any operation that rewrites commit history.

Hash-linking is split between Dolt and the application.
Dolt provides commit-level Prolly-tree root hashes over the entire table state at commit granularity; row-level hash-linking via the `parent_hash` parameter on `emit_event` is application responsibility, computed as `SHA256(payload + parent_hash.encode())` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7.3).
This is more efficient than one-commit-per-event at scale while preserving tamper-evidence at the row level.

Environment requirements are pinned (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7.6): Dolt ≥ 1.0.0 (for `AS OF`, branch protection, GPG-signed commits, Prolly-tree semantics); OPA ≥ 0.55.0 (for `opa eval` subprocess invocation, JSON I/O, bundle format v1); Python ≥ 3.10 (for `Protocol`, `dataclass(frozen=True)`, `Literal`, `Enum`, used throughout §4 and §6).

## 6. Contribution to the AI field and the open-source community

TRUST-BOUNDARY-PROTOCOL's contribution is best read as four concrete claims, each substantiated by the specification's content.

**(i) A reusable specification of the confidence-gated-action pattern that nine independent systems converged on.**
The Codebase Cartographer pipeline established that the pattern `evidence → accumulate → compare_to_threshold → gate_action` is present in 9/9 analyzed systems despite heterogeneous underlying mathematics (trust-boundary-collector-synthesis.md §1; TRUST-BOUNDARY-PROTOCOL-SPEC.md §2).
Each of those systems re-derived some portion of the pattern locally, carrying its own bugs, audit gaps, and cross-system blind spots (README.md §2).
The specification's five interfaces (`UPT`, `TQI`, `EBP`, `TAB`, `PCL`) and nineteen methods cover this pattern at the minimum surface area the empirical evidence imposes — every method is load-bearing for ≥3 of the nine domains (TRUST-BOUNDARY-PROTOCOL-SPEC.md §2).
Future implementors of any system that needs to coordinate confidence-gated actions across domain boundaries can adopt the interface contract directly rather than re-deriving it.

**(ii) A safety-engineered ternary discipline (INDETERMINATE = DENIED) that closes a common silent-allow failure mode found in ad-hoc confidence gating.**
The `AdmissionVerdict` enum is explicitly ternary; CONSTRAINT 5 requires callers to treat `INDETERMINATE` identically to `DENIED`, and implementations that convert `INDETERMINATE` to `ADMITTED` via retry, fallback, or default logic are non-compliant (TRUST-BOUNDARY-PROTOCOL-SPEC.md §4; §8 CONSTRAINT 5).
This rules out the silent-allow failure mode in which a timeout or network error during evaluation defaults to action admission — a failure mode observable in 8/9 of the pattern-report domains that implement Fail-Closed Default ad hoc rather than under a uniform discipline (trust-boundary-collector-synthesis.md §2).
The token system reinforces this: `EBP.is_action_ready` issues only `confidence_only` tokens, which action executors must reject; only `full_admission` tokens issued by `TAB.request_admission` after all five gates pass constitute authoritative admission (TRUST-BOUNDARY-PROTOCOL-SPEC.md §3.3; §4 `AdmissionToken`; §8 CONSTRAINT 9).

**(iii) An auditable provenance substrate (UPT) usable beyond TRUST-BOUNDARY-PROTOCOL itself.**
`UniversalProvenanceTrace` specifies an append-only, hash-linked, bitemporal event log over Dolt, with append-only integrity enforced in five independent layers (SQL grants, Dolt branch protection, remote-side hooks, signed commits, application-level hash-chain verification) (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.1; §7.2).
Bitemporality follows Snodgrass and Jensen (1996) with Dolt's `AS OF` covering tx-time and application-layer schema columns covering valid-time (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7.1; §9 "Best bitemporal design reference").
The substrate is specifiable as a standalone artifact: a system that needs only an auditable provenance log — without TRUST-BOUNDARY-PROTOCOL's epistemic-gating surface — can adopt `UniversalProvenanceTrace` and its enforcement scheme on its own, and the specification's §7 is written to support that decoupling.

**(iv) An open specification (CC-BY-4.0) that downstream implementations, including commercial ones, may adopt with only attribution required.**
The repository is licensed under Creative Commons Attribution 4.0 International (LICENSE; README.md §9).
The license permits sharing and adaptation, including for commercial purposes, subject to attribution; it does not impose a ShareAlike obligation on derivatives (LICENSE §2(a), §3(a)).
This places TRUST-BOUNDARY-PROTOCOL in the same license family as documentation artifacts like the Linux Foundation's specification work and the W3C Recommendation series — an explicit choice to remove license friction from downstream adoption while preserving authorship attribution (README.md §9).

The specification declines to overclaim.
Section 10 (Non-Goals) records four bounds: TRUST-BOUNDARY-PROTOCOL does not mediate content, does not replace domain-internal confidence mechanisms, does not own domain policies, and does not provide message passing or event streaming (TRUST-BOUNDARY-PROTOCOL-SPEC.md §10).
Cross-domain semantic-conflict resolution is exposed via `EBP.get_uncertainty_interval` but is not adjudicated by TRUST-BOUNDARY-PROTOCOL — contradictions are surfaced, not resolved (TRUST-BOUNDARY-PROTOCOL-SPEC.md §10).

## 7. Status, scope, and open questions

The specification is `v0.1-draft`, revised 2026-05-20 after a 5-pass adversarial review whose synthesis output is recorded in the spec front-matter as `pass5-synthesis — 16 targeted edits (CRITICAL/HIGH/MEDIUM severity)` (TRUST-BOUNDARY-PROTOCOL-SPEC.md front-matter; README.md §6).
Three open questions were resolved in this draft (OQ-3 signal-type taxonomy, OQ-5 no-confidence-mechanism adapter, OQ-6 build phasing); ten remain open (TRUST-BOUNDARY-PROTOCOL-SPEC.md §11; README.md §6).

The ten currently-open questions are OQ-1, OQ-2, OQ-4, OQ-7, OQ-8 (carryovers from the original spec) and OQ-9, OQ-10, OQ-11, OQ-12, OQ-13 (added by the Pass-5 synthesis) (TRUST-BOUNDARY-PROTOCOL-SPEC.md §11).
For an implementor evaluating adoption, the most consequential of these are:

- **OQ-9 (distributed deployment concurrency).** v0.1 specifies TRUST-BOUNDARY-PROTOCOL as an in-process Python library (TRUST-BOUNDARY-PROTOCOL-SPEC.md §3.4, §10).
Distributed topology introduces distributed locking, clock synchronization, and split-brain semantics beyond §3.4; without resolution, multi-process or multi-host deployments are out of scope.
- **OQ-10 (token presentation API).** CONSTRAINT 9 mandates that `confidence_only`, expired, and stale tokens "MUST be rejected" but specifies no API for the rejection.
A `validate_token` method must be sited somewhere — either on EBP, on TAB, or in each executing domain's adapter — before a compliant implementation can ship (TRUST-BOUNDARY-PROTOCOL-SPEC.md §11 OQ-10).
- **OQ-11 (payload encoding).** The `emit_event` hash formula `SHA256(payload + parent_hash.encode())` requires deterministic serialization for cross-implementation interoperability.
Without a mandated canonical encoding (UTF-8 JSON with lexicographic key ordering is one candidate), independent implementations may produce hash-incompatible logs (TRUST-BOUNDARY-PROTOCOL-SPEC.md §11 OQ-11).
- **OQ-13 (PCL bootstrap).** At system genesis with an empty UPT, `PCL.validate_self` returns `valid=False` per its fail-closed behavior, which blocks the first policy registration.
A genesis exception path is required and not yet specified (TRUST-BOUNDARY-PROTOCOL-SPEC.md §11 OQ-13; §6.5 `register_domain_policy`).

The remaining open questions concern method signatures (OQ-1, OQ-2), token TTL configuration granularity (OQ-4), snapshot versioning strategy (OQ-7), domain lifecycle mutations (OQ-8), and AUTHORITY signal normalization (OQ-12) — each of which is required for full implementability but does not block evaluation of the design (TRUST-BOUNDARY-PROTOCOL-SPEC.md §11).

## 8. How to engage

The repository is published at https://github.com/jonathan-kellerai/trust-boundary-protocol under Creative Commons Attribution 4.0 International (LICENSE; README.md §9).
The license permits use, modification, and redistribution including for commercial purposes, subject to attribution; it does not impose ShareAlike.

The recommended reading order is documented in `README.md §10` and is reproduced here for completeness:

1. `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` — start here. The specification of record.
2. `docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001.md` — the architectural reasoning behind the design.
3. `docs/pattern-report/trust-boundary-collector-synthesis.md` — the empirical evidence base.
4. `docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md` — the method by which the specification was produced and the method by which any implementation should be built.

This repository ships a specification only.
No implementation is provided here (README.md, header).

## 9. References

### Primary sources (this repository)

1. **README.md** — Repository README and ten-section tour. `trust-boundary-protocol/README.md`.
2. **LICENSE** — Creative Commons Attribution 4.0 International Public License (verbatim). `trust-boundary-protocol/LICENSE`.
3. **specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md** — TRUST-BOUNDARY-PROTOCOL Specification v0.1-draft, revised 2026-05-20. `trust-boundary-protocol/specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md`.
4. **docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001.md** — ADR-TRUST-BOUNDARY-PROTOCOL-0001: Research Methodology for Cross-Domain Product Design. `trust-boundary-protocol/docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001.md`.
5. **docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001-v1-nightops.html**, **-v2-blueprint.html**, **-v3-launch.html**, **-v4-manifesto.html** — Four HTML render variants of ADR-0001.
6. **docs/pattern-report/trust-boundary-collector-synthesis.md** — TRUST-BOUNDARY-PROTOCOL Collector Synthesis: Cross-Domain Pattern Analysis. `trust-boundary-protocol/docs/pattern-report/trust-boundary-collector-synthesis.md`.
7. **docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md** — TRUST-BOUNDARY-PROTOCOL Development Workflow. `trust-boundary-protocol/docs/TRUST-BOUNDARY-PROTOCOL-WORKFLOW.md`.

### External references cited by the specification

8. **Snodgrass, R. T., and Jensen, C. S. (1996).** Temporal database concepts. Referenced as the bitemporal model grounding for `UniversalProvenanceTrace` and as the design reference cited by `matryoshka` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §9 "Best bitemporal design reference").
9. **Open Policy Agent (OPA) and the Rego policy language.** External runtime dependency for `PolicyCompositionLayer.evaluate_bundle` via `opa eval` subprocess invocation (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.5, §7.6).
10. **Dempster-Shafer evidence theory.** Underlying mathematics for `ConfidenceState` (belief, plausibility, point estimate) and `UncertaintyInterval` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §4); used by `matryoshka` and `aegis-drop` in the reference stack (TRUST-BOUNDARY-PROTOCOL-SPEC.md §9).
11. **PAC-Bayes E-process and KL-bound confidence intervals.** Confidence mechanism used by `son-of-anton` in the reference stack (TRUST-BOUNDARY-PROTOCOL-SPEC.md §9; trust-boundary-collector-synthesis.md §1).
12. **Dolt.** Version-controlled SQL database; minimum version 1.0.0; substrate for `UniversalProvenanceTrace` (TRUST-BOUNDARY-PROTOCOL-SPEC.md §7, §7.6).
13. **ELO rating system, Wilson confidence interval, Thompson Sampling.** Authority-signal mechanisms used by `truth-jbt` and `SQ-BCP-ft-DGM` in the reference stack; required to incorporate temporal decay per CONSTRAINT 12 (TRUST-BOUNDARY-PROTOCOL-SPEC.md §6.4, §8 CONSTRAINT 12, §9).

---

## Drafting notes (not rendered in PDF cover material)

- The README states the spec carries "13 correctness constraints" (README.md §3); the specification itself, as of the Pass-5 synthesis revision, carries fourteen (TRUST-BOUNDARY-PROTOCOL-SPEC.md §8 includes CONSTRAINT 1 through CONSTRAINT 14, with CONSTRAINT 14 explicitly added in that revision). This whitepaper uses the figure from the spec itself.
- The README states "5 remain open" (README.md §6) out of eight original open questions; the Pass-5 synthesis added five further open questions (OQ-9 through OQ-13), so the current open-question count is ten (TRUST-BOUNDARY-PROTOCOL-SPEC.md §11). This whitepaper uses the figure from the spec itself.
- The README states "14 (13 empirically derived + 1 from correctness analysis)" methods (README.md §3); the specification front-matter states "19 (UPT: 3, TQI: 3, EBP: 4, TAB: 5, PCL: 4)" (TRUST-BOUNDARY-PROTOCOL-SPEC.md front-matter). The interface-by-interface count in §6 confirms 19. This whitepaper uses 19.
- The discrepancies above are recorded but not resolved here; they are candidates for a README refresh aligned with the Pass-5-revised specification.
