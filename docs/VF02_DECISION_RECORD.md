# VF-02 Decision Record — Authoritative Rig-to-Art Registration

## Status

The bounded production registration architecture and owner-review shoe
authority correction are implemented. Structural registration, the unchanged
Prompt 27B ruler, and aggregate gates pass. Current aesthetic/source-art
measurements remain visible and manual visual acceptance is
`[PENDING OWNER REVIEW]`.

## Pre-change placement-authority audit

Before VF-02, the `foundation` character presenter selected a view, read an
appearance/anatomy transform, applied authored size, pivot, rest rotation,
mirroring, and morphology, and submitted that result. Visual-geometry
landmarks measured the submitted pixels afterward. Rendering therefore owned
one authored-placement formula while the validator owned a second
post-submission expectation.

The audited authorities were:

- canonical skeleton transforms: animation, IK, and foot-planting authority;
- front/side presentation projection: view-specific joint and attachment
  targets;
- appearance/anatomy transforms: legacy component roots;
- `character_art.zig` sizes, pivots, and rest rotations: final legacy sprite
  placement;
- face-feature offsets: final legacy point placement;
- view mirroring: semantic identity-preserving signed scale;
- wardrobe binding transforms: final compatibility placement;
- visual-geometry alpha bounds and landmarks: measurement only.

## Shared registration contract

`visual_registration.zig` is the one bounded structural solver used before
production submission. Its definitions identify a stable component, binding
mode, source landmarks, projected targets, scale policy, mirroring policy,
explicit optional angular adjustment, and fail-closed policy.

Supported modes are:

- `point`: one alpha-visible atlas landmark to one projected target, with
  explicit orientation and scale;
- `point_axis`: one alpha-visible atlas landmark to one projected target plus
  one authored source axis to one explicit view-space orientation target;
- `segment`: proximal and distal atlas landmarks to projected joints, with
  longitudinal scale derived by the solver and transverse morphology applied
  independently;
- `frame`: three nondegenerate orthogonal frame points for torso/pelvis;
- `mesh_bridge`: validated schema boundary for a later bounded deformable
  bridge, without migrating production garments.

The solver emits `RegistrationEvidence` from the exact final
`SpriteRequest`. Production trace, VF-01 overlay, `state.json`, and structural
tests consume that same evidence. No post-submission per-component correction
exists.

## Bounded production migration

Both styles and front, side-right, and side-left presentation register:

- left/right upper arms: shoulder to elbow;
- left/right forearms: elbow to wrist;
- left/right thighs: hip to knee;
- left/right shins: knee to ankle;
- left/right front feet: ankle point plus explicit sole-axis orientation and
  scale policy;
- nose: alpha-visible center to the active projected anatomy feature;
- torso: front shoulder-span/depth frame or side shoulder/profile frame;
- pelvis: front hip-span/waist frame or side hip/profile frame.

Registered submissions are classified `authoritative_registration`.
The equipped shoe is also authoritative: its alpha-derived ankle and authored
sole axis register to the exact `PointAxisTarget` stored by the anatomy foot.
In front view it uses the anatomy foot's full authored transverse scale.
Closed-footwear metadata declares that the shoe owns the rendered foot
envelope, suppresses the covered base-foot pixels, and exposes the ankle.
The suppressed base-foot trace and landmarks remain available to diagnostics.
Other wardrobe submissions remain bounded `compatibility_adapter` placements.
Unmigrated base anatomy, face features, hair, and hands are explicitly
`transitional_legacy`. No trace may claim authoritative registration without
solver evidence.

## Superseded and retained workarounds

- Removed from base anatomy: the former hard-coded front-foot `+/-78` degree
  rest-rotation branch.
- Owner-review discrepancy found: the initial VF-02 pass left an independent
  exact `+/-78` degree branch in `wardrobe_presentation.restRotation`, so
  `crimson_strap_shoe` remained a compatibility adapter with a second final
  orientation authority.
- Corrected: no hard-coded `+/-78` front-foot placement remains. The front
  base `point_axis` binding constrains the projected ankle position and
  orientation of the authored `sole_back -> sole_front` axis. The physical
  policy retains 16-degree male and 13-degree female bilateral toe-out as
  lateral/depth data. Front projection preserves the signed lateral
  component and discards depth instead of treating it as world Y. The current
  front base-foot requests therefore have `0` radians of sprite rotation.
- Corrected: equipped shoes consume the exact anatomy-foot
  `PointAxisTarget`, register their own alpha-derived ankle and sole axis
  through the shared solver, inherit the registered foot's full authored
  transverse scale in front, and emit that same final request to production,
  trace diagnostics, JSON, and validation.
- Corrected: closed footwear explicitly suppresses the covered base-foot
  pixels while retaining the hidden base-foot registration/landmark evidence;
  the ankle is its declared exposed anatomy anchor. There is one visible foot
  envelope owner rather than two overlapping pixel owners.
- Heel, toe, sole-back, and sole-front remain transformed evidence. They are
  not independent registration targets, so neither the base foot nor the shoe
  is described as full endpoint registration.
- Superseded for migrated parts: authored pivots and final root offsets remain
  source metadata but no longer place the registered sprite.
- Superseded for the migrated nose: the legacy face-feature offset no longer
  places the final nose.
- Retained: front/side projection root remaps, because they define the target
  presentation rather than a second final sprite placement.
- Retained as compatibility data: non-shoe wardrobe transforms and all
  unmigrated component pivots/offsets.
- Retained: whole-character Prompt 27B ground alignment. It translates final
  submissions and both sides of registration evidence together; it does not
  alter a component residual.

## Allocation and resource boundary

Alpha-visible bounds are scanned from the real atlas pages during
initialization and stored in a fixed catalog. Temporary PNG decode memory is
released immediately through an initialization-only scratch allocator.
Registration, tracing, F1, and normal submission allocate nothing per frame.

The enlarged fixed trace is one initialization-owned allocation instead of an
inline scene field. Its capacity, overflow behavior, and lifetime are
unchanged. This resolved the Debug executable stack overflow observed during
the first D3D12 launch without adding steady-state allocation or GPU
resources.

## Current-art result

Structural production evidence reports authoritative registered body and shoe
records at or below the unchanged `0.00001 m` threshold in front, side-right,
and side-left D3D12 bundles. In equipped frames the four base-foot records
remain registered diagnostic evidence but are explicitly not queued, while
four authoritative shoe records own the visible envelope.

The owner-review corrective run preserves the historical failing reports and
does not rebaseline any ruler. A fresh Prompt 27B report emits 9,752 metrics
with zero failures. Its 24 front `heel_side_sole_height` /
`toe_side_sole_height` rows all measure `0.0 px`. Those former failures were
registration-policy defects caused by the surviving wardrobe `+/-78` branch,
not deferred source-art defects. Remaining aesthetic/source-art concerns are
separate and do not excuse or reclassify that policy failure.

Historical real-D3D12/DXIL bundles `_0040` through `_0049` are preserved
unchanged. They prove the initial base registration but not the corrected shoe
authority: all four `crimson_strap_shoe` records in each were still
`compatibility_adapter`. Their exact coverage is:

- `_0040` / `_0041`: male and female front idle;
- `_0042` / `_0043`: female side-right idle, male front idle;
- `_0044` / `_0045`: female side-left walk, male front idle;
- `_0046`: female side-left idle plus All Diagnostics, male front idle;
- `_0047` through `_0049`: female and male front idle plus All Diagnostics.

The final corrective D3D12/DXIL proof set is:

- `_0068`: male/female front, body-only;
- `_0069`: male/female side-left, body-only;
- `_0070`: male/female side-right, body-only;
- `_0071`: male/female front, equipped feet;
- `_0072`: male/female side-left, equipped feet;
- `_0073`: male/female side-right, equipped feet.

Every final bundle is schema-3, manifest-complete, hash-valid, and
clean/debug-state-identical. Body-only bundles contain zero shoes and four
rendered anatomy feet. Equipped bundles contain four authoritative shoe
registrations and four explicitly suppressed base-foot diagnostic records.
All current front base-foot and shoe requests have `0` radians of rotation,
horizontal transformed sole axes, and zero sole-endpoint height delta. These
are diagnostic candidates, not approved goldens.

VF-03, body morphology expansion, materials, broad art reauthoring, wardrobe
conversion, locomotion retuning, handshake redesign, and Prompt 28 were not
started.
