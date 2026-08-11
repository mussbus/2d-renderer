# M03 Prompt 2C-R3 — HM08 neutral `human_base` adaptation

> Historical note: R3 remains the structural/anatomical fitting checkpoint,
> but its geometry identities were superseded by the owner-authorized R4
> shape-only neutralization. R4 does not rewrite this historical evidence;
> current identities live in `3d_pipeline_m03_final_neutral_adaptation.md`.

**Status:** Candidate promoted after automated gates; awaiting owner visual and
engineering review. Prompt 2C is not owner-accepted. Prompt 2D, Prompt 2E, and
M04 have not started.

## Authority and scope

The sole geometry authority remains:

`assets/canonical_model/human_base/geometry/human_base_geometry.authoring.json`

R3 used the approved canonical JSON → Blender working data → candidate JSON →
canonical validation workflow. The promoted result is a shape-only adaptation
of the accepted HM08 topology-v2 seed. No retained tool reconstructs the human
shape, no `.blend` or sidecar is authority, and no R1 element correspondence is
claimed.

M02 remains unchanged at normalized SHA-256
`b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda`.
HM08 provenance remains MPFB2 commit
`437dd513888a92399d1d3200d2e80859fae55abc`,
`src/mpfb/data/3dobjs/base.obj`, SHA-256
`bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950`,
CC0 1.0 Universal.

## Current identities

| Identity | SHA-256 / bytes |
| --- | --- |
| authoritative readable geometry | `35a7ab3c433795bcd47975050a5f7ee74a72c43ba3c5d754f9ebbce7886716f7` / 37,263,056 |
| normalized geometry | `7354f67a78000abf4cad63177a492e45ee72a993a9d0a17b5b6ec7c8b1861417` / 17,223,590 |
| control topology | `335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191` |
| triangulation | `967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444` |
| neutral signature | `25472a02ef2e93b2a0afa229335bf172cd5493eae40f745c83fbe6cfc854d532` |

The unchanged topology and triangulation hashes prove that R3 did not replace
or reconnect the accepted HM08 control topology. Topology compatibility remains
2.0.0, revision 4, with 13,380 vertices, 13,378 quads, vertex IDs 0...13,379,
face IDs 0...13,377, and allocation cursors 13,380/13,378. R3 adds/retires no
IDs. It moves 13,379 vertices; the maximum displacement is 0.475771227 m,
primarily from fitting the native HM08 arm/hand pose to the accepted M02
A-pose.

## Neutral shape and structural fit

The adaptation preserves HM08's facial, eye, mouth, shoulder, hand, knee, and
foot loops while fitting the visible body to the M02 A-pose. It reduces the
upstream hourglass bias, narrows the pelvis smoothly, retains moderate neutral
glute volume, reduces default breast projection while preserving breast-root,
areola, and nipple topology, and aligns arms, hands, legs, feet, chin, navel,
heel, toe, and fingertip references. Height is exactly 1.8288 m, ground is
Y=0, +Z remains forward, and bilateral symmetry remains valid.

Geometry-derived measurements are current asset-level OPEN/TUNING values:

| Measurement | Metres |
| --- | ---: |
| visible shoulder width | 0.559834182 |
| chest width / depth | 0.427511811 / 0.226413034 |
| waist width | 0.363345444 |
| hip width / depth | 0.382571191 / 0.262403227 |
| head height / width | 0.330097437 / 0.192025706 |
| hand length | 0.141369337 |
| foot length / width | 0.278403014 / 0.105761223 |

## Landmark semantics

All 35 bindings are explicit in
`human_base_main_body_r3_landmark_bindings.tsv`:

- 18 `SURFACE_CORRESPONDENCE`: median 0.003482047 m, P90 0.008228291 m,
  maximum 0.020506918 m;
- 17 `INTERNAL_STRUCTURAL_REFERENCE`: median intentional surface offset
  0.002749087 m, P90 0.066877936 m, maximum 0.089407904 m;
- 0 `BINDING_REQUIRES_REVIEW`.

The largest internal offsets are sternum, pelvis, shoulder, hip, and waist
reference frames; they remain internal and were not pulled onto the skin.

## Geometry quality

- one connected component;
- 13,380 vertices, 13,378 quads, 26,756 derived triangles;
- zero boundary edges, non-manifold edges, degenerates, duplicate faces, and
  detected non-adjacent triangle self-intersections;
- 320 extraordinary vertices: 164 valence-3 and 156 valence-5; maximum valence
  5;
- quad aspect maximum 14.088067850, P95 4.936391400, P99 7.204559414;
- 86 quads above the R3 review target of 8.0.

The >8 inventory is explicit by FaceId in the JSON report. The largest groups
are palms (max 14.0881), face/nose (12.9746/12.6358), forefeet (12.3253), soles
(11.9287), little toes (11.5786), ears (9.8386), eyelids (9.1472), and upper
lip (8.7437). They are retained owner-review items because R3 prioritized the
proven HM08 deformation flow and credible shape over connectivity changes.
No hidden tolerance was raised and no outlier is classified benign.

## Semantics and later receiver work

Every rendered face remains classified, all 11 M02 seams are present and
deterministically ordered, all 44 source-derived deformation face sets/loops
remain present, and all 53,512 imported UV corners remain
`PROVISIONAL_IMPORTED_UV`. Surface coordinates remain
`OPEN_TUNING_PROVISIONAL_PER_FACE_CHARTS` and independent from texture UVs.

The T3 classification totals remain 140 direct mappings, 70 region splits, 6
local-retopology requirements, 42 module-geometry requirements, and 158 not
rendered at this stage across the 416 M02 region/surface records. R3 makes no
semantic boundary or topology change. The six groin/perineal region/surface
items are explicitly carried to Prompt 2E because the final receiver loops
must be authored together with the project-specific anus and optional anatomy
modules. R3 reshapes the shared receiving surface but does not invent those
interfaces early.

## Visual assessment

| Region | R3 status |
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

No region is classified `STILL_BLOCKING` by the implementation audit. Owner
visual acceptance is still required. The current open visual items are subtle
facial/head tuning, shoulder breadth, pelvis/glute neutrality, default breast
volume, and the explicitly reported palm/face/forefoot aspect outliers.

## Evidence and reproducibility

Persistent evidence is under
`assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation/`:

- 43 high-resolution smooth, wireframe, and semantic views;
- three mobile review sheets;
- nine matched T3-vs-R3 comparisons;
- geometry, landmarks, adaptation, validation, intersection, semantic
  disposition, and five-run determinism reports.

Regenerate derived imagery explicitly with:

```powershell
& '.\tools\render_human_geometry_r3_evidence.ps1'
& '.\tools\compose_human_geometry_r3_review.ps1'
```

Five independent authoring builds produced identical authoritative candidate,
report, and landmark TSV bytes. A fresh canonical → Blender → canonical no-op
round trip preserves the normalized, topology, triangulation, and neutral
identities. Ordinary tests never invoke Blender or regenerate authority.

## Verification

- focused R3/adoption/scaffold/generic chain: 27/27 tests;
- pinned Blender bridge: 4/4 steps, including exact semantic no-op round trip;
- focused M01/M02 regressions: 103/103 unique tests;
- full R3 self-intersection chain: 28/28 tests;
- `zig build test -j1`: 35/35 steps, 420/420 tests;
- `zig build check -j1`: 43/43 steps, 420/420 tests plus formatting and
  repository audits;
- `zig build test-full -j1`: 50/50 steps, 531/531 tests;
- final fixed-order `zig build verify -j1 --seed 0`: 62/62 steps, 533/533
  tests, including stress 2/2.

Two preceding aggregate `verify` attempts showed the documented Windows Zig
test-runner/IPC symptom: all reported tests passed, but the outer graph marked
different already-passing binaries failed. Unchanged isolated reruns passed,
and pinning dependency traversal produced the clean complete result above. No
assertion, source, threshold, or evidence change was used to obtain it.

## OPEN/TUNING

- visible proportions and local anatomical form except locked height;
- the 86 explicit aspect-ratio outliers;
- the 70 provisional semantic region splits;
- final groin/perineal module receiver topology;
- imported UVs and provisional surface-coordinate charts;
- 1500x1500 review render resolution, 64 samples, neutral lighting, wire
  thickness, and mobile-sheet layout.

This package is ready for owner review only. It does not authorize Prompt 2D,
Prompt 2E, Prompt 2F, collision proxies, skinning, morphology, or M04.
