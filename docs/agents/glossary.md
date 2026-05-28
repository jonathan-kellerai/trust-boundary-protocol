# Glossary

Tier-2 detail for [`../../AGENTS.md`](../../AGENTS.md). The load-bearing
vocabulary of the Trust Boundary Protocol specification. Every term here is defined
authoritatively in [`../../specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md`](../../specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md);
this glossary is a fast index, not a substitute. Section references point
into the spec.

## The five interfaces

Trust Boundary Protocol is five interfaces in a dependency DAG, layered L1–L5 (spec §3, §6).

- **`UniversalProvenanceTrace`** (L1) — the append-only event substrate.
  Every state-changing Trust Boundary Protocol operation MUST emit an event here; all other
  layers write into it. It is the shared audit sink.
- **`TemporalQueryInterface`** (L2) — bitemporal query over the trace.
  Prevents Trust Boundary Protocol from treating every signal as current by giving each query
  a time axis.
- **`EpistemicBoundaryProtocol`** (L3) — the primary domain contract. Every
  participating domain MUST implement it; it is how a domain exposes its
  confidence to inspection.
- **`TrustAccumulationBus`** (L4) — signal accumulation and the
  authoritative 5-gate admission chain. Owns `request_admission`.
- **`PolicyCompositionLayer`** (L5) — OPA/Rego policy composition with
  self-validation; Trust Boundary Protocol evaluates its own operation log before deploying a
  new policy bundle.

## Decisions and verdicts

- **`AdmissionVerdict`** — the ternary outcome of an admission decision:
  `ADMITTED`, `DENIED`, or `INDETERMINATE`. `INDETERMINATE` covers timeout,
  error, or unknown state. **All callers MUST treat `INDETERMINATE`
  identically to `DENIED`** (spec §4). There is no fourth state and no
  default-allow.
- **Veto property** — the aggregation in
  `TrustAccumulationBus.request_admission` MUST satisfy this: if any single
  participating domain's most recent signal is below that domain's
  `fail_closed_threshold`, the verdict is `DENIED`, regardless of every
  other domain's confidence (spec §8, CONSTRAINT 3).
- **Fail-closed** — the absence of evidence denies. No signal, an expired
  token, an unbaked state, or an error all resolve toward `DENIED` /
  `REJECT`, never toward admission.

## Signals and tokens

- **`SignalType`** — a closed, peer-level enumeration of five signal types:
  `GROUNDEDNESS`, `POLICY`, `SAFETY`, `STABILITY`, `AUTHORITY`. The set is
  closed; no type overrides, supersedes, or escalates another (spec §4 —
  the resolution of OQ-3).
- **`AdmissionToken`** — the artifact attesting a decision. Its `token_kind`
  discriminator is either `confidence_only` (issued by
  `EpistemicBoundaryProtocol.is_action_ready`; attests that a domain's
  confidence cleared its threshold but is **not** authorization to act) or
  `full_admission` (issued by `request_admission` after all five gates pass;
  the only authoritative admission). Action executors MUST NOT accept a
  `confidence_only` token as authorization.
- **`DomainRegistration`** — the immutable record created when a domain
  registers. Its `declared_action_categories` field fixes which action
  categories the domain governs; gate 2 of `request_admission` evaluates
  only domains whose declared categories contain the action's category.

## Time and stability

- **Evaluation window** — a configurable interval on the transaction-time
  axis during which a `(domain_id, signal_type)` submission counts as
  "current" for gate-2 evaluation (default 60 seconds). A signal older than
  the window is treated as absent (spec §4, CONSTRAINT 1).
- **Bake window** — the hysteresis interval a domain's state change must
  survive before it counts as stable (`is_baked`). Detected oscillation
  resets the bake window to zero rather than pausing it; an unbaked or
  oscillating state is fail-closed.
- **Bitemporality** — provenance carries two independent time axes:
  *valid-time* (`valid_from`, `valid_to` — when a fact is true in the
  domain) and *transaction-time* (`tx_time` — when it was written). The two
  are a two-layer implementation and MUST NOT be conflated (spec §7).
- **Constraint snapshot version** — an integer identifying the immutable set
  of constraints `request_admission` evaluates against. Constraint changes
  for version N MUST complete before evaluation moves to N+1; the version is
  recorded in every issued `AdmissionToken` (spec §8, CONSTRAINT 13).

For anything ambiguous, the spec is authoritative — this glossary defers to
it.
