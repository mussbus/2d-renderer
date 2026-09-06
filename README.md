# SDL3 GPU 2D Engine

This repository is a Windows-first 2D engine and reference sandbox built with
Zig 0.16.0, SDL3, HLSL, and SDL's Direct3D 12 GPU backend. It combines a
deterministic CPU simulation with GPU-instanced sprite and deformable-mesh
rendering. The production engine is reusable independently of the sandbox that
hosts the larger character, interaction, environment, and visual-acceptance
scenarios.

## Engine Lab

Engine Lab is an independent integration application with a production-backed
Overview and a repeatable Fixed-Step Lab. Build/run with
`zig build run-engine-lab -j1`; test with `zig build test-engine-lab -j1`.
See the [EL1 implementation and review guide](docs/implementation/engine_lab_el1.md)
for controls, deterministic checkpoints, ownership and validation evidence.

## Architecture at a glance

- `src/foundation` owns stable identity, deterministic primitives, canonical
  data helpers, references, transforms, and shared diagnostics.
- `src/scene_core` owns authored scene schemas and the generic `RuntimeScene`,
  including entity registry, hierarchy, lifecycle, extensions, snapshots, and
  transactional publication.
- `src/animation`, `src/physics`, `src/interaction`, and specialized modules in
  `src/scene` consume those contracts without becoming generic scene authority.
- `src/graphics/sdl_gpu_renderer.zig` owns SDL GPU resources, submission,
  capture, and cleanup behind the production `Renderer` handle.
- `src/app/engine_smoke.zig` is an independent physical renderer/scene client.
- `src/app/demo_application.zig` is the interactive engine sandbox and scenario
  client; it does not own renderer or reusable scene-system implementation.
- `build/` owns modular application, engine-test, content-test, evidence, and
  aggregate-gate registration. `build.zig` remains the readable composition
  root.

The supported dependency direction is:

```text
authored definitions / canonical assets
                 ↓
      foundation + scene_core
                 ↓
 specialized deterministic runtime systems
                 ↓
     render-facing data and queues
                 ↓
       SDL3 production renderer
                 ↓
       application clients / tools
```

Production code does not depend on sandbox scenarios, acceptance evidence, or
historical development records.

## Build and run

Bootstrap the pinned dependencies as documented in
[`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md), then use the repository-local
compiler:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build -j1
& '.\.deps\zig-0.16.0\zig.exe' build run -j1 -- --demo sprites --frames 120
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-smoke -j1
```

The installed applications are:

- `zig-out/bin/engine_sandbox.exe`: interactive/scripted sandbox scenarios;
- `zig-out/bin/engine_smoke.exe`: independent `RuntimeScene` and physical
  renderer composition proof.

The renderer requires the physical Direct3D 12/DXIL path. It fails closed when
device, shader, pipeline, draw, readback, or resource-cleanup validation fails.

## Validation gates

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build check -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-full -j1
& '.\.deps\zig-0.16.0\zig.exe' build test-content -j1
& '.\.deps\zig-0.16.0\zig.exe' build verify -j1
& '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1
```

- `check` is the routine static and fast engine-contract gate.
- `test-full` adds deterministic CPU integration and stress coverage.
- `test-content` qualifies current canonical and authored content authority.
- `verify` composes the CPU/static/content gates without requiring a GPU.
- `gpu-smoke` runs the production renderer directly through `engine_smoke`.
- `visual-acceptance` and `evidence-history` remain explicit, non-routine
  manual/historical routes.

See [`docs/TESTING.md`](docs/TESTING.md) for focused targets and change-based
gate guidance.

## Assets and authority

[`assets/manifest.json`](assets/manifest.json) is the machine-readable index of
active runtime atlases, installed paths, dimensions, hashes, consumers, source
authority, and protected predecessor mappings. Current canonical-model and
geometry authority remains under `assets/canonical_model`; current qualification
is protected by `test-content`.

Historical/rejected art and protected canonical-geometry lineage are classified
in [`assets/history/manifest.json`](assets/history/manifest.json). Prompt-era
names retained there identify accepted lineage, not current production naming.

## Current documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): production architecture and
  responsibility boundaries;
- [`docs/architecture/shared_engine_scene_foundation_architecture_v1.md`](docs/architecture/shared_engine_scene_foundation_architecture_v1.md): accepted
  shared scene/foundation contract;
- [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md): exact toolchain/dependencies;
- [`docs/TESTING.md`](docs/TESTING.md): test taxonomy and gates;
- [`docs/CONTROLS.md`](docs/CONTROLS.md): sandbox controls and routes;
- [`docs/project/CURRENT_STATE.md`](docs/project/CURRENT_STATE.md): normative
  project status;
- [`docs/project/ARCHITECTURE_MAP.md`](docs/project/ARCHITECTURE_MAP.md): current
  ownership map.

Historical prompt sources, milestone decisions, and implementation reports are
preserved under [`docs/history`](docs/history/README.md). They are provenance,
not normative engine documentation.
