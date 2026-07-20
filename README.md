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

The batch is the production rendering foundation, not a parallel demonstration renderer. Prompt 3 adds foundational math, immutable skeleton definitions, independent mutable poses, hierarchical sockets, render attachments, and programmatic pose manipulation. Prompt 4 adds eight immutable authored clips, typed events, deterministic sampling, component-space blending, one-shot fallbacks, and the finite `zig build run -- --frames 360 --demo animation` idle/walk demonstration. Prompt 5 adds one authoritative 240 Hz physics/animation clock, SDL keyboard/gamepad input, edge-preserving `CharacterIntent`, swept static AABB collision, gravity, variable-height jump, coyote time, jump buffering, landing reporting, render interpolation, and the interactive `zig build run -- --demo controller` mode. Its deterministic GPU-backed acceptance route is `zig build run -- --frames 600 --demo controller --scripted-input`. Prompt 6 layers contact-relative speed-scaled walk bounce, physics-impact landing compression, and acceleration-driven head lag entirely into the visual local pose; its deterministic evidence route is `zig build run -- --frames 900 --demo secondary-motion --scripted-input`. IK and interaction coordination remain in later milestones.

Start with:

- [`AGENTS.md`](AGENTS.md) for binding requirements and prohibitions.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for system boundaries and conventions.
- [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md) for exact versions, hashes, and backend policy.
- [`docs/TESTING.md`](docs/TESTING.md) for test layers and acceptance checks.
- [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) for staged implementation and the final build interface.
- [`docs/SPRITE_BATCH.md`](docs/SPRITE_BATCH.md) for exact CPU/HLSL layout, ordering, capacity, and frame-safety contracts.
- [`docs/HUMANOID.md`](docs/HUMANOID.md) for transform, hierarchy, attachment, body-proportion, and deterministic-demo contracts.
- [`docs/ANIMATION.md`](docs/ANIMATION.md) for clip, key, event, playback, blending, fallback, authored-timeline, and animation-demo contracts.
- [`docs/PHYSICS.md`](docs/PHYSICS.md) for the 240 Hz clock, controller configuration, collision, jump, landing, and allocation contracts.
- [`docs/SECONDARY_MOTION.md`](docs/SECONDARY_MOTION.md) for procedural walk, landing, spring, composition, reset, and evidence contracts.
- [`docs/CONTROLS.md`](docs/CONTROLS.md) for keyboard/gamepad controls, pending-edge semantics, pause, and deterministic scripted input.
