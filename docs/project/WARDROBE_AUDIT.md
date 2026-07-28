# Production Wardrobe Audit

Audit basis: [`wardrobe_catalog.zig`](../../src/scene/wardrobe_catalog.zig), [`wardrobe_presentation.zig`](../../src/scene/wardrobe_presentation.zig), [`visual_geometry.zig`](../../src/scene/visual_geometry.zig), Prompt 25D reports, and stored D3D12 goldens.

All 30 current items are cosmetic: no item contributes an attribute modifier or capability. Every visual component has front and canonical-side atlas bindings. Gameplay-facing side-left/side-right is resolved by the authoritative body projection; the current artwork is treated as mirror-safe. “Fragments” below means conventional two-arm/two-leg resolved visuals. A repeated recipe remains bounded for other compatible topologies.

## Complete item ledger

| Logical item | Occupied slot(s) | Anatomy/attachment binding | Visual fragments and current layers | Declared coverage | Fit / morphology / motion | Known limitation |
|---|---|---|---|---|---|---|
| `crimson_wide_brim_hat` | headwear | first head | 1 headwear (80) | head | wide-hat fit; head morphology 1.0; rigid | Always above single hair layer; no back/front hair composition |
| `moon_ear_headband` | headwear | first head | 1 headwear (80) | head | headwear-band fit; head morphology 1.0; rigid | No independent near/far ear fragments |
| `ember_crescent_headband` | headwear | first head | 1 headwear (80) | head | headwear-band fit; head morphology 1.0; rigid | Canonical-side reflection only |
| `rose_pillbox_hat` | headwear | first head | 1 headwear (80) | head | fitted-headwear fit; head morphology 1.0; rigid | No semantic hair-depth relation |
| `crimson_halter_top` | torso | first torso | 1 upper (68) | torso | sleeveless design-specific front/side coverage; torso morphology 1.0, breathing 0.92; rigid | Halter/neck intent is inferred from landmarks/zone, not first-class collar coverage |
| `garnet_wrap_bodice` | torso | first torso | 1 upper (68) | torso | sleeveless design-specific side span; torso morphology/breathing; rigid | Wrap detail is accepted as mirror-safe; no mixed directional trim policy |
| `scarlet_sport_top` | torso | first torso | 1 upper (68) | torso | sleeveless design-specific spans and female pivot; torso morphology/breathing; rigid | No shoulder-slope contour |
| `rose_romper` | torso, lower | first torso + first pelvis | 2: upper (68), lower (66) | torso, pelvis | torso/lower-shorts contracts; morphology follows anchors; rigid | Two components share item identity but no authored stable fragment names |
| `crimson_cardigan` | torso_outer, sleeves_outer | first torso + every upper arm | 3: upper_outer (74), 2 sleeves_outer (75) | torso, left/right arms | outer-torso + fitted-sleeve contracts; torso/arm morphology; sleeve secondary motion | Numeric depth only; no separate back panel/lapel/tail |
| `ivory_blouse` | torso, sleeves | first torso + every upper arm | 3: upper (68), 2 sleeves (69) | torso, left/right arms | design-specific torso side span + puff-sleeve fit; torso/arm morphology; sleeve secondary motion | Mirror-safe control; no authored directional variant or shoulder-slope contour |
| `ruby_day_dress` | torso, lower | first torso + first pelvis | 2: upper (68), long_lower (70) | torso, pelvis, left/right legs | sleeveless torso + design-specific long-lower fit; morphology follows anchors; rigid | Lower is one sprite; no rear/front or far/near dress panels |
| `crimson_strap_shoes` | footwear | every foot | 2 footwear (72) | left/right feet | strap-shoe registration, axes, size, and intended coverage; foot morphology 1.0; rigid | Source-axis polarity has semantic foot handling, but no per-fragment authored reflection declaration |
| `velvet_puff_blouse` | torso, sleeves | first torso + every upper arm | 3: upper (68), 2 sleeves (69) | torso, left/right arms | design-specific torso spans + puff-sleeve fit; sleeve secondary motion | Puff clearance is fit-specific; shoulder/armhole slope is not first-class |
| `crimson_one_shoulder_top` | torso | first torso | 1 upper (68) | torso | asymmetric bounded coverage zone and span; torso morphology/breathing; rigid | Front asymmetry exists, but side is accepted as mirror-safe and has no mixed directional policy |
| `ruby_fitted_suit` | torso, sleeves, lower | first torso + every upper arm + first pelvis | 4: upper (68), 2 sleeves (69), lower (66) | torso, arms, pelvis, legs | fitted torso/sleeve/pants contracts; morphology follows anchors; rigid | Jacket has no back/lapel/front depth fragments |
| `ribbon_bodice` | torso | first torso | 1 upper (68) | torso | design-specific side span/coverage; torso morphology/breathing; rigid | Directional ribbon detail cannot opt into an authored side variant today |
| `crimson_long_gloves` | gloves | every hand | 2 gloves (73) | left/right hands | long-glove wrist/hand axis and coverage; hand morphology 1.0; rigid | One visual covers cuff/hand role; no separate cuff depth |
| `ivory_wrist_cuffs` | wrist | every hand | 2 gloves (73) | left/right hands | cuff wrist registration; hand morphology 1.0; rigid | Uses gloves render layer; no semantic “around wrist” depth relation |
| `ribbon_waist_sash` | waist | `waist_pelvis` attachment | 1 waist (76) | none in equipment coverage list | waist-sash fit; attachment morphology 1.0; rigid | Visual coverage is fit metadata only; ribbon tails are not separate motion fragments |
| `ebony_waist_belt` | waist | `waist_pelvis` attachment | 1 waist (76) | none in equipment coverage list | waist-belt fit; attachment morphology 1.0; rigid | Named numeric layer instead of semantic in-front-of-waist relation |
| `crimson_tailored_shorts` | lower | first pelvis | 1 lower (66) | pelvis | lower-shorts fit with sex/view pivot corrections; pelvis morphology 1.0; rigid | One panel; leg openings are landmarks, not fragments |
| `scarlet_sport_shorts` | lower | first pelvis | 1 lower (66) | pelvis | design-specific side scale + lower-shorts fit; pelvis morphology; rigid | One panel and numeric depth |
| `velvet_mini_skirt` | lower | first pelvis | 1 lower (66) | pelvis | design-specific side clearance + lower-mini fit; pelvis morphology; rigid | No rear/front or far/near skirt panels |
| `crimson_highwaist_pants` | lower | first pelvis | 1 lower (66) | pelvis, left/right legs | lower-pants contract with side coverage zone; pelvis morphology; rigid | Legs are painted within one pelvis-bound visual, not independently articulated trouser fragments |
| `ruby_fitted_pants` | lower | first pelvis | 1 lower (66) | pelvis, left/right legs | lower-pants contract with side coverage zone; pelvis morphology; rigid | Same one-visual leg limitation |
| `ivory_side_laced_shorts` | lower | first pelvis | 1 lower (66) | pelvis | lower-shorts fit; pelvis morphology; rigid | Side lacing is accepted as mirror-safe; no directional detail policy |
| `garnet_split_skirt` | lower | first pelvis | 1 long_lower mesh (70) | pelvis, left/right legs | split-skirt fit; pelvis morphology; deformable mesh + skirt secondary motion | One mesh cannot independently order rear/far and front/near panels |
| `crimson_thigh_high` | legwear | every lower leg | 2 legwear (71) | left/right legs | fitted-legwear axis/coverage; lower-leg morphology 1.0; rigid | Lower-leg binding only; top band has no independent thigh relation |
| `rose_mesh_legwear` | legwear | every lower leg | 2 legwear (71) | left/right legs | fitted-legwear axis/coverage; lower-leg morphology; rigid | Canonical-side reflection only |
| `ember_pattern_legwear` | legwear | every lower leg | 2 legwear (71) | left/right legs | view-specific coverage thresholds; lower-leg morphology; rigid | Pattern is accepted as mirror-safe; no authored direction policy |

## View and reflection audit

- Required current views: front and canonical side for all 36 visual components.
- Current side reflection behavior: all production components follow gameplay-facing projection; no component supplies an authored `side_left`/`side_right` variant.
- Identity behavior: the loadout, `EquipmentItemId`, recipe IDs, and resolved visual state persist across view/facing changes.
- Resource behavior: art pages and component bindings are resolved during initialization. Turning does not decode images or create GPU resources.

## Focused production inspections

### Ivory blouse — directional control

Current representation: one torso recipe plus an `every_compatible` puff-sleeve recipe, resolving to three conventional fragments. The blouse uses front and one canonical-side source.

Inspection result: the accepted side source has no directional placket, bow, wrap overlap, or false back/front cue. In the stored `06_ivory_blouse_side` D3D12 golden it faces with the body; the visual-geometry acceptance matrix evaluates both `side_left` and `side_right`. It is correctly classified as mirror-safe.

Contract capability: current runtime represents this item correctly. Future asymmetric blouses require the documented authored-directional or mixed-fragment policy.

Source change required for Prompt 25E: **no**.

### Crimson halter top — neck opening

Current representation: one torso-bound sprite with per-item front/side coverage and span values. It intentionally exposes the neck and part of the upper chest.

Inspection result: current fit is accepted as a low-neck/halter design. It must not be reclassified as a high-neck garment merely because some opaque pixels approach the neck.

Contract capability: current fit contract is sufficient for this accepted low-neck item. It is insufficient for a future garment declaring collar-band coverage or rear/front collar depth.

Smallest future correction: add explicit semantic neck/collar coverage plus bounded collar fragments/order when a production item needs them.

### Ivory blouse / ruby fitted jacket — shoulder fit

Current representation: torso art uses neck/shoulder/chest/waist landmarks and repeated sleeve components. Current torso shoulder landmarks form a span and do not encode neck-to-shoulder slope or armhole contour.

Inspection result: Prompt 25D art and pixel continuity are accepted at current poses and morphology matrix. The limitation is representational, not a current visible regression.

Smallest future correction: add fixed shoulder-contour landmarks/slope and sleeve-armhole registration to `visual_geometry`, driven by style/view/semantic component.

### Garnet split skirt and ruby day dress — body depth

Current representation: the split skirt is one deformable mesh at `long_lower`; the day-dress lower is one rigid sprite at the same layer.

Inspection result: accepted current captures do not require a limb to cross between independently ordered panels. The documented reusable skirt/dress contract can represent rear/central/front or far/central/near fragments, but the runtime’s author-facing semantic depth relation is not implemented.

Source change required for Prompt 25E: **no**; reauthoring accepted art solely to make a schema example would be out of scope.

### Long hair with headwear

Current representation: hair is an independently addressable character-presentation visual. Headwear uses numeric layer 80 above it.

Inspection result: current combinations are accepted. The system does not yet represent back hair → headwear → front hair as three semantic fragments.

Smallest future correction: ordinary fragments with body-relative head depth; no item-specific hat/hair branch.

### Mirror-safe control

`crimson_tailored_shorts` is a simple one-fragment control. Its front/canonical-side sources have no one-sided construction that becomes false under reflection, and both semantic sides remain bound through the authoritative pelvis projection.

## Audit conclusion

The current production wardrobe fits the accepted Prompt 25D scope. The audit found no art or runtime regression requiring a Prompt 25E source correction. It also found five concrete future-authoring gaps: stable fragment names, semantic body-relative depth, explicit directional selection, first-class collar coverage, and shoulder-slope/armhole geometry. Implementing them without a production consumer would create unused abstractions and is therefore deferred to the first authorized milestone that requires them.
