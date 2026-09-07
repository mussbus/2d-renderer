Prompt 25C is complete as a measuring system. The validator passes its own correctness and regression tests, while the unchanged Prompt-25B production character intentionally reports **62 quantitative visual-geometry failures**. Prompt 26 was not started.

## A. VALIDATION ARCHITECTURE

Implemented a bounded semantic visual-geometry layer in [visual_geometry.zig](</C:/Users/Chad/Documents/2d Renderer/src/scene/visual_geometry.zig>):

- Typed anatomy, garment, footwear, glove, sleeve, legwear, and headwear landmarks.
- Stable local visual-space landmarks relative to visible alpha geometry.
- Opaque bounds, centroid, width, height, and mask queries derived from production atlas pixels.
- Explicit left/right semantic identity and anatomy binding IDs.
- Data-driven registration, orientation, size, clearance, and coverage contracts.
- Fixed-capacity trace and metric collections.
- Acceptance-camera pixel-space continuity measurements.

Landmarks use the exact production sprite transform exposed by [sprite_batch.zig](</C:/Users/Chad/Documents/2d Renderer/src/graphics/sprite_batch.zig>): pivot, signed scale/mirroring, rotation, translation, projection, and inverse alpha sampling. There is no parallel test-only transform or second renderer.

Character anatomy and wardrobe submission now optionally emit traces containing the exact `SpriteRequest` submitted to the existing global queue. Normal production submission remains unchanged.

The architecture and threshold rationale are documented in [VISUAL_GEOMETRY.md](</C:/Users/Chad/Documents/2d Renderer/docs/VISUAL_GEOMETRY.md>).

## B. NEW TESTS / AUDITS

The focused `test-visual-geometry` command contains eight passing tests covering:

- Alpha-visible bounds excluding transparent padding.
- Exact production transform and inverse-transform agreement.
- Good orientation passing and a backwards axis failing at 180°.
- Correct fit passing and deliberately undersized fit failing.
- Structured text/JSON diagnostics and unapproved/matching/changed golden states.
- Semantic left/right identity independent of scale sign.
- Natural rejection of the current Prompt-25B shoes, garments, and articulation.
- Production pose/morphology sweeps without queue or character-submission allocations.

The sweep includes:

- Male and female profiles.
- Front, side-right, and side-left presentations.
- Neutral, walk phases 0/25/50/75%, knee bends, jump compression/rise/fall, and landing.
- Low/nominal/high build and representative shoulder, hip, limb thickness, hand, and foot morphology values.

The existing weaker footwear test was retained but accurately renamed to say it proves mirrored submission metadata—not visual registration.

## C. CURRENT PROMPT-25B FAILURES

The exhaustive 129-metric report contains **67 passes and 62 failures**:

- [Human-readable report](</C:/Users/Chad/Documents/2d Renderer/zig-out/p25c_visual_geometry/current_prompt25b_failures.txt>)
- [Machine-readable JSON](</C:/Users/Chad/Documents/2d Renderer/zig-out/p25c_visual_geometry/current_prompt25b_failures.json>)

Key current failures:

| Component | Measurement | Current result | Contract |
|---|---:|---:|---:|
| Left shoe | ankle / heel / toe error | 5.027 / 5.950 / 52.141 px | ≤ 2 px |
| Left shoe | forward / sole angle | 174.310° / 180.000° | ≤ 5° |
| Left shoe | length / coverage / off-target | 1.651 / 0.515 / 0.636 | 0.95–1.15 / ≥0.90 / ≤0.15 |
| Right shoe | ankle / heel / toe error | 13.186 / 23.869 / 34.224 px | ≤ 2 px |
| Right shoe | forward / sole angle | 174.310° / 180.000° | ≤ 5° |
| Right shoe | length / coverage / off-target | 1.651 / 0.613 / 0.578 | 0.95–1.15 / ≥0.90 / ≤0.15 |
| Halter top | landmark error | 11.727 px | ≤ 2 px |
| Halter top | shoulder / waist fit | 0.603 / 0.844 | 0.96–1.08 |
| Halter top | torso coverage | 0.391 | ≥ 0.90 |
| Shorts | waist fit | 0.868 | 0.96–1.08 |
| Shorts | left/right leg openings | 17.428 / 19.513 px | ≤ 2 px |
| Shorts | pelvis coverage | 0.401 | ≥ 0.90 |
| Thigh-highs | registration | 9.638 px each | ≤ 2 px |
| Thigh-highs | coverage | 0.298 / 0.304 | ≥ 0.90 |
| Headwear | registration | 26.632 px | ≤ 2 px |

Articulation failures include:

- Male elbow overlap depth: 7.416/7.616 px; allowed ≤5 px.
- Female elbow semantic error: 5.035 px per side; allowed ≤2 px.
- Female elbow overlap: 9.165/9.539 px.
- Male ankle error: 5.530 px; female: 9.031 px.
- Knee/ankle visible overlap depths range from 8.307–11.446 px.
- Bilateral symmetry errors reach 11.809 px male-hand, 12.389 px female-hand, and 14.103 px footwear.

The validator does not trivially reject everything: torso and limb axes, opposite-foot crossing, hip width, off-target garment fractions, hand/forearm ratios, and the principal limb-to-skeleton ratios pass.

## D. DEBUG EVIDENCE

Real D3D12/DXIL captures:

- [Clean production capture](</C:/Users/Chad/Documents/2d Renderer/zig-out/p25c_visual_geometry/03_wide_brim_front_clean.png>)
- [Geometry-debug capture](</C:/Users/Chad/Documents/2d Renderer/zig-out/p25c_visual_geometry/03_wide_brim_front_geometry.png>)

The debug capture uses the existing renderer, readback path, global render queue, and debug-draw system. It displays alpha bounds, pivots, landmarks, centerlines, forward/sole axes, and landmark-error lines. Labels and exact measurements accompany it in the structured report.

Both captures were visually inspected after generation.

## E. FALSE-POSITIVE / FALSE-NEGATIVE CONTROLS

Controlled fixtures prove:

- Coincident axes pass while a reversed shoe axis fails at 180°.
- A 1.02 fit ratio passes while 0.78 fails.
- Transparent padding does not change visible measurements.
- Semantic side remains correct even when scale signs are deliberately misleading.
- Known-correct current metrics pass alongside the 62 genuine failures.
- Golden hashes distinguish unapproved, unchanged, and changed output; current Prompt-25B content was not approved as a golden.

## F. PERFORMANCE / BOUNDS

- Trace capacity: 256 records.
- Landmark capacity: 16 per component.
- Metric capacity: 8,192.
- Debug primitive capacity: fixed 512.
- Six atlas pages are decoded only during test/debug initialization: 38,799,264 decoded bytes.
- Alpha masks and report data are released after audit completion.
- Clean and debug real-GPU routes reported zero update, submission, and render-queue allocations.
- Tracked initialized/final runtime memory was identical at 127,456 bytes.
- GPU resource delta was zero.
- No per-character renderer or new production rendering path was introduced.

## G. REGRESSION STATUS

- Focused validator: 8/8 passed.
- Aggregate check: 325/325 passed.
- Debug, ReleaseSafe, and ReleaseFast builds passed.
- GPU smoke passed through D3D12/DXIL with exact readback.
- Clean and debug visual-quality routes passed with zero allocation/resource deltas.
- Repository audit passed across 109 files.

One initial default-cache build encountered `manifest_create AccessDenied` before semantic compilation. Retrying with the task-local cache `.zig-cache\p25c-global` and `-j1` passed all required gates.

## H. PRODUCTION ART CHANGES

None; Prompt 25C intentionally built validation before visual correction.

`git diff --name-only -- assets/art` is empty, and all ten production PNG SHA-256 values match the pre-implementation baseline. No pivots, sizes, transforms, wardrobe placement, animation, physics, IK, or presentation art were corrected.

## I. PROMPT 26

Prompt 26 was not started.

IMPLEMENTATION REPORT  
Scope completed:
- Added bounded semantic visual geometry, alpha-aware measurements, fit and coverage contracts, orientation checks, proportions, joint continuity, symmetry, pose/morphology sweeps, structured failure reporting, debug overlays, and golden-regression support.
- Measured the unchanged Prompt-25B character and recorded 62 intentional content failures.
- Completed focused, aggregate, build, GPU, visual, documentation, and repository audits.

Files created:
- `docs/VISUAL_GEOMETRY.md`
- `src/debug/visual_geometry_overlay.zig`
- `src/scene/visual_geometry.zig`
- `src/scene/visual_geometry_audit.zig`
- `src/scene/visual_geometry_report.zig`
- `tests/visual_geometry_tests.zig`

Files modified:
- `README.md`
- `build.zig`
- `docs/ARCHITECTURE.md`
- `docs/DIAGNOSTICS.md`
- `docs/PROMPT25B_DECISION_RECORD.md`
- `docs/TESTING.md`
- `docs/VISUAL_ACCEPTANCE_25A.md`
- `docs/WARDROBE.md`
- `src/debug/debug_draw.zig`
- `src/graphics/gpu_demo.zig`
- `src/graphics/sprite_batch.zig`
- `src/main.zig`
- `src/scene/character_art.zig`
- `src/scene/wardrobe_catalog.zig`
- `src/scene/wardrobe_demo.zig`
- `src/scene/wardrobe_presentation.zig`
- `tests/wardrobe_tests.zig`
- `tools/check_repository.ps1`

Commands executed:
1. `.\.deps\zig-0.16.0\zig.exe version`
 Exit code: 0
 Relevant output: `0.16.0`
2. `$env:SDL_GPU_DRIVER='direct3d12'; .\zig-out\bin\skeletal_gpu_demo.exe --frames 600 --demo visual-quality --scripted-input`
 Exit code: 0
 Relevant output: D3D12/DXIL; 11 captures; 60 sprites; 15 ranges/draws; zero allocation/resource deltas.
3. `.\.deps\zig-0.16.0\zig.exe build -j1`
 Exit code: 1
 Relevant output: Initial default-cache `manifest_create AccessDenied`; no semantic compilation.
4. `.\.deps\zig-0.16.0\zig.exe fmt build.zig src tests`
 Exit code: 0
 Relevant output: Formatting completed.
5. `.\.deps\zig-0.16.0\zig.exe build test-visual-geometry -j1`
 Exit code: 0
 Relevant output: 8/8 tests passed.
6. `.\.deps\zig-0.16.0\zig.exe build visual-geometry-report -j1`
 Exit code: 0
 Relevant output: 53 trace records; 129 metrics; 62 intentional content failures.
7. `.\.deps\zig-0.16.0\zig.exe build check -j1 --global-cache-dir .zig-cache\p25c-global --summary all`
 Exit code: 0
 Relevant output: 325/325 tests plus formatting and repository audit passed.
8. `.\.deps\zig-0.16.0\zig.exe build -j1 --global-cache-dir .zig-cache\p25c-global`
 Exit code: 0
 Relevant output: Debug build passed, 18/18 steps.
9. `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseSafe -j1 --global-cache-dir .zig-cache\p25c-global`
 Exit code: 0
 Relevant output: 18/18 steps passed.
10. `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseFast -j1 --global-cache-dir .zig-cache\p25c-global`
 Exit code: 0
 Relevant output: 18/18 steps passed.
11. `.\.deps\zig-0.16.0\zig.exe build gpu-smoke -j1 --global-cache-dir .zig-cache\p25c-global`
 Exit code: 0
 Relevant output: 20/20 steps; D3D12/DXIL; exact readback; two instances in one draw.
12. `$env:SDL_GPU_DRIVER='direct3d12'; .\zig-out\bin\skeletal_gpu_demo.exe --frames 600 --demo visual-quality --scripted-input --debug-visualization`
 Exit code: 0
 Relevant output: One matching debug capture; 317 sprites; 16 ranges/draws; zero allocation/resource deltas.
13. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" diff --name-only -- assets/art`
 Exit code: 0
 Relevant output: Empty; production art unchanged.

Acceptance criteria:
- [PASS] Required semantic landmarks and typed visual roles exist.
- [PASS] Alpha-visible geometry is deterministic and queryable.
- [PASS] Landmark evaluation uses the real production transform.
- [PASS] Left/right identity comes from semantic bindings.
- [PASS] Registration, angle, proportion, fit, coverage, continuity, symmetry, pose, and morphology validation exist.
- [PASS] Quantitative text and JSON diagnostics were generated.
- [PASS] Clean and debug real-D3D12 evidence was generated and inspected.
- [PASS] Current Prompt-25B content naturally fails for footwear, clothing, headwear, articulation, and symmetry defects.
- [PASS] Existing architecture and steady-state allocation contracts remain intact.
- [PASS] Production art was not corrected or altered.
- [PASS] Prompt 26 was not started.

Known limitations:
- The current production character remains visually rejected by design; correction belongs to a later explicitly authorized task.
- The current output has not been approved as a golden.
- In-frame text labels are supplied through the accompanying structured diagnostic report.

Unresolved failures:
- 62 current Prompt-25B visual-content failures remain intentionally unresolved.
- No unresolved compiler, test, build, GPU, resource, or repository-audit failures.

No-placeholder audit:
- TODO matches: 0 implementation matches; only binding-contract/template literals in `AGENTS.md`.
- FIXME matches: 0 implementation matches; only binding-contract/template literals in `AGENTS.md`.
- Stub/placeholder findings: None.
- Disabled or skipped tests: None.
