# Analytical Arm IK

## Solver contract

`src/animation/two_bone_ik.zig` is a stateless analytical solver. It accepts only a root point, two positive segment lengths, a target, a configured bend side, and a finite reference direction used at the zero-distance singularity. It has no entity, interaction, animation, SDL, camera, sprite, or GPU dependency.

The solve plane is any right-handed Cartesian 2D plane supplied by the caller: +X points right, +Y points up, angles are radians, and counterclockwise rotation is positive. Units are physical caller units; the humanoid binding uses metres. The solver uses triangle geometry and the law of cosines for both root and middle angles. Both cosine inputs are clamped to `[-1,+1]` before `acos`.

For upper length `L1` and lower length `L2`, geometric reach is `abs(L1-L2)..L1+L2`. The numerical solve interval is inset by the documented `0.00001 m` reach epsilon. A request below `abs(L1-L2)+epsilon` is classified `clamped_near`; a request above `L1+L2-epsilon` is `clamped_far`; all others are `reachable`. The effective target is clamped along the requested direction. Both segment lengths remain invariant and stretching is not supported. Zero or negative segments, segments shorter than the reach epsilon, non-finite values, and a zero reference direction are rejected. A target at the root is handled safely with the configured reference direction and receives `clamped_near`; no accepted input produces a non-finite result.

`Bend.positive` places the middle joint on the counterclockwise side of the root-to-target direction; `Bend.negative` selects the reflected solution. The configured sign is never inferred from a numerically positive angle. It therefore remains stable at near-extension and across moving targets.

## Humanoid binding and spaces

`src/animation/arm_ik.zig` binds stable validated indices for the right upper arm, right forearm, right hand, and right-hand socket. Initialization verifies the exact parent chain and socket parent. It derives the immutable upper vector from the forearm rest translation and the immutable effective lower vector from the hand rest transform composed with the hand-socket rest transform. No runtime debug-name search occurs.

The current humanoid right-arm values are:

- Upper arm: `0.650000 m`.
- Forearm plus hand-socket effective segment: `0.800000 m`.
- Geometric reach: `0.150000..1.450000 m`.
- Numerical solve reach: `0.150010..1.449990 m`.

The generic solver runs in world metres. The arm adapter converts solved world directions into parent-local rotations with the inverse of the evaluated parent basis. Character-local pose uses +X toward the character's authored right-facing direction and +Y up. Character world applies translation plus an X sign of `+1` when facing right and `-1` when facing left; the same sign converts world X back to character-local X. The solve never enters render-pixel or camera space. Reflection changes the world bend sign while preserving the anatomical right-arm indices: right-facing uses the configured positive bend and left-facing uses its negative reflection.

## Pose pipeline and shared target

The fixed-tick visual pipeline is:

1. Read the authoritative physics root without modifying it.
2. Sample each authored role animation into its mutable local pose.
3. Compose existing procedural visual motion.
4. Evaluate both complete pre-IK hierarchies.
5. Read both pre-IK right-hand sockets and compute one symmetric world target as their midpoint.
6. Freeze that target for the tick.
7. Solve role A and role B independently toward the frozen target.
8. Blend authored shoulder and elbow rotations toward solved local rotations with shortest-angle interpolation.
9. Reevaluate final hierarchies, extract sockets, and submit every body-part sprite through the existing global batch.

The interaction instance recomputes the midpoint every active fixed tick from both newly sampled pre-IK poses. Neither role reads the other's post-IK hand. Solving A then B or B then A is equivalent because target computation precedes both solves. Each active instance owns its target and current pair metrics; there is no global contact target. Completion, cancellation, participant reset, and scene reset clear the instance target, weight, and per-character applied-pose record. The authored pre-IK rotations are restored before ordinary subsequent sampling, so no residual IK transform survives.

## Weight and authority

The interaction's one elapsed-tick counter owns the coordinated weight. From start through contact tick 144, weight rises linearly from `0` to `1`. It remains `1` through release tick 288, then falls linearly to `0` at completion tick 360. Thus the fixed evidence points are start `0`, blend midpoint `0.5`, contact `1`, release `1`, release midpoint `0.5`, and complete `0`. Zero-substep render frames do not advance elapsed ticks, render interpolation does not mutate the value, and enabling IK cannot change lifecycle event ticks.

## Metrics, allocation, and rendering

Each bounded role measurement reports weight, reachability, target, pre/post hand positions, target error, shoulder, elbow, configured and solved segment lengths, and bend sign. The paired measurement adds the shared target, both pre/post errors, and pre/post hand separation. These values support debug overlays without changing solve state; the deterministic demo logs only milestone samples rather than every tick.

Solver results are stack values. Bindings live inline on character instances; interaction targets and pair measurements live inline in the four preallocated interaction slots. Solve, binding lookup, target computation, rotation application, and hierarchy reevaluation allocate zero memory after initialization. IK creates zero GPU resources and adds no pass, pipeline, buffer, texture page, range, or draw call.

## Deterministic evidence

Run `zig build run -- --frames 720 --demo handshake-ik --scripted-input`.

- Nominal `3.720000 m` spacing preserves the Prompt 8 pre-IK baseline `0.000464 m`, then reduces separation to approximately `0.00000018 m`; each target error is approximately `0.00000072 m`.
- Perturbed legal `3.740000 m` spacing starts at `0.019536 m` and ends at approximately `0.00000057 m`, a `99.997%` reduction without root movement.
- The mirrored run has the same pre/post separation within `0.00000001 m`, with world bend signs reversed while anatomical right-arm indices remain unchanged.
- Nominal start/contact/release/complete ticks are `121/265/409/481`; mirrored ticks are `841/985/1129/1201`; perturbed ticks are `1561/1705/1849/1921`.
- Two characters still submit 30 page-zero sprites through one compatible draw range and one actual indexed-instanced draw. IK creates zero GPU resources and all five IK allocation counters remain zero.
