# ADR-005 — Editors Use the Production Schema

- Status: accepted contract; editor implementation deferred.
- Date: 2026-07-27.

## Decision

Future character, garment, level, and mission editors are interfaces over ordinary production definitions and validators. They do not own a second skeleton, fit model, layer model, reflection model, collider model, or asset identity namespace.

## Rationale

One schema lets interactive preview, CI validation, and runtime rendering evaluate the same data. Editor-only semantics would make exported content behave differently from preview.

## Consequences

- Routine garment export must not generate item-specific Zig renderer code.
- Preview invokes the production pose/view/morphology validator and renderer.
- Editor work begins only after the corresponding runtime schema is stable.
- Prompt 25E defines the contract but implements no GUI.
