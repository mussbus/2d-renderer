# Known Gaps

| Gap | Impact | Current workaround | Intended milestone | Blocks Prompt 26? | Blocks a future editor? |
|---|---|---|---|---|---|
| No runtime-authored side-left/side-right fragment selection policy | Asymmetric side garments cannot be represented without separate generalized selection metadata. | All current production garment side sources are mirror-safe and follow the authoritative body projection. | First milestone that authors a genuinely asymmetric side garment; before garment editor export is finalized. | No | Yes |
| Numeric visual layers are the authored garment-depth mechanism | A future author must know renderer layer numbers; reusable relations such as “behind neck” are not first-class. | Current 30-item wardrobe uses a stable, audited numeric layer table. | Before first multi-depth production garment or garment editor. | No | Yes |
| No stable authored fragment ID independent of recipe ID | Diagnostics identify the component/recipe, but a future editor cannot persist a human-authored fragment identity cleanly. | Logical item + component + typed recipe ID remains deterministic. | Garment schema stabilization. | No | Yes |
| Neck/collar coverage is not first-class | A collared/high-neck garment could pass a generic torso fit while missing the intended collar zone. | Current low-neck/halter/blouse art uses per-item fit landmarks and bounded coverage zones; no accepted item declares a high-neck collar. | Before a high-neck/collared production item or garment editor. | No | Yes |
| Shoulder slope is not represented as a bounded semantic contour | A future fitted garment can satisfy rectangle/span metrics while disagreeing with the visual shoulder descent or armhole. | Current art was manually fitted and Prompt 25D metrics/captures are accepted. | Before new fitted upper-body authoring is generalized. | No | Yes |
| Split skirt is one deformable mesh | It cannot independently order rear/far, central, and front/near fabric around limbs. | Existing `garnet_split_skirt` mesh is accepted for current poses and layers as one unit. | When a production skirt/dress requires limb-crossing depth composition. | No | Yes |
| Hair/headwear is not a three-fragment depth recipe | Hats always use the headwear layer above the single hair presentation, limiting back-hair/headwear/front-hair composition. | Current long hair and hats are visually accepted with fixed order. | Hair/headwear authoring expansion. | No | Yes |
| Current atlas supplies only front and canonical-side wardrobe art | Rear, diagonal, and genuinely directional variants are unavailable. | Front and mirrored canonical side are the supported presentation views. | Content-specific; not implied by Prompt 26. | No | Yes, for those views |
| Visual-geometry fit metadata remains authored in Zig | Routine new garments require source edits. | Catalog definitions are bounded, validated, and deterministic. | Garment editor/export schema phase. | No | Yes |
| No authoring GUI | Artists cannot place pivots, landmarks, zones, or fragments interactively. | Definitions are authored in source and checked by focused validation plus D3D12 captures. | Phase 6 authoring tools. | No | Yes |
| Environment themes and layered environment art do not exist | World visuals remain below the production-character standard. | Foundation world/collision/render paths exist. | Prompt 26. | This is Prompt 26 scope, not a precondition | No |
| Prompt 27 integrated presentation is not implemented | Character/world/interaction visual systems have not received the final combined acceptance pass. | Existing focused demonstrations validate the components independently. | Prompt 27. | No | No |
| No bounded gameplay loop | The repository demonstrates systems, not a beginning-to-completion game slice. | Foundation playground and focused demos. | Phase 5 vertical slice. | No | No |

## Art-quality status

The current Prompt 25D art is accepted at the stored 640×480 acceptance camera and required pose/view/preset matrix. This does not prove that arbitrary future combinations, views, body topologies, or morphology ranges are authored. New content must declare and pass its own contracts rather than inheriting acceptance from the current atlas.

## Interaction-presentation limitation

Handshake and IK are production systems, but the richer view-aware interaction presentation planned for Prompt 27 is not complete. This does not block Prompt 26 environment work.
