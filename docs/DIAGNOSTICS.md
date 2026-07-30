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

`debug_draw.CommandBuffer` contains 2,048 fixed sprite requests. VF-01
measured the production All Diagnostics path exceeding the former 512-entry
capacity at command 513, so the fixed capacity was increased and moved to
explicit initialization-time diagnostic ownership. Overflow increments
`overflow_count` and returns `error.DebugCommandCapacityExceeded`; it never
grows or truncates. Lines, markers, and AABB edges visualize physics/visual
roots, collider bounds, ground queries/hits, locked foot targets,
pre/post-leg-IK movement, arm segments, the shared hand target, the
participant link, and semantic visual geometry. Debug submission creates no
GPU object and uses texture page zero in the authoritative global sprite
batch.

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

Prompt 27B keeps the same observation/capture authority and adds a separate
fail-closed semantic coherence report. Detailed debug can append
surface/collider, alpha-derived sole endpoints, camera-safe bounds, actual
far/mid/gameplay parallax anchors, and first-post-abrupt-resize character
bounds through the existing queue. Clean captures are prepared before these
markers. The independent D3D12 review parses marker pixels rather than
trusting semantic metadata and reports 55 passing pixel metrics; the headless
report records 9,714 passing semantic metrics. Both routes retain the
131,216-byte initialized/final fixed-buffer value and zero steady-state
allocation/resource delta.

## VF-01 visual truth debugger

F1 cycles `off`, `rig`, `rig_registration`, and `all_diagnostics`. All modes
append through the one `UnifiedRenderQueue` and use the production camera,
character presenter, atlas metadata, and submitted `SpriteRequest`/mesh trace.
They cannot write controller, collider, pose, view selection, interaction,
camera, or appearance state.

The stable categories are:

| Category | Color |
|---|---|
| Physics root and movement collider | red |
| Canonical skeleton | yellow |
| Projected presentation skeleton | cyan |
| Sockets, attachment points, and component links | green |
| Rig-module joints and sockets | purple |
| Final component/sprite pivots | orange |
| Atlas landmarks | white |
| Alpha-visible bounds | blue |
| Clothing/hair anchors and passing registration links | teal |
| Missing/invalid/failed registration | magenta |

Rig mode shows authoritative roots/colliders, canonical bones/joints,
canonical sockets, appearance/anatomy attachments, module joints/sockets, and
available hierarchy links. Rig + Visual Registration adds the exact
front/side projection used by `character_art.submitTraced`, final pivots,
alpha-visible bounds, transformed atlas landmarks, and expected-to-visible
registration lines. All Diagnostics adds the retained static colliders,
ground/foot/IK/interaction diagnostics, camera-safe bounds, Prompt 27B rulers,
and character-presence evidence.

One initialization-owned `visual_truth.Snapshot` freezes the exact production
objects and trace records used for a rendered frame. The overlay and JSON use
that same snapshot; no parallel placement formula is permitted.
`character_art.Presentation.projectionFor` is shared by production submission
and snapshot capture.

F4 first captures the already-prepared clean queue through the production
D3D12 offscreen target/readback. It then appends All Diagnostics to the same
frozen snapshot and reads back `debug.png`. There is no fixed tick, animation
step, camera update, interaction update, or appearance mutation between the
images. Render frame, simulation tick, live authoritative fingerprint,
snapshot authoritative fingerprint, presentation fingerprint, and capture
fingerprint must all compare equal before finalization.

Each finalized bundle contains `clean.png`, `debug.png`, `state.json`,
`summary.txt`, and `manifest.json`. State schema version 3 records provenance,
controller/collider data, canonical and projected transforms,
appearance/anatomy/module hierarchy, actual final visual submissions,
alpha-visible geometry, orientation-axis evidence, submission visibility,
closed-footwear coverage ownership, and registration mismatches. The summary is
severity-sorted and explicitly leaves manual acceptance pending. The manifest
records byte sizes and SHA-256 values for the four non-self-referential files,
the common state identity, frame/tick equality, and all source-atlas hashes;
the manifest identifies its own hash as not applicable because a self-hash is
self-referential.

Normal F1 execution performs no image decode, persistent GPU creation, file
I/O, or per-frame allocation. Snapshot, alpha catalog, debug buffer, and
readback transfer resources are created before stabilization. The explicit
F4 event may use bounded process/file/hash allocations outside the fixed-tick
path. Persistent white standable tops remain ordinary presentation; debug
observation never becomes collision, interaction, or renderer authority.

## VF-02 registration classification

Rig + Visual Registration and All Diagnostics now use the production trace's
registration evidence for migrated components. Each final visual exported by
F4 states `authoritative_registration`, `compatibility_adapter`, or
`transitional_legacy`.

Authoritative entries also export binding mode, registration identity, scale
policy, mirroring policy, structural threshold, and maximum residual. The
expected-to-transformed overlay line is built from the same evidence points
that produced the final request. Compatibility and transitional visuals keep
the prior alpha-landmark measurement path so their disagreements remain
visible.

Front anatomy feet and equipped shoes export authoritative `point_axis`
bindings. Their exported request is the production request: the alpha-derived
ankle is the sole positional target and `sole_back -> sole_front` is the
orientation constraint. The front support target is horizontal in view space;
the retained physical 16/13-degree toe-out policy supplies its semantic
left/right lateral sign without mapping depth into world Y. The shoe consumes
the exact registered anatomy-foot `PointAxisTarget` and transverse scale.
Heel/toe/sole landmarks remain exported transformed evidence, not additional
registration points.

Schema version 3 also states whether a trace record was rendered or
`suppressed_by_closed_footwear`, its base-visual policy, the covering owner,
and the exposed anatomy anchor. A suppressed base foot has no queue
submission index but retains registration and landmark evidence for F1 and
JSON. This makes pixel ownership explicit rather than hiding the underlying
anatomy record.
