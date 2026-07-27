# Prompt 25 Outfit Reference Inventory

## Scope and provenance boundary

The local inspection sources are:

- `reference/video/outfit_interaction_reference.mp4`
- `reference/video/outfits_1.jpg`
- `reference/video/outfits_2.jpg`

The prompt's movie and contact-sheet descriptions match these actual asset
names. No asset-name mismatch was found. The video is an approximately
136-second, 1920x1080, 30 FPS H.264 reference. Frames were inspected locally at
the required clusters; the two contact sheets were used only to cross-check
category coverage.

The production wardrobe may reuse the references' broad category, silhouette,
layering, proportion, and color ideas. It must not trace, crop, embed, recolor,
or otherwise derive pixels from the reference files. It must not reproduce
logos or protected marks. The stable IDs below name original project
interpretations and are not claims that the source outfits are project assets.

## Required cluster inventory

| Video cluster | Observed categories and silhouette | Reusable project components | Intended bindings | Proposed stable IDs |
| --- | --- | --- | --- | --- |
| 0-2 s | Wide-brim red headwear, fitted red upper and lower, tall legwear, elevated footwear | Hat, halter upper, tailored shorts, thigh-high legwear, strap shoe | Head point; torso; pelvis; every compatible shin/foot | `crimson_wide_brim_hat`, `crimson_halter_top`, `crimson_tailored_shorts`, `crimson_thigh_high`, `crimson_strap_shoe` |
| 3-4 s | Long asymmetric formal wrap/gown with split lower and arm accent | Wrap bodice, split skirt, long glove | Torso; pelvis; every compatible hand | `garnet_wrap_bodice`, `garnet_split_skirt`, `crimson_long_glove` |
| 5-9 s | Compact red two-piece followed by ribbon/bow accents and a waist sash | Modest sport upper/lower, ribbon upper, sash | Torso; pelvis; waist point | `scarlet_sport_top`, `scarlet_sport_shorts`, `ribbon_bodice`, `ribbon_waist_sash` |
| 10-11 s | Pink one-piece/romper silhouette | Romper torso and lower panels | Torso and pelvis | `rose_romper_torso`, `rose_romper_lower` |
| 12 s | Rabbit-ear-like headband, red upper, pink tall legwear, wrist cuffs | Abstract moon-ear headband, halter upper, tall legwear, cuffs | Head point; torso; every compatible shin/hand | `moon_ear_headband`, `crimson_halter_top`, `rose_thigh_high`, `ivory_wrist_cuff` |
| 13 s | Open long-sleeve cardigan over a red lower | Cardigan torso, repeated sleeves, tailored shorts | Torso; every compatible upper arm; pelvis | `crimson_cardigan_torso`, `crimson_cardigan_sleeve`, `crimson_tailored_shorts` |
| 14 s | Light blouse with red shorts | Ivory blouse body, repeated ivory sleeves, red tailored shorts | Torso; every compatible upper arm; pelvis | `ivory_blouse_torso`, `ivory_blouse_sleeve`, `crimson_tailored_shorts` |
| 15 s | Fantasy head/back accents, red upper/lower, dark patterned legwear | Ember crescent headband, wrap upper, tailored shorts, patterned legwear | Head point; torso; pelvis; every compatible shin | `ember_crescent_headband`, `crimson_wrap_top`, `crimson_tailored_shorts`, `ember_pattern_legwear` |
| 16 s | No removable garment visible | Base anatomy only | None | No wardrobe item; this is the empty loadout |
| 17-18 s | Simple asymmetric day dress, then puff-sleeve blouse with belt and short skirt | Dress torso/lower, puff blouse/sleeves, belt, mini skirt | Torso; pelvis; every compatible upper arm; waist point | `ruby_day_dress_torso`, `ruby_day_dress_lower`, `velvet_puff_blouse_torso`, `velvet_puff_sleeve`, `ebony_waist_belt`, `velvet_mini_skirt` |
| 19 s | One-shoulder upper, high-waist trousers, belt, single glove accent | One-shoulder top, pants, belt, long glove | Torso; pelvis; waist point; a specific hand | `crimson_one_shoulder_top`, `crimson_highwaist_pants`, `ebony_waist_belt`, `crimson_long_glove` |
| 20 s | Pillbox/nurse-like headwear, fitted upper, patterned legwear, long gloves, heels | Unmarked rose pillbox hat, halter upper, abstract mesh-pattern legwear, long gloves, strap shoes | Head point; torso; every compatible shin/hand/foot | `rose_pillbox_hat`, `crimson_halter_top`, `rose_mesh_legwear`, `crimson_long_glove`, `crimson_strap_shoe` |
| 21 s | Fitted upper, side-laced lower, thigh strap/accent | Ribbon bodice, side-laced shorts, waist/leg accent | Torso; pelvis; waist point | `ribbon_bodice`, `ivory_side_laced_shorts`, `ribbon_waist_sash` |
| 22-23 s | Fitted long-sleeve red suit with trousers and gloves | Fitted jacket, repeated fitted sleeves, fitted pants, gloves | Torso; every compatible upper arm; pelvis; every compatible hand | `ruby_fitted_jacket_torso`, `ruby_fitted_sleeve`, `ruby_fitted_pants`, `crimson_long_glove` |
| 24-26 s | Return to wide-brim red ensemble | Reuse the opening hat, upper, lower, legwear, and footwear | Same as 0-2 s | Reuse the 0-2 s component IDs; do not duplicate art |

## Catalog consequences

- Slot occupancy, render layer, coverage, and anatomy binding remain separate
  declarations.
- Paired sleeves, cuffs, gloves, legwear, and shoes use
  `every_compatible`; the item does not enumerate left/right sprite copies.
- Long lower garments use bounded segmented or deformable presentation and the
  existing secondary-motion path. They do not introduce cloth simulation.
- Hair remains selected by the character presentation system. Headwear is a
  separate equipment item layered over the crown without clearing or replacing
  the hair selection.
- Prompt 25 presets are recipes over reusable item IDs. The mandatory wide-brim
  ensemble and ivory-blouse/red-shorts ensemble use the same components that
  other presets and the custom recombination use.
- Every listed production item is cosmetic: no attribute modifier or capability
  grant is implied by its silhouette or source category.
