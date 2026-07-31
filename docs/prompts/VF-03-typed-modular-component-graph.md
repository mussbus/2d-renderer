# VF-03 — Typed Modular Component Graph and Optional Rig Modules

## Source status

User-supplied exact execution package in the active Visual Foundation
handoff. This record summarizes the implemented bounded scope and does not
replace the exact request.

## Objective

Compile the established appearance and anatomy topology into one immutable,
inspectable runtime graph with typed sockets, explicit connection semantics,
and explicit optional rig modules. Do not create joints or mutate topology
during normal runtime.

## Implemented result

- one compiled graph facade over immutable appearance/anatomy definitions;
- owner-token and topology-fingerprint compatibility validation;
- typed component definitions and instances with point/segment/frame/mesh
  binding metadata, view requirements, multiplicity, child policy, material
  slot, and morphology-response extension declarations;
- typed sockets with roles, accepted child tags, capacities, and supported
  connection modes;
- fail-closed continuous, intentional-gap, hidden, and soft-bridge contracts;
- explicit head → eye → eyebrow and head/scalp → hair production paths;
- split left/right eyebrow visual bindings driven by projected component
  transforms and authoritative point registration;
- explicit extra-arm modules containing shoulder, elbow, wrist, and hand-tip
  socket data without canonical-bone duplication or runtime joint creation;
- one `0.08 m` intentional-gap technical arm proof;
- front, side-left, side-right, and reflected transform-source support;
- VF-01 schema 4 component/socket/module export and F1 overlay integration;
- a VF-03-R1 production submission invariant requiring each active optional
  arm's three graph-bound visuals to resolve to exactly three final
  submissions;
- real optional upper-arm, forearm, and hand submissions using the ordinary
  character-art queue and the exported projected module endpoints;
- paired continuous and `0.08 m` intentional-gap clean production proofs,
  including active front, side-left, side-right, disabled, and two-module
  cases;
- eight fresh real production D3D12/DXIL corrective bundles (`_0083`,
  `_0091–_0097`);
- deterministic invalid fixtures and steady-state allocation checks;
- manual visual acceptance `[PENDING OWNER REVIEW]`.

## Preserved boundaries

Controller, collision, canonical pose, animation, existing IK and foot
planting, interactions, fixed tick, production registration, unified render
queue, D3D12/DXIL renderer, resource lifetime, reset behavior, and historical
evidence remain authoritative in their established domains.

VF-03 does not add body-morphology behavior, materials, broad character or
wardrobe conversion, arbitrary-limb animation/IK, a runtime editor,
locomotion retuning, handshake redesign, Prompt 28, or a gameplay vertical
slice.

## VF-03-R1 owner-review correction

The original automated gate proved that the graph declared optional-arm
visual identities, but it did not require those identities to appear in
`final_visual_submissions`. The production slot resolver omitted them, the
clean images showed only the standard two arms, side proof modules were
inactive, and continuous versus intentional-gap pixels were not visibly
distinguishable. Manual acceptance therefore failed.

R1 keeps the accepted topology work and adds a fail-closed graph-to-production
contract:

```text
declared == resolved == expected == actual
```

The current expected and actual value is three per active module. Upper arm
binds shoulder → elbow, forearm binds elbow → wrist, and hand binds wrist →
hand-tip. Production, F1, schema 4, validation, summaries, and clean pixels
now consume the same binding result. Inactive visuals are explicitly
`inactive` with no final index; they are not mislabeled missing.

The paired root policies share character, preset, morphology, camera,
viewport, view, facing, module and visual identities, pose, frame policy, and
draw order. Continuous measures `0 m`; intentional-gap measures `0.08 m`
within `0.07–0.09 m`. Acceptance-camera length is derived from
`measured_gap_m × pixels_per_meter`, not hard-coded.

Historical `_0074–_0082` were not changed. Invalid `_0084–_0090` attempts are
preserved but not accepted; JSON parsing is now a prerequisite to bundle
finalization. The accepted set is `_0083` and `_0091–_0097`.

Manual visual acceptance: `[PENDING OWNER REVIEW]`.

VF-04: `NOT STARTED`.

Prompt 28: `NOT STARTED`.
