# Engineering Brief — 3D Model Pipeline M02: `human_base` Structural Definition

**Status:** Ready for Codex implementation planning and staged execution  
**Milestone:** M02  
**Prerequisite:** M01 owner-accepted; M01.5 test-tier refactor complete  
**Source of truth:** `../architecture/3d_model_pipeline_canonical_decision_record_v1.md`  
**Downstream reference only:** `../architecture/creature_interaction_architecture_decision_record_v3.md`  
**Prior milestone evidence:** `3d_pipeline_m01_review_package.md`  
**Testing authority:** repository `docs/TESTING.md` as updated by M01.5  
**Owner-review gate:** Required before M03

---

## 1. Purpose

Instantiate the first real canonical human asset on top of the M01 canonical-model data foundation.

M02 creates the **structural definition of `human_base`**:

- canonical asset identity and neutral configuration;
- human component ownership tree;
- complete canonical human skeletal hierarchy;
- local A-pose rest transforms;
- articulated joint records;
- animator-facing structural controls;
- anchors, sockets, and mount relationships;
- structural semantic regions/surfaces;
- stable measurement landmarks;
- shared seam/boundary identities;
- interaction sites/effectors;
- structural collision-proxy descriptors where M01 can represent them cleanly;
- deterministic validation, normalization, serialization, hashing, and review evidence for the actual human structure.

M02 is the first milestone to instantiate the real `human_base` design. It is **not yet the production human mesh milestone**.

The central outcome is:

> The repository contains one deterministic, validated, renderer-independent canonical `human_base` structural asset that later mesh, skinning, morphology, garment, animation, collision, and representation systems can consume without inventing their own human skeleton or registration landmarks.

---

## 2. Authority and precedence

Codex must treat `docs/architecture/3d_model_pipeline_canonical_decision_record_v1.md` as authoritative for canonical human anatomy, rig, coordinate, naming, morphology, surface, deformation, and registration requirements.

The creature/interaction architecture record remains downstream requirements only. It may expose missing canonical capability but cannot silently redefine `human_base`.

The accepted M01 implementation is the executable data-contract foundation. M02 must use it rather than create parallel types or a second canonical representation.

If implementation exposes a conflict, ambiguity, or missing structural decision:

1. stop at the affected boundary;
2. identify the exact hierarchy/ID/transform/record decision;
3. explain why the current canonical record is insufficient;
4. propose the smallest viable alternatives;
5. request owner review;
6. do **not** silently choose a new rig architecture.

`LOCKED`, `DEFERRED`, `EXCLUDED`, and `OPEN/TUNING` statuses remain binding.

---

## 3. M01 and M01.5 baseline that M02 must preserve

The accepted M01 goldens must remain unchanged unless an explicit reviewed M01 regression fix is authorized.

### Prompt 2C focused fixture SHA-256

`2855fc11c0f8a1e5698af253c1a89eeb07483e5879556094ea4b6f29149b784b`

### Phase F canonical fixture

- size: `12,022` bytes;
- final byte: `}`;
- no trailing newline;
- SHA-256: `b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d`.

M01.5 reorganized test execution without changing M01 contracts or reducing coverage. Use the current tiers:

```text
zig build test -j1
zig build check -j1
zig build test-deterministic -Dtest-filter='<text>' -j1
zig build test-full -j1
zig build test-stress -j1
zig build verify -j1
```

M02 must preserve the M01.5 classification and retirement policy. Do not delete, weaken, shorten, or retire meaningful existing coverage merely because M02 introduces a newer canonical human structure.

---

## 4. Primary objective

Create one canonical asset definition conceptually equivalent to:

```text
human_base
├── canonical identity/version
├── locked coordinate contract
├── human component tree
├── canonical human skeleton
├── rest-pose local transforms
├── joints / mobility profile
├── animator-facing structural controls
├── anchors / sockets / mounts
├── semantic structural regions / surfaces
├── stable body landmarks
├── shared seam identities
├── interaction sites / effectors
├── structural collision-proxy descriptors
├── neutral material references/instances as required
├── visibility / optional-module state
└── deterministic canonical source identity
```

The asset must parse through the real M01 authoring parser, validate fail-closed, normalize deterministically, serialize canonically, and produce a stable source-definition hash.

---

## 5. Explicit non-goals

Do **not** implement in M02:

- production continuous body mesh;
- quad topology or edge-loop authoring;
- subdivision or deterministic triangulation of a real human mesh;
- skin weights / weight painting / skinning execution;
- morph-target vertex deltas or final morphology sculpting;
- corrective-shape vertex deltas;
- soft-tissue or contact-deformation solvers;
- garment fitting, garment authoring, or clothing simulation;
- animation playback, IK solving, procedural grasp solving, or choreography execution;
- UV unwrapping of a real human mesh;
- source texture atlas or compiled 2D atlas generation;
- rasterization or representation cameras;
- replacement of the current 2D renderer;
- live runtime 3D;
- full body-editor UI;
- full mass/center-of-mass/inertia simulation;
- final tuned joint limits, body proportions, collision dimensions, or material values.

M02 may instantiate the **records, IDs, references, provisional values, and structural hooks** required by later milestones.

---

## 6. Canonical `human_base` identity and neutral state

The M02 asset must encode the locked neutral reference:

- asset ID: `human_base`;
- height: `1.8288 m` / 6 ft;
- bind/rest pose: A-pose;
- canonical forward: `+Z`;
- origin centered between the feet on the ground;
- ground: `Y = 0`;
- right-handed coordinates;
- `+X` world/viewer right, `+Y` up, `+Z` toward camera;
- canonical numeric type `f32`;
- local parent-relative canonical transforms only;
- symmetric human-realistic neutral morphology;
- moderate/neutral muscularity;
- moderate-low body fat;
- no exaggerated definition;
- minimal/default breast-tissue morphology;
- shared perineal foundation;
- optional external genital modules disabled in base configuration;
- healthy ordinary eye/teeth/nail/skin semantics;
- no hairstyle, facial hair, body-hair implementation, clothing, jewelry, or accessories;
- neutral temporary/physiological state.

Do not encode male and female as separate rigs.

---

## 7. OPEN/TUNING policy for M02 numeric data

M02 must choose some concrete values that the canonical record intentionally leaves `OPEN/TUNING`, including exact A-pose angles, neutral proportions, mobility ranges, local rest translations, and possibly provisional proxy/material numbers.

M02 is authorized to introduce **provisional asset-level values** only where required to create a coherent first `human_base`.

Rules:

1. Values live in the `human_base` asset/profile, not generic engine constants.
2. They remain explicitly `OPEN/TUNING`.
3. They are centralized and inspectable.
4. They are not described as universal human anatomical laws.
5. The M02 review package lists them.
6. Later mesh/editor evidence may revise them without changing architecture.
7. A choice that changes hierarchy, topology, semantic meaning, or ownership is **not tuning** and must be owner-reviewed.

M02's goal is structural coherence and traceability, not final anatomical perfection.

---

## 8. Required pre-implementation structural manifest

Before final `human_base` authoring, produce a deterministic structural manifest proposal containing:

- component IDs + parents;
- bone IDs + parents;
- `deforms_mesh` classification;
- joint IDs + parent/child bones;
- animator-control IDs + driven targets;
- anchor IDs + drivers;
- socket IDs + accepted targets;
- mount anchors + attachments;
- structural region/surface IDs;
- landmark IDs;
- shared seam IDs;
- interaction-site IDs;
- effector IDs;
- optional module IDs/default state;
- collision-proxy IDs/types/owners if M02 instantiates them.

The manifest must distinguish:

- directly locked counts/hierarchy;
- implementation naming that merely applies the locked naming convention;
- `OPEN/TUNING` numeric data;
- actual structural ambiguities needing owner review.

Explicitly check ambiguous areas such as clavicle/spine attachment, twist-bone chain organization, any “deformation region/bone” wording that could map to a bone vs control, and disabled optional-module bone ownership.

Do not bury these decisions inside generated JSON.

---

## 9. Human component ownership tree

Instantiate one single-parent ownership tree rooted at `body`.

At minimum:

```text
body
├── head
├── torso
├── arm_left_01
├── arm_right_01
└── pelvis
    ├── leg_left_01
    └── leg_right_01
```

Expand structurally where useful, for example hands under arms, feet under legs, eyes/ears/mouth internals under head, and optional anatomy modules under their canonical owner.

Requirements:

- exactly one `body` root;
- single-parent ownership;
- stable immutable IDs;
- anatomical left/right semantics;
- explicit optionality;
- references by ID, never array index;
- no runtime owner tokens or renderer-layer authority;
- no duplicated male/female component trees.

M03 must be able to attach geometry without renaming M02 structural identities.

---

## 10. Canonical human skeleton

M02 must instantiate the locked human rig using M01 records.

### 10.1 Root, spine, neck, head

```text
skeleton_root
└── pelvis
    └── 7-bone spine chain
        └── 3-bone neck chain
            └── head
                └── jaw
```

Requirements:

- exactly one `skeleton_root`;
- pelvis under root;
- exactly 7 spine deformation bones;
- exactly 3 neck deformation bones;
- distinct head/skull deformation bone;
- distinct child jaw deformation bone;
- local rest transforms only.

Instantiate 5 spine controls: 4 regional + 1 whole-spine curve/global concept. Do not implement spline IK yet.

### 10.2 Shoulder girdle and arms

Per side structurally represent:

- clavicle;
- scapula;
- upper-arm main deformation bone;
- 2 upper-arm twist deformation bones;
- forearm main deformation bone;
- 2 forearm twist deformation bones;
- hand/root.

Include mirror references and structural controls such as hand IK target, elbow pole/direction control, and required FK controls. No IK solver in M02.

### 10.3 Hands and fingers

Thumb:

- metacarpal;
- proximal;
- distal.

Index/middle/ring/little:

- metacarpal;
- proximal;
- middle;
- distal.

Instantiate structural control/anchor identities for whole-hand open/close, curl/spread, palm cup, thumb opposition, pinch/grip, palm center, grip anchor, palm heel, thumb pad, and required fingertip/finger-pad anchors.

No procedural grasp solver.

### 10.4 Pelvis and legs

Per side:

- hip connection;
- thigh/femur main deformation bone;
- 2 thigh twist deformation bones;
- knee joint;
- lower-leg main deformation bone;
- 2 lower-leg twist deformation bones;
- ankle;
- foot.

Include foot IK target, knee pole/direction control, and required FK controls. No IK/grounding solver.

### 10.5 Feet and toes

Per foot:

- big toe: 2 deformation bones;
- each other toe: 3 deformation bones;
- structural heel/midfoot/forefoot references as approved by the manifest.

Instantiate ground-contact semantic anchors/sites for heel, inner/outer edge, ball, big-toe pad, and other toe pads.

### 10.6 Eyes, eyelids, ears

Default human:

- 2 eye components;
- 1 eye-socket anchor per eye;
- 1 eyeball deformation bone per eye;
- shared look-target control by default;
- per-eye override hooks;
- optional primary eye group = left/right pair.

Eyelids preserve default inner/center/outer upper and lower regions, with exact bone/control representation resolved by the approved structural manifest where wording remains implementation-flexible.

Ears: one ear-root anchor + one ear-root deformation bone per side.

No gaze/blink solver.

### 10.7 Mouth internals and tongue

Represent upper teeth, upper gums/palate, lower teeth, lower gums, mouth cavity, and tongue.

Tongue:

- 4 shared tongue deformation bones;
- explicit branch point;
- default human = one unbranched terminal tip.

No detailed tongue solver.

### 10.8 Optional genital modules

Base `human_base` keeps optional external genital modules disabled.

Locked support:

- max 1 anus module;
- max 1 vulva/vaginal-canal module;
- schema supports 0..N penis modules;
- initial human implementation uses 0 or 1 unbranched penis;
- enabled penis module structurally uses 7 shaft deformation bones.

Do not implement genital morphology, physiological deformation, contact solving, fluids, or exotic branching physics.

If disabled module-specific bones cannot be represented without duplicating the shared base rig, stop for owner review rather than create a second human skeleton.

---

## 11. Canonical rest transforms and A-pose measurements

Assign explicit local rest transforms in meters to the approved hierarchy.

Requirements:

- local/parent-relative authority only;
- derived global affine transforms are transient;
- local point semantics remain scale → rotate → translate;
- hierarchy composition remains `M_global = M_parent * M_local`;
- right-handed active quaternion rotations;
- exact left/right structural mirroring in neutral `human_base`;
- centerline structural elements stay on `X = 0` unless explicitly justified;
- foot-contact references align to `Y = 0`;
- canonical total height resolves to `1.8288 m`;
- model faces `+Z`;
- A-pose is coherent and mechanically valid.

Generate a deterministic measurement report containing at least:

- total height;
- shoulder breadth;
- hip breadth;
- arm span;
- torso length;
- leg length;
- upper-arm / forearm lengths;
- thigh / lower-leg lengths;
- hand length;
- foot length;
- head height;
- key left/right joint coordinates.

These are provisional M02 `OPEN/TUNING` measurements unless already locked.

---

## 12. Joint and mobility instantiation

Create real joint records using the M01 joint schema.

Requirements:

- exact human ROM values remain `OPEN/TUNING`;
- provisional values are centralized asset/profile data;
- paired joints mirror where neutral anatomy warrants;
- range ordering and semantics validate;
- joint ranges do not substitute for collision checking;
- no collision solver in M02.

Final ROM tuning belongs to later posing/editor validation.

---

## 13. Animator-facing structural controls

Instantiate the structural controls required by the real rig, including as applicable:

- 5 spine controls;
- pelvis/root controls;
- head/jaw controls;
- arm FK + hand IK + elbow pole controls;
- hand/finger structural controls;
- leg FK + foot IK + knee pole controls;
- foot/toe structural controls;
- shared eye look target + per-eye override hooks;
- eyelid/blink control concepts;
- tongue curve/control hooks;
- optional-module structural controls where required.

Requirements:

- stable IDs;
- explicit drive relationships;
- explicit mirror controls;
- explicit control space;
- no solver implementation;
- no hidden renderer mutation.

---

## 14. Stable human landmarks

Instantiate canonical landmarks sufficient for measurement, future clothing, camera/registration, and interaction.

At minimum:

- head top;
- chin;
- face center/reference;
- shoulder left/right;
- chest/sternum center reference;
- navel reference;
- waist reference;
- pelvis/hip references;
- elbow left/right;
- wrist left/right;
- palm centers;
- required fingertip references;
- hip left/right;
- knee left/right;
- ankle left/right;
- heel left/right;
- toe-tip left/right.

Requirements:

- stable IDs and explicit owners;
- deterministic local/reference transforms;
- bilateral landmarks mirror in neutral base;
- midline landmarks stay on center plane;
- M03 can attach them to real geometry without renaming.

---

## 15. Shared seam and boundary identities

M02 does not create mesh rings, but must instantiate stable semantic boundary IDs for later M03 geometry.

At minimum:

- torso ↔ pelvis;
- torso ↔ neck;
- neck ↔ head where useful;
- shoulder/torso ↔ arm;
- pelvis ↔ thigh;
- wrist ↔ hand;
- ankle ↔ foot.

Rules:

- one shared seam identity is authoritative for both later sides;
- no unrelated duplicate seam definitions;
- no atlas/pixel-space seam values;
- no fake vertex-ring membership before the mesh exists.

---

## 16. Structural semantic regions and surfaces

Instantiate the semantic **identity inventory** required for M02 while leaving real mesh membership for M03.

Cover regions needed by components, landmarks, seams, anchors, interaction sites, later clothing coverage, morphology, and registration, including head/face, neck, torso, limb regions, hands/feet, eye/mouth regions, breast/nipple/areola semantics, pelvis/glute/perineal regions, and optional anatomy semantics where structurally required.

Requirements:

- stable `surface_id` / `region_id`;
- explicit owner;
- material-instance references where required by M01;
- no fabricated vertex membership;
- no fabricated UV or atlas coordinates.

---

## 17. Anchors, sockets, mount anchors, attachments

Instantiate real human structural anchors, including as applicable:

### Head

- eye socket anchors;
- ear-root anchors;
- facial perception fallback anchor;
- already-locked unambiguous hair/headwear structural anchors.

### Upper body

- shoulder/clavicle references;
- palm/grip anchors;
- fingertip/finger-pad anchors.

### Pelvis/perineum

At minimum:

- anterior genital anchor;
- perineal center anchor;
- posterior anal anchor;
- left/right groin anchors;
- pubic center anchor.

### Lower body

- heel/ball/toe contact anchors.

Rules:

- every socket references an anchor;
- mount anchors remain separate;
- attachments align parent socket ↔ child mount anchor;
- no duplicated transform authority;
- specific piercing-location authoring remains deferred.

---

## 18. Interaction sites and effectors

Instantiate structural semantic interaction records without contact solving.

Effectors should include at least left/right hands and feet, plus other structurally justified effectors.

Sites should include common structural targets such as shoulder left/right, hip left/right, waist, upper back, chest/torso support region, palms, glutes, head/face reference regions, foot ground-contact sites, and perineal/anatomy sites where structurally required.

Each site may carry owner, preferred anchor, semantic tags, approach/orientation hooks, and capacity/occupancy hooks.

Do not invent detailed contact volumes or penetration deformation in M02.

---

## 19. Optional modules and male/female test configurations

`human_base` remains the shared neutral source.

Do not create a separate male or female skeleton.

The canonical record defines later derived configurations:

```text
human_base
├── male_typical_test
└── female_typical_test
```

M02 may prove **structural configuration enablement** only if the existing M01 model can do so cleanly without introducing a separate preset architecture or duplicating the rig.

If not, explicitly defer those derived profiles to the later morphology/configuration milestone.

---

## 20. Neutral material identities/instances

Instantiate the neutral material definitions/instances required for semantic surface references:

- skin;
- lips;
- nails;
- tooth enamel;
- gums;
- tongue;
- sclera;
- iris;
- pupil;
- cornea/eye surface.

Rules:

- use M01 definition/instance separation;
- preserve linear-sRGB RGBA contract;
- temporary physiological state remains separate;
- no final art tuning;
- any numeric values are provisional `OPEN/TUNING`;
- no textures/UV maps in M02.

---

## 21. Structural collision-proxy descriptors

The canonical record requires collision proxies in the eventual resolved geometry snapshot.

M02 should instantiate the **structural proxy contract** only if it can do so additively and cleanly on M01.

Preferred scope:

- stable proxy ID;
- owner/driver bone or anchor;
- primitive class: capsule/sphere/box where practical;
- purpose classification (broad movement vs future close-contact hook);
- local transform;
- provisional dimensions if required;
- semantic region association.

No collision solver, physics response, or mesh fitting.

Exact dimensions remain `OPEN/TUNING`.

If M01 lacks an appropriate proxy record and adding one materially widens the schema, stop for owner review before extending canonical model data.

---

## 22. Human-specific structural validation

Add human-specific validation without weakening generic M01 validators.

### Identity/hierarchy

Validate:

- exactly one `body` root;
- exactly one `skeleton_root`;
- correct pelvis/root relationship;
- no cycles;
- required locked structural IDs exist;
- no duplicate/wrong-type references.

### Locked counts

Automatically validate explicit locked counts, including:

- 7 spine deformation bones;
- 3 neck deformation bones;
- 5 spine controls;
- 2 upper-arm twist bones per arm;
- 2 forearm twist bones per arm;
- 2 thigh twist bones per leg;
- 2 lower-leg twist bones per leg;
- thumb 3-bone chain including metacarpal;
- each other finger 4-bone chain including metacarpal;
- big toe 2 deformation bones;
- each other toe 3 deformation bones;
- 4 shared tongue deformation bones;
- default human eye count = 2;
- one eyeball deformation bone per eye;
- one ear-root deformation bone per ear;
- optional-module multiplicity where instantiated.

### Symmetry

For neutral `human_base`:

- paired components mirror semantically;
- paired rest transforms mirror within documented numerical tolerance;
- paired landmarks/anchors mirror;
- paired joint/control identities cross-link correctly;
- no accidental asymmetry is fabricated.

### Coordinate/rest-pose invariants

- forward = `+Z`;
- ground = `Y = 0`;
- origin between feet;
- required foot-contact references on ground;
- total height = `1.8288 m`;
- midline landmarks on center plane;
- global transforms derive deterministically from local source transforms.

### References/semantics

Validate required anchor owners, socket→anchor references, mounts/attachments, landmarks, seams, sites/effectors, material references, and absence of fake mesh/UV/atlas data.

### Shared-source rule

Validate that no separate male/female base rig is introduced and optional-module configuration does not mutate unrelated shared structural IDs.

---

## 23. M02 invalid fixtures / negative tests

Create targeted human-specific invalid fixtures or parser-backed mutations where practical, including at least:

1. missing `skeleton_root`;
2. second skeleton root;
3. wrong pelvis parent;
4. only 6 spine bones;
5. only 2 neck bones;
6. wrong arm twist-bone count;
7. wrong leg twist-bone count;
8. malformed finger chain;
9. malformed toe chain;
10. mirror mismatch beyond test tolerance;
11. foot-contact landmark off `Y = 0`;
12. canonical height mismatch;
13. missing required landmark;
14. missing required seam;
15. socket referencing wrong/missing anchor;
16. interaction site with missing owner;
17. invalid optional-module multiplicity where represented;
18. duplicated/separate male/female base rig if configuration proof is in scope.

Each fixture should fail with a precise stable diagnostic and no silent repair.

---

## 24. Deterministic `human_base` source fixture and golden identity

Add a real authoring fixture for the structural human asset at a repository-appropriate path approved by M02 reconnaissance.

Requirements:

- readable authoring source;
- deterministic normalized canonical output;
- committed canonical golden or equivalent reviewed evidence;
- new `human_base` source-definition SHA-256;
- parse → normalize → serialize → parse → normalize identity;
- repeat-build byte/hash identity;
- useful equivalent-input identity proof;
- mutation sensitivity;
- no trailing newline in canonical golden;
- tests never silently regenerate accepted goldens.

The M02 hash is a **new asset golden**. It does not replace or alter the two M01 goldens.

---

## 25. Structural debug/evidence tooling

M02 does not require the full editor, but must provide deterministic offline reports for:

- component tree;
- skeleton tree;
- joint list;
- control → driven-target trace;
- local + derived global transforms for selected IDs;
- parent chain and mirror partner;
- body measurement report;
- landmark inventory/coordinates;
- seam inventory;
- anchor/socket inventory;
- interaction-site/effector inventory;
- optional-module state;
- collision-proxy inventory if in scope.

A CLI/offline report is sufficient. Do not add a renderer dependency to visualize M02.

---

## 26. Testing policy after M01.5

### Normal edit-time loop

Use focused M02 tests plus:

```text
zig build test -j1
```

when appropriate.

### Fast pre-review gate

```text
zig build check -j1
```

### Targeted deterministic iteration

```text
zig build test-deterministic -Dtest-filter='<text>' -j1
```

### Full non-stress regression

```text
zig build test-full -j1
```

at major owner-review gates, not every tiny edit.

### Stress

Do not create arbitrary new endurance loops merely to increase counts. Existing stress coverage remains available through:

```text
zig build test-stress -j1
```

### Final M02 acceptance

Run:

```text
zig build verify -j1
```

Also run the normal host Debug build if the managed environment again hits the accepted cache/manifest limitation.

M02 is structural/offline and should not claim GPU/manual visual realism acceptance before the mesh exists.

---

## 27. Test-retirement rule

Respect the M01.5 retirement policy.

Do not delete or mark existing compatibility/runtime paths obsolete merely because M02 now contains canonical human structure. The current production runtime remains 2D.

For M02, expected retired production/runtime tests = **zero**, unless explicitly owner-approved.

---

## 28. Recommended implementation sequence

### Phase A — repository/M01 handoff reconnaissance

Read the start-here doc, canonical ADR, M01 brief, M01 review package, `docs/TESTING.md`, M01.5 report if retained, and downstream ADR.

Inspect the real M01 API and propose the structural manifest from section 8.

**No final structural source authoring before owner approval of unresolved hierarchy ambiguities.**

### Phase B — `human_base` identity + component/semantic inventory

Implement:

- asset identity/version;
- neutral coordinate/default state;
- component tree;
- structural region/surface inventory;
- optional-module declarations/default disablement;
- neutral material identities/instances required by schema.

### Phase C — skeleton + joints + controls + rest transforms

Implement:

- approved bone hierarchy;
- provisional local A-pose rest transforms;
- joint records + provisional mobility profile;
- structural controls + mirror references;
- deterministic measurement report;
- count/symmetry/coordinate validation.

### Phase D — anchors + landmarks + seams + interaction sites + proxy descriptors

Implement:

- anchors/sockets/mount anchors;
- body landmarks;
- shared seam identities;
- interaction sites/effectors;
- structural proxy descriptors if approved/in-scope.

### Phase E — deterministic asset fixture + negative fixtures + golden evidence

Implement:

- readable `human_base` fixture;
- canonical normalized golden;
- M02 source SHA-256;
- human-specific invalid fixtures;
- determinism/regression tests;
- offline structural reports.

Preserve M01 goldens exactly.

### Phase F — M02 audit/review package

Audit the brief line by line. Fix only in-scope gaps.

Run focused M02 tests, `test`, `check`, `test-full`, relevant deterministic tests, `verify`, and host Debug build if required.

Produce:

`docs/implementation/3d_pipeline_m02_review_package.md`

Then stop for owner acceptance.

---

## 29. Required review package

At M02 completion provide:

### Implemented

- files/modules/assets added or changed;
- actual `human_base` structural source path;
- component/bone/joint/control counts;
- anchors/landmarks/seams/sites instantiated;
- optional-module handling;
- proxy descriptors if implemented.

### Automated tests

Report focused M02 tests, M01 regression/golden status, fast `test`, `check`, `test-full`, `verify`, invalid fixture results, and determinism results.

### Empirical structural evidence

Include:

- normalized `human_base` canonical source;
- M02 source SHA-256;
- component-tree summary;
- complete skeleton-tree summary;
- locked count verification;
- sample local/global transform derivations;
- symmetry evidence;
- body measurement report;
- landmark coordinates;
- seam inventory;
- anchor/socket inventory;
- interaction-site inventory;
- optional-module state;
- representative diagnostics.

### Decisions assumed

Preferred result: `None`.

### OPEN/TUNING values

List all provisional rest measurements, A-pose angles, mobility ranges, collision dimensions, material numeric values, and other empirical tuning data.

### Known limitations

Explicitly state that M02 still has no production mesh, skinning, morphology sculpting, correctives, real-geometry UVs, soft tissue, animation solving, garments, or 2D export.

### M03 readiness

State whether M03 can attach the continuous human mesh without renaming core IDs, replacing the skeleton, changing canonical hierarchy, inventing new landmark/seam identity, or creating renderer-specific authority.

---

## 30. Stop / escalation conditions

Stop for owner review if:

- M01 cannot represent the approved hierarchy without material redesign;
- locked bone/control counts cannot map cleanly to current records;
- exact parent hierarchy is ambiguous in a way that changes rig architecture;
- M02 would require a second male/female human rig;
- disabled optional modules cannot be represented without corrupting the shared base;
- a required surface/seam/landmark must be faked with renderer coordinates;
- canonical source would need global transforms as a second authority;
- M02 would require a real mesh/UV/skin-weight implementation to continue;
- canonical-model code begins depending on renderer/game modules;
- an `OPEN/TUNING` value is being promoted to locked architecture without owner review;
- an M01 golden changes unexpectedly;
- tests must be weakened/skipped to pass;
- active runtime tests are proposed for retirement merely because M02 exists.

---

## 31. Definition of done

M02 is complete only when:

1. `human_base` exists as a real canonical structural asset using M01.
2. Locked coordinate/origin/height/A-pose contract is preserved.
3. Single-parent human component tree is explicit and validated.
4. Approved complete human skeleton is explicit and validated.
5. Locked structural bone/control counts are automatically tested.
6. Local rest transforms are deterministic and global transforms derive reproducibly.
7. Neutral left/right structure is measurably mirrored.
8. Required joint/control records exist and validate.
9. Required anchors/sockets/mounts exist and validate.
10. Stable measurement landmarks exist and produce a deterministic report.
11. Shared seam/boundary identities exist without fake mesh/atlas coordinates.
12. Structural surface/region identities exist without pretending mesh membership is complete.
13. Required interaction sites/effectors exist and validate.
14. Optional anatomy is disabled in `human_base` without separate male/female rigs.
15. Structural collision-proxy handling is cleanly instantiated or owner-approved as deferred.
16. Readable `human_base` input normalizes/serializes/hashes deterministically.
17. M02 has an accepted canonical golden/hash and M01 goldens remain unchanged.
18. Invalid human fixtures fail with precise stable diagnostics and no silent repair.
19. Canonical subsystem remains renderer/runtime independent.
20. M01.5 fast/full/stress/verify structure remains intact.
21. `zig build verify -j1` passes, subject only to already accepted infrastructure limitations with equivalent host evidence.
22. M02 review package is complete.
23. No production human mesh, skinning, morphology sculpting, garment, atlas, or M03 work is pulled forward.

**Owner review is required before M03 begins.**

---

## 32. M03 handoff boundary

M03 begins only after M02 owner acceptance.

M03 creates the actual **continuous canonical human mesh and surface foundation**:

- one continuous main body mesh wherever practical;
- quad-oriented stable topology;
- anatomy/deformation-driven edge flow;
- deterministic subdivision/triangulation strategy;
- actual semantic surface membership;
- actual shared seam/ring geometry;
- canonical surface-coordinate / UV foundation;
- neutral material assignment onto real geometry.

M03 must consume the M02 structural IDs, skeleton, anchors, landmarks, seams, and semantic identities rather than redefine them.

M02 succeeds when the future mesh has a stable structural skeleton to attach to and every important structural value is inspectable rather than guessed.
