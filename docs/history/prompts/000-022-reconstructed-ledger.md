# Prompts 0–22 — Reconstructed Milestone Ledger

**Source status for every entry in this file: reconstructed.** Exact historical prompt wording was not found. Summaries use Git history, current source, README, subsystem documents, tests, and build routes. Acceptance wording below is descriptive evidence, not a quotation of the original prompt.

Implementation-report links point to the [report archive index](../reports/prompt-implementation-reports/INDEX.md), which records whether a verbatim report exists.

## Prompt 0

- Title: Architecture and engineering contract.
- Status: complete.
- Objective: establish repository structure, dependency strategy, architecture documentation, and binding constraints before renderer implementation.
- Major systems/files: `AGENTS.md`, `build.zig`, `docs/ARCHITECTURE.md`, `docs/DEPENDENCIES.md`, `docs/TESTING.md`.
- Evidence: documentation/build-interface inspection.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-0).
- Commit: `3df0ace`.
- Downstream: all milestones.
- Limitation/correction: reconstructed from the initial commit; no exact source text.

## Prompt 1

- Title: SDL3 GPU bootstrap and smoke validation.
- Status: complete.
- Objective: pin Zig/SDL/DXC, create the SDL GPU D3D12 path, compile HLSL to DXIL, and prove resource lifecycle/smoke behavior.
- Major files: `src/platform/sdl.zig`, `src/graphics/gpu_context.zig`, `src/graphics/shader.zig`, dependency/bootstrap tools.
- Evidence: `zig build`, `gpu-smoke`, Debug/Release builds.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-1).
- Commit: `cba01a6`.
- Downstream: all rendering milestones.
- Limitation: Windows/D3D12 is the primary tested backend.

## Prompt 2

- Title: Instanced sprite batching.
- Status: complete.
- Objective: implement one indexed-instanced sprite path with bounded batching, atlas-page ranges, deterministic ordering, and allocation/resource metrics.
- Major files: `src/graphics/sprite_batch.zig`, `src/graphics/render_types.zig`, `assets/shaders/sprite.hlsl`.
- Evidence: CPU batch tests and 1,000-sprite GPU route described in `docs/TESTING.md`.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-2).
- Commit: `2c4dcec`.
- Downstream: every character/world visual.
- Limitation: transparent ordering remains CPU-authored.

## Prompt 3

- Title: Hierarchical humanoid skeleton.
- Status: complete.
- Objective: add immutable skeleton definitions, mutable poses, sockets, attachments, and hierarchical transform evaluation.
- Major files: `src/animation/skeleton.zig`, `src/animation/pose.zig`, `src/scene/humanoid.zig`, math modules.
- Evidence: `--demo humanoid`, deterministic hierarchy/socket tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-3).
- Commit: `44db24d`.
- Downstream: animation, IK, anatomy, presentation.
- Limitation: canonical gameplay rig remains intentionally bounded.

## Prompt 4

- Title: Skeletal animation.
- Status: complete.
- Objective: clips, typed events, deterministic sampling/blending, and animation state transitions.
- Major files: `src/animation/clip.zig`, `animator.zig`, `state_machine.zig`, `events.zig`.
- Evidence: `--demo animation --frames 360`, animation tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-4).
- Commit: `70be8a7`.
- Downstream: controller presentation, interactions, foot planting.
- Limitation: animation remains CPU sampled.

## Prompt 5

- Title: Fixed-step character controller and collision.
- Status: complete.
- Objective: authoritative 240 Hz movement, gravity, swept static AABB collision, jump mechanics, input-to-intent, and render interpolation.
- Major files: `src/physics/fixed_step.zig`, `character_controller.zig`, `collision_world.zig`, `src/platform/input.zig`.
- Evidence: `--demo controller --scripted-input`, schedule-equivalence tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-5).
- Commit: `8490b29`.
- Downstream: all gameplay movement.
- Limitation: static world collision; no external physics engine or ragdoll.

## Prompt 6

- Title: Procedural secondary motion.
- Status: complete.
- Objective: walk bounce, landing compression, and head lag layered visually without modifying the physics root.
- Major files: `src/physics/spring.zig`, procedural/secondary-motion scene modules.
- Evidence: `--demo secondary-motion --scripted-input`, fixed-step spring tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-6).
- Commit: `93d4d13`.
- Downstream: character presentation and later attachment motion.
- Limitation: bounded visual springs, not general soft-body physics.

## Prompt 7

- Title: Multi-character ownership and global ordering.
- Status: complete.
- Objective: independent character runtime state, stable entity IDs, facing reflection, and globally interleaved character sprites.
- Major files: `src/scene/character.zig`, `src/scene/scene.zig`, `docs/MULTI_CHARACTER.md`.
- Evidence: `--demo multi-character`, ownership/order/physics-invariance tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-7).
- Commit: `f936311` (shared Prompts 7–12 integration commit).
- Downstream: interactions and all multi-actor demos.
- Limitation: no character-to-character physics collider.

## Prompt 8

- Title: Synchronized handshake interaction.
- Status: complete.
- Objective: allocation-free paired interaction ownership, eligibility, synchronized clips/events, and deterministic lifecycle.
- Major files: `src/interaction/interaction.zig`, `interaction_system.zig`, `handshake.zig`.
- Evidence: `--demo handshake --scripted-input`, interaction lifecycle/schedule tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-8).
- Commit: `f936311`.
- Downstream: Prompt 9 IK and Prompt 27 presentation.
- Limitation: handshake is the canonical bounded paired interaction.

## Prompt 9

- Title: Handshake arm IK.
- Status: complete.
- Objective: analytical two-bone arm IK around one interaction-owned shared target without root teleporting.
- Major files: `src/animation/ik.zig`, interaction IK integration, `docs/IK.md`.
- Evidence: `--demo handshake-ik --scripted-input`, measured socket-convergence tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-9).
- Commit: `f936311`.
- Downstream: integrated interaction presentation.
- Limitation: canonical two-bone arm chains only.

## Prompt 10

- Title: Foot planting and leg IK.
- Status: complete.
- Objective: authoritative-world ground probes, per-foot locks, and visual two-bone leg IK without changing controller state.
- Major files: foot-planting scene/animation code, ground query support, `docs/FOOT_PLANTING.md`.
- Evidence: `--demo foot-planting --scripted-input`, floor/platform and solve-order tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-10).
- Commit: `f936311`.
- Downstream: integrated locomotion.
- Limitation: locks release when unreachable; no visual root compensation.

## Prompt 11

- Title: Integrated demo and diagnostics.
- Status: complete.
- Objective: compose production character systems and bounded debug visualization through the same batch.
- Major files: integrated demo scene, `src/debug/debug_draw.zig`, `src/debug/metrics.zig`, `docs/DIAGNOSTICS.md`.
- Evidence: `--demo integrated --scripted-input`, optional `--debug-visualization`.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-11).
- Commit: `f936311`.
- Downstream: regression and acceptance routes.
- Limitation: focused demos remain authoritative for subsystem-specific evidence.

## Prompt 12

- Title: Adversarial production-readiness audit.
- Status: complete with known limitations.
- Objective: audit deterministic/runtime/render contracts, add adversarial cases, and report a conservative readiness verdict.
- Major files: tests and diagnostics documentation.
- Evidence: aggregate 183-test-era audit and readiness report referenced by repository history.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-12).
- Commit: `f936311`.
- Downstream: later milestones preserve these contracts.
- Limitation: verdict was checkout-specific; later changes require revalidation.

## Prompt 13

- Title: Production input and interactive playground.
- Status: complete.
- Objective: real SDL keyboard/gamepad/focus handling through `FrameInputSnapshot`, pending edges, and `CharacterIntent`; add `--interactive`.
- Major files: `src/platform/input.zig`, interactive demo/control docs.
- Evidence: input equivalence/focus/reset tests and interactive route.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-13).
- Commit: `611d54f`.
- Downstream: controlled foundation/playable routes.
- Limitation: automated evidence does not claim physical device testing.

## Prompt 14

- Title: Resizable viewport, camera, side-scrolling world, and parallax.
- Status: complete.
- Objective: world-metre rendering, pure camera, high-DPI resize handling, dead-zone following, cave playground, and parallax.
- Major files: camera/world/side-scroller modules and resize paths.
- Evidence: `--demo side-scroller --scripted-input`, fixed readback target.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-14).
- Commit: `7f56f23`.
- Downstream: foundation playground and Prompt 26.
- Limitation: production environment themes are not implemented.

## Prompt 15

- Title: Generalized character visual definitions, attachment points, and extensible rig modules.
- Status: complete.
- Objective: separate reusable appearance/attachment definitions from the canonical rig and permit bounded optional modules.
- Major files: `src/scene/appearance.zig`, generalized humanoid/attachment modules.
- Evidence: definition validation and generalized visual tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-15).
- Commit: `c3ce753`.
- Downstream: anatomy, equipment, art packs.
- Limitation: alternative full gameplay rigs remain out of scope.

## Prompt 16

- Title: Modular adult humanoid anatomy, morphology, faces, hair, and presentation profiles.
- Status: complete.
- Objective: data-defined repeated anatomy, body presets/morphology, independent face/hair presentation, and nonstandard topology proof.
- Major files: `src/scene/anatomy.zig`, `humanoid_anatomy.zig`, `morphology.zig`, `docs/ANATOMY.md`.
- Evidence: `--demo modular-body`, anatomy/morphology/presentation tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-16).
- Commit: `ddd6e36`.
- Downstream: equipment and production character art.
- Limitation: non-sexual current humanoid presentation; no universal creature editor.

## Prompt 17

- Title: Topology-aware equipment, layered clothing, and declarative item effects.
- Status: complete.
- Objective: typed slots, bounded one/every/specific bindings, transactional loadouts, coverage, modifiers, and capabilities.
- Major files: `src/scene/equipment.zig`, equipment demo, `docs/EQUIPMENT.md`.
- Evidence: `--demo equipment`, two-/four-arm recipe expansion and transaction tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-17).
- Commit: `74a4e4b`.
- Downstream: wardrobe and character properties.
- Limitation: original demo art was schematic; Prompt 25 supplied production wardrobe art.

## Prompt 18

- Title: Breathing and shared anatomy/clothing deformation.
- Status: complete.
- Objective: character-owned breathing and one deformation path shared by anatomy and bound equipment.
- Major files: `src/scene/deformation.zig`, breathing demo, `docs/DEFORMATION.md`.
- Evidence: `--demo breathing`, deterministic deformation and ownership tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-18).
- Commit: `0a6cb3a`.
- Downstream: mesh, art, wardrobe fit.
- Limitation: affine bounded response, not cloth simulation.

## Prompt 19

- Title: Topology-aware deformable 2D mesh attachments and unified render ordering.
- Status: complete.
- Objective: permit rigid sprite or bounded deformable mesh visuals without a second character/equipment renderer.
- Major files: `src/graphics/deformable_mesh.zig`, `src/graphics/render_queue.zig`, mesh demo, `docs/MESH_ATTACHMENTS.md`.
- Evidence: `--demo mesh-attachments`, mesh validation/order tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-19).
- Commit: `90e36e7`.
- Downstream: skirt and attachment motion.
- Limitation: fixed topology and affine weighted deformation.

## Prompt 20

- Title: Modular cape, hair, and garment secondary motion.
- Status: complete.
- Objective: one fixed-capacity spring-chain primitive with character-owned state for sprites and meshes.
- Major files: `src/scene/attachment_secondary_motion.zig`, `docs/ATTACHMENT_SECONDARY_MOTION.md`.
- Evidence: `--demo attachment-secondary`, lifecycle/reset/allocation tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-20).
- Commit: `3cf06f1`.
- Downstream: production long hair, sleeves, skirt.
- Limitation: no general cloth/collision.

## Prompt 21

- Title: Character attributes, capabilities, and equipment-effect resolution.
- Status: complete.
- Objective: generic deterministic numeric properties/capabilities consumed by the existing controller.
- Major files: `src/scene/character_properties.zig`, controller consumers, properties demo.
- Evidence: `--demo properties`, stacking/source-count and controller tests.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-21).
- Commit: `3cf06f1`.
- Downstream: future gameplay item effects.
- Limitation: no inventory/combat/economy system.

## Prompt 22

- Title: Integrated Character + World Foundation Playground.
- Status: complete.
- Objective: compose established character, world, interaction, equipment, property, camera, and render paths in one bounded route.
- Major files: `src/scene/foundation_playground.zig`, foundation build/test route.
- Evidence: `--demo foundation`, `test-foundation`, resize/resource/draw/allocation checks.
- Report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-22).
- Commit: `3cf06f1`.
- Downstream: Prompt 23 art and Prompt 27 integration.
- Limitation: foundation playground is not a complete gameplay loop.
