# Prompt 27A — Evidence Integrity, State-Conditioned Captures, and Human Visual-Review Harness

- Status: **automated evidence complete; manual visual acceptance pending**.
- Source: [`../source-prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md`](../source-prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md).
- Baseline HEAD:
  `7c4721a5fedbac93eb507b429dfecf4b9e211cde`.
- Objective delivered: preserve Prompt 27's historical evidence, replace
  phase/frame-selected screenshots with 16 ordered state-conditioned D3D12
  captures, attach fail-closed semantic metadata, and generate a deterministic
  owner-review package without changing production art or approving visuals.
- Major runtime files:
  [`../../../src/scene/foundation_evidence.zig`](../../../src/scene/foundation_evidence.zig),
  [`../../../src/scene/visual_foundation.zig`](../../../src/scene/visual_foundation.zig),
  [`../../../src/debug/acceptance_hud.zig`](../../../src/debug/acceptance_hud.zig),
  and the then-current `src/graphics/gpu_demo.zig` compatibility route (removed
  after production renderer ownership was independently proven).
- Tooling:
  [`../../../tools/build_p27a_review_package.ps1`](../../../tools/build_p27a_review_package.ps1)
  validates and packages one run;
  [`../../../tools/compare_p27a_repeats.ps1`](../../../tools/compare_p27a_repeats.ps1)
  compares two independent runs.
- Focused evidence: 18/18 tests; 16/16 D3D12/DXIL captures; at least
  263 per-case metrics with zero automated failures; byte-identical PPM,
  metadata, and PNG artifacts across two runs.
- Historical boundary: the old nine files, report, timing, and resource data
  remain under `zig-out/p27_visual_foundation`; new work uses
  `zig-out/p27a_evidence`.
- Architecture: one authoritative scene/skeleton/simulation/interaction
  system, one `UnifiedRenderQueue`, and the established SDL3 GPU D3D12
  readback. The HUD is bounded, read-only, and allocation-free after
  initialization.
- Manual boundary: `[PENDING OWNER REVIEW]`. Prompt 27A does not promote a
  golden or establish complete aesthetic acceptance.
- Scope boundary: no character/garment art, locomotion clip, collision,
  camera, or handshake redesign; Prompt 27B and Prompt 28 were not started.
