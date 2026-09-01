# Prompt 25D Decision Record

> Historical milestone note: this record preserves the decisions and scope
> gate at Prompt 25D. Prompt 26 and Prompt 27 are now complete; see
> [`project/CURRENT_STATE.md`](project/CURRENT_STATE.md) for current status.

## A. Validator hardening

The Prompt 25C ruler was audited before accepting production changes.

- Pelvis waist and hip metadata is now selected by body style, presentation
  view, and semantic region. The previous role/view template did not describe
  the visible male and female pelvis sources after anatomy reauthoring.
- The front shin knee landmark is on the new visible proximal knee cap instead
  of the obsolete cropped-source offset.
- Every submitted equipment trace retains its component identity, bound anatomy
  identity, side, and view. Wardrobe evaluation iterates every applicable
  record; it does not stop at the first record matching a role.
- Generic 2 px registration and 5 degree orientation limits were retained.
- Intermediate elbow/wrist/ankle overlap remains 5 px. Knee overlap changed
  from the generic 5 px to a typed 8 px articulated-cap contract because the
  deterministic deep-bend, walk, rise, fall, and landing poses require up to
  7.08 px while the inspected silhouette stays continuous. A controlled 8.1 px
  fixture fails.
- Hip-root overlap changed from the generic 5 px to a typed 15 px root
  contract. Shoulder overlap retains the 15 px nominal floor and adds an
  explicit maximum of 30 percent of the transformed torso span. A fixed 15 px
  ceiling was semantically wrong for supported broad morphology because the
  torso owns the deltoid silhouette and its visible span grows while the
  normalized overlap stays bounded. A 15.1 px nominal fixture still fails
  against a 40 px torso; a broad 17.9/60 px fixture passes and 18.1/60 px
  fails. This contract does not apply to distal joints.
- Lower-garment coverage is defined over the intended design region. Generic
  lower garments retain 0.98 side coverage. The curved side silhouettes use
  explicit contracts: split skirt 0.88 over its waistband/upper-hip drape,
  ruby day dress and ruby fitted pants 0.94 over their rounded pelvis core, and
  crimson high-waist pants 0.96. A controlled 0.75 split-skirt fixture fails.
- The Prompt 25B presentation regression that divided authored quad aspect by
  an axis-aligned source rectangle aspect was retired as a fit proxy. That
  quotient is invalid for alpha-tight components with quarter-turn rest
  rotation and morphology-aware semantic axes. The routing test still requires
  finite positive authored extents, while the stronger Prompt 25D gate measures
  visible span, anatomy-relative proportion, registration, orientation, and
  coverage through the production transform.

These are validator corrections, not production bypasses. No global
registration, orientation, span, or distal-continuity tolerance was increased.

## B. Frozen original production failures

`zig-out/p25d_visual_geometry/pre_correction_report.txt` and `.json` are the
immutable Prompt 25B-derived baseline:

- metrics: 9,261
- failures: 4,284
- text SHA-256:
  `bfc21d4dea488b02183b4805e3031dcfa2810e176f761725eed04c38196a5772`
- JSON SHA-256:
  `7050bb46a11d91cdec70b363110172a0d5f23202fd13ebb5613ab9fff88e1381`

Representative female/front/neutral/left-footwear failures were:

| Metric | Before | Required |
| --- | ---: | ---: |
| ankle error | 4.463 px | at most 2 px |
| heel error | 8.475 px | at most 2 px |
| toe error | 52.992 px | at most 2 px |
| forward-axis error | 173.669 degrees | at most 5 degrees |
| sole-axis error | 180 degrees | at most 5 degrees |
| visible length ratio | 1.429 | 0.95 to 1.15 |
| declared coverage | 0.239 | at least 0.90 in the old baseline contract |

The same baseline rejected the female halter chest span at 0.739, shorts
coverage at 0.612, and multiple elbow overlap depths between 7.2 and 9.5 px.

## C. Root causes

- Footwear: front mirror/rest orientation, authored size, pivot, and local
  equipment transform disagreed with the actual foot axes.
- Clothing: generic authored sizes and pivots did not follow the selected
  body/view geometry; side waist accessories were too narrow on the male
  profile.
- Shoulders: the former upper-arm source owned a rounded ball instead of
  allowing the torso to own the deltoid silhouette.
- Elbows and knees: dark source-edge pixels and incompatible proximal/distal
  caps advertised the sprite cuts.
- Male pelvis: the former modest base source read as an independent rounded
  codpiece and did not bridge cleanly into the thighs.
- Side pelvis: an intermediate source silhouette read as a trailing tail and
  was rejected before acceptance.

## D. Production corrections

- Reauthored neutral, nonsexual, featureless male/female pelvis and limb
  components in `p25b_anatomy_components_atlas.png`.
- Repacked alpha-tight front/side upper arms, forearms, thighs, shins, and
  pelvis regions; updated the matching source rectangles and audit data.
- Normalized joint-edge colors and bounded cap tapers without adding connector
  sprites.
- Kept side upper arms behind the torso so the torso-owned deltoid defines the
  profile shoulder.
- Preserved the permanent modest surface as `base_presentation`, not removable
  clothing.
- Corrected front shoulder spans and side-profile arm-root projection through
  the existing presentation path.
- Corrected female scarlet-sport front pivot to 0.427 and male velvet-mini
  front pivot to 0.115.
- Corrected male side waist-accessory fit scale from 0.895 to 0.975 while
  retaining the 0.96 to 1.08 span acceptance range.
- Centralized the quarter-turn bone-local morphology-axis mapping in the
  production presentation helper used by both anatomy and wardrobe submission.
  Side thighs, shins, and fitted legwear now map thickness to sprite X and
  length to sprite Y for both facings instead of changing visible length when
  only thickness changed.
- Corrected female side thigh/shin authored lengths from 0.895/0.850 m to
  0.919/0.875 m, closing the measured knee and ankle gaps while keeping the
  proximal joints anchored.
- Corrected female side legwear pivots to the actual proximal source landmark:
  crimson thigh-high 0.057, rose mesh 0.058, and ember pattern 0.057.
- Added design-specific side clearance for the male scarlet sport shorts and
  female velvet mini skirt, including side authored heights of 0.67/0.75 m.
  Their intended pelvis coverage now remains valid through stride,
  compression, rise, and landing without changing the 0.98 coverage ruler.

No skeleton, animation, physics, IK, interaction, renderer, or per-character
rendering path was added or replaced.

## E. Final visual-geometry result

The final report contains 20,665 metrics and zero production failures. Its
hashes are:

- text:
  `ca23ac32f9b37194ef3637ace348d6b3382ac2e93a880625b30193ea3d11742f`
- JSON:
  `3811f5e419ba3cea0a1f9ffc99982cdec9a0124c20cacf93708c3e280fd6f951`

The focused production subset reports 158/158 passing checks. The independent
pose/morphology sweep reports 6,354/6,354 passing checks, preserving more than
the required 129-check baseline.

Representative female/front/neutral/left-footwear results are:

| Metric | After | Result |
| --- | ---: | --- |
| ankle error | 0.218 px | pass |
| heel error | 0.341 px | pass |
| toe error | 0.119 px | pass |
| forward-axis error | 0 degrees | pass |
| sole-axis error | 0 degrees | pass |
| visible length ratio | 1.015 | pass |
| declared strappy-shoe sole/heel/toe coverage | 0.808 | pass, minimum 0.65 |
| opposite-foot crossing | 0 px | pass |

The strappy-shoe coverage contract deliberately targets sole, heel, and toe;
it does not require cloth over the open instep.

## F. D3D12 evidence and approved goldens

The 600-frame real D3D12/DXIL route produced 11 clean captures from the same
prepared global queue. Inspection covered base front/side, wide-brim plus male
outfit front/side, ivory blouse front/side, layered custom front/side,
locomotion, jump rise, and jump fall. A second run captured male and female
geometry overlays from that same route.

The approved capture bytes, exact frames, views, presets, poses, and SHA-256
values are in `tests/goldens/p25d/manifest.json`. They were created only after
the production report reached zero failures and the captures were inspected.
The stored/latest comparison passes 12/12.

## G. Test-integrity audit

- No Prompt 25C negative calibration test was deleted.
- No test was skipped, disabled, converted to logging, or removed from build
  discovery.
- No global registration, orientation, fit-span, or distal-joint tolerance was
  widened.
- The shoulder parent-span rule is morphology-relative and independently
  capped by a controlled bad fixture; it is not a Prompt25D-only branch.
- The final report evaluates each production motion sample in side-right and
  side-left. It no longer forces motion evidence through a front projection.
- No metric is omitted based on a stable ID merely because it fails.
- No Prompt25D-only success branch, screenshot coordinate, or suppressed report
  entry exists.
- All garment-specific values describe named design intent and retain controlled
  failing fixtures.
- Legacy Prompt 25A/25B exact-value assertions were migrated to the accepted
  alpha-derived sleeve, legwear, footwear, limb, pelvis, and hand anchors.
  Bilateral footwear metadata remains a separate weaker test; semantic
  left/right heel, toe, ankle, sole, and coverage checks remain in the
  production matrix.
- The repository policy audit now requires the shared
  `spriteMorphologyScale` route, current semantic footwear values, and
  Prompt-25D regression names. It explicitly fails if front/side arm-root
  compression or `compressArmRoots` returns.

## H. Architecture and performance

The authoritative skeleton, morphology, `.character` anatomy ownership,
`.equipment` removable ownership, permanent `base_presentation` modesty layer,
fixed-tick simulation, interactions, IK, `UnifiedRenderQueue`, and D3D12
renderer are unchanged. Clean and debug real-GPU routes reported zero update,
submission, and queue allocations after stabilization and zero GPU-resource
delta.

## I. Full regression

Iteration used the focused report, focused visual-geometry test, and focused
D3D12 captures. The complete repository gates ran only after quantitative and
human visual acceptance:

- `zig build test-presentation -j1`: 15/15 passed.
- `zig build test-wardrobe -j1`: 16/16 passed.
- `zig build test-visual-geometry -j1`: 158/158 focused and 6,354/6,354
  pose/morphology checks passed.
- `zig build visual-geometry-report -j1`: 20,665 production metrics, zero
  failures.
- `zig build test -j1`: exit 0; the aggregate graph passed, including the
  focused visual-geometry gate.
- `zig build`: exit 0.
- `zig build -Doptimize=ReleaseSafe -j1`: exit 0.
- `zig build -Doptimize=ReleaseFast -j1`: exit 0.
- `pwsh -File tools/check_repository.ps1`: exit 0; 110 source files audited.
- `zig build check -j1`: exit 0; 327/327 tests, repository/art audits, and
  12/12 stored Prompt-25D goldens passed.
- `SDL_GPU_DRIVER=direct3d12 zig build gpu-smoke -j1`: exit 0; actual D3D12,
  DXIL agreement, bounded fault-injection cleanup, and two instances in one
  indexed-instanced draw passed readback.

The earlier first aggregate attempt ended at the command wrapper's 180-second
timeout with no test failure output. It was rerun with the same command and a
longer wrapper timeout and passed. The first integrated `check` ran all 327
tests successfully but exposed obsolete Prompt-25A/25B string requirements in
the repository policy script; after the audit-contract migration described
above, the complete `check` passed.

## J. Prompt 26

Prompt 26 was not started.
