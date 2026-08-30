# Modular attachment secondary motion

## Boundary and ownership

Prompt 20 adds `attachment_secondary_motion`, a CPU-only fixed-step primitive for small visual control-point groups. It is not cloth, rope, soft-body, fluid, collision, or self-collision simulation. It cannot write the character controller, physics root, collider, grounding/support state, canonical skeleton, IK target, interaction clock, loadout effects, camera, draw order, or GPU resources.

An immutable `attachment_secondary_motion.Definition` contains:

- one to four cumulative local rest offsets from a fixed resolved anchor;
- the existing scalar spring configuration reused independently for local X and Y;
- optional gravity/sag displacement;
- acceleration and sustained-velocity response;
- bounded predecessor follow for chain-like propagation;
- landing-impulse response;
- output translation and rotation bounds.

Mutable `RuntimeState` contains the resolved anchor, previous authoritative velocity sample, facing, fixed tick/reset counters, and fixed-capacity point springs. State is embedded in the resolved consumer:

- every `appearance.VisualRuntimeState` owns its own state for definition-authored hair or another anatomy visual;
- every `equipment.ResolvedVisualInstance` owns its own state for an equipment component.

Hair, equipment, mesh, anatomy, and shared motion definitions contain no mutable nodes. Repeated sleeves using one component definition and two characters using one cape definition therefore own distinct state values. The definition or component ID is never used as mutable-state storage.

## Fixed-step update

The primitive accepts no caller delta. It uses the authoritative `1 / 240` second timestep and rejects definitions whose stiffness or damping step exceeds the documented semi-implicit stability envelope. Every input and state component must be finite.

For each point, world velocity and acceleration are converted once into character-local coordinates. The target is:

```text
drive = gravity
      - local_acceleration * acceleration_response
      - local_velocity * velocity_response

point_target = drive * normalized_point_index
             + previous_point_displacement * chain_follow
```

Each target is magnitude-clamped, then the existing `spring.State` advances local X and Y. The resulting displacement and velocity vectors are magnitude-clamped again. A landing event adds one bounded local velocity impulse before the spring step. The fixed anchor itself never becomes dynamic.

The final point produces one bounded local translation and the clamped angular difference between its rest and displaced directions. That transform is the deformation input consumed by the visual. The cape mesh uses vertex deformation weights of zero at its clasp edge, intermediate values through the body, and one at its free hem, so the shared local deformation leaves the attachment edge fixed while moving the loose region.

## Consumers

The modular appearance definition opts long hair and ponytail visuals into the primitive. Short hair has no motion definition and remains rigid. The mesh-equipment definition opts the cape into a three-point configuration and the topology-expanded flexible sleeves into a smaller two-point configuration. No consumer has a separate physics engine.

Horizontal acceleration, sustained velocity, reversal, and stopping drive the local X target. Vertical velocity/acceleration drive jump and fall response. The authoritative physical landing event supplies the one landing impulse. Gravity displacement supplies optional settled sag. All inputs are copied from character state; no result feeds back.

## Lifecycle and facing

An equip transaction expands a fresh `ResolvedVisualInstance`, whose motion state is uninitialized and therefore resolves to identity. Its first fixed update captures the current anchor, facing, and velocity and remains exactly at rest, preventing an equip spike. Unequip and rebind explicitly clear active motion and mesh state before the bounded derived arrays are rebuilt. Re-equip therefore starts from the same defined rest state with no stale node or handle.

Hidden appearance visuals clear their state during appearance evaluation. Selecting long hair or a ponytail starts that visual from rest; selecting rigid short hair leaves no active spring entry.

Facing uses one root reflection. Motion input converts world X to character-local X before stepping, and the existing root reflection converts the resulting local deformation back to world space. A facing change explicitly clears affected appearance and equipment state. The next fixed tick captures the new facing at exact rest. This reset policy avoids a second mirror, stale signed displacement, a synthetic acceleration spike, and non-finite or extreme output.

## Composition order

The resolved visual order is:

1. authoritative controller/root motion;
2. authored skeleton animation;
3. walk, landing, and head-lag procedural pose;
4. interaction and arm/leg IK;
5. attachment/anatomy binding from the final pose;
6. Prompt 16 morphology;
7. Prompt 18 breathing response;
8. Prompt 19 weighted mesh deformation data;
9. Prompt 20 attachment secondary transform;
10. the one character-facing reflection already present in the resolved binding;
11. camera/parallax presentation;
12. unified semantic sorting, upload, and rendering.

For equipment meshes, morphology/breathing and attachment motion are combined as finite local deformation components before the existing weighted mesh shader. The binding matrix still contains animation, IK, anatomy attachment, world root, and facing. Camera/parallax remains GPU presentation state and never enters a spring.

## Capacity, reset, and evidence

All point arrays are embedded and fixed capacity. A steady-state update performs no allocation, string lookup, topology upload, or GPU creation. Reset is deterministic and retains no displacement, velocity, target, or previous-facing sample. Long-run tests require finite bounded state and convergence after 24,000 ticks.

Headless coverage is in `tests/attachment_secondary_motion_tests.zig`. It covers definition validation, exact rest, acceleration, sustained motion, reversal, sudden stop, jump, fall, landing, facing reset, explicit reset replay, extreme valid parameters, long-run convergence, shared definitions with independent instances, two characters, equip/unequip/re-equip, hair ownership, grouped mesh rendering, controller/physics invariance, interaction invariance, and fixed-buffer stability.

F4B2 retired the duplicate `attachment-secondary` route alias after its useful
invariants were mapped to `tests/attachment_secondary_motion_tests.zig` and the
retained `mesh-attachments` route.

Permanent tests retain cape, long-hair, ponytail, repeated flexible-sleeve,
lifecycle, facing-reset, authority, and grouped-rendering behavior. The
surviving `mesh-attachments` route continues to exercise the real unified
sprite/mesh GPU path.

## Prompt 22 focused integrated motion

The retained `foundation_playground.Scene` player and showcase use the same
resolved-instance primitive while walking, jumping, double jumping, dashing,
reversing, landing, interacting, changing body/hair, and rebuilding loadouts.
The cape and every topology-expanded loose sleeve keep independent
fixed-capacity state; long hair remains owned by the selected appearance
visual. A loadout rebuild clears removed nodes before new topology expansion,
and exact reset clears every visual node and mesh instance handle before
restored visuals resume.

The bounded route records nonzero cape displacement, two conventional sleeve bindings, four nonstandard sleeve bindings, exact loadout restoration, unchanged handshake roots, and zero fixed-buffer, unified-queue, or GPU-resource growth. It does not add cloth collision, self-collision, wind, rope, soft-body, or authoritative physics.

Prompt 27 exercises the same primitive on the production female long hair and
long-garment wardrobe while moving, jumping, changing outfits, and completing
three handshakes. Interaction view ownership may change the downstream
presentation transform, but it cannot write spring anchors, targets, or
authoritative contact geometry. All recorded secondary state remains finite,
outfit replacement clears removed garment state, and the integrated route
reports zero steady-state update/submission/queue allocation growth.
