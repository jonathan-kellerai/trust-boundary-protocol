---
title: TRUST-BOUNDARY-PROTOCOL Specification
version: 0.1-draft
status: draft
created: 2026-04-15
revised: 2026-05-20
hub_workspace: trust-boundary-protocol-draft-2026-05-27 (2612ec1c-eb35-482b-968b-d37651a2da6f)
empirical_basis: 9/9 Confidence-Gated Action convergence — 831 nodes, 1,104 edges
interfaces: 5
methods: 19 (UPT: 3, TQI: 3, EBP: 4, TAB: 5, PCL: 4)
changes_from_v0.1: pass5-synthesis — 16 targeted edits (CRITICAL/HIGH/MEDIUM severity)
---

# TRUST-BOUNDARY-PROTOCOL Specification
## Layered Invariant Mediating Epistemic Norms

- **Version:** 0.1-draft (revised 2026-05-20 — Pass 5 synthesis edits applied)
- **Status:** Draft — ready for `/spec-init`
- **Created:** 2026-04-15
- **Empirical basis:** 9-domain cross-cutting pattern analysis (`docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001.md`, `docs/pattern-report/trust-boundary-collector-synthesis.md`)
- **ThoughtBox Hub:** `trust-boundary-protocol-draft-2026-05-27` (workspace `2612ec1c`)

---

## 1. Problem Statement

No unified epistemic boundary layer exists across the 9-domain reference stack of independently-evolved systems.
Each domain independently manages confidence gating, provenance, trust, and policy — duplicating infrastructure and creating cross-domain action requests that are evaluated locally by each domain without shared visibility into the synchronized epistemic readiness of every participating domain.

The concrete failure mode: a domain can execute a cross-domain action while a collaborating domain's confidence is below its own threshold, because neither domain has a view into the other's epistemic state at the time of action.

TRUST-BOUNDARY-PROTOCOL solves this by providing a unified inspection and mediation layer.

**TRUST-BOUNDARY-PROTOCOL does not mediate content. It mediates epistemic readiness.**

---

## 2. Convergent Evolution Finding

The empirical basis for TRUST-BOUNDARY-PROTOCOL is that nine independently-developed systems, analyzed post-hoc, each implement the same abstract mechanism:

```
evidence → accumulate → compare_to_threshold → gate_action
```

This pattern appears in 9/9 domains with different implementations (DS intervals, ELO, PAC-Bayes, OPA deny, outcome scoring, narrative confidence, search relevance gating) but identical abstract structure.
TRUST-BOUNDARY-PROTOCOL is the formalization of this convergence — not a product designed top-down, but a pattern that already exists distributed across the stack, waiting to be unified.

| Pattern | Domain Coverage |
|---------|----------------|
| Confidence-Gated Action | 9/9 |
| Fail-Closed Default | 8/9 (CASS-SICA: conditional; sentinel-rag: absent) |
| Append-Only Audit Trail | 7/9 |
| Baking Period and Hysteresis | 5/9 |
| OPA/Rego Policy-as-Code | 5/9 |
| Self-Referential Governance | 4/9 |
| Multi-Layered Admission Gate | 4/9 |
| Hash-Linked Provenance Chain | 4/9 |
| Exponential Decay / Forgetting Curve | 4/9 |
| Event Sourcing + Pure Function Computation | 4/9 |

Every interface method in this spec is load-bearing for ≥ 3 domains.

---

## 3. Architecture

### 3.1 Dependency Graph

The 5 interfaces form a DAG with `UniversalProvenanceTrace` as the universal write sink.
The graph is **not** a linear chain — it has skip-layer dependencies, and UPT is a shared substrate.

```
PolicyCompositionLayer (L5)
    │ validate_self ──────────────────────────────────┐
    │ evaluate_bundle (invoked by TAB gate 3)          │
    ↓                                                  │
TrustAccumulationBus (L4)                              │
    │ request_admission → EBP.query_confidence (gate 2)│
    │   [gate 2 evaluates only domains whose           │
    │    declared_action_categories ∋ action_category] │
    │                  → PCL.evaluate_bundle (gate 3)  │
    │                  → TQI.list_changes_since (gate 4)│
    │ submit_signal    → TQI.get_decay_weight          │
    ↓                                                  │
EpistemicBoundaryProtocol (L3)                         │
    │ query_confidence → TQI.query_at                  │
    │ get_evidence_basis ──────────────────────────┐  │
    ↓                                              │  │
TemporalQueryInterface (L2)                        │  │
    │ query_at          → UPT.replay_from          │  │
    │ get_decay_weight  → UPT event timestamps     │  │
    │ list_changes_since → UPT commit range        │  │
    ↓                                             │  │
UniversalProvenanceTrace (L1) ←───────────────────┘──┘
    (shared write substrate — all layers audit to here)
```

**Note:** TAB (L4) has one upward dependency on PCL (L5) at gate 3 of `request_admission`.
This is the only upward call in the graph and is the primary reason the full admission chain cannot be tested until PCL is built.
Gate 3 can be stubbed for TAB unit testing but integration testing requires the full stack.

The critical hot path is `TAB.request_admission`: touches all 5 layers, maximum call depth 4, includes an external OPA process dependency at gate 3.

### 3.2 Build Order

Build bottom-up: UPT → TQI → EBP → TAB → PCL.
Each layer is independently specifiable; unit testing with mocked dependencies is possible at each layer.
Integration testing of EBP requires TQI (because `EBP.query_confidence` implementations MUST call `TQI.query_at`), and integration testing of TAB gate 3 requires PCL (`TAB.request_admission` calls `PCL.evaluate_bundle` at gate 3).
Full end-to-end testing requires the complete stack (UPT through PCL).
The substrate (UPT) is bootstrappable alone; full system functionality requires the bottom-up build order — see §3.4 for PCL bootstrap requirements.

Alternative orders were considered (see OQ-6 RESOLVED in §11) and rejected — bottom-up is the canonical and only supported delivery order.
Phased EBP-before-TQI would require `as_of` stubbing, creating a known-broken integration for the 4 decay-bearing domains and an unverifiable surface for CONSTRAINT 12 (ELO Decay).

### 3.3 EBP.is_action_ready — Scope Constraint

`EBP.is_action_ready` is a **confidence-only dry-run**:

- Evaluates whether a domain's current confidence exceeds its `fail_closed_threshold`.
- Does **not** run the 5-layer admission chain.
- Does **not** write to the provenance log.
- Returns an `AdmissionToken(token_kind="confidence_only")` when admitted, with a TTL.

The authoritative admission gate is `TAB.request_admission`.
The full 5-gate chain and the durable provenance write live exclusively there.
**Implementations that implement the 5-gate chain inside `is_action_ready` are non-compliant.**

Action executors MUST NOT accept a `confidence_only` token as authorization for cross-domain actions.
Only `full_admission` tokens issued by `TAB.request_admission` constitute authoritative admission (see CONSTRAINT 9).

### 3.4 Concurrency Model

TRUST-BOUNDARY-PROTOCOL v0.1 is specified as an in-process Python library.
The following concurrency requirements apply:

`TAB.request_admission` MUST execute under a per-action-category serialization lock.
Concurrent admission calls for the same `action_category` MUST complete in transaction order — no two evaluations for the same action category may execute gate 2 simultaneously.
The constraint snapshot version (CONSTRAINT 13) is read once at evaluation start and pinned for the duration of the evaluation; signal changes arriving during an in-flight evaluation are queued and take effect in the next evaluation.

`TAB.submit_signal` and token revocation (CONSTRAINT 10) MUST NOT interrupt an in-flight `request_admission` evaluation.
Revocation of `confidence_only` tokens issued by `EBP.is_action_ready` is synchronous with signal submission.
Revocation of `full_admission` tokens is also synchronous with signal submission, but if a `request_admission` evaluation is in-flight when the revocation occurs, the revocation applies to any token issued by that evaluation upon its completion — the in-flight evaluation is not interrupted.

CONSTRAINT 4 (evaluation set freeze) is enforced by the per-action-category serialization lock: domain deregistration requests received while a lock is held for that category are rejected until the lock is released.

Distributed deployment across multiple processes or hosts introduces additional concurrency semantics (distributed locking, clock synchronization, split-brain scenarios) that are out of scope for v0.1.
See OQ-9.

---

## 4. Shared Types

**Evaluation Window.** An evaluation window is a configurable time interval, measured on the transaction-time (tx_time) axis of the UPT log, during which signal submissions for a given `(domain_id, signal_type)` pair are considered "current" for gate-2 evaluation.
The default window duration is 60 seconds; implementations MAY make window duration configurable per domain via an additional parameter on `TAB.register_domain`.
Window boundaries are fixed at constraint snapshot version transitions: when a new constraint snapshot version begins (per CONSTRAINT 13), any in-progress window does not reset — the window boundary is purely time-based, not version-based.
A signal submitted at tx_time T is "within the evaluation window" of a `request_admission` call at tx_time T′ if and only if T′ − T ≤ window_duration.
Signals submitted before the window are treated as absent per CONSTRAINT 1.

All types shared across interfaces live in `trust_boundary_protocol.types`.
Interfaces import from there to prevent cross-layer coupling.

```python
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Literal, Optional, Protocol, Sequence

# ---------------------------------------------------------------------------
# Scalar aliases
# ---------------------------------------------------------------------------
DomainId  = str   # opaque identifier; one of the 9 LIMEN domains
Hash      = str   # hex-encoded SHA-256 (minimum)
Timestamp = datetime


# ---------------------------------------------------------------------------
# Admission verdict (ternary — replaces bare bool throughout)
# ---------------------------------------------------------------------------

class AdmissionVerdict(Enum):
    ADMITTED      = "admitted"
    DENIED        = "denied"
    INDETERMINATE = "indeterminate"
    # INDETERMINATE: timeout, error, or unknown state.
    # ALL callers MUST treat INDETERMINATE identically to DENIED.


# ---------------------------------------------------------------------------
# Trust tier
# ---------------------------------------------------------------------------

class TrustTierLevel(Enum):
    UNTRUSTED   = 0
    PROVISIONAL = 1
    BAKING      = 2
    TRUSTED     = 3
    CANONICAL   = 4


# ---------------------------------------------------------------------------
# Signal type taxonomy (CONSTRAINT 11; OQ-3 RESOLVED)
# ---------------------------------------------------------------------------
# Closed, peer-level enumeration of trust signal types. No type overrides,
# supersedes, or escalates another. TAB.request_admission applies the veto
# property uniformly: any single (domain_id, signal_type) pair below
# threshold yields DENIED for that domain, regardless of type.
# Domains declare a subset at TAB.register_domain;
# submit_signal MUST reject any signal_type not in this enum.

class SignalType(Enum):
    GROUNDEDNESS = "groundedness"   # evidence-grounded confidence (DS belief, PAC-Bayes bound, narrative-coherence threshold)
    POLICY       = "policy"          # OPA/Rego policy-compliance verdict
    SAFETY       = "safety"          # fail-closed bound (budget cap, network deny-by-default, canary tier)
    STABILITY    = "stability"       # bake/hysteresis status (oscillation detection, anti-flap)
    AUTHORITY    = "authority"       # calibration-based authority (ELO, Thompson Sampling, Wilson CI)

# Per-domain declared subsets (§9 reference stack):
#   ArchangelMCP  → {POLICY, SAFETY}
#   son-of-anton  → {GROUNDEDNESS}
#   companion     → {GROUNDEDNESS, POLICY}
#   CASS-SICA     → {AUTHORITY, STABILITY, SAFETY}
#   opa-rego      → {POLICY}
#   matryoshka    → {GROUNDEDNESS}
#   aegis-drop    → {GROUNDEDNESS, SAFETY}
#   sentinel-rag  → ∅ (stub adapter; see §9 OQ-5 resolution)
#   truth-jbt     → {AUTHORITY, GROUNDEDNESS}


# ---------------------------------------------------------------------------
# Admission token (issued by is_action_ready and request_admission on ADMITTED)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class AdmissionToken:
    token_id: str
    domain_id: DomainId
    action_type: str
    action_category: str
    token_kind: Literal["confidence_only", "full_admission"]
    # "confidence_only"  — issued by EBP.is_action_ready; attests that
    #                      the domain's confidence exceeded its threshold.
    #                      Does NOT constitute authoritative admission.
    #                      Action executors MUST NOT accept confidence_only
    #                      tokens as authorization for cross-domain actions.
    # "full_admission"   — issued by TAB.request_admission after all 5
    #                      gates pass. Constitutes authoritative admission.
    issued_at: Timestamp
    expires_at: Timestamp
    constraint_snapshot_version: int
    # Action execution MUST present a full_admission token.
    # confidence_only tokens MUST be rejected at the execution boundary.
    # Expired tokens MUST be rejected.
    # Tokens issued before the most recent signal change from any
    # participating domain MUST be rejected.


# ---------------------------------------------------------------------------
# EpistemicBoundaryProtocol types
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ConfidenceState:
    domain_id: DomainId
    hypothesis: str
    belief: float          # Dempster-Shafer belief  ∈ [0, 1]
    plausibility: float    # Dempster-Shafer plausibility  ∈ [belief, 1]
    point_estimate: float  # degrades to P(true) when belief == plausibility
    as_of: Timestamp
    decay_applied: bool
    # FAIL-CLOSED sentinel: belief=0.0, plausibility=0.0, point_estimate=0.0


@dataclass(frozen=True)
class ReadinessDecision:
    verdict: AdmissionVerdict
    domain_id: DomainId
    action_type: str
    confidence_state: ConfidenceState
    token: Optional[AdmissionToken]    # present only when verdict=ADMITTED; token_kind="confidence_only"
    # FAIL-CLOSED: verdict=DENIED, token=None


@dataclass(frozen=True)
class UncertaintyInterval:
    belief: float        # ∈ [0, 1]
    plausibility: float  # ∈ [belief, 1]
    domain_id: DomainId
    claim_id: str
    # Denial (fail-closed):  belief=0.0, plausibility=0.0   → [0, 0]
    # Total ignorance:        belief=0.0, plausibility=1.0   → [0, 1]
    # These are structurally distinct. FAIL-CLOSED returns [0, 0].


@dataclass(frozen=True)
class EvidenceTrace:
    decision_id: str
    domain_id: DomainId
    evidence_items: Sequence[EvidenceItem]
    provenance_hash: Hash
    # FAIL-CLOSED: evidence_items=[], provenance_hash=""


@dataclass(frozen=True)
class EvidenceItem:
    evidence_id: str
    source_domain: DomainId
    timestamp: Timestamp
    weight: float        # post-decay weight ∈ [0.0, 1.0]
    payload_hash: Hash


# ---------------------------------------------------------------------------
# UniversalProvenanceTrace types
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class EventHandle:
    event_id: str
    event_hash: Hash
    parent_hash: Optional[Hash]   # None only for genesis events
    domain_id: DomainId
    event_type: str
    tx_time: Timestamp
    # emit_event raises TrustBoundaryProtocolWriteRefused on any failure — never silently drops.
    # A handle is returned ONLY after durable commitment.


@dataclass(frozen=True)
class ProvenanceChain:
    decision_id: str
    events: Sequence[EventHandle]  # ordered root → leaf
    root_hash: Hash
    leaf_hash: Hash
    is_complete: bool
    # FAIL-CLOSED: is_complete=False, events=[]


@dataclass(frozen=True)
class EventStream:
    domain_id: DomainId
    from_tx_time: Timestamp
    to_valid_time: Timestamp
    events: Sequence[EventHandle]
    truncated: bool
    # FAIL-CLOSED: events=[], truncated=False


# ---------------------------------------------------------------------------
# TrustAccumulationBus types
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class DomainRegistration:
    domain_id: DomainId
    declared_signal_types: Sequence[SignalType]      # immutable after registration
    declared_action_categories: Sequence[str] # action categories this domain governs;
                                              # immutable after registration.
                                              # gate 2 of request_admission evaluates only
                                              # domains whose declared_action_categories
                                              # contains the ActionSpec.action_category.
    fail_closed_threshold: float              # signals below this → DENIED
    decay_factor: float                       # used by TQI.get_decay_weight
    registered_at: Timestamp
    registration_hash: Hash


@dataclass(frozen=True)
class TrustTier:
    domain_id: DomainId
    tier: TrustTierLevel
    since: Timestamp
    signal_count: int
    last_signal_time: Timestamp
    # FAIL-CLOSED: tier=UNTRUSTED


@dataclass(frozen=True)
class BakeStatus:
    domain_id: DomainId
    state_change_id: str
    is_baked: bool
    bake_window_seconds: int
    elapsed_seconds: int
    oscillation_detected: bool
    # FAIL-CLOSED: is_baked=False, oscillation_detected=True
    # Oscillation resets the bake window to zero — it does not pause it.


@dataclass(frozen=True)
class ActionSpec:
    action_type: str
    action_category: str          # MUST match a declared_action_categories value in at least one
                                  # registered DomainRegistration; gate 2 evaluates only domains
                                  # whose declared_action_categories contains this value.
    target_domain: DomainId
    epistemic_state: ConfidenceState
    requesting_domain: DomainId
    # Required by gate 1 (schema conformance).
    # Free-form str for action_spec is non-compliant.


@dataclass(frozen=True)
class AdmissionDecision:
    verdict: AdmissionVerdict
    requesting_domain: DomainId
    action_spec: ActionSpec
    layer_results: Sequence[AdmissionLayerResult]  # exactly 5 entries
    token: Optional[AdmissionToken]                # present only when verdict=ADMITTED; token_kind="full_admission"
    # FAIL-CLOSED: verdict=DENIED, token=None


@dataclass(frozen=True)
class AdmissionLayerResult:
    layer_name: str  # SCHEMA | CONFIDENCE | OPA_POLICY | BAKE_WINDOW | AUTHORITY
    passed: bool
    reason: str      # mandatory when passed=False


# ---------------------------------------------------------------------------
# TemporalQueryInterface types
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class DomainSnapshot:
    domain_id: DomainId
    valid_time: Timestamp
    tx_time: Timestamp
    confidence_states: Sequence[ConfidenceState]
    trust_tier: TrustTier
    snapshot_hash: Hash
    # FAIL-CLOSED: confidence_states=[], trust_tier at UNTRUSTED


@dataclass(frozen=True)
class ChangeLog:
    domain_id: DomainId
    since: Timestamp
    entries: Sequence[ChangeLogEntry]
    # FAIL-CLOSED: entries=[]


@dataclass(frozen=True)
class ChangeLogEntry:
    tx_time: Timestamp
    event_type: str
    event_hash: Hash
    summary: str


# ---------------------------------------------------------------------------
# PolicyCompositionLayer types
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class PolicyDecision:
    allowed: bool
    policy_bundle_id: str
    bindings: dict[str, object]
    trace: Optional[str]   # OPA decision trace for audit
    # FAIL-CLOSED: allowed=False


@dataclass(frozen=True)
class ComposedPolicyBundle:
    bundle_id: str
    source_domain_ids: Sequence[DomainId]
    rego_modules: Sequence[str]
    bundle_hash: Hash
    created_at: Timestamp
    # compose_policies raises TrustBoundaryProtocolPolicyCompositionRefused
    # if any source domain is in UNTRUSTED tier.


@dataclass(frozen=True)
class PolicyHandle:
    domain_id: DomainId
    rego_module: str
    version: str
    handle_id: str
    registered_at: Timestamp
    bundle_hash: Hash
    # register_domain_policy raises TrustBoundaryProtocolPolicyRegistrationRefused
    # if rego module fails self-validation.


@dataclass(frozen=True)
class ValidationReport:
    policy_bundle_id: str
    valid: bool
    violations: Sequence[ValidationViolation]
    validated_against_event_count: int
    # FAIL-CLOSED: valid=False


@dataclass(frozen=True)
class ValidationViolation:
    rule: str
    message: str
    severity: str   # "ERROR" | "WARNING"
```

---

## 5. Exception Hierarchy

```python
class TrustBoundaryProtocolError(Exception):
    """Base exception for all TRUST-BOUNDARY-PROTOCOL fail-closed refusals."""

class TrustBoundaryProtocolWriteRefused(TrustBoundaryProtocolError):
    """emit_event could not durably commit the event."""

class TrustBoundaryProtocolSignalRefused(TrustBoundaryProtocolError):
    """submit_signal received an unrecognized domain, undeclared type, or out-of-range value."""

class TrustBoundaryProtocolPolicyCompositionRefused(TrustBoundaryProtocolError):
    """compose_policies was called with an UNTRUSTED domain."""

class TrustBoundaryProtocolPolicyRegistrationRefused(TrustBoundaryProtocolError):
    """register_domain_policy failed rego self-validation."""
```

---

## 6. Interface Specifications

### 6.1 UniversalProvenanceTrace

Foundation layer.
All other interfaces write to this.
Every state-changing TRUST-BOUNDARY-PROTOCOL operation MUST emit an event here.

Unifies: Hash-Linked Provenance Chain (4/9), Append-Only Audit Trail (7/9), Event Sourcing (4/9), Bitemporal Data Model (3/9).

Substrate: Dolt (see Section 7).

```python
class UniversalProvenanceTrace(Protocol):

    def emit_event(
        self,
        domain_id: DomainId,
        event_type: str,
        payload: bytes,
        parent_hash: Optional[Hash] = None,
    ) -> EventHandle:
        """Append an event to the provenance log.

        parent_hash: when supplied, the event hash is computed as
        SHA256(payload + parent_hash.encode()), creating a tamper-evident chain.
        None is valid ONLY for genesis events.

        Raises TrustBoundaryProtocolWriteRefused on any failure.
        A handle is returned ONLY after durable commitment to the log.
        """
        ...

    def get_lineage(self, decision_id: str) -> ProvenanceChain:
        """Retrieve the full hash-linked provenance chain for a decision.

        FAIL-CLOSED: ProvenanceChain(is_complete=False, events=[]) when
        decision_id is unknown or any link is unresolvable.
        """
        ...

    def replay_from(
        self,
        domain_id: DomainId,
        from_tx_time: Timestamp,
        to_valid_time: Timestamp,
    ) -> EventStream:
        """Replay events in a bitemporal window.

        from_tx_time: transaction time axis (when events were written).
        to_valid_time: valid time axis (when events are true in the domain).

        FAIL-CLOSED: EventStream(events=[]) — empty stream, not an error.
        """
        ...
```

### 6.2 TemporalQueryInterface

Time-correctness layer.
Prevents TRUST-BOUNDARY-PROTOCOL from treating all signals as current — the Exponential Decay pattern (4/9) falsifies "current" without a timestamp.

Unifies: Bitemporal Data Model (3/9), Event Sourcing (4/9), Exponential Decay (4/9), Append-Only Audit Trail (7/9).

```python
class TemporalQueryInterface(Protocol):

    def query_at(
        self,
        domain_id: DomainId,
        valid_time: Timestamp,
        tx_time: Timestamp,
    ) -> DomainSnapshot:
        """Retrieve a domain's full epistemic state at a bitemporal coordinate.

        valid_time: what was the world like at this time?
        tx_time: what did the system know at this time?

        FAIL-CLOSED: DomainSnapshot with empty confidence_states,
        trust_tier at UNTRUSTED.
        """
        ...

    def get_decay_weight(
        self,
        domain_id: DomainId,
        evidence_id: str,
        as_of: Timestamp,       # required — has no meaning without a timestamp
    ) -> float:
        """Compute the exponential decay weight for a piece of evidence.

        Returns decay_factor^(elapsed_seconds) where elapsed_seconds is
        (as_of − evidence_timestamp).total_seconds() and decay_factor is
        the value registered via TAB.register_domain.

        The exponent is measured in whole seconds. Implementations MUST
        use timezone-aware UTC datetimes for both as_of and
        evidence_timestamp to avoid clock-skew errors.

        FAIL-CLOSED: returns 0.0 (evidence treated as fully decayed
        when unknown or when domain is unregistered).
        """
        ...

    def list_changes_since(
        self,
        domain_id: DomainId,
        tx_time_cutoff: Timestamp,
    ) -> ChangeLog:
        """List all state changes for a domain since a transaction-time cutoff.

        FAIL-CLOSED: ChangeLog(entries=[]).
        """
        ...
```

### 6.3 EpistemicBoundaryProtocol

Primary domain contract.
Every TRUST-BOUNDARY-PROTOCOL domain MUST implement this interface.

Unifies: Confidence-Gated Action (9/9), Fail-Closed Default (8/9).

```python
class EpistemicBoundaryProtocol(Protocol):

    def query_confidence(
        self,
        domain_id: DomainId,
        hypothesis: str,
        as_of: Timestamp,       # required — Exponential Decay invariant
    ) -> ConfidenceState:
        """Return the domain's confidence on a hypothesis at a point in time.

        Implementations MUST call TQI.query_at(domain_id, as_of, now)
        to retrieve the time-correct epistemic state before computing
        the confidence snapshot.

        FAIL-CLOSED: ConfidenceState(belief=0.0, plausibility=0.0,
        point_estimate=0.0) when domain state is unknown.
        """
        ...

    def is_action_ready(
        self,
        domain_id: DomainId,
        action_type: str,
    ) -> ReadinessDecision:
        """Confidence-only dry-run: does current confidence exceed threshold?

        Scope: confidence check ONLY. Does NOT run the 5-layer admission
        chain. Does NOT write to UPT. Does NOT constitute authoritative
        admission.

        Returns:
          ADMITTED + token(token_kind="confidence_only")
                    when confidence ≥ fail_closed_threshold
          DENIED    when confidence < threshold or state unknown
          INDETERMINATE  on timeout or error

        Callers MUST treat INDETERMINATE identically to DENIED.
        Action executors MUST NOT accept confidence_only tokens as
        authorization. Only full_admission tokens from TAB.request_admission
        constitute authoritative admission (CONSTRAINT 9).

        FAIL-CLOSED: verdict=DENIED, token=None.
        """
        ...

    def get_uncertainty_interval(
        self,
        domain_id: DomainId,
        claim_id: str,
    ) -> UncertaintyInterval:
        """Return the DS [belief, plausibility] interval for a claim.

        Denial (fail-closed) is [0.0, 0.0].
        Total ignorance (no evidence) is [0.0, 1.0].
        These are structurally distinct — callers MUST NOT conflate them.

        FAIL-CLOSED: UncertaintyInterval(belief=0.0, plausibility=0.0).
        """
        ...

    def get_evidence_basis(
        self,
        domain_id: DomainId,
        decision_id: str,
    ) -> EvidenceTrace:
        """Return the evidence trail behind a decision.

        Calls UPT.get_lineage internally to retrieve the hash-linked chain.

        FAIL-CLOSED: EvidenceTrace(evidence_items=[], provenance_hash="").
        """
        ...
```

### 6.4 TrustAccumulationBus

Signal accumulation and gating layer.
Owns the authoritative 5-gate admission chain.

Unifies: ELO + Thompson Sampling (3/9), Baking/Hysteresis (5/9), Multi-Layered Admission Gate (4/9).

```python
class TrustAccumulationBus(Protocol):

    def register_domain(
        self,
        domain_id: DomainId,
        declared_signal_types: Sequence[SignalType],
        declared_action_categories: Sequence[str],
        fail_closed_threshold: float,
        decay_factor: float,
    ) -> DomainRegistration:
        """Register a domain with TRUST-BOUNDARY-PROTOCOL.

        declared_signal_types: closed set of signal types this domain may
        submit. Immutable after registration. submit_signal MUST reject
        undeclared types.

        declared_action_categories: set of action categories this domain
        participates in as a gate-2 evaluator. Immutable after registration.
        request_admission evaluates only domains whose declared_action_categories
        contains the ActionSpec.action_category of the inbound action.
        A domain with an empty declared_action_categories set does NOT
        participate in any admission evaluation and is effectively dormant.

        fail_closed_threshold: signal values below this constitute denial
        at gate 2. Used by request_admission and is_action_ready.

        decay_factor: used by TQI.get_decay_weight. Solves the bootstrap
        dependency (TQI needs decay_factor before PCL is available).

        Raises TrustBoundaryProtocolSignalRefused on invalid configuration.
        """
        ...

    def submit_signal(
        self,
        domain_id: DomainId,
        signal_type: SignalType,
        value: float,           # MUST be in [0.0, 1.0]
        timestamp: Timestamp,
    ) -> None:
        """Submit a trust signal from a domain.

        Last-writer-wins per (domain_id, signal_type) within an evaluation
        window. Previous signals for the same pair are overwritten, never
        accumulated.

        signal_type MUST be in the domain's declared_signal_types.
        value MUST be in [0.0, 1.0].

        Raises TrustBoundaryProtocolSignalRefused on invalid domain, undeclared type,
        or out-of-range value.
        """
        ...

    def get_trust_tier(self, domain_id: DomainId) -> TrustTier:
        """Return the current trust tier for a domain.

        FAIL-CLOSED: TrustTier(tier=UNTRUSTED).
        """
        ...

    def check_bake_status(
        self,
        domain_id: DomainId,
        state_change_id: str,
    ) -> BakeStatus:
        """Check whether a state change has completed its baking period.

        Oscillation resets the bake window to zero (not pause).

        FAIL-CLOSED: BakeStatus(is_baked=False, oscillation_detected=True).
        """
        ...

    def request_admission(
        self,
        action_spec: ActionSpec,
        requesting_domain: DomainId,
    ) -> AdmissionDecision:
        """Authoritative 5-layer admission gate for a cross-domain action.

        All 5 layers MUST pass. Veto property enforced: any single
        registered domain's signal below its fail_closed_threshold
        produces verdict=DENIED, regardless of all other domains.

        Gate layers (all must pass):
          1. SCHEMA      — ActionSpec conforms to schema; action_category
                           is non-empty and matches a known category.
          2. CONFIDENCE  — EBP.query_confidence(domain) ≥ threshold,
                           per every domain whose declared_action_categories
                           contains the ActionSpec.action_category.
                           Per-domain veto: the veto property applies to the
                           MINIMUM signal value across all signal_types a domain
                           has declared and submitted within the evaluation window.
                           A single below-threshold (domain_id, signal_type) pair
                           within a domain produces DENY for that domain in gate 2.
                           A domain with no signal of any declared type in the
                           evaluation window = DENIED (CONSTRAINT 1).
                           Zero domains registered for the action's category = DENIED
                           (CONSTRAINT 2, CONSTRAINT 14).
          3. OPA_POLICY  — PCL.evaluate_bundle passes
          4. BAKE_WINDOW — check_bake_status passes
          5. AUTHORITY   — trust tier sufficient for action type

        Partial-admission audit semantics: when gates 1–N pass and gate N+1
        fails (1 ≤ N < 5), an audit event MUST be written to UPT with
        event_type="admission_aborted", recording the highest gate reached and
        the failing gate's reason. No AdmissionToken is issued. The provenance
        log is append-only — there is no rollback of the audit event itself.
        Side effects of gate 3 (OPA evaluation) and gate 4 (bake-status read)
        are read-only by construction; gate 5 (authority check) is read-only;
        gates therefore never require compensating writes. Callers MUST treat
        a partial-admission failure as DENIED, identical to any other denial.

        On ADMITTED: issues AdmissionToken(token_kind="full_admission") with TTL,
        writes admission event to UPT.emit_event.

        Thompson Sampling for domain selection lives inside this method
        when multiple domains could serve the action.

        Timeout or error at any layer → verdict=INDETERMINATE.
        All callers MUST treat INDETERMINATE identically to DENIED.

        FAIL-CLOSED: verdict=DENIED, token=None.
        """
        ...
```

### 6.5 PolicyCompositionLayer

Top of the stack.
Governs all decisions including its own.
Self-referential: TRUST-BOUNDARY-PROTOCOL evaluates its own operation log before deploying any new bundle.

Unifies: OPA/Rego Policy-as-Code (5/9), Self-Referential Governance (4/9).

```python
class PolicyCompositionLayer(Protocol):

    def evaluate_bundle(
        self,
        policy_bundle_id: str,
        input_document: dict[str, object],
    ) -> PolicyDecision:
        """Evaluate an OPA policy bundle against an input document.

        input_document maps to OPA's `input` binding.
        Evaluation uses `opa eval` subprocess (avoids Go FFI complexity).
        Domain policies stored at policies/{domain_id}/.

        FAIL-CLOSED: PolicyDecision(allowed=False).
        """
        ...

    def compose_policies(
        self,
        domain_ids: Sequence[DomainId],
    ) -> ComposedPolicyBundle:
        """Compose a single OPA bundle from multiple domain policies.

        Composition produces an inspectable bundle with an explicit
        conflict resolution log. NOT silent AND.

        validate_self MUST be called and pass before the composed bundle
        is deployed.

        Raises TrustBoundaryProtocolPolicyCompositionRefused if any source domain's
        trust tier is UNTRUSTED.
        """
        ...

    def register_domain_policy(
        self,
        domain_id: DomainId,
        rego_module: str,
        version: str,
    ) -> PolicyHandle:
        """Register a domain's OPA/Rego policy with TRUST-BOUNDARY-PROTOCOL.

        Calls validate_self internally before registration.
        Raises TrustBoundaryProtocolPolicyRegistrationRefused if rego fails self-validation.

        Bootstrap note: at system genesis (empty UPT), validate_self returns
        ValidationReport(valid=False) per its FAIL-CLOSED behavior. Implementations
        MUST provide a bootstrap exception path for the first policy registration
        (e.g., a genesis flag that bypasses validate_self with a mandatory audit
        log entry). See OQ-13.
        """
        ...

    def validate_self(
        self,
        policy_bundle_id: str,
    ) -> ValidationReport:
        """Run a policy bundle against TRUST-BOUNDARY-PROTOCOL's own operation log.

        Self-referential governance hook: evaluates the bundle against
        UPT.replay_from(TRUST_BOUNDARY_PROTOCOL_DOMAIN, ...) to verify that TRUST-BOUNDARY-PROTOCOL's own
        past decisions remain valid under the new policy.

        validate_self MUST pass before ANY bundle is deployed.

        FAIL-CLOSED: ValidationReport(valid=False, violations=[
            ValidationViolation(rule="SELF_CHECK",
                message="Unable to validate — unknown state",
                severity="ERROR")
        ]).
        """
        ...
```

---

## 7. Substrate: Dolt

Dolt is the substrate for `UniversalProvenanceTrace`.
It is the only component in the TRUST-BOUNDARY-PROTOCOL stack with an external runtime dependency.

### 7.1 Bitemporal Implementation

Dolt's `AS OF` clause covers the **transaction time (tx_time) axis only**:

```sql
-- Dolt native: tx_time via AS OF
SELECT * FROM domain_events AS OF 'commit_hash'
```

Valid time (when a fact is true in the domain) is **application-layer**, modeled as schema columns:

```sql
-- Application: valid_time via WHERE clause on app columns
SELECT * FROM domain_events
  AS OF @tx_commit_hash
 WHERE domain_id = @domain_id
   AND valid_from <= @valid_time
   AND (valid_to IS NULL OR valid_to > @valid_time)
```

Bitemporality is a **two-layer implementation**: Dolt `AS OF` for tx_time; application columns `(valid_from DATETIME, valid_to DATETIME)` for valid_time.
Implementors MUST NOT conflate the two axes.

Minimum provenance table schema:

```sql
CREATE TABLE domain_events (
    event_id      VARCHAR(64)  PRIMARY KEY,
    domain_id     VARCHAR(64)  NOT NULL,
    event_type    VARCHAR(128) NOT NULL,
    payload_hash  VARCHAR(64)  NOT NULL,
    parent_hash   VARCHAR(64),           -- NULL for genesis events
    event_hash    VARCHAR(64)  NOT NULL,
    valid_from    DATETIME     NOT NULL,
    valid_to      DATETIME,              -- NULL = currently valid
    tx_time       DATETIME     NOT NULL  -- set by application on insert
);
```

### 7.2 Append-Only Enforcement

True append-only requires 5 defense-in-depth layers.
SQL grants alone are insufficient — Dolt's VCS layer permits history rewriting independently of SQL permissions.

1. **SQL grants**: `GRANT SELECT, INSERT ON domain_events TO trust_boundary_protocol_writer` — denies UPDATE and DELETE at the SQL level.
2. **Dolt branch protection**: configure the main provenance branch to reject force-push.
3. **Remote hooks**: `pre-receive` hook rejects non-fast-forward pushes.
4. **Signed commits**: enable GPG commit signing for all provenance writes.
5. **Application hash-chain verification**: `parent_hash` chain enables tamper detection even if VCS layer is circumvented. `emit_event` MUST verify `parent_hash` on every write.

### 7.3 Hash-Linking Strategy

Dolt provides commit-level hashes (Prolly tree root over the entire table state at commit granularity).
Row-level hash-linking per the `parent_hash` parameter on `emit_event` is **application responsibility**.

**Recommended approach — batched commits with application hashing:**

```python
# Application computes row-level hash at each emit_event call:
event_hash = SHA256(payload + parent_hash.encode())
```

Multiple events per Dolt commit.
Application maintains the row-level `parent_hash` chain.
Dolt commit hashes serve as secondary verification at commit granularity.
This is more efficient than one-commit-per-event at scale while preserving tamper-evidence at the row level.

### 7.4 Branching Policy

Dolt branches are a **read-only analysis tool** for provenance tables:

- `PCL.validate_self` MAY branch from main, replay events, evaluate the proposed bundle, then discard the branch.
- `TQI.query_at` MAY branch for what-if scenario analysis.

**Forbidden on provenance tables:** `dolt merge --squash`, `dolt rebase`, any non-fast-forward merge to the main provenance branch, and any operation that rewrites commit history.
The main provenance branch MUST be strictly linear.
All writes go directly to main.

### 7.5 Bootstrap Decay Factor

`TQI.get_decay_weight` requires a per-domain `decay_factor` before PCL is built.
Resolution: `decay_factor` is supplied at domain registration via `TAB.register_domain`.
This decouples temporal decay configuration from OPA policy and enables TQI to operate before PCL is available.

### 7.6 Environment Requirements

TRUST-BOUNDARY-PROTOCOL v0.1 assumes the following minimum versions of external dependencies. Implementations targeting older versions MUST verify the cited features are available.

| Dependency | Minimum version | Required feature |
|---|---|---|
| Dolt | 1.0.0 | `AS OF` query syntax, branch protection, GPG-signed commits, Prolly tree semantics |
| OPA | 0.55.0 | `opa eval` subprocess invocation, JSON I/O, bundle format v1 |
| Python | 3.10 | `Protocol`, `dataclass(frozen=True)`, `Literal`, `Enum` — used throughout §4 and §6 |

Newer versions are permitted. The spec does not pin upper bounds — implementations SHOULD track upstream releases and report incompatibilities as Open Questions.

---

## 8. Correctness Invariants

These constraints are non-negotiable.
Implementations that violate any constraint are non-compliant.
Each constraint is accompanied by a testability criterion.

Additional normative requirements appear in §3.3 (`is_action_ready` scope), §6.3 (`query_confidence` TQI dependency), §7.2 (`parent_hash` verification), and §4 (token lifecycle).
These are incorporated by reference into the compliance requirement.

---

> **CONSTRAINT 1** (Absent Signal = Deny): `TAB.request_admission` MUST treat any domain registered via `TAB.register_domain` whose `declared_action_categories` contains the action's `action_category` and that has not submitted a signal of any declared type within the current evaluation window as a DENY for that domain.
> Implementations that treat absent signals as abstentions, no-ops, or implicit approvals are non-compliant.
>
> *Test:* Register domain with matching `declared_action_categories`, do not call `submit_signal`, call `request_admission` with matching `action_category` — MUST return DENIED.

---

> **CONSTRAINT 2** (Empty Set = Deny): `TAB.request_admission` MUST return `AdmissionDecision(verdict=DENIED)` when zero domains have a `declared_action_categories` entry matching the action's `action_category`.
> The empty set of domain approvals does not constitute approval.
> Implementations that return ADMITTED when no domains are registered for the action's category are non-compliant.
>
> *Test:* Call `request_admission` with an `action_category` that no registered domain has declared — MUST return DENIED.

---

> **CONSTRAINT 3** (Veto Property): The aggregation function used by `TAB.request_admission` MUST satisfy the veto property: if ANY single participating domain's most recent signal value (across all its declared signal types, per CONSTRAINT 14) is below that domain's `fail_closed_threshold`, `request_admission` MUST return `verdict=DENIED`, regardless of all other domains' signal values.
> Implementations whose aggregation permits high-confidence signals from other domains to compensate for a single below-threshold domain are non-compliant.
>
> *Test:* Register two domains with matching `declared_action_categories`. Submit below-threshold signal from domain A, above-threshold from domain B. `request_admission` MUST return DENIED.

---

> **CONSTRAINT 4** (Evaluation Freeze): A domain registered via `TAB.register_domain` MUST NOT be removed from the evaluation set while any action in that domain's `declared_action_categories` has a pending or in-progress evaluation.
> The registered domain set for an evaluation MUST be frozen at evaluation start.
> Implementations that permit domain removal during an active evaluation cycle are non-compliant.
>
> *Test:* Initiate `request_admission`. Attempt to deregister a participating domain before evaluation completes — MUST be rejected.

---

> **CONSTRAINT 5** (Ternary Return): `EBP.is_action_ready` and `TAB.request_admission` MUST return a ternary `AdmissionVerdict`: ADMITTED, DENIED, or INDETERMINATE.
> When any domain's signal cannot be evaluated within the configured timeout — including network errors, crashes, and resource exhaustion — the verdict MUST be INDETERMINATE.
> All callers MUST treat INDETERMINATE identically to DENIED.
> Implementations that convert INDETERMINATE to ADMITTED via retry, fallback, error handling, or default logic are non-compliant.
>
> *Test:* Simulate domain timeout during evaluation. Verify `AdmissionVerdict.INDETERMINATE` is returned. Verify caller logic treats it as DENIED.

---

> **CONSTRAINT 6** (Last-Writer-Wins): `TAB.submit_signal` MUST enforce last-writer-wins semantics per `(domain_id, signal_type)` pair within a single evaluation window.
> Only the most recent signal for a given `(domain_id, signal_type)` is used in aggregation.
> Previous signals for the same pair are overwritten, never accumulated.
> Implementations that sum, average, or otherwise accumulate multiple signals from the same `(domain_id, signal_type)` within an evaluation window are non-compliant.
>
> *Test:* Submit 10 signals from same `(domain_id, signal_type)`. Verify only the last value is used in the subsequent `request_admission` evaluation.

---

> **CONSTRAINT 7** (Signal Value Range): `TAB.submit_signal` MUST reject any `value` outside the closed interval [0.0, 1.0] at the interface boundary, before it enters the aggregation pipeline.
> Implementations that silently clamp out-of-range values or accept them without raising an exception are non-compliant.
> Repeated signal submissions for the same `(domain_id, signal_type)` within an evaluation window are accepted; the most recent value overwrites all prior values per CONSTRAINT 6 (Last-Writer-Wins).
> Implementations SHOULD enforce a per-domain rate limit on signal submission frequency as an operational hardening measure; excess signals that do not exceed the rate limit MUST still be processed under LWW semantics and MUST NOT be silently dropped.
>
> *Test:* Submit `value=1.5` — MUST raise `TrustBoundaryProtocolSignalRefused`. Submit `value=-0.1` — MUST raise `TrustBoundaryProtocolSignalRefused`. Submit `value=0.5` then `value=0.8` for the same `(domain_id, signal_type)` in one cycle — both MUST succeed; subsequent `request_admission` MUST use `0.8`.

---

> **CONSTRAINT 8** (Declared Signal Types): Each domain's `declared_signal_types` set is immutable after registration via `TAB.register_domain`.
> `TAB.submit_signal` MUST reject any signal whose `signal_type` is not in the submitting domain's declared set.
> Implementations that accept undeclared signal types or permit post-registration modification of the declared set are non-compliant.
>
> *Test:* Register domain with `declared_signal_types=["safety"]`. Submit signal with `signal_type="override"` — MUST raise `TrustBoundaryProtocolSignalRefused`.

---

> **CONSTRAINT 9** (Admission Token Validity): `EBP.is_action_ready` MUST issue an `AdmissionToken(token_kind="confidence_only")` on ADMITTED verdicts.
> `TAB.request_admission` MUST issue an `AdmissionToken(token_kind="full_admission")` on ADMITTED verdicts.
> Both MUST include a bounded `expires_at`.
> Action execution MUST present a `full_admission` token.
> Execution attempts presenting a `confidence_only` token, an expired token, or a token issued before the most recent signal change from any participating domain MUST be rejected.
> Implementations that permit action execution with a `confidence_only` token or without a valid, unexpired `full_admission` token are non-compliant.
>
> *Test:* Call `EBP.is_action_ready` — receive `token_kind="confidence_only"`. Present that token at the action execution boundary — MUST be rejected. Call `TAB.request_admission` — receive `token_kind="full_admission"`. Wait past `expires_at`. Present token — MUST be rejected.

---

> **CONSTRAINT 10** (Token Revocation on Signal Change): When a domain submits a new signal via `TAB.submit_signal`, all outstanding `AdmissionToken` instances whose evaluation included a signal from that domain MUST be immediately invalidated.
> Token invalidation MUST be synchronous with the signal submission (subject to the in-flight evaluation exception in §3.4).
> Implementations that allow previously-issued tokens to remain valid after a participating domain's signal has changed are non-compliant.
>
> *Test:* Receive token. Call `submit_signal` for a participating domain. Attempt action with old token — MUST be rejected.

---

> **CONSTRAINT 11** (Signal Type Taxonomy): The TRUST-BOUNDARY-PROTOCOL layer MUST define a closed, enumerated taxonomy of valid `signal_type` values.
> `TAB.submit_signal` MUST reject any `signal_type` not present in the taxonomy.
> The taxonomy MUST NOT contain signal types with override, supersede, or escalation semantics — no signal type may negate, outrank, or modify the interpretation of another signal type.
> Implementations that permit open-ended signal type creation or signal types with implicit hierarchical authority are non-compliant.
> The Protocol-level type annotation `SignalType` (defined in §4) makes this constraint statically checkable; runtime enforcement remains REQUIRED for dynamically-typed implementations or cross-language ports.
>
> *Test:* Attempt to register a domain with `declared_signal_types=["root_override"]` — MUST be rejected if not in taxonomy.

---

> **CONSTRAINT 12** (ELO Decay): Domain ELO ratings used for signal weighting in `TAB.request_admission` MUST incorporate a monotonically decreasing recency decay function.
> No domain's historical accuracy record may grant it permanent elevated weighting.
> The decay function MUST use the `decay_factor` registered via `TAB.register_domain`.
> The exponent is measured in whole seconds elapsed between the evidence timestamp and `as_of`.
> Implementations that use static, non-decaying ELO weights or that lack a per-domain configurable decay parameter are non-compliant.
>
> *Test:* Register domain with `decay_factor=0.9`. Submit high-confidence signals at T=0. At T=10 seconds with no new signals, verify the domain's effective weight is `0.9^10` of its T=0 weight.

---

> **CONSTRAINT 13** (Evaluation Snapshot): `TAB.request_admission` MUST operate on an immutable constraint snapshot identified by `constraint_snapshot_version` (included in any issued `AdmissionToken`).
> Constraint-change events corresponding to version N MUST complete before `request_admission` evaluates against version N+1.
> Implementations that evaluate `request_admission` against a constraint set being concurrently modified are non-compliant.
>
> *Test:* Trigger a signal change concurrently with an active `request_admission` evaluation. Verify the evaluation completes against a single consistent snapshot version, not a mixed state.

---

> **CONSTRAINT 14** (Action-Category Scoping): `TAB.request_admission` MUST evaluate gate 2 only against domains whose `DomainRegistration.declared_action_categories` contains the `ActionSpec.action_category` of the inbound action.
> A domain registered for category `"llm_generation"` MUST NOT be counted in the gate-2 evaluation set for an action with `action_category="network_egress"`.
> Zero domains registered for the action's category MUST produce `verdict=DENIED` per CONSTRAINT 2.
> Implementations that apply gate 2 universally to all registered domains regardless of their declared action categories are non-compliant.
>
> *Test:* Register domain A with `declared_action_categories=["llm_generation"]` and domain B with `declared_action_categories=["network_egress"]`. Submit above-threshold signals from domain A only. Call `request_admission` with `action_category="network_egress"`. Domain A MUST NOT participate in gate 2; domain B has no signal → MUST return DENIED per CONSTRAINT 1.

---

## 9. Domain Mapping

All 9 TRUST-BOUNDARY-PROTOCOL domains and their current EpistemicBoundaryProtocol implementation status.

| Domain | Repo | Confidence Mechanism | Fail-Closed | Append-Only Log | Temporal Decay | EBP Gap |
|--------|------|---------------------|-------------|-----------------|----------------|---------|
| ArchangelMCP | `~/ArchangelMCP` | PolicyGuardrailEngine + OPA deny (`gateway.py:middleware`) | Yes (`BreachAction=block`) | Ring buffer JSON — not true append-only | No | Migrate to append-only log; add decay |
| son-of-anton | `~/son-of-anton` | PAC-Bayes E-Process + KL-bound CI (`nervous-system/pac_bayes_shield.py`) | Yes (network deny-by-default, `network_policy.py:20`) | EventStream JSONL + FEC WAL — true append-only | No (PAC-Bayes is not time-decay) | Add temporal decay function |
| companion | `~/companion` † | Narrative confidence threshold=0.3 + OPA gate (`narrative/generator.ts:99`) | Yes (`default valid := false` + EMPTY_NARRATIVE) | Append-only date-partitioned JSONL (`store/event-log.ts`) | Yes — `0.9^n` session decay | Minimal — closest to full EBP compliance |
| CASS-SICA | `~/SQ-BCP-ft-DGM` | ELO + oscillation detection + budget cap (`safety/koth_guard.py`) | Mixed — local=closed; KotH gateway=**fail-open** (`koth_guard.py:14-19`) | Append-only JSONL audit 10MB rotation (`safety/audit.py`) | No (bake counter, not time-weighted) | Time-weighted decay; close fail-open on external deps |
| opa-rego | `~/opa-rego` | `default valid := false` + threshold_completeness (`sofa/standard/sofa.rego:721`) | Yes — canonical reference implementation | Stateless evaluator — no native log | No (deadline-based, not decay) | External provenance log; decay N/A for stateless |
| matryoshka | `~/matryoshka` | DS BPA over {Grounded, Partial, Abstain}, three tiers | Yes (Abstain-first + Circuit Breaker) | ProvenanceLedger hash-linked chain — **design only** | Yes — bitemporal valid/tx axes — **design only** | Implement designed architecture |
| aegis-drop | `~/aegis-drop` | DS [Bel, Pl] canary tiers 0.51/0.65/0.85 | Yes (TrustExpiry + Gate Zero) | DeploymentLedger tamper-evident — **design only** | Yes — TrustExpiry — **design only** | Implement designed architecture |
| sentinel-rag | `~/_.jonathans-worktrees/_.skunkworks-sentinel-rag` | None — UI error handling only | **Absent** | None | None | ALL 4 EBP methods from scratch |
| truth-jbt | `~/_.jonathans-worktrees/_.skunkworks-truth-jbt` | ELO + Wilson CI + Thompson Sampling (`src/koth/services/ranking.py:62`) | Partial — conflict resolution strategy-dependent | JSONL telemetry append-only (`src/koth/data/telemetry.py`) | ELO trend, no decay function | True fail-closed default; temporal decay on ELO |

† The `~/companion` path shown is illustrative; the directory was not present at the declared filesystem path at time of this review (Pass 4 ground-truth verification).
The EBP gap assessment and behavioral claims for this domain (narrative confidence threshold, OPA gate, session decay, date-partitioned JSONL) are documented from the pattern-report analysis (`docs/pattern-report/trust-boundary-collector-synthesis.md`) and have not been independently verified against source code.
The reference codebase is internal; cited file paths and behaviors should be treated as architectural documentation, not verified implementation facts.

**Closest implemented bitemporal model:** `companion` — exponential decay `0.9^n` on session evidence, date-partitioned append-only JSONL.
Univariant temporal (session counter), not fully bitemporal.
(Source path unverified — see note †.)

**Best bitemporal design reference:** `matryoshka` — `(valid_start_commit, valid_end_commit, tx_start, tx_end)` on every EvidenceSpan, grounded in Snodgrass/Jensen 1996.
Zero implementation.
Use as design reference for UPT bitemporal schema.

**Sentinel-rag adapter (OQ-5 RESOLVED — stub returning INDETERMINATE):** Sentinel-rag has no native confidence mechanism.
TRUST-BOUNDARY-PROTOCOL supplies a stub `EpistemicBoundaryProtocol` adapter that returns `AdmissionVerdict.INDETERMINATE` for every `query_confidence` and `is_action_ready` invocation.
Per CONSTRAINT 5, callers MUST treat INDETERMINATE identically to DENIED.
Sentinel-rag is therefore *registered* — preserving topology completeness — but cannot be *admitted* until it ships a real confidence source that satisfies the EBP contract.
The domain's `declared_action_categories` MUST be scoped to only those action categories for which it holds signal competence; until a real confidence mechanism is implemented, an empty `declared_action_categories` is RECOMMENDED to prevent permanent DENY on evaluations that include sentinel-rag.

---

## 10. Non-Goals

**TRUST-BOUNDARY-PROTOCOL does not mediate content.** It mediates the epistemic readiness of a domain to act.
TRUST-BOUNDARY-PROTOCOL is a confidence-state router, not a content filter or semantic validator.

**TRUST-BOUNDARY-PROTOCOL does not replace domain-internal confidence mechanisms.** Each domain continues operating its own confidence gating.
TRUST-BOUNDARY-PROTOCOL provides the cross-domain inspection and composition layer on top of those mechanisms.

**TRUST-BOUNDARY-PROTOCOL does not own domain policies.** Domains register their OPA/Rego policies with TRUST-BOUNDARY-PROTOCOL via `PCL.register_domain_policy`.
TRUST-BOUNDARY-PROTOCOL evaluates and composes them; it does not author them.

**TRUST-BOUNDARY-PROTOCOL does not resolve semantic conflicts.** If two domains hold contradictory views of the same fact, TRUST-BOUNDARY-PROTOCOL exposes the contradiction via `EBP.get_uncertainty_interval` but does not adjudicate it.

**TRUST-BOUNDARY-PROTOCOL does not provide message passing or event streaming.** It is an epistemic state inspection and mediation layer, not a pub/sub bus or event router.

**TRUST-BOUNDARY-PROTOCOL does not define a wire protocol, network transport, or IPC mechanism.** The v0.1 specification targets an in-process Python library deployment.
Network-distributed topologies are deferred to a future version.
See OQ-9.

---

## 11. Open Questions (Pre-`/spec-init`)

These require resolution before the spec is final.
Adversarial review phases (OODA, Red Team, Steelman) will stress-test each.

| # | Question | Impact |
|---|----------|--------|
| OQ-1 | Should `EBP.query_confidence.as_of` be `Timestamp` (non-optional) at the type level? The Exponential Decay invariant requires it; making it Optional for Protocol compatibility creates a footgun. **Note:** OQ-6 resolution assumes non-optional (path A); if OQ-1 resolves to Optional, OQ-6 must be re-evaluated. | Method signature, all 9 domain adapters |
| OQ-2 | Should `TAB.submit_signal` return `EventHandle` instead of `None`? Every signal write emits to UPT internally — returning the handle would make the provenance link explicit for callers. | Method signature, audit completeness |
| OQ-3 | **RESOLVED** — Closed 5-type peer enumeration: `GROUNDEDNESS`, `POLICY`, `SAFETY`, `STABILITY`, `AUTHORITY`. Definition in §4 (Shared Types). No type overrides, supersedes, or escalates another; TAB veto property applies uniformly at (domain_id, signal_type) granularity — any single pair below threshold denies that domain. | TAB compliance |
| OQ-4 | What is the admission token TTL? Per-domain configuration, per-action-type configuration, or TRUST-BOUNDARY-PROTOCOL global? Resolution should align TTL configuration granularity with the evaluation window duration configuration (§4). | CONSTRAINT 9 implementation |
| OQ-5 | **RESOLVED** — Option (a): stub EBP adapter returning `INDETERMINATE` for every confidence query. Per CONSTRAINT 5, callers treat INDETERMINATE as DENIED. Sentinel-rag is registered but cannot be admitted until it ships a real confidence source. `declared_action_categories` SHOULD be empty until a real adapter is implemented (see §9). | Domain adapter design |
| OQ-6 | **RESOLVED** (conditionally on OQ-1 path A — non-optional `as_of`) — Full-stack bottom-up (UPT → TQI → EBP → TAB → PCL) is the canonical and only supported delivery order. Phased EBP-before-TQI rejected: requires `as_of` stubbing, breaks integration for the 4 decay-bearing domains, and creates an unverifiable surface for CONSTRAINT 12. See §3.2. | Build order, milestone planning |
| OQ-7 | Constraint snapshot versioning — monotonic integer counter per TRUST-BOUNDARY-PROTOCOL instance, or content-addressed hash of the constraint set? | CONSTRAINT 13 implementation |
| OQ-8 | Does `TAB.register_domain` need an update path, or is re-registration (with a new `registration_hash`) the mutation mechanism? Calling `register_domain` with an existing `domain_id` SHOULD raise `TrustBoundaryProtocolSignalRefused` pending formal resolution. Domain lifecycle mutations are the prerequisite for CONSTRAINT 4 testability. | Domain lifecycle management |
| OQ-9 | Distributed deployment concurrency: what additional specification is required for TRUST-BOUNDARY-PROTOCOL deployments spanning multiple processes or hosts? v0.1 specifies in-process; distributed topology requires distributed locking, clock sync tolerance, and split-brain recovery semantics beyond §3.4. | §3.4 concurrency model; CONSTRAINT 4, 13; cross-process TAB and UPT |
| OQ-10 | Token presentation API: should TRUST-BOUNDARY-PROTOCOL expose a `validate_token(token: AdmissionToken) -> AdmissionVerdict` method on EBP or TAB, or is token validation the responsibility of each executing domain's adapter? CONSTRAINT 9 mandates "MUST reject" but specifies no API for the rejection. | CONSTRAINT 9; all domain adapters; action execution boundary |
| OQ-11 | Payload encoding for `UPT.emit_event`: the hash formula `SHA256(payload + parent_hash.encode())` requires deterministic serialization. Should TRUST-BOUNDARY-PROTOCOL mandate UTF-8 JSON with lexicographic key ordering as the canonical payload encoding, or leave encoding to implementors (risking cross-implementation hash incompatibility)? | §6.1 `emit_event`, §7.3 hash-linking strategy |
| OQ-12 | AUTHORITY signal normalization: ELO (unbounded integer), Wilson CI (confidence interval), and Thompson Sampling (Beta sample) are all cited as AUTHORITY signal sources but none are natively in [0.0, 1.0]. What is the required normalization function? (Candidates: logistic sigmoid of ELO delta vs. reference, Wilson CI lower bound, min-max against declared ELO range.) | CONSTRAINT 7, 12; AUTHORITY signal type; truth-jbt adapter |
| OQ-13 | PCL bootstrap exception path: at system genesis (empty UPT), `PCL.validate_self` FAIL-CLOSEs to `valid=False`, blocking the first policy registration. Does the first `register_domain_policy` call bypass `validate_self` with a mandatory audit log entry, or is there a hardcoded genesis bundle? | §6.5 `register_domain_policy`, §6.5 `validate_self`; PCL initialization |
