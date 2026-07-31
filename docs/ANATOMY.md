# Modular humanoid anatomy

## Model and scope

The canonical humanoid remains the immutable 16-bone locomotion, animation, handshake, and foot-placement rig. Adult anatomy and humanoid-derived additions are a separate compositional catalog. The catalog contains reusable `BodyPartDefinition` records and a bounded list of `BodyPartInstance` records. Instances use typed definition-local IDs after initialization; names and tags are copied into bounded inline storage and are never searched in the steady-state update.

Prompt 18 adds an optional immutable breathing binding to each reusable part definition. The character runtime keeps base morphology separate from tick-derived breathing and exposes both undeformed instance binding matrices and fully deformed descendant matrices. Torso, upper-arm, and chest-adjacent demonstration definitions explicitly opt in; unrelated topology remains neutral. Skin visual response metadata is resolved per visual without mutating the catalog. See `docs/DEFORMATION.md`.

Prompt 19 consumes those same two matrices for mesh attachments. A resolved mesh instance retains the exact `BodyPartInstanceId`; it receives `part_binding_world` plus the result of `resolvedDeformationForPart` using the component's response. The immutable reusable sleeve mesh therefore expands over two or four active upper-arm instances without inventing left/right mesh fields or changing anatomy topology.

A part definition provides an extensible category, type tag, additional tags, child-socket definitions, neutral morphology bindings, and validation metadata. No central enum attempts to list every anatomical or fantasy part. A part instance provides stable identity, a definition reference, parent attachment, local transform, pivot/anchor metadata, body region, visual group, base layer, optional Prompt 15 articulation module, and one explicit visual variant for every presentation profile.

Part parents may be:

- a canonical-rig attachment point;
- a socket owned by another body-part instance;
- a Prompt 15 module-local socket.

The definition resolves all names to compact IDs, rejects dangling parents, self-parenting, disallowed children, rejected child tags, cycles, and depths beyond 16. A body preset is also validated as a closed active topology: every active child whose parent is another part must have that parent active. Zero, one, or many instances of a type are ordinary list contents. Conventional bilateral names are content conveniences, not central storage fields.

This architecture is for humanoid-derived characters. A dragon, horse, spider, snake, centipede, or fundamentally quadrupedal locomotion system should receive another top-level `RigDefinition` (or equivalent) instead of being forced onto the canonical humanoid.

## Module-local articulation

A part may reference one optional `appearance.RigModule`. The module retains its own bounded local joint chain and sockets. The anatomy runtime exposes an explicit part-to-module joint update, but these joints do not enter `BoneSemantic`, canonical clips, controller motion, ordinary arm IK, handshake reach, foot placement, or collision. An extra arm, tail, wing, tentacle, or neck becomes part of one of those systems only through a future explicit integration.

The modular-body evidence definition includes two instances of a three-joint extra-arm definition and a three-joint tail. The canonical rig remains exactly 16 bones and the canonical right-arm IK lengths remain `0.65 m` and `0.80 m`.

## Morphology

Morphology topology and anatomy topology are independent. Channels are stable data IDs. The evidence catalog defines shoulder, torso, chest, waist, hip, limb-thickness, head, hand, foot, breast, tail, horn, wing, and genital visual-scale channels. Content can add channels without adding renderer branches.

Each named morphology preset contains one validated low/high range for every supported channel. The included data presets are `slim`, `average`, `athletic`, `broad_heavy`, and `curvy`. They carry no behavior, strength, intelligence, gameplay, animation, or personality meaning.

The user-facing build value and both override levels use the inclusive range 0–100. Resolution is:

```text
t = user_value / 100
resolved_channel = low + (high - low) * t
```

Precedence for a part is per-instance override, then per-channel override, then global build. Reset selects the body preset's morphology preset and build, clears both override layers, and recomputes all resolved values.

## Integrated foundation evidence

Prompt 22 creates three adult configurations from the same immutable modular definition and canonical animation library: a controlled conventional preset, a distinct-face handshake partner, and a nonstandard extra-arm/tail/horn showcase. Their authored build values differ, the controlled character applies a left-upper-arm instance override, and the three select distinct face/hair combinations. The nonstandard character expands the same long-sleeve recipe to four compatible upper-arm bindings while conventional characters expand it to two.

The controlled character may cycle between canonical adult presets, global build values, and hair definitions while moving. Each selection reevaluates the existing anatomy/appearance runtime and transactionally rebinds the current loadout. It does not allocate a new skeleton, animation library, renderer, mesh topology, or GPU resource. The dedicated Prompt 17 tests remain authoritative for arbitrary topology/cardinality; Prompt 22 provides live integrated evidence without making noncanonical limbs participants in canonical handshake IK.

Bindings use neutral generalized transform coefficients. A resolved scalar contributes translation, rotation, and component scale relative to the binding's neutral value. Definition initialization validates the low and high endpoints so no supported preset can produce a non-positive visual scale. There is no renderer-side per-anatomy interpolation switch.

Canonical bone lengths do not change. Ordinary limb thickness and hand/foot/head proportions are visual deformations applied to existing appearance records. Consequently morphology cannot change controller roots, collider relationships, handshake reach, foot-placement geometry, animation sampling, or canonical IK segment lengths. Module-local articulation may own different geometry because it is not implicitly part of those canonical systems.

## Body presets and multiplicity

Body presets are data-selected active instance sets plus default morphology, build, presentation, face groups, and hair. The shared evidence catalog includes:

- conventional adult male and female configurations;
- typically feminine chest morphology with a penis;
- penis and vulva-region modules together;
- two penis instances;
- three breast instances;
- a nonstandard humanoid with an extra articulated arm, articulated tail, and two horns.

These presets share one skeleton definition, animation library, controller type, interaction code, IK implementation, physics path, input mapping, and renderer. No sex or gender boolean restricts the allowed instances.

Adult chest and genital records are appearance modules only. Their presence does not imply behavior, personality, ability, identity, animation, or gameplay. The visible evidence route remains non-sexual.

## Presentation profiles

Anatomy topology and presentation are distinct immutable definition layers. Every body-part instance declares one deterministic variant for every profile. A variant can reference zero visuals (hidden), one visual, or several visuals. The evidence catalog provides:

- `simplified` with non-explicit visuals;
- `modest` with covered/general-audience visuals;
- `adult_detailed`, which permits content to select anatomically detailed assets.

The bundled adult-detail route remains non-explicit; it proves selection without making explicit artwork mandatory. A game may provide detailed adult assets through the same visual references. Conversely, choosing a covered or hidden variant does not delete the underlying anatomy instance.

Switching a profile updates visibility and deformation on already-created appearance records. It does not allocate, create GPU resources, change the active-part mask, or rebuild authoritative topology. A topology fingerprint is tested before and after profile switches.

## Faces and hair

A `FaceDefinition` names one head instance and a bounded list of independently addressable feature instances. The evidence catalog contains two definitions. `conventional_face` groups the original left/right eyes, eyebrows, nose, mouth, and left/right ears. `angular_face` groups a second set of the same general feature categories with wider, angled green eyes, a thinner wider brow and mouth, a narrower longer nose, and larger ears. The differences are ordinary visual transforms, sizes, and tints referenced by ordinary body-part instances; neither face has a character-specific update or rendering branch. The conventional-male preset selects `conventional_face`, while the conventional-female preset selects `angular_face`, so both are visible side by side in the evidence scene.

Both definitions use the same shared `face_feature_part` definition, head-owned `face` socket, bounded face-feature list, anatomy active mask, appearance visibility/deformation state, and global sprite submission path. Definition initialization validates every named head and feature instance. The grouping is per head; neither the catalog nor runtime assumes exactly one head.

A `HairDefinition` owns a bounded list of hair part instances and an extensible style tag. The evidence content includes short rigid hair, long hair, and a ponytail. Selecting hair rebuilds only the preallocated appearance-level active mask and validates that every selected hair part has an active parent. One hair definition can list parts for several heads.

Prompt 24 maps these same instances to view-specific original atlas regions. Bald is represented by selecting no hair instance; the male buzz cut resolves `short_hair`, and the female long style resolves `long_hair`. Long hair retains the character-owned bounded attachment-secondary state introduced in Prompt 20. A side/front view change clears that state and the next fixed visual tick initializes it from the new view rest configuration. Facial expressions remain out of scope; independently addressable eyes, brows, nose, mouth, and ears are retained.

Prompt 24A makes the visual ownership boundary concrete in the shipped art. Every canonical torso, pelvis, arm, leg, hand, and foot binding resolves neutral base anatomy before and independently of any loadout. Removable clothing uses equipment-kind visual identities and layers over those regions; it never substitutes a `torso_wearing_*`, `arm_with_*`, `leg_with_*`, or `foot_with_*` anatomy definition. The actual training-vest proof regions are co-packed with body regions, demonstrating that atlas placement does not change anatomy/equipment ownership. Torso and pelvis retain an opaque, featureless permanent modesty surface classified as base presentation rather than a removable garment.

Presentation view does not alter anatomy topology. Front projection keeps anatomical left/right identity and uses explicit semantic layers; side projection uses the existing single-root reflection. Body preset, face, hair, morphology, deformation, and view selection therefore remain independent axes.

## Ownership and update order

`anatomy.Definition` owns immutable channels, ranges, profiles, part definitions, flattened tags/sockets/bindings, instances, hierarchy order, variants, face/hair groups, and body presets. `HumanoidDefinition` optionally owns one such catalog next to its skeleton and appearance definitions.

Every `HumanoidCharacter` optionally owns an `anatomy.Runtime` compatible with that catalog. It preallocates:

- active-part state;
- global and per-instance override presence/value arrays;
- resolved channel values;
- per-part morph transforms and world matrices;
- per-instance socket world matrices.

The per-frame visual order is:

1. resolve anatomy-managed visibility and deformation into the existing appearance runtime;
2. evaluate canonical attachment points, optional module joints/sockets, and visuals;
3. evaluate the observational anatomy part/socket hierarchy;
4. submit visible visuals through the sprite fast path or the unified mixed-primitive queue.

All steady-state morphology, body-preset, hair, presentation, module-pose, hierarchy, and submission operations are allocation-free. They create no GPU object. The CPU continues to own anatomy, morphology, animation, physics, IK, interactions, and ordering; the GPU continues to transform vertices, sample textures, blend alpha, and draw instances.

## Equipment compatibility

Prompt 17 consumes anatomy through existing immutable part definitions, typed instance IDs, active-instance state, and evaluated part matrices. It does not add a parallel anatomy model. Equipment anatomy roles resolve at definition initialization to a compatible data-defined part type. Runtime matching iterates active `BodyPartInstanceId` values in definition order and supports first, every, or one specifically resolved instance with an explicit required/optional flag and maximum match count.

The nonstandard preset now contains `extra_arm` and `extra_arm_second`, two instances of the same `extra_arm_part` definition and two independent optional articulation modules. Together with the canonical left and right upper-arm instances, this produces four active `upper_arm` matches. Canonical locomotion, interaction, hand IK, and foot planting still use only the unchanged 16-bone semantic rig; the additional arms remain optional visual modules.

Equipment recipes store instance IDs, never mutable definition pointers or shared transform state. A topology change requires the owning character loadout to rebind and revalidate. Required garments reject a topology without the required part, optional recipes produce no visual, and expansion beyond the recipe maximum rejects the complete loadout candidate. Prompt 19 mesh instances store character-local derived transform/deformation state beside the resolved binding; this state is observational render input and cannot write anatomy or canonical pose state.

## Evidence route and current limitations

Run:

```powershell
zig build run -- --frames 240 --demo modular-body
```

Three characters share one canonical skeleton and animation library. They select conventional male, conventional female, and nonstandard presets, use global builds 15/50/85, apply a hip-width channel override and tail instance override, render `conventional_face` and `angular_face` side by side, use different hair content, and switch presentation profiles at deterministic frames. The route verifies distinct face-part and visual selection, materially different eye transform/size data, one sprite range/draw call, unchanged topology, no steady-state fixed-buffer movement, and no GPU-resource creation.

This is the focused `modular-body` evidence scene, not the current Prompt 27
production lineup. The production `foundation` route uses two characters: an
athletic conventional male with buzz/short hair and a curvy conventional
female with long hair and selectable wardrobe presets. They still use the same
canonical skeleton, typed anatomy, morphology, appearance, and submission
paths; Prompt 27 adds no character-specific rig.

Current limitations are intentional:

- morphology does not alter canonical bone lengths or physics colliders;
- optional module joints have rest/manual local pose only;
- long hair uses bounded visual secondary motion, while the buzz cut remains rigid;
- faces do not yet have expressions or a dedicated face rig;
- adult-detail artwork is not bundled;
- changing an entire body preset is a preallocated topology selection, not an in-game authoring UI;
- optional hands, feet, and arms do not automatically enter canonical handshake or foot-placement systems.

## Prompt 25 wardrobe bindings

Wardrobe visuals consume anatomy roles without changing anatomy ownership. One `every_compatible` upper-arm recipe expands to two sleeve instances on the conventional female and four on the existing nonstandard topology. Gloves, lower-leg wear, and shoes use the same role mechanism. The production shoe item resolves exactly one visual for each active semantic foot; selecting or replacing it leaves both canonical foot-binding matrices unchanged. Closed-footwear metadata may own the visible foot envelope and suppress covered base-foot pixels, but the anatomy foot remains active and its registered ankle, sole-axis constraint, and transformed landmarks remain available to diagnostics. The current shoe declares `ankle` as its exposed anatomy anchor.

Front presentation uses the bounded `FrontAnatomyProjection` of the same active anatomy instances. Side presentation uses the existing evaluated anatomy matrices. View switching therefore changes only which paired art region and projected presentation transform is consumed; it cannot change topology, instance identity, body preset, foot socket, or canonical pose.

Long hair remains an independently selected anatomy/presentation group when headwear is equipped. Hat occupancy neither clears the active hair parts nor substitutes a head definition.

## Prompt 27 production composition

The integrated `visual_foundation.Scene` owns the same two character instances
already constructed by the Prompt 26 environment/wardrobe composition. Body,
build, hair, outfit, movement, jump, dash, interaction, IK, and view changes
act on those instances; no showcase-only anatomy is substituted for
production art. The male uses the conventional-male/athletic presentation and
the female uses the conventional-female/curvy presentation.

Interaction-owned side projection preserves semantic left/right identity and
the participating right-arm animation/IK plane. Equipment ordering resolves
through the actual bound anatomy semantic. Neither feature changes topology,
canonical bones, morphology state, sockets, or base-anatomy ownership.

VF-02 does not change anatomy topology. It consumes the active anatomy and
presentation transforms as typed targets for a bounded set of point, segment,
and frame bindings. Left/right part identity remains authoritative before
mirroring. Registration evidence is presentation metadata and cannot create,
remove, or rename a bone, part, socket, or rig module.

## VF-03 typed component topology

Anatomy part definitions now carry component metadata: semantic role/tags,
point/segment/frame/mesh binding mode, allowed parent-socket role, connection
support, view requirements, maximum instance count, child policy, optional
rig-module template, and material/morphology declaration names. Part sockets
carry stable owner, role, accepted child tag, capacity, connection support,
and local frame.

`component_graph.Definition` compiles these records together with appearance
visuals and rig modules. It does not copy them into another mutable
hierarchy. Runtime compatibility validates the original definition owners and
topology fingerprint.

Current direct typed proofs are:

- head eye socket → eye → eye brow socket → eyebrow;
- head scalp socket → hair;
- torso arm socket → explicit extra-arm module;
- pelvis tail socket → explicit tail module;
- head horn sockets → optional horns.

Standard core torso/head/pelvis and two-arm/two-leg components retain
compatibility-adapter roots where the established attachment hierarchy still
owns placement. Topology is immutable after initialization. No fixed-tick
path creates a part, socket, joint, or module.

VF-03-R1 makes the optional-arm proof a direct production consumer of this
topology. One active arm resolves exactly three graph-bound visuals: upper arm
shoulder → elbow, forearm elbow → wrist, and hand wrist → hand-tip. The
presentation evaluator supplies those projected endpoints; anatomy's
connection evaluator supplies the parent/child root proof. A continuous root
must be within its unchanged epsilon, while the technical intentional-gap
root must measure `0.07–0.09 m` around its `0.08 m` target. The offset is
world-metre data, so parent morphology scale does not inflate or shrink it.
Inactive modules remain explicit definitions but resolve zero active visuals,
joints, sockets, or submissions.
