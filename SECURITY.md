# Security Policy

Trust Boundary Protocol is a **specification**, not a running system. A security-relevant defect
here is a design choice in the specification that — implemented faithfully —
would create a vulnerability in a consuming system. For example: a field the
spec stores in the clear that should be hashed, or gate wording that admits a
fail-open path.

## Reporting a vulnerability

Report suspected security-relevant defects **privately**, through GitHub's
**Security Advisories** — use the *Report a vulnerability* button on this
repository's **Security** tab. Do not open a public issue for these.

Include:

- The location in the spec — file, section, and the interface, type, or
  CONSTRAINT involved.
- The defect, and the failure it would produce in a faithful implementation.

You can expect an initial response within a reasonable time. If a defect is
confirmed, it is corrected in the specification and recorded in `CHANGELOG.md`.

## Scope

This policy covers the Trust Boundary Protocol specification in this repository only. It does not
cover downstream systems that implement Trust Boundary Protocol — the security of an
implementation is the responsibility of its own maintainers.

## Supported versions

The specification is `v0.1-draft`. Only the current published version is in
scope; there is no back-port channel for a draft specification.
