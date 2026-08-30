# Breathing and shared appearance deformation

## Boundary and ownership

Prompt 18 adds one CPU-only resolved deformation stage shared by modular anatomy and topology-expanded equipment visuals. Immutable anatomy, appearance, and equipment definitions contain only deformation bindings and response metadata. Each character owns its morphology overrides, bounded breathing phase/configuration, resolved part transforms, and loadout records. No definition is mutated and procedural breathing is never written into the selected preset, global build value, channel overrides, or per-instance overrides.

This is visual deformation. It cannot write the physics root, controller position or velocity, collider extents, grounded/support state, canonical skeleton lengths, interaction state or timing, equipment modifiers, capabilities, or character attributes. It creates no GPU resource. Resolved sprites enter the existing `SpriteBatch`; resolved meshes enter the unified queue with the same semantic key.

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

An anatomy-bound equipment record already retains its exact `BodyPartInstanceId`. Sprite submission evaluates `part_binding_world * recipe_local * resolved_component_deformation` for that exact instance. Mesh submission sends `part_binding_world * recipe_local` and the same resolved component deformation as separate GPU instance fields. Each immutable mesh vertex has one normalized weight; the mesh vertex shader interpolates between its base local position and the resolved affine-deformed position, then applies the binding/world matrix. Four sleeves expanded from one recipe remain bound to four distinct arms; they are never collapsed into a left/right transform pair.

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
11. advance and compose any Prompt 20 per-visual bounded attachment secondary transform;

Prompt 22 exercises that exact order on one moving controlled character with global/part morphology, fixed-tick breathing, a topology-generated long-sleeve mesh, fitted torso mesh, rigid armor, cape motion, and selectable long hair. There is no demo-local deformation calculation. Rigid armor opts down or out through its existing declarative response, while body, fitted mesh, and sleeves sample the same anatomy runtime and breathing phase. The bounded route records a full breathing range and nonzero secondary displacement while controller roots, collision, handshake geometry, attributes, and capabilities remain independent.
12. submit all visible records through the sprite batch or unified mixed queue.

IK remains canonical-pose authority; breathing does not alter its inputs or segment lengths. Facing is one character-root reflection and therefore reflects the already-resolved visual result without swapping anatomy identities.

The matrix order for an anatomy visual is `source_world * attachment_local * resolved_deformation * attachment_secondary`. For anatomy-bound equipment it is `part_binding_world * recipe_local * resolved_deformation * attachment_secondary`. The sprite path composes that matrix on the CPU into the existing sprite record. The mesh path combines the two finite local deformation component sets and sends that weighted local result separately from the binding matrix: the GPU applies weighted local deformation first and the binding matrix second. Because column vectors are used, the authored attachment-local transform and final animated/IK/facing source hierarchy follow the deformation. Body morphology is composed first, breathing second, and attachment secondary motion last; breathing and motion are always regenerated from their respective base/runtime state.

## Runtime changes and future material state

Preset, build, channel override, part override, phase, and breathing configuration changes recompute existing bounded arrays. Loadout changes may rebuild the Prompt 17 fixed-capacity resolved visual records. None of these changes creates textures, buffers, pipelines, samplers, shaders, or other GPU objects. Steady-state breathing and morphology do not allocate.

Resolved equipment visuals are character-owned per-instance records with stable recipe and anatomy-source identity. Future wetness or other material state can be stored beside those records without mutating immutable assets or changing the deformation resolver. Prompt 18 does not implement wetness, rain, liquids, mud, snow, blood, temperature, or material simulation.

Prompt 19 does not integrate a second morph system. `deformable_mesh.InstanceState.resolved_deformation` is a copy of the Prompt 18 resolver output for the bound anatomy instance. Mesh state, queue preparation, GPU upload, and draw encoding never feed values back into the resolver.

## Evidence

Pure deterministic coverage is in `tests/deformation_tests.zig`. It covers neutral/extreme samples, long-run cycles, reset, independent characters, shared body/clothing resolution, exact four-sleeve binding, isolated part overrides, rigid opt-out, composition, loadout changes, physics/controller/IK/effect invariance, interaction timing, render grouping, and fixed-buffer no-growth.

F4B2 retired the standalone breathing route after its continuing invariants
were mapped to `tests/deformation_tests.zig`, which runs through
`zig build test`.

Permanent tests directly advance the 240 Hz breathing state, compare
character-local rates/phases, retain topology-expanded clothing and isolated
overrides, check rigid opt-out and gameplay authority, and assert steady-state
allocation invariants.
