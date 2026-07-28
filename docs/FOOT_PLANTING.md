# Deterministic Foot Planting

## Authority boundary

Walk events express authored anatomical contact intent only. `CollisionWorld.queryGroundDown` validates physical support using the same immutable static AABB array used by the character controller. Controller grounding, support ID, position, velocity, collision bounds, jump/landing results, and animation selection remain authoritative and are never written by foot placement. A plant is a character-local visual constraint on a mutable pose.

`left_foot_contact` always addresses the anatomical left foot and `right_foot_contact` always addresses the anatomical right foot. Character reflection changes the world transform and bend sign; it never swaps events, sockets, bindings, or plant storage.

## Ground query contract

The reusable query is a vertical downward point query against eligible solid AABB top faces:

- Origin, maximum distance, and epsilon must be finite; distance and epsilon must be nonnegative.
- An origin exactly on a top face is a zero-distance hit.
- A hit exactly at maximum distance is included. Epsilon permits only comparison tolerance; it never moves the returned point.
- X containment includes both AABB edges within `0.00001 m`. The returned hit X equals the query X, so the query never snaps sideways onto a platform.
- Only `solid && ground_query_eligible` top faces qualify. Demo walls and the ceiling are explicitly ineligible; undersides and sides are never candidates.
- An origin below a candidate top, including an origin inside that collider, cannot hit that top.
- The nearest downward top wins. Distances equal within epsilon use the lowest stable `ColliderId`; array addresses and hash order are irrelevant.
- No candidate returns `null`, with no fabricated normal, collider, or target.

Foot sampling uses the pre-leg-IK sole X, raises the query origin by `1.00 m`, and queries at most `2.00 m`. This deliberately covers the authored gait's visual swing/contact displacement. Acquisition still rejects a target outside the immutable chain reach, so the longer probe does not extend a leg or create support. The desired target is `(pre_ik_sole.x, ground_height + 0.0 m)`.

## Immutable leg bindings and solver

Each `CharacterInstance` creates two stable bindings during initialization. No fixed tick performs a semantic or debug-name lookup. Both chains are hip/thigh, knee/shin, ankle/foot, and anatomical sole socket. Lengths come only from rest transforms:

| Chain | Upper length | Effective knee-to-sole length | Local bend |
|---|---:|---:|---|
| Anatomical left | `0.900000 m` | `0.919239 m` | positive, character-forward |
| Anatomical right | `0.900000 m` | `0.919239 m` | positive, character-forward |

The effective lower length includes the immutable ankle transform and sole-socket offset. `leg_ik` reuses `two_bone_ik.solve`; it does not contain a second geometric solver. Near/far targets use the generic classification and clamp, segment lengths never change, and all results must remain finite. Facing left flips the world bend while preserving anatomical identity.

## Fixed-tick plant state

Each foot independently owns `swing`, `plant_candidate`, `planted`, or `releasing`, a bounded weight, optional world target and collider ID, latest ground sample, last consumed event identity, pending contact intent, pre/post sole positions, reachability, and bounded aggregate metrics. Definitions and clips contain no mutable plant data.

Walk phase is normalized to `[0,1)` and centralized as:

- Left stance: `[0.00, 0.58)`.
- Right stance: `[0.50, 1.00)`.

The `0.08` overlap gives a deterministic dual-contact transition without stretching either chain. A contact starts pending acquisition. If the authored sole is not yet reachable at the event sample, the intent may acquire later in the same stance after a fresh valid query; it cannot survive the stance, state exit, or airborne transition. This handles the existing transition-start event without a snap.

Acquisition requires a matching event, authoritative grounding, an active walk destination/current state, positive walk blend weight, eligible ground, and an unclamped reachable target. Weight moves toward one over `0.10 s` using only `1/240 s` ticks. Stance exit, walk exit, invalid collider identity/height/X support, or excessive reach begins a `0.08 s` release. Jump/airborne transition immediately clears both locks and weights; landing cannot reuse a pre-jump target and requires a fresh event and query. Reset clears only that character's two feet.

The locked target is assigned once from the pre-IK sample and remains world-space fixed. Repeated contacts cannot move an existing lock, and post-IK output never feeds target acquisition. The implementation uses no visual pelvis/root compensation: an unreachable single or dual lock releases deterministically. Physics root motion and Prompt 6 root/pelvis offsets remain untouched.

## Pose pipeline and solve independence

The ordinary locomotion path is physics root/facing, authored animator sampling, Prompt 6 procedural composition, pre-leg hierarchy evaluation, frozen left/right sole/hip/query inputs, left leg application, right leg application, final attachment evaluation, and the global sprite batch. During an interaction-locked tick, shared interaction sampling first recreates the authored/procedural pre-IK pose, the manager freezes both hand inputs and applies both arm solves, and then the character reapplies only already-owned foot constraints. Arm and leg order is observationally equivalent because they modify disjoint chains; both leg targets are frozen before either leg solve and both hand inputs are frozen before either arm solve. Tests run left-then-right and right-then-left from identical inputs and require equivalent sockets.

## Metrics and quality gates

For each foot the runtime exposes state, weight, query hit/collider/height, lock target, pre/post sole, target error, world slip, penetration, hover, reachability, and aggregate stable-plant maxima. Lifecycle observation stores the triggering semantic contact, candidate acquisition, full-weight plant, release start, and full release for one latest-acquired lifecycle. Its present ticks are monotonic. Repeated contacts while locked do not replace its trigger. Separate aggregate fields retain the most recent semantic contact and acquisition/full-plant/started-release/full-release counts. No generic plant tick represents multiple transitions. Stable quality is sampled only at full weight with a reachable solve:

```text
slip        = distance(post_ik_sole, locked_target)
penetration = max(locked_target.y - post_ik_sole.y, 0)
hover       = max(post_ik_sole.y - locked_target.y, 0)
```

The required absolute tolerance is `0.0002 m`. The scripted evidence route reports the uncorrected pre-IK vertical error and corrected post-IK error on the floor and raised platform, plus physics/timing equality against an IK-disabled shadow character.

## Allocation, rendering, and evidence route

Ground hits are values, bindings and plant states are inline, and solve temporaries are stack values. Ground query, plant update, binding use, IK, target storage, and hierarchy evaluation allocate zero bytes after initialization. Foot placement creates zero GPU resources, adds no pass or buffer, and submits through the existing global page-zero sprite batch.

Run the deterministic route with:

```powershell
.\.deps\zig-0.16.0\zig.exe build run -- --frames 1200 --demo foot-planting --scripted-input
```

It exits nonzero unless idle/walk contacts, alternating plants, jump clearing, airborne rejection, fresh landing plants, raised-platform adaptation, final stability, exact physics/animation agreement, one draw range, one actual indexed-instanced draw, zero hot-path allocation, and zero foot-created GPU resources are all observed.

Prompt 27 reuses this same ground-query and leg-IK authority in the production
art `foundation` route. Its deterministic matrix includes walk, short/full/
double jump, deep airborne states, landing, and a non-floor raised-platform
landing over the Prompt 26 collision-derived surface presentation. Theme,
outfit, and interaction-view changes cannot acquire or move a foot lock.
During handshakes, only already-acquired grounded constraints are reapplied
after the arm solve, exactly as in the established pipeline.
