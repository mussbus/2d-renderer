# `human_base_geometry` authority

`human_base_geometry.authoring.json` is the sole authoritative M03 geometry
source for the human geometry implemented so far. It is independent from, and
structurally compatible with, the sole M02 authority at
`../human_base.authoring.json`.

Prompt 2C-R4 currently authors one HM08-derived, M02-fitted shared main-body
candidate:

- `human_base_main_body`

The source owns its stable vertex/face IDs, allocation cursors, ordered quad
connectivity, explicit triangulation diagonals, semantic face memberships,
provisional surface-coordinate charts/imported UV islands, all 11 M02 seam
bindings, all 35 M02 landmark geometry bindings, 43 deformation-critical face
sets/loops, and the minimal anus receiver closure face set/internal loop. The
anus module mesh remains deferred to Prompt 2E. Collision proxies remain
deferred to Prompt 2F.

T3 is an explicitly authorized whole-topology reset. It preserves
`MeshId=human_base_main_body` and `TopologyId=human_base_topology`, advances the
topology compatibility version to 2.0.0 and revision to 4, and starts a fresh
version-scoped namespace: vertex IDs 0...13,379, face IDs 0...13,377, and
cursors 13,380/13,378. Matching numeric IDs in topology version 1.x do not
claim identity or correspondence. R3 and R4 preserve that topology
family/version/revision and every element ID; both are shape-only adaptations.
Except for locked height and ground contact, visible proportions, local form,
edge spacing, provisional charts/imported UV layout, remaining aspect-ratio
outliers, and final module-interface receiver loops remain `OPEN/TUNING`.

Accepted historical Prompt 2B evidence remains frozen under
`evidence/prompt_2b/`; original Prompt 2C and R1 evidence remains frozen under
`evidence/prompt_2c/` and `evidence/prompt_2c_r1/`. R1 is classified
`HISTORICAL_SUPERSEDED_M03_R1_CANDIDATE`. T3 adoption evidence remains under
`evidence/prompt_2c_t3_hm08_adoption/`. R3 evidence remains frozen under
`evidence/prompt_2c_r3_hm08_neutral_adaptation/`. Current R4 evidence lives
under `evidence/prompt_2c_r4_final_neutral/` and includes:

- 43 persistent 1500x1500 smooth/wire/semantic PNG views;
- three mobile review sheets and three matched R3-vs-R4 comparisons;
- all 35 classified landmark bindings;
- geometry-quality and zero-self-intersection reports;
- complete R3/R4 measurement deltas and outlier lineage;
- the 18 surface-correspondence and 17 internal-reference landmark records.

Regenerate the source-driven derived review images explicitly with:

```powershell
& '.\tools\render_human_geometry_r4_evidence.ps1'
& '.\tools\compose_human_geometry_r4_review.ps1'
```

Ordinary `test`, `check`, `test-full`, and `verify` routes validate committed
source/evidence but never rewrite the authoritative geometry or repair derived
evidence automatically. The explicit evidence exporter reads the authoritative
JSON and produces derived artifacts only. The one-shot HM08 adoption, R3, and R4
shape-authoring helpers do not remain competing mesh definitions. Retained
renderers consume only the authoritative JSON and produce derived evidence.
Ordinary builds never invoke authoring/evidence workflows or rewrite authority.

## Blender working bridge

Prompt 2C-T1 adds a pinned Blender 4.5.9 LTS authoring bridge. R3 and R4 prove it
against the topology-v2 authority. The following are ignored, reproducible working
artifacts and are never geometry authority:

- `.authoring-work/r4/human_base_geometry_r4_authority.blend`;
- `.authoring-work/r4/human_base_geometry_r4_authority.sidecar.json`;
- `.authoring-work/human_base_geometry.candidate.json`;
- `.authoring-work/human_base_geometry.candidate.validation.txt`.

The `.blend` records the source hashes, bridge schema/version, Blender version,
sidecar hash, stable-ID cursors, and explicit per-element canonical IDs. The
sidecar preserves source-bound complex relationships that do not fit safely in
Blender attributes. Blender vertex/polygon indexes are working details, not
`VertexId` or `FaceId`. Candidate export always targets staging data and must
pass the normal canonical loader/validation/normalization/hashing pipeline;
promotion to this authoritative file is a separate owner-reviewed action.

The complete authority, coordinate, stable-ID, and command contract is in
`docs/implementation/3d_pipeline_m03_blender_bridge.md`.
