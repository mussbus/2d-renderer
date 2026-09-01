# Prompt 27B Implementation Report

Baseline HEAD:
`0e29e0cbf9644a4284ab791c2bed6dcc366acabf`.

Prompt 27A automated evidence integrity was accepted as the inherited
baseline. Its owner/manual visual field remains `[PENDING OWNER REVIEW]`.
The pre-change SHA-256 inventory covers 314 Prompt 27 and Prompt 27A evidence
files. The final integrity audit reports zero missing and zero changed files.
Rejected Prompt 27B development candidates were retained.

IMPLEMENTATION REPORT
Scope completed:
- Added one fail-closed semantic contact chain from immutable supporting
  collider top through post-IK sole socket, alpha-derived actual submitted
  anatomy/equipment sole, the production camera, semantic render order, and
  real D3D12 pixels.
- Added actual `UnifiedRenderQueue` submission indices to anatomy and wardrobe
  traces so ground presentation corrects the intended submitted record without
  changing physics roots, colliders, animation, IK, identity, or source art.
- Added bounded vertical safe-region framing to the existing production
  camera from actual submitted anatomy, hair, headwear, equipment, and
  deformable-garment bounds. Same-frame camera publication keeps semantic and
  submitted pixels consistent.
- Added typed far/midground/gameplay parallax traces containing actual
  submitted anchors and camera factors, plus semantic and independent D3D12
  pixel measurement.
- Added an allocation-free visible character-presence detector and a
  controller-driven partner walk-clear/return route. Stopped roots remain
  invariant and moving roots obey per-tick controller bounds; no teleport or
  handshake redesign was introduced.
- Added debug-only surface, sole, camera-safe, and parallax evidence through
  the existing `UnifiedRenderQueue`. Clean captures are prepared before debug
  evidence is appended.
- Added a fast 28-test Prompt 27B focused gate, a 9,714-metric TXT/JSON
  semantic report, a 12-capture/55-pixel-metric D3D12 review package, and
  byte-repeatability checks.
- Added an additive direct 960×540-to-640×480 regression without removing the
  incremental 960×540-to-800×510-to-640×480 route. The first post-resize
  frame is validated as viewport reprojection with 37.50 px headroom,
  36.77 px footroom, and D3D12 bounds markers; subsequent world-camera motion
  remains under the unchanged 16 px limit.
- Preserved all 16 Prompt 27A state-conditioned captures per D3D run and added
  four Prompt 27B supplemental captures. The final Prompt 27A regression
  review remains 16/16 captures, 263 metrics, and zero failures.
- Preserved all historical Prompt 27/27A evidence, hash inventory, reports,
  and failed Prompt 27B candidates. No evidence was promoted to a golden.
- Updated current architecture, testing, controls, diagnostics, environment,
  interaction, batching, wardrobe, prompt ledger, roadmap, scope, known-gap,
  decision, and report documentation through Prompt 27B.
- Confirmed no anatomy, garment, footwear, atlas art, locomotion clip,
  handshake definition, or world-collider source changed. Prompt 27C and
  Prompt 28 were not started.
Files created:
- `docs/PROMPT27B_DECISION_RECORD.md`
- `docs/prompts/027B-ground-contact-camera-parallax-presence.md`
- `docs/reports/prompt-implementation-reports/exact/027B-implementation-report.md`
- `src/scene/foundation_coherence.zig`
- `src/scene/foundation_coherence_report.zig`
- `tools/build_p27b_review_package.ps1`
Files modified:
- `README.md`
- `build.zig`
- `docs/ARCHITECTURE.md`
- `docs/CONTROLS.md`
- `docs/DIAGNOSTICS.md`
- `docs/ENVIRONMENT_THEMES.md`
- `docs/INTERACTIONS.md`
- `docs/SPRITE_BATCH.md`
- `docs/TESTING.md`
- `docs/WARDROBE.md`
- `docs/decisions/README.md`
- `docs/project/ARCHITECTURE_MAP.md`
- `docs/project/CURRENT_STATE.md`
- `docs/project/KNOWN_GAPS.md`
- `docs/project/MASTER_ROADMAP.md`
- `docs/project/README.md`
- `docs/project/SCOPE_BOUNDARIES.md`
- `docs/prompts/027-integrated-foundation.md`
- `docs/prompts/INDEX.md`
- `docs/reports/README.md`
- `docs/reports/prompt-implementation-reports/INDEX.md`
- `src/graphics/gpu_demo.zig`
- `src/scene/character_art.zig`
- `src/scene/environment_demo.zig`
- `src/scene/environment_theme.zig`
- `src/scene/foundation_evidence.zig`
- `src/scene/visual_foundation.zig`
- `src/scene/visual_geometry.zig`
- `src/scene/wardrobe_presentation.zig`
- `tests/visual_foundation_tests.zig`
- `tools/check_repository.ps1`
Commands executed:
1. `& '.\.deps\zig-0.16.0\zig.exe' version`
 Exit code: 0
 Relevant output: `0.16.0`.
2. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: `28/28 tests passed`.
3. `& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: `metrics=9714 failures=0`.
4. `& '.\.deps\zig-0.16.0\zig.exe' build test-environment -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: `13/13 tests passed`; two environment-atlas audits passed.
5. `& '.\.deps\zig-0.16.0\zig.exe' build test-foot-planting -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 1
 Relevant output: no build step named `test-foot-planting`; no tests ran. The
 declared `test-foundation`, `test-presentation`, focused Prompt 27B, and
 aggregate routes were used instead.
6. `& '.\.deps\zig-0.16.0\zig.exe' build test-foundation -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: `4/4 tests passed`.
7. `& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: `15/15 tests passed`.
8. `& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: `16/16 tests passed`.
9. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: `10/10 tests passed`; Prompt 25D focused production
 geometry `158/158 PASS`; pose/morphology geometry `6354/6354 PASS`.
10. `& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: `381/381 tests passed`.
11. `& '.\.deps\zig-0.16.0\zig.exe' build -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: Debug install `20/20 steps succeeded`.
12. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: ReleaseSafe install `20/20 steps succeeded`.
13. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: ReleaseFast install `20/20 steps succeeded`.
14. `$env:SDL_GPU_DRIVER='direct3d12'; & '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: actual driver `direct3d12`; generated format `DXIL`;
 readback passed; two instances rendered in one indexed draw.
15. Two isolated executions of
 `$env:SDL_GPU_DRIVER='direct3d12'; & '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --scripted-input --frames 2400`
 Exit code: 0 for each
 Relevant output: D3D12/DXIL; 16 Prompt 27A plus 4 Prompt 27B captures;
 `sprites=149 meshes=1 sprite_ranges=36 mesh_ranges=1 sprite_draws=36
 mesh_draws=1`; initialized/final fixed-buffer bytes `131216/131216`; zero
 update, submission, queue-allocation, and GPU-resource deltas.
16. `& '.\tools\build_p27b_review_package.ps1'` with isolated run-6/run-7
 foundation, supplemental, semantic-report, and output directories
 Exit code: 0 for each
 Relevant output: each package contains 12 captures, 9,714 semantic metrics,
 55 pixel metrics, and zero failures.
17. `& '.\tools\build_p27a_review_package.ps1' -EvidenceDirectory '.\zig-out\p27b_evidence\final_d3d_run_8\zig-out\p27a_evidence\candidate' -OutputDirectory '.\zig-out\p27b_evidence\p27a_regression_review_run_8'`
 Exit code: 0
 Relevant output: `16/16`, 263 metrics, zero failures; manual visual
 acceptance `PENDING OWNER REVIEW`.
18. `& '.\.deps\zig-0.16.0\zig.exe' fmt build.zig src/graphics/gpu_demo.zig src/scene/character_art.zig src/scene/environment_demo.zig src/scene/environment_theme.zig src/scene/foundation_coherence.zig src/scene/foundation_coherence_report.zig src/scene/foundation_evidence.zig src/scene/visual_foundation.zig src/scene/visual_geometry.zig src/scene/wardrobe_presentation.zig tests/visual_foundation_tests.zig`
 Exit code: 0
 Relevant output: formatting completed without diagnostics.
19. `& '.\tools\check_documentation.ps1'`
 Exit code: 0
 Relevant output: documentation audit passed.
20. `& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 1 on the first run
 Relevant output: all 380 tests passed, but the source-policy audit still
 required Prompt 27's obsolete exact
 `self.visual_captures_written != foundation_capture_count` expression. The
 audit was corrected to require the inherited capture count, the three-item
 Prompt 27B count, and their bounded sum.
21. `& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all --global-cache-dir '.zig-cache\p27b-global'`
 Exit code: 0
 Relevant output: formatting, Prompt 27B source-policy audit,
 image/environment/golden audits, and `381/381` tests passed.
22. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" diff --check`
 Exit code: 0
 Relevant output: no whitespace errors.
23. Historical Prompt 27/27A SHA-256 comparison against
 `zig-out/p27b_evidence/baseline_prompt27a_head_0e29e0c_pre27b/historical_evidence_hashes.csv`
 Exit code: 0
 Relevant output: 314 files; missing 0; changed 0; intact true.
Acceptance criteria:
- [PASS] Supporting-collider, anatomical-socket, submitted visual-sole,
  projection, order, and D3D12-pixel measurements form one fail-closed chain.
- Evidence: 14 required contact rows have `0 px` canonical and sole-midpoint
  error; heel/toe error is `0..0.03 px` and `-0.03..0 px`; D3D markers are
  within `0.5 px`.
- [PASS] Camera framing uses the existing camera and protects actual
  character/headwear/garment bounds without changing gameplay.
- Evidence: top clearance `16..115.30 px`, bottom clearance
  `16..80.24 px`, maximum vertical movement `15.57 px/render`; gameplay
  fingerprint unchanged.
- [PASS] The additive direct 960×540-to-640×480 fixture validates its first
  post-resize frame without weakening the world-camera bound.
- Evidence: semantic headroom/footroom `37.50/36.77 px`; complete 49-pixel
  D3D markers; projection errors `0.50/0.23 px`; subsequent world-camera
  maximum `15.566496 px` against the unchanged 16 px limit.
- [PASS] Parallax is measured from actual submitted factors semantically and
  from D3D12 pixels.
- Evidence: 10.93 m travel; D3D displacement `30/113/246 px`;
  factor-prediction error `0.48/0.16/0 px`; adjacent separation
  `83/133 px`.
- [PASS] Scripted character presence has zero uncontrolled ordinary overlap,
  bounded controller steps, and no root teleport.
- Evidence: ordinary overlap ratio is zero; stopped-root and per-tick
  controller-step fixtures pass. General interactive collision is not
  claimed.
- [PASS] State-conditioned, D3D12, allocation, render-path, and repeatability
  evidence pass.
- Evidence: semantic report `9714/0`; each D3D review `55/0`; repeatability
  compares 38 production and 15 review artifacts with zero mismatches;
  initialized/final bytes `131216/131216` and all steady-state deltas zero.
- [PASS] Prompt 27A regression and historical evidence integrity remain
  intact.
- Evidence: Prompt 27A review `16/16`, 263 metrics, zero failures; 314
  historical files, zero missing, zero changed.
- [PASS] No anatomy/garment art, locomotion clip, handshake definition,
  world-collider source, renderer ownership, or simulation authority changed.
- Evidence: no asset or `foundation_playground.zig` diff; only trace indices,
  presentation coherence, evidence harness, tests, tools, and documentation
  changed.
- [PASS] Prompt 27C and Prompt 28 were not started.
- Evidence: no Prompt 27C/28 implementation files or build routes were added.
Known limitations:
- Prompt 27A and Prompt 27B owner/manual visual acceptance remain
  `[PENDING OWNER REVIEW]`; no new capture is an approved golden.
- General interactive dynamic character-character collision remains
  unimplemented. Prompt 27B proves only its deterministic routed presence
  contract plus fail-closed overlap detection.
- The nonexistent `test-foot-planting` alias failed at build-step dispatch;
  foot/ground behavior is covered by the real focused Prompt 27B,
  `test-foundation`, presentation, visual-geometry, and aggregate gates.
Unresolved failures:
- None in the implemented Prompt 27B automated, semantic, D3D12, focused,
  aggregate, build, audit, repeatability, or historical-integrity gates.
- Owner/manual visual acceptance remains pending and is not represented as an
  automated failure or approval.
No-placeholder audit:
- TODO matches: 0 in Prompt 27B source, tests, tool, and new documentation.
- FIXME matches: 0 in Prompt 27B source, tests, tool, and new documentation.
- Stub/placeholder findings: 0; no empty body, unconditional-success shim,
  screenshot-coordinate exception, second renderer, or disabled production
  path was added.
- Disabled or skipped tests: 0.
