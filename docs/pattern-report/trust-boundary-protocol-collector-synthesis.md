---
title: Trust Boundary Protocol Collector Synthesis — Cross-Domain Pattern Analysis
date: 2026-04-15
session: 50c46eda-547b-4fd9-81b9-9f244317888e
domains: 9
graph_nodes: 831
graph_edges: 1104
---

# Trust Boundary Protocol Collector Synthesis — Cross-Domain Pattern Analysis

- **Date:** 2026-04-15
- **Domains analyzed:** 9 (ArchangelMCP, son-of-anton, companion, SQ-BCP-ft-DGM, opa-rego, matryoshka, aegis-drop, skunkworks-sentinel-rag, skunkworks-truth-jbt)
- **Neo4j graph:** 831 nodes, 1,104 edges, 39 node labels, 62 relationship types
- **Source:** The Collector agent synthesis (agents ab6e9956a486db596 + af6c560915c5b7b71)

---

## Neo4j Graph Population

Trust-Boundary-Protocol-specific nodes and edges written:

| Type | Count |
|------|-------|
| TrustBoundaryProtocolDomain nodes | 9 |
| TrustBoundaryProtocolPattern nodes | 18 |
| TrustBoundaryProtocolInterface nodes | 5 |
| APPEARS_IN edges | 75 |
| UNIFIES edges | 20 |
| IMPLEMENTS edges | 11 |
| ENABLES edges | 10 |
| Pattern dependency edges | 4 |

Key relationship classes: `APPEARS_IN`, `UNIFIES`, `DEPENDS_ON`, `IMPLEMENTED_BY`, `EXTENDS`, `FEEDS_INTO`, `STABILIZES`, `SHARES_SUBSTRATE_WITH`, `REQUIRES`

---

## Top 10 Cross-Cutting Patterns

### 1. Confidence-Gated Action — 9/9 domains

Every domain independently evolved the same mechanism: evidence accumulates against a hypothesis set until a confidence threshold is crossed, at which point an action is permitted.

| Domain | Implementation |
|--------|---------------|
| matryoshka | DS belief-plausibility intervals |
| aegis-drop | DS belief-plausibility intervals |
| skunkworks-truth-jbt | ELO + Wilson CI |
| SQ-BCP-ft-DGM | CASS outcome scoring |
| opa-rego | OPA policy evaluation |
| ArchangelMCP | OPA policy evaluation |
| son-of-anton | PAC-Bayes e-process |
| companion | Narrative confidence scoring |
| skunkworks-sentinel-rag | Search relevance gating |

Abstract structure (identical across all 9): `evidence → accumulate → compare_to_threshold → gate_action`

**Trust Boundary Protocol implication:** This is the definitional core of Trust Boundary Protocol. Trust Boundary Protocol does not mediate content — it mediates the epistemic readiness of a domain to act. The primary contract Trust Boundary Protocol must enforce: no domain crosses an action boundary without presenting its confidence state in a form Trust Boundary Protocol can inspect. **Trust Boundary Protocol is a confidence-state router.**

---

### 2. Fail-Closed Default — 8/9 domains

(Missing: skunkworks-sentinel-rag — no authoritative action path to close.) The default answer to an undefined input is silence or denial. No domain treats "unknown" as "permitted."

**Trust Boundary Protocol implication:** Trust Boundary Protocol's own default must be fail-closed. Cross-domain composition cannot weaken this. If domain A is fail-closed and domain B's output feeds domain A's decision, B's uncertainty must propagate, not be absorbed. Trust Boundary Protocol's composition semantics must preserve the fail-closed invariant end-to-end.

---

### 3. Append-Only Audit Trail — 7/9 domains

Present in: ArchangelMCP, son-of-anton, companion, SQ-BCP-ft-DGM, opa-rego, matryoshka, aegis-drop. Every domain with consequential state transitions maintains an append-only log. The log IS the truth; derived state is computed from it.

**Trust Boundary Protocol implication:** Trust Boundary Protocol cannot sit outside the audit trail — it must be a write participant. Any cross-domain action Trust Boundary Protocol mediates must emit to a canonical log that is at least as durable as the most durable domain log in the composition. Trust Boundary Protocol's audit is the audit of last resort.

---

### 4. Baking Period and Hysteresis for Stability — 5/9 domains

Present in: ArchangelMCP, companion, SQ-BCP-ft-DGM, aegis-drop, skunkworks-truth-jbt. A newly promoted state must persist for N consecutive periods without reversal before being treated as stable. Oscillation is explicitly detected and blocks re-proposal.

**Trust Boundary Protocol implication:** Trust Boundary Protocol's cross-domain trust state is itself subject to baking. Trust Boundary Protocol needs a stability layer between raw confidence signals and composed trust decisions. Minimum implementation: configurable `bake_window` per domain pair.

---

### 5. OPA/Rego Policy-as-Code — 5/9 domains

Present in: ArchangelMCP, companion, opa-rego, matryoshka, aegis-drop. Policy is code: versioned, testable, executable at call time. Applied pre-action as a gate, not post-hoc as an audit.

**Trust Boundary Protocol implication:** Trust Boundary Protocol's composition rules must be expressible as OPA bundles. Five of nine domains already understand and consume OPA. Cross-domain permission grants, budget gates, and trust tier checks should all be OPA data documents that Trust Boundary Protocol evaluates before permitting cross-domain signal flow.

---

### 6. Self-Referential Governance — 4/9 domains

Present in: ArchangelMCP, SQ-BCP-ft-DGM, opa-rego, aegis-drop. The governance machinery is applied to itself. SICA improves SICA rules. OPA lints OPA policies.

**Trust Boundary Protocol implication:** Trust Boundary Protocol must govern its own operation with the same mechanisms it enforces on domains. An ungoverned Trust Boundary Protocol is an epistemic bypass — exactly the attack surface the whole architecture is designed to eliminate.

---

### 7. Multi-Layered Admission Gate — 4/9 domains

Present in: ArchangelMCP, SQ-BCP-ft-DGM, matryoshka, aegis-drop. Consequential transitions pass through a chain of independent evaluators. No single layer can grant full admission.

**Trust Boundary Protocol implication:** The five gate layers for cross-domain action requests:
1. Schema conformance of the epistemic state object
2. Confidence threshold check per domain
3. OPA policy bundle evaluation for the cross-domain composition
4. Baking window check for stability
5. Authority/role check for the requesting composition

All five must pass.

---

### 8. Hash-Linked Provenance Chain — 4/9 domains

Present in: son-of-anton, SQ-BCP-ft-DGM, matryoshka, aegis-drop. Every derivation step records a cryptographic hash of its inputs. The chain is tamper-evident.

**Trust Boundary Protocol implication:** Cross-domain signal composition must be provenance-preserving. Trust Boundary Protocol cannot absorb provenance — it must forward and extend it. When composing a trust decision from domain A's DS output and domain B's ELO output, the composite must carry hashes from both lineages.

---

### 9. Exponential Decay and Forgetting Curve — 4/9 domains

Present in: son-of-anton, companion, SQ-BCP-ft-DGM, skunkworks-truth-jbt. Evidence from time T is weighted by `decay_factor^(now - T)`. Rolling windows drop evidence older than a threshold.

**Trust Boundary Protocol implication:** Trust Boundary Protocol must hold time-stamped confidence snapshots, not just latest values, and apply decay to cross-domain compositions. A static trust cache in Trust Boundary Protocol is architecturally incorrect.

---

### 10. Event Sourcing with Pure Function Computation — 4/9 domains

Present in: ArchangelMCP, son-of-anton, companion, SQ-BCP-ft-DGM. Derived state is always computable as a pure function of the append-only event log.

**Trust Boundary Protocol implication:** Trust Boundary Protocol's routing decisions, trust state, and confidence composites should be derivable from an event log of domain signals. This enables Trust Boundary Protocol to replay its own decisions for audit and test policy changes against past event history before deploying them.

---

## Minimum Viable API Surface — 5 Interfaces, 13 Methods, 0 Optional

### Interface 1: EpistemicBoundaryProtocol

Primary contract. Every domain must implement it.

```
EpistemicBoundaryProtocol:
  query_confidence(domain_id, hypothesis, as_of: timestamp?) → ConfidenceState
  is_action_ready(domain_id, action_type) → ReadinessDecision
  get_uncertainty_interval(domain_id, claim_id) → [belief, plausibility]
  get_evidence_basis(domain_id, decision_id) → EvidenceTrace
```

Rationale: Confidence-Gated Action (9/9) + Fail-Closed Default (8/9). The `as_of` parameter is mandatory — Exponential Decay (4/9) means "current" without a timestamp is underspecified. The `[belief, plausibility]` return is the DS interval — strictly more general than a point estimate, degrades gracefully to a probability or boolean.

---

### Interface 2: UniversalProvenanceTrace

Unifies: Hash-Linked Provenance Chain, Bitemporal Data Model, Append-Only Audit Trail, Event Sourcing.

```
UniversalProvenanceTrace:
  emit_event(domain_id, event_type, payload, parent_hash?) → EventHandle
  get_lineage(decision_id) → ProvenanceChain
  replay_from(domain_id, from_tx_time, to_valid_time) → EventStream
```

Rationale: 7/9 domains maintain append-only logs. 3 use bitemporal models. 4 use hash-linked chains. The `parent_hash` on `emit_event` means Trust Boundary Protocol's own events are hash-linked to their source domain events — no provenance break at the boundary.

---

### Interface 3: TrustAccumulationBus

Unifies: ELO + Thompson Sampling, Baking Period and Hysteresis, Canary-Progressive Rollout, Multi-Layered Admission Gate.

```
TrustAccumulationBus:
  submit_signal(domain_id, signal_type, value, timestamp) → void
  get_trust_tier(domain_id) → TrustTier
  check_bake_status(domain_id, state_change_id) → BakeStatus
  request_admission(action_spec, requesting_domain) → AdmissionDecision
```

Rationale: 3/9 domains use ELO with Thompson Sampling. 5 use baking/hysteresis. 4 use multi-layer admission gates. Thompson Sampling for domain selection lives inside `request_admission`.

---

### Interface 4: TemporalQueryInterface

Unifies: Bitemporal Data Model, Event Sourcing, Exponential Decay, Append-Only Audit Trail.

```
TemporalQueryInterface:
  query_at(domain_id, valid_time, tx_time) → DomainSnapshot
  get_decay_weight(domain_id, evidence_id, as_of: timestamp) → float
  list_changes_since(domain_id, tx_time_cutoff) → ChangeLog
```

Rationale: 7 domains with append-only logs + 3 with bitemporal models. Without this, Trust Boundary Protocol assumes all signals are current — which Exponential Decay (4/9) explicitly falsifies.

---

### Interface 5: PolicyCompositionLayer

Unifies: OPA/Rego Policy-as-Code, Self-Referential Governance, Role-Separated Authority Model.

```
PolicyCompositionLayer:
  evaluate_bundle(policy_bundle_id, input_document) → PolicyDecision
  compose_policies(domain_ids: list) → ComposedPolicyBundle
  register_domain_policy(domain_id, rego_module, version) → PolicyHandle
  validate_self(policy_bundle_id) → ValidationReport
```

Rationale: 5/9 domains use OPA. 4 use self-referential governance. `validate_self` is the self-referential hook: before Trust Boundary Protocol deploys a new composed bundle, it runs the bundle against Trust Boundary Protocol's own operation log.

---

## The Dependency Stack

The 5 interfaces form a dependency chain — not a bus:

```
PolicyCompositionLayer
    ← governs →
TrustAccumulationBus
    ← routes signals from →
EpistemicBoundaryProtocol
    ← time-aware queries from →
TemporalQueryInterface
    ← all write to →
UniversalProvenanceTrace
```

**This ordering is not architectural opinion — it is the dependency graph the patterns impose on each other.**

Build bottom-up in this order: each layer is independently testable and the whole system is bootstrappable from the provenance layer alone.

Provenance is the foundation. Temporal correctness sits on top of it. Epistemic state is queried through the temporal layer. Trust accumulates from epistemic signals. Policy governs the trust accumulation decisions.

---

## Key Observation

These 9 repos are not independent projects. They are the **9 empirical domains of convergent evolution toward a unified epistemic boundary system**. Every domain independently arrived at the same abstract mechanism (Confidence-Gated Action, 9/9). Trust Boundary Protocol is the formalization of that convergence — not a product designed top-down, but a pattern that already exists distributed across the stack, waiting to be unified.
