# Character Art Boundary Decision

Date: 2026-07-26

## Context

The original Prompt 24 atlas pixels baked removable clothing into canonical torso, arm, pelvis, leg, and foot regions. Although equipment state already existed independently, those production pixels would have made a clothed body region the effective base asset.

## Decision

Canonical presentation bindings now resolve non-sexual neutral base anatomy. Arms, legs, hands, and feet use bare base-form pixels. Torso and pelvis use smooth opaque skin-adjacent maquette surfaces. That permanent modesty treatment is classified as `base_presentation`: it has no equipment slot, garment semantic, fabric edge, or removal operation. It preserves the male/female outer silhouette and the attachment/deformation boundaries needed by future clothing.

Removable clothing remains an equipment-kind visual layered over base anatomy. Each corrected page deliberately contains a side and front training-vest overlay containing garment pixels only. This is a minimal boundary proof, not a wardrobe system.

| Style/view | Base torso binding | Removable vest binding | Physical page |
| --- | --- | --- | --- |
| Male side | `.character`, region `5001` | `.equipment`, region `5032` | `41` |
| Male front | `.character`, region `5016` | `.equipment`, region `5033` | `41` |
| Female side | `.character`, region `5101` | `.equipment`, region `5132` | `42` |
| Female front | `.character`, region `5116` | `.equipment`, region `5133` | `42` |

The shared page is intentional: texture packing controls batching, while binding kind plus semantic and region IDs control ownership. `Presentation` resolves only character-kind base identities. `Definition.validateAnatomyClothingBoundary` rejects kind crossover and validates the real same-page mappings.

## Consequences

- Base anatomy is complete with no garment selection.
- Removing or replacing a garment cannot remove or replace an anatomy binding.
- Hair remains independently addressable presentation content.
- The existing fixed-tick simulation, animation, physics, IK, interaction, appearance, global render queue, and D3D12 resource model are unchanged.
- The corrected pack still uses two pages and the same per-character submission path; only four initialization-time art bindings were added.

## Implementation note

The first female image-edit request was rejected by the image safety filter before producing output. The successful replacement used neutral sculptor-maquette language and fully opaque featureless surfaces. This changed no engineering requirement or runtime design.
