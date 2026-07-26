# Character Attributes, Capabilities, and Equipment Effects

## Boundary and ownership

Prompt 21 inserts one renderer-independent gameplay-property layer:

```text
explicit base character data
    + active bounded modifier/grant sources
    -> deterministic character property resolution
    -> resolved numeric attributes and capability source counts
    -> controller, future inventory, future combat, or another consumer
```

`character_properties.zig` owns the generic typed IDs, definition metadata, source keys, bounded builder, stacking rule, and resolved value. It imports no controller, equipment, renderer, camera, SDL, GPU, inventory, or combat module. Equipment remains one declaration source. The final resolved set is character-owned and is recomputed from current active data after initialize, equip, unequip, replace, and reset.

Definitions and active records use compact definition-local `u16` IDs. Stable strings are copied and resolved during definition initialization; no fixed tick performs a string or hash lookup. Appearance presets, presentation profiles, morphology channels, visible limb size, face selection, and hair selection are not property sources. Gameplay differences must be explicit base values or modifiers/grants.

## Attribute definitions and validation

An attribute definition contains:

- a typed `AttributeId`;
- a bounded stable identifier for initialization and diagnostics;
- a finite default base value;
- a finite inclusive minimum and maximum.

Definitions reject non-finite values, reversed ranges, and a base outside its range. A character may supply explicit bounded base overrides through the generic builder; duplicate overrides, invalid IDs, non-finite values, and values outside the definition range are rejected.

The representative catalog defines:

| Attribute | Base | Inclusive range | Current consumer |
| --- | ---: | ---: | --- |
| `movement_speed` | `4.5` | `[0.1, 20]` | Character controller |
| `jump_strength` | `9.0` | `[3.51, 30]` | Character controller |
| `carrying_capacity` | `50` | `[0, 10000]` | Queryable; future inventory |
| `armor` | `0` | `[0, 10000]` | Queryable; future combat |
| `physical_damage_reduction` | `0` | `[0, 0.95]` | Queryable; future combat |

Future inventory and damage systems must query the character's resolved set. They must not scan equipped items or infer values from visual coverage.

## Numeric stacking

The only operations are `add` and `multiply`. Add amounts may be any finite `f32`. Multipliers must be finite and inside `[0, 16]`. Resolution uses exactly:

```text
resolved = clamp((base + additive_total) * multiplier_product, minimum, maximum)
```

The builder copies at most 256 modifiers into fixed storage and insertion-sorts them by attribute ID, operation (`add` before `multiply`), source-kind ID, source instance ID, then source-local ordinal. Accumulation uses `f64`; the bounded result is converted to `f32`. Caller order, pointer identity, allocation address, and hash iteration therefore cannot choose the stacking sequence.

The source key is a compact `(source_kind, source_instance)` pair. Equipment uses one stable source kind and its `EquipmentItemId` as the instance. The generic resolver does not interpret that key. A later bounded temporary-effect system can submit its own stable source kind and records without adding a central switch over property names.

## Capabilities

Capabilities are separate from numeric attributes. A capability definition has a typed `CapabilityId`, a stable identifier, and an optional explicit base/default grant. Active grants identify a stable source.

Resolution counts current independent sources per capability. Two sources granting `double_jump` produce count two. Removing either source and recomputing produces count one, so the capability remains active. Duplicate grants from the same source are rejected. No equip path imperatively writes `can_double_jump = true` and no unequip path blindly clears a Boolean.

The representative capabilities are `double_jump` and `dash`. Items are never named or visually classified inside the controller.

## Controller consumption

`CharacterInstance.stepController` creates a compact `GameplayProperties` value from the current resolved set and passes it to the existing controller. A character without initialized property definitions uses the controller configuration unchanged.

- `movement_speed` supplies the per-character target and clamp speed. It never mutates the shared `Configuration`.
- `jump_strength` supplies accepted grounded, coyote, buffered, and air-jump launch velocity. Jump buffering, coyote timing, early-release clamping, gravity, grounding, and collision retain their existing order.
- `double_jump` permits exactly one additional air jump. A valid ground contact or full reset clears `air_jumps_used`. Removing the capability while airborne does not rewrite velocity and does not clear the used count; it prevents a new air jump while absent. A pending jump edge is checked against the capability on each bounded buffer tick.
- `dash` permits a small horizontal controller action on the platform-neutral dash edge.

Default resolved movement and jump values are exactly `4.5 m/s` and `9.0 m/s`, preserving Prompt 0-20 controller behavior. A regression test executes the same 240-tick trace through `step` and `stepWithProperties` and requires identical step results and controller state.

## Dash contract

The dash input is Left Shift or the gamepad right shoulder. It follows the established `SDL state -> FrameInputSnapshot -> PendingInput -> CharacterIntent` path and survives a zero-substep frame exactly once.

- Allowed states: grounded or airborne, when the resolved `dash` capability is active.
- Direction: current movement intent when its magnitude reaches the existing facing threshold; otherwise the current facing.
- Speed: `12 m/s`.
- Active duration: `0.12 s`, resolved to 29 fixed ticks.
- Reuse gate: `0.12 + 0.20 s`, resolved to 77 fixed ticks from start.
- Collision: the normal horizontal sweep remains authoritative; a wall zeros horizontal velocity and ends the active dash. Gravity, vertical sweep, ceiling, ground, and landing behavior continue.
- Facing: the dash starts in its selected direction and holds that direction for the active dash.
- Capability removal: an already-started bounded dash may finish; removal prevents the next dash.
- Reset: controller reset clears active duration, reuse timer, direction state, and all jump counters.

There is no action framework, damage, attack, invulnerability, status timer, or combat event attached to dash.

## Bounded evidence

Pure and integrated coverage lives in `tests/character_properties_tests.zig`. The GPU-backed deterministic evidence route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo properties
```

Initialization runs actual controller steps for default/modified movement, default/stronger jump, denied/allowed double jump, denied/allowed dash, and dash collision. It also proves carrying capacity, armor, physical damage reduction, duplicate-source removal, restoration, and two-character isolation. The visible phase submits the two independently equipped characters through the existing one-range, one-draw sprite batch. The route fails on missing behavioral evidence, frame mismatch, fixed-buffer growth, batch allocation, or property-created GPU resources.

## Prompt 22 integrated consumers

The foundation playground resolves the same generic attributes/capabilities from its mixed sprite/mesh loadout and feeds only the compact `GameplayProperties` value to the existing controller. Its bounded script reaches the speed-modified terminal run velocity, compares actual accepted launch velocities before and after stronger-jump boots, consumes one granted air jump, and starts one granted collision-aware dash. Carrying capacity, armor, and physical damage reduction are queried into diagnostics only because inventory and combat consumers do not yet exist.

Appearance changes and topology rebinds may change visual cardinality but cannot add a modifier or capability. Attribute/capability resolution may change controller behavior but cannot create or select render resources. Reset reconstructs the default resolved set from the restored loadout and clears air-jump/dash state; no stale source count survives.
