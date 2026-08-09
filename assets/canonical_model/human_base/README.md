# `human_base` M02 structural asset

This directory contains the repository-authoritative Prompt 2E evidence for the shared neutral `human_base` structural definition.

- `human_base.authoring.json` is the sole authoritative readable M02 asset source. It intentionally uses insignificant formatting, omitted schema defaults, and a different ordering for the schema-declared unordered component collection.
- `human_base.canonical.json` is the immutable normalized canonical golden. It is UTF-8, whitespace-free, 379,458 bytes, ends in `}` (`0x7d`), and has no trailing newline.
- `human_base.structural_report.txt` is the deterministic offline hierarchy, transform, measurement, joint, control, anchor, landmark, seam, site, effector, optional-module, and deferral report.

Canonical SHA-256:

`7b579784f239d90ae9757a0aec1967fc37cf752733a4ac13409977f6f3212381`

The 17 applicable file-backed invalid human definitions live under `tests/fixtures/canonical_model/human_base/invalid/`. Each is parsed by the real canonical authoring parser and rejected through the human validation matrix.

Male/female derived structural profiles remain deferred until canonical configuration records can prove derivation from this single shared base without introducing duplicate rigs. Collision proxies likewise remain `defer_from_m02` until resolved M03+ geometry can validate their placement and dimensions.

The explicit `zig build update-human-base-evidence` step reads the authoring source and intentionally rewrites only the derived canonical golden, invalid fixtures, and structural report. It never creates or repairs `human_base.authoring.json`. Ordinary `test`, `check`, `test-full`, and `verify` routes only read/compare the accepted evidence and never run the update step. A mismatch remains a failure until an author intentionally edits the source and runs the update command for separate owner review.
