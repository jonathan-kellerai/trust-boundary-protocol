---
title: TRUST-BOUNDARY-PROTOCOL Development Workflow
status: draft
created: 2026-04-15
plugins: <spec-plugin>@<plugin-marketplace>, <tdd-plugin>@<plugin-marketplace>
---

# TRUST-BOUNDARY-PROTOCOL Development Workflow

> This workflow used internal spec-generation and TDD-enforcement plugins; the workflow shape is portable to any equivalent toolchain.

- **Stack:** Python (core), OPA/Rego (policy layer), Dolt (substrate)
- **Build order:** Bottom-up — provenance → temporal → epistemic → trust → policy
- **Plugins:** a spec-generation plugin (spec generation), a TDD-enforcement plugin (test enforcement)
- **Ground truth:** `docs/adr/TRUST-BOUNDARY-PROTOCOL-ADR-0001.md` (validated), `docs/pattern-report/trust-boundary-collector-synthesis.md`

---

## Phase 0: Foundation (Complete)

- [x] ADR validated — 9-repo empirical confirmation, status `Validated`
- [x] Collector synthesis — 9/9 Confidence-Gated Action convergence, 5-interface API contract
- [x] 9 domain manifests in `manifests/`
- [x] Session transcripts compressed in `docs/sessions/`
- [ ] Current session transcript — run after session close:
  ```bash
  python3 ~/.claude/plugins/cache/<plugin-marketplace>/log-compressor-tools/1.4.0/skills/transcript-compressor/scripts/compress_transcript.py \
    ~/.claude/projects/<project>/<session>.jsonl \
    -o ~/limen/docs/sessions/session-50c46eda-limen-analysis.md --stats
  ```

---

## Phase 1: Spec Generation (a spec-generation plugin)

### 1.1 Write the Spec Draft

Before the spec pipeline runs, a draft spec must exist. Create at `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md`.

The draft must cover (drawn from ADR + Collector synthesis):
- Problem statement: no unified epistemic boundary layer across the 9-domain stack
- The 5 interfaces (EpistemicBoundaryProtocol, UniversalProvenanceTrace, TrustAccumulationBus, TemporalQueryInterface, PolicyCompositionLayer)
- The dependency stack (build order rationale)
- The 9-domain mapping (which domain each interface serves)
- The convergent evolution finding (why this is formalization, not invention)
- Substrate decision: Dolt for UniversalProvenanceTrace (bitemporal, time-queryable, version-controlled)
- Non-goals: TRUST-BOUNDARY-PROTOCOL does not mediate content; it mediates epistemic readiness

### 1.2 Initialize the Spec Pipeline

```bash
/spec-init ~/limen/specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md --phases default --models cross-model
```

Artifacts land in `specs/artifacts/trust-boundary-protocol/`.

**Pre-flight check (run before `/spec-init`):**
```bash
claude plugin list | grep -E "feature-spec|tdd|thoughtbox|morphllm"
```

### 1.3 Run the Spec Pipeline

```bash
/spec-resume trust-boundary-protocol --auto
```

Phase routing for TRUST-BOUNDARY-PROTOCOL:

| Phase | Type | Agent | Notes |
|-------|------|-------|-------|
| 1.1 Recon | exploration | Explore (Opus) | Scan 9 domain repos + limen/manifests/ |
| 1.2 Deepen | exploration | Explore (Opus) | Deep trace: provenance → policy dependency chain |
| 1.3 Inversion | reasoning | thoughtbox:architecture-planner-agent | ADR-style analysis of the 5-interface stack |
| 2.1 OODA | cross-model | strategic-reasoner + Grok + Gemini + Codex | Adversarial: does the dependency stack hold? |
| 2.2 Red Team | cross-model | strategic-reasoner + Grok + Gemini + Codex | Attack: where can TRUST-BOUNDARY-PROTOCOL be bypassed or gamed? |
| 2.3 Steelman | cross-model | strategic-reasoner + Grok + Gemini + Codex | Best case for alternative interface designs |
| 3.1 Error Scrub | quality_review | improvement-reasoner | Verify: API shapes, type names, Dolt schema refs |
| 4.1 Background | exploration | Explore | Write: Dolt substrate background, DS theory primers |
| 4.2 TDD Anchoring | semantic_search | morph-semantic-fix-agent | Link each interface method to test acceptance criteria |
| 5.1 Second Scrub | quality_review | improvement-reasoner | Final verification pass (3 iterations) |
| 5.2 De-slopify | editing | morph-editor-agent | Polish prose and format |
| 6.1 Validate Beads | validation | Explore | Verify spec structure for import |
| 6.2 Beads Import | import | beads:task-agent | Create tasks, wire dependencies |
| 7.1 OODA Closure | reasoning | strategic-reasoner | Final strategic review before implementation |

**Model recommendations:**
- Phases 1-3 (investigation, adversarial): Opus — these are the load-bearing analysis phases
- Phases 4-7 (polish, import, closure): Sonnet — high throughput, lower stakes

**Cross-model phase note:** TRUST-BOUNDARY-PROTOCOL's adversarial phases (2.1-2.3) are particularly important — the 5-interface contract will be stress-tested by 4 models simultaneously. The synthesis gate must produce evidence that the fail-closed invariant survives adversarial composition.

### 1.4 Spec Trum (Optional Deep Enrichment)

If phases 1-2 surface ambiguities in the 5-interface contract:

```bash
/spec-trum trust-boundary-protocol --depth deep
```

This dispatches additional Explore + MorphLLM searcher agents to enrich the spec with cross-domain evidence before implementation begins.

---

## Phase 2: TDD Baseline (a TDD-enforcement plugin)

Run before writing a single line of implementation code.

### 2.1 Establish Baseline

```bash
/tdd-observatory --repos ~/limen --depth quick --track
```

This inventories the current state (no tests yet) and creates beads tracking issues. The observatory output is the before-picture for the final health check.

### 2.2 Scan for Gaps

```bash
/tdd-scan ~/limen --format markdown --create-issues
```

Catches missing CI config, coverage thresholds, pre-commit hooks before implementation starts. Fixes any Critical gaps (GAP-01 through GAP-07) before proceeding.

### 2.3 Activate Strict TDD Enforcement

```bash
/tdd --strict
```

**Strict mode** requires test edits to precede source edits for EVERY file. This is the right mode for TRUST-BOUNDARY-PROTOCOL's bottom-up build — each interface layer is independently testable, so there is no valid reason to write source before tests at any point.

---

## Phase 3: Build — Layer 1: UniversalProvenanceTrace

The foundation layer. Dolt as the append-only, hash-linked, bitemporal substrate.

### 3.1 Test-First

Spawn `<tdd-plugin>:tdd-python-test-writer-agent` with the accepted spec for `UniversalProvenanceTrace`.

Required test coverage:
- `emit_event()` — appends to Dolt, returns EventHandle with hash
- `get_lineage()` — reconstructs ProvenanceChain from event log
- `replay_from()` — time-travel query using valid_time + tx_time axes
- Hash-linking invariant: `emit_event(parent_hash=X)` verifiable against parent
- Fail-closed: `get_lineage()` on unknown decision_id returns empty chain, never errors

Commit tests before implementation:
```
test(tbp): UniversalProvenanceTrace acceptance tests — red
```

### 3.2 Implement Against Tests

Implement only to make the tests pass. No speculative functionality.

Dolt substrate requirements:
- Table: `events(event_id, domain_id, event_type, payload_hash, parent_hash, valid_time, tx_time)`
- All inserts append-only — no UPDATE or DELETE
- `replay_from()` uses Dolt's `AS OF` clause for bitemporal queries

Commit:
```
feat(tbp): UniversalProvenanceTrace — green
```

### 3.3 Quality Gate

```bash
/tdd-scan ~/limen/src/universal_provenance_trace.py --format markdown
```

All tests pass. No Critical gaps. Coverage ≥ 90% for this file.

---

## Phase 4: Build — Layer 2: TemporalQueryInterface

Depends on: UniversalProvenanceTrace (Layer 1 green)

### 4.1 Test-First

`tdd-python-test-writer-agent` for `TemporalQueryInterface`.

Required coverage:
- `query_at(valid_time, tx_time)` — returns correct DomainSnapshot using Dolt AS OF
- `get_decay_weight()` — returns float in [0, 1]; weight=1.0 at t=0, decays monotonically
- `list_changes_since()` — returns ordered ChangeLog with no gaps
- Decay invariant: older evidence always has lower weight than newer evidence
- Temporal correctness: `query_at(t1)` for t1 < t2 never returns state from t2

Commit tests:
```
test(tbp): TemporalQueryInterface acceptance tests — red
```

### 4.2 Implement

Commit:
```
feat(tbp): TemporalQueryInterface — green
```

### 4.3 Quality Gate

Coverage ≥ 90%. No Critical gaps.

---

## Phase 5: Build — Layer 3: EpistemicBoundaryProtocol

Depends on: TemporalQueryInterface (Layer 2 green)

The primary domain contract — every TRUST-BOUNDARY-PROTOCOL domain must implement this interface.

### 5.1 Test-First

Required coverage:
- `query_confidence()` — returns ConfidenceState with `as_of` respected
- `is_action_ready()` — returns ReadinessDecision; never true when confidence below threshold
- `get_uncertainty_interval()` — returns `[belief, plausibility]` where belief ≤ plausibility
- `get_evidence_basis()` — returns EvidenceTrace with provenance hash chain
- Fail-closed invariant: all methods fail-closed when domain state is unknown
- Protocol compliance test: mock domain implementing all 4 methods passes compliance suite

Commit:
```
test(tbp): EpistemicBoundaryProtocol acceptance tests — red
```

### 5.2 Implement

Note: The protocol itself is an abstract interface. Implementation of the 9 domain adapters (one per TRUST-BOUNDARY-PROTOCOL domain) is subsequent work. This layer delivers: the protocol definition + a reference implementation + compliance test suite that all adapters must pass.

Commit:
```
feat(tbp): EpistemicBoundaryProtocol + reference implementation — green
```

### 5.3 Quality Gate

Coverage ≥ 90%. Protocol compliance test suite passes with reference implementation.

---

## Phase 6: Build — Layer 4: TrustAccumulationBus

Depends on: EpistemicBoundaryProtocol (Layer 3 green)

ELO + Wilson CI + Thompson Sampling + baking period + multi-layer admission gate.

### 6.1 Test-First

Required coverage:
- `submit_signal()` — signal recorded with timestamp; ELO updates after sufficient samples
- `get_trust_tier()` — returns correct TrustTier (L0-L4+) based on accumulated ELO
- `check_bake_status()` — returns BakeStatus.BAKING until N consecutive clean sessions
- `request_admission()` — all 5 gate layers evaluated; fail-closed when any layer fails
- Baking invariant: oscillation resets bake window (not just pauses it)
- Regression gating: get_trust_tier() cannot advance tier when ELO in regression
- Decay integration: signals older than decay window reduce ELO weight

Commit:
```
test(tbp): TrustAccumulationBus acceptance tests — red
```

### 6.2 Implement

Five-layer admission gate (Layer 4 owns layers 1-4; Layer 5 owns layer 5):
1. Schema conformance of the epistemic state object
2. Confidence threshold check per domain (calls EpistemicBoundaryProtocol)
3. OPA policy bundle evaluation (stub for Layer 5 — returns allow during Layer 4 phase)
4. Baking window check for stability
5. Authority/role check (stub for Layer 5)

Commit:
```
feat(tbp): TrustAccumulationBus — green
```

### 6.3 Quality Gate

Coverage ≥ 90%. Admission gate integration test: all 5 layers exercised with pass and fail cases.

---

## Phase 7: Build — Layer 5: PolicyCompositionLayer

Depends on: TrustAccumulationBus (Layer 4 green)

OPA/Rego policy evaluation + self-referential governance.

### 7.1 Test-First

Required coverage:
- `evaluate_bundle()` — OPA bundle evaluation returns PolicyDecision with reasons
- `compose_policies()` — composition produces inspectable bundle (not silent AND)
- `register_domain_policy()` — Rego module stored, versioned, returns PolicyHandle
- `validate_self()` — TRUST-BOUNDARY-PROTOCOL's own OPA bundle evaluated against TRUST-BOUNDARY-PROTOCOL's operation log
- Composition safety: composing two fail-closed policies produces fail-closed result
- Self-referential invariant: `validate_self()` must pass before any new bundle is deployed
- No-weaken guarantee: composing domain A and domain B never grants permissions neither held alone

Commit:
```
test(tbp): PolicyCompositionLayer acceptance tests — red
```

### 7.2 Implement

OPA integration notes:
- Use `opa eval` subprocess for bundle evaluation (avoids Go FFI complexity)
- Domain policies registered as `.rego` files in `policies/{domain_id}/`
- Composition produces a merged bundle with explicit conflict resolution log
- `validate_self()` evaluates `policies/trust-boundary-protocol/self-governance.rego` against `UniversalProvenanceTrace` event log

Fill in the 2 stubs from Layer 4 admission gate:
- Layer 3: `evaluate_bundle()` now resolves against real OPA bundles
- Layer 5: Authority/role check implemented via policy evaluation

Commit:
```
feat(tbp): PolicyCompositionLayer — green
```

### 7.3 Quality Gate

Coverage ≥ 90%. Self-referential governance test passes. All 5 admission gate layers now fully implemented (no stubs).

---

## Phase 8: Integration Testing

All 5 layers green. Now test the stack end-to-end.

### 8.1 Cross-Layer Integration Tests

Write integration tests that exercise the full dependency chain:

```
PolicyCompositionLayer
  → governs TrustAccumulationBus.request_admission()
  → which calls EpistemicBoundaryProtocol.is_action_ready()
  → which calls TemporalQueryInterface.query_at()
  → which reads from UniversalProvenanceTrace event log
```

Test: a signal emitted to UniversalProvenanceTrace propagates correctly through all 5 layers to a PolicyDecision.

### 8.2 Domain Adapter Smoke Tests

For each of the 9 TRUST-BOUNDARY-PROTOCOL domains, write a minimal adapter that implements EpistemicBoundaryProtocol and passes the protocol compliance test suite.

These are smoke tests — not full domain integrations — but they verify the protocol is implementable by each domain without modification.

Nine adapters × compliance suite = minimum integration proof.

### 8.3 TDD Observatory — Final Health Check

```bash
/tdd-observatory --repos ~/limen --depth deep --track
```

Compare against Phase 2 baseline. All 4 observatory axes (Specification Quality, Verification Coverage, Enforcement Rigor, Continuous Integration) should be ≥ 4/5 at this point.

---

## Phase 9: Ongoing Health Monitoring

### Scheduled

After each major milestone (spec complete, each layer green, integration complete):

```bash
/tdd-scan ~/limen --format markdown   # Gap check
/tdd-observatory --repos ~/limen --depth standard --track  # Health trend
```

### Spec Drift Check

The spec (a spec-generation plugin output) and the implementation will diverge. Catch it early:

```bash
/tdd-decouple ~/limen/specs/ --threshold 3
```

Flags any spec file with coupling score ≥ 3 for extraction. The TRUST-BOUNDARY-PROTOCOL spec and TRUST-BOUNDARY-PROTOCOL tests must evolve independently — spec describes behavior, tests verify it, neither defines the other.

---

## Commit Standards for TRUST-BOUNDARY-PROTOCOL

Follow Conventional Commits with `tbp` scope where appropriate:

| Type | Usage |
|------|-------|
| `test(tbp):` | Test files (must precede corresponding feat commits) |
| `feat(tbp):` | New interface implementation — must reference beads issue |
| `fix(tbp):` | Bug fix in existing interface |
| `docs(tbp):` | ADR updates, spec updates, workflow updates |
| `chore(tbp):` | Config, CI, dependencies |
| `refactor(tbp):` | Implementation changes that don't change interface contract |

**Zero dirty state rule applies.** No commit with failing tests. No commit with lint errors. No commit without UBS scan clean.

---

## Quick Reference — Commands

```bash
# Spec
/spec-init ~/limen/specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md --phases default --models cross-model
/spec-resume trust-boundary-protocol --auto
/spec-status trust-boundary-protocol
/spec-trum trust-boundary-protocol --depth deep

# TDD
/tdd --strict              # Activate strict enforcement
/tdd --status              # Check current mode
/tdd --off                 # Deactivate
/tdd-scan ~/limen --create-issues
/tdd-observatory --repos ~/limen --depth deep --track
/tdd-decouple ~/limen/specs/ --threshold 3

# Build validation
ubs ~/limen/src/ --format toon   # Static analysis before commit
bd ready                          # Check available work in issue tracker
bd list --status=in_progress      # What's active
```
