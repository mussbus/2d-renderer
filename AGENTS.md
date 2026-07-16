# Binding Engineering Contract

This file is binding for every future task in this repository. If a later request conflicts with it, stop and report the conflict instead of silently relaxing these rules.

## Product target

- Use Zig 0.16.0 exactly. Do not downgrade Zig or write code intended for Zig 0.15.x or earlier.
- Treat Windows 11 as the primary development platform.
- Use SDL3 for windows, keyboard and gamepad input, and platform integration.
- Use the SDL3 GPU API for rendering.
- Keep HLSL as shader source and compile it into a shader format supported by the selected SDL GPU backend.
- Perform animation, character physics, inverse kinematics, interaction coordination, and transparent draw ordering on the CPU.
- Perform vertex transformation, texture sampling, alpha blending, and instanced sprite rendering on the GPU.

## Final demonstration acceptance criteria

The final demonstration must include all of the following:

- Two segmented humanoid characters.
- Idle, walk, jump, fall, land, and handshake animations.
- Keyboard and gamepad control.
- Gravity and collision against static platforms.
- Visible vertical body movement while stepping.
- Landing compression and spring-like secondary motion.
- A synchronized handshake between two characters.
- Hand-to-hand inverse kinematics during the handshake.
- Explicit control over which hand and forearm appear in front.
- GPU-instanced rendering of body-part sprites.
- Debug visualization for bones, colliders, sockets, and interaction targets.

## Non-negotiable prohibitions

Never:

- Use `SDL_Renderer`, `SDL_RenderTexture`, `SDL_RenderGeometry`, or another high-level SDL 2D rendering path.
- Use OpenGL, raylib, SFML, a game engine, a skeletal-animation library, or an external physics engine.
- Implement a CPU rasterizer and call it GPU rendering.
- Render each body part with an independent command submission.
- Replace the skeletal character with one monolithic animated sprite sheet.
- Replace physics with a prerecorded jump animation.
- Replace interaction coordination with two visually unrelated animations.
- Use a full-body teleport as the normal solution for aligning a handshake.
- Permanently weld handshake participants together.
- Claim a hand is aligned without calculating and measuring socket positions.
- Claim rendering is instanced if it issues one draw call per sprite.
- Leave fake implementations, empty bodies, unconditional success returns, placeholder constants, `TODO`, `FIXME`, `unreachable`, or commented-out intended implementations.
- Disable a failing test, weaken its assertion, or delete it merely to make the build pass.
- Write tests that simply reproduce the implementation line for line.
- Silently fall back to another graphics API.
- Silently continue when GPU device, shader, pipeline, texture, buffer, or swapchain creation fails.
- Invent SDL or Zig APIs from memory when the installed headers or Zig 0.16 compiler can provide the real answer.
- Report a command as passing unless it was actually run and returned exit code zero.

`unreachable` is permitted only when the invariant is formally established immediately above it and a comment explains why the state is impossible. It must never stand in for unfinished error handling.

## Required engineering rules

1. Run `zig version` before modifying the project in every implementation task.
2. Stop and report a blocking error if the active compiler is not exactly 0.16.0.
3. Inspect the actual SDL3 headers used by the project before calling GPU APIs.
4. Pin every external dependency to an exact release, commit, archive hash, or package-lock entry. Never depend on a floating `main`, `master`, or `latest` reference.
5. Keep ownership and destruction explicit.
6. Permit no heap allocation in the steady-state simulation/render loop after initialization, except when an intentionally bounded collection grows and that growth is reported in debug output.
7. Give every GPU resource a corresponding destruction path.
8. Make every partially completed initialization sequence clean up resources already acquired if a later step fails.
9. Use a fixed simulation timestep and interpolate only for rendering.
10. Keep simulation state independent from the renderer.
11. Keep user input independent from character control by converting input into a character-intent structure.
12. Keep physics root motion separate from visual skeleton offsets.
13. Make deterministic systems testable without creating a window or GPU device.
14. Use tolerances for floating-point assertions and explain each selected tolerance.
15. Run formatting before reporting completion.
16. Use meaningful error sets and propagate errors instead of swallowing them.
17. Log errors with enough context to identify the failed operation and the SDL error string.
18. Do not create abstractions unused by the current or immediately following milestone.
19. Do not combine unrelated milestone work unless it is required to make the current milestone function.
20. Do not create every empty repository file up front. Create a file only when its milestone needs real implementation.

## Intended repository structure

Use this structure unless the repository already has a demonstrably better equivalent. Add files only as their milestone acquires real content.

```text
build.zig
build.zig.zon
AGENTS.md
README.md
assets/
  shaders/
    sprite.hlsl
docs/
  ARCHITECTURE.md
  DEPENDENCIES.md
  TESTING.md
  CONTROLS.md
src/
  main.zig
  platform/
    sdl.zig
    input.zig
  graphics/
    gpu_context.zig
    gpu_resources.zig
    shader.zig
    sprite_batch.zig
    renderer.zig
    render_types.zig
  math/
    vec2.zig
    mat3.zig
    transform2d.zig
    interpolation.zig
  animation/
    skeleton.zig
    pose.zig
    clip.zig
    animator.zig
    state_machine.zig
    events.zig
    ik.zig
  physics/
    body.zig
    collider.zig
    collision_world.zig
    character_controller.zig
    spring.zig
    fixed_step.zig
  interaction/
    interaction.zig
    interaction_system.zig
    handshake.zig
  scene/
    character.zig
    scene.zig
    demo_scene.zig
  debug/
    debug_draw.zig
    metrics.zig
tools/
  compile_shaders.ps1
  bootstrap_dependencies.ps1
tests/
  test_all.zig
```

## Required documentation before implementation

`docs/ARCHITECTURE.md` must document:

- Coordinate system and axis directions.
- Matrix/vector convention.
- Transform multiplication order.
- Physics units.
- Fixed timestep.
- CPU/GPU responsibility boundary.
- Skeleton and pose ownership.
- Animation sampling model.
- Interaction ownership.
- Draw-order model.
- Resource lifetime model.
- Error-handling strategy.
- Why character physics is not a full ragdoll.
- Which systems are deterministic.
- Which portions require a GPU to test.

`docs/DEPENDENCIES.md` must document:

- Exact Zig version.
- Exact SDL3 version or commit.
- Exact shader compiler or SDL_shadercross version or commit.
- How dependencies are obtained.
- How versions and hashes are verified.
- Runtime DLL requirements.
- Supported shader formats.
- Expected Windows GPU backend.
- How to diagnose a backend or shader-format mismatch.

`docs/TESTING.md` must separately document:

- Pure unit tests.
- Deterministic simulation tests.
- GPU smoke tests.
- Manual visual acceptance tests.
- Performance checks.

## Required build interface

The completed repository must provide and genuinely implement all of these commands:

```text
zig build
zig build test
zig build run
zig build gpu-smoke
zig build check
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseFast
```

`zig build check` must run formatting verification, unit tests, and every static repository check that does not require a physical GPU.

## Milestone discipline

The initial documentation milestone is limited to repository inspection, dependency strategy, architecture documents, this file, and build planning. It must not implement the renderer.

## Required completion report

End every response that performs repository work with this exact report structure, populated with observed facts rather than claims:

```text
IMPLEMENTATION REPORT
Scope completed:
- ...
Files created:
- ...
Files modified:
- ...
Commands executed:
1. <exact command>
 Exit code: <number>
 Relevant output: <actual concise output>
Acceptance criteria:
- [PASS/FAIL] ...
- Evidence: ...
Known limitations:
- ...
Unresolved failures:
- ...
No-placeholder audit:
- TODO matches:
- FIXME matches:
- Stub/placeholder findings:
- Disabled or skipped tests:
```

Do not say a milestone is complete while any of its required acceptance criteria are failing.
