# Known Gaps

Prompt 27 is the accepted current integration boundary. The gaps below are
future-content or tooling limitations; none invalidates the current Prompt 27
acceptance route.

| Gap | Impact | Current workaround | Trigger for implementation | Blocks current Prompt 27 acceptance? | Blocks a future editor? |
|---|---|---|---|---|---|
| No runtime-authored side-left/side-right fragment selection policy | Asymmetric side garments cannot be represented without separate generalized selection metadata. | All current production garment side sources are mirror-safe and follow the authoritative body projection. | First milestone that authors a genuinely asymmetric side garment; before garment editor export is finalized. | No | Yes |
| Numeric visual layers are the authored garment-depth mechanism | A future author must know renderer layer numbers; reusable relations such as “behind neck” are not first-class. | Current 30-item wardrobe uses a stable, audited numeric layer table. | Before first multi-depth production garment or garment editor. | No | Yes |
| No stable authored fragment ID independent of recipe ID | Diagnostics identify the component/recipe, but a future editor cannot persist a human-authored fragment identity cleanly. | Logical item + component + typed recipe ID remains deterministic. | Garment schema stabilization. | No | Yes |
| Neck/collar coverage is not first-class | A collared/high-neck garment could pass a generic torso fit while missing the intended collar zone. | Current low-neck/halter/blouse art uses per-item fit landmarks and bounded coverage zones; no accepted item declares a high-neck collar. | Before a high-neck/collared production item or garment editor. | No | Yes |
| Shoulder slope is not represented as a bounded semantic contour | A future fitted garment can satisfy rectangle/span metrics while disagreeing with the visual shoulder descent or armhole. | Current art was manually fitted and Prompt 25D metrics/captures are accepted. | Before new fitted upper-body authoring is generalized. | No | Yes |
| Split skirt is one deformable mesh | It cannot independently order rear/far, central, and front/near fabric around limbs. | Existing `garnet_split_skirt` mesh is accepted for current poses and layers as one unit. | When a production skirt/dress requires limb-crossing depth composition. | No | Yes |
| Hair/headwear is not a three-fragment depth recipe | Hats always use the headwear layer above the single hair presentation, limiting back-hair/headwear/front-hair composition. | Current long hair and hats are visually accepted with fixed order. | Hair/headwear authoring expansion. | No | Yes |
| Current atlas supplies only front and canonical-side wardrobe art | Rear, diagonal, and genuinely directional variants are unavailable. | Front and mirrored canonical side are the supported presentation views. | Content-specific authored-view expansion. | No | Yes, for those views |
| Visual-geometry fit metadata remains authored in Zig | Routine new garments require source edits. | Catalog definitions are bounded, validated, and deterministic. | Garment editor/export schema phase. | No | Yes |
| Only two environment themes are authored | The theme architecture is proven but the world has limited visual variety. | Violet crystal ruin and neutral diagnostic chamber cover production and diagnostic presentation. | New world-content milestone. | No | Yes, for scalable content production |
| Environment placements are authored in source | Artists cannot place parallax or decorative elements interactively. | Theme definitions are immutable, bounded, and validated against collision ownership. | Level/theme editor phase. | No | Yes |
| Interaction presentation has one production contact/occlusion profile | Carrying, lifting, hand-to-prop, multi-contact, or cinematic interactions need additional data contracts and authored animation/views. | The fixed-root handshake uses typed role views, automatic-view suppression, one typed right-hand contact profile, existing IK, and deterministic cleanup. | First production interaction requiring more contacts, a relative-root constraint, or world anchors. | No | Yes, for general interaction authoring |
| No authoring GUI | Artists cannot place pivots, landmarks, zones, fragments, themes, or interaction presentation interactively. | Definitions are authored in source and checked by focused validation plus D3D12 captures. | Phase 6 authoring tools. | No | Yes |
| No bounded gameplay loop | The repository demonstrates integrated production systems, not a beginning-to-completion game slice. | Prompt 27 foundation supports traversal, jumps, dash, themes, outfits, and three handshakes with reset. | Phase 5 vertical slice after explicit authorization. | No | No |

## Art-quality status

The current Prompt 25D character art is accepted at the stored 640×480
acceptance camera and required pose/view/preset matrix. Prompt 26 environment
art and Prompt 27 combined captures were inspected through the real D3D12/DXIL
route. This does not prove arbitrary future combinations, views, body
topologies, morphology ranges, themes, or interactions. New content must
declare and pass its own contracts rather than inheriting acceptance from the
current atlases.

## Interaction-presentation boundary

Prompt 27 completed the planned view-aware handshake presentation. Each
interaction definition can declare a view for each participant role, whether
ordinary automatic view selection is suppressed, and a typed occlusion
profile. The current handshake owns side/side presentation, preserves the
participating right-arm animation/IK plane, applies participant-qualified
body/equipment ordering, and releases every claim on completion,
cancellation, rollback, and reset.

This is deliberately not a general paired-pose or prop-interaction framework.
Future multi-contact, relative-root, world-anchor, back/three-quarter, or
cinematic behavior remains out of scope until real content requires it.
