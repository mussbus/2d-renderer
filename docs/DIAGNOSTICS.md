# Integrated diagnostics and debug visualization

Prompt 11 composes the existing controller, animation, procedural-motion, interaction, arm-IK, foot-planting, leg-IK, global-ordering, and SDL GPU sprite paths. The integration layer orchestrates deterministic input and scene setup; it does not own an alternative implementation of any subsystem.

## Observer ownership

`diagnostics.capture` accepts only constant character, fixed-clock, and interaction-manager views. A snapshot copies bounded scalar values: IDs, enum states, counters, ticks, vectors, optional collider/target values, and owned resource counts. It does not retain pointers and is never read by a simulation update. Repeated capture neither acknowledges nor clears animator, landing, interaction, or foot-contact events.

The current history capacity is 32 snapshots. Storage is inline. Once full, a push overwrites the oldest entry, advances the ring start, and increments `overwrite_count`. Ten named milestone snapshots use a second fixed optional array. Neither path allocates after initialization or serializes a scene.

Foot telemetry exposes one coherent latest-acquired lifecycle record: the semantic contact that created its pending intent, candidate acquisition, full-weight plant, release start, and full release. Repeated semantic contacts while that foot is already locked increment aggregate contact metrics but do not rewrite the lifecycle's triggering contact. Acquisition/full-plant/release/full-release counts and the separate most-recent semantic-contact metric remain independent. A locked target and collider remain the foot system's state; diagnostics only copy them.

Scene reset clears current history, overwrite count, milestone snapshots, and the latest snapshot. Resource counters supplied by the renderer remain owned by the renderer. Stress-cycle restart also clears observer storage while preserving the external fixed-tick total and interaction ID/metrics sequence.

## Fixed-tick production order

The integrated route executes this order on every authoritative tick:

1. Derive deterministic scripted raw input from the current phase.
2. Convert raw input through `SnapshotBuilder`, `PendingInput`, and `CharacterIntent`.
3. Advance the controlled character's controller and collision state.
4. Produce jump/landing physics results.
5. Select the controlled character's animation state when it is not interaction-locked.
6. Advance ordinary animator playback.
7. Consume the landing result once and advance procedural walk, landing, and head springs.
8. Compose procedural local-pose offsets and evaluate the pre-IK hierarchy.
9. Freeze both anatomical foot inputs, query the authoritative ground world, update plant state, solve both legs, and evaluate the resulting hierarchy.
10. Process a real `interact_pressed` request after ordinary locomotion state is current.
11. Advance the one shared interaction clock and sample both interaction poses.
12. Compute one hand target from both pre-arm-IK socket positions.
13. Apply both analytical arm solves.
14. Reapply only already-acquired grounded foot constraints through the ordinary foot/leg system; no interaction tick can create a new foot lock.
15. Observe milestones and copy optional diagnostics after all authoritative updates.
16. On the render frame, globally submit both characters and environment sprites, then append optional debug sprites before the existing batch sort and draw.

Steps 6–9 are skipped for an interaction-locked character because shared interaction sampling owns that tick's animator pose. Steps 11–14 do nothing when no interaction is active. These branches prevent two animator clocks and prevent post-IK values from feeding the next authoritative target. Rendering and diagnostics never feed back into the tick.

During an interaction-locked tick, step 13 applies the arm constraint before step 14 reapplies already-owned leg constraints. The chains are disjoint, both hand inputs were frozen before either arm solve, and the foot target was acquired on an earlier ordinary locomotion tick. Final hierarchy evaluation therefore contains both constraints without either solver reading the other's post-IK endpoint.

## Integrated route

The `integrated` scripted demo uses two humanoids and one real controller. Its phase IDs are `initial_idle`, `walk_floor`, `jump`, `airborne`, `landing`, `walk_platform`, `approach_interaction`, `handshake`, `post_interaction`, and `final_idle`. Transitions use fixed ticks, controller milestones, plant state, ground collider IDs, or interaction lifecycle state. Every transition validates phase-specific entry and exit conditions.

The route walks and alternates plants on the floor, jumps, proves both locks clear in air, consumes the landing event once, replants, jumps onto the `1.15 m` platform, records an actual raised-ground plant, returns to the floor, approaches the second character through controller input, issues one real interaction press, completes the shared handshake and IK timeline, observes cleanup, and settles into a finite grounded final state. Missing mandatory milestones cause a nonzero exit.

Milestones are stored by `Milestone` enum identity, not sorted by time. Output prints one name/tick pair per milestone and validates the dependency graph. In particular, `left_foot_planted` may precede `walk_started`: foot acquisition is allowed during the idle-to-walk blend, while `walk_started` records completion of that transition into the full walk state. This is not a prerequisite violation. Jump, airborne release, landing, replant, platform sample, request/start, contact, arm satisfaction, release, completion, cleanup, and final stability are explicitly checked in prerequisite order.

## Debug commands and draw accounting

The optional command is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 2400 --demo integrated --scripted-input --debug-visualization
```

`debug_draw.CommandBuffer` contains 512 inline sprite requests. Overflow increments `overflow_count` and returns `error.DebugCommandCapacityExceeded`; it never grows. Lines, markers, and AABB edges visualize physics/visual roots, collider bounds, ground queries/hits, locked foot targets, pre/post-leg-IK movement, arm segments, the shared hand target, the participant link, and Prompt 25C semantic visual geometry. Debug submission creates no GPU object and uses texture page zero in the authoritative global sprite batch.

Because ordinary and debug sprites are compatible, the Prompt 11
`integrated` route retains one texture range and one actual
indexed-instanced draw. Accounting reports ordinary sprite count and debug
primitive count separately, with `debug_draw_calls = 0`,
`sprite_draw_calls = 1`, and total actual draws equal to one. If compatibility
changes later, those counters must expose the additional range/draw rather
than folding it into the sprite count.

## Invariance and resource gates

Deterministic tests compare authoritative results with debug visualization off/on and with diagnostics unread/read every tick. They compare phase and interaction event ticks, controller state, animator state/time, foot lifecycle ticks and targets, the shared hand target, final locks, override/constraint counts, interaction ID use, and allocation totals.

The renderer reports only resources it owns: two textures, five GPU buffers, two pipelines (fixed readback and swapchain format), one sampler, two shaders, and three upload transfer buffers after initialization. Fence acquisition/release and lifetime creation totals remain separate renderer metrics. The integrated route records initial/final CPU fixed-buffer usage, the live tracked GPU-resource count, and creations during the run; it rejects growth during ordinary frames. CPU timings are not an acceptance gate. Headless stress executes 100,000 fixed ticks, repeatedly completing and resetting the integrated route while checking finite controller, spring, and foot states plus interaction/override cleanup.

## Prompt 27 integrated diagnostics

The current visible `--demo foundation` route is a separate production
composition from the historical Prompt 11 `integrated` route. Its
`visual_foundation.Scene` records fixed-capacity evidence for:

- body, build, hair, outfit, view, and theme changes;
- movement, short/full/double jump, dash, raised-platform landing, and camera
  parallax;
- six collision-derived white standable segments;
- three fixed-root handshakes with role views, preset/theme IDs,
  start/contact/release/complete ticks, pre/post-IK socket separation,
  projected hand separation, ordering proof, and root invariance;
- interaction view/override/IK cleanup, exact reset, and final front
  presentation;
- peak sprites, meshes, ranges, draws, upload bytes, fixed-buffer use, queue
  allocation, decoded-page ownership, and GPU-resource delta.

The original 2,100-frame D3D12 route, nine scheduled captures, and timing
records remain unchanged under `zig-out/p27_visual_foundation` as historical
Prompt 27 evidence. Prompt 27A writes 16 separate state-conditioned captures
and per-capture JSON under `zig-out/p27a_evidence/candidate`. Its fixed-tick
tracker requires the named controller/presentation/interaction state, rejects
early frames, and reports the actual state on timeout.

Capture 15 requires all five submitted diagnostic categories: collider, root,
ground query/target, interaction IK, and participant link. The current
production observation records 32, 4, 8, 7, and 1 primitives respectively.
The evidence-window HUD is a bounded read-only submission through the global
queue; it has no SDL polling or control authority. Clean capture files exclude
the HUD, while the detailed-debug capture includes production debug
primitives.

The Prompt 27A route retains initialized and final fixed-buffer usage of
131,216 bytes and reports zero update, submission, queue-allocation, and GPU
resource deltas. Its larger preinitialized sprite capacity accommodates the
same-queue HUD without runtime growth.

`F1` still appends detailed collider/debug evidence through the one global
queue. Persistent white standable tops are ordinary product presentation,
while cyan/orange collider outlines remain optional diagnostics. Debug
observation does not become collision, interaction, or renderer authority.
