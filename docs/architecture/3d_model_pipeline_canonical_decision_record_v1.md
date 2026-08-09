# Canonical 3D Model Pipeline — Consolidated Decision Record

**Status:** Working source of truth  
**Revision:** 1 — consolidated from the current 3D model-pipeline design thread  
**Date:** 2026-08-07  
**Primary scope:** Canonical human/creature authoring data, rig, morphology, deformation, animation, materials/surfaces, registration/export, and the first `human_base` asset  
**Immediate implementation target:** Offline canonical 3D human source that can generate deterministic, validated 2D representations; future live 3D remains compatible but is not required

---

## 0. Authority, precedence, and status language

This document consolidates the decisions explicitly accepted in the current design thread.

### Decision precedence

1. **This record is the current source of truth for the canonical 3D model pipeline.**
2. When an older architecture document disagrees with a decision recorded here, **the newer decision here wins for canonical anatomy/rig/model-pipeline behavior**.
3. The existing creature/interaction architecture record remains a **downstream requirements record** for composition, garments, interactions, representation, caching, and runtime integration. It does not silently redefine canonical anatomy.
4. Future explicit decisions supersede this record only when deliberately accepted and versioned.

Two known older-record conflicts already resolved in favor of this record:

- The canonical asset origin is **centered between the feet on the ground in the A-pose**, not at the pelvis.
- The canonical tongue uses **four shared deformation bones plus an explicit branching point**, not the older simplified root/mid/tip summary.

### Status labels

- **LOCKED** — accepted design decision.
- **DEFERRED** — architecture/support remains open, but implementation is intentionally postponed.
- **EXCLUDED** — explicitly not part of the current design/scope.
- **OPEN/TUNING** — implementation detail intentionally left for empirical tuning once the real model/editor exists.

Unless otherwise marked, decisions in sections 1–19 are **LOCKED**.

---

# 1. Core coordinate and measurement contract

## 1.1 Units and numeric representation

- World/model units are **meters**.
- Canonical numeric precision is **`f32`**.
- Normal authoring/UI measurement increment is **0.001 m (1 mm)**.
- Internal calculations may produce finer fractional values; the 1 mm step is an authoring convenience, not a forced quantization rule.
- Imperial values are **display/input conversions only**. The underlying simulation remains metric.
- Examples:
  - `1.0` = 1 meter
  - `0.01` = 1 centimeter
  - `0.001` = 1 millimeter
- `f64` is not required for the canonical character pipeline. If very large worlds later cause `f32` positional precision issues, solve them with room/local coordinates or a floating-origin strategy rather than changing the human rig contract.

## 1.2 Coordinate-system orientation

Use a **right-handed coordinate system**.

- `+X` = world/viewer right
- `+Y` = up
- `+Z` = toward the camera
- `-Z` = away from the camera
- Canonical model forward = `+Z`

`left` and `right` in anatomical IDs always mean **the character's anatomical left/right**, not screen/viewer left/right.

## 1.3 Ground and origin

- Local floor/ground reference is `Y = 0`.
- The canonical **asset origin** is centered between the feet on the ground in the neutral A-pose.
- This is a model/asset reference, not a requirement that the runtime origin remain physically under the feet during every animation.
- A runtime entity transform places the character in the world; the skeleton remains local to that entity.

## 1.4 Bind pose and canonical size

- Bind/rest pose = **A-pose**.
- Canonical height = **1.8288 m (6 ft)**.
- Height/proportion sliders may resolve shorter or taller characters from this baseline.
- Target height is stored directly; users do not need to enter a derived scale ratio.

## 1.5 Facing behavior

This is separate from the canonical model forward direction.

- Runtime facing uses **input intent**, not actual velocity.
- A character pushing into a wall can still face the attempted direction.
- Idle-facing behavior is **developer-configurable per game**, e.g.:
  - `front_when_idle`
  - `retain_last_direction`
  - explicit animation/state-driven facing

---

# 2. Core terminology

These definitions are canonical because many later systems depend on them.

## 2.1 Bone

A rig **bone** is fundamentally a hierarchical transform node, not necessarily a literal anatomical bone.

A bone may have:

- position/pivot
- orientation
- scale
- parent
- optional editor-visible/display length

The displayed stick/arrow/sphere is editor visualization only.

### Bone length vs scale

- Rest/display length describes the normal axis/child relationship and is useful for visualization.
- Scale transforms the bone and may affect effective length.
- They are not the same concept.

## 2.2 Deformation

**Deformation** means any controlled change in mesh shape, not necessarily damage.

Examples:

- bending an arm
- blinking
- breathing
- muscle flexing
- soft-tissue movement
- impact compression
- temporary swelling
- contact displacement

Tearing/popping also changes shape, but additionally changes topology.

## 2.3 Deformation bone

A **deformation bone** directly influences mesh vertices through skin weights.

A non-deformation/helper/control node may still translate, rotate, and scale; it simply does not directly skin/deform the mesh.

## 2.4 Animator-facing control

A **control** is an authoring/runtime handle that drives bones, morphs, constraints, or other lower-level mechanisms.

Typical flow:

```text
animator/gameplay control
→ deformation bones / morphs / solver
→ mesh
```

Controls are deliberately simpler than manually editing every deformation bone.

## 2.5 Anchor, socket, mount anchor, interaction site, effector

- **Anchor:** stable semantic coordinate frame attached to a component/body area.
- **Socket:** an anchor that accepts an attachment. Every socket is an anchor; not every anchor is a socket.
- **Mount anchor:** the coordinate frame on a child component that aligns to a parent socket.
- **Interaction site:** semantic contact region where a solver may choose an exact contact point.
- **Effector:** body part/object that performs an interaction, such as a hand, foot, mouth, weapon edge, etc.

---

# 3. Naming, identity, transforms, and versioning

## 3.1 Canonical naming

Machine-facing IDs use **lowercase `snake_case`**.

Rules:

- `left` / `right` = character anatomical side.
- Repeated structures use `_01`, `_02`, etc.
- Use `center`, not `middle`, for midline structures.
- IDs are **stable and immutable once published**.
- Human-readable display names are separate from machine IDs.
- References use IDs, never array positions.
- Parent relationships are not encoded into IDs.
- Prefer semantic names to generic names like `bone_17`.
- Exotic/custom components follow the same naming conventions.

Examples:

```text
skeleton_root
spine_01
eye_left_01
eye_center_01
ear_right_01
```

## 3.2 Schema, asset, and compiler versions

Keep these separate:

- `schema_version` — canonical data-contract version
- `asset_version` — version of a particular asset using that schema
- `compiler_version` — version of generation/compilation logic

### M01 locked semantic-version encoding

`SchemaVersion`, `AssetVersion`, and `CompilerVersion` are separate strongly typed identities. Each contains:

```text
{ major, minor, patch }
```

`major`, `minor`, and `patch` are unsigned integers. The three version kinds are not interchangeable. Prerelease identifiers and build-metadata strings are not part of the current canonical contract, and schema, asset, and compiler versions remain independent identities.

## 3.3 Bone transform storage

Canonical files store **local, parent-relative transforms only**.

Each bone may store:

- local position in meters
- local rotation as quaternion
- local XYZ scale

Global/world transforms are derived at runtime/editor/build time and may be cached, but are not a second authoritative copy.

Rotation data is stored canonically as a **quaternion**; editors may display/manipulate ordinary XYZ degrees.

### M01 locked hierarchical transform semantics

Canonical source transforms remain local, parent-relative TRS only:

- translation is measured in meters;
- rotation uses the canonical quaternion component order `[x, y, z, w]`;
- scale is XYZ `f32`;
- no global or world transform is serialized as canonical source authority.

The mathematical transform order for a local point is scale, then rotate, then translate:

```text
p_parent = translation + rotate(rotation, scale ⊙ p_local)
```

Here, `⊙` is component-wise XYZ scale. Hierarchy composition uses affine-transform composition with column-vector mathematical semantics:

```text
M_global = M_parent * M_local
```

This defines the mathematical convention only and does not require a particular row-major or column-major in-memory matrix layout. Quaternion rotations are active right-handed rotations. Where rotational composition is applicable, the child/local rotation is relative to the parent and uses the Hamilton product:

```text
q_global = q_parent * q_local
```

Non-uniform parent scale combined with child rotation may produce shear in the composed global affine transform. Derived global transforms may therefore be represented internally as affine matrices/transforms without decomposing an arbitrary result back into TRS. A decomposed global TRS is not canonical authority. Canonical source authority remains the local TRS hierarchy, and all derived global/affine transforms are transient computed data.

### M01 locked quaternion canonical identity

- Component order is `[x, y, z, w]`.
- Every component must be finite.
- Input must satisfy `abs(length_squared - 1.0) <= 1e-5`.
- Input within that tolerance is normalized to exact unit length before canonical serialization or hashing.
- Input outside that tolerance fails validation and is not silently repaired.
- `q` and `-q` represent the same rotation and normalize to identical canonical bytes.
- Canonical hemisphere selection prefers `w > 0`. If `w == 0`, the first nonzero component in `x`, then `y`, then `z` must be positive.
- Canonical numeric normalization converts `-0.0` to `+0.0`.

Quaternion normalization is part of canonical identity and occurs before deterministic serialization and hashing.

## 3.4 Canonical angles

- Canonical joint/angle values use **radians**.
- Editor/UI displays **degrees**.

---

# 4. Root hierarchy and canonical skeleton

## 4.1 Top-level structure

```text
entity/world transform
└── skeleton_root
    └── pelvis
```

- Entity transform handles world placement.
- `skeleton_root` is the stable skeletal/animation reference.
- Pelvis remains free to animate.

## 4.2 Spine

Canonical human spine:

- **7 spine deformation bones**
- **5 animator-facing controls**
  - 4 regional controls
  - 1 whole-spine curve/global control

The spine controls distribute bend/twist automatically across the seven deformation bones, spline-IK style.

Capabilities:

- whole-back bend
- twist
- S-curve
- cat-cow style curvature
- regional lower/upper refinements
- configurable distribution rather than forced equal rotation

The seven deformation bones are not normally manipulated individually.

## 4.3 Neck

- **3 neck deformation bones**
- Smooth weights into upper torso/shoulders/head
- Sufficient for close-ups
- Neck smoothness comes from geometry, weighting, and correctives, not from the neck behaving as three rigid segments

## 4.4 Head and jaw

- Separate **head/skull deformation bone**
- Separate child **jaw deformation bone**
- Jaw supports broad mouth opening plus small forward/backward/left/right shift

## 4.5 Mouth internals

Canonical hierarchy/support includes:

- upper teeth
- upper gums/palate
- lower teeth
- lower gums
- mouth-cavity/internal geometry
- tongue

Upper teeth/gums follow the head; lower teeth/gums follow the jaw.

### Tongue

- **4 shared tongue deformation bones**
- Explicit semantic branch point after the shared chain
- Default = one terminal tip
- Schema permits multiple terminal branches/tips
- Optional extra branch/tip bones for independently curling forked tips
- Initial human implementation uses one normal unbranched tongue

## 4.6 Healthy mouth morphology

The initial human profile uses normal healthy adult dentition.

Teeth/gums:

- full normal adult set by default
- healthy alignment/spacing
- normal white/off-white enamel
- shared controls for overall tooth size and dental-arch width/depth
- universal/default gum amount with advanced override later
- healthy gum color/material by default
- individual teeth retain semantic identity so missing/damaged/custom variants can be added later

Tongue morphology:

- length
- width
- thickness
- taper
- tip width/roundness
- resting curvature
- surface roughness/papillae detail
- color/material
- optional fork/branch morphology when the component topology uses it

**DEFERRED:** missing/crooked/damaged/unusually colored/custom teeth are supported by schema but not required initially.

## 4.7 Joint and range-of-motion schema

Each articulated joint has:

- stable `joint_id`
- parent and child bone references
- joint type, such as hinge-like, ball-and-socket, multi-axis, or twist
- preferred/soft range
- hard/absolute range
- preferred bend direction
- swing/twist limits where applicable
- stiffness approaching limits
- default human mobility profile
- optional character/profile mobility override

Canonical angle data uses radians; editor shows degrees.

**Joint range and body collision are separate constraints.** A pose can be within anatomical joint range but still invalid because a limb intersects the torso or another body part.

Male-typical/female-typical presets may provide different starting mobility values if desired, but sex does not hardcode joint limits. Character-specific flexibility/mobility remains independently configurable.

Exact numeric limits are **OPEN/TUNING** and should be tuned in the editor against validation poses.

## 4.8 Animator-control schema

Animator-facing controls have stable IDs and explicit drive relationships.

Core control types include:

- FK rotation control
- IK target
- pole/direction control
- curve/spline control
- whole-region control
- normalized slider control
- look target
- procedural grasp control

A control may declare:

- `control_id`
- control type
- driven bones/morphs/constraints
- control space
- mirror control ID
- limits/defaults
- semantic region/tags

Controls are authoring/runtime handles; they are not synonymous with joints.

---

# 5. Eye, brow, face, ears, hair, and head details

## 5.1 Skull, head, and neck morphology

### Skull/head morphology

Controls:

- overall head height/width/depth
- cranium size/roundness
- forehead height/width/slope/projection
- temple width
- face height/width
- upper/mid/lower-face proportions
- cheekbone-to-skull width relationship
- rear-skull projection
- narrow ↔ broad
- long ↔ short
- angular ↔ rounded
- head-to-body proportion
- advanced asymmetry

Male-typical/female-typical and other presets provide starting values only; no control is sex-restricted.

Existing eyes, nose, ears, jaw, hairline, etc. reposition from the resolved head morphology rather than staying at hardcoded coordinates.

### Neck morphology

The three-bone neck rig supports permanent morphology controls:

- neck length
- circumference
- front/back depth
- left/right width
- skull-to-shoulder taper
- trapezius transition
- sternocleidomastoid prominence
- throat/larynx prominence
- tendon/muscle definition
- fat/soft-tissue coverage
- overall muscularity
- flex/strain state
- advanced asymmetry

Presets may include slender/average/thick/muscular.

Neck morphology blends automatically into jaw, clavicles, shoulders, and upper torso.

## 5.2 Eye collection and grouping

Eyes are a **variable-count collection**.

Each eye has:

- unique ID
- spatial semantic side: `left`, `center`, or `right`
- index for repeated eyes on a side
- optional eye group

Supports:

- standard two eyes
- cyclops/center eye
- multiple side/center eyes
- asymmetric arrangements

### Primary eye group

- Optional.
- Default human primary group = left/right pair.
- May contain one or more eyes.
- Used by default for:
  - viewing direction
  - field of view
  - aiming
  - conversation focus
  - camera framing
  - gameplay vision sensor orientation
- Secondary groups can provide additional perception directions/cones.
- If no primary group exists, use a **head-attached facial perception anchor** near the center/front of the face.

Gameplay vision sensing is separate from eye meshes/bones.

## 5.3 Eye look targets

- One shared look target by default.
- Optional per-group target overrides.
- Optional per-eye target overrides.
- Configurable convergence for close targets.

## 5.4 Eye morphology

Permanent eye morphology controls:

- eye width/height
- eyeball size
- eye spacing
- vertical position
- deep-set ↔ protruding
- inner/outer corner position
- eye tilt
- upper/lower lid curvature
- exposed-eye shape
- iris size/profile
- pupil size
- sclera visibility
- advanced left/right asymmetry

Composable presets may include round/almond/narrow/deep-set/wide-set/etc.

These morphology values sit underneath the look/blink/socket systems and must not redefine their semantic identities.

## 5.5 Individual eye rig

Each eye uses:

```text
eye_socket_anchor
└── eyeball_deformation_bone
```

- Socket anchor = stable mounting/reference frame at the eyeball rotational center.
- Eyeball bone = rotates/poses the eyeball mesh.
- They may occupy nearly identical positions but have different semantics.
- The socket anchor moves with head/morphology but does not move merely because the eye looks around.

## 5.6 Eyelids

Default per lid:

- inner deformation region/bone
- center
- outer

So **3 eyelid deformation bones/regions per lid by default**.

Optional **5-point eyelid profile** for large/highly expressive eyes.

Behavior:

- bones provide broad motion
- corrective shapes preserve natural curvature/contact
- coordinated blink control
- independent-eye override for winks/injury/etc.
- upper-vs-lower blink contribution is configurable
- closure-line shape/height is configurable
- normal blink remains coordinated/symmetric within one eye

## 5.7 Iris, pupil, cornea, and eye-surface controls

Support:

- pupil dilation
- iris scale/profile
- optional stylized iris/pupil offset
- corneal shape/projection
- eye-surface gloss/wetness/highlights
- optional lens/glow behavior

Eye profiles may be:

- spherical
- flattened
- planar/stylized
- custom

Each may define its own gaze/deformation/blink behavior.

## 5.8 Eye-effect layer

Each eye may expose an effect/emitter layer with:

- emitter/origin anchor
- iris/pupil tint override
- full-eye overlay/color
- glow/emission intensity
- charge-state animation
- beam/effect direction
- optional group-wide effect

**DEFERRED:** eye/iris glow implementation is not required for the first human asset.

## 5.9 Eyebrows

Use a **flexible eyebrow collection**.

Default human profile:

- one brow per eye

Schema allows:

- missing brows
- unibrow
- brows associated with eye groups
- unusual/extra/decorative brows

Each brow:

- 3 regions by default: inner/middle/outer
- optional 5-point profile
- whole-brow control
- raise/lower
- inner/outer independent movement
- curve
- tilt
- compress
- stretch
- independent or mirrored left/right editing

Each eye placement/profile (`left`, `center`, `right`) defines a default brow placement.

Brows are head-attached, not attached to the rotating eyeball.

## 5.10 Nose

Shape-deformation oriented.

Semantic controls:

- bridge
- tip
- left/right nostril regions
- width
- length
- projection
- rotation
- flare
- compression

## 5.11 Cheeks and midface

Primarily shape deformation, no default cheek bones required.

Per side:

- raise
- compress
- puff
- hollow
- shift

Morphology:

- cheekbone height/width/projection/definition
- upper/lower cheek fullness
- under-eye/midface fullness

Nasolabial folds:

- automatically driven by smile, cheek compression, mouth motion, age/profile
- manual intensity override available

Correctives connect cheeks with eyelids, nose, lips, and jaw.

## 5.12 Lips and external mouth

Support:

- upper/lower lip regions
- independent left/right corners
- width
- thickness
- projection
- curvature
- open/close
- purse
- stretch
- curl
- asymmetric movement

Jaw provides broad opening. Lips deform independently around it.

Support blendable speech-shape presets/visemes and corrective shapes for lips/teeth/cheek/jaw contact.

### Facial-expression presets

Support reusable blendable facial presets such as happy/sad/angry/afraid/surprised/disgusted and custom profiles.

A preset may drive:

- eyelids
- eyebrows
- cheeks
- lips
- jaw
- optional eye direction

Preset weights are continuous and blendable, e.g. happy + surprised. Manual control remains available after preset application.

Head tilt belongs to head/neck animation, but a higher-level performance preset may combine facial expression with head/gesture animation.

## 5.13 Chin and jawline

Controls:

- chin width/height/projection/roundness
- optional cleft
- jaw width/angle/taper
- lower-face length
- under-chin fullness
- left/right asymmetry
- jaw shift forward/backward/left/right
- masseter/jaw-muscle definition and clench state

Primarily morphology/shape deformation plus the existing jaw bone.

## 5.14 Ears

Ear collection:

- semantic sides limited to `left` and `right`
- default human = one per side
- variable count supported if later needed

Per ear:

- ear-root anchor attached to skull
- one ear-root deformation bone for normal human ears
- shape deformation for detailed cartilage/morphology

Controls:

- height/width
- projection
- vertical position
- forward/back rotation
- upper/lower shape
- attached/free earlobe
- cartilage definition
- advanced asymmetry

Hearing:

- ear-root anchor is the default hearing reference for visible functional ears
- hearing acuity/range is gameplay data, not derived from ear size
- characters without visible ears can use a head-level hearing reference

Accessory sockets may later support earrings, gauges, hearing devices, headphones, etc.

## 5.15 Scalp and head hair

- Scalp surface and hairline are part of the head definition.
- Hairstyle is a replaceable component.
- Current target = human-like scalp hair.
- Hybrid approach:
  - authored sections
  - broad bone/control motion
  - optional secondary simulation

Supported sections include:

- bangs/fringe
- left side
- right side
- crown/top
- back
- ponytail/tied sections
- loose strands

Movable sections may use:

```text
section_root
→ section_mid
→ section_tip
```

Short hair can use fewer/no chains.

Hair responds to:

- head movement
- gravity
- wind
- clothing/headwear
- body collision

Hairline:

- primarily authored
- preset/procedural starting templates may be offered
- front/side/temple/nape coverage can be represented

### Headwear-linked hair profiles

A hairstyle may reference alternate authored profiles:

- normal
- hat-compressed
- helmet-tucked
- helmet-exposed-back
- hood profile
- etc.

Multiple source hairstyles may share one compatible alternate profile.

Representation profiles may render the same hairstyle differently in world sprites, portraits, close-ups, future 3D, etc.

## 5.16 Facial hair

Schema/design support:

- mustache
- chin
- jaw
- cheeks
- sideburns
- neck
- composite beard profiles

Controls:

- length
- density
- thickness
- curl
- softness/coarseness
- color
- coverage
- growth state: clean-shaven, stubble, short, medium, long

Short facial hair follows facial deformation; long facial hair may use deformation chains and secondary motion.

Compatibility rules can hide/compress/substitute facial-hair variants under masks/headwear.

**DEFERRED:** detailed facial-hair implementation is not an early priority.

## 5.17 Optional head attachments

Allowed canonical attachment regions:

- forehead above brows
- top/crown
- back of head
- left/right sides/temples

Not allowed on:

- eyes/eyelids
- nose
- cheeks
- lips/mouth
- chin/jaw
- ears
- neck

Attachments anchor to the skull/head structure, not expressive facial deformation regions.

May be rigid/deformable/removable/damaged/replaced.

---

# 6. Upper body, arms, hands, and shoulder morphology

## 6.1 Shoulder/arm rig

Per side:

- clavicle
- scapula
- upper-arm main deformation bone
- **2 upper-arm twist deformation bones**
- forearm main bone
- **2 forearm twist deformation bones**
- hand/root

Clavicle supports shoulder elevation/depression/protraction/retraction.

Scapula supports shoulder-blade movement across ribcage.

Twist bones distribute rotation gradually and avoid candy-wrapper collapse.

Animator controls include:

- FK joint controls
- hand IK target
- elbow pole/direction control
- manual overrides for clavicle/scapula

## 6.2 Shared human rig across sex/body presets

Do **not** create separate male/female skeleton systems.

Use:

```text
shared humanoid rig/topology
+ morphology parameters
+ optional anatomy modules
+ materials/state
```

Male-typical/female-typical presets choose different defaults, but underlying sliders remain available to every profile.

## 6.3 Shoulder morphology

Controls:

- overall shoulder width
- clavicle length
- clavicle angle
- shoulder height
- shoulder forward/back placement
- overall deltoid volume
- front/side/rear deltoid volume
- deltoid roundness
- definition/separation
- trapezius-to-shoulder transition
- activation/flex
- advanced asymmetry

Group presets may include narrow/average/broad/athletic/rounded/muscular/powerful.

`overall_shoulder_width` may drive several underlying structural parameters, but low-level geometry still has one authoritative resolver.

## 6.4 Upper-arm morphology

Controls:

- upper-arm length
- circumference
- biceps volume
- biceps peak
- biceps length/fullness distribution
- triceps total volume
- triceps region emphasis
- brachialis volume
- inner/outer fullness
- muscle definition/separation/sharpness
- fat/soft tissue
- flex/activation
- advanced asymmetry

Grouped presets such as slim/athletic/muscular/powerful/soft.

## 6.5 Forearm and wrist morphology

Controls:

- forearm length/circumference
- elbow prominence/width
- upper/lower forearm thickness
- flexor volume
- extensor volume
- brachioradialis prominence
- taper
- wrist width/depth
- tendon definition
- muscle definition/separation/sharpness
- fat/soft tissue
- flex/activation
- advanced asymmetry
- composable presets

Human-realistic ranges are canonical. Stylized/cartoon ranges use expanded profiles rather than unlimited normal-human sliders.

## 6.6 Hand rig

Human default = thumb + four fingers.

Canonical structure:

- hand/wrist root
- thumb:
  - metacarpal
  - proximal
  - distal
- index/middle/ring/little:
  - metacarpal
  - proximal
  - middle
  - distal

So:

- thumb = 3 bones including metacarpal
- each other digit = 4 bones including metacarpal

Metacarpals allow palm cupping/spreading rather than a rigid palm plate.

### Hand controls

- whole-hand open/close
- fist
- finger curl
- finger spread
- palm cup
- thumb opposition
- pinch
- grip width
- independent per-digit/per-joint controls

Interaction anchors:

- palm center
- grip anchor
- palm heel
- thumb pad
- fingertip and finger-pad anchors
- optional knuckle/contact anchors

## 6.7 Procedural grasp control

Inputs may include:

- grasp target
- grip position
- target axis
- target collision/grip geometry
- grip closure
- grip strength
- thumb opposition
- finger-contact bias

`grip_width` should normally be derived from target geometry.

Solver behavior:

- place palm
- curl fingers until contact
- orient thumb
- respect joint limits
- prevent penetration
- preserve realistic small gaps

Generated grasp may be:

- used directly
- saved as hand-pose preset
- manually refined
- layered with independent finger corrections

## 6.8 Hand morphology and nails

Hand morphology:

- palm width/length/thickness
- cupping depth
- finger lengths/thickness/taper/spacing
- joint prominence
- thumb size/placement
- knuckle/tendon definition
- soft-tissue/muscle volume
- advanced asymmetry

Supports broad/meaty through slim/petite/delicate.

Fingernails:

- separate components
- attach only to distal fingertip region
- may extend beyond fingertip
- configurable length/width/thickness/curvature/shape

Nail material:

- base/color
- translucency
- gloss
- thickness
- tip color
- surface smoothness
- curvature
- healthy human default

Toenails follow the equivalent foot/toe logic.

---

# 7. Torso, abdomen, body fat, chest, breasts, nipples, and breathing

## 7.1 Shared torso foundation

One shared human torso system. No separate male/female torso rigs.

### Ribcage/torso controls

- ribcage width/depth/length
- independent upper/lower ribcage width
- rib flare
- sternum length/projection
- torso length
- waist height
- waist width/depth
- torso taper
- advanced left/right asymmetry

All continuous. Symmetric editing default. Asymmetry values default to zero and can remain advanced/hidden initially.

## 7.2 Torso muscle regions

Support detailed front/side/back regions including:

- left/right pectorals
- upper/middle/lower abdominal regions
- obliques
- serratus
- lats
- trapezius
- spinal erectors
- lower-back musculature

Per relevant region:

- size/volume
- definition
- separation
- surface sharpness
- activation/flex
- advanced asymmetry

Group controls may include:

- overall muscularity
- chest development
- core development
- back development
- upper-back thickness
- lat width
- abdominal definition
- oblique development
- full-body flex intensity

Muscle size, body fat, and definition remain independent.

## 7.3 Abdominal segmentation

Rectus-abdominis segmentation is an explicit discrete profile:

- 4-pack
- 6-pack (default human preset)
- 8-pack
- custom/asymmetric profile

Not a skeleton-topology change and not triggered automatically by definition.

Controls:

- individual segment height/width/volume
- upper/lower development
- left/right asymmetry
- linea alba width/depth
- horizontal intersection depth/definition
- roundness/sharpness
- overall projection
- flex/activation
- definition/separation
- overlying fat/soft-tissue coverage

Group controls such as `abdominal_development` and `ab_definition` may drive lower-level controls.

## 7.4 Body fat and torso soft tissue

Independent regional controls for:

- upper/lower chest
- upper/lower abdomen
- waist
- left/right flanks
- upper/lower back
- underarm/side chest
- under-chin/neck transition (shared with head/neck system)

Separate properties:

- fat volume
- distribution
- surface softness/firmness
- fold/crease tendency

Pose-driven folds appear when bending/twisting/sitting/compressing rather than being permanently baked.

Group controls:

- overall body-fat amount
- abdominal distribution
- waist/flank distribution
- back-fat distribution
- upper-body softness
- surface firmness
- fold tendency

## 7.5 Pectorals and breast tissue

Layering:

```text
ribcage
→ pectoral muscle
→ breast tissue
→ skin
→ nipple/areola surface
```

Every human profile has pectoral structure. Breast tissue is an independent continuous morphology layer, not a male/female Boolean.

### Pectoral controls

Per side with linked editing by default:

- width/height
- thickness/projection
- upper/middle/lower development
- inner/outer fullness
- definition/separation
- relaxed/flexed activation

### Breast morphology

Per side:

- volume
- base width/height
- vertical/horizontal placement
- projection
- upper/lower fullness
- inner/outer fullness
- spacing/separation
- slope
- firmness
- sag/ptosis
- orientation
- asymmetry

Automatic correction should prevent unrealistic overlap; if inner fullness creates impossible intersection, surrounding forms can redistribute/push outward according to the resolver.

No `real/fake` toggle. Continuous controls such as:

- firmness
- upper-pole fullness
- shape retention
- gravity resistance

produce the range of appearances.

### Manual breast pose/deformation controls

Per side/group:

- lift/drop
- move inward/outward
- up/down
- left/right
- diagonal
- forward pull
- compression
- spread
- circular/orbit/swing
- side sway
- bounce/follow-through
- contact deformation

Group controls:

- overall size
- fullness
- firmness
- spacing
- lift/sag
- projection
- motion intensity

## 7.6 Breast soft-tissue properties

Per breast:

- mass
- stiffness
- elasticity
- damping
- gravity response
- inertia
- shape retention
- maximum displacement
- compression resistance
- recovery speed

Presets may include:

- firm
- soft
- heavy
- light
- highly supported/constrained
- highly mobile

Clothing support is an **external constraint layer**, not a replacement for intrinsic tissue properties.

## 7.7 Secondary-motion recoil

Make recoil explicit:

```text
body acceleration/stop
→ tissue lag
→ overshoot
→ oscillation
→ damping/settling
```

Controls:

- recoil intensity
- oscillation speed
- damping/settling time
- directional response
- maximum displacement
- left/right coupling
- clothing suppression
- manual multiplier/override

Reusable across running, stopping, jumping, dancing, impacts, interactions, etc.

## 7.8 Gravity/environment response

Soft tissue uses actual **world/environment gravity vectors**, not character-down.

Must support:

- upright
- upside down
- sideways
- low gravity
- high gravity
- swimming/other media
- ceiling/sticky-foot scenarios

Maximum displacement/solver limits prevent unrealistic lag in stylized high-speed movement.

## 7.9 Nipple and areola

Per side:

- nipple position
- areola position
- nipple size
- areola size
- shape
- projection
- orientation
- asymmetry
- nipple base diameter
- nipple tip diameter
- length/protrusion
- areola puffiness/raisedness
- inverted/flat/protruding state
- surface texture/bump detail

Color/material profile:

- nipple base color
- areola base color
- radial/edge gradient
- center-to-edge variation
- optional mottling/natural variation
- gloss/wetness response
- softness/surface quality

Temporary states:

- contraction
- softness
- firmness
- compression
- cold response
- warm/relaxed response
- arousal response

Clothing visibility is resolved by garment pressure/support/opacity/structure, not hardcoded.

## 7.10 Arousal response for breast/nipple tissue

Use normalized `arousal = 0.0–1.0`.

Each character/profile defines response curves for:

- breast-volume delta
- firmness/shape retention
- nipple projection/firmness
- areola contraction/puffiness
- temperature/warmth response
- color
- surface gloss/moisture

Do not hardcode a universal percent increase.

A separate representation-exaggeration multiplier can make changes more visually readable without changing the underlying physiological profile.

## 7.11 Breathing

Breathing is an animation/deformation layer.

Controls:

- rate
- depth
- ribcage expansion
- abdominal expansion
- sternum/upper-chest lift
- shoulder/back contribution
- breast response
- chest-vs-abdomen ratio
- inhale/exhale timing

Profiles:

- breath hold
- gasp
- pant
- cough
- strained breathing
- exertion/emotional inputs
- stylized exaggeration

World-view breathing may be exaggerated for readability.

## 7.12 Navel

Semantic surface feature anchored to abdomen.

Controls:

- vertical/horizontal position
- size
- depth/projection
- innie ↔ flat ↔ outie
- round/oval/vertical/horizontal/custom shape
- rim/fold definition
- surrounding tissue depth
- color/material variation
- advanced asymmetry

Correctives for breathing, flexing, bending, stretching, morphology/pregnancy.

No dedicated deformation bone required.

---

# 8. Pelvis, glutes, perineum, genital modules, and physiological state

## 8.1 Pelvic structural frame

Pelvic frame controls:

- pelvis width/depth/height
- iliac-crest width/flare
- sacrum angle
- pubic-arch shape
- hip-socket spacing/height/orientation
- lower-abdomen-to-pelvis length
- pelvic-floor/perineal length
- forward/back pelvic tilt
- advanced asymmetry

Structural anchors include:

- left/right hip sockets
- sacrum reference
- anterior/perineal/posterior references

The pelvis itself is structurally rigid; surrounding tissue deforms.

## 8.2 Pelvis animator controls

Support:

- forward/back tilt
- side roll
- left/right rotation
- translation
- forward/back thrust
- hip hike/drop
- side-to-side sway
- circular motion
- figure-eight motion
- isolated pelvis motion with constrained feet/torso

Twerking combines pelvis, lower spine, hips/knees, and gluteal secondary motion.

## 8.3 Gluteal morphology

Left/right independent with linked symmetric editing by default.

Per side:

- width
- height
- rear projection
- upper/lower fullness
- inner/outer fullness
- hip-side fullness
- central cleft depth/shape
- gluteal-fold height/depth/curvature
- glute muscle volume/definition
- fat volume/coverage
- firmness/softness
- shape retention

Glute morphology is independent from leg morphology, though presets may intentionally combine them.

## 8.4 Gluteal movement

Per side:

- mass
- stiffness
- elasticity
- gravity response
- inertia/recoil
- oscillation speed
- damping/settling
- maximum displacement
- compression resistance
- recovery speed
- left/right coupling

Deformation approach:

```text
pelvis/thigh motion
+ shape deformation
+ pose correctives
+ soft-tissue solve
+ manual controls
```

Optional left/right soft-tissue driver controls are preferred over treating the glutes as rigid bone-driven blocks.

Group controls:

- overall size
- projection
- width
- fullness
- firmness
- softness
- motion intensity
- recoil intensity

Presets:

- muscular
- firm
- soft
- heavy
- light
- highly mobile
- highly constrained/compressed

Gluteal tissue can use the same generalized temperature/arousal tissue-response framework as other soft tissue. Human-realistic defaults should be subtle or zero where appropriate; stylized profiles may exaggerate fullness, firmness, color, or motion.

## 8.5 Shared perineal surface

One continuous shared soft-tissue surface connecting:

- lower abdomen/pubic region
- left/right groin creases
- inner thighs
- pelvic floor/perineum
- gluteal cleft

It exists regardless of which optional external anatomy modules are enabled.

Morphology:

- pubic-region width/fullness
- perineal length/width
- tissue depth/softness
- groin-crease depth
- inner-thigh spacing
- lower-abdominal transition
- gluteal-cleft transition
- firmness/compression response
- advanced asymmetry

Correctives support sitting, squatting, spreading, deep flexion, compression/contact.

## 8.6 Perineal structural anchors

At minimum:

- anterior genital anchor
- perineal center anchor
- posterior anal anchor
- left/right groin anchors
- pubic center anchor

Anchors have position + orientation; resolve from pelvis morphology and pose.

External anatomy remains modular.

## 8.7 Anatomy-module limits

Schema:

- maximum **1 anus module**
- maximum **1 vulva/vaginal-canal module**
- **0..N penis modules** supported by schema
- initial human implementation supports **0 or 1 unbranched penis**
- multiple/branching penis configurations are schema-supported but not initial implementation

Placement uses semantic anatomy zones/anchors rather than screen coordinates.

## 8.8 Anus module

Optional, max one, attached to posterior anal anchor.

Structure:

- external opening
- surrounding perianal tissue
- short internal canal

Morphology:

- resting width/height
- shape
- projection/inset
- surrounding fullness
- fold depth/definition
- orientation
- softness/firmness
- advanced asymmetry

Temporary deformation:

- open/close
- radial dilation
- contraction/tone
- stretch
- compression
- directional displacement
- recovery
- residual deformation
- maximum safe deformation

Primarily shape deformation + correctives + animator-facing ring control.

Interaction contract:

- entry frame
- approach cone
- centerline
- depth/capacity
- deformation envelope
- occupancy
- contact/occlusion volume
- pressure/recovery response

Surface state supports color gradient, softness, gloss, wetness/residue, irritation, bruising/injury.

## 8.9 Vulva/vaginal-canal module

Optional, max one, attached to anterior genital region.

External semantic structures include:

- mons
- left/right labia majora
- left/right labia minora
- clitoral region
- urethral opening landmark
- vaginal opening
- vestibule
- vaginal canal

External morphology:

- overall width/height/projection
- placement/orientation
- mons fullness
- independent labial size/thickness/shape/visibility/curvature
- opening visibility
- softness/firmness/fullness
- linked symmetry default with independent asymmetry

Clitoral region:

- glans size/projection
- hood size/coverage/position
- exposed/covered amount
- orientation
- firmness/state
- material/color

Vaginal opening:

- resting width/height
- shape/orientation
- open/close
- radial/directional stretch
- tissue tone
- compression
- edge thickness/surrounding fullness
- recovery/residual deformation

Internal canal:

- deformable centerline/spline
- canal entry/mid/deep semantic regions
- resting length
- width/capacity along canal
- curvature
- directional compliance
- wall softness/elasticity
- pressure response
- expansion limits
- recovery
- configurable deep endpoint

Deformation:

```text
shape deformation
+ canal spline controls
+ correctives
+ contact solve
+ manual corrections
```

Arousal/temperature/physiological response may affect fullness, relaxation, clitoral response, lubrication, color, etc. via configurable response curves.

Lubrication is handled by the general fluid/surface system, not permanently baked into geometry.

## 8.10 Penis module

Optional anatomy module attached to anterior genital anchor.

Initial implementation = one unbranched penis.

Canonical source rig:

- stable root/base
- **7 shaft deformation bones**
- glans/tip structure
- shape deformation for detailed skin/glans/state
- optional foreskin
- optional extra segments for unusually long/flexible future profiles

Seven bones are spline/IK-driven, not normally edited one by one.

Animator controls:

- root angle/orientation
- whole curve
- tip position
- bend direction
- twist
- stiffness
- secondary-motion intensity
- regional correction
- tip/IK-like control
- directional/orbit control

### Orbit control

Supports:

- up/down/left/right/diagonal
- circular/orbital motion
- orbit radius
- configurable orientation-follow amount

Small orbit can retain mostly forward orientation; large orbit can increasingly orient along the circle.

### Penis morphology

- soft length
- erect length
- girth at multiple shaft regions
- taper
- cross-sectional shape
- base width
- curvature amount/direction
- resting orientation
- glans dimensions/shape
- ridge/corona definition
- urethral opening placement/size
- foreskin length/coverage/thickness/retraction
- surface texture
- vascular definition
- advanced asymmetry

Not modeled as one uniform cylinder.

### Erection state

One normalized continuous input:

```text
erection_state = 0.0 → 1.0
```

Each anatomy profile defines nonlinear response curves for:

- length
- girth
- curvature
- base angle
- rigidity
- bend limits
- gravity
- damping/recoil
- color/vascularity

Convenient named presets may include soft/partial/erect/highly rigid.

### Temperature/arousal

Arousal and temperature are separate drivers.

Cold may affect contraction/resting size/orientation; warmth may affect relaxation/hang/softness/color. Response strength is configurable per character/profile.

### Physical/secondary properties

- mass
- stiffness
- elasticity
- inertia
- gravity response
- damping
- recoil/settling
- max bend/displacement
- compression resistance
- recovery

Properties can vary continuously with erection state.

### Surface and emitter support

The penis module exposes:

- semantic shaft/glans material regions
- stable surface coordinates
- color/vascular response
- wetness/residue support
- temporary redness/pressure marks/bruising/injury through the shared surface-state system
- urethral emitter anchor
- optional additional effect emitters for custom profiles

Fluids remain separate fluid/emitter-system state rather than permanent mesh state.

### Branching/multiple schema

Future schema supports:

- several separate root modules
- one shared root with branches
- branches with independent morphology/state/interaction occupancy

**DEFERRED:** exotic multi-penis/branching physical implementation.

## 8.11 Scrotum and testicles

One optional scrotal module containing independent left/right testicles.

Morphology:

- overall size/hang
- width/depth/skin thickness
- independent testicle size/shape
- spacing
- vertical offset
- forward/back position
- tightness/looseness
- wrinkling/texture
- asymmetry

Natural left/right asymmetry is allowed.

Temperature response:

- contraction/relaxation
- testicle elevation
- hang length
- skin wrinkling

Arousal remains an independent driver.

Motion:

- mass
- inertia
- swing
- damping
- recoil
- gravity
- max displacement
- collision/contact
- recovery

Deformation:

- scrotal root control
- one control/deformation structure per testicle
- surrounding scrotal shape deformation
- correctives for thigh/contact/sitting/clothing

Manual controls:

- lift/drop
- spread/compress
- independent left/right position
- forward/back
- swing direction
- motion multiplier
- compression
- temperature/arousal override

Surface/state support:

- color gradients
- vascular detail
- wrinkles
- wetness/residue
- redness
- bruising
- pressure marks
- injury
- temperature/physiological color response

Clothing may provide support, compression, upward positioning, movement restriction, and contact constraints.

## 8.12 Unified genital physiological/deformation state

Separate permanent morphology from temporary state:

```text
permanent morphology
+ physiological state
+ environment/temperature
+ contact deformation
+ injury/surface state
→ resolved anatomy
```

Shared inputs may include:

- arousal
- temperature
- blood flow/engorgement
- tissue tone
- fatigue
- irritation/injury
- recovery

Each module defines its own output response curves.

Recovery controls:

- response speed
- max change
- hold time
- recovery speed
- damping/hysteresis

For authoring/tests, recovery may be made **instant, accelerated, or skipped**.

---

# 9. Legs, feet, and lower-body morphology

## 9.1 Leg rig

Per side:

- hip connection
- thigh/femur main deformation bone
- **2 thigh twist deformation bones**
- primary knee joint
- lower-leg main bone
- **2 lower-leg twist deformation bones**
- ankle
- foot

Hip supports:

- flexion/extension
- abduction/adduction
- internal/external rotation
- circular movement
- extreme ranges for squat/kick/spread/climb/etc.

Knee has pole/direction control for IK.

Corrective shapes are important for groin/glute/thigh/knee transitions.

## 9.2 Thigh morphology

Controls:

- length
- circumference
- front/back/inner/outer thickness
- quadriceps total size
- detailed quad definition
- hamstring size/definition
- adductor/inner-thigh volume
- outer-thigh musculature
- upper-thigh/glute transition
- knee taper
- fat/soft tissue
- definition/separation/sharpness
- flex activation
- advanced asymmetry

Thigh gap should mostly be **derived**, not an isolated geometric hack, from:

- pelvis width
- hip-socket spacing
- femur angle
- inner-thigh/adductor volume
- body-fat distribution
- thigh width

A convenience thigh-gap control may drive underlying valid parameters.

Composable presets supported.

## 9.3 Lower leg/calf

Morphology:

- lower-leg length
- upper/lower calf circumference
- calf width/rear projection
- calf insertion height
- medial/lateral fullness
- tibialis/shin prominence
- taper
- ankle width/thickness
- Achilles definition
- fat/softness
- definition/separation/sharpness
- activation/flex
- asymmetry

### Calf activation

Normalized activation/flex control.

Tiptoe/push-off should automatically coordinate:

- plantarflexion
- heel elevation
- toe contact
- calf shortening/bulging
- Achilles tension
- knee/hip balance correction

## 9.4 Ankle, foot, and toes

Ankle supports:

- plantarflexion/dorsiflexion
- inversion/eversion
- small rotational freedom
- Achilles/malleoli/top-of-foot correctives

Foot structure includes semantic/rig support for:

- heel
- midfoot
- forefoot
- toe chains

Human toes:

- big toe = **2 deformation bones**
- each other toe = **3 deformation bones**
- plus metatarsal/forefoot deformation

Controls:

- foot IK
- heel
- ball-of-foot
- toe-group curl
- independent big toe
- toe spread
- foot roll
- arch
- tiptoe
- individual toe overrides

Ground-contact regions:

- heel
- outer edge
- inner edge
- ball
- big-toe pad
- other toe pads

Terrain-aware grounding supports slopes, stairs, crouch, tiptoe, one-foot balance, partial contact.

Foot morphology:

- length
- width
- arch height
- instep height
- heel width
- forefoot width
- toe lengths/spacing/taper
- ankle transition
- tendon/vein definition
- fat-pad thickness
- asymmetry
- composable presets

Toenails mirror fingernail principles as closely as appropriate.

---

# 10. Skin, surface features, vascularity, body hair, and eyelashes

## 10.1 Skin material system

Character-level properties:

- base skin color
- continuous undertone
- pigmentation/melanin level
- saturation
- brightness/value
- roughness
- oiliness
- softness
- translucency/subsurface response
- pore/detail intensity

## 10.2 Regional skin variation

Allow regional modifiers for:

- face
- lips
- ears
- neck
- chest
- nipples/areolas
- abdomen
- genitals/perineum
- glutes
- elbows
- knees
- hands
- feet
- other semantic regions as needed

Per-region modifiers may affect:

- hue
- saturation
- brightness
- roughness
- redness/vascular appearance
- pigmentation strength

Do not require elaborate procedural/random pigmentation in the first implementation.

## 10.3 Persistent surface features

Use a separate surface-feature layer for:

- freckles
- moles
- tattoos
- scars
- wrinkles/creases
- optional calluses later
- other authored marks

A feature stores semantic surface/region, canonical surface location, size, rotation, shape, material/color, and optional displacement/geometry if silhouette matters.

**EXCLUDED:** stretch marks are not part of the current canonical-human implementation scope.

**DEFERRED:** makeup/cosmetics and specific piercing-location authoring.

## 10.4 Dynamic surface/physiological state

Separate global drivers and regional overrides.

Global/large-area drivers may include:

- arousal
- warmth/cold
- blood flow/congestion
- pallor
- oxygen-loss/choking response
- illness/weakness
- stress/fear
- optional exertion

Regional overrides may include:

- facial flush
- neck pressure marks
- breast compression redness
- nipple color response
- bruising
- irritation
- pressure blanching
- local blood pooling
- injury discoloration

This is a layered physiological/surface-state color system, not independent ad hoc logic per body part.

## 10.5 Vascularity

Vascularity is a **stable authored network**, not random veins regenerated each time.

A vascular segment may carry:

- region
- parent/branch relationship
- canonical surface path
- thickness
- depth beneath skin
- color
- baseline visibility
- raisedness
- physiological-response weights

Controls:

- global vascularity
- regional vascularity
- density
- thickness
- depth
- visibility/contrast
- raisedness
- branch detail
- color/material
- asymmetry

High-detail profiles should be available especially for:

- penis
- forehead/temples
- neck
- arms/hands
- calves/feet
- other close-up regions

Visibility resolves from:

```text
authored network
+ regional vascularity
+ skin properties
+ fat coverage
+ muscular definition
+ physiological state
```

Close-up 3D may use slight surface displacement for prominent vessels; medium detail may use material/normal effects; tiny 2D sprites may simplify/omit them.

Presets may include low/average/lean-athletic/highly-vascular/extreme.

## 10.6 Body hair

Schema/design support is locked, but implementation is low priority.

Regions may include:

- chest
- abdomen
- shoulders
- back
- arms
- hands/fingers
- pubic/groin
- glutes
- thighs
- lower legs
- feet/toes

Controls:

- density
- coverage area
- length
- thickness
- curl/wave
- direction/growth flow
- softness/coarseness
- color
- variation
- taper/fade

Body-hair color may default from scalp/facial-hair color while remaining independently editable.

Use authored density maps + directional guide fields.

Grooming states may include natural/trimmed/shaved/partially shaped.

Longer body hair may respond to gravity/wind/wetness/compression.

**DEFERRED:** body-hair implementation is not required early.

## 10.7 Eyelashes

Attached to eyelids, not eyeball.

Upper/lower independently configurable:

- length
- density
- thickness
- curl
- direction
- color
- inner/center/outer distribution
- asymmetry

Human-realistic defaults with exaggerated ranges permitted.

Follow eyelid deformation automatically.

May be simplified/omitted in small 2D representations.

---

# 11. Global body proportions and morphology/preset model

## 11.1 Global proportions

Structural controls:

- target height
- leg-to-torso ratio
- torso length
- overall leg length
- arm span
- upper-arm:forearm ratio
- thigh:lower-leg ratio
- shoulder breadth
- pelvis/hip breadth
- head-to-body ratio
- neck length
- hand size
- foot size
- overall body depth/thickness
- optional advanced left/right limb-length asymmetry

Convenience controls:

- long-limbed ↔ short-limbed
- long-torso ↔ short-torso
- narrow-frame ↔ broad-frame
- small-head ↔ large-head

Changing height does not force uniform scaling of every region.

## 11.2 Human-realistic vs stylized ranges

- Canonical human profile uses anatomically plausible ranges.
- Stylized/cartoon profiles may expose expanded hard ranges.
- Expanded ranges must use the same explicit validation/corrective framework rather than corrupting normal-human assumptions.

## 11.3 Parameter categories

Morphology parameter categories:

- `structural`
- `morphological`
- `appearance`
- `group`

Temporary properties such as arousal, breathing, flex activation, injury, etc. are state parameters, not permanent morphology.

## 11.4 Parameter value types

Support:

- `f32`
- integer
- enum
- bool only when genuinely binary

Prefer continuous values when the property is actually continuous.

Physical values may use meters; others may use normalized `0.0–1.0`.

## 11.5 Parameter ranges

Each parameter may define:

- default value
- recommended/profile range
- hard supported range

## 11.6 Response curves

Support at least:

- linear
- smooth
- custom authored curve

## 11.7 Symmetry

Parameter modes may include:

- centered
- mirrored
- independent pair

Editor links left/right by default in almost all normal cases. Users may explicitly unlink sides.

## 11.8 Morphology cannot silently change topology

A continuous parameter may reshape an existing component but cannot silently add/remove components or alter connectivity.

Examples:

```text
eye_size → changes existing eye
third_eye → explicit component-graph change

arm_length → changes existing arm
third_arm → explicit component-graph change
```

Discrete profiles such as 4/6/8-pack are explicitly selected rather than appearing when an unrelated slider crosses a threshold.

## 11.9 Parameter bindings

Each parameter explicitly declares what it affects.

### M01 locked target-property grammar

Every binding addresses its target property through the extensible typed identity:

```text
BindingTarget
├── target_type
├── target_id
└── property_id
```

- `target_type` is the canonical target category/type.
- `target_id` is the stable ID of the target object.
- `property_id` is a stable lowercase `snake_case` semantic property identifier, not an unchecked arbitrary string.
- Each `target_type` defines or validates its legal `property_id` set.
- Unknown or unsupported target/property combinations fail validation.
- Writer-conflict detection keys on the complete structured target-property identity.

Example:

```text
target_type = anchor_transform
target_id = hip_socket_left
property_id = position_x
```

Binding targets may include:

- rest bone transforms
- anchors/sockets
- mesh morph targets
- corrective-shape inputs
- material parameters
- collision geometry
- interaction sites
- garment-fitting envelopes/surfaces
- semantic landmarks
- soft-tissue properties

If one parameter affects eight outputs, conceptually it has eight explicit bindings or a reusable generated binding rule that is equally explicit.

No hidden “remember to also move X” behavior.

### Binding operations

Standard operations:

- `set`
- `offset`
- `scale`
- `weight`
- `remap`
- `derive`

## 11.10 Dependency rules

- One authoritative writer/resolver per low-level property.
- Group sliders drive other parameters, not final geometry directly.
- Derived values explicitly list all inputs.
- Dependencies form a directed acyclic graph.
- Fixed evaluation order.
- Conflicting bindings fail validation.
- Editor provides “what drives this?” traceability.

### Morphology resolution order

```text
structural parameters
→ rest skeleton + anchors
→ mesh morphology
→ soft tissue
→ collisions/interaction sites
→ garment-fitting data
→ corrective validation
```

## 11.11 Editor exposure model

The canonical parameter specification is more detailed than the default editor needs to be.

Rules:

- Do not require one canonical rule = one visible slider.
- Some fine-grained properties expose one direct slider.
- Some concepts require several independent sliders.
- High-level group sliders may drive several lower-level canonical parameters.
- Editor may provide **Basic** and **Advanced** modes.
- Basic exposes useful group controls/presets.
- Advanced can expose nearly every underlying canonical parameter.
- Group controls never bypass the authoritative parameter-binding/resolution rules.

## 11.12 Composable preset system

Preset types remain separate:

- morphology
- material
- component
- garment (later)
- animation (later)
- physiological-state

Each preset has:

- stable `preset_id`
- display name
- type
- explicit scope
- partial parameter ownership

Presets may be:

- regional
- body-part
- upper/lower body
- limbs/extremities
- full-body
- composites of smaller presets

### Composition modes

When presets overlap:

- override
- blend
- additive

Priority is explicit.

Manual slider changes normally resolve last.

Presets never permanently lock underlying controls.

### Nested presets

Larger presets may reference smaller presets. Cycles are invalid.

### Provenance

Editor should show where a resolved value came from, e.g.:

```text
thigh_volume
= 70% athletic_lower_body
+ 30% powerful_legs
+ manual adjustment
```

Preset compatibility checks rig/body family and required components.

Human presets must not silently apply to incompatible animal rigs.

---

# 12. Materials, semantic surfaces, canonical coordinates, UVs, and seams

## 12.1 Semantic surfaces

Every meaningful mesh area receives stable semantic IDs.

Examples:

- skin face/chest/abdomen
- breast left/right
- nipple/areola
- lips
- eye sclera/iris
- nails
- limb surfaces

Use both:

- fine `surface_id`
- coarser `region_id`

## 12.2 Canonical surface coordinates vs texture UVs

These are distinct.

- **Canonical surface coordinates** identify where something is on the body and should remain stable across compatible morphology.
- **Texture UVs** map geometry into source texture/material images and may be repacked/reorganized.

Stable canonical surface coordinates support:

- tattoos/scars/moles
- vascularity
- clothing fitting
- wetness/residue
- persistent marks
- atlas generation
- 3D→2D traceability

## 12.3 Material roles

Use semantic roles rather than only final RGB:

- `skin.base`
- `skin.highlight`
- `skin.shadow`
- `lip.base`
- `nipple.base`
- `areola.base`
- `eye.sclera`
- `eye.iris`
- `hair.base`
- `nail.base`
- etc.

## 12.4 Material properties

Material definitions may support:

- base color
- roughness
- gloss/specular
- opacity
- translucency
- subsurface response
- normal/detail strength
- emission
- wetness response
- temperature/color response
- optional displacement/detail

### M01 locked base-material color contract

Canonical base material colors use:

- color space `linear_srgb`;
- channel order `[r, g, b, a]`;
- numeric type `f32`;
- channel range `0.0–1.0`;
- straight/unassociated alpha.

Editor and UI input may use ordinary sRGB controls, hex values, RGB `0–255`, or other human-facing representations. Those values are converted to canonical linear-sRGB RGBA before canonical serialization; UI/display encoding is not the canonical material-color representation. Base material color remains within `0.0–1.0`. Future HDR/emissive quantities may use separate contracts and are not constrained by this base-color decision.

## 12.5 Material definitions vs instances

- **Material definition:** reusable material behavior/capabilities, e.g. `human_skin`.
- **Material instance:** character-specific parameter values using that definition.

Surfaces reference material instances.

Temporary wetness/flush/bruising/etc. layer on top and do not permanently modify the instance.

Material IDs/assignments are deterministic/versioned.

## 12.6 Layered surface resolution

```text
canonical material
→ persistent features
→ physiological state
→ contamination/wetness
→ environment/lighting
→ final material
```

## 12.7 Shared seams/boundaries

Even on a continuous canonical body mesh, define semantic seam/boundary identities for transitions such as:

- torso ↔ pelvis
- torso ↔ neck
- shoulder ↔ arm
- pelvis ↔ thigh
- wrist ↔ hand
- ankle ↔ foot

These shared boundaries later drive modular sprite registration.

Morphology uses the same resolver/shared seam data on both sides so pieces cannot drift apart.

## 12.8 Neutral UV strategy

For `human_base`:

- one stable canonical UV layout for the human morphology family
- no forced left/right UV mirroring where it prevents asymmetry/tattoos/etc.
- seams placed unobtrusively where practical
- reasonably consistent texel density
- extra UV detail where needed: face, hands, genitals, etc.
- stable UV topology across normal morphology
- optional anatomy modules may have their own compatible UV layouts
- multiple source texture tiles/pages are allowed

Validation:

- missing/invalid UVs
- unintended overlaps
- stretching
- surface-ID ↔ UV consistency
- left/right identity
- seam continuity
- morphology-extreme usability

---

# 13. Component graph, attachments, optional modules, visibility, and coverage

## 13.1 Component graph

One logical root component:

```text
body
├── head
├── torso
├── arm_left_01
├── arm_right_01
└── pelvis
    ├── leg_left_01
    ├── leg_right_01
    └── optional modules...
```

Ownership hierarchy is a **single-parent tree**.

Other relationships may form a broader graph through references without adding multiple ownership parents.

Every component supports:

- immutable `component_id`
- `component_type`
- `parent_component_id`
- attachment anchor/socket reference
- semantic tags
- required/optional status
- enabled/disabled state
- multiplicity
- compatibility/profile requirements
- references to rig/morphology/materials/surfaces/visibility/collision/etc.

Adding/removing a true component is an explicit topology/module change.

## 13.2 Anchors

Anchor = named semantic coordinate frame.

Stores:

- stable `anchor_id`
- owner component
- driver/reference
- local position
- local quaternion rotation

Anchor may be repositioned by morphology/pose resolution without changing ID.

## 13.3 Sockets

Socket = anchor with attachment acceptance rules.

May define:

- accepted component types/tags
- capacity
- required/optional attachment
- compatibility/profile rules

## 13.4 Child mount anchors and attachment records

Child components may define their own mount anchor.

Attachment aligns:

```text
parent socket
↔ child mount anchor
```

This avoids assuming the child origin is always the mount point.

## 13.5 Interaction sites

Semantic regions such as:

- hip right
- shoulder left
- upper back
- waist
- palm
- glute
- etc.

An interaction site may define:

- preferred contact anchor
- valid contact surface
- approach directions
- orientation rules
- pressure/deformation properties

Solver may choose an exact valid point rather than hardcoding arbitrary world coordinates.

## 13.6 Module existence vs visibility vs coverage vs representation

These are separate dimensions.

A component can:

- exist/be enabled
- be visible/partially visible/occluded
- be covered `0.0–1.0`
- use a representation variant/substitution

Visibility states may include:

- visible
- partially visible
- fully occluded
- hidden by policy
- hidden for representation
- replaced by variant

Geometry-driven occlusion should come from depth where possible; policy/substitution is explicit metadata.

No silent fallback.

---

# 14. Thermal/exposure contract and garment-facing body requirements

## 14.1 Thermal state

Use:

```text
core/global temperature state
+ regional surface/exposure state
```

Semantic body regions can have thermal-response profiles.

Do not initially compute detailed surface-area-based heat loss.

**EXCLUDED for now:** surface-area thermodynamics based on exact limb length/area.

## 14.2 Local exposure

Regional thermal state may depend on:

- ambient temperature
- core temperature
- local garment coverage
- garment insulation
- wetness/wind/environment
- local anatomy response curve

Local exposure can drive temporary anatomy state.

## 14.3 Coverage

Coverage is normalized `0.0–1.0`, not Boolean.

May be produced by:

- clothing
- armor
- hair
- accessories
- body overlap
- props

Coverage can feed:

- visibility
- thermal exposure
- wetness
- contact accessibility
- protection

## 14.4 Clothing/garment body-side requirements

The resolved body must expose:

- stable landmarks
- semantic body/surface regions
- canonical surface coordinates
- garment-fitting surface/envelope
- body clearance/compression information
- collision surface/proxies
- soft-tissue properties
- morphology signature
- coverage region IDs
- attachment anchors where appropriate

These are required now even though the full garment schema is downstream.

---

# 15. Downstream garment requirements preserved now

The full garment schema is **DEFERRED**, but these requirements are locked so the body pipeline does not block them later.

## 15.1 Garments are compositional

Future garment resolution concept:

```text
garment archetype
+ coverage/dimensions
+ fit profile
+ fragments/construction
+ material
+ pattern
+ garment state
→ fitted garment on resolved body
```

## 15.2 Coverage/dimension presets

Garments can reference semantic body landmarks rather than only absolute centimeters.

Examples:

- just below chest/breast
- above navel
- navel length
- waist length
- hip length
- tunic/long
- custom continuous length

## 15.3 Fit profiles

Support concepts like:

- skin-tight
- fitted
- slim
- regular/classic
- relaxed
- oversized
- structured
- rigid

Mixed fits per fragment are allowed, e.g. fitted torso + loose sleeves.

## 15.4 Garment fragments

Garments are not necessarily one binary object.

Examples:

Bra:

- left cup
- right cup
- center
- underband
- left strap
- right strap

Shirt:

- front panel
- back panel
- left/right sleeve
- collar
- left/right shoulder areas
- closures

Fragments may have independent states.

## 15.5 Granular garment state

Support as appropriate:

- open/closed
- zip fraction `0.0–1.0`
- button states
- lifted
- rolled
- displaced up/down/inward/outward/sideways
- shoulder slipped
- sleeve pushed up
- cup displaced
- waistband lowered
- detached
- torn

Where practical, displacement is continuous amount + direction, with named presets layered on top.

## 15.6 Multiple simultaneous wearables

Do not enforce one item per broad body region.

Examples may include:

- collar + multiple necklaces
- watch + bracelets
- multiple rings
- garment layers

Conflicts are resolved from authored layer/occupancy/collision/compatibility rules.

Three rigid chest plates should fail compatibility because their occupied volumes conflict, not because an arbitrary `chest_item_count = 1` rule exists.

## 15.7 Procedural/data-driven garment appearance

Future garment authoring should support reusable pattern generators such as:

- horizontal/vertical stripes
- checks/plaid
- dots
- gradients
- repeating motifs
- trim/borders
- panel/color blocking

Pattern data maps through stable garment UV/surface coordinates.

Transparency/mesh-like materials may expose:

- opacity
- translucency
- weave density
- open-space ratio
- pattern scale

At high detail, openings may require geometry; at small representation they may be material/mask detail.

## 15.8 Thermal properties

Garment/material fragments may later expose insulation/warmth properties.

User-facing UI may simplify this to a single warmth/insulation rating while keeping internal data extensible.

---

# 16. Deformation system and debugging

## 16.1 Five explicit deformation mechanisms

Every visible shape change must be traceable to one of:

1. skeletal skinning
2. morph target
3. corrective shape
4. procedural/soft-tissue deformation
5. contact deformation
6. explicit topology/module change

Topology change is listed separately because it is not a continuous deformation.

## 16.2 Skinning

Canonical authoring supports **up to 8 bone influences per vertex**.

- Weights normalize to `1.0`.
- Initial weights may be generated automatically, then manually refined.
- Left/right weighting may mirror by default.
- Weights remain stable across ordinary morphology.
- Twist bones receive gradual weights.
- Joint regions intentionally blend multiple influences.

Support:

- **dual-quaternion skinning** for high-quality/offline canonical deformation
- linear blend skinning where useful
- optional per-region blend/selection if needed

Runtime/export profiles may reduce influence count later if necessary.

## 16.3 Morph targets

Morph targets store vertex deltas while preserving topology/vertex IDs.

Rules:

- stable topology
- same vertex correspondence
- neutral-centered endpoints where appropriate
- two-direction parameters may use narrow/wide or low/high endpoints
- one-direction parameters may use neutral→high
- structural parameters may combine rest-skeleton changes + morph targets
- pure shape parameters usually use morphs
- independent left/right underlying targets
- presets combine parameters, not separate meshes

Human-realistic endpoints come first. Stylized extremes later.

## 16.4 Corrective shapes

Correctives fix combinations where ordinary skinning/morphs fail.

Drivers may include:

- joint angle
- morphology parameter
- another morph
- soft-tissue state
- contact pressure

Corrective record may include:

- stable ID
- affected mesh/region
- drivers
- activation range
- response curve
- vertex deltas
- max influence
- mirror relationship

Types include pose, morphology-combination, and contact correctives.

Initial corrective set focuses on:

- shoulder/armpit
- elbow
- forearm/wrist twist
- hip/groin/glute
- knee
- ankle/Achilles
- spine/abdomen
- neck
- jaw/mouth
- breast/chest

Add correctives when real validation exposes actual problems rather than preauthoring hundreds blindly.

## 16.5 Soft-tissue deformation profiles

Applicable to breasts, glutes, abdomen, genital tissue, etc.

Properties may include:

- mass
- stiffness
- elasticity
- damping
- inertia
- gravity response
- compression resistance
- max displacement
- recovery
- volume preservation

Solver baseline may be manually corrected and baked.

## 16.6 Contact deformation

Inputs:

- contact shape/area
- direction
- depth
- speed/impulse
- source stiffness
- effective mass/body momentum
- sustained force
- repeated rhythm
- affected tissue properties

Target profile may include:

- compression
- displacement spread
- volume preservation
- inward/outward limits
- stiffness
- recovery
- damage thresholds
- stylized-exaggeration limits

Impacts, body contact, furniture contact, garment pressure, and authorized penetration use the same general contact-deformation foundation.

### Authorized penetration/contact-volume response

For authorized insertion/penetration-style interactions, the solver may additionally use:

- penetrating shape/cross-section
- insertion direction/depth
- receiving-region deformation field
- internal clearance/capacity
- tissue properties
- effective body mass/momentum behind the effector
- repeated rhythm/force

It can resolve:

- entry-site stretching
- surrounding compression
- internal displacement
- external surface/abdominal bulging when geometry warrants it
- pressure/contact visibility

External bulging is **not automatic**; it depends on geometry, body size, tissue thickness, position, and the selected realism/exaggeration profile.

Visual deformation and gameplay damage/injury are related but remain separate outputs.

### Multiple simultaneous contacts

Calculate each contact independently first, then resolve them in one coupled body solve.

The coupled solver enforces:

- tissue/joint limits
- volume preservation
- overlapping deformation fields
- collision constraints
- max displacement
- representation exaggeration

Opposing forces may cancel net body movement without canceling local deformation/damage.

## 16.7 Deformation evaluation order

```text
base topology
→ structural/rest-skeleton resolution
→ permanent morphology morphs
→ morphology correctives
→ skeletal pose/skinning
→ pose correctives
→ soft-tissue deformation
→ contact deformation
→ final corrective/constraint pass
→ surface/material state
```

## 16.8 Geometry regeneration/topology rule

Do not regenerate/switch topology for ordinary continuous changes such as:

- wider pelvis
- longer arms
- larger breasts
- bigger muscles
- ordinary face changes

Topology/module change is explicit when:

- component is added/removed
- requested morphology leaves supported family
- geometry is demonstrably too coarse for required quality
- fundamentally different construction is required

No silent topology change during a slider movement.

## 16.9 Deformation debug tooling

Editor requirements:

- isolate/display each deformation stage
- bone + skin-weight heatmaps
- selected vertex bone influence inspection
- morph target 0→1 preview with ghosted base
- corrective trigger + current activation
- soft-tissue vectors/displacement/gravity/damping
- contact pressure/influence/deformation visualization
- topology-change before/after comparison

Provide:

```text
base
→ morphology
→ skinning
→ corrective
→ soft tissue
→ contact
→ final
```

stage stepping.

### “Why is this vertex here?” inspector

For a selected vertex/point, show:

- skin weights
- active morphs
- active correctives
- soft-tissue displacement
- contact displacement
- any other deterministic contributors

---

# 17. Animation system contract

## 17.1 High-level reuse principle

Reuse:

- intent
- roles
- contacts
- timing/phase
- semantic targets

whenever possible.

### Same rig family

Use:

```text
base clip
→ retarget to resolved skeleton
→ IK/contact correction
→ collision correction
→ morphology correctives
```

Different-size humans should not require separate animations by default.

### Different rig families

Reuse choreography/interaction intent but use rig-family adapters.

Example:

- humanoid animation adapter
- digitigrade-quadruped adapter
- unguligrade-quadruped adapter

If a valid solve/adapter does not exist, reject the combination instead of forcing broken geometry.

## 17.2 Animation clip identity

Each clip has:

- stable `animation_id`
- `animation_version`
- duration in seconds
- compatibility metadata

## 17.3 Canonical timing

Use **seconds**, not frame numbers, as canonical animation time.

Keeps animation independent from:

- simulation Hz
- display FPS
- pixel-art authored cadence

## 17.4 Tracks and keyframes

Tracks normally animate controls, not raw deformation bones.

Supported track values:

- scalar
- vector
- quaternion
- transform
- enum/discrete
- event/reference

Interpolation:

- step
- linear
- smooth/cubic
- custom curve

Continuous keyframes may store editable incoming/outgoing tangents/easing.

Rotations use quaternion interpolation internally.

Tracks are sparse: only values intentionally owned/changed are stored.

Transform spaces may include:

- local
- character
- world
- target-relative

World-space authoring is explicit, not default.

IK tracks may reference semantic anchors/sites instead of fixed XYZ.

Raw deformation-bone tracks remain possible for specialized cases.

## 17.5 Playback modes

Every animation supports the data model for:

- forward
- reverse
- one-shot
- repeat N
- infinite repeat
- ping-pong
- native closed loop
- explicit return segment
- playback-speed control
- start/end phase

### Closed loop vs motion loop

- Closed pose loop returns to same pose.
- Motion loop may return to same skeletal phase while the entity moves through world space, e.g. walking.

### Reverse

Reverse playback is always available as an animation feature, even if not physically realistic.

Dynamic systems may:

- re-solve during reverse
- or play recorded state if exact reversal matters

Animation reverse is distinct from a full world-state rewind.

**DEFERRED:** world-state rewind mechanic.

## 17.6 Layers, masks, and conflicts

Layer schema includes:

- layer ID
- source animation
- blend mode
- priority
- mask
- weight
- timing/phase

Masks use normalized `0.0–1.0` influence per control/region.

Reusable masks may include:

- face
- upper body
- lower body
- right arm
- left hand
- etc.

Rules:

- override = highest-priority active owner
- additive = adds adjustment
- mask scales influence
- same-priority competing overrides = validation error
- explicit priority beats file order

Editor provides **“Why is this control moving?”** with all active contributing layers.

## 17.7 Reusable clip dependencies and migration

Larger animations may reference version-pinned reusable clips.

Example:

```text
idle_guard
├── breathing_v2
├── look_around_v1
└── wave_v2
```

If `wave_v3` is created:

- do not silently upgrade
- show dependency usage count
- allow explicit upgrade
- revalidate every affected consumer
- report pass/fail and exact reason
- keep older version until migration is accepted

Validate:

- controls/masks
- markers
- timing
- joint/collision
- constraints
- props/effectors
- entry/exit compatibility

## 17.8 Sync markers and normalized phase

Use named markers, e.g.:

- loop start/end
- left/right foot contact
- contact acquired/released
- variation entry/exit

Store at canonical time.

Looping interactions also use normalized phase `0.0–1.0` so different clips can remain synchronized.

## 17.9 Variation slots

Base animations may expose data-driven variation slots.

A slot defines:

- allowed variants
- required free bones/controls/effectors
- probability weights
- cooldown
- min/max wait
- repeat rules
- mask/layer behavior
- required props/sites
- compatibility
- entry/exit markers

Examples:

- idle hand rest/coin flip/head scratch
- dance twirl
- alternate hand placement
- synchronized interaction gesture

Variation eligibility checks resource availability/reachability before selection.

Selection uses deterministic seeded randomness.

## 17.10 IK and constraints

Constraint fields include:

- effector
- target
- constraint type
- position/orientation requirements
- tolerance
- influence
- active time/phase
- priority
- release behavior

Constraint types:

- position
- orientation
- full transform
- contact
- grasp
- look-at
- grounding
- distance
- aim
- support/balance
- multi-effector

Interaction-site targets may use placement biases rather than fixed coordinates.

Constraint influence can ramp `0→1→0`.

If solve fails joint/collision/reach/morphology rules:

- use declared fallback
- relax only within declared tolerance
- or fail validation

Never silently create a broken pose.

## 17.11 Animation events

Generic typed event system with payloads.

Types may include:

- sound
- contact
- impact
- effect emission
- fluid emission
- prop action
- state change
- gameplay signal
- camera signal
- custom

Support:

- point events
- event windows

Events use semantic source/target references.

Reusable subclips own their own events.

### Reverse event policy

Each event declares:

- fire both directions
- forward only
- reverse alternative
- suppress on reverse

### Scrubbing/debugging

Timeline scrubbing distinguishes:

- preview
- execute

Scrubbing across a damaging/gameplay event must not repeatedly apply side effects unless explicitly enabled.

Events use deterministic timing/seed behavior.

## 17.12 Multi-actor choreography

A multi-actor interaction is a versioned choreography graph, not one giant clip.

Contains:

- participants
- roles
- shared phase/timeline
- per-role animations
- contacts/constraints
- resource reservations
- state/phase graph
- transitions
- variation slots
- events

### Participants vs roles

Separate identity from current role so participants can switch roles.

### Shared phase

Choreography owns normalized master phase. Per-role clips map onto that phase.

### Contacts/resources

Contacts explicitly connect effectors to semantic interaction sites.

Resources are reserved/occupied so one hand/site cannot be used incompatibly twice.

### State graph

Typical phases:

```text
approach
→ align
→ establish contact
→ main loop
→ optional variation
→ disengage
→ recover
```

### Transitions

Major transitions explicitly:

- validate destination
- release contacts
- bridge/reposition
- acquire new contacts
- enter new state

If invalid after movement begins, use authored safe fallback rather than snapping backward.

### Join/leave

Joining/leaving occurs only at declared synchronization points and correctly reserves/releases resources.

### Rig-family adaptation

Same choreography may use different rig-family adapters. Invalid/incompatible combinations fail explicitly.

### Determinism/validation

Store versions/dependencies, seed, chosen variations, roles, sync state.

Validate:

- reachability
- joint limits
- collision
- required components
- resource conflicts
- contact error
- transition compatibility
- entry/exit phase

---

# 18. Registration, representation profiles, 3D→2D export, and runtime package

## 18.1 Fundamental export rule

**The 2D representation is derived from one resolved 3D body, and every exported piece carries enough metadata to prove exactly where it belongs.**

## 18.2 Export identity

Every export explicitly identifies:

- resolved geometry signature
- pose/animation/phase
- camera profile
- representation profile
- material profile
- render settings
- compiler version

Never combine pieces from mismatched morphology/geometry/configuration.

## 18.3 Camera/projection contract

Each representation defines:

- camera position/orientation
- orthographic or perspective
- framing/crop
- resolution
- pixels-per-meter/effective scale
- character alignment
- pixel snapping rules

## 18.4 Registration landmarks and shared seams

Components/export pieces expose named landmarks/seams.

Critical seam pairs should derive from the **same canonical shared seam/ring** wherever possible rather than two independently authored edges.

Pipeline:

```text
resolved 3D seam
→ projected 2D seam
→ sprite-local pixel seam
```

Validation compares expected/actual projected registration and fails when outside tolerance.

This is specifically intended to catch issues such as a vertically squished pelvis no longer meeting the torso.

## 18.5 Sprite record registration data

Every sprite/frame record carries:

- sprite ID
- component ID
- atlas page/rect
- logical size
- trimmed size
- trim offset
- pivot
- registration landmarks
- shared seams
- source surface IDs
- representation profile
- geometry signature
- depth/order metadata
- animation/time/phase metadata as needed

**Atlas page/rectangle does not define geometric placement. Registration metadata does.**

## 18.6 Trimming

Transparent trimming/packing must preserve logical placement.

Store:

- original logical canvas
- trimmed atlas rectangle
- trim offset
- pivot
- landmarks

## 18.7 Per-pixel traceability

Where required, exported pixels can map to:

- component ID
- surface ID
- region ID
- canonical UV/surface coordinate
- material role
- depth
- normal category
- source 3D surface/triangle

Exact auxiliary-buffer packing remains open.

## 18.8 Source atlas vs compiled sprite atlas

Explicit distinction:

- **Source UV/material atlas** = texture/material data applied to 3D source.
- **Compiled sprite atlas** = rasterized 2D output consumed by renderer.

Source material mapping may remain stable while a morphology change requires new compiled sprite output.

## 18.9 Representation profiles

Examples:

- `world_front`
- `world_side`
- `world_three_quarter`
- portrait
- close-up
- inventory
- interaction close-up

A representation profile changes presentation, not character identity.

Each profile defines:

- camera/projection
- output resolution
- framing
- effective scale
- detail level
- allowed art-direction corrections
- required visible components
- silhouette simplification
- shading/material simplification
- export settings
- validation tolerance

### Representation-only art direction

May intentionally exaggerate/simplify:

- eyes
- hands
- facial expression
- overlapping limbs
- muscle/breast/glute curves
- hair strands

These are representation-only and never feed back into canonical morphology.

### Shared state

Switching representation preserves:

- morphology
- animation/pose phase
- facial state
- clothing state
- surface marks
- wetness/residue
- anatomy state
- interaction contacts

Each profile declares which details are supported/simplified/omitted.

## 18.10 Compiled representation package

The runtime consumes a self-contained deterministic package:

```text
CompiledRepresentationPackage
├── identity/versions
├── source signatures
├── representation profile
├── atlas pages
├── sprite/frame records
├── registration metadata
├── auxiliary buffers
├── palette/material mapping
├── animation metadata
├── event/sync metadata
└── validation report
```

Runtime does **not** require the 3D editor or hidden authoring state.

### Palette/material mapping

Preserve semantic roles in the runtime package so recoloring/environment shifts can reuse atlases where geometry permits.

### Animation metadata

Include:

- sprite sequence
- authored holds/durations
- normalized phase
- loop mode
- reverse support
- sync markers
- variation markers
- event markers

Simulation rate and pixel-art frame cadence remain separate.

## 18.11 Export validation

Validate before package acceptance:

- seam continuity
- landmark alignment
- pivot consistency
- gaps
- unintended overlap
- silhouette
- source signatures
- morphology
- camera/profile
- component configuration
- stale generated artifacts

Failed production package is not accepted.

## 18.12 Pixel-to-source debug inspector

Clicking a rendered pixel should be able to reveal:

- sprite/component
- surface
- canonical UV/surface coordinate
- source triangle
- resolved 3D position
- projected 2D position
- sprite-local position
- atlas position
- related seam/landmark

---

# 19. Deterministic serialization, hashing, validation, migration, and builds

## 19.1 Canonical JSON

Rules:

- UTF-8
- `snake_case` fields
- deterministic generated field ordering
- deterministic collection ordering
- no duplicate IDs
- no NaN/infinity
- no meaningless precision noise

For `f32`:

- parse/store as `f32`
- serialize shortest decimal that round-trips to the exact same `f32`

Arrays with semantic ordering preserve it. Unordered collections canonicalize by stable ID.

### M01 locked canonical byte identity

- Canonical source-definition bytes use UTF-8.
- Canonical JSON contains no insignificant whitespace.
- The canonical byte payload has no trailing newline. A CLI or editor may print a newline after displaying the payload, but that newline is not part of canonical bytes or hashing.
- `-0.0` canonicalizes to `+0.0`.
- Equivalent quaternion signs canonicalize to the same quaternion representation using the locked quaternion identity rules in section 3.3.
- Display names participate in the M01 `source_definition_hash` because they are part of the exact canonical source definition.
- Future stage-specific hashes, such as resolved-geometry or representation hashes, may define different dependency scopes where appropriate.
- All canonical values, defaults, and ordering normalize before serialization and hashing.
- Hashing never depends on file name, timestamp, source formatting, or unordered input collection order.

## 19.2 Defaults and normalized canonical form

Readable authoring files may omit defaults.

Before hashing, compiler creates normalized canonical form with defaults explicitly resolved.

Equivalent authoring input must produce equivalent canonical identity.

## 19.3 Hashes

Use SHA-256 or equivalent strong stable signature.

Stages may have distinct hashes such as:

- source-definition hash
- resolved-geometry hash
- resolved-pose hash
- representation-package hash

Generated artifacts record all relevant dependency hashes.

## 19.4 Validation severity

- error
- warning
- info

Errors may include:

- duplicate/missing IDs
- broken references
- cycles
- invalid parent hierarchy
- invalid weights
- incompatible topology
- conflicting bindings
- invalid joint ranges
- missing seams
- registration outside tolerance
- stale dependencies

Diagnostics identify exact object/property.

## 19.5 No silent repair

Invalid canonical data is not secretly corrected.

Example: weights totaling `1.03` are not silently normalized.

Editor may offer an explicit “normalize/fix” authoring operation that changes source data.

## 19.6 Schema migration

Versioned deterministic migration:

```text
v1 → v2 → v3
```

Rules:

- preserve stable IDs where possible
- report non-exact translation
- never silently discard unsupported data
- create new canonical file
- preserve old source until accepted

## 19.7 Reproducible builds

Identical:

- canonical inputs
- dependencies
- compiler version
- generation settings
- deterministic seed

should produce byte-identical canonical/generated metadata and deterministic visual output where supported.

## 19.8 Dependency graph

Build tooling tracks upstream/downstream dependencies so changes trigger only required:

- revalidation
- regeneration
- cache invalidation

No blind full rebuild requirement and no silent stale reuse.

---

# 20. `human_base`: first canonical neutral human asset

## 20.1 Definition

`human_base` is an authoring reference, not necessarily a game character.

Defaults:

- 1.8288 m / 6 ft
- A-pose
- faces `+Z`
- origin between feet at `Y = 0`
- full shared human skeleton/rig
- continuous shared human topology
- symmetric morphology
- human-realistic middle-of-range proportions
- moderate/neutral muscle development
- moderate-low body fat
- no exaggerated definition
- minimal/default breast-tissue morphology
- shared perineal foundation
- optional external genital modules disabled
- normal healthy eyes/teeth/nails/skin
- no hairstyle/facial hair/body hair/clothing/jewelry/accessories
- neutral material instance
- neutral temporary state

Derived test profiles:

```text
human_base
├── male_typical_test
└── female_typical_test
```

These are configurations/presets using the same rig/source, not separate rigs.

## 20.2 Continuous canonical body mesh

Use **one continuous main body mesh** wherever practical:

- torso
- pelvis
- arms
- legs
- neck
- head

Separate geometry only when structurally useful:

- eyeballs
- teeth/gums
- tongue
- nails
- hair
- optional genital modules
- other optional modules

Resolve the continuous body first. Derive modular 2D pieces afterward.

## 20.3 Quad-based authoring topology

Canonical authoring mesh is quad-oriented for edge flow/editability.

Rules:

- stable vertex IDs/topology within human morphology family
- anatomy/deformation-driven edge loops
- more density around high-deformation/high-detail regions
- less density on flatter areas
- continuous morphology does not change vertex count
- deterministic triangulation for processing/rendering/export
- exact polygon count is not fixed in advance

## 20.4 Subdivision

Use:

```text
canonical quad deformation mesh
→ optional deterministic subdivision
→ triangulation
→ representation/export
```

Subdivision improves smoothness/detail but is **not required for anatomical correctness**.

Canonical deformation mesh must already deform correctly.

Fine pores/wrinkles/etc. should usually come from material/normal/displacement data rather than millions of base polygons.

## 20.5 Rest skeleton and body landmarks

For `human_base`:

- `skeleton_root` at canonical origin
- explicit rest transforms in meters
- exact left/right mirroring
- anatomically sensible pivot centers
- feet contact `Y = 0`
- mesh and skeleton resolve from the same measurement/morphology data

Stable measurement landmarks include head/chin/shoulder/elbow/wrist/fingertip/hip/knee/ankle/heel/toe and other required semantic points.

Do not hardcode many body ratios as universal engine rules; `human_base` has one neutral set, morphology generates others.

## 20.6 Initial morphology-target proof set

Do not sculpt every final slider immediately.

First proof set should include representative controls such as:

- target height / major proportions
- shoulder/pelvis width
- torso width/depth
- arm/leg proportions
- muscularity
- body fat
- head/face proportions
- breast morphology
- glute morphology
- male/female-typical configurations

Expand after the system proves stable.

## 20.7 Initial required correctives

Start with the validation-driven set described in section 16.4.

## 20.8 Semantic instantiation on mesh

Instantiate:

1. semantic surface regions
2. shared seams/boundaries
3. precise landmarks
4. anchors/sockets
5. interaction sites

Validation ensures required IDs exist, are on correct surfaces, mirror correctly, and move correctly with morphology.

## 20.9 Neutral material instances

Initial neutral material instances include:

- skin
- lips
- nails
- tooth enamel
- gums
- tongue
- sclera
- iris
- pupil
- cornea/eye surface

---

# 21. Collision proxy contract

Collision is required in the resolved geometry snapshot but exact dimensions are empirical.

Rules:

- simple primitives where practical: capsules, spheres, boxes
- multiple proxies for complex regions rather than one giant collider
- higher-fidelity convex/deformable proxies only where close-contact accuracy matters
- gameplay collision remains separate from visible mesh
- close-contact/interaction solving may use higher-fidelity geometry than movement collision
- proxies resize/reposition from the same morphology resolver as mesh/bones/anchors/garments
- editor overlays proxies on body
- validation checks they match resolved morphology

Exact proxy dimensions are **OPEN/TUNING**.

---

# 22. Resolved Human Geometry Snapshot

After `human_base` is built, generate the first authoritative resolved neutral geometry snapshot.

It contains at least:

- final vertex positions
- resolved rest skeleton
- anchors/sockets
- semantic surfaces/regions
- landmarks/seams
- skin weights
- UVs/material assignments
- collision proxies
- interaction sites
- measurements/bounds
- source/schema/compiler/version hashes

Downstream systems consume this snapshot instead of independently reinterpreting morphology.

---

# 23. Validation philosophy and test matrix

## 23.1 General validation rule

**Every construction stage gets its own validation pass.**

The goal is to catch failures close to their source and avoid guessing later.

Validation must produce measurable diagnostics wherever possible.

## 23.2 Lower-body validation

Locked tests include:

- normal standing
- walking
- running
- deep squat
- kneeling
- bilateral tiptoe
- alternating single-leg heel raise while both feet remain grounded
- one-leg balance
- normal jump
- exaggerated game-style jump
- one-foot push-off/hop
- high kick
- leg spread
- climbing step
- sitting
- twerking/pelvic isolation
- extreme hip flexion
- glute/thigh compression
- crawling

### Jump phases

Validate:

1. load/crouch
2. hip/knee/ankle/toe extension
3. toe-off
4. airborne
5. landing contact
6. compression
7. recovery

## 23.3 Upper-body validation

Locked tests include:

- arms overhead
- arms fully out to sides
- full arm/forearm pronation/supination
- reach across chest
- reach behind back
- hands behind head
- arms crossed
- deep push/pull
- push-up/plank
- one-arm/two-arm hanging
- climbing/pulling upward
- throwing
- sword swing
- bow draw/release
- procedural grips at multiple object sizes
- maximum elbow flexion
- shoulder shrug/protraction/retraction
- extreme spine bend/twist with arm constraints
- breathing with moving arms/shoulders
- clapping

## 23.4 Full-body validation

Locked tests include:

- walk/jog/sprint
- start/stop/change direction
- jump/landing
- hop
- crouch→sprint
- crawl
- climb
- swim
- full-body throw
- melee swing with hip/spine/shoulder rotation
- kick with upper-body counterbalance
- lift/carry/push/pull heavy object
- hanging/pull-up
- falling/getting up
- strikes from multiple directions
- dancing with independent torso/pelvis/limbs
- twerking
- sitting↔standing
- extreme whole-body twist
- simultaneous constrained hands/feet
- jump rope
- lunges
- front split
- side split

## 23.5 Head/neck/hair validation

- nod yes
- shake no
- full head/neck circles both directions
- hair response to head movement
- hair-pull force from multiple directions
- constrained vs free head
- long vs short hair
- force transmission from hair → scalp/head → neck/spine

Hair should not stretch infinitely; limits eventually move head/deform hair/reach authored constraints.

## 23.6 Yoga/deep-flexion validation

Include:

- happy baby
- cat-cow
- downward dog
- deep forward bend/bent-over pose
- other useful extreme-flexion reference poses

## 23.7 Soft-tissue/contact validation

Include:

- hands displacing breasts inward/outward/up/down/forward
- nipple-specific deformation
- hands displacing/compressing glutes
- glute/perineal response
- localized anal-opening deformation where geometry/contact warrants it
- running/jumping/stopping stressing breast/glute/genital recoil
- extreme exaggeration settings specifically to expose solver instability
- tissue recovery after release

## 23.8 Physiological/effect validation

Later tests include:

- arousal transitions
- erection-state deformation
- genital self-contact/manipulation as a contact/grasp test
- external genital wetness/lubrication
- fluid emission/transfer
- surface wetness/residue
- recovery and accelerated/skipped test modes

These validate state/contact/emitter/surface systems rather than only the skeleton.

## 23.9 Real-world reference comparison

The authoring/validation workflow may compare generated poses/deformation against real human reference images/video, including nude anatomical reference when appropriate, to assess realism and deformation quality.

## 23.10 Multi-morphology validation

Representative validation must run across morphology extremes, not only `human_base`.

At minimum:

- short/tall
- narrow/broad
- lean/heavy
- low/high muscularity
- male-typical/female-typical

A pose passing on the six-foot neutral body is not sufficient.

## 23.11 Loopability of validation clips

Validation animations should be loopable through:

- native closed loop
- explicit return segment
- optional ping-pong/reverse

Playback supports:

- one-shot
- repeat N
- infinite loop
- speed control

This makes deformation problems easier to inspect repeatedly.

---

# 24. Deferred, excluded, and open/tuning items

## 24.1 DEFERRED implementation

Architecturally supported but not required for the first canonical-human milestone:

- detailed body-hair implementation
- detailed facial-hair implementation
- eye/iris glow/effect implementation
- unusual/missing/crooked/damaged teeth
- makeup/cosmetics
- specific piercing-location authoring
- exotic multi/branching penis physical implementation
- many exotic eye/ear/body-module configurations
- full garment schema/editor
- detailed garment cloth solver
- detailed fluid system
- persistent dirt/residue in games that do not need it
- full live runtime 3D
- world-state rewind
- full thermodynamic/surface-area heat-loss model
- full-body mass/inertia/balance system until physical-animation validation
- exact auxiliary-buffer packing strategy

## 24.2 EXCLUDED/currently rejected

- stretch marks in the current canonical-human implementation
- using milk volume as a direct breast-morphology size driver
- detailed surface-area-based heat-loss calculations for the initial temperature system
- silent topology changes
- silent dependency upgrades
- silent data repair
- atlas location as a substitute for explicit registration
- one monolithic male rig and separate female rig
- one item per broad body region as a garment-equipment rule

## 24.3 OPEN/TUNING

These are deliberately empirical:

- exact joint-angle limits
- exact mobility defaults
- exact neutral A-pose joint angles
- exact neutral body proportions inside the human-realistic range
- exact canonical polygon/quad count
- exact edge-loop density
- exact skin weights
- exact morph endpoint sculpt values
- exact corrective-shape deltas/activation thresholds
- exact soft-tissue solver coefficients
- exact collision-proxy dimensions
- exact material numeric values
- exact UV packing/layout coordinates
- exact atlas auxiliary-buffer channel packing
- exact representation error tolerances
- exact per-profile pixel scale/camera numbers
- exact body mass/center-of-mass/inertia properties
- exact garment thermal-property model

These should be tuned through the editor and validation harness rather than guessed in advance.

---

# 25. Immediate implementation milestone

The architecture is sufficiently specified to stop adding abstract rules and begin implementation.

Recommended next execution sequence:

```text
build human_base continuous quad mesh
→ place canonical rest skeleton/landmarks
→ skin mesh
→ implement initial morphology proof set
→ implement initial corrective set
→ instantiate surfaces/seams/landmarks/anchors/sites
→ assign neutral materials/UVs
→ generate collision proxies
→ generate first Resolved Human Geometry Snapshot
→ run staged validation
→ derive male_typical_test / female_typical_test
→ fix evidence-backed failures
→ only then expand finer morphology and downstream garments/representations
```

The primary engineering principle going forward is:

> **If something looks wrong, the tooling should identify the exact stage, parameter, binding, deformation, seam, registration value, or dependency responsible. The pipeline must prefer measurable traceability over visual guesswork.**
