# Fixed-Step Character Controller

## Authoritative clock

Gameplay physics and gameplay animation share one clock at exactly 240 Hz: `fixed_dt = 1 / 240` second. The accumulator, raw frame delta, clamped delta, discarded time, and interpolation alpha use `f64`; controller integration uses validated `f32` configuration values.

- Maximum accepted real-frame delta: `0.10 s`.
- Maximum fixed ticks per rendered frame: `8`.
- Negative real delta: sanitized to zero.
- Non-finite real delta: rejected.
- Excess policy: execute at most eight whole ticks, discard all remaining whole accumulated ticks, retain only the fractional remainder, and report both per-frame and lifetime discarded seconds.
- Pause: accumulate no real time and execute no tick. `F3` may request exactly one tick. Pause transitions clear stale pending edges.
- Rendering: interpolate previous/current physics position with bounded `alpha = accumulator / fixed_dt`; interpolation never writes to physics or advances animation.

The per-tick order is pending-edge consumption, `CharacterIntent`, horizontal controller integration, gravity and jump policy, horizontal sweep/resolve, vertical sweep/resolve, ground and landing classification, physics-driven animation selection, one animator update at `1/240 s`, one procedural-motion update and local-pose composition, and world-pose evaluation. A render evaluation may replace only the character-to-world presentation transform with an interpolated value. Rendering never advances a spring.

The controller captures landing impact as the positive magnitude of downward velocity immediately before vertical collision resolution zeros that velocity. A `StepResult` landing event is the only production input to visual landing compression. Animation contact events, post-resolution velocity, floor distance, and rendered movement cannot create a physical landing or a visual landing impulse. Procedural motion receives the event after controller state is authoritative and cannot write position, velocity, grounding, support ID, collider dimensions, or static geometry.

## Configuration

| Value | Setting | Unit |
| --- | ---: | --- |
| Gravity | `-28.0` | m/s² |
| Ground acceleration | `36.0` | m/s² |
| Air acceleration | `18.0` | m/s² |
| Ground deceleration | `44.0` | m/s² |
| Maximum run speed | `4.5` | m/s |
| Jump speed | `9.0` | m/s |
| Jump-release speed | `3.5` | m/s |
| Coyote duration | `0.10` (`24` ticks) | s |
| Jump-buffer duration | `0.125` (`30` ticks) | s |
| Maximum fall speed | `18.0` | m/s |
| Collider half extents | `(0.30, 1.05)` | m |
| Ground/contact epsilon | `0.0001` | m |
| Landing threshold | `0.25` | m/s |
| Facing threshold | `0.20` | normalized intent |

Jump release clamps positive rising velocity to `3.5 m/s`; it has no effect after the apex. Landing impact is stored as the positive magnitude of downward velocity captured before vertical collision clears it. A landing event requires an airborne-to-ground transition and impact strictly above `0.25 m/s`.

Animation priority is physical jump, physical landing, protected one-shot playback/fallback, airborne rising/falling, then grounded idle/walk. A buffered jump accepted on its landing tick selects jump-start so the newly accepted physical jump is not visually overwritten by landing. Animation foot-contact events never affect collision, grounding, root position, or landing events.

## Collision world

The authoritative character collider is a stable AABB independent of animated limbs and pose offsets. The world owns one contiguous bounded array of five immutable static AABBs: floor, right wall, ceiling/overhang, raised platform 1, and raised platform 2. IDs remain stable for the world's lifetime and the same records drive controller collision, support queries, and visible collider geometry.

Movement resolves with axis-separated continuous sweeps: horizontal first, then vertical, then ground classification. Each sweep checks whether the moving leading edge crosses the nearest eligible static face, so collision does not depend on end-position overlap and cannot tunnel at configured maximum speed. Only a downward vertical hit produces normal `(0, +1)`, grounded state, and a supporting collider ID. Wall and ceiling hits never count as ground. Platforms are solid from all directions: upward motion hits an underside rather than snapping onto its top, and downward motion lands on the top.

Externally supplied initial penetration is rejected. Runtime validation tolerates contact-rounding overlap no deeper than the configured epsilon and rejects deeper unsupported penetration. There is no iterative push-out or hidden teleport.

## Ownership and allocation

The collision array is allocated once and freed explicitly. The fixed clock, snapshots, pending intent, controller, sweeps, animation selection, animator update, interpolation, and collision queries allocate nothing after initialization. Controller initialization fault injection covers the collider allocation and partial controller-demo acquisition; each injected failure is followed by a successful clean initialization.
