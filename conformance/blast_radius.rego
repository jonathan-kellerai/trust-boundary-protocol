# METADATA
# title: blast-radius pulse verdict policy
# description: |
#   Pure deterministic blast-radius function. Consumes a change set (the git
#   diff'd file paths, plus optional JSON sub-target diffs and a set of
#   commit-footer-declared DONE actions) as `input`, and the affects manifest
#   (conformance/affects.json) as `data.blast_radius.affects`. Emits exactly
#   one verdict structure carrying the fired entries, owed actions, and
#   aggregate counts.
#
#   The policy is a PURE function: no clock, no network, no filesystem read,
#   no opa.runtime. Every input is in `input`; every threshold and relationship
#   is in `data.blast_radius`. This is what makes `opa test` a proof of
#   determinism.
package conformance.blast_radius

import rego.v1

# ---------------------------------------------------------------------------
# Data shortcut (the affects manifest, conformance/affects.json)
# ---------------------------------------------------------------------------

_matrix := data.blast_radius.affects

# ---------------------------------------------------------------------------
# Input shortcuts
# ---------------------------------------------------------------------------

_paths := input.changed_files

_json_changes := object.get(input, "json_changes", {})

_done := {a | some a in object.get(input, "commit_footer_actions_done", [])}

# ---------------------------------------------------------------------------
# Glob helpers
# ---------------------------------------------------------------------------

# Strip any `#sub.target` suffix off a `when_changed` pattern; the path-level
# match operates on the bare path glob and the sub-target gate is a separate
# predicate (`_json_subtarget_match`).
_strip_subtarget(pattern) := before if {
	contains(pattern, "#")
	before := split(pattern, "#")[0]
}

_strip_subtarget(pattern) := pattern if {
	not contains(pattern, "#")
}

# `**` matches any number of path segments, `*` matches a single segment.
# Implementation uses OPA's `glob.match` with `/` as a separator and the
# wildcard set {"**", "*"} so `template/_files/**` does what an editor expects.
_glob_match(pattern, path) if {
	glob.match(pattern, ["/"], path)
}

# Exact match — falls through when glob.match returns false but the pattern is
# a literal path (no wildcards).
_glob_match(pattern, path) if {
	not contains(pattern, "*")
	pattern == path
}

# A `when_changed` value matches a changed path when:
#   * the bare path glob matches, AND
#   * if the value carries a `#json.subtarget` suffix, the input.json_changes
#     for that path actually contains that subtarget.
_when_changed_matches(entry, path) if {
	bare := _strip_subtarget(entry.when_changed)
	_glob_match(bare, path)
	_json_subtarget_match(entry, path)
}

# Sub-target gate: when no `#` is present, the gate is open (true for all
# matching paths). When `#` IS present, the suffix must appear in the
# `input.json_changes[path]` array.
_json_subtarget_match(entry, _) if {
	not contains(entry.when_changed, "#")
}

_json_subtarget_match(entry, path) if {
	contains(entry.when_changed, "#")
	target := split(entry.when_changed, "#")[1]
	changes := object.get(_json_changes, path, [])
	target in changes
}

# ---------------------------------------------------------------------------
# Per-entry verdict
# ---------------------------------------------------------------------------

# An entry "triggers" if any of its when_changed patterns matches any of the
# changed paths AND the sub-target gate (if any) is open.
_entry_triggers(entry) if {
	some path in _paths
	_when_changed_matches(entry, path)
}

# Which of the entry.affects globs are *present in the diff* (the editor
# already touched them — counts as half-credit toward the required actions)?
_affected_present(entry) := [p |
	some p in _paths
	some pattern in entry.affects
	_glob_match(pattern, p)
]

# Which of the entry.affects globs do NOT appear in the diff?
_affected_missing(entry) := [pattern |
	some pattern in entry.affects
	not _any_path_matches(pattern)
]

_any_path_matches(pattern) if {
	some path in _paths
	_glob_match(pattern, path)
}

# Build the per-required-action record. `done` is true when the action id
# appears in the commit-footer DONE set.
_action_record(entry, idx, text) := {
	"id": sprintf("%s-%d", [entry.id, idx + 1]),
	"text": text,
	"done": sprintf("%s-%d", [entry.id, idx + 1]) in _done,
}

_required_actions(entry) := [_action_record(entry, idx, text) |
	some idx, text in entry.required_actions
]

# Count of un-done required actions.
_owed_count(entry) := count([a |
	some a in _required_actions(entry)
	a.done == false
])

# ---------------------------------------------------------------------------
# Surface: fired entries
# ---------------------------------------------------------------------------

# The structured `fired` list — one element per entry whose when_changed
# matched a path in the diff.
fired contains f if {
	some entry in _matrix
	_entry_triggers(entry)
	f := {
		"id": entry.id,
		"trigger": entry.when_changed,
		"affects": entry.affects,
		"reason": entry.reason,
		"required_actions": _required_actions(entry),
		"severity": entry.severity,
		"verifiable": object.get(entry, "verifiable", false),
		"affected_present_in_diff": _affected_present(entry),
		"affected_missing_from_diff": _affected_missing(entry),
		"owed_count": _owed_count(entry),
	}
}

# ---------------------------------------------------------------------------
# Surface: aggregate counts
# ---------------------------------------------------------------------------
# Verifiable/unverifiable split — an entry's required_actions are "verifiable"
# when there is a deterministic post-condition the pulse (or CI) can check
# programmatically. Only verifiable=true error-severity entries with owed
# actions can BLOCK; verifiable=false errors and warning-severity entries
# downgrade to warnings (advisory). This keeps the gate honest: a blocked
# verdict means a machine-checkable invariant is owed, not just an advisory
# checklist. See docs/agents/enforcement.md for the per-entry classification.
# An entry is verifiable when entry.verifiable == true (explicit opt-in).
# Missing field defaults to false (advisory).
# ---------------------------------------------------------------------------

errors := count([f |
	some f in fired
	f.severity == "error"
	f.verifiable == true
	f.owed_count > 0
])

# Warnings include EVERY fired entry with owed actions that is NOT counted as
# an error (i.e. severity == "warning" OR verifiable == false). Severity is
# not the only axis any more — verifiability is the gate; severity is the
# author's intent. Both must align for a hard block.
warnings := count([f |
	some f in fired
	f.owed_count > 0
	not _is_error(f)
])

_is_error(f) if {
	f.severity == "error"
	f.verifiable == true
}

# ---------------------------------------------------------------------------
# Surface: verdict
# ---------------------------------------------------------------------------
# `clear`   = no entry fired with any owed action.
# `owed`    = at least one entry fired with owed actions, but none of them are
#             both error-severity AND verifiable=true (everything advisory).
# `blocked` = at least one verifiable=true error-severity entry fired with
#             owed actions.
# ---------------------------------------------------------------------------

default verdict := "clear"

verdict := "blocked" if {
	errors > 0
}

verdict := "owed" if {
	errors == 0
	warnings > 0
}

# ---------------------------------------------------------------------------
# Surface: allow — convenience boolean. True when verdict != blocked.
# ---------------------------------------------------------------------------

default allow := false

allow if verdict != "blocked"

# ---------------------------------------------------------------------------
# Surface: result — the full structured record returned by `opa eval`.
# Carries the four whitepaper-mandated fields: inputs, rule_applied,
# alternatives, rationale.
# ---------------------------------------------------------------------------

result := {
	"verdict": verdict,
	"fired": fired,
	"errors": errors,
	"warnings": warnings,
	"git_sha": object.get(input, "git_sha", ""),
	"mode": object.get(input, "mode", ""),
	"inputs": input,
	"rule_applied": "affects_manifest",
	"alternatives": ["clear", "owed", "blocked"],
	"rationale": sprintf(
		"changed=%d fired=%d errors=%d warnings=%d -> %s",
		[count(_paths), count(fired), errors, warnings, verdict],
	),
}
