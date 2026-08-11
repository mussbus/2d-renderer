# M03 Prompt 2C-R4 — final neutral shared-human adaptation

## Status and authority

Prompt 2C-R4 is an automated-gate-passing owner-review candidate. It does not
declare Prompt 2C accepted and does not authorize Prompt 2D, Prompt 2E, Prompt
2F, collision proxies, skinning, morphology, or M04.

The sole authority remains
`assets/canonical_model/human_base/geometry/human_base_geometry.authoring.json`.
R4 used the approved canonical JSON → Blender → candidate JSON → canonical
validation route. Its working `.blend`, sidecar, analysis, and images are
derived authoring/review data, not competing geometry definitions.

## Current identities

| Identity | SHA-256 |
|---|---|
| authoritative readable geometry | `4bed342c289f1f1238c7397c524b63e32d2037737cde08304fe5c47af1b43b8f` |
| normalized geometry | `d7fee949a5ee70c926f19dc46615fa965fa2d75176ba1fc0ea4e02d50aa9b096` |
| control topology | `335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191` |
| triangulation | `967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444` |
| neutral geometry signature | `31beb6c39ffdcfd6ae009c1b416b7c78a000230ca5ce11de6e2f01dd150022f7` |
| M02 structural compatibility | `b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda` |

The authoritative source is 37,263,098 bytes. Normalized canonical geometry is
17,223,551 bytes. M01 and M02 sources were not modified by R4.

## Topology preservation

R4 moved 2,709 existing vertices, with maximum displacement
0.052528810 m. It added/retired no vertex or face IDs and changed no
connectivity. The topology remains version 2.0.0/revision 4 with 13,380
vertices, 13,378 quads, 26,756 derived triangles, and allocation cursors
13,380/13,378. All face semantics, 11 seam bindings, deformation face sets,
provisional UVs, and provisional surface-coordinate charts are unchanged.

## Neutral adaptation measurements

These are mesh-derived OPEN/TUNING values. They describe this geometry and are
not sex-specific norms.

| Measurement | R3 m | R4 m | Delta m |
|---|---:|---:|---:|
| visible shoulder width | 0.697210 | 0.716663 | +0.019453 |
| chest width | 0.428053 | 0.429859 | +0.001807 |
| chest depth | 0.239784 | 0.220982 | -0.018802 |
| waist width | 0.363345 | 0.393214 | +0.029868 |
| hip width | 0.382571 | 0.353952 | -0.028619 |
| hip/glute depth | 0.262403 | 0.245109 | -0.017294 |
| breast projection from report reference plane | 0.107115 | 0.056761 | -0.050353 |
| breast semantic base width | 0.347315 | 0.375495 | +0.028180 |
| glute projection from origin | 0.111470 | 0.094176 | -0.017294 |
| upper-thigh width | 0.406134 | 0.395827 | -0.010307 |
| head height | 0.330223 | 0.330223 | 0 |
| hand semantic span | 0.346729 | 0.346729 | 0 |
| foot length | 0.278403 | 0.278403 | 0 |

The final visual audit classifies the whole result `SLIGHT_FEMALE_LEAN`:
shoulders and ribcage have more moderate frame presence, the hourglass and
breast silhouettes are materially reduced, and breast-root/nipple/areola
topology remains while visible projection is shallow. The retained hip/glute
curve still reads slightly female-leaning and is therefore called out for owner
review rather than overstated as fully neutral. The head, hands, lower legs,
and feet are intentionally unchanged.

## Registration and quality

The accepted landmark classification remains 18 `SURFACE_CORRESPONDENCE` and
17 `INTERNAL_STRUCTURAL_REFERENCE`; `waist_center_landmark` remains internal.
Surface correspondence is max 0.020506918 m, median 0.003398644 m, and P90
0.010319053 m. Internal offsets are reported separately: max 0.073612655 m,
median 0.005550390 m, and P90 0.072373050 m.

The mesh remains one connected component with zero boundaries, non-manifold
edges, duplicate faces, degenerate faces, and detected non-adjacent triangle
intersections. Aspect ratio is max 14.088068, P95 4.944810, P99 7.205161, with
86 faces above 8. R4 created no new above-8 outliers. The 14 R3-created
face/palm/toe outliers are unchanged because those regions were deliberately
outside R4's neutral-body edits; all remaining outliers carry into empirical
M04 deformation validation.

## Evidence

Persistent evidence is under
`assets/canonical_model/human_base/geometry/evidence/prompt_2c_r4_final_neutral/`:

- 43 high-resolution smooth, wireframe, and semantic images;
- mobile Sheet A/B/C;
- matched R3-vs-R4 front, side, and back comparisons;
- complete geometry/measurement/quality report;
- all 35 landmark rows;
- all 86 aspect outliers with T3/R3/R4 lineage;
- Blender BVH self-intersection report.

Explicit regeneration commands are:

```powershell
& '.\tools\render_human_geometry_r4_evidence.ps1'
& '.\tools\compose_human_geometry_r4_review.ps1'
```

Ordinary test/check/verify routes compare committed authority/evidence and do
not rewrite either.

## Verification

- focused R4 geometry chain: 18/18 steps, 32/32 tests passed;
- Blender bridge: 4/4 steps passed;
- isolated R3 regression chain: 15/15 steps, 27/27 tests passed;
- full geometry/self-intersection route: 21/21 steps passed;
- focused M01/M02 routes: 27/27 steps, 103/103 tests passed;
- `zig build test -j1`: 37/37 steps, 290/290 uncached tests passed;
- `zig build check -j1`: 45/45 steps passed;
- `zig build test-full -j1`: 52/52 steps, 110/110 uncached broader tests
  passed;
- `zig build verify -j1`: 64/64 steps passed, including stress 2/2.

Canonical roots reused by the aggregate commands were separately executed and
passed in the focused routes above. The complete owner-facing audit is stored
with the evidence as `prompt_2c_r4_owner_report.md`.

## OPEN/TUNING

- all visible proportions and local form except locked height/ground;
- remaining aspect-ratio outliers and their M04 empirical deformation result;
- provisional semantic splits;
- provisional imported UVs and surface-coordinate charts;
- final optional-module receiver geometry;
- 1500x1500, 64-sample neutral review rendering and mobile-sheet layout.

Prompt 2C-R4 stops at final owner review. No later M03 prompt or M04 work was
started.
