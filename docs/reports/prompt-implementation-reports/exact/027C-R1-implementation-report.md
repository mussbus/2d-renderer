# Prompt 27C-R1 Implementation Report

IMPLEMENTATION REPORT

Scope completed:

- Staged the inherited Prompt 27C checkpoint with the user-authorized elevated
  `git add .`; subsequent R1 edits remain unstaged.
- Reproduced the interactive-equivalent presence failure before correction and
  recorded frame `56`, simulation tick `57`, female position
  `(-2.353127, 1.050000)`, male position `(-1.400000, 1.050000)`, overlap
  `0.031753`, no active interaction, side presentation, and controlled
  velocity `(4.5, 0)`.
- Identified the exact torso shown in the previous summary as the rejected
  ImageGen candidate with SHA-256
  `747949bf121c876e4964402eb3910a2b7c37219c5bf2e6d9226dba41719f0aaa`,
  proved it is not consumed by the authoring tool, and traced all production
  torso IDs, pages, rectangles, UVs, installed paths, and D3D12 output.
- Restored the pre-27C female chest identity and inspected/corrected the same
  source-padding defect in the male torso while retaining only bounded
  shoulder contours.
- Fixed the deterministic authoring path so untouched straight-alpha page
  pixels remain byte-identical, preserved the Prompt 27C component page
  exactly, and added a full-page changed-pixel audit with four controlled
  invalid fixtures.
- Separated character-presence measurement from enforcement with explicit
  `measure_only` and `enforce_acceptance` policies. The interactive route no
  longer terminates on overlap; scripted evidence and invalid fixtures remain
  fail-closed.
- Added deterministic approach, former-failure crossing, pass-through,
  move-away, exact `0.021407`, interaction completion, and reset-cancellation
  coverage.
- Generated two isolated real D3D12/DXIL anatomy/foundation evidence trees and
  two classified review packages. Owner aesthetic acceptance remains
  `[PENDING OWNER REVIEW]`.
- Preserved 314/314 Prompt 27/27A artifacts and restored the accidentally
  overwritten Prompt 27B semantic report from deterministic HEAD
  `3259f79db18659746ca97bde96456da086a40126`; its JSON/TXT hashes exactly
  match the recorded two-run repeatability hashes.
- Prompt 27D and Prompt 28 were not started.

Files created:

- `assets/art/source/p27c_rejected/README.md`
- `assets/art/source/p27c_rejected/prompt27c_owner_rejected_male_atlas.png`
- `assets/art/source/p27c_rejected/prompt27c_owner_rejected_female_atlas.png`
- `tools/audit_p27c_r1_torso.ps1`
- `tools/build_p27c_r1_review_package.ps1`
- `docs/PROMPT27C_R1_DECISION_RECORD.md`
- `docs/prompts/027C-R1-owner-rejected-torso-presence.md`
- `docs/reports/prompt-implementation-reports/exact/027C-R1-implementation-report.md`
- `zig-out/p27c_r1_evidence/` generated corrective, D3D12, provenance,
  repeatability, and review evidence

Files modified:

- `README.md`
- `build.zig`
- `assets/art/p27c_male_base_anatomy_atlas.png`
- `assets/art/p27c_female_base_anatomy_atlas.png`
- `src/graphics/gpu_demo.zig`
- `src/scene/anatomy_quality.zig`
- `src/scene/foundation_coherence_report.zig`
- `src/scene/visual_foundation.zig`
- `tests/visual_foundation_tests.zig`
- `tools/reauthor_p27c_anatomy.ps1`
- `docs/ARCHITECTURE.md`
- `docs/ART_PIPELINE.md`
- `docs/CONTROLS.md`
- `docs/PROMPT27C_DECISION_RECORD.md`
- `docs/TESTING.md`
- `docs/decisions/README.md`
- `docs/project/CURRENT_STATE.md`
- `docs/project/KNOWN_GAPS.md`
- `docs/project/SCOPE_BOUNDARIES.md`
- `docs/prompts/027C-production-anatomy.md`
- `docs/prompts/INDEX.md`
- `docs/reports/README.md`
- `docs/reports/prompt-implementation-reports/INDEX.md`

Commands executed:

1. `& '.\.deps\zig-0.16.0\zig.exe' version`
   Exit code: 0
   Relevant output: `0.16.0`.
2. Elevated `git add .`
   Exit code: 0
   Relevant output: inherited Prompt 27C checkpoint staged; LF/CRLF warnings
   only.
3. `& '.\.deps\zig-0.16.0\zig.exe' build run -j1 -- --demo foundation --interactive`
   Exit code: 1 for two attempted synthetic-input reproductions
   Relevant output: D3D12 process started, but the managed session exposed no
   focusable main-window handle, so synthetic key delivery was not possible.
4. Deterministic interactive-equivalent held-right reproduction through the
   production scene/update/submit route
   Exit code: 1 before the policy correction
   Relevant output: frame `56`, tick `57`, positions
   `(-2.353127,1.050000)`/`(-1.400000,1.050000)`, overlap `0.031753`,
   interaction count `0`, `CharacterPresenceOverlapExceeded`.
5. `& '.\tools\reauthor_p27c_anatomy.ps1'`
   Exit code: 0
   Relevant output: male
   `7f83e8197b41c760f5f67da3c2aa12ef20c9fa886f92e90945b9bcb8dacee8a6`,
   female
   `fa43d355b693cb80337ba2f448535da948dad74bd820fe91e35031f8f6370610`,
   unchanged component
   `e8b10e30f3154d75d6bebd53975ac06ffa10f125ae4ddb0634f622d56d4cea46`.
6. `& '.\tools\audit_p27c_r1_torso.ps1' -OutputDirectory 'zig-out\p27c_r1_evidence\torso_audit'`
   Exit code: 0
   Relevant output: 2 pages, 4 regions, 4/4 invalid fixtures rejected, zero
   unapproved changed pixels, owner review pending.
7. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
   Exit code: 0
   Relevant output: 31/31 tests passed.
8. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
   Exit code: 0
   Relevant output: 15/15 tests, 158/158 production checks, and 6,354/6,354
   pose/morphology checks passed; both Prompt 27C art audits passed.
9. `& '.\.deps\zig-0.16.0\zig.exe' build p27c-anatomy-report -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global' -- --output 'zig-out\p27c_r1_evidence\final_semantic_report' --expect-pass`
   Exit code: 0
   Relevant output: 102 cases, 2,450 traces, 3,788 metrics, zero failures.
10. `& '.\.deps\zig-0.16.0\zig.exe' build test-foundation -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 4/4 tests passed.
11. `& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 15/15 tests passed.
12. `& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 16/16 tests passed.
13. `& '.\.deps\zig-0.16.0\zig.exe' build test-environment -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 13/13 tests and the two-atlas environment audit passed.
14. `& '.\.deps\zig-0.16.0\zig.exe' build visual-geometry-report -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 6,364 traces, 20,665 metrics, zero production failures.
15. `& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 124, then 0 with a 600-second wrapper
    Relevant output: first run exceeded the 300-second wrapper; warmed rerun
    completed 13/13 steps and 389/389 tests.
16. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 20/20 steps succeeded.
17. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 20/20 steps succeeded.
18. `$env:SDL_GPU_DRIVER='direct3d12'; & '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 22/22 steps; actual `direct3d12`, DXIL agreement, two
    instances in one indexed draw, readback within tolerance.
19. Two isolated executions of
    `skeletal_gpu_demo.exe --demo anatomy-quality --scripted-input --frames 600`
    Exit code: 0 for both
    Relevant output: D3D12/DXIL, 8/8 captures, zero update/submission/queue
    allocations, zero GPU-resource delta.
20. Two isolated executions of
    `skeletal_gpu_demo.exe --demo foundation --scripted-input --frames 2400`
    Exit code: 0 for both
    Relevant output: D3D12/DXIL, 16 Prompt 27A plus 4 Prompt 27B captures,
    three handshakes, zero steady-state allocation/resource growth.
21. `skeletal_gpu_demo.exe --demo foundation --interactive --frames 300`
    Exit code: 0
    Relevant output: real D3D12/DXIL interactive mode completed 300 frames,
    93 sprites, 12 indexed-instanced draws, zero steady-state
    allocation/resource growth. No physical keyboard/gamepad claim.
22. Two invocations of `tools/build_p27c_r1_review_package.ps1`
    Exit code: 0 for both
    Relevant output: 45 classified visuals, anatomy 8/8, foundation 16/16,
    zero unclassified PNGs, owner review pending.
23. SHA-256 comparison of the two isolated R1 D3D trees and review PNGs
    Exit code: 0
    Relevant output: D3D artifacts 47/47 byte-identical; review PNGs 43/45
    byte-identical. The two expected differences are the provenance and owner
    sheets that print each run's distinct truthful source path.
24. `& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global' -- --output 'zig-out\p27c_r1_evidence\p27b_regression_semantic'`
    Exit code: 1
    Relevant output: 9,714 metrics, 24 failures, all inherited Prompt 27C
    front-foot `heel_side_sole_height`/`toe_side_sole_height`; the 2,400
    character-presence metrics have zero failures.
25. Deterministic HEAD export/recovery of the final Prompt 27B semantic report
    Exit code: 0
    Relevant output: 9,714 metrics, zero failures; restored JSON
    `ddb98bcd24a3c2150c1d8b5db81d3a7d5d1f5d3b10aca537321853f34a22df6b`
    and TXT
    `301281759d774e6f5a44414dce17f3bd4138d47eedbbfe37ba3c4f92d56545c0`
    match both recorded repeat-run hashes.
26. Historical Prompt 27/27A SHA-256 comparison against
    `historical_evidence_hashes.csv`
    Exit code: 0
    Relevant output: 314 files, zero missing, zero changed, intact `True`.
27. `& '.\tools\check_documentation.ps1'` and
    `& '.\tools\check_repository.ps1'`
    Exit code: 0
    Relevant output: documentation audit passed 46 required files, 36
    Markdown files, and 89 local targets; repository policy audit passed.
28. R1 no-placeholder/disabled-test search
    Exit code: 0
    Relevant output: TODO 0, FIXME 0, disabled/skipped 0; repository audit
    passed.
29. `& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all --global-cache-dir '.zig-cache\p27c-r1-global'`
    Exit code: 0
    Relevant output: 19/19 steps and 389/389 tests passed; formatting,
    repository policy, Prompt 27C art, and Prompt 27C-R1 torso audits passed.
30. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" diff --check`
    followed by staged/unstaged status and stat inspection
    Exit code: 0
    Relevant output: no whitespace errors; the 47-file inherited Prompt 27C
    checkpoint remains staged, while R1 corrections remain unstaged.

Acceptance criteria:

- [PASS] Exact displayed-summary torso provenance is established.
- Evidence: repository path, hash, original ImageGen output, rejection status,
  non-consumption, incompatibilities, and no exact production-pixel match are
  recorded in the permanent manifest and four-panel sheet.
- [PASS] Female chest identity is restored and male padding is inspected
  without broad atlas redesign.
- Evidence: current pages derive from the accepted Prompt 25A atlases; the
  front chest and profile breast/chest projection remain the predecessor
  pixels below the bounded shoulder edits.
- [PASS] No unrelated atlas pixel changed.
- Evidence: male front `1206` at `(269,432)-(376,464)`, male side `303` at
  `(289,17)-(315,58)`, female front `1148` at
  `(240,449)-(332,482)`, female side `86` at
  `(250,40)-(277,56)`; zero changed pixels outside these bounds.
- [PASS] Alpha, continuity, directional, and matte fixtures remain
  fail-closed.
- Evidence: straight-alpha/nearest production convention confirmed; each
  torso has one alpha component and zero transparent nonzero-RGB texels; 4/4
  controlled invalid fixtures rejected.
- [PASS] Interactive presence overlap is diagnostic, not a fatal simulation
  invariant.
- Evidence: `measure_only` exposes every measurement and completed the
  approach/cross/pass/move-away test plus real 300-frame D3D interactive run.
- [PASS] The exact `0.021407` result remains failed and measurable without
  crashing interactive mode.
- Evidence: `passes_acceptance=false`; measure-only returns normally;
  enforcement returns `CharacterPresenceOverlapExceeded`.
- [PASS] No presence or camera threshold was relaxed.
- Evidence: ordinary `0.02`, active interaction `0.15`, and world-camera
  `16 px` constants are unchanged.
- [PASS] Controlled invalid and scripted presence acceptance remain
  fail-closed.
- Evidence: exact-condition enforcement errors; all 2,400 fresh Prompt 27B
  presence metrics pass; the 31-test foundation gate passes.
- [PASS] Interaction completion and cancellation restore ordinary context.
- Evidence: the complete scripted route and explicit reset-cancellation test
  both require `activeCount()==0` and `presenceInteractionContext()==false`.
- [PASS] Real D3D12/DXIL, readback, allocation, and resource checks pass.
- Evidence: 47/47 repeated D3D artifacts, 8/8 anatomy captures, 16/16
  foundation captures, GPU smoke, and zero steady-state growth.
- [PASS] Historical evidence is preserved.
- Evidence: 314/314 historical files unchanged; final Prompt 27B semantic
  hashes match both recorded repeats; final Prompt 27B D3D/review evidence was
  not overwritten.
- [FAIL] A fresh full current-art Prompt 27B semantic report has zero failures.
- Evidence: the requested isolated report correctly fails with 24
  front-foot endpoint-height metrics inherited from staged Prompt 27C; its
  2,400 character-presence metrics have zero failures. R1 did not weaken that
  ruler or redesign the unrelated accepted foot work.
- [PENDING OWNER REVIEW] Torso aesthetic acceptance.
- Evidence: every corrective sheet and manifest explicitly retains
  `[PENDING OWNER REVIEW]`; automated checks do not approve aesthetics.
- [PASS] Prompt 27D and Prompt 28 were not started.

Known limitations:

- Physical keyboard/gamepad movement was not manually tested. The real
  interactive executable was run for 300 frames without injected movement;
  movement-through-overlap coverage is deterministic and uses the same
  production scene/update/submit route.
- The two pre-correction attempts could not deliver synthetic Windows input
  because the managed session exposed no focusable main-window handle.
- Review sheets that print distinct run paths are intentionally not
  byte-identical; their 43 other PNGs and all 47 D3D artifacts are identical.
- Owner aesthetic acceptance remains `[PENDING OWNER REVIEW]`.

Unresolved failures:

- A fresh full current-art Prompt 27B coherence report reports 24
  `heel_side_sole_height`/`toe_side_sole_height` failures caused by Prompt
  27C's inherited ±78-degree front-foot presentation. This is outside the
  owner-rejected torso and presence-policy correction; the strict ruler and
  failed report are preserved under
  `zig-out/p27c_r1_evidence/p27b_regression_semantic`.

No-placeholder audit:

- TODO matches: 0 in Zig/PowerShell implementation files.
- FIXME matches: 0 in Zig/PowerShell implementation files.
- Stub/placeholder findings: 0; repository policy audit passed.
- Disabled or skipped tests: 0 in R1 implementation files.
