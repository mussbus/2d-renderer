# M03 Prompt 2C-T3 — HM08 canonical topology adoption

**Status:** HM08 topology-v2 candidate promoted; awaiting owner review  
**Authority:** `assets/canonical_model/human_base/geometry/human_base_geometry.authoring.json`  
**Runtime impact:** none; offline canonical geometry only

## Provenance and authority

The adopted topology originates from the official MakeHuman Community MPFB2
repository at commit
`437dd513888a92399d1d3200d2e80859fae55abc`, asset
`src/mpfb/data/3dobjs/base.obj` (`hm08`). The pinned OBJ is 1,808,470 bytes,
SHA-256 `bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950`.
The selected asset is CC0 1.0 Universal; the pinned `LICENSE.ASSETS.md` SHA-256
is `5f3ab0cf6f7ebe92efe4b83213131c617d308d164eeefd5da230373640b0c226`.

Only the qualified visible-body range was adopted. Helpers, rig, weights,
targets, morphs, genital helper, eyes, teeth, tongue, and skeleton remain
external reference data. The OBJ, sparse upstream checkout, Blender files,
sidecar, candidate, reports, and images are non-authoritative. After promotion,
the file-backed canonical JSON above is the sole geometry authority. The
one-shot adoption generator and promotion wrapper were removed so they cannot
become a competing mesh definition.

## Topology reset

This is the owner-authorized whole-topology reset before M03 acceptance:

| Field | Current value |
|---|---|
| MeshId | `human_base_main_body` |
| TopologyId | `human_base_topology` |
| compatibility version | `2.0.0` |
| revision | `4` |
| VertexId range | `0...13,379` |
| FaceId range | `0...13,377` |
| `next_vertex_id` | `13,380` |
| `next_face_id` | `13,378` |

Element IDs are scoped by mesh/topology/version. Equal numeric values in the
historical topology-1.x R1 asset do not imply reuse or correspondence. R1 is
now `HISTORICAL_SUPERSEDED_M03_R1_CANDIDATE`; its reports and images remain
unchanged under `evidence/prompt_2c_r1/`.

## Coordinate alignment

The pinned OBJ uses right-handed MakeHuman native coordinates with X lateral,
Y up, and Z forward. Adoption does not rely on an unstated absolute source-unit
meaning: the qualified native height `16.6589` is normalized uniformly to the
locked `1.8288 m` canonical height with scale
`0.10977915708720262`. Native minimum Y `-8.1676` is translated to ground
before scale; X remains centered and axes require no permutation or mirroring.
The qualified symmetric neutral A-pose is preserved. Exact M02 limb-pose and
shape fitting is intentionally deferred to Prompt 2C-R3.

Blender working coordinates remain the separately accepted bridge mapping
`(Xc,Yc,Zc) -> (Xc,-Zc,Yc)` with identity object transforms.

## Current identities

| Identity | SHA-256 / size |
|---|---|
| authoritative readable JSON | `29552addc3d550c4a423609598a0dfbc5d28629e62329fb11ef6ce52cab875bf` / 37,259,068 bytes |
| normalized geometry | `76cdb1330c952ceb4f5660066c4f5dd516f24ac0ba2c4bd5418f50cf65d00463` / 17,219,323 bytes |
| control topology | `335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191` |
| triangulation | `967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444` |
| neutral geometry signature | `d0c63b599aec00c14ffcfca95bcafde16b3c31d14429a0eec67d31a2484bec83` |
| M02 structural target | `b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda` |

## Structural and semantic mapping

All 13,378 rendered quads have one accepted M02 primary surface, one accepted
material instance, and required region membership. The 208 regions plus 208
surfaces are all classified in `hm08_t3_semantic_classification.tsv`:

- `DIRECT_MAPPING`: 140;
- `REGION_SPLIT`: 70;
- `LOCAL_RETOPOLOGY_REQUIRED`: 6;
- `MODULE_GEOMETRY_REQUIRED`: 42;
- `NOT_RENDERED_AT_THIS_STAGE`: 158.

The visible body currently renders 108 distinct surface/region pairs. Deferred
or separate geometry is explicitly classified rather than fabricated into the
shared body. Breast, nipple, and areola identities map to the continuous shared
torso. Perineal/adult receiver areas remain provisional; the minimal anus
receiver is one closure quad plus its four-edge loop and is explicitly marked
for Prompt 2E local retopology/module work.

All 11 M02 seam IDs bind deterministic, closed, mutually compatible ordered
edge loops. All 35 landmarks have face-local geometry bindings and retain their
surface-vs-internal semantic classification. Current seed-pose registration is
not Prompt 2C-final: all-landmark median/P90/max are approximately
0.11029/0.35649/0.38008 m, dominated by M02 fingertip positions versus the
preserved HM08 A-pose. M02 anchors were not moved and no global tolerance was
raised. Prompt 2C-R3 owns the pose/shape registration correction.

There are 43 source-derived deformation-critical face sets and matching loops
for eyes, lips/corners, shoulders, breast roots, elbows, wrists, thumb bases,
finger zones, groin/thigh roots, glute folds, knees, ankles, forefeet, and toe
zones, plus the anus receiver face set/loop.

## Geometry quality baseline

- vertices: 13,380;
- authoritative quads: 13,378;
- deterministic triangles: 26,756;
- connected components: 1;
- boundary/non-manifold/degenerate/duplicate faces: 0;
- detected non-adjacent triangle self-intersections: 0;
- bilateral symmetry: pass;
- aspect maximum/P95/P99: 13.85832 / 4.50260 / 7.01503;
- quads over aspect 8: 80;
- valence 3/4/5: 164 / 13,060 / 156;
- extraordinary vertices: 320; maximum valence: 5.

These are adoption baselines, not final Prompt 2C acceptance thresholds.
Outliers and semantic receiver topology carry forward to R3.

## Surface channels

All 53,512 texture corners preserve the qualified upstream UV coordinates with
status `PROVISIONAL_IMPORTED_UV`; zero fallback UV quads were required. Each
face has its own deterministic current island identity, so this checkpoint does
not claim final island grouping or overlap policy. Canonical surface coordinates
remain independent per-face provisional charts with status
`OPEN_TUNING_PROVISIONAL_PER_FACE_CHARTS`. Prompt 2F owns final acceptance of
both channels.

## Determinism and bridge proof

Five complete independent generations produced identical readable bytes,
normalized/topology/triangulation/neutral identities, M02 target, semantic
classification, and landmark mapping. The canonical-to-Blender-to-canonical
no-op round trip changed only readable JSON formatting; all canonical semantic
identities, IDs, connectivity, membership, seams, bindings, and cursors remain
exact. Evidence lives in:

- `hm08_t3_five_run_determinism.txt`;
- `hm08_t3_blender_roundtrip.txt`;
- `hm08_t3_adoption_manifest.json`.

## Visual evidence

`evidence/prompt_2c_t3_hm08_adoption/images/` contains 28 persistent
high-resolution PNGs: whole front/back/side/three-quarter, whole front/side
wireframes, semantic surface map, head front/side/wire, shoulder/armpit
shaded/wire, hand palm/back/three-quarter/wire, pelvis front/back/wire,
perineal receiver, knee, ankle, foot top/side, toe wire, and torso/breast
front/side/wire. `hm08_t3_visual_index.json` binds them to the authority hash.
They are derived review evidence, not geometry authority.

Regenerate visual evidence only with:

```powershell
& '.\tools\render_hm08_adoption_evidence.ps1'
```

## Verification

The promoted authority passed the final owner-review gates with Zig 0.16.0:

- focused HM08 adoption: 12/12 build steps, 22/22 tests;
- Blender bridge no-op and fail-closed checks: 4/4 build steps;
- canonical human geometry full/self-intersection route: 15/15 build steps,
  23/23 tests;
- `zig build test -j1`: 33/33 build steps, 415/415 tests;
- `zig build check -j1`: unchanged rerun 41/41 build steps, 415/415
  tests, formatting and repository audits passed;
- `zig build test-full -j1`: 48/48 build steps, 526/526 tests;
- `zig build verify -j1`: 60/60 build steps, 528/528 tests, including
  stress 2/2.

The first `check` execution encountered the known Windows test-runner IPC
process anomaly after reporting 404/404 tests and passing the repository
audits. No assertion diagnostic was emitted; the unchanged rerun completed
successfully as recorded above. The final retained source-driven renderer also
regenerated all 28 review PNGs successfully from the promoted authority.

## OPEN/TUNING and next gate

Prompt 2C-R3 must adapt the neutral seed without changing the accepted M02
source: exact rest-pose fit, whole-body neutral proportions, local anatomical
shape, landmark registration, semantic split boundaries, perineal/optional
module receivers, remaining aspect outliers, surface charts, UV organization,
and any justified local retopology. Prompt 2D and M04 remain unstarted.
