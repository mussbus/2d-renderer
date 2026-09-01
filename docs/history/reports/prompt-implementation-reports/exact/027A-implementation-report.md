# Prompt 27A Implementation Report

IMPLEMENTATION REPORT

Baseline HEAD:
- `7c4721a5fedbac93eb507b429dfecf4b9e211cde`

Initial Git status:
- The tracked worktree was clean before the user copied the Prompt 27A–27H
  roadmap into `prompts/`.
- At Prompt 27A implementation entry, the user-supplied
  `prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md` was untracked.
- No file was staged, committed, reverted, reset, cleaned, or removed.

Scope completed:
- Inserted the exact common empirical-verification contract after the common
  pre-change requirements in the user-supplied Prompt 27A–27H roadmap.
- Preserved the original Prompt 27 report, nine captures, timing, and resource
  artifacts. All 20 frozen historical files still match their baseline
  SHA-256 hashes.
- Added an ordered, data-driven 16-case capture specification with
  authoritative, presentation, interaction, stability, debug-category, and
  timeout predicates.
- Changed stability accounting to fixed simulation ticks. Duplicate render
  observations at one simulation tick add zero stability, and interrupted
  predicates reset the hold.
- Added fail-closed capture observation and commit validation, including
  entity/content/view/state identity, controller/collision state, bilateral
  raised-landing sole measurements, theme invariance, interaction ownership,
  detailed-debug submissions, camera, renderer, allocation, resource, and
  reset metadata.
- Added a bounded read-only acceptance HUD through the existing
  `UnifiedRenderQueue`; it owns no SDL input, controls, texture, renderer,
  simulation state, or steady-state allocation.
- Kept clean D3D12 captures on the existing production prepared queue, then
  appended the HUD to the same queue for the visible evidence window.
- Extended the existing D3D12 readback route to write exactly 16 PPMs, 16 JSON
  records, an ordered manifest, RGB payload statistics, and SHA-256 evidence.
- Added deterministic PPM validation/PNG conversion, five labeled contact
  sheets, ordered review manifest, human review report, and 263 raw per-case
  metrics.
- Added a two-run comparison that requires byte-identical PPM, metadata, and
  PNG artifacts plus identical canonical metrics.
- Added controlled valid, minimally invalid, and clearly invalid predicate
  fixtures, stable-reset/timeout/commit-order/alternate-render-schedule tests,
  and a bounded allocation-free HUD test.
- Updated live architecture, testing, controls, diagnostics, interaction,
  environment, wardrobe, batching, prompt-ledger, project-state, scope,
  decision, and report documentation through Prompt 27A.
- Prompt 27B and Prompt 28 were not started.

Files created:
- `docs/PROMPT27A_DECISION_RECORD.md`
- `docs/prompts/027A-evidence-integrity.md`
- `docs/reports/prompt-implementation-reports/exact/027A-implementation-report.md`
- `src/debug/acceptance_hud.zig`
- `src/scene/foundation_evidence.zig`
- `tools/build_p27a_review_package.ps1`
- `tools/compare_p27a_repeats.ps1`
- User-supplied and retained:
  `prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md`

Files modified:
- `README.md`
- `build.zig`
- `docs/ARCHITECTURE.md`
- `docs/CONTROLS.md`
- `docs/DIAGNOSTICS.md`
- `docs/ENVIRONMENT_THEMES.md`
- `docs/INTERACTIONS.md`
- `docs/MESH_ATTACHMENTS.md`
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
- `src/scene/visual_foundation.zig`
- `tests/visual_foundation_tests.zig`
- `tools/check_documentation.ps1`
- `tools/check_repository.ps1`
- `prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md`

Architecture confirmed:
- One authoritative skeleton, character runtime, 240 Hz simulation,
  controller, collision world, interaction manager, presentation authority,
  and SDL3 GPU renderer remain.
- All production and HUD sprites plus meshes use the existing global
  `UnifiedRenderQueue`.
- The HUD and capture observer are read-only and allocate nothing in
  steady-state.
- D3D12/DXIL readback uses the existing production renderer and transfer
  infrastructure.
- Character art, garment art, locomotion clips, collision, camera behavior,
  and handshake definition were not modified.

Pre-change baseline:
- Historical Prompt 27 evidence:
  `zig-out/p27_visual_foundation/`.
- Frozen hashes:
  `zig-out/p27a_evidence/baseline_prompt27_head_7c4721a5/historical_prompt27_hashes.csv`.
- Separately executed inherited route:
  `zig-out/p27a_evidence/baseline_prompt27_head_7c4721a5/`.
- Baseline behavior: nine phase/frame-selected PPM captures, no per-capture
  semantic JSON, no state-conditioned manifest, and no deterministic owner
  review package.

Threshold and bound decisions:
- Route length: 2,100 to 2,400 rendered frames. The required 60-frame
  inspection holds plus first-contact/release/cleanup evidence and all three
  retained handshakes cannot finish inside the inherited bound. Fixed tick,
  clips, physics, and interaction event ticks are unchanged.
- Initial-idle timeout: 90 to 180 render observations.
- Cleanup timeout: 100 to 180 render observations.
- Timeout reason: allow the same 240 Hz state under an alternate 120 Hz render
  observation schedule. Fixed-tick stability is unchanged; the controlled
  timeout still fails on the first observation beyond the bound.
- Raised-landing sole contract: added bilateral semantic sole-to-raised-surface
  error at most 0.08 m. Production measures 0.009689 m per foot; the 0.0801 m
  minimally invalid and 2 m clearly invalid fixtures fail. No art,
  simulation, foot IK, collider, or camera value changed.

Capture-integrity automated acceptance:
- [PASS] 16/16 ordered captures have matching semantic state and metadata.
- [PASS] 263/263 raw review metrics pass.
- [PASS] Bilateral raised landing reports 0.009689 m / 0.009689 m.
- [PASS] Detailed debug reports collider/root/ground/IK/participant-link
  counts 32/4/8/7/1.
- [PASS] Two independent routes have byte-identical PPM, JSON, and PNG files.
- [PASS] Canonical metric SHA-256 is
  `2c3d302c300ccba5d9cb99dbed57ae65e363775a7d278f955b28e5deefee13d0`.
- [PASS] Alternate render observations produce the same fixed-tick stability.

D3D12 evidence-generation acceptance:
- [PASS] Both routes selected actual SDL GPU driver `direct3d12`.
- [PASS] Generated shader format DXIL matched
  `SDL_GPU_SHADERFORMAT_DXIL`.
- [PASS] Each route wrote 16 distinct 640 by 480, 921,600-byte RGB payloads.
- [PASS] All independent payload hashes match metadata and manifest.
- [PASS] Contact sheets were generated and inspected for state/label
  correspondence:
  `01_complete_matrix.png`, `02_static_and_reset.png`,
  `03_locomotion_and_jump.png`, `04_interaction_sequence.png`, and
  `05_detailed_debug.png`.
- [PASS] No candidate was promoted to a golden.

Owner/manual visual acceptance:
- [PENDING OWNER REVIEW]
- Automated evidence integrity and Codex inspection do not establish complete
  aesthetic acceptance.

Performance and bounds:
- Initialized/final fixed storage: 131,216 / 131,216 bytes.
- Update allocations after stabilization: 0.
- Submission allocations after stabilization: 0.
- Unified-queue allocations after stabilization: 0.
- GPU-resource delta during the route: 0.
- GPU instance/upload slots are pre-grown once during initialization from the
  inherited 1,024 requirement to a 2,048 capacity for a bounded 1,792
  request.
- Clean production peak: 139 sprites, one mesh, 17 sprite ranges/draws, one
  mesh range/draw.
- Same-queue window peak: 85,824 sprite-upload bytes; mesh upload 64 bytes.
- HUD maximum is 1,500 sprites and is tested below that bound.

Commands executed:
1. `.\.deps\zig-0.16.0\zig.exe version`
   Exit code: 0
   Relevant output: `0.16.0`
2. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" status --short`
   Exit code: 0
   Relevant output: user-supplied roadmap untracked at implementation entry;
   no staged files.
3. `.\.deps\zig-0.16.0\zig.exe build test-visual-foundation -j1`
   Exit code: 1
   Relevant output: host cache `manifest_create AccessDenied`; no semantic
   compilation result.
4. `.\.deps\zig-0.16.0\zig.exe build test-visual-foundation -j1 --global-cache-dir .zig-cache\p27a-global`
   Exit code: 0
   Relevant output: equivalent baseline retry passed.
5. `.\.deps\zig-0.16.0\zig.exe build -j1 --global-cache-dir .zig-cache\p27a-global`
   Exit code: 0
   Relevant output: baseline and final Debug builds passed.
6. `$env:SDL_GPU_DRIVER='direct3d12'; & '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --scripted-input --frames 2400`
   Exit code: 0
   Relevant output: 16 captures; 3 handshakes; zero steady-state allocation
   and GPU-resource delta.
7. `& '.\tools\build_p27a_review_package.ps1'`
   Exit code: 0
   Relevant output: `Captures: 16/16`; `Metrics: 263, failures: 0`;
   manual pending.
8. `& '.\tools\build_p27a_review_package.ps1' -EvidenceDirectory <repeat-run-candidate> -OutputDirectory <repeat-run-review>`
   Exit code: 0
   Relevant output: second independent package 16/16, 263 metrics, zero
   failures.
9. `& '.\tools\compare_p27a_repeats.ps1' -FirstEvidenceDirectory '.\zig-out\p27a_evidence\candidate' -SecondEvidenceDirectory '.\zig-out\p27a_evidence\repeat_run_b\zig-out\p27a_evidence\candidate' -FirstReviewDirectory '.\zig-out\p27a_evidence\review_package' -SecondReviewDirectory '.\zig-out\p27a_evidence\repeat_run_b\review_package'`
   Exit code: 0
   Relevant output: 16/16 byte-identical PPM, metadata, and PNG; canonical
   metrics identical.
10. `.\.deps\zig-0.16.0\zig.exe build test-visual-foundation -j1 --global-cache-dir .zig-cache\p27a-global`
    Exit code: 0
    Relevant output: 18/18 tests passed.
11. `.\.deps\zig-0.16.0\zig.exe build p27a-review -j1 --global-cache-dir .zig-cache\p27a-global`
    Exit code: 0
    Relevant output: 16/16 captures; 263 metrics; zero failures.
12. `& '.\tools\check_repository.ps1'`
    Exit code: 0
    Relevant output: 122-file audit passed; no alternate renderer,
    unfinished marker, or disabled-test finding.
13. `Compare-Object <frozen historical hashes> <current historical hashes>`
    Exit code: 0
    Relevant output: historical Prompt 27 evidence unchanged, 20/20 files.
14. `.\.deps\zig-0.16.0\zig.exe build test -j1 --summary all --global-cache-dir .zig-cache\p27a-global`
    Exit code: 124
    Relevant output: first wrapper reached its 240-second host timeout without
    a test failure; not counted as a pass.
15. `.\.deps\zig-0.16.0\zig.exe build test -j1 --summary all --global-cache-dir .zig-cache\p27a-global`
    Exit code: 0
    Relevant output: 13/13 steps; 371/371 tests passed.
16. `.\.deps\zig-0.16.0\zig.exe build check -j1 --summary all --global-cache-dir .zig-cache\p27a-global`
    Exit code: 0
    Relevant output: 17/17 steps; formatting, 371/371 tests, repository audit,
    Prompt 26 art, and 12/12 Prompt 25D goldens passed.
17. `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseSafe -j1 --summary all --global-cache-dir .zig-cache\p27a-global`
    Exit code: 0
    Relevant output: 20/20 build/install steps passed.
18. `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseFast -j1 --summary all --global-cache-dir .zig-cache\p27a-global`
    Exit code: 0
    Relevant output: 20/20 build/install steps passed.
19. `$env:SDL_GPU_DRIVER='direct3d12'; .\.deps\zig-0.16.0\zig.exe build gpu-smoke -j1 --summary all --global-cache-dir .zig-cache\p27a-global`
    Exit code: 0
    Relevant output: 22/22 steps; D3D12/DXIL two-instance readback passed with
    one indexed-instanced draw.
20. `& '.\tools\check_documentation.ps1'`
    Exit code: 0
    Relevant output: populated after this report was archived; consolidated
    documentation and links passed.

Acceptance criteria:
- [PASS] Historical Prompt 27 report/captures/timing/resource evidence is
  preserved.
- [PASS] Captures are state-conditioned rather than phase-entry conditioned.
- [PASS] Every capture has validated semantic and pixel metadata.
- [PASS] Filenames, ordered IDs, predicates, metadata, and D3D payloads agree.
- [PASS] Stable holds cannot fire early and are render-schedule independent.
- [PASS] Timeouts fail honestly with actionable production diagnostics.
- [PASS] Detailed debug proves actual category submissions.
- [PASS] Deterministic PNG/contact-sheet/review packaging exists.
- [PASS] Two critical evidence runs are byte-repeatable.
- [PASS] Existing Prompt 0–27 automated contracts and architecture pass.
- [PASS] No art, garment, clip, collision, camera, or handshake redesign was
  performed.
- [PASS] Prompt 27B and Prompt 28 were not started.
- [PENDING OWNER REVIEW] Manual/aesthetic visual acceptance.

Known limitations:
- Prompt 27A proves evidence integrity and state correspondence, not complete
  aesthetic quality.
- The raised-landing 0.08 m semantic gate is deliberately a landing-pose
  capture contract; Prompt 27B owns stricter independent pixel/sole-to-surface
  correction.
- The visible HUD is not baked into clean art captures. It is displayed in
  the evidence window through the same queue, while capture 15 contains the
  actual production diagnostic primitives.
- Failed development candidates remain under uniquely named
  `zig-out/p27a_evidence/candidate_dev*` paths as rejection evidence.

Unresolved failures:
- None in automated Prompt 27A, aggregate, build, audit, or GPU gates.
- Owner/manual visual acceptance remains `[PENDING OWNER REVIEW]`.

No-placeholder audit:
- TODO matches: 0 in Prompt 27A implementation/test/tool files.
- FIXME matches: 0 in Prompt 27A implementation/test/tool files.
- Stub/placeholder findings: 0.
- Disabled or skipped tests: 0.

Final Git status:
- Modified tracked source, tests, build integration, audit tooling, and live
  documentation are listed above.
- New Prompt 27A source, HUD, tools, records, report, and user-supplied roadmap
  remain untracked.
- No file is staged or committed.
