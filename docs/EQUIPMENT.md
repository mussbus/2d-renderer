# Equipment, Clothing, and Loadouts

Prompt 17 extends the Prompt 15/16 definition architecture with declarative equipment. The runtime data flow is:

```text
DefinitionInputs
    -> Definition validation and name-to-ID resolution
    -> immutable DefinitionView
    -> character-owned bounded Loadout
    -> generic character visual submission and gameplay consumers
```

No editor, serialization format, inventory economy, combat, health, status-effect, persistence, or movement-capability behavior is implemented. A future editor or data loader may produce the same `DefinitionInputs`; it must pass through the same validation and runtime.

## Separate concepts

The implementation deliberately does not use one universal slot:

- An `EquipmentSlotId` claims exclusive logical loadout capacity. Shirt, outerwear, torso armor, chest undergarment, neck accessory, and backpack are distinct slots even when several cover the torso.
- An `AnatomyRoleId` names a reusable compatibility rule. The current representative catalog resolves roles to data-defined anatomy part-type tags such as `torso`, `upper_arm`, `hand`, and `foot`.
- An `AttachmentPointId` is an existing appearance transform source such as `neck` or `upper_back`; it is not an equipment slot or anatomy instance.
- A `BodyRegionId` records semantic coverage independently of occupancy and geometry.
- A `VisualComponentId` identifies immutable sprite data.
- An `ItemVisualRecipeId` combines a component, a semantic binding rule, a local transform, a covered region, and a `VisualLayerId`.
- A `VisualLayerId` maps declarative clothing order to the existing integer body-part draw layer.
- `AttributeId` and `CapabilityId` identify gameplay declarations. The renderer does not inspect them.

All are compact typed IDs after initialization. Bounded inline `DebugName` values exist only in immutable definition metadata and initialization lookup. Equip, unequip, replacement, reset, visual expansion, effect queries, fixed-tick updates, and rendering perform no string or hash lookup.

## Immutable definition validation

`equipment.Definition.init` copies initialization inputs into contiguous owned arrays and rejects:

- duplicate stable IDs in every registry;
- missing slot, role, visual layer, visual component, anatomy instance, attachment point, body region, attribute, capability, item, and default-loadout references;
- empty items with no occupancy, visual, modifier, or capability declaration;
- duplicate slots, regions, modifiers, or capabilities inside one item;
- invalid or non-finite sprite, transform, pivot, tint, UV, or modifier data;
- invalid match cardinality or a specific anatomy instance that does not satisfy its declared role;
- aggregate counts beyond documented fixed maxima;
- duplicate or slot-conflicting default items.

Every allocation is paired with reverse-order `errdefer` cleanup. A completed definition owns all copied arrays and releases them explicitly in `deinit`.

## Topology-aware visual recipes

An anatomy recipe supports:

- `first_compatible`: resolve once to the first active compatible anatomy instance;
- `every_compatible`: expand in ascending anatomy-instance ID order;
- `specific_instance`: bind once to a named instance resolved to `BodyPartInstanceId` during definition initialization;
- `required = false`: allow zero matches without invalidating the item;
- `required = true`: reject the complete equip transaction when no match exists;
- `maximum_matches`: reject expansion beyond the authored bound.

The reusable `long_sleeve_sweatshirt` contains one torso recipe and one `every_compatible` upper-arm recipe. A conventional preset resolves two sleeve instances. The nonstandard Prompt 16 fixture now contains two additional instances of the same optional upper-arm definition and resolves four sleeve instances. There is no four-arm sweatshirt definition.

Resolved visuals store only item ID, recipe ID, and a typed source union containing a body-part instance ID or attachment-point ID. They do not cache mutable world transforms. Submission reads the current character-owned anatomy or appearance matrix, applies the recipe-local transform, and sends the sprite through `CharacterInstance.submitAttachments` and the existing global `SpriteBatch`.

## Transactional loadouts

`Loadout` is embedded per character and contains fixed-capacity arrays for:

- at most 24 equipped items;
- 32 slot occupants;
- 96 resolved visuals;
- 96 active numeric modifiers;
- 64 active capability grants;
- 96 coverage records.

Equip, explicit replacement, unequip, reset-to-default, and topology rebind copy the bounded loadout value, validate and rebuild the candidate, and commit with one assignment only after success. A failed required match, conflict, invalid ID, or capacity check leaves the original loadout bit-for-bit unchanged.

Equipped items are maintained in ascending `EquipmentItemId` order. Slot occupancy, visuals, coverage, modifiers, and grants are rebuilt in item-definition order, recipe order, and anatomy-instance order. Request order therefore cannot change listing or rendering order.

Explicit replacement removes every item conflicting with any candidate slot in the temporary value, then validates the complete candidate. This handles one item replacing several independently equipped pieces and a multi-slot item being replaced without a partial state.

Reset first restores the character's default anatomy preset, then atomically rebuilds the definition's default loadout. Mutable loadout state is never shared between characters.

## Coverage and gameplay declarations

Coverage records are independent of logical slots. Underwear, a shirt, a sweatshirt, armor, and an accessory may coexist while covering the same torso region. Coverage is metadata only; Prompt 17 never hides base anatomy automatically. Actual geometry, visibility, and draw order remain authoritative.

Numeric modifiers record source item, typed attribute, `add` or `multiply`, and a finite amount. Capability records contain source item and typed capability. Queries return deterministic slices or answer `hasCapability`; unequip and reset remove declarations by rebuilding the active view. Prompt 17 does not combine modifiers into final character statistics and does not implement double jump or dash. Those consumers must use IDs rather than item names or sprite types.

Representative definitions cover underwear, a chest undergarment, short-sleeve shirt, long-sleeve sweatshirt, socks, shoes, bilateral shoulder armor and gauntlets, multi-slot full plate, amulet, backpack, speed boots, and double-jump boots. Attribute definitions include armor, physical damage reduction, movement speed, jump strength, and carrying capacity; capability definitions include double jump and dash.

## Rendering and authority

Equipment creates no GPU resource, SDL object, controller state, physics state, animation state, IK state, or interaction state. It imports neither SDL nor the sprite batch. The character visual consumer resolves the generic visual records and submits them through the same batch used by anatomy and debug visuals.

Facing is inherited from the reflected character root. Canonical animation, procedural offsets, IK, foot planting, and handshake layer overrides remain authoritative for their existing bones and visuals. Equipment cannot write canonical pose locals, roots, colliders, clocks, sockets, locks, or layer-override ownership.

## Demonstration

The bounded route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo equipment
```

It renders a two-arm and four-arm character with the same sweatshirt definition, multiple simultaneous clothing layers, independent left/right armor, a multi-slot armor replacement transaction, an amulet, a backpack, independent loadouts, deterministic modifier/capability reporting, conflict rejection, unequip/restoration, one texture page, and one actual indexed-instanced draw. It fails if sleeve counts are not exactly two and four, any transaction evidence is missing, fixed-buffer usage changes after initialization, equipment creates GPU resources, or rendering leaves the global one-range/one-draw path.

## Intentional limitations

- Compatible roles currently match an exact data-defined anatomy part-type tag. More expressive tag predicates may be added as definition data without changing loadout algorithms.
- Equipment visuals are rigid sprite components. Deformable clothing belongs to Prompt 19.
- Active modifiers are declarations, not a final stacking-resolution policy.
- Capability grants are declarations; controller consumption belongs to Prompt 21.
- Changing topology with equipped required items calls bounded rebind validation. Ordinary gameplay should validate a proposed topology/loadout pair before exposing a topology change that may be rejected.
