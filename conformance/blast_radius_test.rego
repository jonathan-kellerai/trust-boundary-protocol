# METADATA
# title: blast-radius pulse — determinism test suite
# description: |
#   Enumerates every seed relationship in conformance/affects.json (BR-001
#   through BR-009) plus the empty-diff baseline plus the
#   commit_footer_actions_done coverage matrix plus sub-target gating.
#
#   The matrix is loaded from conformance/affects.json exactly as in
#   production; the tests vary `input` only (same convention as
#   trust_dial_test.rego). This is what makes the suite a proof that
#   blast_radius.rego is a pure deterministic function of (input, data).
package conformance.blast_radius_test

import data.conformance.blast_radius
import rego.v1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_input(changed, json_changes, done) := {
	"changed_files": changed,
	"json_changes": json_changes,
	"commit_footer_actions_done": done,
	"git_sha": "abc123",
	"mode": "live",
}

_fired_ids(result) := {f.id | some f in result.fired}

# ---------------------------------------------------------------------------
# Baseline — empty diff fires no entries and is clear.
# ---------------------------------------------------------------------------

test_no_diff_returns_clear if {
	result := blast_radius.result with input as _input([], {}, [])
	result.verdict == "clear"
	count(result.fired) == 0
	result.errors == 0
	result.warnings == 0
}

# ---------------------------------------------------------------------------
# BR-001 — editing conformance/conformance.rego requires digest refreeze.
# ---------------------------------------------------------------------------

test_br001_fires_on_policy_edit if {
	result := blast_radius.result with input as _input(
		["conformance/conformance.rego"], {}, [],
	)
	"BR-001-conformance-rego" in _fired_ids(result)
	result.verdict == "blocked"
}

test_br001_clears_when_all_actions_done if {
	# Editing conformance/conformance.rego also matches BR-006 (conformance/*.rego);
	# both rules' actions must be declared DONE for the verdict to clear.
	result := blast_radius.result with input as _input(
		["conformance/conformance.rego"],
		{},
		[
			"BR-001-conformance-rego-1",
			"BR-001-conformance-rego-2",
			"BR-001-conformance-rego-3",
			"BR-006-new-rego-policy-1",
			"BR-006-new-rego-policy-2",
			"BR-006-new-rego-policy-3",
			"BR-006-new-rego-policy-4",
		],
	)
	result.verdict == "clear"
	result.errors == 0
}

# ---------------------------------------------------------------------------
# BR-002 — artifact-types triplicate (sub-target gate).
# ---------------------------------------------------------------------------

test_br002_fires_on_artifact_types_subtarget if {
	# BR-002 is verifiable=false — it fires but downgrades from error to
	# warning. Verdict is "owed" (advisory), not "blocked".
	result := blast_radius.result with input as _input(
		["conformance/data.json"],
		{"conformance/data.json": ["schema.artifact_types"]},
		[],
	)
	"BR-002-artifact-types-triplicate" in _fired_ids(result)
	result.verdict == "owed"
	result.errors == 0
}

test_br002_does_not_fire_on_unrelated_subtarget if {
	# Editing _schema_version must NOT trigger BR-002 (sub-target gate works).
	result := blast_radius.result with input as _input(
		["conformance/data.json"],
		{"conformance/data.json": ["_schema_version"]},
		[],
	)
	not "BR-002-artifact-types-triplicate" in _fired_ids(result)
}

test_br002_clears_when_all_actions_done if {
	result := blast_radius.result with input as _input(
		["conformance/data.json"],
		{"conformance/data.json": ["schema.artifact_types"]},
		[
			"BR-002-artifact-types-triplicate-1",
			"BR-002-artifact-types-triplicate-2",
			"BR-002-artifact-types-triplicate-3",
			"BR-002-artifact-types-triplicate-4",
		],
	)
	result.verdict == "clear"
}

# ---------------------------------------------------------------------------
# BR-003 — required-files subtarget triggers template + bootstrap actions.
# ---------------------------------------------------------------------------

test_br003_fires_on_required_files_change if {
	# BR-003 is verifiable=false — bootstrap smoke test is not auto-checked.
	# Fires as a warning; verdict is "owed".
	result := blast_radius.result with input as _input(
		["conformance/data.json"],
		{"conformance/data.json": ["schema.required_files"]},
		[],
	)
	"BR-003-required-files" in _fired_ids(result)
	result.verdict == "owed"
	result.errors == 0
}

test_br003_clears_when_all_actions_done if {
	result := blast_radius.result with input as _input(
		["conformance/data.json"],
		{"conformance/data.json": ["schema.required_files"]},
		[
			"BR-003-required-files-1",
			"BR-003-required-files-2",
			"BR-003-required-files-3",
		],
	)
	result.verdict == "clear"
}

# ---------------------------------------------------------------------------
# BR-004 — AGENTS.md length (warning severity).
# ---------------------------------------------------------------------------

test_br004_fires_on_agents_md_edit_as_warning if {
	result := blast_radius.result with input as _input(
		["AGENTS.md"], {}, [],
	)
	"BR-004-agents-md" in _fired_ids(result)
	# Warning does not block.
	result.verdict == "owed"
	result.errors == 0
	result.warnings == 1
}

test_br004_clears_when_actions_done if {
	result := blast_radius.result with input as _input(
		["AGENTS.md"], {},
		["BR-004-agents-md-1", "BR-004-agents-md-2"],
	)
	result.verdict == "clear"
}

# ---------------------------------------------------------------------------
# BR-005 — CLAUDE.md invariants (error severity).
# ---------------------------------------------------------------------------

test_br005_fires_on_claude_md_edit if {
	result := blast_radius.result with input as _input(
		["CLAUDE.md"], {}, [],
	)
	"BR-005-claude-md" in _fired_ids(result)
	result.verdict == "blocked"
}

test_br005_clears_when_actions_done if {
	result := blast_radius.result with input as _input(
		["CLAUDE.md"], {},
		[
			"BR-005-claude-md-1",
			"BR-005-claude-md-2",
			"BR-005-claude-md-3",
		],
	)
	result.verdict == "clear"
}

# ---------------------------------------------------------------------------
# BR-006 — a NEW .rego file in conformance/ requires a sibling test.
# ---------------------------------------------------------------------------

test_br006_fires_on_new_rego if {
	# BR-006 is verifiable=false — OPA coverage parsing is fragile, so the
	# entry is advisory. Fires as a warning; verdict is "owed".
	result := blast_radius.result with input as _input(
		["conformance/new_policy.rego"], {}, [],
	)
	"BR-006-new-rego-policy" in _fired_ids(result)
	result.verdict == "owed"
	result.errors == 0
}

test_br006_clears_when_actions_done if {
	result := blast_radius.result with input as _input(
		["conformance/new_policy.rego"], {},
		[
			"BR-006-new-rego-policy-1",
			"BR-006-new-rego-policy-2",
			"BR-006-new-rego-policy-3",
			"BR-006-new-rego-policy-4",
		],
	)
	result.verdict == "clear"
}

# ---------------------------------------------------------------------------
# BR-007 — trust_dial.rego edits force matrix + test + template mirror updates.
# ---------------------------------------------------------------------------

test_br007_fires_on_trust_dial_edit if {
	# BR-007 is verifiable=false; BR-006 (also matches conformance/*.rego)
	# is also verifiable=false. Both fire as warnings; verdict is "owed".
	result := blast_radius.result with input as _input(
		["conformance/trust_dial.rego"], {}, [],
	)
	"BR-007-trust-dial-manifest" in _fired_ids(result)
	result.verdict == "owed"
	result.errors == 0
}

test_br007_clears_when_actions_done if {
	# trust_dial.rego also matches BR-006 (conformance/*.rego).
	result := blast_radius.result with input as _input(
		["conformance/trust_dial.rego"], {},
		[
			"BR-007-trust-dial-manifest-1",
			"BR-007-trust-dial-manifest-2",
			"BR-007-trust-dial-manifest-3",
			"BR-007-trust-dial-manifest-4",
			"BR-006-new-rego-policy-1",
			"BR-006-new-rego-policy-2",
			"BR-006-new-rego-policy-3",
			"BR-006-new-rego-policy-4",
		],
	)
	result.verdict == "clear"
}

# ---------------------------------------------------------------------------
# BR-008 — edits under template/_files/** are advisory (warning severity).
# ---------------------------------------------------------------------------

test_br008_fires_on_template_edit_as_warning if {
	result := blast_radius.result with input as _input(
		["template/_files/AGENTS.md"], {}, [],
	)
	"BR-008-templatized-required-file" in _fired_ids(result)
	result.verdict == "owed"
}

test_br008_clears_when_actions_done if {
	# template/_files/AGENTS.md also matches BR-013 (template/**).
	result := blast_radius.result with input as _input(
		["template/_files/AGENTS.md"], {},
		[
			"BR-008-templatized-required-file-1",
			"BR-008-templatized-required-file-2",
			"BR-013-template-coverage-1",
		],
	)
	result.verdict == "clear"
}

# ---------------------------------------------------------------------------
# BR-009 — conformance.yml contract change (warning severity).
# ---------------------------------------------------------------------------

test_br009_fires_on_conformance_yml_edit if {
	result := blast_radius.result with input as _input(
		[".github/workflows/conformance.yml"], {}, [],
	)
	"BR-009-conformance-workflow" in _fired_ids(result)
	result.verdict == "owed"
}

test_br009_clears_when_actions_done if {
	result := blast_radius.result with input as _input(
		[".github/workflows/conformance.yml"], {},
		[
			"BR-009-conformance-workflow-1",
			"BR-009-conformance-workflow-2",
		],
	)
	result.verdict == "clear"
}

# ---------------------------------------------------------------------------
# Sub-target gate: a JSON edit with no json_changes entry must NOT fire the
# subtarget-gated rules (BR-002, BR-003).
# ---------------------------------------------------------------------------

test_subtarget_gate_closed_when_no_json_changes if {
	result := blast_radius.result with input as _input(
		["conformance/data.json"], {}, [],
	)
	not "BR-002-artifact-types-triplicate" in _fired_ids(result)
	not "BR-003-required-files" in _fired_ids(result)
}

# ---------------------------------------------------------------------------
# Determinism: identical (input, data) -> identical verdict, twice.
# ---------------------------------------------------------------------------

test_deterministic_same_input_same_verdict if {
	in1 := _input(
		["conformance/conformance.rego"], {}, [],
	)
	v1 := blast_radius.result.verdict with input as in1
	v2 := blast_radius.result.verdict with input as in1
	v1 == v2
	v1 == "blocked"
}

# ---------------------------------------------------------------------------
# Severity mixing: a fired warning alongside a fired-and-cleared error
# downgrades from blocked to owed.
# ---------------------------------------------------------------------------

test_warning_does_not_block if {
	# Touch AGENTS.md only (warning severity); no error-severity rule fires.
	result := blast_radius.result with input as _input(
		["AGENTS.md"], {}, [],
	)
	result.verdict == "owed"
	blast_radius.allow with input as _input(["AGENTS.md"], {}, [])
}

# ---------------------------------------------------------------------------
# rationale string carries the four whitepaper-mandated fields.
# ---------------------------------------------------------------------------

test_result_carries_rule_applied if {
	result := blast_radius.result with input as _input([], {}, [])
	result.rule_applied == "affects_manifest"
}

test_result_carries_alternatives if {
	result := blast_radius.result with input as _input([], {}, [])
	result.alternatives == ["clear", "owed", "blocked"]
}

test_result_carries_rationale if {
	# conformance/conformance.rego matches BR-001 (verifiable=true error) AND
	# BR-006 (verifiable=false error → counted as warning). 2 fired, 1 error,
	# 1 warning, verdict blocked.
	result := blast_radius.result with input as _input(
		["conformance/conformance.rego"], {}, [],
	)
	result.rationale == "changed=1 fired=2 errors=1 warnings=1 -> blocked"
}

# ---------------------------------------------------------------------------
# Verifiable/unverifiable split — Option-D verdict semantics.
#
# Only a fired entry that is BOTH severity=="error" AND verifiable==true with
# owed_count > 0 counts as an error. Everything else with owed_count > 0
# (severity=="warning" OR verifiable==false) counts as a warning. The verdict
# blocks only on errors.
# ---------------------------------------------------------------------------

# Positive: a verifiable=true error with owed > 0 BLOCKS.
# CLAUDE.md edit fires BR-005 (severity=error, verifiable=true). One owed
# action remains → blocked.
test_verifiable_error_with_owed_blocks if {
	result := blast_radius.result with input as _input(
		["CLAUDE.md"], {}, [],
	)
	"BR-005-claude-md" in _fired_ids(result)
	result.verdict == "blocked"
	result.errors == 1
}

# Negative: a verifiable=false error with owed > 0 does NOT block — it
# downgrades to a warning. conformance/data.json with the artifact_types
# sub-target fires BR-002 alone (severity=error, verifiable=false). Verdict
# must be "owed", not "blocked".
test_unverifiable_error_with_owed_does_not_block if {
	result := blast_radius.result with input as _input(
		["conformance/data.json"],
		{"conformance/data.json": ["schema.artifact_types"]},
		[],
	)
	"BR-002-artifact-types-triplicate" in _fired_ids(result)
	result.verdict == "owed"
	result.errors == 0
	result.warnings == 1
	blast_radius.allow with input as _input(
		["conformance/data.json"],
		{"conformance/data.json": ["schema.artifact_types"]},
		[],
	)
}

# Cleared: a verifiable=true error with all actions footer-DONE has
# owed_count == 0 and does NOT block (verdict clear). CLAUDE.md edit with
# the three BR-005 actions DONE.
test_verifiable_error_cleared_when_all_actions_done if {
	result := blast_radius.result with input as _input(
		["CLAUDE.md"], {},
		[
			"BR-005-claude-md-1",
			"BR-005-claude-md-2",
			"BR-005-claude-md-3",
		],
	)
	"BR-005-claude-md" in _fired_ids(result)
	result.verdict == "clear"
	result.errors == 0
}

# Fired record carries the verifiable flag — downstream consumers (the
# pulse.sh PR comment, audit/blast-radius.jsonl) need to render it.
test_fired_record_carries_verifiable_field if {
	result := blast_radius.result with input as _input(
		["CLAUDE.md"], {}, [],
	)
	some f in result.fired
	f.id == "BR-005-claude-md"
	f.verifiable == true
}

# A mixed diff: one verifiable=true error (BR-005) AND one verifiable=false
# error (BR-002 via sub-target). Verdict is blocked from the verifiable error
# alone; the unverifiable error counts as a warning.
test_mixed_verifiable_and_unverifiable_errors if {
	result := blast_radius.result with input as _input(
		["CLAUDE.md", "conformance/data.json"],
		{"conformance/data.json": ["schema.artifact_types"]},
		[],
	)
	result.verdict == "blocked"
	result.errors == 1
	result.warnings == 1
}
