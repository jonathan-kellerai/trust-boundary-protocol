# METADATA
# title: trust-dial Dependabot auto-merge verdict policy
# description: |
#   Pure deterministic verdict function. Consumes a Dependabot PR descriptor
#   plus the live trust-dial state as `input`, and the verdict matrix +
#   thresholds (trust_dial_data.json) as `data`. Emits exactly one verdict.
#
#   The policy is a PURE function: no clock, no network, no filesystem read.
#   Every input is in `input`; every threshold is in `data.trust_dial`.
#   This is what makes `opa test` a proof of determinism.
package kellerai.oss.trust_dial

import rego.v1

# ---------------------------------------------------------------------------
# Data shortcuts (the trust-dial manifest, trust_dial_data.json)
# ---------------------------------------------------------------------------

_matrix := data.trust_dial.verdict_matrix

_budget := data.trust_dial.budget

# ---------------------------------------------------------------------------
# Ecosystem key — explicit override row, or the "default" row.
# ---------------------------------------------------------------------------

_eco := input.ecosystem if {
	_matrix[input.tier][input.ecosystem]
}

_eco := "default" if {
	not _matrix[input.tier][input.ecosystem]
}

# ---------------------------------------------------------------------------
# Base verdict — the (tier × ecosystem × update_type) cell.
# ---------------------------------------------------------------------------

_base := _matrix[input.tier][_eco][input.update_type]

# ---------------------------------------------------------------------------
# verdict — exactly one of: "auto-merge" | "hold-for-review" | "block".
# Fail-safe default: hold-for-review. Never auto-merge by omission.
# ---------------------------------------------------------------------------

default verdict := "hold-for-review"

# Non-auto-merge base verdicts pass through unchanged.
verdict := _base if {
	_base != "auto-merge"
}

# auto-merge survives only when the per-cycle budget has not been exhausted.
verdict := "auto-merge" if {
	_base == "auto-merge"
	input.cycle_merge_count < _budget.max_auto_merges_per_cycle
}

# auto-merge downgrades to hold-for-review once the budget is exhausted.
verdict := "hold-for-review" if {
	_base == "auto-merge"
	input.cycle_merge_count >= _budget.max_auto_merges_per_cycle
}

# ---------------------------------------------------------------------------
# rationale — a single string written verbatim into the decision trace.
# ---------------------------------------------------------------------------

rationale := sprintf(
	"tier=%s ecosystem=%s update_type=%s base=%s cycle=%d/%d -> %s",
	[
		input.tier, _eco, input.update_type, _base,
		input.cycle_merge_count, _budget.max_auto_merges_per_cycle, verdict,
	],
)

# ---------------------------------------------------------------------------
# decision — the full decision record, surfaced for trace emission.
# Carries the four whitepaper-mandated fields: inputs, rule_applied,
# alternatives, rationale.
# ---------------------------------------------------------------------------

decision := {
	"verdict": verdict,
	"rationale": rationale,
	"inputs": input,
	"rule_applied": "verdict_matrix",
	"alternatives": ["auto-merge", "hold-for-review", "block"],
}
