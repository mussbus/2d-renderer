# Prompt 27C-R1 Engineering Decision Record

## Status and corrective boundary

The owner rejected the original Prompt 27C torso presentation. Prompt 27C-R1
reopens only the four production torso regions and the Prompt 27B
character-presence submission policy. Prompt 27C limb, joint, pelvis, hand,
foot, stance, skeleton, animation, IK, physics, camera, garments, unified
queue, and allocation/resource ownership remain unchanged. Prompt 27D and
Prompt 28 were not started.

The inherited Prompt 27C checkpoint was staged before R1 edits. Historical
Prompt 27/27A evidence and final Prompt 27B semantic, resize, reprojection,
D3D12, and repeatability evidence are immutable. New evidence is written only
beneath `zig-out/p27c_r1_evidence`.

## Displayed-summary torso provenance

The high-quality standalone male torso shown in the prior summary is
`assets/art/source/p27c_candidates/male_torso_imagegen_candidate_v1_rejected.png`,
SHA-256
`747949bf121c876e4964402eb3910a2b7c37219c5bf2e6d9226dba41719f0aaa`.
It was produced by ImageGen at
`C:/Users/Chad/.codex/generated_images/019f9ef4-c5ad-71f1-83a9-749677822134/call_8vevlE29MqtR5h5BrNshZGBW.png`.

It is a rejected review-only candidate, not a production source. It has baked
checkerboard pixels instead of alpha, changes the established anatomy
identity, and contains oversized opaque deltoid bulbs. The deterministic
`reauthor_p27c_anatomy.ps1` tool does not consume it, and no final production
atlas contains its exact torso pixels.

The permanent R1 provenance manifest classifies every displayed PNG as
`actual_runtime_production_atlas`, `candidate`, `reference`, or
`evaluation_artifact`. Its four-panel sheet labels the displayed candidate,
current atlas region, actual D3D12 crop, and last pre-27C reference with paths,
hashes, regions, and status.

## Production torso route

`src/scene/character_art.zig` is the source registry. Both directions of a
side presentation use one canonical region and the authoritative character
root reflection.

| Style/view | Semantic ID | Region ID | Texture page | Pixel rectangle | Runtime renderer index |
| --- | ---: | ---: | ---: | --- | ---: |
| male/front | `1001` | `5016` | `41` | `(248,430)-(398,612)` | `1` |
| male/side | `1001` | `5001` | `41` | `(284,17)-(379,233)` | `1` |
| female/front | `1101` | `5116` | `42` | `(224,446)-(348,628)` | `2` |
| female/side | `1101` | `5101` | `42` | `(245,39)-(344,229)` | `2` |

Page IDs 41 and 42 resolve to character-art page ordinals 0 and 1. The
renderer adds its procedural page at index 0, yielding installed texture
indices 1 and 2. Assets are installed beneath `zig-out/bin/art` and resolved
from the SDL executable base path.

The male UV rectangles are
`(0.155000,0.437436)-(0.248750,0.622584)` front and
`(0.177500,0.017294)-(0.236875,0.237030)` side. Female UVs are derived from
the fixed 1599×984 page and the unchanged pixel rectangles above. Neither
region, pivot, semantic landmark, lookup, nor page dimension changed in R1.

## Chest-regression root cause and source correction

The rejected source pass treated the full torso alpha bounds as shoulder
authority. On profile art, it misclassified the chest or breast projection as
a second shoulder and filled the space back to an invented shallow contour,
creating a wedge and changing chest identity. Its full-page `Graphics`
surface copy also rounded straight-alpha edge RGB on unrelated pixels.

R1 starts from the last accepted Prompt 25A base pages. It edits only the
single authored profile deltoid and a bounded front shoulder cap; it never
uses the chest projection as a shoulder. The direct decoded-bitmap edit path
preserves every untouched pixel byte. The accepted Prompt 27C component page
remains byte-identical at
`e8b10e30f3154d75d6bebd53975ac06ffa10f125ae4ddb0634f622d56d4cea46`.

The renderer uses straight alpha:

- sampled HLSL color is `texture * tint`;
- RGB blend is `SRC_ALPHA`, `ONE_MINUS_SRC_ALPHA`;
- alpha blend is `ONE`, `ONE_MINUS_SRC_ALPHA`;
- production anatomy pages use nearest sampling.

Transparent torso texels are normalized to zero RGB only after confirming
that convention. The R1 audit also stresses bilinear interpolation over dark
and light backgrounds and rejects transparent-white controlled fixtures.

## Changed-pixel contract

Compared byte-for-byte with the last pre-27C production pages:

| Page/region | Changed pixels | Exact changed bounds |
| --- | ---: | --- |
| male/front torso | `1206` | `(269,432)-(376,464)` |
| male/side torso | `303` | `(289,17)-(315,58)` |
| female/front torso | `1148` | `(240,449)-(332,482)` |
| female/side torso | `86` | `(250,40)-(277,56)` |

The male page has 1,509 changed pixels and the female page has 1,234. The
full-page audit reports zero changed pixels outside those four approved
rectangles. Each torso has one alpha-connected component, zero transparent
nonzero-RGB texels, and an exact directional mirror round trip.

Controlled fixtures prove that transparent-white bilinear contamination,
directional silhouette mismatch, detached geometry, and an unapproved
outside pixel are rejected. These checks protect objective provenance and
continuity; owner aesthetic acceptance remains `[PENDING OWNER REVIEW]`.

## Character-presence ownership

Prompt 27B presence is an acceptance measurement, not character-collision
authority. The production scene now receives an explicit
`PresenceValidationPolicy`:

- `measure_only` always calculates and exposes positions, overlap,
  interaction context, frame/tick, and pass/fail status but does not terminate
  unrestricted interactive movement;
- `enforce_acceptance` returns `CharacterPresenceOverlapExceeded` for the
  scripted evidence/report route and controlled invalid fixtures.

The ordinary threshold remains exactly `0.02`; the active-interaction
threshold remains exactly `0.15`. No epsilon was added. The exact observed
`0.021407` condition remains a measurable failure: it is nonfatal under
`measure_only` and returns `CharacterPresenceOverlapExceeded` under
`enforce_acceptance`.

Interaction context is true only while the authoritative interaction manager
owns an active interaction. Proximity, a completed interaction, or a cancelled
interaction cannot opt into the wider interaction threshold. Submission
errors are still propagated normally; there is no global catch-and-discard.
General dynamic character collision remains unimplemented and was not added
in this bounded corrective pass.

## Owner-review boundary

Automated torso, geometry, presence, D3D12, resource, preservation, and
repeatability evidence cannot approve anatomy aesthetics. The corrective
contact sheet is explicitly `[PENDING OWNER REVIEW]`; no R1 image is an
approved golden until the owner accepts it.
