# Breathing and shared appearance deformation

## Boundary and ownership

Prompt 18 adds one CPU-only resolved deformation stage shared by modular anatomy and topology-expanded equipment visuals. Immutable anatomy, appearance, and equipment definitions contain only deformation bindings and response metadata. Each character owns its morphology overrides, bounded breathing phase/configuration, resolved part transforms, and loadout records. No definition is mutated and procedural breathing is never written into the selected preset, global build value, channel overrides, or per-instance overrides.

This is visual deformation. It cannot write the physics root, controller position or velocity, collider extents, grounded/support state, canonical skeleton lengths, interaction state or timing, equipment modifiers, capabilities, or character attributes. It creates no GPU resource. Resolved sprites still enter the existing global `SpriteBatch`.

## Resolved data flow

For each active anatomy instance, the runtime resolves:

1. the selected morphology preset range;
2. global build;
3. an optional channel override;
4. an optional anatomy-instance/channel override;
5. the immutable part morphology bindings;
6. that character's current procedural breathing sample;
7. the immutable part breathing binding;
8. the consuming visual's morphology and breathing response strengths.

The shared `deformation.resolve` function is the only formula used by skin visuals and anatomy-bound clothing/equipment. Response strengths are finite normalized values:

- `1` applies the full relevant deformation;
- a value between `0` and `1` attenuates it;
- `0` opts out.

Body skin defaults to full response. The demonstration data gives chest underwear near-full morphology response, shirts full response, a sweatshirt substantial response, flexible sleeves full morphology and attenuated breathing response, and rigid armor/gauntlets little or no soft response.

The resolved anatomy runtime retains both:

- `part_binding_world`: the instance's undeformed binding matrix;
- `part_world`: the fully deformed anatomy matrix used by descendants.

An anatomy-bound equipment record already retains its exact `BodyPartInstanceId`. Submission therefore evaluates `part_binding_world * recipe_local * resolved_component_deformation` for that exact instance. Four sleeves expanded from one recipe remain bound to four distinct arms; they are never collapsed into a left/right transform pair.

## Breathing clock

`BreathingState` is character-owned and allocation-free. Its period is an integer number of authoritative 240 Hz ticks. The default period is 960 ticks (4 seconds). Valid periods are bounded from 4 ticks through 10 minutes, and amplitude is finite in `[0, 1]`. A rate can be supplied only when it maps to an integer tick period within `1e-4` tick; the resolved rate is `240 / period_ticks`.

The state stores only `cycle_tick`, advances with bounded integer wrap, and derives phase from that tick. It never integrates floating phase, reads wall-clock time, or depends on render frames. Reset returns phase to tick zero without baking breathing into morphology. Setting phase or configuration recomputes derived appearance immediately.

The authored modular body opts the torso into a restrained maximum horizontal scale delta of `0.03`, a vertical delta of `0.012`, and a `0.006 m` local translation before per-character amplitude and per-visual response. Upper arms and chest-adjacent anatomy have smaller explicit bindings. Tail, horns, legs, face, hair, pelvis, hands, and feet have zero breathing binding unless future definitions explicitly opt in.

## Composition order

The fixed-tick execution order is:

1. sample authored animation into canonical local pose;
2. apply walk bounce;
3. apply landing compression;
4. apply the existing secondary spring/head follow-through;
5. advance the character-local breathing tick;
6. evaluate the canonical hierarchy from the physics root with character facing reflection;
7. perform foot planting and/or interaction arm IK when active, then reevaluate the canonical hierarchy;
8. resolve attachment points and module joints/sockets from the final canonical pose;
9. resolve base body morphology and procedural breathing per anatomy instance;
10. resolve each skin/clothing/equipment response from the same instance deformation;
11. submit all visible records through the global batch.

IK remains canonical-pose authority; breathing does not alter its inputs or segment lengths. Facing is one character-root reflection and therefore reflects the already-resolved visual result without swapping anatomy identities.

The matrix order for an anatomy visual is `source_world * attachment_local * resolved_deformation`. For anatomy-bound equipment it is `part_binding_world * recipe_local * resolved_deformation`. Because column vectors are used, the resolved deformation acts first on visual-local points, followed by the authored attachment-local transform and then the final animated/IK/facing source hierarchy. Body morphology is composed first in the resolved transform's components and breathing second; breathing is always regenerated from base state.

## Runtime changes and future material state

Preset, build, channel override, part override, phase, and breathing configuration changes recompute existing bounded arrays. Loadout changes may rebuild the Prompt 17 fixed-capacity resolved visual records. None of these changes creates textures, buffers, pipelines, samplers, shaders, or other GPU objects. Steady-state breathing and morphology do not allocate.

Resolved equipment visuals are character-owned per-instance records with stable recipe and anatomy-source identity. Future wetness or other material state can be stored beside those records without mutating immutable assets or changing the deformation resolver. Prompt 18 does not implement wetness, rain, liquids, mud, snow, blood, temperature, or material simulation.

## Evidence

Pure deterministic coverage is in `tests/deformation_tests.zig`. It covers neutral/extreme samples, long-run cycles, reset, independent characters, shared body/clothing resolution, exact four-sleeve binding, isolated part overrides, rigid opt-out, composition, loadout changes, physics/controller/IK/effect invariance, interaction timing, render grouping, and fixed-buffer no-growth.

The bounded GPU-backed route is:

```text
zig build run -- --frames 240 --demo breathing
```

It advances four 240 Hz ticks per nominal frame for one complete four-second breathing cycle, renders two different character-local rates/phases, keeps the four-arm sweatshirt topology, performs an isolated extra-arm sleeve override, checks rigid opt-out and gameplay invariants, and requires one global draw range/draw call with zero steady-state allocation or GPU-resource growth.
