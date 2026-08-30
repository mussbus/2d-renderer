# Secondary Motion

This document describes Prompt 6 pose-level walk, landing, and head follow-through. Prompt 20's modular per-visual cape/hair/garment system reuses the scalar spring implementation but has separate resolved-instance ownership and is documented in `docs/ATTACHMENT_SECONDARY_MOTION.md`.

## Ownership and composition

`procedural_motion.State` is embedded per character. It owns only visual walk state, two scalar spring channels, previous horizontal velocity for acceleration sampling, event-consumption identity, bounded metrics, and the last pose-composition tick. It does not own or duplicate physics position, physics velocity, grounding, support ID, collider data, static geometry, renderer state, GPU handles, clip keys, or skeleton rest data.

Prompt 7 embeds one distinct value in every `CharacterInstance`; no pointer to shared spring state exists. The two-character demonstration advances A while B is initially settled and records A's nonzero walk offset alongside B's exact zero. Character and scene reset call the established reset policy on only the requested instance or explicitly on both.

The production order is:

```text
authoritative physics character-world transform
        -> authored animation local pose
        -> visual root walk plus landing translation
        -> head rotational secondary offset
        -> hierarchical world-pose evaluation
        -> render attachments
        -> production instanced sprite batch
```

The combined visual translation is added once to the root bone. Head lag is added once to the head bone. `composePose` rejects a second composition carrying the same simulation tick, while the next animator update replaces the mutable local transforms with a fresh authored pose. Neither offset enters `character_to_world`, so the collider and physics root remain unchanged.

## Fixed-step policy

Every procedural update uses `procedural_fixed_dt`, derived directly from `fixed_step.fixed_dt_seconds`, and compile-time checks require its `f32` value to equal `1 / 240`. The update API accepts no delta. A rendered frame with zero simulation substeps performs zero procedural updates; a frame with multiple substeps performs one update per substep. Pause freezes the channels and single-step advances them once. Render evaluation only substitutes the interpolated physics presentation root and reevaluates the already-composed pose; it does not advance or mutate springs. Procedural offsets are held at the newest fixed-tick value rather than separately interpolated.

## Reusable spring

`spring.State` stores offset, velocity, and target offset. `spring.Configuration` stores stiffness, damping, maximum displacement, and maximum velocity. Mass is one. One semi-implicit Euler tick evaluates:

```text
acceleration = -stiffness * (offset - target) - damping * velocity
velocity = clamp(velocity + acceleration * fixed_dt, -maximum_velocity, +maximum_velocity)
offset = clamp(offset + velocity * fixed_dt, -maximum_displacement, +maximum_displacement)
```

Velocity that points farther outside a newly reached displacement clamp is cleared. Configuration rejects non-finite or negative stiffness, damping, displacement limit, and velocity limit, plus non-finite or non-positive timestep. Initialization rejects non-finite or out-of-limit state. Tests cover exact rest, signed recovery, bounded impulses, 10-second convergence, a 100-second stress interval, repeat determinism, and reset replay.

## Walk weight transfer

Walk phase is normalized over the authored one-second loop. `[0.0, 0.5)` is relative to left contact and `[0.5, 1.0)` is relative to right contact. Each half-cycle samples smooth interpolation through these explicit contact-relative points:

| Relative phase | Meaning | Normalized height |
| ---: | --- | ---: |
| `0.00` | foot contact | `0.00` |
| `0.18` | slight compression | `-0.35` |
| `0.50` | body passes support | `0.00` |
| `0.76` | body rise | `+1.00` |
| `1.00` | opposite contact | `0.00` |

This is sampled position, never integrated velocity, so phase `0.0`, `0.5`, and every complete loop are exactly neutral. Tests run 1, 10, and 1,000 cycles without accumulated offset.

Horizontal speed uses magnitude, so direction cannot invert vertical bounce. Speeds at or below `0.12 m/s` produce zero amplitude. Amplitude rises linearly to the `0.040 m` maximum at `4.50 m/s` and clamps above it. The current amplitude moves toward its target at `0.24 m/s` while entering and `0.40 m/s` while leaving. The animation walk layer contributes transition weight. Physical airborne state immediately suppresses the output while the stored amplitude decays; semantic foot-contact events never change physics or create landing response.

## Landing response

Only `CharacterController.StepResult.landed` supplies a production landing event. Its impact is the downward speed measured immediately before collision resolution. Negative and non-finite inputs are rejected. Impacts at or below `1.0 m/s`, including the approximately `0.166667 m/s` resting contact, produce no visual impulse. The nominal reference is `5.25 m/s`, and input clamps at `10.0 m/s`.

For valid impact above threshold:

```text
n = clamp((impact - 1.0) / (10.0 - 1.0), 0, 1)
response = n * n * (3 - 2 * n)
impulse_magnitude = lerp(0.35, 2.0, response)
spring_velocity_impulse = -impulse_magnitude
```

Negative visual Y is compression because world positive Y is up. The landing spring uses stiffness `180 s^-2`, damping `22 s^-1`, maximum displacement `0.060 m`, and maximum velocity `2.40 m/s`. A simulation-tick identity prevents duplicate consumption. Repeated grounded ticks, animation contacts, walls, and ceilings provide no event and therefore no impulse.

The landing clip already lowers the pelvis by up to `0.23 m`. Procedural variation is therefore added at the root and the total walk-plus-landing root offset is conservatively clamped to `[-0.060, +0.045] m`. This bounds double compression without independently moving feet or claiming foot planting; later leg IK owns planted-foot correction.

## Head follow-through

The visible secondary channel rotates the head opposite measured horizontal acceleration. Each fixed tick derives:

```text
horizontal_acceleration = (current_horizontal_velocity - previous_horizontal_velocity) / fixed_dt
target_head_rotation = clamp(-horizontal_acceleration * 0.0025, -0.120, +0.120) radians
```

The head spring uses stiffness `96 s^-2`, damping `17 s^-1`, maximum displacement `0.120 rad`, and maximum velocity `2.50 rad/s`. It responds to a measurable controller velocity change rather than arbitrary oscillation and does not interfere with future arm IK.

Reset clears both springs, walk amplitude and offset, consumed landing identity, peaks, and composition identity. It synchronizes previous horizontal velocity to the reset controller velocity, preventing a false acceleration spike. Disabling procedural motion performs the same synchronization and leaves the animator-authored pose unchanged on composition.

Prompt 22 composes this character-level landing/walk/head follow-through with Prompt 20 resolved-visual cape, long-hair, and topology-expanded sleeve motion. The controller produces the shared velocity, acceleration, facing, and landing observations; each visual instance owns its bounded response. Walking, jumping, double jumping, dashing, reversing, handshake locking, and loadout replacement cannot feed a visual offset back into controller position, velocity, collision, attributes, capabilities, or interaction geometry. The authoritative reset clears both procedural layers before visual evaluation resumes.

## Allocation, determinism, and demonstration

All state and evidence storage is embedded or fixed capacity. Walk update, landing consumption, both spring updates, pose composition, and world-pose evaluation allocate zero bytes in the steady-state loop. Procedural motion imports no SDL or rendering module and creates no GPU resource.

The pure schedule test applies the identical per-tick trace under one-tick, four-tick, and mixed zero/one/multi-tick render groupings and compares all visual channels within `1e-5`. The physics-invariance test replays the same 600-frame input with procedural motion enabled and disabled; final position, velocity, grounding, support ID, and landing count must agree.

F4B2 retired the standalone secondary-motion route after its useful
fixed-tick/controller integration invariants were mapped to
`tests/secondary_motion_tests.zig`, which runs through `zig build test`.

The retired route historically staged partial/full speed, alternating contacts,
head lag, reset, physical landings, impact-scaled peaks, and recovery. Permanent
tests now assert those responses, replay determinism, controller equivalence,
and zero hot-path allocation directly.
