# SDL3 GPU 2D Skeletal Character Prototype

This repository contains the reproducible Prompt 1 build foundation for Zig 0.16.0, Windows 11 x64, SDL 3.4.10, the SDL3 GPU API with an explicit Direct3D 12 backend, and offline DXIL compilation with DXC v1.9.2602.24.

Bootstrap the exact dependencies once from PowerShell, then normal build operations are offline:

```powershell
& '.\tools\bootstrap_dependencies.ps1'
zig build
zig build test
zig build run
zig build gpu-smoke
zig build check
```

The default build compiles and validates both HLSL stages with repository-local DXC, installs `SDL3.dll` beside `skeletal_gpu_demo.exe`, and installs DXIL under `zig-out/bin/shaders`. `zig build run` launches that installed layout. The default visible demonstration submits 1,000 deterministic procedural sprites through one authoritative instanced batch and one actual GPU draw. `zig build run -- --frames 300 --demo humanoid` instead runs the deterministic 16-bone, four-socket, 15-attachment segmented humanoid through that same batch. `gpu-smoke` uses the batch for fault cleanup, presentation, two UV-selected sprites, and fenced render-target readback. It fails rather than skipping when the required graphical session, D3D12 backend, DXIL support, pipeline, or readback is unavailable.

The batch is the production rendering foundation, not a parallel demonstration renderer. Prompt 3 adds foundational math, immutable skeleton definitions, independent mutable poses, hierarchical sockets, render attachments, and programmatic pose manipulation. Prompt 4 adds eight immutable authored clips, typed events, deterministic sampling, component-space blending, one-shot fallbacks, and the finite `zig build run -- --frames 360 --demo animation` idle/walk demonstration. Prompt 5 adds one authoritative 240 Hz physics/animation clock, SDL keyboard/gamepad input, edge-preserving `CharacterIntent`, swept static AABB collision, gravity, variable-height jump, coyote time, jump buffering, landing reporting, render interpolation, and the interactive `zig build run -- --demo controller` mode. Its deterministic GPU-backed acceptance route is `zig build run -- --frames 600 --demo controller --scripted-input`. Prompt 6 layers contact-relative speed-scaled walk bounce, physics-impact landing compression, and acceleration-driven head lag entirely into the visual local pose; its deterministic evidence route is `zig build run -- --frames 900 --demo secondary-motion --scripted-input`. Prompt 7 adds stable entity IDs, independently owned character runtime state, character-local reflection, bounded semantic layer overrides, and globally interleaved two-character ordering; its evidence route is `zig build run -- --frames 720 --demo multi-character`. Prompt 8 adds the allocation-free shared paired-interaction manager and deterministic fixed-position handshake; its non-IK evidence route remains `zig build run -- --frames 720 --demo handshake --scripted-input`. Prompt 9 adds analytical two-bone arm IK, stable humanoid bindings, symmetric pre-IK midpoint constraints, deterministic timeline weighting, mirrored bend control, and perturbed-contact proof through `zig build run -- --frames 720 --demo handshake-ik --scripted-input`. Prompt 10 adds authoritative-world ground probes, anatomical per-foot world locks, immutable leg bindings, analytical visual leg IK, fixed-tick acquisition/release, and measured floor/platform quality through `zig build run -- --frames 1200 --demo foot-planting --scripted-input`. Prompt 11 composes every production path into `zig build run -- --frames 2400 --demo integrated --scripted-input`, adds bounded read-only diagnostics and milestone snapshots, and optionally appends debug primitives with `--debug-visualization` through the same one-draw sprite batch. Prompt 14 moves every sprite submission into world metres, adds a pure `Camera2D`, resizable/high-DPI swapchain rendering, deterministic dead-zone following, an extended cave playground, and three-layer parallax. Its bounded evidence route is `zig build run -- --frames 1100 --demo side-scroller --scripted-input`; the fixed 640×480 GPU readback target remains independent.

Prompt 16 adds data-defined adult anatomy modules, repeated hierarchical body parts, parametric build morphology, per-channel and per-instance overrides, independently addressable face features, short/long/ponytail hair, and topology-independent presentation profiles. Its non-sexual evidence route is `zig build run -- --frames 240 --demo modular-body`: the conventional male and female visibly select different compositional face definitions, while those presets and the articulated extra-arm/tail/horn preset share one canonical skeleton, animation library, global sprite batch, and draw path.

## Interactive playground

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo playground --interactive
```

| Control | Action |
| --- | --- |
| `A` / Left Arrow | Move left |
| `D` / Right Arrow | Move right |
| Space | Jump; hold for a higher jump or release early for a shorter jump |
| `E` | Interact |
| `R` | Reset the playground |
| `F1` | Toggle debug visualization |
| `F2` | Cycle normal, quarter-speed, and paused controller time modes where exposed |
| `F3` | Single-step a paused controller route where exposed |
| Escape | Exit |

Walk right toward the passive character and stop near the authored handshake position. Both characters must be grounded and facing one another; spacing remains deliberately strict, and pressing `E` never snaps or warps either root. The raised platforms, short/held jump behavior, foot planting, arm IK, reset, and debug overlay all use the production runtime paths.

The window can be resized without changing character scale. Walk left beyond the original view to exercise camera following and the distant, midground, and gameplay cave layers.

The bounded automated route uses synthetic raw key state through the identical keyboard mapping:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 1800 --demo playground --scripted-input
```

Start with:

- [`AGENTS.md`](AGENTS.md) for binding requirements and prohibitions.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for system boundaries and conventions.
- [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md) for exact versions, hashes, and backend policy.
- [`docs/TESTING.md`](docs/TESTING.md) for test layers and acceptance checks.
- [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) for staged implementation and the final build interface.
- [`docs/SPRITE_BATCH.md`](docs/SPRITE_BATCH.md) for exact CPU/HLSL layout, ordering, capacity, and frame-safety contracts.
- [`docs/HUMANOID.md`](docs/HUMANOID.md) for transform, hierarchy, attachment, body-proportion, and deterministic-demo contracts.
- [`docs/ANATOMY.md`](docs/ANATOMY.md) for compositional adult anatomy, multiplicity, morphology, presentation, face/hair, ownership, and alternative-rig boundaries.
- [`docs/ANIMATION.md`](docs/ANIMATION.md) for clip, key, event, playback, blending, fallback, authored-timeline, and animation-demo contracts.
- [`docs/PHYSICS.md`](docs/PHYSICS.md) for the 240 Hz clock, controller configuration, collision, jump, landing, and allocation contracts.
- [`docs/SECONDARY_MOTION.md`](docs/SECONDARY_MOTION.md) for procedural walk, landing, spring, composition, reset, and evidence contracts.
- [`docs/MULTI_CHARACTER.md`](docs/MULTI_CHARACTER.md) for entity IDs, instance ownership, facing reflection, global ordering, overrides, and two-character evidence.
- [`docs/INTERACTIONS.md`](docs/INTERACTIONS.md) for paired definitions, eligibility, shared timing, event authority, locks, overrides, cancellation, and handshake evidence.
- [`docs/IK.md`](docs/IK.md) for analytical geometry, reachability, arm binding, pose-pipeline order, shared-target ownership, weighting, and quantitative evidence.
- [`docs/FOOT_PLANTING.md`](docs/FOOT_PLANTING.md) for ground-query inclusion rules, anatomical leg bindings, fixed-tick plant/release semantics, visual-only ownership, and quantitative slip/contact evidence.
- [`docs/DIAGNOSTICS.md`](docs/DIAGNOSTICS.md) for the integrated fixed-tick order, bounded observer model, debug-command capacity, reset policy, invariance, and resource accounting.
- [`docs/CONTROLS.md`](docs/CONTROLS.md) for keyboard/gamepad controls, pending-edge semantics, pause, and deterministic scripted input.
