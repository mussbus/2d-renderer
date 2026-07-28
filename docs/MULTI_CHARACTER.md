# Multi-Character Runtime and Occlusion

## Ownership model

`character.CharacterInstance` is the mutable per-entity runtime boundary. Each instance owns its stable entity ID, optional controller value, visual world position, facing, pose buffers, animator playback and event buffers, procedural springs, actor layer, bounded layer overrides, last submitted order keys, and counters. A physically controlled instance stores its `CharacterController` value inline; a passive visual instance has no controller and therefore cannot enter collision queries accidentally.

Instances borrow `HumanoidDefinitionView` and `AnimationDefinitionsView` records. These views copy only stable slice, lookup, and compatibility-token metadata. Their skeleton bones, sockets, attachments, clip keys, events, states, and transitions remain in the scene-owned immutable allocations. The views do not own or release those allocations. This avoids dependence on a movable owner-wrapper address while allowing both characters to prove that their underlying attachment and clip slice pointers are identical.

Each pose, animator scratch pose, animator event buffer, procedural state, override table, and controller state has distinct storage. Resetting one character touches only that instance. Whole-scene reset explicitly visits both instances. Runtime entity removal is not introduced in Prompt 7; the scene tears down B, then A, then shared animation definitions, then the shared humanoid definition. IDs are therefore not reused during a scene lifetime.

## Stable entity identifiers

`EntityId` has an explicit `u32` representation. Zero is invalid. `EntityIdAllocator` starts at one and returns monotonically increasing values; two allocators replay the same deterministic sequence. The maximum `u32` value is issued once, after which allocation returns `error.EntityIdOverflow`. It never wraps. `EntityRegistry` rejects zero, duplicates, and more than eight simultaneous registered characters. Identity and ordering never use object, slice, allocator, or GPU addresses.

## Facing and reflection

Facing is anatomical-state-preserving visual data:

- `left_hand`, `right_hand`, `left_foot`, and `right_foot` semantics never change.
- Animation tracks continue to target their authored anatomical bones.
- The immutable skeleton and socket definitions are never rewritten or copied for facing.
- Physics position, velocity, AABB half extents, grounding, support, and collision results are not read or written by `setFacing`.

The reflection is applied once in character-to-world evaluation. Right facing uses `T(world_position)`. Left facing uses `T(world_position) * S(-1, +1)`, reflecting across the vertical axis through `world_position.x`. Translation therefore remains fixed, local X changes sign, local Y is preserved, and every ancestor rotation participates before the root reflection. Socket transforms need no separate mirroring step.

Reflected attachment matrices are decomposed to a negative presentation X scale, a positive Y scale, and a corresponding rotation. Pivots remain unit-quad values and pass through the same production instance record. UV bounds are unchanged; reflecting geometry around its pivot intentionally mirrors the sampled sprite once. The SDL GPU pipeline uses `SDL_GPU_CULLMODE_NONE`, so negative scale cannot cull a sprite. Tests cover a rotated torso and upper arm, hand and foot sockets in both directions, preserved anatomical meanings, and a right-left-right round trip within `1e-5` metres.

Future IK must solve against the already reflected world hierarchy or transform its targets into the same character space. It must not mirror socket results a second time.

## Semantic order model

Every sprite uses the existing lexicographic integer key:

```text
scene layer, interaction layer, actor layer, body-part layer, submission index
```

Scene-layer anchors are background `-30000`, world `-10000`, characters `0`, foreground `10000`, and debug overlay `30000`; values between anchors are reserved for subdivisions of that scene class. Existing static controller geometry at `-10` remains below characters inside the upper world interval. Interaction layer `0` is neutral. Prompt 7 reserves the checked inclusive range `[-1024, +1024]` for temporary interaction ordering. Actor layer is an unsigned 16-bit whole-character default. Body-part layer is an unsigned 16-bit anatomy-local value. The final `u64` submission index is assigned by the one global `SpriteBatch`.

The centralized default layers are:

| Visual role | Thigh/upper arm | Shin/forearm | Foot/hand |
| --- | ---: | ---: | ---: |
| Back leg | 10 | 11 | 12 |
| Back arm | 20 | 21 | 22 |
| Centre body | Pelvis 30 | Torso 31 | Head 40 |
| Front leg | 50 | 51 | 52 |
| Front arm | 60 | 61 | 62 |

For right facing, anatomical left limbs use back roles and anatomical right limbs use front roles. Left facing reverses only this visual role mapping. Bone hierarchy order, attachment array order, and debug names do not choose depth.

## Temporary overrides

Each character embeds eight override slots. Applying an override allocates nothing and returns a monotonic nonzero handle. A target may be an attachment ID or an attachment semantic, including a specific hand or forearm. Invalid IDs, invalid raw semantics, an empty request, out-of-range interaction values, invalid body layers, exhausted handle values, and a ninth simultaneous override all return specific errors.

An override may independently replace the interaction component, body-part component, or both. For multiple active overrides of one attachment, the highest handle wins separately for each supplied component. Clearing the latest override reveals an older component value; clearing one handle never clears another attachment or another character. `clearAll` and character reset restore the exact facing-computed defaults without mutating `RenderAttachment.body_part_layer`.

Because interaction precedes actor in the comparator, A can remain behind B at the torso while A's hand or forearm is temporarily above B. Moving one limb never changes the whole actor layer.

Prompt 27 extends the consumer, not this ordering model: the interaction
definition selects a typed occlusion profile, and equipment bound to an
anatomy semantic inherits that semantic's interaction layer while preserving
its own body/garment layer. A glove therefore follows the participant's hand
without replacing actor order, changing item identity, or adding an
outfit-specific branch.

## Global submission and batching

`submitGlobally` accepts up to eight character pointers, sorts a fixed stack array by numeric entity ID, rejects duplicate IDs, and submits every attachment into the existing global batch. Pointer values are never compared. Entity order plus immutable attachment order establishes the deterministic final tie-breaker. The batch then performs one global semantic sort, permitting attachments from different characters to interleave.

Both demonstration characters share texture page zero. Their 15 attachments each produce exactly 30 humanoid instances, one compatible range, one 1,800-byte instance upload, and one `SDL_DrawGPUIndexedPrimitives` command. Facing, actor changes, override apply/clear, and restoration create no GPU resource.

## Deterministic demonstration

Run:

```powershell
zig build run -- --frames 720 --demo multi-character
```

Each 80-frame phase logs the six final submitted keys for both torsos, right forearms, and right hands, then validates the required comparison:

1. A behind B.
2. B behind A.
3. A right hand above B right hand while A torso remains behind.
4. B right hand above A right hand while B torso remains behind.
5. A right forearm above B torso while A torso remains behind.
6. Exact override restoration.
7. Mirror A.
8. Mirror B.
9. Restore stable right/left facing and default actor order.

A begins in walk while B remains idle, then B starts later. The captured evidence has different clip times, distinct hand poses, active walk bounce only on A, and shared immutable clip storage. The final phase clears overrides and returns A/B to actor layers zero/one and right/left facing.

## Allocation and failure policy

Pose/animator allocations occur only during instance initialization. Controller state, procedural state, ID registry, overrides, phase tracking, ordering copies, and evidence are inline or fixed capacity. Character update, mirroring, layer resolution, override operations, global submission, hierarchy evaluation, and sorting perform zero heap allocation after capacity stabilization.

Second-character fault tests inject failure at pose-local, pose-world, character, animator-pose, and animator-event acquisition stages. Every partial second instance releases what it acquired, the first instance and shared definitions remain usable, and a subsequent second-character creation succeeds.
