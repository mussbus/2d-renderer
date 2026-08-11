# Engineering Brief — 3D Model Pipeline M03: Canonical Human Mesh & Surface Foundation

**Status:** Prompts 2A and 2B owner-approved; Prompt 2C remains open; Prompt 2C-R4 final neutral shared-human candidate awaits owner acceptance
**Milestone:** M03  
**Prerequisites:** M01, M01.5, M02, and M02.5 owner-accepted  
**Accepted structural source:** `assets/canonical_model/human_base/human_base.authoring.json`  
**Canonical architecture authority:** `docs/architecture/3d_model_pipeline_canonical_decision_record_v1.md`  
**Testing authority:** `docs/TESTING.md`  
**Prior evidence:** `docs/implementation/3d_pipeline_m02_review_package.md` and `docs/implementation/3d_pipeline_m02_5_review_package.md`  
**Next milestone:** M04 — Skinning & Morphology Foundation  
**Owner-review gate:** Required before M04  
**Runtime boundary:** Production runtime remains 2D-only. M03 is offline canonical geometry authoring and validation.

---

## 1. Purpose

M03 creates the first real canonical human **geometry**.

M01 defined the canonical data language. M02 defined the canonical human structure. M02.5 enforced one file-backed structural authority and one supported consumption path. M03 now attaches real topology and real surface membership to that accepted structure.

The central outcome is:

> A deterministic, file-backed, renderer-independent canonical human geometry asset exists and is structurally bound to the accepted `human_base` components, skeleton, materials, regions, surfaces, anchors, landmarks, seams, interaction identities, and optional anatomy architecture.

M03 must create the mesh/surface foundation that later milestones can skin, morph, pose, deform, clothe, and compile to 2D without redefining the human.

M03 is **not** a skinning or morphology milestone.

---

## 2. Authority and precedence

Read and follow:

1. `docs/implementation/3d_pipeline_start_here.md`
2. `docs/architecture/3d_model_pipeline_canonical_decision_record_v1.md`
3. this M03 engineering brief
4. `docs/implementation/3d_pipeline_m02_review_package.md`
5. `docs/implementation/3d_pipeline_m02_5_review_package.md`
6. `docs/TESTING.md`
7. `docs/architecture/creature_interaction_architecture_decision_record_v3.md`

Authority rules:

- The canonical decision record owns canonical model architecture.
- The accepted M02 file-backed `human_base` owns human structural identity.
- This brief owns M03 implementation scope.
- The downstream interaction ADR is requirements/reference material only.
- Newer explicit owner decisions supersede older conflicting text.

If implementation requires changing an accepted M02 component ID, bone ID, hierarchy, anchor ID, landmark ID, seam ID, material identity, region/surface identity, or optional-module architecture, **STOP FOR OWNER REVIEW** unless the change is a proven M02 defect.

Do not rename structural identities merely to make mesh implementation easier.

---

## 3. Accepted baseline M03 must preserve

### 3.1 Sole structural authority

The sole authoritative structural human source is:

`assets/canonical_model/human_base/human_base.authoring.json`

M03 must consume it through the accepted file-backed:

`load → parse → validate → normalize`

path established by M02.5.

M03 must not use as structural source authority:

- `human_base.canonical.json`;
- `human_base.structural_report.txt`;
- hashes or traces;
- removed/reconstructed Zig human arrays;
- current runtime 2D anatomy;
- current runtime humanoid skeleton;
- sprite registration data.

### 3.2 Accepted M02 structural identity

M02 canonical SHA-256:

`b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda`

M03 must not alter the M02 structural authoring file or canonical golden unless a separately reviewed M02 regression fix is required.

The current accepted M02 manifest contains 208 regions and 208 surfaces. These
are current manifest totals, not universal architecture constants.

### 3.2.1 Prompt 2A accepted checkpoint

Prompt 2A introduces the renderer-independent `src/canonical_geometry/` layer
with schema, parsing, validation, normalization, canonical JSON serialization,
separate source/control-topology/triangulation/neutral hashes, deterministic
quad triangulation, Catmull-Clark v1 level-one evaluation, and an explicit-limit
loader. Its tests use only tiny synthetic geometry while resolving structural
references through the accepted file-backed M02 loader.

Prompt 2A did not include production human geometry. Its generic architecture
is now owner-approved and remains the foundation consumed by Prompt 2B.

### 3.2.2 Prompt 2B candidate checkpoint

Prompt 2B creates the first production file-backed geometry authority at:

`assets/canonical_model/human_base/geometry/human_base_geometry.authoring.json`

The candidate contains the single continuous `human_base_main_body` scaffold,
real face semantics, all 11 M02 seam-loop bindings, all 35 landmark geometry
bindings, and the approved anus receiver closure face set/loop. It remains a
coarse scaffold: detailed deformation-critical edge flow is Prompt 2C work.
Separate eyes, oral meshes, teeth, tongue, nails, adult modules, final UVs,
collision proxies, weights, and morphs remain unimplemented under the accepted
prompt boundaries.

### 3.2.3 Prompt 2C review candidate checkpoint

Prompt 2C evolves the same authoritative file to topology revision 2; it does
not introduce another human mesh source. The current review candidate contains
11,506 stable vertices, 11,504 quads, 23,008 deterministic triangles, 39
critical-zone face sets, and 55 explicit topology loops covering eyes, lips,
breast roots, shoulders, elbows, wrists, every finger, glute/perineal zones,
knees, ankles, feet, and every toe. All Prompt 2B vertices remain allocated;
its 2,876 face IDs are retired and not reused.

The current offline evidence reports a closed connected manifold, zero
degenerate quads, zero non-manifold/boundary edges, zero detected non-adjacent
triangle intersections, exact locked height/ground, and 35 landmark bindings
under the proposed 0.10 m OPEN/TUNING Prompt 2C tolerance. Visible proportions,
local form, edge spacing, topology density, and chart/UV layout remain
OPEN/TUNING pending owner visual review. Prompt 2D and M04 have not started.

### 3.2.4 Prompt 2C-R1 targeted-refinement checkpoint

Prompt 2C-R1 advances the same file-backed authority to topology revision 3.
It preserves 11,506 stable vertex IDs, retires 218 face IDs without reuse, and
allocates 218 redirected replacement quads; the current topology remains
11,504 quads and 23,008 deterministic derived triangles. High-resolution
offline evidence is isolated under `evidence/prompt_2c_r1/`; Prompt 2B and the
original Prompt 2C packages remain unchanged historical evidence.

The R1 audit is fail-closed for topology integrity: one connected component,
no boundaries or non-manifold edges, no degenerate quads, and zero detected
non-adjacent triangle intersections. It does not claim visual acceptance. The
current candidate improves aggregate aspect-ratio counts and landmark median,
but still misses the owner guardrails in shoulder, foot/toe, lip-loop, and
landmark-registration evidence and remains blocked for further topology work.
Prompt 2D and M04 have not started.

### 3.2.5 Prompt 2C-T1 Blender authoring bridge checkpoint

T1 does not alter the R1 geometry authority or resume anatomy work. It pins
the portable Windows x64 Blender 4.5.9 LTS archive, isolates it under `.deps`,
and supplies a headless canonical JSON ↔ Blender working bridge. The `.blend`,
deterministic sidecar, candidate JSON, and validation report are ignored
derived working data. Candidate export is source-bound and fail-closed; stable
`VertexId`/`FaceId` values live in explicit attributes rather than Blender
indexes, while complex seam/set/binding data remains in a source-bound sidecar.

The no-op gate requires exact preservation of the R1 normalized geometry,
control topology, triangulation, neutral signature, stable ID sets, semantics,
seams, bindings, and allocation cursors. Canonical-to-Blender coordinates are
exactly `(Xc,Yc,Zc) -> (Xc,-Zc,Yc)` with the documented inverse. The bridge
also defines explicit UNALLOCATED state, deterministic cursor-based allocation,
retirement/non-reuse rules, and owner-reviewed candidate promotion. Detailed
commands and evidence are in
`docs/implementation/3d_pipeline_m03_blender_bridge.md`. Prompt 2D and M04
remain unauthorized.

### 3.2.6 Prompt 2C-T2 hm08 topology-seed qualification checkpoint

T2 does not alter or supersede the R1 geometry authority. It pins the official
MPFB2 `hm08` OBJ and its asset-license evidence, separates the closed visible
body from MakeHuman helpers, audits topology/anatomy/morphology capacity, and
constructs provisional feasibility mappings for every M02 region, surface,
seam, and landmark. The external OBJ, inspection `.blend`, and proposed reset
IDs remain non-authoritative; no external vertex or face has a canonical M03
stable ID.

The qualification finds hm08 materially more anatomy-driven and
deformation-ready than R1 while retaining explicit project work for semantic
remapping, surface channels, module receivers, and all accepted adult anatomy.
Adoption is a separate owner decision. Full provenance, metrics, mapping,
visual evidence, and the proposed topology-reset policy are in
`docs/implementation/3d_pipeline_m03_hm08_qualification.md`. Prompt 2C-R2,
Prompt 2D, and M04 remain blocked.

### 3.2.7 Prompt 2C-T3 HM08 topology-adoption checkpoint

T3 is the owner-authorized whole-topology reset. The file-backed canonical
geometry authority now contains only the pinned HM08 visible body at topology
compatibility 2.0.0/revision 4: 13,380 fresh version-scoped vertex IDs, 13,378
fresh face IDs/quads, cursors 13,380/13,378, and no claimed R1 correspondence.
Every face has accepted M02 surface/material/region data, all 11 M02 seams and
35 landmarks are rebound, deformation-critical face sets/loops are rebuilt,
and upstream UVs are retained as provisional data separate from provisional
canonical surface charts.

The closed connected symmetric topology has zero boundary/non-manifold/
degenerate faces and zero detected non-adjacent triangle intersections. Five
independent generation/validation runs and a Blender no-op round trip preserve
the T3 identities. The one-shot adoption generator was removed after promotion
so canonical JSON remains the only mesh authority. R1 evidence remains frozen
as `HISTORICAL_SUPERSEDED_M03_R1_CANDIDATE`. Full provenance, identities,
mapping, quality, and visual inventory are in
`docs/implementation/3d_pipeline_m03_hm08_adoption.md`. Prompt 2C-R3, Prompt
2D, and M04 have not started.

### 3.2.8 Prompt 2C-R3 HM08 neutral-human adaptation checkpoint

R3 uses the accepted canonical JSON → Blender → candidate JSON bridge to fit
the promoted HM08 topology-v2 body to the M02 A-pose and a neutral shared-human
shape. It changes positions only: topology compatibility remains 2.0.0,
revision 4, with 13,380 vertex IDs, 13,378 face IDs/quads, unchanged allocation
cursors, and unchanged control-topology/triangulation identities. Height is
exactly 1.8288 m, ground is Y=0, symmetry remains valid, and the closed
connected mesh has zero detected non-adjacent triangle intersections.

All 35 landmarks are now classified as surface correspondences or intentional
internal structural references rather than compared under one misleading
global tolerance. All 11 seams, semantic coverage, deformation face sets, and
provisional imported UVs remain intact. Persistent high-resolution views,
mobile sheets, T3-vs-R3 comparisons, quality metrics, and the OPEN/TUNING
inventory are in
`docs/implementation/3d_pipeline_m03_hm08_neutral_adaptation.md`. This is an
owner-review candidate, not Prompt 2C acceptance. Prompt 2D, Prompt 2E, and
M04 have not started.

### 3.2.9 Prompt 2C-R4 final neutral shared-human checkpoint

R4 preserves the accepted HM08 topology exactly and performs only symmetric
vertex-position edits. Topology compatibility remains 2.0.0/revision 4 with
13,380 vertices, 13,378 quads, unchanged stable IDs/cursors, and unchanged
control-topology and triangulation identities. The adaptation reduces R3's
female-coded silhouette by broadening the shoulder surface and waist,
moderating external hips, glute projection, upper-thigh fullness, and visible
breast projection, while retaining the accepted anatomical topology.

The candidate remains exactly 1.8288 m high on ground Y=0, closed, connected,
manifold, symmetric, and free of detected non-adjacent triangle intersections.
All 11 seam bindings and 35 landmark bindings remain intact, with the accepted
18 surface/17 internal classification. Complete identities, measurements,
quality metrics, mobile sheets, and R3-vs-R4 comparisons are in
`docs/implementation/3d_pipeline_m03_final_neutral_adaptation.md`. This remains
an owner-review candidate, not Prompt 2C acceptance. Prompt 2D, Prompt 2E, and
M04 have not started.

### 3.3 Accepted M01 regression identities

Prompt 2C focused fixture:

`2855fc11c0f8a1e5698af253c1a89eeb07483e5879556094ea4b6f29149b784b`

Phase F fixture:

`b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d`

These remain immutable regression contracts.

### 3.4 Structural contracts

M03 inherits:

- meters and `f32`;
- right-handed coordinates;
- `+X` world/viewer right;
- `+Y` up;
- `+Z` toward camera;
- human faces `+Z`;
- ground `Y=0`;
- origin centered between feet;
- canonical height exactly `1.8288 m`;
- A-pose;
- local parent-relative structural TRS authority;
- stable snake-case IDs;
- explicit anatomical left/right;
- one shared human structure;
- optional module architecture;
- canonical joint angles in radians;
- deterministic normalization/hashing.

---

## 4. Primary objective

M03 must produce a canonical geometry package conceptually containing:

```text
human_base_geometry
├── geometry identity/version
├── structural-source compatibility identity
├── one continuous main-body control mesh where practical
├── separate canonical mesh components
├── optional anatomy module meshes
├── stable topology identities
├── semantic face/region/surface membership
├── real shared-seam edge/vertex bindings
├── canonical surface-coordinate data
├── independent texture-UV foundation
├── material assignments
├── geometry bindings for accepted landmarks/sites
├── deterministic triangulation
├── deterministic subdivision support
├── neutral collision-proxy foundation
├── geometry/topology hashes
├── structural/topological/geometry validators
└── deterministic inspection/export evidence
```

The geometry package references the accepted M02 structural asset instead of copying its structural records.

---

## 5. Explicit non-goals

Do **not** implement in M03:

- production skin weights;
- DQ or LBS skinning execution;
- per-vertex bone-weight authoring;
- morphology target deltas;
- body-shape slider execution;
- corrective-shape deltas;
- pose-space correctives;
- soft-tissue simulation;
- breast/glute/genital secondary-motion solving;
- contact or penetration deformation;
- arousal/erection deformation;
- physiological material-state execution;
- animation playback;
- IK/FK solving;
- grasp/gait/grounding/balance solving;
- garment fitting or garment geometry;
- head/facial/body hair geometry;
- atlas generation;
- 3D→2D rasterization;
- runtime 3D;
- replacement of the current 2D runtime;
- a full body/model editor UI.

M03 may create geometry contracts later systems require.

---

## 6. Geometry authority and source layout

M03 must preserve the M02.5 single-authority principle.

### 6.1 Separate structural and geometry authority

The M02 structural JSON remains authoritative for components, bones, joints, controls, anchors, landmarks, semantic IDs, materials, seams as semantic identities, sites/effectors, and optional-module state.

M03 creates a separate file-backed **geometry authority** referencing those IDs.

Do not embed a second copy of the complete M02 structure into the geometry source.

### 6.2 Preferred source organization

Prompt 1 reconnaissance must propose exact format and paths. Conceptually:

```text
assets/canonical_model/human_base/
  human_base.authoring.json
  geometry/
    human_base_geometry.authoring.<format>
    human_base_geometry.canonical.<format>
    ...derived evidence...
```

The exact authoring format is not yet locked.

The chosen format must:

- be file-backed;
- preserve canonical quad topology;
- be deterministic and inspectable;
- support stable topology identities;
- support semantic memberships;
- support canonical surface coordinates;
- support independent texture UVs;
- validate without the runtime renderer;
- avoid arbitrary fixed serialization buffers;
- not require Zig source code to reconstruct the mesh.

Do not use a canonical source format that inherently discards the quad control mesh.

A bootstrap generator may be used during implementation only if the committed file-backed geometry becomes the sole authority afterward. A generator must not remain a competing mesh authority.

---

## 7. Geometry schema/version boundary

M03 will likely need geometry-specific records not present in M01/M02.

Prompt 1 must recommend whether to use:

- a separate geometry schema/version; or
- a narrowly versioned additive canonical-model geometry extension.

Preferred direction:

> Keep geometry identity/versioning separate enough that M02 structural canonical bytes remain unchanged.

The geometry asset must include or reference at minimum:

- geometry schema/version;
- geometry asset/version;
- structural asset ID;
- expected M02 structural source hash/signature;
- topology identity/version;
- coordinate-system compatibility;
- mesh/topology records;
- surface/material bindings;
- seam bindings;
- geometry-binding metadata;
- collision proxies where implemented.

If exact versioning requires an owner decision, Prompt 1 must stop before implementation.

---

## 8. Stable topology identity

Later skin weights, morph targets, correctives, and caches will depend on stable topology.

M03 must establish:

- stable deterministic mesh IDs;
- stable deterministic vertex identity/order within each mesh;
- stable deterministic face identity/order;
- stable edge derivation;
- explicit topology revision/version;
- a topology identity/hash later morph/weight data can target;
- no dependence on hash-map iteration;
- no assumption that vertex reordering is harmless.

Prompt 1 must recommend the exact scoped identity model.

Possible valid approaches include stable numeric vertex/face IDs scoped to an immutable topology version, explicit stable IDs, or another deterministic equivalent.

Do not silently use transient array order without defining its stability contract.

---

## 9. Canonical mesh strategy

### 9.1 Main body

Create one continuous canonical main-body mesh wherever practical.

The main body should include continuous external geometry for:

- head/skull surface;
- ears;
- eyelids/face skin;
- lips/external mouth;
- neck;
- torso/chest;
- breast tissue;
- nipples/areolae;
- abdomen/navel/back/waist;
- pelvis/pubis/perineal base;
- glutes;
- shoulders/arms/hands/fingers;
- thighs/lower legs/feet/toes.

Do not cut the body into separate torso/limb meshes merely because M02 has component boundaries.

M02 seams such as torso↔arm remain semantic edge-loop boundaries on a continuous mesh unless an explicit modular geometry interface requires a real boundary.

### 9.2 Separate geometry components

Separate canonical geometry is appropriate for:

- eyeballs;
- corneal/eye-surface geometry where separate;
- teeth;
- gums/palate where separate;
- mouth cavity/interior;
- tongue;
- fingernails;
- toenails;
- optional genital/anatomy modules;
- future hair/accessories.

Hair is not implemented in M03.

### 9.3 Component ownership versus continuity

Mesh ownership and component identity must not force geometric disconnection.

A single mesh may span multiple accepted structural components. Semantic membership must preserve the relevant component/region identity.

---

## 10. Canonical quad control mesh

The canonical deforming/source topology is quad-oriented.

Requirements:

- stable quad topology;
- no n-gons in canonical deforming control meshes unless explicitly owner-approved;
- avoid triangles in deforming source topology unless a documented exceptional detail requires them;
- deterministic winding;
- no T-junctions;
- no zero-area faces;
- no duplicate faces;
- no invalid references;
- no unintended non-manifold edges;
- no accidental open boundaries;
- no disconnected pieces inside a mesh declared continuous;
- intentional boundaries explicitly classified.

Extraordinary vertices/poles are allowed where necessary, but should be kept away from high-deformation/contact-critical regions where practical.

Exact polygon/vertex counts remain `OPEN/TUNING`.

Do not optimize toward a fixed polygon budget before deformation evidence exists.

---

## 11. Anatomy-driven topology requirements

M03 topology must support later deformation rather than merely resemble a human at rest.

Provide appropriate edge flow/local density around at least:

### Face/head

- eye sockets and eyelids;
- forehead/brow transitions;
- nose bridge/tip/nostrils;
- cheeks/nasolabial region;
- lips/mouth corners;
- chin/jawline;
- ears;
- neck/jaw transition.

### Torso

- clavicle/shoulder;
- armpit;
- pectoral/breast region;
- nipple/areola;
- sternum/ribcage;
- abdomen/navel;
- waist/back/scapular region;
- lats/side torso;
- pelvis transition.

### Arms/hands

- shoulder;
- elbow;
- forearm twist region;
- wrist;
- palm;
- thumb base/opposition;
- knuckles;
- every finger joint;
- fingertip pads.

### Pelvis/lower body

- hip/groin crease;
- glute fold/cleft;
- perineal base;
- thigh/knee/calf;
- ankle/Achilles;
- heel/arch/forefoot;
- toe joints/pads.

### Adult anatomy/module interfaces

Topology must preserve later deformation capacity for:

- breast tissue;
- nipple/areola;
- anus/perianal/canal interface;
- vulvar/vaginal structures;
- penis;
- scrotum/testicles.

Do not defer all topology support for these structures to later milestones. M03 creates the geometry later systems will deform.

---

## 12. Adult anatomy geometry requirements

Adult anatomy must not be omitted because neutral `human_base` disables some modules.

### 12.1 Breasts, nipples, areolae

These remain part of the shared main-body mesh.

M03 must create:

- neutral minimal/default breast volume;
- distinct left/right breast topology;
- areola regions;
- nipple geometry;
- topology capable of later size/fullness/firmness/sag/deformation changes.

Do not create a separate female torso.

Exact visible dimensions remain `OPEN/TUNING`.

### 12.2 Anus module

The anus module is present/enabled in neutral `human_base`.

Provide geometry for:

- external opening;
- perianal region;
- short canal sufficient to establish the canonical interface.

No dilation/contact behavior yet.

### 12.3 Vulva / vaginal-canal module

Although disabled in neutral `human_base`, author its canonical geometry so later configurations can enable it without inventing a second human mesh.

Include support for:

- mons;
- labia majora L/R;
- labia minora L/R;
- clitoral region;
- urethral opening;
- vaginal opening;
- vestibule;
- initial canal geometry.

No arousal/contact deformation.

### 12.4 Penis module

Author geometry compatible with the accepted seven-shaft-bone optional rig.

Include at minimum:

- root/base interface;
- shaft;
- glans;
- urethral opening;
- topology support for later foreskin/morphology requirements where applicable;
- stable regions for later material/vascularity variation.

The neutral mesh is a provisional `OPEN/TUNING` reference, not a final soft/erect physiological state.

No erection solver.

### 12.5 Scrotum/testicles module

Author:

- scrotal skin geometry;
- left/right testicle geometry/structural surfaces as appropriate;
- stable interface to pelvis/perineal base.

No secondary-motion solver.

### 12.6 Module compatibility

Prompt 1 must explicitly propose the static geometry assembly/interface contract.

Do not silently assume:

- penis requires scrotum;
- scrotum requires penis;
- vulva implies a separate base human;
- module enablement changes shared skeleton IDs.

If additional stable interface seam IDs or replacement-surface IDs are required, Prompt 1 must list them for owner review before implementation.

---

## 13. Mouth, eyes, teeth, tongue, and nails

### Eyes

Author separate left/right eyeball geometry preserving semantic/material support for:

- sclera;
- iris;
- pupil;
- corneal/eye surface.

Eye rotational center must align with the accepted M02 eye socket/eyeball structure.

### Mouth internals

Create real geometry for:

- mouth cavity;
- upper gums/palate;
- lower gums;
- upper teeth;
- lower teeth;
- tongue.

Upper structures follow head structurally, lower follows jaw, and tongue uses its accepted structural chain later when skinning is added.

### Dentition

M02 contains full adult dentition semantic identities. M03 should create geometry capable of assigning those individual tooth regions rather than reducing the mouth to one undifferentiated block.

Exact tooth morphology remains `OPEN/TUNING`.

### Nails

Create separate nail geometry for all accepted fingernail/toenail components.

Nail geometry attaches at the distal digit and may extend beyond the tip.

No polish/dirt/damage state.

---

## 14. Optional-module interface geometry

M03 must make optional modules geometrically composable with the shared base.

The base geometry should contain stable receiving/interface regions.

Each module must define:

- attachment/interface identity;
- ordered boundary loop(s) where applicable;
- alignment to M02 structural anchors;
- surfaces replaced/occluded when enabled;
- compatibility metadata;
- no duplicate transform authority.

Validate enabled combinations for:

- no unintended cracks;
- no unintended overlap;
- matching interface orientation;
- deterministic assembly.

Exact interface tolerances are validation-only / `OPEN/TUNING` and must be reported separately.

Do not introduce sex-specific whole-body topology variants.

---

## 15. Semantic face/region/surface membership

M02 created semantic identities without pretending mesh membership existed. M03 must now bind real geometry to them.

Requirements:

- every rendered canonical face has explicit primary surface/material ownership;
- semantic region memberships are explicit;
- overlapping semantic regions are supported where meaningful;
- no face is silently unclassified;
- no unknown structural ID is introduced;
- ownership remains consistent with M02;
- optional-module faces use accepted module-owned regions/surfaces.

Examples of overlapping semantics include broad `torso` plus narrower `chest`, `breast_left` within torso, a hand plus digit-specific region, or pelvis plus perineal.

Prompt 1 must recommend whether membership is stored per face, per face range, or another deterministic representation.

---

## 16. Real shared-seam bindings

Bind M02 seam identities to actual topology.

Required seams include:

- torso ↔ pelvis;
- torso ↔ neck;
- neck ↔ head;
- torso ↔ arm L/R;
- wrist ↔ hand L/R;
- pelvis ↔ thigh L/R;
- ankle ↔ foot L/R.

For a continuous mesh, a seam can be a semantic boundary loop without a geometric gap.

Requirements:

- one authoritative seam ID;
- deterministic ordered loop;
- valid edges;
- no self-crossing loop;
- defined loop orientation;
- expected semantic sides;
- zero positional gap for continuous topology because the same vertices/edges are shared.

Additional optional-module interface seams require owner-reviewed M03 manifest decisions.

---

## 17. Canonical surface coordinates

M03 must implement canonical surface coordinates separately from texture UVs.

Purpose:

- persistent semantic location;
- decals/marks;
- interaction/contact localization;
- later 2D traceability;
- correspondence across morphs;
- seam/debug inspection.

Requirements:

- separate channel from texture UV;
- stable for accepted topology;
- deterministic;
- explicit surface/region context;
- finite and validated;
- survives later morphology without changing identity;
- does not use atlas adjacency as connectivity.

Prompt 1 must propose the exact representation.

A valid design may use `surface_id + local 2D canonical surface coordinate`, or another equivalent stable scheme.

Raw vertex index alone is not the complete semantic surface-coordinate contract.

---

## 18. Texture UV foundation

Create an independent texture-UV foundation.

Requirements:

- stable across future morphology;
- no forced left/right mirroring;
- supports identity-specific marks;
- unobtrusive seams where practical;
- consistent texel-density strategy;
- intentionally higher detail allocation for face, hands, feet, adult anatomy, and close-up-critical regions;
- deterministic serialization;
- explicit island/seam metadata where useful.

Texture UV and canonical surface coordinates may be numerically similar in places, but remain separate semantic channels.

M03 does not create final textures.

---

## 19. Material assignment

Bind M02 material instances to real geometry.

At minimum preserve:

- skin;
- lips;
- nails;
- tooth enamel;
- gums;
- oral mucosa;
- tongue;
- sclera;
- iris;
- pupil;
- cornea.

Do not create temporary wetness/arousal/injury state in base geometry.

Current numeric material appearance values remain `OPEN/TUNING`.

---

## 20. Geometry bindings for landmarks and sites

M02 landmarks remain structurally anchor-backed.

M03 may add geometry bindings describing where those references correspond to actual geometry.

The structural anchor remains authoritative for the structural frame.

A geometry binding must not silently move or replace it.

Possible binding data includes:

- mesh ID;
- face ID;
- local face coordinate/barycentric or equivalent;
- canonical surface coordinate;
- expected positional tolerance.

Prompt 1 must propose the exact representation.

Bind at least the landmarks/sites needed for head top, chin, face center, shoulders, sternum, navel, waist, hips, elbows, wrists, fingertips, knees, ankles, heels, toe tips, and interaction-critical locations.

---

## 21. Deterministic triangulation

The canonical source remains quad-oriented. Render/export triangulation is derived.

M03 must define one deterministic triangulation rule.

Requirements:

- same quad topology always yields the same triangles;
- winding preserved;
- diagonal selection deterministic;
- no hidden GPU/runtime decision;
- source quads remain authoritative;
- derived triangulation may have its own signature/hash.

If a fixed diagonal rule is inadequate, Prompt 1 may propose an explicit per-quad diagonal hint.

Do not silently change source topology because a runtime wants triangles.

---

## 22. Deterministic subdivision

Establish deterministic subdivision capability.

Requirements:

- base control mesh remains source authority;
- subdivision is derived;
- at least one deterministic subdivision level can be generated and validated;
- stable rule/version;
- no mutation of base topology;
- reproducible derived output;
- semantic/material/UV/canonical-surface data propagate deterministically.

Exact supported subdivision levels and future runtime use remain `OPEN/TUNING`.

---

## 23. Topology and geometry validation

### Generic checks

At minimum validate:

- finite vertex positions;
- valid face references;
- unique/stable topology identity rules;
- no duplicate face;
- no degenerate face;
- no zero-area derived triangle;
- consistent winding;
- valid edge incidence;
- intentional versus accidental boundaries;
- manifoldness where required;
- connectedness where declared;
- deterministic edge derivation;
- deterministic triangulation;
- deterministic subdivision;
- valid material refs;
- valid surface refs;
- valid semantic membership;
- valid canonical surface coordinates;
- valid texture UVs.

### Human-specific checks

At minimum validate:

- main-body connectedness;
- visible height exactly `1.8288 m`;
- ground contact at `Y=0`;
- neutral bilateral symmetry within documented geometry tolerance;
- accepted landmark bindings/proximity;
- seam loop existence/orientation/ownership;
- eye center alignment;
- mouth/jaw internal ownership;
- nail ownership/placement;
- optional-module interface compatibility;
- adult anatomy semantic coverage;
- no unexpected holes;
- no obvious interpenetration among accepted neutral assemblies;
- structural source compatibility/hash.

### Self-intersection

Add an offline self-intersection check for the neutral base and selected optional-module assemblies.

If expensive, place it in full/verify or a specialized geometry target, not the fast tier.

Do not weaken tests to accommodate poor geometry.

---

## 24. Collision-proxy foundation

Collision proxies were deferred from M02 until real geometry existed. M03 now has real geometry and must carry the requirement forward.

Introduce a renderer-independent neutral collision-proxy foundation supporting at minimum:

- stable proxy ID;
- owner component;
- driver bone or anchor;
- primitive type;
- local transform;
- dimensions;
- purpose/classification;
- semantic region association;
- structural/geometry compatibility identity.

Prefer simple primitives where practical:

- sphere;
- capsule;
- box.

Initial neutral coverage should include major regions such as head, torso, pelvis, upper/lower arms, hands where appropriate, thighs, lower legs, and feet.

Higher-fidelity close-contact proxies may remain later work.

Requirements:

- fit based on actual M03 geometry;
- exact dimensions `OPEN/TUNING`;
- no runtime physics solver;
- no reuse of current runtime 2D AABBs;
- later morphology can resize/reposition proxies;
- deterministic proxy evidence/report.

If proxy records require material schema redesign, stop for owner review.

---

## 25. Geometry measurements and bounds

Create deterministic geometry-derived measurements distinct from M02 rig-reference measurements.

Examples:

- visible total height;
- maximum shoulder/body width;
- chest width/depth;
- waist width/depth;
- hip/glute width/depth;
- head bounds;
- hand/foot bounds;
- limb bounds;
- breast geometry dimensions;
- optional-module geometry dimensions;
- overall/per-mesh AABBs;
- centroids where useful.

Use explicit geometry names such as `mesh_visible_shoulder_width` instead of silently reusing structural measurement names.

All geometry measurements except locked total height remain `OPEN/TUNING`.

---

## 26. Geometry quality profile

Exact polygon count is intentionally not locked.

Report at least:

- mesh count;
- vertex count per mesh;
- quad count per mesh;
- derived triangle count;
- connected components;
- boundary-loop count;
- extraordinary vertex count where measurable;
- edge-length distribution;
- quad aspect-ratio distribution;
- surface area by major region;
- UV island count;
- UV area/texel-density proxies;
- seam count/loop lengths;
- self-intersection count;
- non-manifold edge count;
- degenerate face count.

Zero required for accepted neutral geometry:

- invalid references;
- duplicate faces;
- degenerate faces;
- unintended non-manifold edges;
- unintended open boundaries;
- self-intersections in accepted neutral assemblies;
- missing required semantic membership.

Other metrics remain evidence/`OPEN_TUNING` unless owner-approved thresholds are added.

---

## 27. Visual inspection evidence

M03 is the first milestone where visual geometry quality matters.

Automated metrics are not enough.

Provide deterministic offline visual evidence without making canonical code depend on the runtime renderer.

Preferred derived evidence:

- OBJ or equivalent inspectable export;
- orthographic front/back/left/right/three-quarter views;
- wireframe views;
- flat or surface-ID shaded views.

Provide close-ups for:

- head/face;
- eyes/lids;
- hands/fingers;
- feet/toes;
- torso/breast/nipple/areola topology;
- pelvis/perineum;
- anus;
- optional vulva/vaginal module;
- optional penis;
- optional scrotum/testicles;
- mouth/teeth/tongue.

These artifacts are **derived review evidence**, never canonical source authority.

Manual owner visual review is required before final M03 acceptance.

Do not claim anatomical quality based only on test counts.

---

## 28. Neutral assembly profiles for validation

Validate at least:

### Base neutral

- shared main body;
- anus enabled;
- external genital modules disabled;
- required eyes/mouth/teeth/tongue/nails enabled.

### Vulva profile

- shared base;
- anus;
- vulva/vaginal-canal module enabled;
- penis/scrotum disabled.

### Penis + scrotum profile

- shared base;
- anus;
- penis enabled;
- scrotum/testicles enabled;
- vulva disabled.

Where architecture permits independent module enablement, validate it without forcing a sex package.

These are geometry assembly test profiles, not yet formal `male_typical_test` / `female_typical_test` morphology presets.

Do not duplicate the shared body mesh.

---

## 29. Deterministic geometry hashing

Establish deterministic identities for later dependency invalidation.

At minimum:

### Geometry source hash

Covers canonical M03 geometry source and compatibility metadata.

### Topology hash

Covers stable topology/connectivity/identity while excluding tunable positions where appropriate.

Later skin weights, morphs, and correctives must be able to declare the topology identity they target.

### Neutral geometry signature

May combine structural source identity, geometry source identity, topology identity, and geometry schema/compiler version.

Prompt 1 must propose exact hash boundaries before implementation.

Do not overload the M02 structural source hash to mean geometry identity.

---

## 30. Invalid geometry fixtures

Create targeted file-backed invalid fixtures or deterministic mutations covering at least:

1. missing structural compatibility identity;
2. wrong structural asset/hash;
3. duplicate mesh ID;
4. duplicate vertex identity;
5. invalid vertex reference;
6. degenerate quad;
7. duplicate face;
8. inconsistent winding;
9. unintended non-manifold edge;
10. unexpected open boundary;
11. disconnected main body;
12. missing required surface assignment;
13. missing required region membership;
14. unknown material instance;
15. invalid canonical surface coordinate;
16. invalid texture UV;
17. missing seam binding;
18. malformed seam loop;
19. seam bound to wrong semantic sides;
20. invalid landmark geometry binding;
21. module interface mismatch;
22. module seam/ring mismatch;
23. optional-module overlap/gap beyond tolerance;
24. symmetry mismatch;
25. visible-height mismatch;
26. ground-contact mismatch;
27. collision proxy invalid owner/driver;
28. collision proxy invalid dimensions;
29. topology hash mismatch;
30. source hash/golden mismatch where applicable.

Prefer one intended defect per fixture.

Diagnostics must remain deterministic and fail closed.

---

## 31. Testing policy

Follow `docs/TESTING.md`.

### Fast iteration

Use focused geometry tests plus:

`zig build test -j1`

### Fast pre-review

`zig build check -j1`

### Full geometry checks

Expensive checks such as self-intersection, subdivision validation, optional-module assembly intersection, or full UV overlap analysis may belong to `test-full` or specialized geometry targets if they materially slow fast tests.

### Final acceptance

Run:

`zig build verify -j1`

Do not move arbitrary endurance loops into fast tests.

Do not weaken M01/M02 regressions.

M03 tests must remain reachable through the accepted tier structure.

---

## 32. Recommended M03 implementation sequence

### Phase A — read-only reconnaissance and geometry architecture manifest

Inspect M02.5 loader API, canonical schema, serialization, semantic surface model, seams/landmarks/materials, asset conventions, and test graph.

Propose:

- geometry source format;
- geometry schema/version;
- topology identity model;
- mesh records;
- face/vertex identity;
- semantic membership representation;
- canonical surface-coordinate representation;
- texture UV representation;
- seam binding representation;
- landmark/site geometry binding;
- optional-module interface seams;
- triangulation rule;
- subdivision rule;
- collision-proxy schema;
- geometry/topology hash boundaries;
- exact source/evidence paths.

**STOP FOR OWNER REVIEW.**

### Phase B — generic canonical geometry foundation

Implement geometry records, parser/codec, deterministic serialization, hashing, generic validators, triangulation, subdivision primitives, geometry loader, and tiny synthetic fixtures.

No human mesh yet beyond minimal proof fixtures.

**STOP FOR OWNER REVIEW.**

### Phase C — main human body control mesh

Implement the continuous main body including face/head/ears/lids/lips, torso/breast/nipple/areola, arms/hands/fingers, pelvis/glutes/perineal base, legs/feet/toes, semantic membership, and structural alignment.

**STOP FOR OWNER REVIEW.**

### Phase D — separate internal/detail meshes

Implement eyeballs/cornea/iris/pupil, mouth cavity, gums/palate, dentition, tongue, and nails.

**STOP FOR OWNER REVIEW.**

### Phase E — adult optional anatomy modules

Implement anus, vulva/vaginal canal, penis, scrotum/testicles, module interfaces, and static assembly compatibility.

**STOP FOR OWNER REVIEW.**

### Phase F — surfaces, UVs, seam bindings, geometry bindings, proxies

Implement canonical surface coordinates, texture UVs, real seam loops, landmark/site geometry bindings, neutral collision proxies, and geometry measurements/bounds.

**STOP FOR OWNER REVIEW.**

### Phase G — formal geometry asset, goldens, visual evidence, invalid matrix

Implement authoritative file-backed geometry source, canonical geometry golden, topology hash, geometry hash, deterministic reports, inspection exports, orthographic visual evidence, invalid fixtures, and five-run determinism.

**STOP FOR OWNER REVIEW.**

### Phase H — final audit

Audit this brief line-by-line, run final verification, create:

`docs/implementation/3d_pipeline_m03_review_package.md`

**STOP FOR OWNER ACCEPTANCE.**

Do not begin M04.

---

## 33. Final review package requirements

The M03 review package must include:

### A. Authority

- structural source path/hash;
- geometry source path;
- proof geometry is file-backed authority;
- proof no Zig reconstruction authority remains.

### B. Schema

- geometry schema/version;
- topology identity model;
- structural compatibility model.

### C. Mesh inventory

For every mesh:

- ID;
- owner/component coverage;
- enabled/default state;
- vertex count;
- quad count;
- derived triangle count;
- boundary count;
- material/surface coverage.

### D. Main-body evidence

- continuous connectedness;
- anatomy-driven topology;
- symmetry;
- height/ground;
- face/head;
- torso;
- hands;
- feet;
- pelvis/perineum.

### E. Adult anatomy evidence

Explicitly list geometry and visual evidence for:

- breast/nipple/areola;
- anus;
- vulva/vaginal canal;
- penis;
- scrotum/testicles.

Do not reduce this to aggregate mesh counts.

### F. Surface/UV evidence

- semantic memberships;
- canonical surface coordinates;
- texture UVs;
- islands;
- seams;
- material assignments.

### G. Structural binding evidence

- seam loops;
- landmark bindings;
- site bindings where implemented;
- M02 anchor alignment.

### H. Collision proxies

- proxy inventory;
- fit evidence;
- `OPEN/TUNING` dimensions;
- deferred higher-fidelity requirements.

### I. Determinism

- geometry source hash;
- topology hash;
- neutral geometry signature;
- canonical byte counts;
- five-run identity;
- mutation sensitivity.

### J. Geometry validation

- manifoldness;
- boundary inventory;
- self-intersections;
- degenerates;
- connected components;
- winding;
- optional-module assembly results.

### K. Visual evidence

- front/back/side/three-quarter;
- wireframe;
- surface/region view;
- required close-ups.

### L. OPEN/TUNING

List visible dimensions, topology density, geometry offsets, UV tuning, interface tolerances, collision-proxy dimensions, and any visual-quality thresholds.

### M. Non-goals

Confirm no M04/later systems were implemented.

### N. M04 readiness

State whether M04 can add skinning/morphology without changing topology identity, renaming mesh/structural IDs, recreating seams, changing geometry authority, or inventing alternate surface coordinates.

---

## 34. Stop / escalation conditions

STOP FOR OWNER REVIEW if:

- accepted M02 structural source needs modification;
- M03 requires a new structural ID not already approved;
- main-body continuity conflicts with component ownership;
- optional anatomy cannot attach without changing shared base architecture;
- geometry schema cannot preserve stable quad topology;
- chosen source format makes generated Zig mesh the real authority;
- canonical surface coordinates cannot be cleanly separated from texture UVs;
- seam bindings require duplicate authority;
- triangulation is nondeterministic;
- topology identity cannot safely support future morph/weight binding;
- geometry validation requires weakening tests;
- adult anatomy would be omitted merely to simplify the milestone;
- collision proxies would require importing runtime 2D physics;
- M03 begins skinning/morphology to compensate for bad rest geometry;
- accepted M01/M02 hashes change unexpectedly.

---

## 35. Definition of done

M03 is complete only when all are true:

1. A separate file-backed canonical human geometry authority exists.
2. It references and validates against the accepted M02 structural source.
3. M02 structural authoring/canonical bytes remain unchanged.
4. Stable topology identity/versioning exists.
5. One continuous main-body quad control mesh exists where practical.
6. Main-body topology covers head, torso, arms, hands, pelvis, legs, feet, and required external anatomy.
7. Separate eye, oral, tongue, tooth/gum, nail, and optional-module geometry exists as required.
8. Adult anatomy geometry is explicitly present and reviewable.
9. Canonical quad topology validates.
10. Deterministic triangulation validates.
11. Deterministic subdivision validates.
12. Semantic region/surface membership is bound to real geometry.
13. Every rendered canonical face has valid material/surface ownership.
14. M02 seam IDs bind to real topology loops.
15. Additional optional-module interface seams are owner-approved and validated.
16. Canonical surface coordinates exist independently from texture UVs.
17. Texture UV foundation exists without forced bilateral mirroring.
18. Required landmark/site geometry bindings are valid.
19. Neutral geometry is symmetric within documented geometry tolerance.
20. Visible height is exactly `1.8288 m`.
21. Ground contacts align to `Y=0`.
22. Accepted neutral assemblies have zero unintended self-intersections.
23. Zero unexpected non-manifold edges or open boundaries remain.
24. Optional anatomy assemblies have no unintended cracks/overlaps.
25. Neutral collision-proxy foundation is implemented or an explicit owner-reviewed M03 exception exists.
26. Geometry-derived measurement/bounds report exists.
27. Geometry source hash exists.
28. Topology hash exists.
29. Deterministic neutral geometry signature exists.
30. File-backed invalid geometry matrix fails closed with stable diagnostics.
31. Deterministic visual evidence exists.
32. Manual owner visual review is completed.
33. `zig build verify -j1` passes subject only to already accepted infrastructure limitations.
34. M01/M02 regression identities remain unchanged.
35. Current production 2D runtime remains unaffected.
36. No M04 skinning/morphology implementation was pulled forward.
37. M03 review package is complete.
38. Owner accepts M03 before M04 begins.

---

## 36. M04 handoff boundary

M04 begins only after M03 owner acceptance.

M04 — Skinning & Morphology Foundation — will consume the accepted M03:

- topology identity;
- canonical control meshes;
- stable vertex/face identities;
- structural skeleton;
- component ownership;
- semantic regions/surfaces;
- seam loops;
- canonical surface coordinates;
- texture UVs;
- collision-proxy bindings;
- geometry measurements.

M04 will add:

- stable skin weights;
- dual-quaternion / linear-blend skinning data;
- structural/morphological parameters that actually deform the mesh;
- initial morph targets;
- morphology-driven rest-skeleton/anchor adjustments;
- first corrective-shape foundations where required.

M04 must not need to rebuild M03 topology merely because M03 failed to plan for deformation.

M03 succeeds when the mesh is anatomically structured, deterministic, semantically bound, and stable enough for M04 to deform rather than replace it.
