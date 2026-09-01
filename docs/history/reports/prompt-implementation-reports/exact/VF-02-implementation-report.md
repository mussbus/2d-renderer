# VF-02 Implementation Report

IMPLEMENTATION REPORT

Scope completed:

- Baseline HEAD:
  `0e9bfcb733ad24ae167acf8deb43540917cbb641`.
- Initial Git status: the complete inherited VF-01 worktree shown below, with
  18 modified paths, four untracked paths, and no staged paths.
- Added one bounded fail-closed registration contract shared by production
  submission, VF-01 truth traces, JSON export, overlay residuals, and focused
  fixtures.
- Supported point, segment, frame, and mesh/bridge schema modes with explicit
  longitudinal/transverse scale, mirroring, authored-adjustment, and failure
  policies.
- Migrated both upper arms, both forearms, both thighs, both shins, both feet,
  torso, pelvis, and nose for both production styles in front, side-right, and
  side-left presentation.
- Removed the superseded hard-coded front-foot `+/-78` degree placement
  rotation. The registered ankle remains fixed while an explicit style/view
  point-binding orientation policy supplies toe-out.
- Classified every traced submission as
  `authoritative_registration`, `compatibility_adapter`, or
  `transitional_legacy`. Wardrobe remains an explicit compatibility path.
- Extended the VF-01 schema to version 2 with exact registration identity,
  mode, policies, threshold, source/target/transformed points, residual, and
  placement-authority fields.
- Kept whole-character ground alignment coherent by translating target and
  transformed registration evidence together; it cannot hide or change a
  structural residual.
- Added initialization-time alpha-visible atlas scans. Temporary PNG decode
  allocation is released immediately and does not consume the scene's fixed
  steady-state allocator.
- Moved the enlarged bounded visual trace from the Debug executable stack to
  one explicitly owned initialization allocation. Capacity and fail-closed
  overflow behavior remain fixed; deinitialization is explicit.
- Added controlled rejection fixtures for missing source/target data,
  coincident segments, nonfinite points, swapped proximal/distal roles,
  invalid reflection, degenerate frames, excessive residual, thickness
  movement of the proximal anchor, front-route bypass, and side semantic
  swaps.
- Produced ten fresh real-D3D12/DXIL manual bundles `_0040` through `_0049`.
  They cover male/female front, female side-right, female side-left walk, and
  All Diagnostics. Every bundle contains 26 authoritative registered
  submissions with zero residual failures.
- Independently recomputed all bundle file and source-asset SHA-256 values and
  byte sizes. Clean/debug render frame, simulation tick, frozen state, and
  common fingerprint equality all validate.
- Preserved Prompt 27, Prompt 27A, final Prompt 27B, Prompt 27C/R1, and VF-01
  evidence. Prompt 27A was independently validated into a new VF-02-only
  output rather than overwriting its historical review package.
- Preserved the fresh-current Prompt 27B failure: 9,714 metrics and 24
  front-foot endpoint-height failures.
- Did not repaint production art, migrate wardrobe placement, expand
  morphology, add materials, generalize topology, retune locomotion, redesign
  the handshake, begin VF-03, or begin Prompt 28.

Baseline initial Git status:

```text
## master...origin/master
 M build.zig
 M docs/ARCHITECTURE.md
 M docs/CONTROLS.md
 M docs/DIAGNOSTICS.md
 M docs/TESTING.md
 M docs/project/ARCHITECTURE_MAP.md
 M docs/project/CURRENT_STATE.md
 M docs/project/KNOWN_GAPS.md
 M docs/prompts/INDEX.md
 M docs/reports/prompt-implementation-reports/INDEX.md
 M src/debug/debug_draw.zig
 M src/graphics/gpu_demo.zig
 M src/platform/input.zig
 M src/platform/sdl_input.zig
 M src/scene/character_art.zig
 M src/scene/visual_foundation.zig
 M tests/visual_foundation_tests.zig
 M tools/check_repository.ps1
?? docs/VF01_DECISION_RECORD.md
?? docs/prompts/VF-01-visual-truth-debugger.md
?? docs/reports/prompt-implementation-reports/exact/VF-01-implementation-report.md
?? src/debug/visual_truth.zig
```

Files created:

- `docs/VF02_DECISION_RECORD.md`
- `docs/prompts/VF-02-authoritative-rig-to-art-registration.md`
- `docs/reports/prompt-implementation-reports/exact/VF-02-implementation-report.md`
- `src/scene/visual_registration.zig`
- `tests/visual_registration_tests.zig`

Files modified for VF-02:

- `build.zig`
- `docs/ANATOMY.md`
- `docs/ARCHITECTURE.md`
- `docs/CHARACTER_PRESENTATION.md`
- `docs/CONTROLS.md`
- `docs/DIAGNOSTICS.md`
- `docs/MESH_ATTACHMENTS.md`
- `docs/TESTING.md`
- `docs/VISUAL_GEOMETRY.md`
- `docs/project/ARCHITECTURE_MAP.md`
- `docs/project/CURRENT_STATE.md`
- `docs/project/KNOWN_GAPS.md`
- `docs/prompts/INDEX.md`
- `docs/reports/prompt-implementation-reports/INDEX.md`
- `src/debug/visual_truth.zig`
- `src/graphics/gpu_demo.zig`
- `src/scene/character_art.zig`
- `src/scene/foundation_coherence.zig`
- `src/scene/foundation_coherence_report.zig`
- `src/scene/visual_foundation.zig`
- `src/scene/visual_geometry.zig`
- `src/scene/wardrobe_presentation.zig`
- `tests/visual_foundation_tests.zig`

Architecture confirmed:

- Authoritative controller/root/collider state remains independent of
  rendering.
- Canonical skeleton pose remains animation, IK, and foot-planting authority.
- Front/side presentation projection supplies view-specific registration
  targets without changing canonical semantic identities.
- The atlas region's alpha-visible landmarks and the projected targets now
  jointly own the migrated final sprite transform.
- Production submission emits the evidence later consumed by VF-01; the
  debugger and validator do not reconstruct a parallel registered transform.
- Appearance/anatomy topology remains unchanged and inspectable; VF-03's
  consolidated graph was not started.
- All registered visuals still enter the one `UnifiedRenderQueue` and the
  existing indexed-instanced D3D12/DXIL renderer.
- Registration and F1 execution allocate nothing per frame and create no GPU
  resources.

Architecture discrepancies found:

- Before VF-02, authored size/pivot/rest-rotation placement owned the final
  sprite while visual landmarks validated afterward. That dual-authority path
  is removed for the migrated components.
- Wardrobe placement and unmigrated head, hand, face, and hair visuals still
  use compatibility or transitional authority. Diagnostics label them
  honestly; broad migration is out of scope.
- Extending each fixed trace record with registration points made the
  previously inline Debug scene exceed the Windows stack. The trace remains
  fixed-capacity but is now one initialization-owned allocation.
- The current atlas art does not satisfy the independent production-pixel
  ruler after structural registration. This is a source-art/silhouette and
  legacy-wardrobe discrepancy, not a hidden registration residual.

Commands executed:

1. `& '.\.deps\zig-0.16.0\zig.exe' version`
   Exit code: 0
   Relevant output: `0.16.0`.

2. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" rev-parse HEAD`
   Exit code: 0
   Relevant output:
   `0e9bfcb733ad24ae167acf8deb43540917cbb641`.

3. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
   Exit code: 0
   Relevant baseline output: 40/40 tests passed before VF-02 changes.

4. `& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --summary all --global-cache-dir '.zig-cache\vf02-global' -- --output 'zig-out\vf02_baseline\p27b'`
   Exit code: 1
   Relevant baseline output: 9,714 metrics, 24 current-art failures,
   `ProductionCoherenceRejected`.

5. `& '.\.deps\zig-0.16.0\zig.exe' build -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
   Exit code: 0
   Relevant output: Debug build 20/20 steps succeeded; DXIL shaders and eight
   production atlas pages installed.

6. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-registration -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
   Exit code: 0
   Relevant output: 9/9 tests passed.

7. `& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
   Exit code: 0
   Relevant output: 15/15 tests passed.

8. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
   Exit code: 0
   Relevant output: 41/41 tests passed in 37 seconds.

9. The exact production capture driver was:

   ```powershell
   $vf02CaptureRoot = Join-Path (Get-Location) 'zig-out\manual_debug_captures'
   $vf02Before = @()
   if (Test-Path -LiteralPath $vf02CaptureRoot) {
       $vf02Before = @(Get-ChildItem -LiteralPath $vf02CaptureRoot -Directory |
           Select-Object -ExpandProperty Name)
   }
   Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class VF02InputFinal { [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam); }'
   $vf02Process = Start-Process -FilePath '.\zig-out\bin\skeletal_gpu_demo.exe' `
       -ArgumentList @('--demo','foundation','--interactive','--frames','5000') `
       -WorkingDirectory (Get-Location).Path `
       -RedirectStandardOutput 'zig-out\vf02_runtime\final.stdout.txt' `
       -RedirectStandardError 'zig-out\vf02_runtime\final.stderr.txt' `
       -WindowStyle Hidden -PassThru
   $vf02Deadline = [DateTime]::UtcNow.AddSeconds(15)
   while (($vf02Process.MainWindowHandle -eq 0) -and
          ([DateTime]::UtcNow -lt $vf02Deadline)) {
       Start-Sleep -Milliseconds 100
       $vf02Process.Refresh()
   }
   if ($vf02Process.MainWindowHandle -eq 0) {
       throw 'VF-02 production window did not become available'
   }
   $vf02Window = $vf02Process.MainWindowHandle
   function Send-VF02Key([int]$key, [int]$hold = 80) {
       [VF02InputFinal]::PostMessage(
           $vf02Window, 0x100, [IntPtr]$key, [IntPtr]::Zero) | Out-Null
       Start-Sleep -Milliseconds $hold
       [VF02InputFinal]::PostMessage(
           $vf02Window, 0x101, [IntPtr]$key, [IntPtr]::Zero) | Out-Null
       Start-Sleep -Milliseconds 1200
   }
   Start-Sleep -Seconds 2
   Send-VF02Key 0x73
   Send-VF02Key 0x73
   Send-VF02Key 0x51
   Send-VF02Key 0x73
   Send-VF02Key 0x73
   [VF02InputFinal]::PostMessage(
       $vf02Window, 0x100, [IntPtr]0x41, [IntPtr]::Zero) | Out-Null
   Start-Sleep -Milliseconds 700
   Send-VF02Key 0x73
   Send-VF02Key 0x73
   [VF02InputFinal]::PostMessage(
       $vf02Window, 0x101, [IntPtr]0x41, [IntPtr]::Zero) | Out-Null
   Start-Sleep -Milliseconds 500
   Send-VF02Key 0x70
   Send-VF02Key 0x70
   Send-VF02Key 0x70
   Send-VF02Key 0x73
   Send-VF02Key 0x51
   Send-VF02Key 0x73
   Send-VF02Key 0x73
   Send-VF02Key 0x73
   $vf02Process.WaitForExit()
   $vf02After = @()
   if (Test-Path -LiteralPath $vf02CaptureRoot) {
       $vf02After = @(Get-ChildItem -LiteralPath $vf02CaptureRoot -Directory |
           Select-Object -ExpandProperty Name)
   }
   $vf02New = @($vf02After |
       Where-Object { $_ -notin $vf02Before } | Sort-Object)
   Write-Output ('PROCESS_EXIT=' + $vf02Process.ExitCode)
   Write-Output ('CAPTURE_COUNT=' + $vf02New.Count)
   $vf02New
   ```

   Exit code: 0
   Relevant output: process exit 0 and exactly ten new bundles, `_0040`
   through `_0049`.

10. The PowerShell manifest/state validation loop over `_0040` through `_0049`
    recomputed every manifest file hash/size and source-asset hash/size,
    compared manifest and JSON fingerprints, required all clean/debug equality
    flags, counted registered submissions, and checked residual thresholds.
    Exit code: 0
    Relevant output:
    `BUNDLES_VALIDATED=10`, `VALIDATION_FAILURES=0`,
    `registered=26`, `residual_failures=0` for every bundle.

11. `Get-Content -Raw -LiteralPath 'zig-out\vf02_runtime\final.stdout.txt'; Get-Content -Raw -LiteralPath 'zig-out\vf02_runtime\final.stderr.txt'`
    Exit code: 0
    Relevant output: actual SDL GPU driver `direct3d12`; generated shader
    format `DXIL`; eight initialized art pages; 47,187,872 decoded bytes; two
    persistent mesh definitions; ten finalized bundles.

12. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
    Exit code: 1
    Relevant output: 13/15 tests passed. Current baseline found eight failure
    categories; pose/morphology/legacy-wardrobe sweep found 116. Prompt 27C
    and Prompt 27C-R1 art-bound audits passed.

13. `& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
    Exit code: 0
    Relevant output: 16/16 tests passed.

14. `& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
    Exit code: 124 on the first attempt after the 240-second host timeout.
    Relevant output: visual-geometry had already reproduced the same two
    failures. No test process remained.

15. `& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
    Exit code: 1 on the equivalent 600-second retry.
    Relevant output: 406/408 tests passed. Deterministic aggregate 311/311,
    image decode 3/3, wardrobe 16/16, registration 9/9, environment 13/13,
    visual foundation 41/41, and visual geometry 13/15.

16. `& '.\tools\build_p27a_review_package.ps1' -EvidenceDirectory 'zig-out\p27a_evidence\candidate' -OutputDirectory 'zig-out\vf02_p27a_integrity'`
    Exit code: 0
    Relevant output: Prompt 27A 16/16 captures, 263 metrics, zero failures,
    manual acceptance pending.

17. `& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --summary all --global-cache-dir '.zig-cache\vf02-global' -- --output 'zig-out\vf02_current_art\p27b'`
    Exit code: 1
    Relevant output: fresh current art emits 9,714 metrics and retains 24
    failures; `ProductionCoherenceRejected`.

18. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
    Exit code: 0
    Relevant output: 20/20 steps succeeded.

19. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
    Exit code: 0
    Relevant output: 20/20 steps succeeded.

20. `& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all --global-cache-dir '.zig-cache\vf02-global'`
    Exit code: 1
    Relevant output: formatting, repository source policy, GPU ownership,
    historical Prompt audits, Prompt 25D goldens, and 406/408 tests pass.
    Only the same two fail-closed visual-geometry tests fail.

21. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" diff --check`
    Exit code: 0
    Relevant output: no whitespace errors; Git emitted only LF-to-CRLF
    working-copy notices.

22. The focused implementation scan ran `rg --line-number` independently for
    `TODO`, `FIXME`, and `unreachable|testing\.skip|SkipZigTest` across all
    VF-02 code and test paths.
    Exit code: 0 for the wrapper; each `rg` returned 1.
    Relevant output: no matches.

23. `& '.\tools\check_documentation.ps1'`
    Exit code: 0
    Relevant output: 46 required files, 38 Markdown files, and 95 local
    Markdown targets passed.

24. `& '.\tools\check_repository.ps1'`
    Exit code: 0
    Relevant output: 137 implementation files passed; no unfinished markers,
    unreachable paths, skipped tests, alternate renderer, unmatched GPU
    acquisition family, or extra indexed-instanced sprite draw site.

25. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" status --short --branch; git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" diff --cached --name-only; git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" rev-parse HEAD`
    Exit code: 0
    Relevant output: branch `master...origin/master`, 26 modified paths, nine
    untracked paths, zero staged paths, and unchanged HEAD
    `0e9bfcb733ad24ae167acf8deb43540917cbb641`.

Focused test results:

- [PASS] Registration contract and invalid fixtures: 9/9.
- [PASS] Character presentation: 15/15.
- [PASS] VF-01/VF-02 production snapshot and submission: 41/41.
- [PASS] Wardrobe binding regressions: 16/16.
- [PASS] Anatomy, skeleton, foot-planting, IK, controller, interaction,
  allocation, and reset regressions inside the deterministic aggregate:
  311/311.
- [FAIL] Independent current-pixel visual geometry: 13/15.

Aggregate regression results:

- [FAIL] `zig build test`: 406/408. Only the two visual-geometry tests fail.
- [FAIL] `zig build check`: 406/408. Formatting and every static repository
  audit pass; the same pixel-ruler failures propagate.
- [PASS] Debug build: 20/20 steps.
- [PASS] ReleaseSafe build: 20/20 steps.
- [PASS] ReleaseFast build: 20/20 steps.

Actual D3D12/DXIL evidence:

- Production executable returned exit code 0.
- SDL advertised D3D12 and Vulkan and selected `direct3d12`.
- Generated shader format `DXIL` agreed with SDL's selected backend.
- Eight real atlas files decoded to 47,187,872 bytes during initialization.
- Two persistent garment mesh definitions own 12 vertices and 24 indices.
- Bundles:
  - `20260729T222812.380Z_0040`
  - `20260729T222813.692Z_0041`
  - `20260729T222816.284Z_0042`
  - `20260729T222817.587Z_0043`
  - `20260729T222819.611Z_0044`
  - `20260729T222820.916Z_0045`
  - `20260729T222826.632Z_0046`
  - `20260729T222829.263Z_0047`
  - `20260729T222830.567Z_0048`
  - `20260729T222831.875Z_0049`
- `_0042` and `_0043` are controlled female side-right idle.
- `_0044` and `_0045` are controlled female side-left walk.
- `_0046` through `_0049` use All Diagnostics where applicable.
- Every bundle has 26 authoritative registrations and zero structural
  residual failures.

Current-art report results:

- Prompt 27B fresh current art: 9,714 metrics, 24 failures, exit code 1.
- Visual-geometry current baseline: eight failure categories:
  - male/female front shoulder slope and contour;
  - male/female pelvis-to-torso height;
  - male arm length slightly below its band;
  - male forearm width slightly below its band;
  - female upper-arm root width slightly above its band;
  - female foot dark transverse edge.
- Pose/morphology/legacy-wardrobe sweep: 116 failures, including front
  hip-overlap/shoulder-gap findings and legacy side-garment
  landmark/coverage/waist-registration findings.
- These failures are not structural registration residuals and were neither
  removed nor weakened.

Allocation/resource evidence:

- Production runtime:
  `initialized_bytes=131216`, `final_bytes=131216`,
  `update_allocations=0`, `submission_allocations=0`,
  `queue_allocations=0`, `gpu_resource_delta=0`.
- F1 and normal registered submission perform no allocation and create no GPU
  resources.
- Initialization-only alpha scanning releases temporary decode allocations
  immediately.
- F4's explicitly permitted diagnostic allocation/file-I/O boundary remains
  separate from fixed-tick simulation.

Acceptance criteria:

- [PASS] Migrated visuals are placed by atlas-to-rig registration, not merely
  validated afterward.
- [PASS] Production submission, VF-01 overlay, JSON, and structural tests use
  the same emitted registration evidence.
- [PASS] Front, side-right, and side-left use the registration authority.
- [PASS] Required upper arms, forearms, thighs, shins, feet, torso, pelvis,
  and one face point are migrated for both styles.
- [PASS] The hard-coded front-foot `+/-78` degree placement rotation is
  removed; remaining adjustment is explicit binding data.
- [PASS] Missing, invalid, degenerate, swapped, bypassed, reflected, residual,
  thickness-anchor, and semantic-swap fixtures fail closed.
- [PASS] Fresh D3D12/DXIL bundles prove zero structural residual for all
  migrated components and validate clean/debug state identity.
- [PASS] Steady-state allocation and resource guarantees remain intact.
- [PASS] Historical evidence remains unchanged; Prompt 27A validates from its
  preserved candidate into a separate VF-02 output.
- [FAIL] Required aggregate tests and `zig build check` do not pass because
  the independent current production-art pixel ruler reports two failing
  tests.
- [PENDING OWNER REVIEW] Manual visual acceptance.
- [PASS] VF-03 and Prompt 28 were not started.
- Evidence: focused structural suites, aggregate summary, fresh Prompt 27B
  output, D3D runtime log, bundles `_0040` through `_0049`, and independent
  bundle hash/state validation described above.

Known limitations:

- The bounded migration does not include hands, head, all face features, hair,
  or wardrobe; those paths remain explicitly transitional or compatibility
  placements.
- Mesh/bridge binding is a validated schema boundary, not a broad production
  garment migration.
- Current source art retains silhouette, proportion, continuity, and
  dark-edge findings even when structural landmarks register exactly.
- Timestamped bundles are diagnostic candidates and not approved goldens.

Unresolved failures:

- `test-visual-geometry`: 13/15, with eight current baseline categories and
  116 pose/morphology/legacy-wardrobe findings.
- `zig build test`: 406/408 because of those same two tests.
- `zig build check`: 406/408 because of those same two tests.
- Prompt 27B current art: 9,714 metrics and 24 front-foot endpoint-height
  failures.
- Consequently VF-02 is not declared complete under the repository contract,
  even though its focused structural, runtime, allocation, and evidence scope
  passes.

No-placeholder audit:

- TODO matches: 0.
- FIXME matches: 0.
- Stub/placeholder findings: 0. The repository policy audit reports no
  unfinished markers, unreachable paths, or fake implementation patterns.
- Disabled or skipped tests: 0. No test was removed, renamed out of discovery,
  weakened, disabled, or skipped.

Final Git status:

```text
## master...origin/master
 M build.zig
 M docs/ANATOMY.md
 M docs/ARCHITECTURE.md
 M docs/CHARACTER_PRESENTATION.md
 M docs/CONTROLS.md
 M docs/DIAGNOSTICS.md
 M docs/MESH_ATTACHMENTS.md
 M docs/TESTING.md
 M docs/VISUAL_GEOMETRY.md
 M docs/project/ARCHITECTURE_MAP.md
 M docs/project/CURRENT_STATE.md
 M docs/project/KNOWN_GAPS.md
 M docs/prompts/INDEX.md
 M docs/reports/prompt-implementation-reports/INDEX.md
 M src/debug/debug_draw.zig
 M src/graphics/gpu_demo.zig
 M src/platform/input.zig
 M src/platform/sdl_input.zig
 M src/scene/character_art.zig
 M src/scene/foundation_coherence.zig
 M src/scene/foundation_coherence_report.zig
 M src/scene/visual_foundation.zig
 M src/scene/visual_geometry.zig
 M src/scene/wardrobe_presentation.zig
 M tests/visual_foundation_tests.zig
 M tools/check_repository.ps1
?? docs/VF01_DECISION_RECORD.md
?? docs/VF02_DECISION_RECORD.md
?? docs/prompts/VF-01-visual-truth-debugger.md
?? docs/prompts/VF-02-authoritative-rig-to-art-registration.md
?? docs/reports/prompt-implementation-reports/exact/VF-01-implementation-report.md
?? docs/reports/prompt-implementation-reports/exact/VF-02-implementation-report.md
?? src/debug/visual_truth.zig
?? src/scene/visual_registration.zig
?? tests/visual_registration_tests.zig
```

Staged paths: 0. HEAD remains
`0e9bfcb733ad24ae167acf8deb43540917cbb641`. No Git history or evidence path
was reset, restored, cleaned, deleted, discarded, staged, or committed.

---

# Owner-Review Corrective Addendum — 2026-07-30

This addendum preserves the initial VF-02 report above as the record of the
owner-review finding. It supersedes only that report's completion verdict,
current-art result, and shoe-authority description. No historical report,
capture, candidate, or golden was overwritten.

IMPLEMENTATION REPORT

Scope completed:

- Baseline HEAD remained
  `0e9bfcb733ad24ae167acf8deb43540917cbb641`; staged paths remained zero.
- Removed the surviving exact `+/-78` degree front-shoe branch from
  `wardrobe_presentation.restRotation`.
- Made `crimson_strap_shoe` an authoritative point registration. Its
  alpha-derived ankle maps to the exact registered anatomy-foot ankle. Its
  authored sole axis maps to an orientation target derived from the registered
  foot's transformed sole evidence: support-plane direction in front and
  registered sole direction at the side.
- Preserved the base foot's limited contract. It constrains only the projected
  ankle; authored heel-to-toe landmarks plus explicit 16-degree male /
  13-degree female toe-out data compute orientation. Heel, toe, sole-back, and
  sole-front remain transformed evidence rather than target endpoints.
- Restored the preserved front base-foot result after detecting an accidental
  shared 12-degree corrective value: athletic male `+/-75.8113` degrees and
  curvy female `+/-79.2672` degrees in the final D3D evidence.
- Kept one exact final shoe request across production queue, registration
  trace, VF-01 JSON/overlay, and visual-geometry validation. The validation
  gate recomputes the shoe ankle transform and rejects an authority, request,
  source, target, point-count, or residual disagreement.
- Added an initialization-only six-case proof selector for body/equipped
  front, side-left, and side-right. It sets both the controlled character's
  authoritative controller facing and the passive character's facing before
  simulation. It cannot run after the first simulation tick and creates no
  `CharacterIntent`.
- Preserved the initial `_0040` through `_0049` bundles as historical evidence.
  Their four shoes remain correctly labeled `compatibility_adapter`; they are
  not cited as proof of the correction.
- Produced and validated the final corrective D3D12/DXIL set:
  `_0060` body-front, `_0058` body-side-left, `_0054` body-side-right,
  `_0061` equipped-front, `_0059` equipped-side-left, and `_0057`
  equipped-side-right.
- Kept the pre-correction 9,714-metric/24-failure Prompt 27B report. A separate
  fresh report now contains 9,714 metrics and zero failures; all 24 front
  endpoint-height rows are exactly `0.0 px`.
- VF-03 and Prompt 28 were not started.

Files created:

- No new tracked file was created by the owner-review correction.
- New untracked runtime evidence was written only below
  `zig-out/manual_debug_captures/` and `zig-out/vf02_corrective/`.
- The VF-01/VF-02 files listed in the initial report remain inherited
  untracked working-tree files; they were not recreated or replaced.

Files modified:

- Corrective production/policy code:
  `src/scene/character_art.zig`,
  `src/scene/wardrobe_catalog.zig`,
  `src/scene/wardrobe_presentation.zig`,
  `src/scene/visual_geometry.zig`,
  `src/scene/visual_geometry_audit.zig`.
- Corrective production proof route:
  `src/main.zig`, `src/graphics/gpu_demo.zig`,
  `src/scene/visual_foundation.zig`.
- Corrective tests:
  `tests/wardrobe_tests.zig`, `tests/visual_geometry_tests.zig`,
  `tests/visual_foundation_tests.zig`.
- Corrective documentation:
  `docs/ARCHITECTURE.md`, `docs/CHARACTER_PRESENTATION.md`,
  `docs/CONTROLS.md`, `docs/DIAGNOSTICS.md`, `docs/TESTING.md`,
  `docs/VISUAL_GEOMETRY.md`, `docs/VF02_DECISION_RECORD.md`,
  `docs/project/ARCHITECTURE_MAP.md`, `docs/project/CURRENT_STATE.md`,
  `docs/project/KNOWN_GAPS.md`, `docs/prompts/INDEX.md`,
  `docs/prompts/VF-02-authoritative-rig-to-art-registration.md`, and this
  report.

Architecture confirmed:

- The authoritative controller/collider, canonical pose, presentation
  projection, anatomy/appearance topology, atlas metadata, global queue,
  D3D12 renderer/readback, and acceptance evidence remain separate domains.
- Base and shoe placement both use the shared `visual_registration` solver,
  but they do not claim the same endpoint contract. The base target is one
  ankle plus explicit point-orientation data. The shoe target is one ankle
  plus an orientation axis derived from the registered base-foot evidence.
- The whole-character ground correction still translates the production
  request and registration evidence together; it cannot hide a structural
  residual.
- Normal capture-inactive execution remains allocation-free and resource
  stable. F4 retains its explicitly bounded diagnostic allocation/file-I/O
  boundary.

Architecture discrepancies found:

- Owner review correctly found that the initial VF-02 result had two final
  orientation owners: registered base anatomy and a wardrobe compatibility
  `+/-78` degree shoe rotation.
- Evidence inspection found that the first proof selector changed the female
  presentation-facing field without changing her authoritative controller
  facing. The next fixed tick restored right-facing. The selector now sets
  both authorities before simulation, and its test advances a real frame.
- Reconciliation against `_0040` found that an intermediate correction had
  accidentally replaced the preserved style-specific point-orientation data
  with a shared 12-degree value. The final code restores explicit 16/13 data
  and directly tests it.

Commands executed:

1. `& '.\.deps\zig-0.16.0\zig.exe' version`
   Exit code: 0.
   Relevant output: `0.16.0`.

2. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" rev-parse HEAD`
   and complete staged/unstaged/untracked status inspection.
   Exit code: 0.
   Relevant output: baseline
   `0e9bfcb733ad24ae167acf8deb43540917cbb641`; staged paths 0.

3. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-registration -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global'`
   Exit code: 0.
   Relevant output: 9/9 tests passed.

4. `& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global'`
   Exit code: 0.
   Relevant output: 15/15 tests passed.

5. `& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global'`
   Exit code: 0.
   Relevant output: 17/17 tests passed; exact toe-out policy, registered ankle,
   horizontal front sole, queue/trace request identity, and point-contract
   classification passed.

6. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global'`
   Exit code: 0.
   Relevant output: 42/42 tests passed, including the six proof cases before
   and after a real frame and fail-closed post-simulation application.

7. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global'`
   Exit code: 0.
   Relevant output: 15/15 tests, Prompt 27C focused production geometry
   162/162, and pose/morphology geometry 6,426/6,426 passed. Printed
   Prompt 27C baseline lines are controlled historical observations.

8. `& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global' -- --output 'zig-out\vf02_corrective\p27b_authoritative_shoe_final3'`
   Exit code: 0.
   Relevant output: 9,714 metrics, zero failures. Independent JSON inspection
   found 24 front endpoint-height rows, zero failures, minimum `0`, maximum
   `0`.

9. `& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global'`
   Exit code: 0.
   Relevant output: 411/411 tests passed.

10. `& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global'`
    Exit code: 0.
    Relevant output: 21/21 steps and 411/411 tests passed; Zig formatting,
    repository source policy, Prompt audits, art audits, and 12/12 approved
    historical Prompt 25D goldens passed.

11. `& '.\.deps\zig-0.16.0\zig.exe' build -j1 --summary all --cache-dir '.zig-cache\vf02-corrective' --global-cache-dir '.zig-cache\vf02-corrective-global'`
    Managed-sandbox exit code: 1.
    Relevant output: Windows host/cache failure,
    `manifest_create AccessDenied` / missing Clang diagnostics; this was an
    environment failure, not a project diagnostic.
    The exact equivalent command was retried outside the sandbox with the same
    task-local caches.
    Retry exit code: 0.
    Relevant output: 20/20 Debug build steps passed.

12. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1 --summary all --cache-dir '.zig-cache\vf02-corrective-release-safe' --global-cache-dir '.zig-cache\vf02-corrective-global'`
    Exit code: 0.
    Relevant output: 20/20 steps passed.

13. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1 --summary all --cache-dir '.zig-cache\vf02-corrective-release-fast' --global-cache-dir '.zig-cache\vf02-corrective-global'`
    Exit code: 0.
    Relevant output: 20/20 steps passed.

14. `& '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1 --summary all --cache-dir '.zig-cache\vf02-corrective-gpu' --global-cache-dir '.zig-cache\vf02-corrective-global'`
    Exit code: 0.
    Relevant output: 22/22 steps passed; actual SDL driver `direct3d12`,
    generated format `DXIL`, 640x480 readback, two instances in one indexed
    instanced draw, and every fault-injection cleanup checkpoint passed.

15. `& '.\tools\build_p27a_review_package.ps1' -EvidenceDirectory 'zig-out\p27a_evidence\candidate' -OutputDirectory 'zig-out\vf02_corrective\p27a_integrity'`
    Exit code: 0.
    Relevant output: Prompt 27A 16/16 captures, 263 metrics, zero failures,
    manual acceptance pending.

16. The production capture driver launched
    `.\zig-out\bin\skeletal_gpu_demo.exe --demo foundation --interactive --frames 1000 --registration-proof-case <case>`,
    waited for the persistent-mesh initialization log, and posted one F4
    press/release to the real SDL window.
    Exit code: 0 for every final selected case.
    Relevant output: actual `direct3d12` / `DXIL`; one complete atomic bundle
    per case; no OS screenshot path.

17. The PowerShell validation loop over `_0060`, `_0058`, `_0054`, `_0061`,
    `_0059`, and `_0057` reparsed JSON, recomputed every manifest-listed file
    and source-asset SHA-256/size, and checked frame, tick, state, and common
    fingerprint equality.
    Exit code: 0.
    Relevant output: all six valid; body frames 26 registered/0 shoes;
    equipped frames 30 registered/4 authoritative shoes; maximum residual
    `0.000000119 m`; direct3d12/DXIL throughout.

18. `& '.\tools\check_documentation.ps1'`
    Exit code: 0.
    Relevant output: 46 required files, 38 Markdown files, and 95 local
    Markdown targets passed.

19. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" diff --check`
    Exit code: 0.
    Relevant output: no whitespace errors; Git emitted only the repository's
    LF-to-CRLF working-copy notices.

20. Focused `rg --line-number` scans for `TODO`, `FIXME`,
    `unreachable|testing\.skip|SkipZigTest`, and hard-coded 78-degree foot
    placement patterns, plus staged/asset/golden status checks.
    Exit code: 0.
    Relevant output: zero matches, zero staged paths, and zero modified
    `assets/` or `tests/goldens/` paths.

Acceptance criteria:

- [PASS] Prompt 27B has zero front sole-endpoint-height failures.
  Evidence: 9,714 metrics, zero total failures, 24/24 endpoint rows at
  exactly `0.0 px`.
- [PASS] `test-visual-geometry`, aggregate `test`, and `check` pass.
  Evidence: 15/15, 411/411, and 21/21 steps with 411/411.
- [PASS] Production, diagnostics, JSON, and validation report the same final
  shoe transform.
  Evidence: queue/trace identity test, authoritative JSON requests,
  recomputed transformed ankle/sole evidence, and zero registration residual.
- [PASS] No hard-coded `+/-78` front shoe placement remains.
  Evidence: focused source scan contains no 78-degree foot placement literal;
  `restRotation` has no foot case.
- [PASS] Base foot remains ankle-only `point_authored`.
  Evidence: point count 1/source ankle; 16/13 orientation data; heel/toe/sole
  exported only as transformed evidence.
- [PASS] Fresh real D3D12/DXIL bundles cover male/female front, side-left,
  side-right, body-only, and equipped-foot presentation.
- [PASS] Historical evidence remains untouched and the original 24-failure
  report remains preserved.
- [PASS] Debug, ReleaseSafe, ReleaseFast, GPU smoke, Prompt 27A integrity,
  allocation, and resource checks pass.
- [PENDING OWNER REVIEW] Manual visual acceptance. No bundle is promoted to a
  golden and no aesthetic approval is claimed.
- [PASS] VF-03 and Prompt 28 were not started.

Known limitations:

- Neither the base foot nor the shoe is full endpoint registration. Heel, toe,
  sole-back, and sole-front are transformed evidence; the unchanged Prompt 27B
  contact ruler validates the final visible envelope independently.
- Non-shoe wardrobe remains a compatibility adapter, and unmigrated base
  visuals remain transitional where documented.
- Current source art still has aesthetic/registration-overlay disagreements
  visible in F1/manual summaries. Automated structural/contact success is not
  owner visual approval.
- F4 may perform bounded diagnostic allocations and synchronous file I/O.
  Only capture-inactive steady state is guaranteed allocation-free.

Unresolved failures:

- None in the required automated VF-02 correction gates.
- Manual visual acceptance remains `[PENDING OWNER REVIEW]`.

No-placeholder audit:

- TODO matches: 0 in audited implementation files.
- FIXME matches: 0 in audited implementation files.
- Stub/placeholder findings: 0; repository source policy passed.
- Disabled or skipped tests: 0; no test was removed, renamed out of
  discovery, weakened, disabled, or skipped.

Final Git status:

```text
 M build.zig
 M docs/ANATOMY.md
 M docs/ARCHITECTURE.md
 M docs/CHARACTER_PRESENTATION.md
 M docs/CONTROLS.md
 M docs/DIAGNOSTICS.md
 M docs/MESH_ATTACHMENTS.md
 M docs/TESTING.md
 M docs/VISUAL_GEOMETRY.md
 M docs/project/ARCHITECTURE_MAP.md
 M docs/project/CURRENT_STATE.md
 M docs/project/KNOWN_GAPS.md
 M docs/prompts/INDEX.md
 M docs/reports/prompt-implementation-reports/INDEX.md
 M src/debug/debug_draw.zig
 M src/graphics/gpu_demo.zig
 M src/main.zig
 M src/platform/input.zig
 M src/platform/sdl_input.zig
 M src/scene/character_art.zig
 M src/scene/foundation_coherence.zig
 M src/scene/foundation_coherence_report.zig
 M src/scene/visual_foundation.zig
 M src/scene/visual_geometry.zig
 M src/scene/visual_geometry_audit.zig
 M src/scene/wardrobe_art.zig
 M src/scene/wardrobe_catalog.zig
 M src/scene/wardrobe_demo.zig
 M src/scene/wardrobe_presentation.zig
 M tests/visual_foundation_tests.zig
 M tests/visual_geometry_tests.zig
 M tests/wardrobe_tests.zig
 M tools/check_repository.ps1
?? docs/VF01_DECISION_RECORD.md
?? docs/VF02_DECISION_RECORD.md
?? docs/prompts/VF-01-visual-truth-debugger.md
?? docs/prompts/VF-02-authoritative-rig-to-art-registration.md
?? docs/reports/prompt-implementation-reports/exact/VF-01-implementation-report.md
?? docs/reports/prompt-implementation-reports/exact/VF-02-implementation-report.md
?? src/debug/visual_truth.zig
?? src/scene/visual_registration.zig
?? tests/visual_registration_tests.zig
```

Staged paths: 0. HEAD remains
`0e9bfcb733ad24ae167acf8deb43540917cbb641`. No Git history, source-art asset,
historical report, evidence path, or golden was reset, restored, cleaned,
deleted, discarded, staged, committed, or overwritten.

## Owner-review point-axis and visible-envelope corrective addendum

This addendum supersedes the earlier corrective interpretation above without
deleting it. Owner review exposed that removing the exact wardrobe `+/-78`
degree branch was necessary but insufficient: the earlier base-foot
`point_authored` orientation still treated physical ground-plane depth as
world Y and produced approximately `+/-75.8` / `+/-79.3` degree front sprite
rotations. Those values are not retained as valid front registration policy.

IMPLEMENTATION REPORT

Scope completed:

- Baseline HEAD:
  `0e9bfcb733ad24ae167acf8deb43540917cbb641`.
- Initial Git status for this corrective continuation: 33 modified paths,
  nine untracked paths, zero staged paths. All were preserved.
- Strengthened front anatomy-foot placement to `point_axis`: one positional
  ankle target plus one authored `sole_back -> sole_front` orientation axis.
- Retained the explicit physical toe-out policy as male 16 degrees / female
  13 degrees with lateral and depth components. Front projection maps only
  signed lateral to the horizontal support tangent and never maps physical
  depth to world Y.
- Removed the second wardrobe orientation formula. Shoes consume the exact
  stored anatomy-foot `PointAxisTarget`, and front shoes use the registered
  foot's full authored transverse scale.
- Added explicit closed-footwear visible-envelope ownership. Equipped shoes
  suppress covered base-foot pixels while the base-foot registration,
  landmarks, alpha bounds, and owner/exposed-anchor metadata remain in the
  trace and schema-3 JSON.
- Kept heel, toe, sole-back, and sole-front as transformed evidence. They are
  not independent target endpoints, and this report does not claim full
  endpoint registration.
- Updated production submission, diagnostics, JSON, the coherence report, and
  visual-geometry validation to consume the same final shoe request and
  visibility classification.
- Added direct tests for the point-axis solver, front body-foot projection,
  queue/trace/shoe identity, closed-footwear equip/unequip/view/facing
  lifecycle, schema-3 orientation/visibility export, and fail-closed
  validation.
- Preserved all source art, historical Prompt 27/27A/27B/27C/27C-R1
  evidence, rejected candidates, approved goldens, thresholds, camera,
  support surfaces, fixed-tick behavior, and the R1 measure/enforce policy.

Files created:

- None in this owner-review corrective increment.

Files modified:

- `build.zig`
- `src/debug/visual_truth.zig`
- `src/scene/character_art.zig`
- `src/scene/foundation_coherence.zig`
- `src/scene/foundation_coherence_report.zig`
- `src/scene/visual_foundation.zig`
- `src/scene/visual_geometry.zig`
- `src/scene/visual_geometry_audit.zig`
- `src/scene/visual_registration.zig`
- `src/scene/wardrobe_catalog.zig`
- `src/scene/wardrobe_demo.zig`
- `src/scene/wardrobe_presentation.zig`
- `tests/visual_foundation_tests.zig`
- `tests/visual_registration_tests.zig`
- `tests/wardrobe_tests.zig`
- `docs/ANATOMY.md`
- `docs/ARCHITECTURE.md`
- `docs/CHARACTER_PRESENTATION.md`
- `docs/CONTROLS.md`
- `docs/DIAGNOSTICS.md`
- `docs/TESTING.md`
- `docs/VISUAL_GEOMETRY.md`
- `docs/VF02_DECISION_RECORD.md`
- `docs/project/ARCHITECTURE_MAP.md`
- `docs/project/CURRENT_STATE.md`
- `docs/project/KNOWN_GAPS.md`
- `docs/prompts/VF-02-authoritative-rig-to-art-registration.md`
- `docs/reports/prompt-implementation-reports/INDEX.md`
- this implementation report

Architecture confirmed:

- Controller/collider state, canonical pose, view projection, component
  topology, atlas metadata, final queue submissions, automated evidence, and
  owner approval remain distinct authorities.
- `visual_registration.solvePointAxis` creates both anatomy-foot and shoe
  requests and their orientation evidence before production submission.
- `wardrobe_demo` resolves coverage before anatomy submission, so a closed
  shoe is the single rendered foot-envelope owner without deactivating or
  deleting the anatomy foot.
- Whole-character ground alignment translates rendered requests and hidden
  registration evidence together. Suppressed records are excluded from
  visible bounds and outermost-visible-foot selection.
- Schema 3 exports the same request, registration axis, submission
  visibility, coverage owner, and exposed ankle that production and
  validation use.
- Normal capture-inactive execution remains fixed-capacity and
  allocation-free. The correction creates no GPU resource and no second
  renderer or submission path.

Architecture discrepancies found:

- The earlier base-foot orientation result was not a valid front projection:
  physical ground-plane depth had become world Y, creating near-vertical
  `+/-75.8` / `+/-79.3` degree requests after the literal `+/-78` branch was
  gone.
- The former ankle-only point evidence could not prove which system owned
  orientation. `point_axis` now makes the orientation constraint explicit.
- Rendering both registered base-foot pixels and closed-shoe pixels left two
  visible-envelope owners. Typed suppression now makes coverage explicit
  without hiding the underlying evidence.
- An intermediate local candidate multiplied front shoe thickness by `0.10`.
  Visual inspection exposed the compressed silhouette; that multiplier was
  removed before final evidence. Final shoes inherit the full registered
  anatomy-foot transverse scale.

Commands executed:

1. `& '.\.deps\zig-0.16.0\zig.exe' version`
   Exit code: 0.
   Relevant output: `0.16.0`.

2. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" rev-parse HEAD`
   plus complete staged, unstaged, and untracked status inspection.
   Exit code: 0.
   Relevant output:
   `0e9bfcb733ad24ae167acf8deb43540917cbb641`; zero staged paths.

3. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-registration -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
   Exit code: 0.
   Relevant output: 11/11 tests passed.

4. `& '.\.deps\zig-0.16.0\zig.exe' build test-presentation -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
   Exit code: 0.
   Relevant output: 15/15 tests passed.

5. `& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
   Exit code: 0.
   Relevant output: 19/19 tests passed.

6. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
   Exit code: 0.
   Relevant output: 42/42 tests passed.

7. `& '.\.deps\zig-0.16.0\zig.exe' build test-visual-geometry -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
   Exit code: 0.
   Relevant output: 15/15 tests, 196/196 production geometry checks, and
   6,954/6,954 pose/morphology checks passed. Printed Prompt 27C baseline
   observations remain historical controlled evidence.

8. `& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global' -- --output 'zig-out\vf02_manual_corrective\p27b_point_axis_coverage_final2'`
   Exit code: 0.
   Relevant output: 9,752 metrics, zero failures. Independent JSON inspection
   found 24 front sole-endpoint-height rows, zero failures, minimum `0`,
   maximum `0`.

9. `& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
   First host attempt exit code: 124 after 240 seconds.
   Relevant output: host timeout after the visual-geometry component had
   passed; no failing assertion or compiler diagnostic.
   Exact warmed-cache retry exit code: 0.
   Relevant output: 15/15 steps and 417/417 tests passed.

10. `& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
    Exit code: 0.
    Relevant output: 21/21 steps and 417/417 tests passed; formatting,
    repository source policy, Prompt audits, art audits, resource ownership,
    and 12/12 approved Prompt 25D goldens passed.

11. `& '.\.deps\zig-0.16.0\zig.exe' build -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
    Managed-sandbox exit code: 1.
    Relevant output: `manifest_create AccessDenied`, classified as a Windows
    host/cache ACL failure rather than a project diagnostic.
    Exact same-cache retry outside the sandbox exit code: 0.
    Relevant output: 20/20 Debug build steps passed.

12. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective-release-safe' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
    Exit code: 0.
    Relevant output: 20/20 ReleaseSafe build steps passed.

13. `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective-release-fast' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
    Exit code: 0.
    Relevant output: 20/20 ReleaseFast build steps passed.

14. `& '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1 --summary all --cache-dir '.zig-cache\vf02-manual-corrective-gpu' --global-cache-dir '.zig-cache\vf02-manual-corrective-global'`
    Exit code: 0.
    Relevant output: 22/22 steps; real `direct3d12`, generated `DXIL`,
    640x480 readback, two instances in one indexed-instanced draw, and every
    fault-injection cleanup checkpoint passed.

15. `& '.\tools\build_p27a_review_package.ps1' -EvidenceDirectory 'zig-out\p27a_evidence\candidate' -OutputDirectory 'zig-out\vf02_manual_corrective\p27a_integrity'`
    Exit code: 0.
    Relevant output: 16/16 Prompt 27A captures, 263 metrics, zero failures,
    manual acceptance pending.

16. The bounded production capture driver launched
    `.\zig-out\bin\skeletal_gpu_demo.exe --demo foundation --interactive --frames 5000 --registration-proof-case <case>`,
    waited for persistent mesh initialization, posted one F4 press/release,
    waited for atomic finalization, and closed the SDL window cleanly.
    Exit code: 0 for the six final cases.
    Relevant output: `_0068` body-front, `_0069` body-side-left, `_0070`
    body-side-right, `_0071` equipped-front, `_0072` equipped-side-left, and
    `_0073` equipped-side-right; real D3D12/DXIL throughout.
    One earlier side-right window missed its F4 edge and was terminated
    without promoting an incomplete bundle.

17. The PowerShell validation loop over `_0068` through `_0073` reparsed
    schema-3 JSON, recomputed every manifest-listed SHA-256 and byte size, and
    checked clean/debug frame, tick, state, and common-fingerprint equality.
    Exit code: 0.
    Relevant output: all six valid; body cases have four rendered anatomy feet
    and no shoes; equipped cases have four rendered authoritative shoes and
    four suppressed registered base-foot records. Front shoe rotations and
    sole-axis height deltas are zero.

18. `& '.\tools\check_documentation.ps1'`
    Exit code: 0.
    Relevant output: 46 required files, 38 Markdown files, and 95 local
    Markdown targets passed.

19. Focused `rg --line-number` scans for `TODO`, `FIXME`,
    `testing\.skip|SkipZigTest`, hard-coded 78-degree foot placement, and the
    rejected intermediate shoe-depth multiplier; staged/asset/golden status
    checks; and
    `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" diff --check`.
    Exit code: 0.
    Relevant output: zero TODO/FIXME/skipped-test/78-degree/depth-multiplier
    matches; zero staged, asset, or golden paths; no whitespace errors. Git
    emitted only LF-to-CRLF working-copy notices.

20. Final `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" status --short`
    inspection.
    Exit code: 0.
    Relevant output: 33 modified, nine untracked, zero staged paths.

Acceptance criteria:

- [PASS] Prompt 27B has zero front sole-endpoint-height failures.
  Evidence: 9,752 metrics, zero total failures, 24/24 endpoint rows exactly
  `0.0 px`; the `[-0.5, 1.5] px` endpoint range is unchanged.
- [PASS] `test-visual-geometry`, aggregate `test`, and `check` pass.
  Evidence: 15/15, 417/417, and 21/21 steps with 417/417.
- [PASS] Production, diagnostics, JSON, and validation report the same final
  shoe transform.
  Evidence: queue/trace identity tests; schema-3 requests; shared axis
  identity; zero solver residual; manifest-valid `_0071`.
- [PASS] No hard-coded `+/-78` front shoe placement remains.
  Evidence: `restRotation` has no foot branch and the focused literal scan is
  empty.
- [PASS] The strengthened base-foot contract remains precise.
  Evidence: one positional ankle target plus one sole-axis orientation
  constraint; heel/toe/sole landmarks are transformed evidence, not
  independent targets.
- [PASS] Fresh real D3D12/DXIL bundles cover both styles in front, side-left,
  and side-right, including body-only and equipped-foot evidence.
- [PASS] Historical evidence remains untouched and both the preserved
  24-failure report and new zero-failure report remain honestly classified.
- [PASS] Debug, ReleaseSafe, ReleaseFast, GPU smoke, Prompt 27A integrity,
  allocation, and resource checks pass.
- [PENDING OWNER REVIEW] Manual visual acceptance. No bundle is promoted to a
  golden and no aesthetic approval is claimed.
- [PASS] VF-03 and Prompt 28 were not started.

Known limitations:

- Neither the base foot nor the shoe has independent heel/toe/sole endpoint
  targets. Prompt 27B remains the fail-closed final-pixel contact ruler.
- The physical front toe-out policy retains depth for provenance, but the 2D
  front projection has no screen-space depth axis; it displays the signed
  lateral component on a horizontal support tangent.
- Hidden registered anatomy sole evidence can lie below the shoe envelope.
  It is exported as hidden evidence and is not misreported as a visible or
  independently registered endpoint.
- Non-shoe wardrobe remains a compatibility adapter, and current source-art
  aesthetic disagreements remain visible in F1/manual summaries.
- F4 may perform bounded diagnostic allocations and synchronous file I/O.
  Capture-inactive steady state remains allocation-free.

Unresolved failures:

- None in the required automated VF-02 corrective gates.
- Manual visual acceptance remains `[PENDING OWNER REVIEW]`.

No-placeholder audit:

- TODO matches: 0 in audited implementation files.
- FIXME matches: 0 in audited implementation files.
- Stub/placeholder findings: 0; repository source policy passed over 137
  files.
- Literal code-path `unreachable`: one pre-existing, permitted exhaustive-loop
  invariant in `presentation_pose.zig`, with the formal explanation required
  by `AGENTS.md`; repository source policy passed it.
- Disabled or skipped tests: 0; no test was removed, renamed out of
  discovery, weakened, disabled, or skipped.

Final Git status:

- 33 modified paths, nine untracked paths, zero staged paths.
- HEAD remains `0e9bfcb733ad24ae167acf8deb43540917cbb641`.
- No Git write, cleanup, reset, restore, source-art edit, golden promotion, or
  historical-evidence overwrite occurred.
