#!/usr/bin/env bash
# pulse.sh — compute the blast radius of a change set and either report or
# block. Wraps `opa eval data.conformance.blast_radius.result` with the same
# preflight discipline as scripts/bootstrap.sh.
#
# Modes:
#   (default)             reads `git diff --name-only --cached` (live, lefthook)
#   --mode live           same as default
#   --mode audit          requires --diff-range R; reads `git diff --name-only R`
#   --mode predict        hypothetical mode; takes file globs as positional args
#   --predict GLOB...     shorthand for --mode predict
#
# Optional flags:
#   --diff-range R        the range for --mode audit (e.g. origin/main...HEAD)
#   --commit-msg-file F   path to a file holding the pending commit message;
#                         Pulse-Action: <id> DONE lines parsed from it
#   --json                emit the raw OPA result JSON to stdout (in addition
#                         to human-readable output on stderr)
#   --output-dir DIR      where to write opa-input.json / opa-eval.stdout /
#                         pr-comment.md / verdict.json (default: cwd)
#
# Exit codes:
#   0  = verdict.verdict in {"clear", "owed"}   (warnings only or no fire)
#   1  = verdict.verdict == "blocked"
#   2  = opa eval failed / manifest invalid / preflight failed
set -euo pipefail

# --- preflight ----------------------------------------------------------------
die() {
	printf 'pulse: %s\n' "$1" >&2
	exit "${2:-2}"
}

for tool in opa jq git awk; do
	command -v "$tool" >/dev/null 2>&1 ||
		die "required tool not found on PATH: $tool"
done

# --- arg parse ----------------------------------------------------------------
mode="live"
diff_range=""
commit_msg_file=""
emit_json=0
output_dir="."
predict_globs=()

while [ "$#" -gt 0 ]; do
	case "${1:-}" in
	--mode)
		mode="${2:-}"
		shift 2
		;;
	--diff-range)
		diff_range="${2:-}"
		shift 2
		;;
	--commit-msg-file)
		commit_msg_file="${2:-}"
		shift 2
		;;
	--predict)
		mode="predict"
		shift
		while [ "$#" -gt 0 ] && [ "${1:0:2}" != "--" ]; do
			predict_globs+=("$1")
			shift
		done
		;;
	--json)
		emit_json=1
		shift
		;;
	--output-dir)
		output_dir="${2:-}"
		shift 2
		;;
	-h | --help)
		sed -n '2,30p' "$0"
		exit 0
		;;
	*)
		die "unknown argument: ${1:-}"
		;;
	esac
done

case "$mode" in
live | audit | predict) ;;
*) die "invalid --mode: $mode (expected live|audit|predict)" ;;
esac

if [ "$mode" = "audit" ] && [ -z "$diff_range" ]; then
	die "--mode audit requires --diff-range R"
fi

mkdir -p "$output_dir"

# --- repo root + policy dir ---------------------------------------------------
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
policy_dir="$repo_root/conformance"
[ -d "$policy_dir" ] ||
	die "conformance/ directory not found at $policy_dir"
[ -f "$policy_dir/blast_radius.rego" ] ||
	die "conformance/blast_radius.rego not found"
[ -f "$policy_dir/affects.json" ] ||
	die "conformance/affects.json not found"

# --- compute changed_files set ------------------------------------------------
changed_files_file="$(mktemp)"
trap 'rm -f "$changed_files_file"' EXIT

case "$mode" in
live)
	(cd "$repo_root" && git diff --name-only --cached) >"$changed_files_file"
	;;
audit)
	(cd "$repo_root" && git diff --name-only "$diff_range") >"$changed_files_file"
	;;
predict)
	# Each positional glob is a literal file path the editor proposes to touch.
	# (Globbing is the caller's responsibility; pulse treats inputs as-is.)
	printf '%s\n' "${predict_globs[@]}" >"$changed_files_file"
	;;
esac

# --- detect JSON sub-targets --------------------------------------------------
# For every changed JSON file, compute the set of top-level dotted keys whose
# scalar value differs between the comparator state and the candidate state.
json_changes_file="$(mktemp)"
trap 'rm -f "$changed_files_file" "$json_changes_file"' EXIT
echo '{}' >"$json_changes_file"

_dotted_keys() {
	# Read JSON from stdin; emit a newline-delimited list of dotted scalar keys.
	jq -r 'paths(scalars) | join(".")' 2>/dev/null || true
}

_diff_dotted_keys() {
	local before="$1" after="$2"
	# Concatenate keys/values from both sides, find symmetric difference.
	diff <(
		jq -S 'paths(scalars) as $p | {key: ($p | join(".")), value: getpath($p)}' \
			"$before" 2>/dev/null | jq -c .
	) <(
		jq -S 'paths(scalars) as $p | {key: ($p | join(".")), value: getpath($p)}' \
			"$after" 2>/dev/null | jq -c .
	) | awk '/^[<>]/ {print}' | jq -r '.key' 2>/dev/null | sort -u
}

case "$mode" in
live | audit)
	# For each changed *.json, compare HEAD (or base of diff_range) to the
	# candidate (working tree for live, head of diff_range for audit).
	tmp_before="$(mktemp)"
	tmp_after="$(mktemp)"
	tmp_keys="$(mktemp)"
	trap 'rm -f "$changed_files_file" "$json_changes_file" "$tmp_before" "$tmp_after" "$tmp_keys"' EXIT

	while IFS= read -r path; do
		case "$path" in
		*.json) ;;
		*) continue ;;
		esac
		# Resolve "before" and "after" blobs.
		case "$mode" in
		live)
			# before = HEAD:<path>; after = working tree.
			git -C "$repo_root" show "HEAD:$path" >"$tmp_before" 2>/dev/null || echo '{}' >"$tmp_before"
			cp "$repo_root/$path" "$tmp_after" 2>/dev/null || echo '{}' >"$tmp_after"
			;;
		audit)
			base="${diff_range%%...*}"
			head="${diff_range##*...}"
			[ "$head" = "$diff_range" ] && head="${diff_range##*..}"
			git -C "$repo_root" show "$base:$path" >"$tmp_before" 2>/dev/null || echo '{}' >"$tmp_before"
			git -C "$repo_root" show "$head:$path" >"$tmp_after" 2>/dev/null || echo '{}' >"$tmp_after"
			;;
		esac
		# Compute differing dotted keys.
		_diff_dotted_keys "$tmp_before" "$tmp_after" >"$tmp_keys" || true
		if [ -s "$tmp_keys" ]; then
			# Merge into json_changes.
			keys_array="$(jq -R -s 'split("\n") | map(select(length > 0))' "$tmp_keys")"
			jq --arg p "$path" --argjson keys "$keys_array" \
				'. + {($p): $keys}' "$json_changes_file" >"$json_changes_file.tmp"
			mv "$json_changes_file.tmp" "$json_changes_file"
		fi
	done <"$changed_files_file"
	;;
predict)
	# predict mode never reads HEAD — keys default to "everything in the file"
	# treated as changed. For determinism we emit no json_changes (so subtarget
	# gates stay CLOSED in predict mode). The caller may pass --json-changes
	# explicitly (out of scope for v1).
	:
	;;
esac

# --- parse Pulse-Action footer ------------------------------------------------
done_actions_file="$(mktemp)"
trap 'rm -f "$changed_files_file" "$json_changes_file" "$tmp_before" "$tmp_after" "$tmp_keys" "$done_actions_file"' EXIT
: >"$done_actions_file"

if [ -n "$commit_msg_file" ] && [ -f "$commit_msg_file" ]; then
	awk '/^Pulse-Action:[[:space:]]*[A-Za-z0-9_-]+[[:space:]]+DONE[[:space:]]*$/ {
		# Extract the id between "Pulse-Action:" and "DONE".
		sub(/^Pulse-Action:[[:space:]]*/, "", $0)
		sub(/[[:space:]]+DONE[[:space:]]*$/, "", $0)
		print
	}' "$commit_msg_file" >"$done_actions_file"
fi

# --- compute git_sha ----------------------------------------------------------
git_sha="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || echo "")"

# --- build OPA input ----------------------------------------------------------
opa_input="$output_dir/opa-input.json"

changed_array="$(jq -R -s 'split("\n") | map(select(length > 0))' "$changed_files_file")"
done_array="$(jq -R -s 'split("\n") | map(select(length > 0))' "$done_actions_file")"
json_changes="$(cat "$json_changes_file")"

jq -n \
	--argjson changed "$changed_array" \
	--argjson json_changes "$json_changes" \
	--argjson done "$done_array" \
	--arg sha "$git_sha" \
	--arg mode "$mode" \
	'{
		changed_files: $changed,
		json_changes: $json_changes,
		commit_footer_actions_done: $done,
		git_sha: $sha,
		mode: $mode
	}' >"$opa_input"

# --- evaluate -----------------------------------------------------------------
opa_stdout="$output_dir/opa-eval.stdout"
opa_stderr="$output_dir/opa-eval.stderr"

set +e
opa eval \
	--data "$policy_dir" \
	--input "$opa_input" \
	--format json \
	'data.conformance.blast_radius.result' \
	>"$opa_stdout" \
	2>"$opa_stderr"
opa_exit=$?
set -e

if [ "$opa_exit" -ne 0 ]; then
	printf 'pulse: opa eval failed (exit %d):\n' "$opa_exit" >&2
	cat "$opa_stderr" >&2
	exit 2
fi

result_json="$(jq -c '.result[0].expressions[0].value' "$opa_stdout")"
[ -n "$result_json" ] && [ "$result_json" != "null" ] ||
	die "opa eval produced no result"

verdict="$(printf '%s' "$result_json" | jq -r '.verdict')"
errors="$(printf '%s' "$result_json" | jq -r '.errors')"
warnings="$(printf '%s' "$result_json" | jq -r '.warnings')"

printf '%s' "$result_json" >"$output_dir/verdict.json"

# --- emit human-readable report ----------------------------------------------
_render_report() {
	local sink="$1"
	{
		printf '[blast-radius] verdict=%s errors=%d warnings=%d (mode=%s)\n' \
			"$verdict" "$errors" "$warnings" "$mode"
		if [ "$verdict" != "clear" ]; then
			printf '%s\n' "$result_json" | jq -r '
				.fired[]
				| select(.owed_count > 0)
				| "  - \(.id) (\(.severity)) [owed=\(.owed_count)]\n      Trigger: \(.trigger)\n      Reason : \(.reason)\n      Affects: \(.affects | join(", "))\n      Required:\n" +
				  (.required_actions | map("        [" + (if .done then "x" else " " end) + "] " + .id + ": " + .text) | join("\n"))
			'
		fi
	} >"$sink"
}

_render_pr_comment() {
	local sink="$1"
	{
		printf '## Blast-radius pulse — %s\n\n' "$verdict"
		printf '- errors: %d\n- warnings: %d\n- mode: %s\n\n' "$errors" "$warnings" "$mode"
		if [ "$verdict" != "clear" ]; then
			printf '### Fired entries\n\n'
			printf '%s\n' "$result_json" | jq -r '
				.fired[]
				| select(.owed_count > 0)
				| "**" + .id + "** (`" + .severity + "`)\n\nTrigger: `" + .trigger + "`\n\n" +
				  "Reason: " + .reason + "\n\n" +
				  "Affects:\n" + (.affects | map("- `" + . + "`") | join("\n")) + "\n\n" +
				  "Required actions:\n" + (.required_actions | map("- [" + (if .done then "x" else " " end) + "] `" + .id + "`: " + .text) | join("\n")) + "\n\n---\n"
			'
		else
			printf 'No fired entries — the diff is clear.\n'
		fi
	} >"$sink"
}

case "$mode" in
live)
	_render_report /dev/stderr
	;;
predict)
	_render_report /dev/stdout
	;;
audit)
	_render_report "$output_dir/pulse-report.txt"
	_render_pr_comment "$output_dir/pr-comment.md"
	cat "$output_dir/pulse-report.txt" >&2
	;;
esac

if [ "$emit_json" -eq 1 ]; then
	printf '%s\n' "$result_json"
fi

# --- exit ---------------------------------------------------------------------
case "$verdict" in
clear | owed) exit 0 ;;
blocked) exit 1 ;;
*) die "unexpected verdict: $verdict" ;;
esac
