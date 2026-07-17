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

The default build compiles and validates both HLSL stages with repository-local DXC, installs `SDL3.dll` beside `skeletal_gpu_demo.exe`, and installs DXIL under `zig-out/bin/shaders`. `zig build run` launches that installed layout. The visible demonstration submits 1,000 deterministic procedural sprites through one authoritative instanced batch and one actual GPU draw. `gpu-smoke` uses that same batch for fault cleanup, presentation, two UV-selected sprites, and fenced render-target readback. It fails rather than skipping when the required graphical session, D3D12 backend, DXIL support, pipeline, or readback is unavailable.

The batch is the production rendering foundation, not a parallel demonstration renderer. The complete skeletal-character systems remain in later milestones.

Start with:

- [`AGENTS.md`](AGENTS.md) for binding requirements and prohibitions.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for system boundaries and conventions.
- [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md) for exact versions, hashes, and backend policy.
- [`docs/TESTING.md`](docs/TESTING.md) for test layers and acceptance checks.
- [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) for staged implementation and the final build interface.
- [`docs/SPRITE_BATCH.md`](docs/SPRITE_BATCH.md) for exact CPU/HLSL layout, ordering, capacity, and frame-safety contracts.
