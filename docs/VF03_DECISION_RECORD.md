# VF-03 Decision Record — Typed Modular Component Graph

## Status

The VF-03-R1 rendered optional-arm correction is implemented on the bounded
immutable component-topology milestone. Focused graph, presentation,
registration, visual-foundation, wardrobe, and visual-geometry gates pass.
Eight fresh schema-4 D3D12/DXIL corrective bundles are complete,
machine-readable, and hash-valid. Manual visual acceptance remains
`[PENDING OWNER REVIEW]`.

VF-03 does not start body-morphology expansion, palette/material behavior,
broad production-art migration, arbitrary-limb IK/animation, a character
editor, Prompt 28, or a gameplay vertical slice.

## Topology authority

VF-03 consolidates the existing appearance and anatomy hierarchies through
`component_graph.Definition`. It is a compiled, allocation-free facade over
the immutable definitions rather than a third editable hierarchy. The facade
stores owner tokens and a topology fingerprint, then fails compatibility
validation if either source definition changes after initialization.

For every component it exposes:

- stable instance and definition identities;
- semantic role and tags;
- active state, parent component, and parent socket;
- point, segment, frame, or mesh binding mode;
- connection mode and declared gap/bridge data;
- supported and required presentation views;
- selected visual variant and bound visual identities;
- optional explicit rig-module ownership;
- material-slot and morphology-response declaration names.

Appearance remains the authority for transform-source evaluation and visual
attachment storage. Anatomy remains the authority for part evaluation,
deformation, active presets, and typed part sockets. The compiled graph is the
single runtime inspection and topology-validation authority spanning both.

## Typed sockets and connections

Part sockets now declare a stable ID, owner component, local transform,
accepted child tag, semantic role, capacity, supported connection modes, and
view metadata through their owner definition. Initialization rejects unknown
sockets, role/tag mismatches, capacity and multiplicity excess, forbidden
children, self-parenting, cycles, inactive required parents, duplicate IDs,
unsupported views, and unsupported connection modes.

Connection modes are explicit data:

- `continuous` declares a maximum connection gap;
- `intentional_gap` declares minimum and maximum visible gap;
- `hidden` names the component expected to hide the connection;
- `soft_bridge` names the bridge component that owns the span.

The connection mode is never inferred from alpha overlap. The technical
detached-arm proof measures `0.08 m` inside its declared `0.07–0.09 m`
intentional-gap contract. The same transform is rejected by a continuous
contract with its ordinary bound.

## Child-follow and hair proofs

The conventional and angular face definitions contain explicit:

```text
head
├── left_eye
│   └── left_eyebrow
└── right_eye
    └── right_eyebrow
```

Eyes attach to typed `head_eye` sockets. Eyebrows attach to typed `eye_brow`
sockets owned by their eye components. The production brow source region is
split into bounded left/right regions so each child has one final visual
identity. Eye, eyebrow, and hair submissions use the projected component
world transform and the shared point-registration solver; trace, VF-01 JSON,
and validation therefore report the same final request with zero structural
residual.

Hair components attach to the typed `head_scalp` socket. Front, side-left,
and side-right projection use the same component relationship. Secondary
motion remains an attachment-owned visual deformation applied after the
component anchor and does not mutate topology.

## Optional arm modules

The nonstandard technical preset owns two explicit optional arm components.
Each exported module contains:

```text
shoulder
└── elbow
    └── wrist
        └── hand_tip socket
```

Every joint and socket already exists in immutable appearance data at
initialization. The graph verifies the required chain, module owner, joint
parents, and end socket. It never creates a joint at runtime and never
duplicates a canonical humanoid semantic bone. The standard two-arm
production presets are unchanged.

One optional arm uses `continuous`; the second uses `intentional_gap`. F1
draws their component edges, typed sockets, module joints/sockets, final
visual bounds, graph binding identities, and the line through the declared
gap.

### VF-03 owner-review discrepancy and R1 correction

The original automated proof validated the compiled graph and its declared
`bound_visuals`, but `character_art.slotForAttachment` did not resolve those
optional identities into production slots. Consequently an active component
could compile while producing no `final_visual_submissions`. The overlay
showed the module topology, but the clean image contained only the standard
two arms. Side proof cases also initialized the modules inactive, so passing
projection tests did not prove visible production submission. Manual review
correctly rejected that evidence.

R1 makes the cross-layer result fail closed:

```text
declared bound visuals
  == resolved active graph visuals
  == expected production submissions
  == actual production submissions
```

Each active optional arm must resolve exactly three submissions:
`extra_upper_arm`, `extra_forearm`, and `extra_hand`, or the corresponding
`extra_second_*` identities. Production submission validates the owning
component/module and exact shoulder → elbow, elbow → wrist, and wrist →
hand-tip bindings. Missing, duplicate, orphaned, inactive, wrong-owner,
wrong-joint, or unsupported-view records fail rather than being omitted.

The visuals use existing anatomy regions with a deterministic technical tint
and enter the ordinary character-art `UnifiedRenderQueue`. Their transforms
come from the same projected module endpoints exported by schema 4; there is
no overlay-only arm and no second placement formula. Module one is green and
module two is magenta so the standard arms and both optional modules remain
distinguishable in the clean production frame.

For `continuous`, presentation reanchors the shoulder/root to the projected
torso socket and reports a measured gap of `0.0 m`. For
`intentional_gap`, the same module, visual set, pose, camera, and draw policy
use the declared `0.08 m` connection vector. The range remains
`0.07–0.09 m`; a `0.08 m` separation still fails the continuous contract.
The child offset is applied in world metres so morphology scale cannot change
the declared gap. The exported pixel length is derived at capture time as:

```text
gap_px = measured_gap_m × camera.pixels_per_meter
```

At the acceptance camera this is approximately `0.08 × 82 = 6.56 px`. The
upper-arm proximal alpha boundary begins at the projected child root, leaving
that span empty in the intentional-gap clean frame.

Inactive modules remain present as immutable definitions but are exported
with `active=false`, `bound_visual_submission_status=inactive`, and no final
submission index. They contribute zero optional visual submissions and no
active module/joint/socket/edge record.

## Projection and capture

Front and side projection now resolve every existing appearance transform
source category: canonical bone, attachment point, module joint, module
socket, and visual parent. `FrontAnatomyProjection` then evaluates typed
component parents and sockets in deterministic definition order. Unsupported
component views fail graph compilation.

VF-01 schema 4 exports component roles, binding and connection modes, parent
socket ownership, capacity/occupancy, active state, gap bounds, topology
status, material/morphology declaration names, bound visuals, module owners,
and projected transforms. The debug overlay and JSON consume the same frozen
snapshot. The schema expansion fills preallocated character records in place
to avoid stack copies; normal F1 execution remains allocation-free.

The deterministic initialization-only selector now includes the paired
rendered proof cases:

```text
--component-proof-case \
  <disabled|continuous-front|intentional-gap-front|continuous-side-left|\
   continuous-side-right|intentional-gap-side-left|\
   intentional-gap-side-right|two-modules>
```

It changes only initial proof content/view. F4 remains the existing
frame-level diagnostic edge and creates ordinary timestamped manual bundles.
`--capture-manual-bundle` invokes that same one-shot production capture path
for deterministic evidence; it does not create `CharacterIntent` or a second
renderer.

## Compatibility boundary

Direct graph components in this milestone are the typed eyes, eyebrows, hair,
optional arms, tail, and horns. Existing core torso/pelvis/head and standard
arm/leg components remain compatibility adapters where their established
attachment roots still own topology. Inactive combined eyebrow components and
their source attachments remain transitional compatibility data but are not
selected by current face presets.

This graph is suitable as a bounded export target for a future character
editor or 3D-to-atlas pipeline because identities, parents, sockets,
connections, view requirements, optional modules, and extension metadata are
explicit and deterministic. It is not yet a runtime editor, arbitrary
topology mutator, general arbitrary-limb animator, or material/morphology
system.

## Evidence

Historical `_0074–_0082` remain unchanged. They are diagnostic candidates and
are not used to prove the R1 rendered optional-arm correction.

The accepted fresh production D3D12/DXIL corrective set is:

- `_0083`: disabled front, zero active modules and zero optional submissions;
- `_0091`: continuous front, one active module and exactly three submissions;
- `_0092`: intentional-gap front, the same arm with a visible `0.08 m`
  (`6.560 px`) root gap;
- `_0093`: continuous side-left, one active module and three submissions;
- `_0094`: continuous side-right, reflected presentation with unchanged graph
  ownership and three submissions;
- `_0095`: intentional-gap side-left, `0.08000008 m` (`6.560007 px`);
- `_0096`: intentional-gap side-right, `0.08000003 m` (`6.560002 px`);
- `_0097`: both modules visible with distinct identities and exactly six
  submissions; primary continuous and secondary intentional-gap.

Every accepted bundle is schema 4, manifest-complete, JSON-parseable,
SHA-256/size valid, `direct3d12`/DXIL, and clean/debug frame, tick, state, and
common fingerprint identical. Missing and orphan counts are zero.

The first R1 active capture attempts `_0084–_0090` exposed an extra closing
brace in `state.json`. They were finalized because the prior finalizer
validated writes and hashes but did not parse its generated JSON. They remain
preserved invalid diagnostic candidates and are not completion evidence.
Finalization now parses both `state.json` and `manifest.json` before the
temporary directory can be renamed complete; `_0091–_0097` are the valid
replacements.

Fresh current-art Prompt 27B evidence remains fail-closed and passes 9,752
metrics with zero failures. Historical evidence and goldens are unchanged.
None of the VF-03 bundles is an approved golden.

Generalized optional-arm animation and IK remain deferred. VF-04 and Prompt
28 were not started.
