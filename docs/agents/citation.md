# Citing Trust Boundary Protocol

Tier-2 detail for [`../../AGENTS.md`](../../AGENTS.md). This document covers
how to cite the Trust Boundary Protocol specification when you reference it elsewhere.

## Licence

The repository is licensed **Apache-2.0** (see [`../../LICENSE`](../../LICENSE)
and [`../../NOTICE`](../../NOTICE)). You may use, share, and adapt the
material, including commercially, under the terms of the licence.

## Attribution template

> *LIMEN — Layered Invariant Mediating Epistemic Norms* (version 0.1.0).
> Jonathan A. Bowe, 2026. Licensed Apache-2.0.
> https://github.com/jonathan-kellerai/trust-boundary-protocol

When you cite a specific claim, add the file and line — e.g.
`specs/TRUST-BOUNDARY-PROTOCOL-SPEC.md:188` for the rule that `INDETERMINATE` is treated as
`DENIED`.

## BibTeX

```bibtex
@misc{limen2026,
  author       = {Bowe, Jonathan A.},
  title        = {{LIMEN: Layered Invariant Mediating Epistemic Norms}},
  year         = {2026},
  version      = {0.1.0},
  howpublished = {\url{https://github.com/jonathan-kellerai/trust-boundary-protocol}},
  note         = {Specification. Licensed Apache-2.0}
}
```

## Suggested citation slug

`Trust Boundary Protocol 0.1.0` — always pin the version. The specification is an early draft;
its interfaces and types may change before `1.0.0`.

## Machine-readable citation

The repository ships a [`CITATION.cff`](../../CITATION.cff) file at its root,
so GitHub's "Cite this repository" widget and Zenodo archiving work
automatically. It is the authoritative citation source; the templates above
restate it for convenience.

## Citing the external sources Trust Boundary Protocol draws on

Trust Boundary Protocol itself cites prior work. If you follow those threads, cite the
originals in full — not Trust Boundary Protocol's summary of them. The specification draws on
the bitemporal data-model literature (Snodgrass & Jensen), Dempster–Shafer
belief theory, and PAC-Bayes generalisation bounds; §2 and §7 carry the
in-context citations.
