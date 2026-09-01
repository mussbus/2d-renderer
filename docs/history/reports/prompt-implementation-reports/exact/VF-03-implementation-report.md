# VF-03-R1 Implementation Report

Baseline HEAD:
`624bf26c73aeea23f16f94c88350bf5a7c646604`

Initial Git status:

- branch `master`, tracking `origin/master`, ahead/behind `+0/-0`;
- staged: none;
- unstaged tracked: 28 files — `build.zig`, 13 VF-03 source/test files,
  and 14 VF-03 documentation/index files already present in the inherited
  VF-03 worktree;
- untracked: `src/scene/component_graph.zig`,
  `tests/component_graph_tests.zig`, `docs/VF03_DECISION_RECORD.md`,
  `docs/prompts/VF-03-typed-modular-component-graph.md`, and this report.

The inherited unstaged/untracked VF-03 work was preserved. No stage, commit,
reset, clean, restore, delete, or evidence promotion was performed.

## Scope completed

- Kept the accepted immutable graph, typed sockets, fail-closed validation,
  eye → eyebrow, scalp → hair, schema-4 export, front/side/reflection
  projection, and explicit connection semantics.
- Corrected the owner-review failure: an active optional arm's declared upper
  arm, forearm, and hand now enter the real `character_art` production
  `UnifiedRenderQueue`.
- Made the graph-to-production contract fail closed:

  ```text
  declared bound visuals
    == resolved active graph visuals
    == expected production submissions
    == actual production submissions
  ```

  The expected and actual value is exactly three per active module.
- Bound upper arm shoulder → elbow, forearm elbow → wrist, and hand wrist →
  hand-tip from the same projected module endpoints exported by schema 4.
- Added technical green/magenta presentation using existing anatomy regions,
  deterministic socket locations, and ordinary draw ordering. Clean frames
  visibly separate standard arms, module one, and module two.
- Made front, side-left, and side-right active-module cases use stable graph,
  module, joint, socket, and visual identities. Reflection changes projected
  presentation without changing ownership.
- Kept continuous and intentional-gap thresholds distinct. Continuous
  measures `0 m` and rejects `0.08 m`; intentional-gap accepts `0.08 m` only
  in `0.07–0.09 m`.
- Kept the gap vector in world metres under morphology and derived capture
  pixels from `measured_gap_m × pixels_per_meter`.
- Extended F1 and schema 4 with module ownership, projected chain,
  connection endpoints/vector/range/result, graph bindings, visual bounds,
  placement authority, submission presence/index, and active/expected/actual/
  missing/orphan totals.
- Classified inactive bindings as inactive with no final index. Disabled
  output has zero optional submissions and no active orphan graph/module
  records.
- Added fail-closed graph/submission ownership, duplication, joint, view,
  visibility, continuous/gap, range, morphology, and reflection coverage.
- Added one-shot `--capture-manual-bundle`, which invokes the same F4
  production capture request without `CharacterIntent` or a parallel
  renderer.
- Strengthened bundle finalization by parsing `state.json` and
  `manifest.json` before the incomplete directory can be finalized.
- Preserved historical `_0074–_0082` unchanged and produced the accepted
  corrective `_0083`, `_0091–_0097` set.
- Did not start generalized optional-limb animation/IK, VF-04, Prompt 28,
  materials, morphology expansion, editor work, gameplay work, broad
  production migration, locomotion retuning, or handshake redesign.

## Files created

Current VF-03 worktree additions:

- `src/scene/component_graph.zig`
- `tests/component_graph_tests.zig`
- `docs/VF03_DECISION_RECORD.md`
- `docs/prompts/VF-03-typed-modular-component-graph.md`
- `docs/reports/prompt-implementation-reports/exact/VF-03-implementation-report.md`

VF-03-R1 itself created no additional repository file.

## Files modified

- `build.zig`
- `src/debug/debug_draw.zig`
- `src/debug/visual_truth.zig`
- `src/graphics/gpu_demo.zig`
- `src/main.zig`
- `src/scene/anatomy.zig`
- `src/scene/character.zig`
- `src/scene/character_art.zig`
- `src/scene/environment_demo.zig`
- `src/scene/humanoid.zig`
- `src/scene/modular_body_demo.zig`
- `src/scene/presentation_pose.zig`
- `src/scene/visual_foundation.zig`
- `src/scene/visual_geometry.zig`
- `src/scene/wardrobe_demo.zig`
- `tests/anatomy_tests.zig`
- `tests/character_presentation_tests.zig`
- `tests/test_all.zig`
- `tests/visual_foundation_tests.zig`
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

No production atlas, source asset, historical evidence, approved golden,
controller, collider, canonical animation/IK, interaction, or shader file was
modified.

## Architecture confirmed

1. Controller/collider state remains authoritative gameplay state.
2. Canonical skeleton pose remains animation, IK, and foot-planting authority.
3. Front/side presentation remains a read-only production projection.
4. Anatomy/appearance definitions remain immutable topology owners;
   `component_graph.Definition` is their one compiled inspection/validation
   facade.
5. Optional visuals consume projected module endpoints and the existing
   registration/submission route; no renderer-local transform formula exists.
6. Final sprites, meshes, and debug primitives still use the global
   `UnifiedRenderQueue` and real SDL3 D3D12 renderer.
7. F1, schema 4, summary, validation, and clean pixels consume the same trace.
8. Capture evidence remains separate from owner visual approval.

## Architecture discrepancies found

- Original VF-03 proved declared graph bindings but not production
  submissions. `character_art.slotForAttachment` omitted the optional visual
  identities, clean frames showed only two arms, and side cases were inactive.
  R1 adds the cross-layer submission invariant and real production slots.
- Local copied debug-name storage initially left graph identity slices
  lifetime-unsafe. Graph/module evidence now references immutable backing
  definition arrays.
- Expanded F1 labels exceeded the bounded command buffer during development.
  Labels were shortened and drawn through a fixed-capacity allocation-free
  path; overflow remains detected, never truncated.
- Initial active R1 bundles `_0084–_0090` contain invalid `state.json` due to
  one extra closing brace. The old finalizer checked file writes and hashes
  but did not parse generated JSON. Those bundles remain preserved invalid
  diagnostic candidates. Finalization now parses state and manifest JSON;
  `_0091–_0097` are valid replacements.
- Managed sandbox compiler processes intermittently failed before semantic
  compilation with `manifest_create AccessDenied`. Only equivalent commands
  with documented task-local host caches were retried.

## Commands executed

1. `& '.\.deps\zig-0.16.0\zig.exe' version`
   - Exit code: `0`
   - Relevant output: `0.16.0`
2. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" rev-parse HEAD`
   - Exit code: `0`
   - Relevant output:
     `624bf26c73aeea23f16f94c88350bf5a7c646604`
3. Initial status, branch/tracking, staged, unstaged, and untracked inspection.
   - Exit code: `0`
   - Relevant output: 28 unstaged tracked and five untracked VF-03 files;
     staged empty; `master...origin/master`.
4. Fresh pre-change current-art Prompt 27B coherence report.
   - Exit code: `0`
   - Relevant output: `metrics=9752 failures=0`, output
     `zig-out\vf03_r1_baseline\p27b`.
5. `& '.\.deps\zig-0.16.0\zig.exe' build test-component-graph test-visual-foundation -j1 --summary all --cache-dir '.zig-cache\vf03-r1-focus-final' --global-cache-dir '.zig-cache\vf03-global'`
   - Exit code: `0`
   - Relevant output: `53/53` — component graph `6/6`, visual foundation
     `47/47`.
6. `& '.\.deps\zig-0.16.0\zig.exe' build test-presentation test-visual-registration test-visual-geometry test-wardrobe -j1 --summary all --cache-dir '.zig-cache\vf03-r1-regressions-final' --global-cache-dir '.zig-cache\vf03-global'`
   - Exit code: `0`
   - Relevant output: `60/60` — presentation `15/15`, registration `11/11`,
     visual geometry `15/15`, wardrobe `19/19`; Prompt 27C matrices
     `196/196` and `6954/6954`.
7. `& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --summary all --cache-dir '.zig-cache\vf03-r1-p27b-final' --global-cache-dir '.zig-cache\vf03-global' -- --output 'zig-out\vf03_corrective\p27b'`
   - Exit code: `0`
   - Relevant output: `metrics=9752 failures=0`; `3/3` steps succeeded.
8. `& '.\.deps\zig-0.16.0\zig.exe' build test -j1 --summary all --cache-dir '.zig-cache\vf03-r1-test' --global-cache-dir '.zig-cache\vf03-global'`
   - Exit code: `0`
   - Relevant output: `428/428` — deterministic `320`, image `3`, wardrobe
     `19`, registration `11`, geometry `15`, environment `13`, visual
     foundation `47`.
9. `& '.\.deps\zig-0.16.0\zig.exe' build check -j1 --summary all --cache-dir '.zig-cache\vf03-r1-check' --global-cache-dir '.zig-cache\vf03-global'`
   - Exit code: `0`
   - Relevant output: `21/21` steps and `428/428` tests; repository source,
     formatting, historical art/evidence, resource-family, and single
     indexed-instanced-draw audits passed.
10. Debug build attempts:
    - Managed caches `.zig-cache\vf03-r1-debug` and
      `.zig-cache\vf03-r1-debug-retry`: exit `1`,
      `manifest_create AccessDenied` before project semantic compilation.
    - Equivalent host command:
      `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=Debug -j1 --summary all --cache-dir '.zig-cache\vf03-r1-debug-host' --global-cache-dir '.zig-cache\vf03-r1-debug-host-global'`
    - Exit code: `0`
    - Relevant output: `20/20` steps succeeded.
11. ReleaseSafe build:
    - Managed cache command exited `1` with
      `manifest_create AccessDenied`.
    - First equivalent host-cache invocation exceeded the 59-second wrapper
      while warming the cache; the unchanged retry:
      `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseSafe -j1 --summary all --cache-dir '.zig-cache\vf03-r1-release-safe-host' --global-cache-dir '.zig-cache\vf03-r1-release-safe-host-global'`
    - Exit code: `0`
    - Relevant output: `20/20` steps succeeded.
12. ReleaseFast build:
    - Managed cache command exited `1` with
      `manifest_create AccessDenied`.
    - First equivalent host-cache invocation exceeded the 59-second wrapper
      while warming the cache; the unchanged retry:
      `& '.\.deps\zig-0.16.0\zig.exe' build -Doptimize=ReleaseFast -j1 --summary all --cache-dir '.zig-cache\vf03-r1-release-fast-host' --global-cache-dir '.zig-cache\vf03-r1-release-fast-host-global'`
    - Exit code: `0`
    - Relevant output: `20/20` steps succeeded.
13. GPU smoke:
    - Managed cache command exited `1` with
      `manifest_create AccessDenied`.
    - Equivalent host command:
      `& '.\.deps\zig-0.16.0\zig.exe' build gpu-smoke -j1 --summary all --cache-dir '.zig-cache\vf03-r1-gpu-host' --global-cache-dir '.zig-cache\vf03-r1-gpu-host-global'`
    - Exit code: `0`
    - Relevant output: `22/22`; actual `direct3d12`, generated DXIL,
      640×480 pitched readback, two instances in one
      `SDL_DrawGPUIndexedPrimitives` draw, every cleanup checkpoint passed.
14. `& '.\tools\build_p27a_review_package.ps1' -EvidenceDirectory 'zig-out\p27a_evidence\candidate' -OutputDirectory 'zig-out\vf03_corrective\p27a'`
    - Exit code: `0`
    - Relevant output: `16/16` captures, `263` metrics, zero failures,
      manual acceptance pending.
15. Eight production launches using:
    `& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --interactive --frames 1 --component-proof-case <case> --capture-manual-bundle`
    for `disabled`, `continuous-front`, `intentional-gap-front`,
    `continuous-side-left`, `continuous-side-right`,
    `intentional-gap-side-left`, `intentional-gap-side-right`, and
    `two-modules`.
    - Exit code: `0` for all.
    - Relevant output: actual `direct3d12`, DXIL; queue allocations `0`;
      GPU-resource delta `0`; accepted bundles `_0083`, `_0091–_0097`.
16. Independent PowerShell JSON, manifest, byte-size, SHA-256, source-asset,
    provenance, state-equality, and optional-submission validation over the
    accepted eight bundles.
    - Exit code: `0`
    - Relevant output: `_0083` active/expected/actual `0/0/0`;
      `_0091–_0096` each `1/3/3`; `_0097` `2/6/6`; every bundle has
      missing/orphan `0/0`, four manifest files, eight source assets, and
      `state_equal=True`.
17. `zig fmt build.zig src tests`
    - Exit code: `0`
    - Relevant output: `tests/visual_foundation_tests.zig` formatted; no
      formatting failure.
18. `& '.\tools\check_documentation.ps1'`
    - Exit code: `0`
    - Relevant output: `46` required files, `39` Markdown files, and `98`
      local Markdown targets passed.
19. `git -c "safe.directory=C:/Users/Chad/Documents/2d Renderer" diff --check`
    - Exit code: `0`
    - Relevant output: no whitespace error; only the repository's expected
      LF-to-CRLF working-copy warnings.
20. Changed implementation/test audit:
    `rg --line-number "TODO|FIXME|unreachable|skip(ped)?|disabled test|placeholder" <changed implementation and test paths>`
    - Exit code: `0`
    - Relevant output: no TODO, FIXME, skipped/disabled-test, or placeholder
      match. One `unreachable` remains in `presentation_pose.zig`; the
      immediately preceding four-root exhaustive loop and inline invariant
      comment establish why the default is impossible.
21. Final branch/status, staged-path, changed asset/evidence path, and diff-stat
    inspection.
    - Exit code: `0`
    - Relevant output: `master...origin/master`; staged empty; no changed
      asset or `zig-out` path; 32 tracked modified and five untracked VF-03
      files.

## D3D12/DXIL corrective evidence map

| Bundle | Proof | Optional submission integrity |
|---|---|---|
| `20260731T001802.149Z_0083` | disabled front; standard two-arm output unchanged | active `0`, expected/actual `0/0`, missing/orphan `0/0` |
| `20260731T002000.945Z_0091` | one continuous front module; visible attached root | `1`, `3/3`, `0/0`; gap `0 m` |
| `20260731T002002.571Z_0092` | same front module/pose with visible intentional gap | `1`, `3/3`, `0/0`; `0.08000003 m`, `6.560002 px` |
| `20260731T002004.216Z_0093` | continuous side-left | `1`, `3/3`, `0/0`; gap `0 m` |
| `20260731T002005.889Z_0094` | continuous side-right and reflection | `1`, `3/3`, `0/0`; gap `0 m` |
| `20260731T002007.558Z_0095` | intentional-gap side-left | `1`, `3/3`, `0/0`; `0.08000008 m`, `6.560007 px` |
| `20260731T002009.222Z_0096` | intentional-gap side-right and reflection | `1`, `3/3`, `0/0`; `0.08000003 m`, `6.560002 px` |
| `20260731T002010.924Z_0097` | two distinct visible modules; graph-to-submission linkage | `2`, `6/6`, `0/0`; primary continuous, secondary `0.07999997 m` / `6.559998 px` |

Every accepted bundle contains `clean.png`, `debug.png`, `state.json`,
`summary.txt`, and `manifest.json`; the manifest lists the other four files
with verified byte size and SHA-256 plus eight verified source-asset hashes.
Frame, tick, state, and common-fingerprint equality are true. Driver and
shader provenance are actual `direct3d12` and DXIL.

Historical `_0074–_0082` are untouched. Invalid-JSON `_0084–_0090` are
preserved diagnostic candidates and are not accepted or promoted. No bundle
is a golden.

## Allocation and resource evidence

- Graph, module, and visual binding records are fixed-capacity initialization
  data.
- F1 and active/inactive optional-arm production submission perform no
  per-frame heap allocation.
- Each production evidence route reported queue allocations `0` and
  GPU-resource delta `0`.
- F1 mode changes decode no texture and create no GPU resource.
- F4/`--capture-manual-bundle` remains the explicit bounded diagnostic
  allocation and filesystem-I/O boundary outside fixed-tick simulation.
- GPU smoke passed all partial-initialization cleanup checkpoints.

## Acceptance criteria

- `[PASS]` Active optional upper arm, forearm, and hand use the real
  character-art production queue.
- `[PASS]` Active graph visual counts equal resolved, expected, and actual
  final submissions: exactly three per module.
- `[PASS]` Production, F1, schema 4, validation, summary, and clean pixels
  consume the same projected module bindings.
- `[PASS]` Shoulder→elbow, elbow→wrist, and wrist→hand-tip bindings fail
  closed on missing, duplicate, wrong-owner, wrong-joint, inactive, orphan,
  or unsupported-view data.
- `[PASS]` Disabled output has zero active modules/submissions and leaves the
  standard two-arm character unchanged.
- `[PASS]` Continuous and intentional-gap clean renders are visibly distinct;
  continuous remains epsilon-bounded and rejects `0.08 m`.
- `[PASS]` Intentional-gap measures `0.08 m` within `0.07–0.09 m`, preserves
  visible empty pixels, and derives capture pixels from the camera.
- `[PASS]` Front, side-left, side-right, and reflection evidence contains all
  three submissions with stable ownership and identity.
- `[PASS]` Two simultaneously active modules produce six distinct
  submissions.
- `[PASS]` Focused `53/53`, regression `60/60`, aggregate `428/428`, and
  `check` `21/21` pass.
- `[PASS]` Fresh Prompt 27B has `9,752` metrics and zero failures.
- `[PASS]` Debug, ReleaseSafe, ReleaseFast, D3D12/DXIL smoke, Prompt 27A
  integrity, documentation, and `git diff --check` pass.
- `[PASS]` Historical evidence/goldens remain unchanged and no corrective
  bundle was promoted.
- `[PENDING OWNER REVIEW]` Manual visual acceptance.
- `[PASS]` VF-04: `NOT STARTED`.
- `[PASS]` Prompt 28: `NOT STARTED`.

## Known limitations

- Technical optional-arm pixels are structural proof art, not owner-approved
  production art.
- Optional-arm generalized animation and IK remain deferred; the module pose
  is deterministic presentation data over explicit immutable joints.
- Standard core root/limb components retain labeled compatibility adapters.
- Material/morphology extension metadata remains declaration-only; no new
  material or morphology behavior was implemented.
- No editor, runtime topology mutation, broad production migration, or
  gameplay slice exists.
- Invalid `_0084–_0090` remain on disk as disclosed diagnostic candidates
  because deletion was prohibited.
- Manual visual acceptance remains `[PENDING OWNER REVIEW]`.

## Unresolved failures

- No automated project failure remains.
- Manual owner review is unresolved by design.

## No-placeholder audit

- TODO matches: none.
- FIXME matches: none.
- Stub/placeholder findings: none.
- Disabled or skipped tests: none.
- Invariant-backed `unreachable`: one, immediately justified by the exhaustive
  four-root loop in `presentation_pose.zig`.

## Final Git status

- Branch: `master`, tracking `origin/master`, ahead/behind `+0/-0`.
- Staged: none.
- Unstaged tracked: 32 files, all within the inherited VF-03 plus bounded R1
  implementation/test/documentation scope listed above.
- Untracked: the same five VF-03 files listed under “Files created.”
- Changed asset, historical evidence, approved golden, or `zig-out` paths:
  none.
- No staging, commit, push, reset, clean, restore, delete, discard, or
  evidence-promotion operation was performed.

Manual visual acceptance: `PENDING OWNER REVIEW`

VF-04: `NOT STARTED`

Prompt 28: `NOT STARTED`
