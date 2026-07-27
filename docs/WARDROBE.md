# Modular Wardrobe Catalog

Prompt 25 stress-tests the Prompt 17 equipment model with original, reusable clothing rather than full-outfit sprites. The production catalog contains 30 cosmetic items, 36 independently addressable visual components, 15 presets, and one custom recombination. Every component has a side and front binding, giving 72 atlas regions across three physical PNG pages.

The reference-derived category inventory and project-local IDs are recorded in `OUTFIT_REFERENCE_INVENTORY.md`. Reference material was used only to identify garment categories, silhouettes, layering, proportions, and broad color families. The production pixels are original and contain no source-game crop, trace, logo, text, or symbol.

## Semantic model

The runtime composition is:

```text
base anatomy
  -> ordinary clothing layers
  -> outer clothing layers
  -> equipment and accessories
```

The following concepts remain independent:

- `EquipmentSlotId` controls incompatible occupancy.
- `VisualLayerId` controls semantic draw order.
- `BodyRegionId` records coverage.
- `VisualComponentId` identifies reusable garment geometry.
- `PresentationSemanticId` identifies one garment across side/front art.
- `OutfitPresetId` is only a typed convenience list of item IDs.

For example, `ivory_blouse` occupies `torso` and `sleeves`, covers torso and both arms, and renders on `upper` and `sleeves`. `crimson_cardigan` occupies `torso_outer` and `sleeves_outer`, covers the same body regions, and renders on `upper_outer` and `sleeves_outer`. They can coexist because shared coverage does not imply a slot conflict, and outer draw order is not inferred from occupancy.

All Prompt 25 items declare zero attribute modifiers and zero capability grants. A hat, dress, shoe, or glove cannot implicitly grant armor, speed, jump, dash, or double jump.

## View and topology resolution

`wardrobe_presentation.Presentation` resolves both art views for every component during initialization. At submission it selects the already-resolved side or front record from the character's current presentation view. Changing view never changes the equipped item ID and performs no string lookup, image decode, allocation, or GPU-resource creation.

Sleeves, gloves, legwear, and footwear use `every_compatible` anatomy-role recipes. One sleeve recipe therefore yields two conventional-arm visuals and four visuals on the existing four-arm test topology. One shoe component binds separately to the semantic left and right foot instances. Equipment selection does not write canonical foot sockets, physics, foot planting, facing, or locomotion state.

Long female hair remains base character presentation. Headwear is a separate item and renders at the explicit `headwear` layer above the single bounded hair presentation, so selecting a hat never deletes or replaces the hair definition.

## Long garments

`garnet_split_skirt` uses the existing deformable-mesh and attachment-secondary-motion systems. Side and front meshes are immutable, uploaded during renderer initialization, and selected by view. Each resolved visual owns its existing bounded mesh and spring state. Unequip, replacement, topology rebind, and reset rebuild the transactional loadout and clear removed state. No general cloth simulation is introduced.

## Presets and custom composition

The 15 stable preset IDs are:

```text
wide_brim_crimson
garnet_formal
scarlet_sport
ribbon_sash
rose_romper
moon_cuffs
crimson_cardigan
ivory_blouse_red_shorts
ember_fantasy
base_only
ruby_day_dress
velvet_puff
one_shoulder_trouser
rose_pillbox
ruby_fitted_suit
```

`wide_brim_crimson` and `ivory_blouse_red_shorts` are mandatory production entries. Reused items include `crimson_tailored_shorts` in at least five presets and `crimson_strap_shoes` in at least ten. `customItems()` combines the wide-brim hat, ivory blouse, outer cardigan, velvet skirt, patterned legwear, long gloves, and shoes from existing presets without creating a monolithic outfit texture.

`Loadout.replaceAll` builds and validates a bounded candidate before committing it. Explicit selection and O-key cycling preserve body/hair selection, facing, presentation view/override, controller and physics state, animation state/time, camera, and unrelated properties. Failure leaves the prior fingerprint unchanged.

## Adding wardrobe content

### Add a garment

1. Add one stable `VisualSpec` per independently reusable component in `wardrobe_catalog.zig`. Assign a unique typed presentation semantic, anchor, authored size, and pivot.
2. Add original side/front art to an appropriate wardrobe atlas. Physical page choice is only a batching decision.
3. Add the paired region and binding metadata in `wardrobe_art.zig`; both views use the same presentation semantic and distinct region IDs.
4. Add an `EquipmentItemInput` in `wardrobeItems()`, referencing existing slots, anatomy roles, body regions, and visual layers.
5. Use an existing sprite, mesh, or secondary-motion primitive. Add a new core primitive only when the garment truly cannot be expressed by the established ones.
6. Add or extend validation, focused tests, and visual acceptance for both views.

Ordinary garments do not require edits to `equipment.Loadout`, topology matching, transaction logic, character control, or rendering algorithms.

### Add a view-specific visual

Add a distinct region for the new view and bind it to the component's existing `PresentationSemanticId`. Keep item identity unchanged. `Presentation.init` will reject a component without a complete side/front pair or with both views pointing to the same region.

### Add an equipment slot

Add a stable slot record to the catalog's `EquipmentSlotInput` list, then reference it from relevant items. Add a visual layer only if draw order also changes; add coverage only if semantic coverage changes. Do not encode either fact by reusing the slot name implicitly.

### Add an outfit preset

Add one `PresetSpec` with a stable ID and existing item stable names. Keep it within the bounded item capacity. Catalog initialization resolves names once to typed item IDs, and validation plus selection rejects duplicate/conflicting occupancy.

## Demonstration

Run the deterministic GPU-backed route:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo wardrobe --scripted-input --frames 600
```

It cycles every preset through front and side presentation, then shows the custom recombination while the female character walks, jumps, lands, breathes, and updates garment secondary motion. A male character sharing the immutable definition remains unequipped and unchanged. Startup loads five total production art pages and two persistent skirt mesh definitions; the cycle itself must report zero allocation and zero GPU-resource delta.

For inspection:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo wardrobe --interactive
```

Use O to cycle presets, P to pause simulation, Q to cycle automatic/side/front presentation, and R to reset the character and first preset. Physical keyboard use is a manual acceptance activity; the automated suite tests the platform-neutral mappings and synthetic edge semantics.
