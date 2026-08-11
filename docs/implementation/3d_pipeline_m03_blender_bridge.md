# M03 Prompt 2C-T1 — Blender authoring bridge

**Status:** Tooling implementation ready for owner review; R1 geometry unchanged

## Authority boundary

The sole M03 human geometry authority remains:

`assets/canonical_model/human_base/geometry/human_base_geometry.authoring.json`

Blender 4.5.9 LTS is offline authoring tooling. A `.blend` is not canonical
geometry, a Blender element index is not a canonical stable ID, and Blender is
not part of the runtime, renderer, or canonical library dependency graph.

The bridge produces only ignored, reproducible working data:

| Artifact | Default path | Role |
| --- | --- | --- |
| working file | `.authoring-work/human_base_geometry_r1_working.blend` | interactive derived representation |
| sidecar | `.authoring-work/human_base_geometry_r1_working.sidecar.json` | deterministic complex metadata bound to source and working file |
| candidate | `.authoring-work/human_base_geometry.candidate.json` | staged canonical candidate; never an automatic promotion |
| validation report | `.authoring-work/human_base_geometry.candidate.validation.txt` | normal canonical pipeline evidence |

All four may be deleted and recreated. Tests never require a committed
`.blend` file.

## Pinned dependency

- version: Blender 4.5.9 LTS;
- archive: `blender-4.5.9-windows-x64.zip`;
- SHA-256: `41da973b9bf95bb312cbeff4d1982feb13259b43c821686b9bafea4dfe5477cf`;
- archive cache: `.deps/cache/blender-4.5.9-windows-x64.zip`;
- extraction: `.deps/blender-4.5.9-windows-x64/`;
- executable: `.deps/blender-4.5.9-windows-x64/blender.exe`;
- local preferences: `.deps/blender-4.5.9-windows-x64/portable/`.

The dependency lock and bootstrap verify the archive before extraction.
Blender binaries and preferences are ignored and never enter Git or global
`PATH`.

## Bridge schema and metadata transport

The bridge schema is `canonical_geometry_blender_bridge` 1.0.0.

Object and scene custom properties record geometry/mesh/topology identities,
source authoritative and normalized hashes, M02 compatibility identity, bridge
schema/version, exact Blender version, working-file ID, sidecar hash, topology
revision, and allocation cursors.

Per-point and per-face INT attributes store split high/low halves of each u32
`VertexId` and `FaceId`, allocation state, and explicit allocation order. Face
and corner attributes transport diagonal, surface, material, region-set,
surface-chart coordinate, texture-space, UV-island, UV coordinate, and overlap
indexes. Imported faces carry an explicit semantic-state marker. Stable IDs do
not depend on Blender array order.

Ordered seam loops, overlapping semantic sets, face-set/topology-loop records,
module interfaces, geometry bindings, and the original canonical document
template remain in the deterministic sidecar because those variable-length
relationships do not map losslessly to simple Blender attributes. The `.blend`
stores the required sidecar SHA-256. The sidecar stores bridge/source identities
and a deterministic working-file ID. Export rejects a missing, stale, changed,
or incompatible source, sidecar, working ID, bridge version, Blender version,
object identity, or structural compatibility value.

The sidecar is not independent authority: it is generated from the canonical
JSON and is accepted only while cryptographically/source-identity bound to the
matching working file.

## Coordinate contract

Canonical data uses meters, right-handed coordinates, +X anatomical/viewer
right, +Y up, and +Z forward. Blender uses meters, +Z up, and -Y as canonical
forward. The bridge owns this exact conversion:

```text
canonical -> Blender: (Xc, Yc, Zc) -> (Xc, -Zc, Yc)
Blender -> canonical: (Xb, Yb, Zb) -> (Xb, Zb, -Yb)
```

Canonical mesh objects must retain identity location, rotation, and scale.
The focused bridge gate checks basis vectors, arbitrary representative f32
positions, asymmetric left/right data, handedness/winding, ground Y=0, and
height 1.8288 m.

## Stable-ID edit policy

Existing vertex movement preserves its `VertexId`. Existing face connectivity
may preserve `FaceId` only when its ordered connectivity is unchanged. A face
whose connectivity is replaced is retired and must receive a newly allocated
ID.

New canonical-relevant points/faces use split halves `(-1,-1)` plus allocation
state `0` as UNALLOCATED. This sentinel cannot overlap the u32 domain. The
editor/helper must mark the explicit new Blender element indexes immediately;
export refuses every remaining UNALLOCATED element and never invents a fallback
ID.

`Allocate` consumes unique positive explicit allocation-order values, sorts by
that order rather than Blender creation/index order, assigns from the persisted
`next_vertex_id`/`next_face_id` cursors, clears allocation order, and increments
topology revision for topology allocations. Deleted IDs are retired; cursor
regression and reuse below the original cursor fail closed. New faces also need
an explicit `CopyFaceSemantics` operation before export. Export rejects missing
semantic state, invalid table indexes, duplicates, missing attributes, nonquads,
or an existing FaceId whose connectivity changed.

Regional patch replacement therefore follows this order:

1. select the canonical face set/region and preserve the accepted boundary;
2. record unchanged perimeter stable IDs;
3. remove interior topology, retiring its IDs;
4. create replacement topology;
5. mark new Blender points/faces UNALLOCATED with an explicit deterministic order;
6. copy/author required semantic and corner channels explicitly;
7. allocate from canonical cursors;
8. update source-bound sidecar loop/set/binding records as required;
9. export to candidate and run canonical validation/evidence;
10. compare rendered evidence and obtain owner review before promotion.

## Commands

```powershell
# Recreate the working representation from authoritative R1.
& '.\tools\blender_bridge.ps1' -Command Import

# Select by source-bound canonical metadata.
& '.\tools\blender_bridge.ps1' -Command SelectFaceSet -FaceSetId 'face_set_id'
& '.\tools\blender_bridge.ps1' -Command SelectRegion -RegionId 'region_id'

# After an explicit edit, mark new Blender indexes and assign deterministic IDs.
& '.\tools\blender_bridge.ps1' -Command MarkUnallocated -MeshId 'human_base_main_body' -VertexIndexes '12000,12001' -FaceIndexes '13000,13001'
& '.\tools\blender_bridge.ps1' -Command CopyFaceSemantics -MeshId 'human_base_main_body' -SourceFaceId 100 -TargetPolygonIndexes '13000,13001'
& '.\tools\blender_bridge.ps1' -Command Allocate

# Export staging data; never overwrite authority.
& '.\tools\blender_bridge.ps1' -Command ExportCandidate
& '.\tools\blender_bridge.ps1' -Command ValidateCandidate

# Rebuild from source and prove the complete no-op gate.
& '.\tools\blender_bridge.ps1' -Command RoundTrip
& '.\.deps\zig-0.16.0\zig.exe' build test-blender-bridge -j1
```

The bridge is headless and does not depend on viewport, selection, active
editor, or user-global preferences. Selection commands are authoring
conveniences only. Landmark bindings are shown as derived empties; seam and
topology-loop edges are marked for inspection; semantic face data can be
selected by canonical region. A non-destructive Catmull-Clark level-one
viewport modifier is present only on meshes whose canonical policy enables it.

Front, side, three-quarter, and close-up reference planes may be added to a
working file as editor aids. Reference images must be user/provenance supplied,
remain outside canonical data, and are never downloaded or promoted by the
bridge.

## No-op semantic gate

The R1 no-op path requires exact preservation of:

- normalized geometry: `88ed9f846a3ddc048bf219e5f8f63d6ffa75e167a07e64ecc527f1fec1be56ae`;
- control topology: `23a3575d1e8aa25bc14f630ead9e5f1fabef36b18acfccd0cdc407a6e750b931`;
- triangulation: `1e587d27b6524888f14fe50b9e8912f107dea8627abf9435378f556d65f5fc5b`;
- neutral signature: `aa7352786b5e564f2bab96f4f12edcaf08a837204ab70667be75a0ca488e89c8`;
- M02 compatibility: `b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda`;
- 11,506 `VertexId` values and 11,504 `FaceId` values;
- 40 face sets, 56 topology loops, 11 seam bindings, and 35 geometry bindings;
- `next_vertex_id=11506`, `next_face_id=14598`.

Readable candidate formatting is secondary: deterministic bridge serialization
may differ from the hand-authored source bytes while normalized semantic
identity remains exact. The bridge never overwrites the authoritative file.

## Candidate validation and promotion

The exporter writes only the candidate path. The independent Zig validator
loads it through the same structural compatibility, parse, generic validation,
human validation, normalization, hash, topology, triangulation, and neutral
signature pipeline used for authoritative geometry. A malformed candidate is
required to fail closed. No ordinary test or bridge command promotes it.

Promotion is deliberately manual:

```text
candidate JSON -> canonical validation/evidence -> owner review -> explicit promotion
```

Any promoted topology change must also carry reviewed revision, stable-ID
retirement/allocation, semantic, seam/interface, binding, and evidence changes.

## External basemesh assessment boundary

Prompt 2C-T1 does not download or adopt third-party geometry. Candidate seeds
must receive a separate provenance/architecture decision because adoption
would replace most or all current topology and require full remapping of M02
surfaces, regions, seams, bindings, receiver interfaces, stable IDs, and
allocation history. Blender extensions, MakeHuman/MPFB integration, auto-rig
tools, and retopology add-ons are not installed by T1.

The current read-only assessment is recorded in the T1 owner report rather than
turning a third-party mesh into repository authority.

## OPEN/TUNING

- retaining a full source template in the deterministic sidecar versus a more
  granular future sidecar;
- ignored working/candidate paths and retention policy;
- the accepted f32 coordinate round-trip boundary;
- interactive boundary-preservation procedure for each anatomical patch;
- author-entered deterministic allocation order for new topology;
- exact semantic transfer/authoring helpers beyond explicit copy;
- owner-guided versus tool-assisted Blender editing;
- whether a provenance-approved external basemesh should replace the R1 seed.

## Additive T3 authority update

The identities above preserve the Prompt 2C-T1 no-op proof as historical
evidence. Prompt 2C-T3 subsequently used the accepted bridge to validate and
promote the owner-authorized HM08 topology-v2 candidate. Active bridge defaults
now bind to authority SHA-256
`29552addc3d550c4a423609598a0dfbc5d28629e62329fb11ef6ce52cab875bf`,
normalized SHA-256
`76cdb1330c952ceb4f5660066c4f5dd516f24ac0ba2c4bd5418f50cf65d00463`,
topology `335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191`,
triangulation `967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444`,
and neutral signature
`d0c63b599aec00c14ffcfca95bcafde16b3c31d14429a0eec67d31a2484bec83`.
The active element/cursor counts are 13,380 vertices and 13,378 faces. This
note does not rewrite or invalidate the earlier T1 R1 evidence.

## Additive R3 shape-authoring update

Prompt 2C-R3 subsequently used the bridge's explicit position-edit mode to
reshape the accepted topology-v2 authority without changing connectivity or
stable IDs. The exporter remains fail-closed by default; a caller must pass
`-AllowPositionEdits`, which maps to `--allow-position-edits`, for an intended
shape-edit candidate. This permission does not relax stable-ID, quad,
connectivity, semantic, seam, binding, sidecar, source-identity, or cursor
validation.

The active R3 authority is
`35a7ab3c433795bcd47975050a5f7ee74a72c43ba3c5d754f9ebbce7886716f7`,
normalized geometry is
`7354f67a78000abf4cad63177a492e45ee72a993a9d0a17b5b6ec7c8b1861417`,
control topology remains
`335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191`,
triangulation remains
`967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444`,
and the neutral signature is
`25472a02ef2e93b2a0afa229335bf172cd5493eae40f745c83fbe6cfc854d532`.
The ignored recreatable working paths are
`.authoring-work/r3/human_base_geometry_r3_authority.blend` and its bound
`.sidecar.json`. A fresh no-op round trip preserves every normalized semantic
identity; authoring byte formatting may differ and is not authority.

## Additive R4 final-neutral update

Prompt 2C-R4 reused the same explicit position-edit route and preserved every
topology, ID, semantic, seam, binding, UV, and cursor record. The current
authority is
`4bed342c289f1f1238c7397c524b63e32d2037737cde08304fe5c47af1b43b8f`,
normalized geometry is
`d7fee949a5ee70c926f19dc46615fa965fa2d75176ba1fc0ea4e02d50aa9b096`,
control topology remains
`335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191`,
triangulation remains
`967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444`,
and the neutral signature is
`31beb6c39ffdcfd6ae009c1b416b7c78a000230ca5ce11de6e2f01dd150022f7`.
The ignored recreatable default working paths now use
`.authoring-work/r4/human_base_geometry_r4_authority.blend` and its bound
`.sidecar.json`. R3 identities above remain historical evidence.
