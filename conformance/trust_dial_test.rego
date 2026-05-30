# METADATA
# title: trust-dial verdict policy — determinism test suite
# description: |
#   Enumerates the verdict matrix (4 tiers × 3 update-types × budget states)
#   plus fail-safe cases. A passing run is a proof that trust_dial.rego is a
#   pure deterministic function of (input, data).
#
#   The thresholds and matrix are loaded from conformance/trust_dial_data.json
#   exactly as in production; the tests vary `input` only. This is the same
#   convention conformance_test.rego uses — and is what allows OPA to compile
#   without spurious cross-package recursion warnings.
package kellerai.oss.trust_dial_test

import data.kellerai.oss.trust_dial
import rego.v1

# ---------------------------------------------------------------------------
# Input fixture — every test passes a variation of this descriptor.
# ---------------------------------------------------------------------------

_input(tier, eco, update_type, cycle_n) := {
	"tier": tier,
	"ecosystem": eco,
	"update_type": update_type,
	"dependency": "actions/checkout",
	"from_version": "4.1.0",
	"to_version": "4.2.0",
	"cycle_merge_count": cycle_n,
	"pr_number": 42,
	"pr_actor": "dependabot[bot]",
}

# ---------------------------------------------------------------------------
# Observed — every cell is hold-for-review.
# ---------------------------------------------------------------------------

test_observed_patch_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Observed", "github-actions", "version-update:semver-patch", 0)
}

test_observed_minor_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Observed", "github-actions", "version-update:semver-minor", 0)
}

test_observed_major_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Observed", "github-actions", "version-update:semver-major", 0)
}

# ---------------------------------------------------------------------------
# Assisted — patch auto-merges (within budget); minor holds; major blocks.
# ---------------------------------------------------------------------------

test_assisted_patch_auto if {
	trust_dial.verdict == "auto-merge" with input as _input("Assisted", "github-actions", "version-update:semver-patch", 0)
}

test_assisted_patch_budget_exhausted_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Assisted", "github-actions", "version-update:semver-patch", 5)
}

test_assisted_minor_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Assisted", "github-actions", "version-update:semver-minor", 0)
}

test_assisted_major_blocks if {
	trust_dial.verdict == "block" with input as _input("Assisted", "github-actions", "version-update:semver-major", 0)
}

# ---------------------------------------------------------------------------
# Supervised — patch + minor auto-merge; major holds.
# ---------------------------------------------------------------------------

test_supervised_patch_auto if {
	trust_dial.verdict == "auto-merge" with input as _input("Supervised", "github-actions", "version-update:semver-patch", 0)
}

test_supervised_minor_auto if {
	trust_dial.verdict == "auto-merge" with input as _input("Supervised", "github-actions", "version-update:semver-minor", 0)
}

test_supervised_minor_budget_exhausted_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Supervised", "github-actions", "version-update:semver-minor", 5)
}

test_supervised_major_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Supervised", "github-actions", "version-update:semver-major", 0)
}

# ---------------------------------------------------------------------------
# Trusted — patch + minor auto-merge; major holds (deliberate ceiling).
# ---------------------------------------------------------------------------

test_trusted_patch_auto if {
	trust_dial.verdict == "auto-merge" with input as _input("Trusted", "github-actions", "version-update:semver-patch", 0)
}

test_trusted_minor_auto if {
	trust_dial.verdict == "auto-merge" with input as _input("Trusted", "github-actions", "version-update:semver-minor", 0)
}

test_trusted_major_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Trusted", "github-actions", "version-update:semver-major", 0)
}

test_trusted_patch_budget_exhausted_holds if {
	trust_dial.verdict == "hold-for-review" with input as _input("Trusted", "github-actions", "version-update:semver-patch", 5)
}

# ---------------------------------------------------------------------------
# Fail-safe: unknown tier → default `hold-for-review` (never auto-merge).
# ---------------------------------------------------------------------------

test_unknown_tier_falls_back_to_hold if {
	trust_dial.verdict == "hold-for-review" with input as _input("Untrusted", "github-actions", "version-update:semver-patch", 0)
}

# ---------------------------------------------------------------------------
# Ecosystem fallback: an ecosystem with no override falls back to "default".
# ---------------------------------------------------------------------------

test_unknown_ecosystem_uses_default_row if {
	trust_dial.verdict == "auto-merge" with input as _input("Assisted", "npm", "version-update:semver-patch", 0)
}

# ---------------------------------------------------------------------------
# decision record carries the four whitepaper-mandated fields.
# ---------------------------------------------------------------------------

test_decision_carries_rule_applied if {
	d := trust_dial.decision with input as _input("Observed", "github-actions", "version-update:semver-patch", 0)
	d.rule_applied == "verdict_matrix"
}

test_decision_carries_alternatives if {
	d := trust_dial.decision with input as _input("Observed", "github-actions", "version-update:semver-patch", 0)
	d.alternatives == ["auto-merge", "hold-for-review", "block"]
}

test_decision_carries_rationale if {
	d := trust_dial.decision with input as _input("Trusted", "github-actions", "version-update:semver-major", 0)
	d.rationale == "tier=Trusted ecosystem=default update_type=version-update:semver-major base=hold-for-review cycle=0/5 -> hold-for-review"
}

# ---------------------------------------------------------------------------
# Determinism: identical (input, data) → identical verdict, twice.
# ---------------------------------------------------------------------------

test_deterministic_same_input_same_verdict if {
	v1 := trust_dial.verdict with input as _input("Supervised", "github-actions", "version-update:semver-minor", 2)
	v2 := trust_dial.verdict with input as _input("Supervised", "github-actions", "version-update:semver-minor", 2)
	v1 == v2
	v1 == "auto-merge"
}
