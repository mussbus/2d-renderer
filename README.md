# SDL3 GPU 2D Skeletal Character Prototype

This repository is in its binding design milestone. It targets Zig 0.16.0, Windows 11 x64, SDL 3.4.10, the SDL3 GPU API with an explicit Direct3D 12 backend, and offline DXIL compilation with DXC v1.9.2602.24.

No renderer or feature code exists yet. That is intentional: the initial request limits this milestone to inspection, dependency strategy, architecture/testing documentation, and build planning.

Start with:

- [`AGENTS.md`](AGENTS.md) for binding requirements and prohibitions.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for system boundaries and conventions.
- [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md) for exact versions, hashes, and backend policy.
- [`docs/TESTING.md`](docs/TESTING.md) for test layers and acceptance checks.
- [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) for staged implementation and the final build interface.
