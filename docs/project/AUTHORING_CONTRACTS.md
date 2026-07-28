# Unified Authoring Contracts

This document distinguishes the **current production schema** from the **required stable authoring contract**. “Required” describes what a future schema/editor must express; it does not claim that every field is implemented today. Runtime gaps are tracked in [KNOWN_GAPS.md](KNOWN_GAPS.md).

## Universal identity rule

Every authored entity has separate identities where applicable:

1. stable logical identity — persistent content identity;
2. runtime typed identity — bounded index/enum used after initialization;
3. atlas-region identity — visible pixel source;
4. presentation view — front, side, or future authored view;
5. facing/reflection behavior — how a view responds to gameplay facing.

Texture packing never owns semantic identity. Different body, clothing, and equipment regions may share a texture page without becoming one asset.

## Entity contract matrix

| Entity | Stable/runtime identity | Current production fields | Required validation/ownership |
|---|---|---|---|
| Texture page | stable page ID / typed page ID | source path, dimensions, pixel format, GPU page index | exact pinned asset, deterministic decode, explicit GPU lifetime |
| Atlas region | stable region ID / typed region ID | page, alpha-tight source rectangle, semantic/view binding | in-page bounds, non-empty visible alpha, deterministic visible geometry |
| Presentation view | stable `ViewId` / typed ID | front and canonical side are used in production | explicit availability; no filename inference |
| Anatomy component | stable part instance/type / typed IDs | skeleton binding, body region, base-presentation visual | anatomy owns the body even with no garment equipped |
| Body preset | stable preset / typed ID | selected anatomy morphology defaults | deterministic compatibility and bounded channel values |
| Morphology channel | stable channel / typed ID | affected dimensions and response weights | only semantically relevant geometry responds |
| Hair | independent presentation semantic and atlas binding | one front/side visual per current style | remains independent of anatomy and headwear; future depth fragments may be needed |
| Face | stable face definition and presentation semantic | style-specific art/view binding | does not alter skeleton or equipment identity |
| Equipment item | stable item / typed `EquipmentItemId` | slots, recipes, coverage, modifiers/capabilities | bounded transactional equip; effects do not own movement/combat logic |
| Garment | one logical equipment item | one or more bounded recipes | must not be equated with one sprite, one region, or one layer |
| Outfit preset | stable preset / typed ID | bounded ordered item list | recombines ordinary items; no monolithic full-body texture |
| Sprite visual | component/semantic/region IDs | binding, authored size, pivot, deformation response, texture page | production transform, alpha-visible geometry, semantic landmarks |
| Deformable mesh visual | component plus mesh/material IDs | bounded vertices/indices and weights | same unified queue and resource lifecycle as sprites |
| Secondary-motion visual | resolved visual instance + definition | bounded points/springs and fixed-step state | state persists by visual identity; no steady-state allocation |
| Interaction presentation | interaction/participant/target semantic identity | handshake targets, ordering, IK/debug metadata | interaction system remains authority; visuals cannot fabricate success |

## Logical garments and bounded visual recipes

A garment remains one logical reusable equipment item:

```text
Logical Garment
    + occupancy claims
    + anatomy compatibility
    + semantic coverage
    + gameplay effects (usually none)
    + view-specific visual recipe
        + fragment A
        + fragment B
        + fragment N
```

Current support: [`equipment.ItemVisualRecipe`](../../src/scene/equipment.zig) provides a bounded component, anatomy/attachment binding, transform, body region, and visual layer. `every_compatible` expands one recipe over compatible anatomy instances, so the conventional blouse resolves one torso visual plus two sleeve visuals while remaining one item. `maximum_visual_recipes` and `maximum_resolved_visuals` bound initialization and runtime storage.

Required stable fragment contract:

- stable fragment ID;
- owning logical garment;
- applicable presentation view(s);
- side-facing/reflection policy;
- semantic anatomy binding;
- pivot or attachment anchor;
- semantic landmarks;
- body-relative depth relationship;
- contribution to declared coverage;
- deformation response;
- optional mesh use;
- optional secondary-motion use;
- deterministic resolved ordering.

Current `ItemVisualRecipeId` is deterministic but not a persisted authored fragment name. The future stable fragment field must be added only when production content or the authorized editor/export milestone needs it.

## Body-relative depth

A reusable garment fragment must be able to declare one of these relations, optionally relative to a semantic limb:

- behind entire body;
- behind torso;
- behind neck/head;
- behind a specific limb;
- between far and near limbs;
- in front of torso;
- in front of neck/chest;
- in front of a specific limb;
- foreground accessory.

The unified queue remains the only renderer. A future resolver maps semantic relations into its internal numeric order tuple. Item-name conditions and submission-time callbacks are forbidden.

Current production status: wardrobe definitions use named layers (`lower`, `upper`, `sleeves`, `long_lower`, `legwear`, `footwear`, `gloves`, `upper_outer`, `sleeves_outer`, `waist`, `headwear`) which resolve to audited numeric layers. This is sufficient for accepted items but not a stable editor-facing semantic depth schema.

## Required layered examples

### Skirt

Front:

- rear/back panel: behind pelvis and legs;
- front panel: in front of pelvis and declared leg portions;
- waistband: aligned to the waist contract;
- optional hem: deformable mesh and/or bounded secondary motion.

Side:

- far-side fabric: behind the far leg;
- central waist/body fragment;
- near-side fabric: in front of the near leg;
- deterministic near/far resolution when facing changes.

The current `garnet_split_skirt` is one deformable mesh and does not yet model these depth fragments independently.

### Blouse or halter

- torso fabric in front of the chest;
- optional rear collar/strap behind the neck;
- optional front collar trim in front of lower neck/upper chest;
- sleeves independently bound and validated against their corresponding arms.

### Jacket

- back panel;
- torso panel;
- lapel/front trim;
- repeated topology-aware sleeves;
- optional rear tail with mesh/secondary motion.

### Hair with headwear

- back hair;
- headwear;
- front hair or facial framing.

The composition must follow semantic depth data, not a hat-name/hair-name branch.

## Directional side presentation

### Policies

**Mirror-safe**

One canonical side visual is reflected with gameplay facing. Use it for symmetric or reflection-safe silhouettes/details.

**Authored directional variants**

Separate side-left and side-right presentations. Use when front/back construction or asymmetric detail would be wrong under reflection.

**Mixed-fragment directional composition**

Each fragment declares its policy. A reusable body panel may reflect while a placket, wrap, bow, or asymmetric trim resolves direction-specific art.

### Facing invariants

Changing gameplay facing must not:

- change equipment item identity or outfit preset;
- recreate loadout/visual runtime state;
- decode images, read files, or create GPU resources;
- reset deformation or secondary motion;
- swap anatomical left/right identity.

Only selected presentation fragments and their transforms/order may change.

### Current production proof

`ivory_blouse` was inspected in front and canonical side art, in the stored `06_ivory_blouse_side` D3D12 golden, and across the existing front/side-left/side-right geometry matrix. Its torso and sleeve sources have no directional placket, bow, or front/back detail that becomes false when reflected. It is therefore a valid **mirror-safe** control, not proof that every future blouse may reflect.

The runtime does not yet expose authored directional/mixed policies because no accepted production item requires them. Adding unused policy state now would violate the repository rule against abstractions unused by the current or immediately following milestone.

## Neck and collar coverage

Upper-body authoring regions must distinguish:

- torso core;
- upper chest;
- clavicle;
- neck base;
- collar band;
- left/right shoulder transition;
- left/right armhole.

A garment declares only the regions it intends to cover. A low-neck top is valid with the neck exposed; a high-neck or collared garment is invalid if its declared collar region is uncovered.

Collar depth may require:

```text
rear collar loop      -> behind neck
torso fabric          -> in front of torso
front collar edge     -> in front of lower neck / upper chest
```

Validation for a declared collar includes neck-base registration, width/span, intended and off-target coverage, and front/behind-neck order. It must not paint a fake body-colored hole or force the entire garment in front of or behind the character.

Current status: `visual_geometry.FitContract` supports semantic point registration and bounded coverage zones, but no first-class collar-region declaration or collar-fragment ordering exists. Current accepted tops are low-neck/halter/open-neck designs; the richer contract is required before a genuinely collared/high-neck production item or editor export.

## Shoulder-slope-aware fit

Physics torso collision is not a clothing contour. Required visual landmarks are:

- neck-base center, left, and right;
- left/right clavicle or upper-chest transition;
- left/right shoulder seam;
- left/right shoulder root;
- left/right armhole reference.

A compact bounded representation may be a fixed landmark polyline or semantic span plus slope. An unbounded vector-path system is not required.

Upper-garment fit validates:

- neckline registration;
- shoulder-seam registration;
- left/right slope agreement;
- armhole registration;
- upper-chest and waist spans;
- intended coverage and design-specific clearance.

Sleeves additionally validate proximal opening to shoulder/upper arm, gap/overlap, ordering, front/side/facing, and relevant morphology extremes. Oversized opaque patches are not a valid solution.

Current status: torso and garment geometry expose neck, shoulder, chest, and waist points/spans, but current shoulder pairs are effectively flat and do not encode the neck-to-root slope contour. Prompt 25D art passes current semantic/pixel continuity and human acceptance; slope-aware authoring remains required before routine fitted-garment export.

## Morphology and deformation

Expected fit derives from the active skeleton, body preset, morphology channels, and presentation profile. It must not use a global “correct human proportions” table.

Each fragment declares which dimensions may affect:

- scale and clearance;
- pivot/landmark transform;
- deformation response;
- attachment overlap.

Unrelated channels must not move a shoulder root or collar merely because they share a generic scale. Current wardrobe components follow authoritative bound-anatomy morphology and have design-specific breathing response.

## Future editor output boundary

The future editor is a user interface over the production schema. It must export ordinary atlas resources, item/component/recipe definitions, fit/coverage metadata, and validator inputs. It must not generate routine item-specific Zig branches or maintain parallel anatomy, layering, reflection, morphology, collision, or validation models.

Expected workflow:

```text
Create/import original garment artwork
    -> assign stable logical garment identity
    -> declare occupancy and compatible anatomy
    -> declare semantic coverage
    -> add required presentation views
    -> choose side reflection policy
    -> split into bounded fragments where necessary
    -> bind fragments to anatomy landmarks
    -> assign body-relative depth
    -> place pivots and semantic landmarks
    -> define morphology/deformation response
    -> preview required matrix
    -> run production validator
    -> export ordinary runtime definitions and atlas resources
```

Minimum preview/validation matrix:

- views/facing: front, side-left, side-right, and both turn directions;
- poses: neutral, walk stride phases, jump rise/fall, deep knee bend where relevant;
- morphology: nominal plus relevant low/high extremes;
- layer checks: body-only, highlighted fragments, depth/order, coverage, landmarks, and a visually distinct collider overlay;
- composition: compatible hair/headwear, adjacent garments, and a custom recombined outfit.

The editor invokes the same semantic validator used by tests and CI.

## Validation requirements

Every production definition must retain:

- deterministic metadata validation;
- atlas/alpha-visible geometry checks;
- production-path landmark transforms;
- independent semantic left/right identity;
- registration, axis, fit, coverage, and continuity checks;
- relevant pose/morphology sweep;
- actionable diagnostics;
- bounded resources and zero steady-state allocation/resource churn;
- real D3D12 visual inspection before golden approval.

Golden comparison detects visual change; semantic geometry explains correctness or failure.
