@AGENTS.md

## Claude-specific notes

The import above pulls [`AGENTS.md`](AGENTS.md) into context — everything in
that file applies. The notes below are specific to Claude Code sessions.

- **This repo is docs-only.** Do not run `cargo`, `npm`, `python -m`, `make`,
  or any build/test command — there is no implementation and no toolchain.
  The only actions this repo supports are reading and editing Markdown.
- **No tracker.** There is no issue database or task tracker in this repo.
  Do not expect issue IDs or a tracker command. Open work is tracked in prose
  in `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` §11.
- **Prose edits.** Apply a clarity-and-concision pass to human-facing prose
  (`README.md`, `CONTRIBUTING.md`, the white paper). Do not "humanise" the
  specification's normative language — keep `MUST`, `MUST NOT`, `SHOULD`,
  `MAY` exact; they carry RFC-2119 weight.
- **Citations.** Internal references use `file:line`. External academic
  references use a full bibliographic citation — e.g. Snodgrass & Jensen on
  bitemporal data models, Dempster–Shafer belief theory, PAC-Bayes bounds.
  Never cite from memory; verify the source. See
  [`docs/agents/citation.md`](docs/agents/citation.md).
- **Staging vs published files.** `.gitignore` is the boundary: anything it
  matches is staging-only and never published. Everything else is the public
  artifact — treat edits to it with the PR discipline described in `AGENTS.md`.
- **Don't regress the spec.** `specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md` passed a five-pass
  adversarial review. Do not restructure or re-section it without an
  explicit request.

When a request is ambiguous, ask before editing a published file.
