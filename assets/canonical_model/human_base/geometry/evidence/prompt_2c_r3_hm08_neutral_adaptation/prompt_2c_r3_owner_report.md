# Prompt 2C-R3 deterministic owner report

Status: `READY_FOR_OWNER_VISUAL_ENGINEERING_REVIEW`. This report does not
approve Prompt 2C and does not authorize Prompt 2D, Prompt 2E, or M04.

## Identities

- authoritative geometry: `35a7ab3c433795bcd47975050a5f7ee74a72c43ba3c5d754f9ebbce7886716f7` (37,263,056 bytes);
- normalized geometry: `7354f67a78000abf4cad63177a492e45ee72a993a9d0a17b5b6ec7c8b1861417` (17,223,590 bytes);
- control topology: `335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191`;
- triangulation: `967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444`;
- neutral signature: `25472a02ef2e93b2a0afa229335bf172cd5493eae40f745c83fbe6cfc854d532`;
- M02 compatibility: `b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda`.

Five independent candidate builds reproduced identical authority, normalized,
topology, triangulation, neutral, landmark-table, and final-report evidence.

## Topology and geometry

- topology compatibility 2.0.0, revision 4;
- 13,380 vertices, 13,378 authoritative quads, 26,756 derived triangles;
- VertexIds 0...13,379, FaceIds 0...13,377;
- cursors 13,380/13,378;
- 13,379 shape-only vertex moves, maximum displacement 0.475771227 m;
- zero added/retired IDs and zero connectivity changes;
- one connected component;
- zero boundaries, non-manifold edges, duplicate/degenerate faces, and
  detected non-adjacent triangle self-intersections;
- exact height 1.8288 m, ground Y=0, +Z facing, bilateral symmetry.

Quad aspect ratio is maximum 14.088067850, P95 4.936391400, P99
7.204559414, with 86 faces above 8.0. The explicit FaceId inventory is in
`human_base_main_body_r3_report.json`. Largest groups are palms, face/nose,
forefeet, soles, little toes, ears, eyelids, and upper lip. These remain
OPEN/TUNING review items; none was hidden by increasing a tolerance.

Valence distribution is 164 valence-3, 13,060 valence-4, and 156 valence-5
vertices: 320 extraordinary vertices, maximum valence 5. The adopted HM08 eye,
mouth, shoulder, hand, knee, and foot topology was not degraded by gratuitous
retopology.

## Geometry-derived measurements

All values below are current asset-level OPEN/TUNING values in metres except
the locked total height:

| measurement | value |
| --- | ---: |
| visible shoulder width | 0.559834182 |
| chest width | 0.427511811 |
| chest depth | 0.226413034 |
| waist width | 0.363345444 |
| hip width | 0.382571191 |
| hip depth | 0.262403227 |
| head height | 0.330097437 |
| head width | 0.192025706 |
| hand length | 0.141369337 |
| foot length | 0.278403014 |
| foot width | 0.105761223 |

## Landmark semantics

All 35 rows and vectors are in
`human_base_main_body_r3_landmark_bindings.tsv`.

- 18 `SURFACE_CORRESPONDENCE`: median 0.003482047 m, P90 0.008228291 m,
  maximum 0.020506918 m;
- 17 `INTERNAL_STRUCTURAL_REFERENCE`: median intentional offset
  0.002749087 m, P90 0.066877936 m, maximum 0.089407904 m;
- zero `BINDING_REQUIRES_REVIEW`.

Internal pelvis, sternum, shoulder, hip, and waist frames remain internal; the
reported skin correspondence offset is not mislabeled as geometry error.

## Semantics and receivers

Every rendered face remains classified. All 11 M02 seam bindings, all 35
geometry bindings, and all 44 deformation face sets/loops remain valid. The
416 region/surface classifications remain: 140 `DIRECT_MAPPING`, 70
`REGION_SPLIT`, 6 `LOCAL_RETOPOLOGY_REQUIRED`, 42
`MODULE_GEOMETRY_REQUIRED`, and 158 `NOT_RENDERED_AT_THIS_STAGE`.

The six local-retopology items are the groin-left, groin-right, and perineal
region/surface pairs. R3 reshapes their shared receiving surface but carries
their final interface topology to Prompt 2E, where it can be authored with the
project-specific anus and optional anatomy modules. No module geometry is
created here.

All 53,512 imported UV corners remain `PROVISIONAL_IMPORTED_UV`. Canonical
surface coordinates remain `OPEN_TUNING_PROVISIONAL_PER_FACE_CHARTS` and are
independent from UVs.

## Visual audit

| region | classification |
| --- | --- |
| whole-body proportions | `CREDIBLE_NEUTRAL_BASE` |
| head / face | `CREDIBLE_NEUTRAL_BASE` |
| eye openings / eyelids | `ACCEPTABLE_WITH_OPEN_TUNING` |
| shoulder / clavicle / armpit | `CREDIBLE_NEUTRAL_BASE` |
| torso | `CREDIBLE_NEUTRAL_BASE` |
| breast / nipple / areola | `ACCEPTABLE_WITH_OPEN_TUNING` |
| hands / fingers | `CREDIBLE_NEUTRAL_BASE` |
| pelvis / hips / glutes | `ACCEPTABLE_WITH_OPEN_TUNING` |
| groin / perineal receiver | `ACCEPTABLE_WITH_OPEN_TUNING` |
| legs / knees | `CREDIBLE_NEUTRAL_BASE` |
| ankles / Achilles | `ACCEPTABLE_WITH_OPEN_TUNING` |
| feet / toes | `CREDIBLE_NEUTRAL_BASE` |

No implementation-audit region is `STILL_BLOCKING`; external owner visual
acceptance remains mandatory. Current visible OPEN/TUNING items are subtle
facial/head shape, shoulder breadth, pelvis/glute neutrality, minimal/default
breast volume, and the reported palm/face/forefoot aspect outliers.

## Evidence inventory

- `images/`: 43 high-resolution smooth, wireframe, and semantic views;
- `mobile_sheets/`: three phone-oriented review sheets;
- `comparisons/`: nine matched T3-vs-R3 views;
- `r3_visual_index.json`: identity-bound image index;
- JSON/TSV/TXT reports: adaptation, geometry, landmarks, validation,
  self-intersection, semantic disposition, and five-run determinism.

The R3 package changes canonical geometry only. M01 and M02 identities remain
regression contracts; active 2D runtime code and all later prompt work remain
untouched.

## Verification

- focused R3/adoption/scaffold/generic chain: 27/27;
- Blender bridge/no-op round trip: 4/4 steps;
- focused M01/M02 regressions: 103/103 unique tests;
- full self-intersection chain: 28/28;
- `zig build test -j1`: 35/35 steps, 420/420 tests;
- `zig build check -j1`: 43/43 steps, 420/420 tests plus static audits;
- `zig build test-full -j1`: 50/50 steps, 531/531 tests;
- final `zig build verify -j1 --seed 0`: 62/62 steps, 533/533 tests, stress
  2/2.

Two earlier aggregate verify attempts exhibited non-deterministic outer
test-runner/IPC exits after their reported tests passed. The affected
standalone targets passed unchanged, and the fixed dependency-order complete
run passed without altering source or acceptance thresholds.
