# Creature Authoring, Multi-Actor Interaction, Surface-State, and Representation Architecture

**Status:** Working architecture decision record  
**Revision:** 3 — adds the explicit handoff from the canonical 3D model pipeline, authoritative resolved-geometry snapshots, continuous low/high morphology paths, whole-body-before-fragment resolution, source-versus-compiled atlas separation, adaptive representation sampling, compiled geometry contracts, and generated-cache identity.  
**Date:** 2026-08-04  
**Purpose:** Preserve the current design decisions for future engine, creature-authoring, animation, rendering, and game-simulation work.  
**Primary output target:** Deterministic 2D pixel-art representations authored from an offline 3D source of truth, with optional runtime or load-time generated/cached variants.

**Current runtime boundary:** The present renderer remains 2D-only. Canonical 3D data, fitting, solving, validation, and atlas generation occur offline or in authoring/build tooling. Live runtime 3D is a future-compatible option, not a current implementation requirement.

---

## 1. Executive decision

The project should continue with an **offline 3D creature-authoring pipeline** as the authoritative source for:

- anatomy and morphology;
- rigging and deformation;
- animation and retargeting;
- multi-actor choreography;
- body/prop contact;
- intentional penetration and occlusion;
- clothing deformation and access;
- soft-tissue response;
- surface coordinates and material semantics;
- alternate cameras and close-up representations;
- generation of deterministic 2D pixel-art atlases and auxiliary masks.

The runtime game should not treat every visual state as a separate pre-authored atlas combination. It should combine:

1. canonical creature morphology;
2. temporary deformation state;
3. skeletal animation;
4. interaction constraints;
5. clothing/equipment state;
6. persistent surface state;
7. environmental state;
8. emitted effects;
9. representation-specific art direction;
10. gameplay state and outcomes.

A complex consenting-adult interaction should be used as a **later integrated vertical slice**, after the underlying systems have been implemented and tested individually. It is valuable because it combines difficult requirements that also apply to combat, riding, grappling, swimming, restraint, furniture, injury, stealth, sensory impairment, and persistent world state.


### 1.1 Relationship to the “3D Model Pipeline Step” specification

This document is a **downstream integration and acceptance-requirements record**. It does not replace the canonical human/creature model specification being locked in the separate “3D Model Pipeline Step” work.

The division of authority is:

```text
3D Model Pipeline Step
  owns canonical units, axes, naming, anatomy topology, rig structure,
  morphology controls, deformation rules, sockets, materials, visibility,
  deterministic JSON, and neutral reference assets

This architecture record
  owns how those definitions are resolved, composed into interactions,
  fitted with garments, rendered into representations, validated,
  cached, and connected to game simulation
```

A downstream interaction requirement may expose a missing canonical capability, but it must not silently redefine the body contract. The missing capability should be returned to the model-pipeline specification as an explicit schema decision.

If the two records ever disagree:

1. stop generation for the affected asset;
2. identify whether the conflict is canonical anatomy, rig-family behavior, interaction behavior, or representation behavior;
3. update the owning specification;
4. increment the relevant schema or compiler version;
5. invalidate and regenerate affected derived artifacts.

### 1.2 Inherited canonical-pipeline assumptions

The following decisions are treated as inherited requirements for this architecture:

- canonical measurements use meters and stored floating-point values; imperial values are display/input conveniences only;
- handedness and the meanings of up, forward, and right are explicit data-contract decisions, never implicit renderer assumptions;
- the canonical character origin is associated with the pelvis/hips, while gameplay facing and presentation-camera facing remain separate concepts;
- one skeleton root owns pose propagation;
- the typed component graph owns topology, parent/child relationships, optional modules, sockets, multiplicity, and capacity;
- the canonical skeleton owns animation pose; exported landmarks and binding metadata own 2D registration;
- deformation uses bone transforms, skin weights, shape deformation, and corrective shapes; geometry regeneration is reserved for coarse/topology-level changes;
- topology and semantic surface correspondence remain stable within a compatible morphology family whenever practical;
- visibility and clothing coverage are explicit manifest data, not incidental consequences of draw order;
- JSON definitions, generated manifests, and output packages are deterministic and versioned;
- the first implementation remains a normal human profile, while variable component counts and exotic topology remain supported by the schema rather than all being implemented immediately.

Current human-rig decisions that downstream systems must be able to consume include:

- one skeleton root;
- seven spine deformation bones with five animator-facing control concepts, including whole-spine and pelvis-handoff behavior;
- three neck deformation bones;
- separate skull and jaw structures;
- separate upper teeth, upper gum/palate, jaw, lower teeth, lower gums, and tongue root/mid/tip, with branching tongue topology permitted;
- an optional primary eye group, a normal default pair, shared look target plus per-eye overrides, semantic eye positions, variable eye count, deformable eyeballs, socket anchors, multi-segment upper/lower eyelids, and non-deforming look controls;
- default one eyebrow per eye while permitting variable count, with authored brow regions/profile points and independent raise, tilt, curve, compression, and stretch controls;
- semantic sockets, component IDs, and view-specific default placements rather than hardcoded screen coordinates;
- shape-deformation-oriented facial controls, including bridge, tip, nostril, width, length, projection, rotation, flare, and compression behavior for the nose.

These values remain owned by the model-pipeline specification. They are repeated here only to prevent downstream systems from introducing incompatible assumptions.

### 1.3 Required staging boundary

The canonical model pipeline should still be implemented in this order:

```text
coordinate/measurement contract
→ naming and deterministic schema
→ skeleton/component topology
→ morphology and deformation definitions
→ optional-anatomy visibility/export rules
→ one minimal neutral base body and rig
→ resolved-geometry snapshot
→ clothing/hair fitting
→ animation and interactions
→ representation generation and atlas export
→ runtime integration
```

The existence of later vertical-slice requirements does not justify skipping the neutral body/rig and resolved-geometry foundation.

For the current renderer, the output of this sequence is a deterministic 2D runtime package. Runtime systems must not depend on hidden 3D authoring state or an editor being present. The canonical source should remain reusable by a future 3D engine, but that future use must not force live 3D into the present 2D runtime.

---

## 2. Scope and content contract

### 2.1 Engine capability versus authored game content

The lower-level engine should support general:

- contact;
- restraint;
- insertion;
- grasping;
- mounting;
- carrying;
- striking;
- biting;
- fluid emission;
- surface contamination;
- arbitrary anatomy counts;
- arbitrary rig families.

The game-content layer decides which interactions are permitted and authored.

Technical capability is not the same as content eligibility.

### 2.2 Adult-interaction eligibility

For the intended game-side adult-content contract, eligible participants are:

- consenting adult humans;
- clearly adult, sapient, person-like fantasy species;
- adult-equivalent sapient artificial persons;
- characters with explicit compatible interaction adapters.

Ordinary animals, mounts, pets, and animal-form creatures are not eligible for sexual participant roles. They can still use the same engine for locomotion, riding, carrying, combat, injury, grooming, swimming, restraint, and other nonsexual interactions.

### 2.3 Horse, unicorn, centaur, cyclops, and robot distinctions

These are not differentiated by a single `sexual_interaction = true/false` field.

A creature definition separates:

```text
CreatureDefinition
├── lineage/species identity
├── rig topology
├── anatomy modules
├── personhood/agency classification
├── lifecycle stage
├── locomotion profiles
├── capabilities
├── interaction adapters
└── game-content eligibility
```

Examples:

- **Horse:** equine lineage, quadruped unguligrade rig, non-person animal, rideable and harness-capable.
- **Animal-like unicorn:** magical equine lineage, horse-like rig plus horn/magic modules, still a non-person animal.
- **Sapient unicorn-person:** explicitly authored person-like species with adult lifecycle and compatible humanoid or custom interaction adapters.
- **Centaur:** sapient person, humanoid upper topology plus quadruped lower topology, requiring centauroid-specific adapters.
- **Cyclops:** humanoid topology with one eye module; usually reuses most humanoid contracts.
- **Robot:** may be a prop, non-person agent, or sapient person. Only the explicitly sapient adult-equivalent category can be eligible for adult roles.

The engine should not infer personhood merely from intelligence, magic, speech, or appearance. The authored content definition must state it explicitly.

---

## 3. Core layered visual and simulation state

A resolved character or creature should be treated as layered state:

```text
CreatureVisualState
├── canonical anatomy and morphology
├── temporary deformation configuration
├── skeletal pose and animation
├── soft-tissue response
├── clothing and equipment
├── active interaction constraints
├── surface condition
├── environmental medium and lighting
├── attached residue and decals
├── emitted particles/fluids
├── sensory impairment state
└── representation profile
```

### 3.1 Canonical morphology

Persistent authored body definition:

- height;
- limb lengths;
- body-part volumes;
- face structure;
- anatomy dimensions;
- number and placement of modules;
- normal tissue shape;
- normal rig proportions.

### 3.2 Temporary deformation

Temporary or state-driven changes:

- rage-related muscle enlargement;
- swelling;
- pregnancy progression;
- inflation;
- erection or soft-tissue state;
- magical transformation;
- injury deformation;
- temperature-related changes;
- species transformations.

### 3.3 Pose and animation

Bones, controls, animation clips, procedural corrections, and multi-actor phase synchronization.

### 3.4 Surface state

Persistent or decaying material-local state:

- wetness;
- sweat;
- mud;
- blood;
- snow;
- frost;
- oil;
- residue;
- stains;
- burns;
- bruising;
- magical contamination.

### 3.5 Environment state

Surrounding effects:

- underwater color absorption;
- fog;
- rain;
- snow;
- smoke;
- lava illumination;
- heat distortion;
- ambient occlusion or local lighting.

### 3.6 Emitted effects

Free-moving effects should remain separate from the body animation:

- droplets;
- streams;
- bubbles;
- particles;
- sparks;
- vapor;
- breath;
- projectiles;
- temporary decals.


### 3.7 Authoritative data-stage hierarchy

“3D model” and “atlas” are too broad to serve as precise contracts. The pipeline should use explicit stages:

```text
CanonicalCreatureDefinition
        ↓
ResolvedCreatureGeometrySnapshot
        ↓
ResolvedPoseSnapshot
        ↓
ResolvedInteractionSceneSnapshot
        ↓
CompiledRepresentationContract
        ↓
SceneRepresentationPackage / sprite atlases / auxiliary buffers
        ↓
runtime dynamic surface, effect, and gameplay state
```

#### Canonical creature definition

The reusable source definition contains:

- canonical mesh/topology or module sources;
- rig and control definitions;
- morphology controls and authored endpoint vectors;
- semantic surfaces, seams, sockets, landmarks, and regions;
- material and palette roles;
- deformation and corrective-shape definitions;
- visibility/export policy;
- deterministic schema/version metadata.

#### Resolved creature geometry snapshot

The `ResolvedCreatureGeometrySnapshot` is the authoritative answer for one actual body configuration before scene-specific animation and contacts are applied.

```text
ResolvedCreatureGeometrySnapshot
├── complete resolved morphology vector
├── body-family/profile identity
├── canonical/reference-pose geometry
├── resolved rest-joint and socket transforms
├── shared seam/ring geometry
├── semantic landmarks
├── surface IDs and canonical coordinates
├── base collision proxies and hitboxes
├── interaction sites and effectors
├── garment-fitting envelope
├── visible bounds and silhouette metrics
├── source parameter signature
└── schema/compiler versions
```

No downstream system independently recalculates what a morphology value means. Animation, garments, hitboxes, interactions, cameras, diagnostics, and exports consume the same snapshot.

#### Resolved pose snapshot

The `ResolvedPoseSnapshot` applies:

- skeletal animation;
- temporary deformation state;
- soft-tissue response;
- pose-dependent collision;
- pose-dependent lowest/drip points;
- pose-dependent visibility.

#### Resolved interaction-scene snapshot

The `ResolvedInteractionSceneSnapshot` combines all posed actors, props, garments, restraints, contacts, authorized penetration volumes, scene depth, and camera state after constraint solving.

This is the correct input for a baked or generated interaction representation.

### 3.8 Continuous weight/morphology paths

A Skyrim/BodySlide-style weight value is an authored coordinate along a morphology path, not a global scale multiplier.

For each affected control:

```text
resolved_control =
    low_endpoint_control
    + (high_endpoint_control - low_endpoint_control) × normalized_weight
```

Example:

```text
low-weight bicep definition:   20
high-weight bicep definition: 100
weight:                        50
resolved bicep definition:     60
```

The source definition therefore contains:

```text
WeightMorphPath
├── low-endpoint morph vector
├── high-endpoint morph vector
├── interpolation function
├── valid range
└── body-family/profile association
```

Linear interpolation is the initial default. The contract should permit authored curves or corrective shapes where linear interpolation produces poor anatomy, garment fit, or silhouette behavior.

The logical range may be represented as `0–100` for authoring/UI and normalized internally to `0.0–1.0`. Supporting 101 logical values does not imply manually authoring 101 source meshes or textures.

### 3.9 Weight is not the complete body identity

One weight axis describes one path through body-shape space. It cannot independently represent every combination of:

- height;
- torso-to-leg ratio;
- shoulder width;
- hip width;
- muscularity;
- adiposity;
- limb girth;
- limb length;
- chest or breast dimensions;
- other anatomy dimensions.

A character should therefore resolve from a broader parameter set:

```text
body family/profile
+ permanent proportions
+ weight path position
+ independent morphology axes
+ anatomy configuration
+ persistent transformations
```

Two characters with the same weight value can remain visibly and geometrically different.

Player-facing labels such as `Small`, `Normal`, or `Big` are parameter presets, not the underlying morphology model.

### 3.10 Resolve the complete body before deriving modular render pieces

Morphology must be applied to the complete compatible body surface before the pipeline derives modular crops, rigid sprite pieces, clothing fragments, seams, hitboxes, or registration landmarks.

Incorrect order:

```text
upper arm resolves weight independently
forearm resolves weight independently
sleeve resolves weight independently
```

Required order:

```text
resolve complete body
→ establish shared shoulder/elbow/wrist geometry
→ derive body render pieces
→ fit garment pieces
→ derive pivots, landmarks, masks, hitboxes, and interaction anchors
```

The upper arm, forearm, hand, sleeve, glove, elbow socket, collision proxy, and interaction landmark must all agree on the same resolved elbow and wrist geometry.

This is the enforceable contract that prevents disconnected or mismatched body parts in the final 2D renderer.

### 3.11 Stable topology and explicit topology changes

Within one compatible morphology family:

- vertex correspondence should remain stable;
- triangle count should remain stable where practical;
- semantic surface IDs and canonical coordinates should remain stable;
- seam/ring identities should remain stable;
- skinning and garment correspondence should remain valid.

A true topology change—adding/removing a limb, head, mouth, wing, genital module, tail, or other component—is represented as a component/module configuration change with an explicit compatibility signature. It is not hidden inside an ordinary continuous morph.

### 3.12 Source texture atlas versus compiled sprite atlas

The term `atlas` must be qualified.

#### Source UV/material atlas

The texture/material data wrapped onto a 3D body or garment. It can usually remain reusable while geometry changes.

#### Compiled 2D sprite atlas

The rasterized output consumed by the 2D renderer. Its silhouette, registration, shading, occlusion, and pixel clusters may change with morphology, garment fit, pose, interaction, camera, and representation profile.

Therefore:

- one source garment does not require one manually authored texture per weight value;
- generated 2D sprite atlases are derived artifacts;
- changing silhouette may require a new compiled representation even when the source material atlas is unchanged.

---

## 4. Modular anatomy and variable body-part counts

The schema must not assume exactly:

- two arms;
- two legs;
- one head;
- one mouth;
- one penis;
- one vagina;
- one anus;
- one tail;
- one eye pair.

Instead, anatomy is a set of uniquely identified components:

```text
anatomy:
  heads: [...]
  mouths: [...]
  eyes: [...]
  arms: [...]
  legs: [...]
  wings: [...]
  tails: [...]
  grasping_effectors: [...]
  penetrating_effectors: [...]
  receiving_sites: [...]
  emitters: [...]
```

Each module defines:

```text
AnatomyModule
├── component_id
├── semantic tags
├── parent component
├── local transform
├── rig controls
├── deformation shapes
├── material/surface regions
├── collision proxies
├── effectors
├── emitters
├── occupancy capacity
├── state configuration
└── representation rules
```

Examples:

- A four-armed character exposes four independent grasping effectors.
- A three-headed character exposes three independently targetable mouths.
- A fantasy character may expose multiple explicitly authored receiving sites.
- A winged humanoid adds wing modules without requiring a separate renderer.
- A centaur composes humanoid-upper and quadruped-lower modules.

Interactions target **semantic requirements**, then resolve them to actual component IDs:

```text
target_requirement:
  semantic_tag: mouth
  availability: free
  reachability: valid
  capacity: available

resolved_target:
  head_2.mouth_0
```

### 4.1 Anatomy as a resource

Every effector or target site has availability and capacity:

```text
InteractionResource
├── current claims
├── maximum concurrent contacts
├── allowed contact modes
├── exclusion rules
├── occupancy depth/capacity
└── release policy
```

A hand gripping furniture cannot simultaneously occupy another exclusive grasp role. A four-armed character may occupy more roles, but only when each arm can reach its target without collision or balance failure.

---

## 5. Multi-actor choreography model

A multi-actor interaction is not one giant animation clip. It is an **interaction choreography graph**.

```text
InteractionInstance
├── interaction definition
├── participant membership
├── phase/state graph
├── master timeline
├── role assignments
├── contact graph
├── prop assignments
├── reservations
├── active constraints
├── state channels
├── effect events
└── outcome accumulator
```

### 5.1 Membership versus role

These are separate:

- **Membership:** who is participating in or observing the scene.
- **Role:** what each participant is doing during the current phase.

An actor may transition:

```text
observer
→ interested
→ approaching
→ support role
→ active contact role
→ recovering
→ leaving
```

Roles are phase-specific, not permanently assigned for the full interaction.

### 5.2 Contact graph

A contact edge describes one intentional relationship:

```text
ContactEdge
├── source effector
├── target site
├── mode
├── position/orientation target
├── active phase range
├── depth
├── pressure
├── friction
├── allowed error
├── ownership/release policy
└── collision exception volume
```

Supported contact modes can include:

```text
touch
support
grasp
restrain
strike
bite
insert
pull
push
carry
mount
harness
```

The same framework supports:

- hands on furniture;
- a rider on a saddle;
- a knife entering a torso;
- a hand entering a pocket;
- a limb under a blanket;
- grappling;
- adult anatomy contact.

---

## 6. Switching from one complex interaction pose to another

A major transition—such as disengaging several simultaneous contacts, turning one participant around, and re-establishing new contacts—must not be implemented as ordinary skeletal blending.

It should be a **planned, transactional choreography transition**.

### 6.1 Transition request

An actor or encounter controller submits:

```text
TransitionRequest
├── requested destination state
├── requesting actor
├── reason/intent
├── priority
├── required releases
├── desired new roles
└── interruption tolerance
```

### 6.2 Authority and cooperation

The system evaluates:

- who is allowed to request the transition;
- which contacts require another participant's cooperation;
- whether the scene is cooperative or contested;
- whether restraints or props prohibit movement;
- whether all required anatomy resources can be released;
- whether participants have enough stamina and balance;
- whether a collision-free path exists.

In a cooperative consenting scene, a participant can request a position change, and the choreography asks other participants to release or reposition.

In a fight, a pinned participant cannot simply switch to an unpinned animation. The requested change becomes an **escape attempt** or contested action. The controlling participant may oppose it.

### 6.3 Contact ownership and release policy

Every active contact declares a release policy:

```text
release_policy:
  requester_can_release
  target_can_request_release
  mutual_release_required
  controller_release_required
  forced_release_on_injury
  forced_release_on_scene_end
```

This avoids hardcoding “the primary participant always controls the scene.”

### 6.4 Transactional transition stages

A complex transition should run through explicit stages:

1. **Propose** the destination choreography state.
2. **Validate** permissions, cooperation, restraints, stamina, geometry, and role availability.
3. **Reserve** destination roles, space, and anatomy resources.
4. **Plan** a safe transition path.
5. **Enter release phase** and reduce or stop rhythmic motion.
6. **Disengage contacts** in a defined order.
7. **Move to neutral bridge pose** if required.
8. **Reorient roots and bodies** through authored transition clips plus constraints.
9. **Align destination anchors.**
10. **Re-engage contacts** in a defined order.
11. **Synchronize** to the destination loop phase.
12. **Commit** the new state.

If validation fails before movement, the transition is denied.

If something fails after movement begins, the graph should route to:

- a safe fallback pose;
- partial rollback;
- a neutral disengaged state;
- an interruption state.

Do not snap back to the original pose after participants have visibly moved.

### 6.5 Transition graph example

```text
state_a_loop
→ request_change
→ decelerate
→ release_contact_group_a
→ release_contact_group_b
→ bridge_pose
→ rotate_primary_actor
→ reposition_supporting_actors
→ destination_alignment
→ acquire_contact_group_b
→ acquire_contact_group_a
→ state_b_loop
```

The exact release and re-acquisition order is authored because simultaneous release may create balance failures or impossible motion.

### 6.6 Restraints and denied transitions

A restraint participates in validation:

```text
RestraintConstraint
├── anchor_a
├── anchor_b
├── min/max separation
├── permitted rotations
├── stiffness
├── break threshold
└── attachment state
```

A requested turn may be:

- valid without correction;
- valid through a restraint-specific bridge pose;
- valid only if the restraint is unlocked;
- impossible.

Physics alone is not enough. The animation needs restraint-compatible correction layers so shoulders, spine, and balance remain readable.

### 6.7 Contested transitions in combat

A pinned actor's request is evaluated as:

```text
EscapeAttempt
├── requested movement
├── available leverage
├── current grips/restraints
├── strength/control contest
├── stamina
├── skill
├── injury
└── environment
```

Possible results:

- denied with a struggle animation;
- partial positional improvement;
- grip broken;
- full escape;
- reversal of control.

This uses the same choreography framework, but the transition is not cooperative.

### 6.8 Presentation transition modes

Not every change between scene states needs a physically continuous in-world transition. Every scene or interaction package should declare its presentation mode explicitly:

```text
transition_mode:
  hard_cut
  fade
  bridge_clip
  procedural_bridge
  transactional_choreography
  reset_to_neutral
```

Use the modes as follows:

- **Hard cut:** galleries, previews, debug selectors, montage presentation, or any context where continuity is not claimed.
- **Fade:** a presentation-level transition that intentionally hides continuity.
- **Bridge clip:** a short authored connection between two compatible states.
- **Procedural bridge:** root motion, IK, and pose matching connect states within a validated range.
- **Transactional choreography:** full permission, release, reservation, reorientation, and re-engagement logic for continuous multi-actor action.
- **Reset to neutral:** participants disengage to a known safe state before another interaction begins.

The engine should not force transactional choreography for a non-diegetic scene browser. Conversely, an in-world position change that claims uninterrupted physical continuity should not use a hard cut merely to conceal invalid geometry.

---

## 7. Joining, leaving, finishing, and role switching

A nearby actor does not join merely because a slot exists.

The candidate evaluation can include:

```text
consent
interest/desire
relationship
social context
privacy
risk
stamina
fatigue
current obligations
role compatibility
anatomy compatibility
distance
navigation
geometric feasibility
scene capacity
```

Use different thresholds for:

- joining;
- continuing;
- switching roles;
- leaving.

Hysteresis prevents oscillation:

```text
join_threshold:      high
continue_threshold:  medium
leave_threshold:     low
```

An optional participant may:

1. observe;
2. change internal state over time;
3. reserve an available role;
4. approach;
5. align;
6. join at a legal synchronization marker;
7. later finish, recover, switch roles, observe, or leave.

The scene ends when:

```text
no valid active roles remain
OR all configured goals are complete
OR all remaining participants choose to leave
OR an interruption forces termination
OR the encounter definition explicitly ends
```

One participant finishing does not automatically terminate the entire scene.

---

## 8. Role conflicts and logical constraints

Designers should not need to write raw Boolean expressions, but the system should support equivalent rules.

Useful constructs:

```text
requires
excludes
at_least_one
exactly_one
at_most_n
requires_one_of
shared_capacity_group
```

Example:

```text
exclusion_group:
  capacity: 1
  members:
    - role_left
    - role_front
```

This means the two roles may each be empty, but cannot both be occupied. Logically, that is a NAND-style constraint rather than XOR.

Dynamic body sizes can also create runtime conflicts even when the authored roles normally coexist.

---

## 9. Geometric feasibility, comfort, and skill are separate

### 9.1 Geometric feasibility

Can the bodies, anatomy, clothing, restraints, and props align without impossible joints or unintended collision?

### 9.2 Comfort and tolerance

Is the current size, pressure, angle, force, duration, and preparation within the character's comfort range?

### 9.3 Control and skill

Can an actor maintain the intended rhythm, precision, force, or pose efficiently?

Skill may improve:

- positioning;
- control;
- timing;
- safety;
- stamina efficiency;
- tolerance through progression;
- recovery.

Skill does not make impossible geometry possible.

Expandable anatomy should declare:

```text
rest range
comfortable deformation range
trained/adapted range
maximum safe range
injury threshold
```

Progression can expand authored comfort and adapted ranges, but must not erase hard physical limits.

---

## 10. 3D geometric validation and diagnostics

The authoring tool should visualize:

- **green:** required contact satisfied;
- **yellow:** within tolerance but near a limit;
- **red:** invalid overlap, unreachable target, or joint failure;
- **blue:** reserved role/approach volume;
- **purple:** authorized penetration volume;
- **orange:** pixel-readability warning.

The solver distinguishes:

```text
intentional contact
intentional penetration
unintended intersection
```

Measured diagnostics:

```text
contact error
entry-angle error
penetration-depth error
joint-limit violation
unintended body overlap
role-to-role collision
balance/support error
restraint tension
garment strain
silhouette collapse
pixel-cluster instability
```

An interaction should not export simply because every bone has a transform.

---

## 11. Body size, soft tissue, and visibility

Different body dimensions can radically change visible overlap.

For example, a body part may be:

- fully visible;
- partially occluded;
- mostly hidden;
- completely hidden by surrounding soft tissue or clothing.

This should be handled as a **hybrid**:

1. 3D geometry and soft-tissue deformation determine actual depth and shape.
2. The 3D renderer produces color, depth, region, and occlusion data.
3. The pixel exporter quantizes the result.
4. Runtime depth masks may handle limited continuous variation.
5. Large morphology differences use generated/cached variants or prevalidated morphology bands.

Do not manually encode one generic “50% hidden” sprite for every character.

### 11.1 Soft-tissue deformation

Soft tissue can define:

```text
SoftTissueRegion
├── driver bones
├── volume preservation
├── compression response
├── stiffness
├── damping
├── phase delay
├── maximum displacement
├── contact deformation field
└── representation exaggeration
```

Contact can compress and displace tissue. Body size and contact pressure determine how much of another object remains visible.

### 11.2 Morphology bands

Morphology bands are not player body presets. They are validation/retargeting templates such as:

- compact;
- average;
- tall/long-limbed;
- broad/deep-bodied;
- extreme relevant anatomy size.

Within a validated band, procedural correction can adjust:

- pelvis/root position;
- joint angles;
- limb placement;
- contact depth;
- soft-tissue deformation;
- camera correction.

Outside the safe range, the system requires:

- another band;
- a corrective pose;
- a generated custom atlas;
- or rejection.


### 11.3 Logical morphology versus represented morphology

A character may have a continuous logical morphology while a particular visual package uses an exact or sampled representation.

Each active visual package therefore carries a compiled geometry contract:

```text
CompiledRepresentationContract
├── logical morphology signature
├── represented morphology signature
├── source resolved-snapshot signature
├── visual atlas and auxiliary buffers
├── registration data
├── visible hitboxes/collision proxies
├── interaction approximation limits
├── maximum silhouette/landmark/contact error
└── compiler/schema versions
```

If a logical weight-47 character uses a weight-50 visual sample:

- the visible registration and visible interaction geometry must match the weight-50 compiled representation;
- the logical value may remain 47 for non-geometric gameplay calculations;
- close-contact interactions must reject the approximation or request an exact generated package when the representation error exceeds tolerance.

The engine must never display one morphology while using materially different close-contact geometry underneath it.

### 11.4 Exact, sampled, and live representation strategies

A representation may use:

#### Exact generated output

Generate and cache the actual resolved configuration through offline, authoring-time, or build/load tooling. Best for:

- player characters;
- close-ups;
- clothing-sensitive scenes;
- furniture contact;
- multi-actor close contact;
- unusual or extreme morphology.

#### Quantized/adaptively sampled output

Use the nearest approved generated sample when measured error remains below the representation's acceptance threshold. Appropriate for:

- distant NPCs;
- low-detail world sprites;
- rigid or morphology-insensitive assets;
- scenes without close contact.

#### Live deformation or low-resolution 3D

Resolve continuously at runtime. Most flexible, but highest implementation and pixel-art stability cost.

These strategies correspond to the scene implementation tiers rather than forming a separate incompatible system.

### 11.5 Adaptive sample generation

Eleven initial samples (`0, 10, 20, …, 100`) are a reasonable proof fixture, not a permanent global rule.

The durable rule is:

> Generate as few representation samples as satisfy the measurable visual and geometric contract for the asset, scene, and camera.

An adaptive compiler can test an interval:

```text
generated endpoints: weight 0 and weight 10
exact validation reference: weight 5
```

If the nearest endpoint/sample exceeds tolerance, subdivide:

```text
0, 5, 10
```

Relevant measurements include:

- silhouette deviation in pixels;
- semantic-landmark displacement;
- seam and registration error;
- garment clearance and strain;
- contact and penetration error;
- depth-order changes;
- feature disappearance;
- pixel-cluster instability.

Different assets and scenes may require different sample densities. A rigid helmet may need few samples; a tight garment or close-contact scene may require many samples or exact generation.

The `SceneCoverageManifest` should declare:

```text
morphology_support:
  mode: exact_generated | adaptive_sampled | fixed_presets | live | unsupported
  sampled_axes: [...]
  maximum_silhouette_error_px: ...
  maximum_landmark_error_px: ...
  maximum_contact_error: ...
  exact_generation_required_for: [...]
```

### 11.6 Player-facing morphology presets versus validation bands

A player-facing body choice and an internal interaction-validation band are different concepts and must have different schema types.

```text
PlayerMorphologyPreset
  Small
  Normal
  Big
  custom named presets
```

A player preset is a convenient authored set of morphology parameters. It may affect height, body volumes, limb dimensions, and other sliders.

```text
InteractionValidationBand
  compact
  average
  tall_long_limb
  broad_deep_body
  interaction_specific_extreme
```

A validation band is selected from actual measurements relevant to one interaction: pelvis height, limb reach, torso depth, hip breadth, tissue volume, anatomy dimensions, and prop clearance.

There is no required one-to-one mapping. Two characters using the same visible `Big` preset may fall into different validation bands because their height or limb proportions differ. A custom character may cross several interaction-specific bands depending on which measurements matter.

---

## 12. Intentional penetration and dynamic occlusion

The authoritative 3D representation retains complete geometry. Inserted portions are hidden by normal depth and authorized occlusion.

```text
InsertionEffector
├── tip
├── base
├── centerline
├── cross-section
├── available length
├── rigidity
├── bend limits
└── emitters
```

```text
ReceivingSite
├── entry transform
├── permitted entry cone
├── depth range
├── deformation field
├── occlusion volume
├── capacity
├── residue receiver
└── comfort/safety envelope
```

For compound insertion, such as fingers, hand, wrist, and forearm, the effector is a chain rather than one point.

### 12.1 Final 2D implementation modes

**Precomputed:** render each interaction frame from 3D. Best quality.

**Parameterized hybrid:** render separate layers plus depth/occlusion masks and a finite set of corrective overlays.

**Highly dynamic:** live low-resolution 3D or load-time/runtime atlas generation and caching.

Manual depth slices are a fallback, not the preferred authoritative solution.

---

## 13. Clothing and equipment interaction architecture

Clothing cannot be treated as one flat sprite placed over the body.

Each garment should define:

```text
GarmentDefinition
├── garment fragments
├── material properties
├── closures
├── access routes
├── body anchors
├── collision thickness
├── deformation response
├── padding
├── transparency
├── surface coordinates
├── state variants
└── interaction volumes
```


### 13.1 Source garment and fitting order

A garment should be authored once as a source asset:

```text
SourceGarment
├── source mesh/topology
├── source material/UV atlas
├── skeleton binding
├── body-surface correspondence
├── fit definition
├── fit category
├── garment-specific corrective shapes
├── coverage and clearance rules
├── closures and access routes
├── material behavior
└── schema/version identity
```

The required order is:

```text
ResolvedCreatureGeometrySnapshot
→ source garment fitting
→ garment corrections and clearance validation
→ posed body/garment solution
→ interaction and access-state solution
→ 2D rasterization/export
```

Do not stretch an already-rendered pixel garment to fit another morphology. Fit or deform the 3D source first, then render the resulting silhouette and shading.

Garment behavior depends on fit category:

- **tight:** closely follows body surfaces and may need denser morphology sampling;
- **loose:** follows anchors and broad dimensions while preserving drape/clearance;
- **structured:** preserves more authored volume and uses local fitting corrections;
- **rigid:** primarily updates anchors and clearance, with limited deformation;
- **adaptive/fantasy:** uses explicit authored rules rather than implicit universal stretching.

### 13.2 Garment fragments and depth

A bra may contain:

```text
left_cup_front
left_cup_inner
right_cup_front
right_cup_inner
center_gore
underband
left_strap
right_strap
```

A skirt or dress may contain:

```text
front_panel
back_panel
left_side_panel
right_side_panel
hem
waistband
closure
lining
```

These fragments participate independently in depth ordering.

### 13.3 Access routes

An interaction should query garment access rather than hardcode “remove clothing.”

```text
AccessRoute
├── target body region
├── required garment state
├── displacement path
├── stretch requirement
├── closure actions
├── hand requirements
├── time cost
└── valid poses
```

Examples:

- lift a loose skirt;
- raise a dress hem;
- open a zipper;
- pull aside elastic fabric;
- move a bra cup;
- use an existing opening;
- remove the garment;
- tear the garment if allowed.

A tight dress may require opening, removal, or a different pose. A loose skirt may be lifted and held. The garment definition decides.

### 13.4 Interaction between body, inserted object, and bra

A “between garment and body” action uses a bounded interaction channel:

```text
GarmentBodyChannel
├── body surface
├── garment inner surface
├── entry opening
├── available clearance
├── friction
├── stretch
├── pressure capacity
└── exit constraints
```

Depth is resolved in 3D:

- chest/body behind;
- interacting object in the channel;
- cup/front fabric in front.

For final 2D output, this can be baked for high-value scenes or represented with garment/body depth masks for validated variable geometry.

### 13.5 Clothing material properties

Required properties include:

```text
thickness
opacity/transparency
padding
stiffness
elasticity
compression
stretch limit
recovery rate
friction
drape
wrinkle response
tear threshold
wet response
surface absorption
collision thickness
```

These properties determine whether anatomy detail transfers through clothing.

### 13.6 Nipple or erection visibility under clothing

Use a body-to-garment pressure/displacement model:

```text
visible_protrusion =
  body protrusion
  - garment clearance
  - padding suppression
  - compression
  + stretch response
```

A padded bra may almost completely suppress nipple shape. A thin tight shirt may show a small silhouette or shading change. A loose shirt may show none.

For an erection under shorts or pants, the garment solver considers:

- anatomy dimensions and orientation;
- available internal volume;
- underwear presence;
- garment fit;
- fabric stiffness and stretch;
- seam layout;
- waistband and leg opening;
- current pose.

Possible outcomes:

- absorbed by available garment volume;
- visible bulge;
- fabric displacement;
- garment shifted;
- pose restricted;
- garment opened;
- garment overstretched or torn;
- incompatible without a garment-state change.

Significant silhouette changes should be generated/baked or use a garment-state variant. Minor shading/pressure detail can be dynamic.

---

## 14. Soft versus erect anatomy states

An erection is not a uniform scale change.

The module should expose:

```text
states:
  soft
  transition_low
  transition_high
  erect

parameters:
  length
  girth
  curvature
  base angle
  rigidity
  bend limit
  gravity response
  secondary-motion damping
```

The soft state has greater gravity response, flexibility, and follow-through.

The erect state has greater stiffness, reduced secondary motion, different collision behavior, and a different authored shape.

The 3D system can evaluate a continuous transition. Pixel output should use a controlled number of meaningful state frames or generated variants.

This architecture also applies to:

- retractable claws;
- inflatable throat sacs;
- fin raising;
- horn growth;
- pufferfish inflation;
- tentacle stiffening;
- magical enlargement;
- rage-related muscle expansion.

---

## 15. Fluids, surface contamination, pooling, and drying

Fluids are general reusable assets:

```text
FluidProfile
├── palette
├── opacity
├── viscosity
├── density
├── surface tension
├── stream cohesion
├── droplet behavior
├── spread
├── absorption
├── drying/evaporation
├── dried residue
├── staining
├── irritancy
├── odor
└── cleaning requirements
```

Lifecycle:

```text
emission
→ stream/droplet
→ surface contact
→ film/streak/patch
→ flow/absorption
→ dripping/pooling
→ evaporation/drying/crusting/staining
→ cleaning or decay
```

### 15.1 Pixel-art fluid representation

Continuous fluid behavior should be reduced into stable categories:

```text
consistency:
  watery
  medium
  thick
  gel-like

coverage:
  none
  specks
  streak
  patch
  heavy

state:
  fresh
  partially dried
  dried residue
```

This creates designed pixel clusters rather than noisy simulation.

### 15.2 Persistent surface maps

Each exported sprite pixel may carry auxiliary data:

```text
surface_id
canonical_uv
material_id
region_id
normal category
depth
```

The character, garment, or prop stores contamination in canonical surface space.

A mark on a shirt therefore remains on the same shirt region while the actor:

- changes animation;
- turns;
- enters a close-up;
- removes and re-equips the garment;
- changes camera angle.

### 15.3 Pooling and drainage

Bodies, clothing, furniture, and terrain expose accumulation regions and drainage links:

```text
SurfaceFlowGraph
├── body hollows
├── fabric folds
├── garment hems
├── hair tips
├── chair depressions
├── prop edges
└── floor depressions
```

A low-frequency update moves fluid based on:

- gravity;
- orientation;
- viscosity;
- absorption;
- saturation;
- region capacity.

Excess creates drips or transfers to adjacent surfaces.

### 15.4 Drying and cleaning

Outcome depends on the fluid-surface reaction:

```text
SurfaceReactionProfile
├── absorption
├── spread
├── dry time
├── remaining residue
├── dried color
├── stain persistence
├── odor persistence
└── cleaning method
```

The engine should not globally delete all fluids after a fixed time.

---

## 16. Fluid or residue affecting eyesight

Eyes should be semantic sensory surfaces, not merely face pixels.

```text
VisionSensor
├── left/right/other eye sites
├── eyelid state
├── contamination
├── irritation
├── optical obstruction
├── acuity
├── field of view
└── recovery/cleaning state
```

A fluid contacting an eye can produce:

- immediate blink reflex;
- eyelid closure;
- blur;
- reduced contrast;
- partial visual-field obstruction;
- temporary blindness;
- irritation/pain;
- color cast;
- need to wipe or rinse;
- persistent damage for hazardous substances.

The `FluidProfile` supplies:

```text
eye_opacity
irritancy
adhesion
washability
damage potential
```

The gameplay vision system uses the resulting impairment. The renderer may also show:

- closed/blinking eyes;
- residue;
- tears;
- screen-space blur or obstruction for the controlled character.

This same architecture supports:

- mud;
- blood;
- smoke;
- sand;
- poison;
- snow glare;
- underwater visibility;
- damaged goggles;
- blindness effects.

---

## 17. Sound masking and hearing

Loud nearby sounds should not simply disable all distant sounds. They raise the effective hearing threshold.

Use a sound-perception model:

```text
SoundEvent
├── source position
├── loudness
├── frequency bands
├── duration
├── semantic category
└── propagation profile
```

```text
HearingSensor
├── acuity by frequency
├── attention
├── current masking field
├── obstruction
├── injury
└── detection threshold
```

The listener evaluates signal-to-mask ratio after:

- distance attenuation;
- walls and obstacles;
- environmental absorption;
- competing nearby sounds;
- rain, waterfalls, machinery, battle, crowds;
- attention and focus;
- hearing damage.

A loud nearby scene may cause:

- distant footsteps to be missed;
- speech to become unintelligible;
- direction estimates to become less accurate;
- only low-frequency impacts to remain detectable.

This is a general sensory system, not a special adult-scene rule.

---

## 18. Environmental wetness, water, rain, snow, and lava

### 18.1 Semantic palette/material rendering

Atlases should preserve semantic material roles rather than only final RGB:

```text
body.skin.base
body.skin.shadow
hair.base
hair.highlight
shirt.primary
shirt.trim
metal.base
eye.iris
```

Environment-specific lookup tables can map these roles to:

- underwater blue/green shifts;
- lava orange/red/yellow illumination;
- moonlight;
- poison fog;
- magical light.

This is better than grayscale tinting.

### 18.2 Wetness

Wetness is tracked per material region:

```text
skin_wetness
hair_wetness
cloth_wetness
fur_wetness
metal_surface_water
```

Material response includes:

```text
absorption
darkening
hue shift
specular response
drying
clumping
drip threshold
```

After leaving water, underwater color stops immediately, but wetness remains and decays.

### 18.3 Rain and snow

Rain adds wetness and impact droplets.

Snow deposits on upward-facing surfaces, then may:

- remain;
- fall off;
- compress;
- melt into wetness.

### 18.4 Lava and other media

A general environmental medium interface supports:

```text
density
drag
buoyancy
visibility
color absorption
emitted light
surface residue
temperature
damage behavior
```

Water, lava, oil, slime, poison, magical liquid, and liquid metal use different configurations.

---

## 19. Alternate-detail character representations

A single resolved 3D scene can drive:

```text
world side view
world front view
three-quarter view
mounted view
interaction sprite
portrait close-up
cinematic close-up
inventory paper doll
```

These share:

- identity;
- morphology;
- pose phase;
- contact graph;
- facial state;
- surface contamination;
- anatomy configuration;
- clothing state.

Each representation may apply art-directed corrections:

- stronger facial expression;
- clearer contours;
- slightly separated overlapping limbs;
- enlarged hands or eyes;
- stronger curve depiction;
- simplified world details;
- more detailed close-up shading.

A close-up is not a scaled gameplay sprite. It is another output profile from the same scene state.


### 19.1 Compiled representation contract

Before a representation becomes a sprite package, it must bind to an exact `CompiledRepresentationContract` describing which resolved geometry it depicts and which approximation limits are permitted.

The contract prevents a renderer, hitbox system, interaction solver, or close-up from silently using different morphology interpretations.

```text
CompiledRepresentationContract
├── canonical creature/version identity
├── resolved geometry snapshot hash
├── represented morphology vector
├── represented anatomy/module configuration
├── garment/hair/accessory configuration
├── pose or interaction package identity
├── camera/representation profile
├── registration and visible-geometry contract
├── accepted approximation/error bounds
└── generation/compiler versions
```

### 19.2 Generated-cache identity and invalidation

Generated artifacts should be cached by resolved dependencies rather than file names alone.

A cache key should include, as applicable:

```text
body family/profile version
+ resolved morphology-vector hash
+ persistent/temporary deformation-state hash
+ rig and component-graph versions
+ garment, hair, and accessory IDs/versions
+ pose/interaction package version
+ camera and representation profile
+ render/pixel-style settings
+ palette/material schema version
+ atlas compiler version
```

Any dependency change invalidates the affected derived package. Cache reuse must never cross incompatible geometry, rig, garment, camera, or compiler versions.

### 19.3 Generated scene and representation packages

The resolved 3D source should compile into an explicit package rather than an undocumented collection of sprite sheets:

```text
SceneRepresentationPackage
├── scene/interaction identifier
├── representation profile
├── authored frame sequence
├── palette/material channels
├── depth and occlusion data
├── surface-coordinate data
├── effect and event markers
├── transition metadata
├── customization coverage manifest
├── validation report
└── source-generation signature
```

This package can still be extremely inexpensive at runtime: select frames, apply semantic palettes and permitted overlays, then draw. The generality belongs primarily in the authoring and generation pipeline.

### 19.4 Scene customization coverage manifest

Every scene and representation must declare exactly which customization dimensions it supports. Unsupported combinations must never fail silently.

```text
SceneCoverageManifest
├── logical morphology ranges
├── represented morphology mode and tolerances
├── exact-generation requirements
├── anatomy configurations
├── rig families
├── hairstyles
├── facial-feature variants
├── palette channels
├── clothing and garment states
├── accessories
├── participant counts and roles
├── close-up availability
├── fluid/surface-state support
├── transition modes
└── fallback policy per dimension
```

Supported fallback policies are:

```text
fully_supported
generated
nearest_supported_variant
authored_override
hidden_for_scene
scene_incompatible
```

Examples:

- Colors may be `fully_supported` through semantic palette mapping.
- A hairstyle may be `generated`, may use an `authored_override`, or may make the scene `scene_incompatible`.
- An accessory may be intentionally `hidden_for_scene` only when that behavior is declared and visually justified.
- An unsupported morphology must not quietly reuse a visibly broken atlas.

The manifest should be generated and validated with the package, and it should be visible in authoring diagnostics.

### 19.5 Authored pixel cadence

Simulation time, choreography time, and visible sprite cadence are separate. Pixel-art animation should not be interpolated merely because the game runs at a high frame rate.

```text
simulation_rate: 60 Hz
interaction_phase_rate: continuous or fixed-step
sprite_authored_rate: commonly 6–12 fps
frame_hold_pattern: authored
effect_update_rate: independent
```

The authored sequence may use:

- repeated held frames;
- asymmetric timing;
- longer anticipation or recovery holds;
- short impact/contact frames;
- faster droplets, particles, or interface effects than body animation.

The exporter should preserve intentional pixel clusters and authored holds. It must not create subpixel shimmer by synthesizing intermediate body frames unless the selected representation explicitly supports that treatment.

### 19.6 Implementation support tiers

Not every scene should be forced to use the most dynamic implementation. Each package selects the least expensive tier that satisfies its design requirements.

```text
Tier 0 — Fixed
  One fully baked composition with fixed silhouettes.

Tier 1 — Palette-parametric
  Fixed geometry with semantic skin, hair, eye, clothing, and effect colors.

Tier 2 — Discrete variants
  Authored body presets, hairstyles, garment states, cameras, or participant variants.

Tier 3 — Generated variants
  Morphology- and configuration-specific atlases generated from the 3D source and cached.

Tier 4 — Runtime hybrid
  Baked/generated bodies plus dynamic masks, optional roles, surface state, limited retargeting, and effects.

Tier 5 — Live resolved (future/alternative runtime)
  Runtime low-resolution 3D or fully dynamic choreography and rendering.
  This tier is not required by the current 2D-only renderer milestone.
```

A polished Tier 1 or Tier 2 scene is preferable to an unstable Tier 5 scene. The architecture must allow fixed, art-directed output while preserving a path to more general generation where the game actually needs it.

---

## 20. Baked, dynamic, and hybrid decisions

| Feature | Treatment |
|---|---|
| Base skeletal animation | Baked from 3D |
| Skin, hair, eye, outfit, and accessory color | Dynamic semantic palette/material mapping |
| Player-facing body presets | Parameter presets; resulting silhouettes baked/generated as needed |
| Continuous weight and morphology values | Continuous logical parameters resolved through authored paths/axes |
| Resolved geometry snapshot | Deterministic generated contract consumed by all downstream systems |
| Quantized visual morphology | Allowed only within declared error tolerances; visible geometry data must match the represented sample |
| Source UV/material atlases | Reused across compatible geometry where semantic correspondence remains stable |
| Compiled 2D sprite atlases | Derived and regenerated when silhouette, pose, garment fit, or representation requires it |
| Hairstyle silhouette changes | Discrete or generated representation variants |
| Scene-to-scene presentation | Explicit hard cut, fade, bridge, reset, or transactional mode |
| Major multi-actor contact choreography | Baked or generated/cached |
| Complex transition between choreography states | Authored transition graph, then baked/generated |
| Body-proportion retargeting | Solved in 3D, then baked/generated |
| Major soft-tissue bounce/compression | Solved offline and baked |
| Minor secondary particles | Dynamic |
| Facial expressions | Baked variants/layers |
| Major anatomy-state changes | Hybrid geometry state |
| Rage-related enlargement | Hybrid |
| Pregnancy progression | Persistent morphology layer with periodic regeneration |
| Intentional penetration visibility | Baked when possible; depth-masked when variable |
| Restraints | Dynamic constraints plus authored corrections |
| Clothing access and lifting | Hybrid garment state plus authored/procedural motion |
| Minor garment pressure detail | Dynamic material/normal/palette effect |
| Major garment silhouette displacement | Generated/baked garment variant |
| Wetness amount | Dynamic surface state |
| Wet cloth clinging | Hybrid |
| Droplets and streams | Dynamic effects |
| Persistent residue/stains | Dynamic canonical surface map |
| Large pools/puddles | Dynamic surface/prop/world state |
| Clothing tears | Garment-state variant |
| Vision obstruction | Dynamic sensory state plus visual overlay/animation |
| Sound masking | Dynamic sensory simulation |
| Close-up | Separate high-detail representation |
| Stamina, interest, comfort, pain, pleasure, fatigue | Dynamic gameplay state |
| Quest/relationship/economy outcomes | Dynamic game systems |

General rule:

> If it changes silhouette, joint relationships, major tissue shape, or contact geometry, generate or bake it. If it changes color, residue, small surface detail, particles, or perception, keep it dynamic. If it changes both, use a hybrid.

---

## 21. Persistent state and outcomes

The interaction system reports facts. It does not directly own quest logic.

```text
InteractionOutcome
├── participant roles
├── completion state
├── fatigue changes
├── mood changes
├── relationship signals
├── cleanliness changes
├── contamination transfer
├── clothing state changes
├── injuries
├── sensory impairment
├── reproduction-relevant events
├── witness/attention events
└── encounter-specific signals
```

The game/encounter layer decides consequences.

Example:

```text
encounter_goal: persuade_guard

success:
  door_unlocked
  guard_allows_passage

relationship_change:
  optional or zero
```

The same physical interaction can have different narrative meaning in another encounter.

---

## 22. Pregnancy and long-term morphology

The interaction emits a reproduction-relevant event. A separate reproduction system decides whether conception occurs.

```text
ReproductiveExposureEvent
├── participants
├── anatomy sites
├── timing
├── protection state
├── fertility state
└── species/reproduction profiles
```

If conception occurs:

```text
PregnancyState
├── gestational progress
├── parent/genetic references
├── offspring profile
├── morphology progression
├── symptoms/stat modifiers
├── clothing-fit consequences
└── outcome rules
```

Pregnancy affects:

- body morphology;
- collision;
- clothing fit;
- animation corrections;
- stamina;
- movement;
- close-up and world representations.

Fantasy species may use eggs, spores, magical creation, fabrication, or other explicit reproduction profiles.

---

## 23. Creature archetypes and future extensibility

Do not use one universal skeleton. Do not create one unrelated engine per species.

Use rig archetype families:

```text
humanoid_biped
avian_biped
pterosaur
quadruped_plantigrade
quadruped_digitigrade
quadruped_unguligrade
cetacean
fish
serpentine
arthropod
cephalopod
amorphous
```

Shared engine contracts:

- transforms;
- modular anatomy;
- material roles;
- capabilities;
- effectors;
- emitters;
- contacts;
- constraints;
- surface state;
- representation profiles;
- diagnostics.

Archetype-specific implementations:

- gait;
- foot/paw/hoof contact;
- balance;
- wingbeat;
- swim undulation;
- jaw behavior;
- tentacle solving;
- clothing topology.

### 23.1 Capability-based behavior

The engine asks:

```text
Does it support swimming?
Does it expose a rideable surface?
Does it have grasp-capable effectors?
Does it have a jaw strike?
Does it have wings?
Can it pull a vehicle?
Does it have compatible role adapters?
```

It should not hardcode:

```text
if species == horse
if species == bear
if species == dragon
```

### 23.2 Generic intent to specific animation

Example strike mapping:

```text
generic intent:
  strike target upper torso

human adapter:
  fist/palm/elbow

bear adapter:
  forepaw swipe

bird adapter:
  beak/talon/wing

robot adapter:
  installed manipulator
```

They share targeting, timing, impact, damage, and reaction contracts, but use different rig-family animations.

---

## 24. Dog and horse derivation workflow

Project-wide preferences should be inherited automatically:

- meters;
- coordinate conventions;
- naming;
- control/deformation separation;
- semantic sockets;
- variable component counts;
- corrective shapes;
- JSON definitions;
- representation profiles;
- atlas rules;
- diagnostics;
- capability-based interactions.

Then derive a proposed species specification from:

```text
project preferences
+ rig archetype template
+ species anatomy/locomotion requirements
→ proposed rig
→ difference/risk report
→ owner review
```

### Dog proposal should test

- digitigrade quadruped anatomy;
- paws;
- jaw-centered interaction;
- tail communication;
- expressive ears;
- breed morphology;
- low-to-ground movement;
- sitting, lying, running, biting, carrying.

### Horse proposal should test

- unguligrade limbs;
- hoof contacts;
- long cervical chain;
- saddle seats;
- reins;
- harness sockets;
- cart pulling;
- mounted rider response;
- large-body collision.

This avoids manually repeating every human design question while still requiring review of genuinely species-specific decisions.

---

## 25. Integrated vertical slice

The adult vertical slice should occur only after the major components exist independently. It should be built in two deliberately separated passes:

> First prove that the system can match the stability, readability, and art direction of a conventional baked preset system. Then prove that the same source data supports generation, persistence, transitions, optional participants, and validation beyond what a purely baked system normally provides.

### 25.1 Phase A — baked-system parity benchmark

The first pass should remain intentionally constrained:

```text
Participants:
  two consenting adult sapient humanoids

Environment:
  one furniture asset

Representation:
  one fixed gameplay loop
  one separately rendered close-up

Customization:
  three visibly different PlayerMorphologyPresets
  one guaranteed supported hairstyle
  dynamic skin, hair, and eye palettes

Presentation:
  hard-cut gallery/debug selector
  explicit authored pixel cadence
  one temporary fluid/effect overlay
```

Required outputs:

- a `SceneRepresentationPackage`;
- a complete `SceneCoverageManifest`;
- deterministic frame timing and hold patterns;
- stable silhouettes and contact readability;
- no palette leakage between semantic regions;
- no unsupported customization accepted silently;
- one close-up that clearly represents the same character identity and scene state.

This pass establishes that the 3D-authored pipeline can equal the reliability and clarity of a conventional preset sprite-sheet implementation.

### 25.2 Phase B — general-system differentiation

The second pass should prove what the broader architecture adds:

- generate the same interaction for all three body profiles from the 3D source;
- preserve one persistent surface mark between gameplay loop and close-up;
- transition continuously to a second position through transactional choreography;
- permit one optional third adult participant to observe and join at a legal synchronization point;
- reject or redirect one geometrically invalid morphology/role combination;
- demonstrate one garment access or body/garment-channel interaction;
- carry fatigue, mood, cleanliness, and contamination into the aftermath;
- report one encounter/world outcome.

### 25.3 Expanded participants and environment

```text
Participants:
  two required consenting adult sapient humanoids
  one optional third adult participant

Environment:
  one furniture asset
  one restraint asset

Representations:
  one gameplay view
  one detailed close-up
  one second choreography state
```

### 25.4 Morphology and anatomy tests

- at least three substantially different body profiles;
- clear separation between `PlayerMorphologyPreset` and `InteractionValidationBand`;
- one anatomy configuration transition;
- one intentional-penetration path;
- one compound hand/wrist/forearm insertion/contact test;
- one garment access/channel test;
- one body-size-dependent occlusion test;
- one restrained transition rejection or correction;
- one declared unsupported customization fallback.

### 25.5 Choreography tests

- looping synchronized motion;
- authored low-frame-rate pixel cadence independent of simulation rate;
- participant-specific fatigue;
- optional observer;
- observer-to-participant transition;
- one major multi-contact position change;
- ordered disengagement;
- bridge pose;
- reorientation;
- re-engagement;
- one participant finishing earlier;
- role switching;
- scene continuation and termination;
- both a hard-cut presentation transition and a continuous transactional transition used in appropriate contexts.

### 25.6 Surface and fluid tests

- one configurable fluid profile;
- emission;
- stream/droplets;
- body contact;
- garment contact;
- furniture contact;
- transfer;
- pooling;
- partial drying;
- persistent residue;
- cleaning requirement;
- eye-contact impairment test.

### 25.7 State and world-outcome tests

State channels:

- stamina;
- interest/desire;
- comfort;
- pain;
- pleasure;
- fatigue;
- cleanliness;
- mood;
- sensory impairment.

At least one encounter result should be produced, such as:

- route opened;
- guard distracted;
- payment/tip generated;
- witness/reputation event;
- relationship signal;
- fatigue and cleanliness consequences.

### 25.8 Pregnancy integration test

The first integrated slice need only verify:

- a reproduction-relevant event is emitted;
- the reproduction system receives it;
- a deterministic test conception can create persistent state;
- morphology preview changes;
- clothing/animation systems detect the new body state.

A full gestation simulation is not required for the first slice.

---

## 26. Recommended implementation order

1. Lock the canonical coordinate, measurement, handedness, origin, facing, and naming contract.
2. Lock deterministic/versioned JSON schemas for skeletons, components, morphology, materials, visibility, and generated manifests.
3. Complete the human anatomy, component graph, neutral bind pose, and morphology specification.
4. Implement one minimal neutral human body/rig with no scene-specific interaction assumptions.
5. Implement `ResolvedCreatureGeometrySnapshot` generation and validation.
6. Prove complete-body resolution before modular render-piece, seam, landmark, hitbox, and socket derivation.
7. Implement continuous low/high weight-path resolution plus independent morphology axes.
8. Implement semantic material/palette roles and stable source UV/material correspondence.
9. Implement source garment fitting against the resolved geometry snapshot.
10. Define `CompiledRepresentationContract`, `SceneRepresentationPackage`, and `SceneCoverageManifest` schemas.
11. Implement adaptive morphology sampling, exact generation, cache identity, and invalidation.
12. Implement auxiliary surface-coordinate/depth/region export.
13. Implement basic single-actor skeletal animation and held-frame pixel export.
14. Define explicit transition-mode and authored-cadence metadata.
15. Implement the generic contact graph.
16. Implement prop/furniture anchors and depth fragments.
17. Implement restraints as constraints.
18. Implement multi-actor roles and master phase.
19. Implement transactional choreography transitions.
20. Implement morphology retargeting, validation bands, and geometry diagnostics.
21. Implement soft-tissue offline response.
22. Implement intentional penetration and authorized occlusion.
23. Implement garment fragments, material properties, closures, access routes, and body/garment channels.
24. Implement persistent surface maps.
25. Implement the general fluid lifecycle.
26. Implement vision impairment and sound masking.
27. Implement alternate-detail representation cameras.
28. Build the Tier 1/Tier 2 Phase A parity benchmark.
29. Derive minimal dog rig and fixtures from the inherited project contract.
30. Derive minimal horse rig and fixtures from the inherited project contract.
31. Remove hidden human-only assumptions from shared schemas.
32. Build the Phase B generated/hybrid vertical slice.
33. Expand with an optional third participant and role switching.
34. Decide which production scenes require Tier 3, Tier 4, or Tier 5 behavior.
35. Freeze shared creature/interaction schema 1.0 only after human, dog, horse, resolved-snapshot, coverage-manifest, and vertical-slice results are compared.

---

## 27. Decisions currently established

- Offline 3D remains the source of truth.
- The system is a creature-authoring system, not a humanoid-only generator.
- Final gameplay output may remain deterministic pixel art.
- The current production runtime remains 2D-only; offline 3D authoring does not imply a current live-3D runtime dependency.
- Anatomy uses variable-count modules and semantic tags.
- Species identity, rig topology, personhood, lifecycle, capability, and content eligibility are separate.
- Adult sexual roles are limited to consenting adult persons with explicit compatibility.
- Multi-actor interactions use choreography graphs, not monolithic clips.
- Membership is separate from current role.
- Contacts have ownership and release policies.
- Major state switches use transactional transition graphs.
- Cooperative transitions and contested transitions use the same framework with different arbitration.
- Restraints are dynamic constraints plus authored pose corrections.
- Geometry, comfort, and skill are separate evaluations.
- Body-size-dependent visibility is solved from 3D depth and soft-tissue deformation.
- Clothing uses fragments, material properties, access routes, and body/garment channels.
- Nipple and erection visibility through clothing depends on clearance, padding, compression, stiffness, and stretch.
- Fluids use general emitters, lifecycle, surface transfer, pooling, drying, staining, and cleaning.
- Persistent marks live in canonical surface space.
- Eye contamination affects the gameplay vision sensor.
- Loud sounds mask other sounds through signal-to-mask perception rather than globally disabling hearing.
- Major geometry changes are baked/generated; surface state and particles remain dynamic; mixed cases are hybrid.
- Close-ups are separate representations of the same resolved 3D scene.
- Interactions emit outcomes; game systems apply narrative and persistent consequences.
- Pregnancy is a separate persistent simulation driven by interaction events.
- Dog and horse specifications should be derived from inherited project preferences and archetype templates.
- Every scene/representation package declares supported customization and explicit fallbacks.
- Player-facing morphology presets are distinct from interaction-validation bands.
- Scene transitions explicitly choose hard cut, fade, bridge, reset, procedural, or transactional behavior.
- Pixel sprite cadence is authored independently from simulation and effect update rates.
- Each scene uses the least complex implementation tier that satisfies its design and quality requirements.
- The first vertical-slice pass matches conventional baked-system reliability before advanced generalization is tested.
- The canonical 3D definition, resolved geometry snapshot, resolved scene snapshot, and compiled representation package are distinct data stages.
- Weight is an authored low/high morphology path, not a global scale multiplier.
- Weight remains only one axis within a broader body-family and independent-proportion system.
- The complete body resolves before modular render pieces, seams, garments, landmarks, and hitboxes are derived.
- Source UV/material atlases are distinct from compiled 2D sprite atlases.
- One source garment is fitted to the resolved body before rasterization; compiled garment sprites are derived artifacts.
- Continuous logical morphology may use exact, adaptive-sampled, or live visual representations according to declared tolerances.
- Visible registration, hitboxes, and close-contact geometry must match the represented morphology, not an undisclosed logical value.
- Generated representation caches are keyed and invalidated by all geometry-, rig-, garment-, interaction-, camera-, style-, and compiler-relevant versions.
- The “3D Model Pipeline Step” specification owns canonical anatomy and rig decisions; this record owns downstream composition, interaction, representation, and acceptance requirements.
- Shared schema 1.0 should not be frozen until human, dog, horse, coverage-manifest, and integrated interaction tests have exposed hidden assumptions.

---

## 28. Major decisions still open

1. **Runtime representation strategy:** generated/cached atlases versus live low-resolution 3D for the most dynamic interactions.
2. **Pixel auxiliary-buffer budget:** exact channel packing for surface ID, UV, material, depth, normal category, and region ID.
3. **Garment solver fidelity:** authored state variants versus runtime cloth deformation limits.
4. **Soft-tissue solver choice:** bones, corrective shapes, cages, simulation, or a hybrid.
5. **Interaction authoring UX:** timeline editor, role graph editor, constraint visualization, transition planner, and coverage-manifest editor.
6. **Morphology path and sampling policy:** which axes use linear versus authored curves, how validation bands are defined, and what error thresholds trigger adaptive subdivision or exact generation.
7. **Persistent contamination resolution:** per-character texture size and update frequency.
8. **Runtime fluid fidelity:** region-flow graph only versus limited particle-to-surface simulation.
9. **Generated atlas cache operations:** final key serialization, storage budget, invalidation granularity, persistence, loading behavior, and eviction; the required dependency categories are established.
10. **Content authoring policy:** exact game-specific eligibility, consent, interruption, and encounter rules.
11. **Coverage fallback policy:** which customization dimensions may use nearest variants, authored overrides, scene hiding, or incompatibility.
12. **Pixel cadence profiles:** default authored rates and hold-pattern conventions by representation and animation category.
13. **Support-tier boundaries:** which capabilities formally distinguish Tier 2, Tier 3, Tier 4, and Tier 5 packages.
14. **Hair and accessory compatibility:** when to regenerate, substitute, hide, or reject silhouette-changing customization.
15. **Parity acceptance bar:** objective pixel-readability, contact, silhouette, and palette criteria required before Phase B begins.
16. **Resolved-snapshot persistence:** whether snapshots are stored as durable intermediate artifacts, regenerated on demand, or both.
17. **Representation-error classes:** default silhouette, landmark, contact, and garment-clearance tolerances for distant world sprites, close combat, furniture interactions, portraits, and cinematic close-ups.
18. **Topology-family boundaries:** exact conditions that require a new morphology family/module configuration rather than a continuous morph or corrective shape.
19. **Generated-body versus generated-scene cache layering:** which outputs are reused across poses/scenes and which must be regenerated as interaction-specific composites.

These decisions do not need to block current human anatomy, rig, component graph, and offline export work, provided the contracts remain extensible.

---

## 29. Handoff checklist for future “3D Model Pipeline Step” decisions

When locking any remaining body part, facial control, anatomy module, material region, or rig feature, verify that the definition provides enough data for the downstream pipeline.

### 29.1 Required canonical data

- stable component ID and semantic tags;
- parent relationship and typed sockets;
- multiplicity/capacity rules;
- canonical reference transform;
- deformation bones and animator controls;
- skin weights, morphs, and corrective shapes;
- stable semantic surface regions and canonical coordinates;
- seam/ring definitions where the module connects to another surface;
- collision proxy and interaction effectors/sites where applicable;
- emitter points where applicable;
- material and palette roles;
- visibility and coverage policy;
- supported representation profiles and required view corrections;
- deterministic JSON serialization and schema version.

### 29.2 Morphology requirements

For every morphology control or state:

- declare whether it is permanent, persistent, temporary, pose-driven, or representation-only;
- declare whether it is continuous, discrete, or a topology/module switch;
- define valid ranges and authored endpoints/curves;
- define which bones, surfaces, collisions, sockets, garments, and interaction sites move with it;
- define corrective shapes and failure limits;
- preserve stable topology/surface correspondence when the control is classified as continuous;
- identify when exact representation generation is required.

### 29.3 Interaction requirements

For any body part that can contact, grasp, support, insert, receive, emit, restrain, strike, bite, mount, or carry:

- expose semantic effectors/sites rather than relying on species-specific code;
- define local coordinate frames and approach cones;
- define occupancy and simultaneous-contact capacity;
- define authorized penetration/contact volumes;
- define release and state-transition behavior;
- define comfort/safety/deformation envelopes where applicable;
- define visibility/occlusion behavior for 2D export.

### 29.4 Garment and representation requirements

For any body change that affects clothing or silhouettes:

- expose a garment-fitting surface or correspondence;
- identify tight, loose, structured, or rigid fitting implications;
- identify likely access routes and coverage behavior;
- identify whether the change requires a new compiled sprite representation;
- identify which close-up and world-view corrections are expected;
- ensure generated registration and hitboxes derive from the same represented geometry.

### 29.5 Decision-record rule

The model-pipeline chat should use this document as a downstream-requirements checklist, but should continue to record the final canonical anatomy and rig choices in its own source-of-truth document. Once a canonical choice is accepted, this architecture record should reference or inherit it rather than maintaining an independent competing definition.

