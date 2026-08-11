# M03 Prompt 2C-R4 owner-review report

## Current geometry identities

| Identity | SHA-256 |
|---|---|
| authoritative geometry source | `4bed342c289f1f1238c7397c524b63e32d2037737cde08304fe5c47af1b43b8f` |
| normalized geometry | `d7fee949a5ee70c926f19dc46615fa965fa2d75176ba1fc0ea4e02d50aa9b096` |
| control topology | `335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191` |
| triangulation | `967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444` |
| neutral geometry signature | `31beb6c39ffdcfd6ae009c1b416b7c78a000230ca5ce11de6e2f01dd150022f7` |
| M02 structural compatibility | `b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda` |

The authoritative geometry source is 37,263,098 bytes. Normalized canonical
geometry is 17,223,551 bytes. The two accepted M01 identities reproduced as
`2855fc11c0f8a1e5698af253c1a89eeb07483e5879556094ea4b6f29149b784b`
and `b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d`.

## Topology preservation

- mesh: `human_base_main_body`;
- topology: `human_base_topology` 2.0.0, revision 4;
- 13,380 vertices, 13,378 authoritative quads, 26,756 derived triangles;
- zero stable-ID additions, retirements, or changes;
- zero connectivity or triangulation-diagonal changes;
- allocation cursors remain 13,380/13,378;
- all 11 M02 seams, semantic memberships, deformation face sets, provisional
  UVs, and provisional surface-coordinate charts remain unchanged.

The topology and triangulation hashes are byte-for-byte equal to R3. R4 is a
position-only geometry change.

## Neutral adaptation

R4 moved 2,709 existing vertices with a maximum displacement of 0.052528810 m.
The deterministic bilateral operations modestly broadened and raised the outer
shoulder presentation, strengthened ribcage frame presence, reduced waist
taper, reduced external hip and upper-thigh fullness, reduced posterior glute
projection, and reduced semantic breast/nipple projection while retaining the
breast-root, nipple, and areola topology.

| Mesh-derived measurement | R3 m | R4 m | Delta m |
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

Overall visual classification: `SLIGHT_FEMALE_LEAN`.

| Region | R4 visual result |
|---|---|
| shoulders | moderate shared frame; no bodybuilder/V-taper exaggeration |
| ribcage | moderate frame presence relative to pelvis |
| waist | materially reduced R3 hourglass emphasis, with some curve remaining |
| pelvis | plausible shared width around unchanged structural references |
| hips | reduced lateral fullness without a male-coded narrow pelvis |
| breasts | shallow minimal/default tissue; root, nipple, and areola structure retained |
| glutes | credible anatomy with reduced prominence, but still a mild female-leaning cue |
| thighs | moderate neutral mass with reduced upper-thigh fullness |

The remaining hip/glute/waist curve produces a slight female lean, not the
strongly female-coded R3 silhouette. The prompt permits a slight residual lean
as owner-reviewable; final owner visual judgment remains the acceptance
authority.

## Registration

The owner-accepted classification remains 18 `SURFACE_CORRESPONDENCE` and 17
`INTERNAL_STRUCTURAL_REFERENCE`; `waist_center_landmark` remains an internal
reference. The complete 35-row positions, vectors, and interpretations are in
`human_base_main_body_r4_landmark_bindings.tsv` and the JSON report.

| Class | Count | Median m | P90 m | Maximum m |
|---|---:|---:|---:|---:|
| surface correspondence | 18 | 0.003398644 | 0.010319053 | 0.020506918 |
| intentional internal-to-surface offset | 17 | 0.005550390 | 0.072373050 | 0.073612655 |

Surface registration remains inside the R4 max/median/P90 targets. Internal
offsets remain reported separately and are not mislabeled as surface errors.

## Quality

- aspect ratio: max 14.088068, P95 4.944810, P99 7.205161;
- 86 quads above 8;
- 72 inherited HM08-seed outliers and 14 R3-created outliers;
- zero R4-created above-8 outliers;
- the 14 R3-created face/palm/toe outliers were unchanged because R4 did not
  edit those regions;
- 320 extraordinary vertices, maximum valence 5;
- one connected component;
- zero boundary edges, non-manifold edges, duplicate faces, and degenerates;
- zero detected non-adjacent triangle self-intersections.

The complete 86-row lineage is in `r4_aspect_outliers.tsv`. Remaining reviewed
outliers are OPEN/TUNING and must be evaluated empirically during M04
deformation validation; no topology was damaged merely to improve this metric.

## Visual evidence

Persistent evidence is stored in this directory:

- 43 high-resolution smooth, wireframe, and semantic PNGs in `images/`;
- mobile Sheet A/B/C in `mobile_sheets/`;
- matched R3-vs-R4 front, side, and back comparisons in `comparisons/`;
- `r4_visual_index.json` enumerates every individual image;
- `human_base_main_body_r4_report.json` is the complete deterministic report;
- `human_base_main_body_r4_self_intersection.json` is the Blender BVH result;
- `human_base_main_body_r4_landmark_bindings.tsv` contains all 35 bindings;
- `r4_aspect_outliers.tsv` contains all 86 reviewed outliers;
- `human_base_main_body_r4_adaptation.json` records the shape operations.

## Tests

- R4 focused geometry chain: 18/18 steps, 32/32 tests passed;
- Blender bridge: 4/4 steps passed, including exact R4 no-op identity and
  fail-closed invalid-candidate coverage;
- isolated R3 regression chain: 15/15 steps, 27/27 tests passed;
- full geometry/self-intersection route: 21/21 steps passed;
- focused M01/M02 routes: 27/27 steps, 103/103 tests passed;
- `zig build test -j1`: 37/37 steps, 290/290 uncached tests passed, with the
  separately proven canonical roots reused from cache;
- `zig build check -j1`: 45/45 steps passed, including formatting and
  repository-policy audits;
- `zig build test-full -j1`: 52/52 steps, 110/110 uncached broader tests
  passed, with the fast and canonical roots reused from their successful runs;
- `zig build verify -j1`: 64/64 steps passed, including stress 2/2.

The managed default-cache attempt encountered `manifest_create AccessDenied`
before compilation. Two earlier full-geometry aggregate attempts encountered
the known Windows Zig test-listener timeout after their contained assertions
had passed. The unchanged isolated and warmed-cache reruns returned exit code
zero, including the required full geometry and final verify routes.

## OPEN/TUNING

- all R4 mesh-derived proportions and local form except locked height/ground;
- remaining aspect-ratio outliers and their future empirical deformation result;
- provisional semantic splits;
- provisional imported UVs and surface-coordinate charts;
- final optional-module receiver geometry;
- 1500x1500, 64-sample review rendering and mobile-sheet composition.

## Blockers

None in the automated R4 engineering gates. Final owner visual acceptance is
still required. Prompt 2C is not self-approved by this report, and no Prompt
2D, Prompt 2E, Prompt 2F, collision-proxy, skinning, morphology, or M04 work
was begun.
