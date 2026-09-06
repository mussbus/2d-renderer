# Engine Lab EL1: application foundation

Status: EL1 implementation and full verification passed; ready for owner review. Owner acceptance is pending.

## Baseline and pre-implementation audit

The original checkout is `C:/Users/Chad/Documents/2d Renderer`, clean on
`master` at `cb60fc9a9b24ba7d69578ffc721948e9b00de8fd`. Local master and the
locally recorded origin/master have the same HEAD. No fetch was performed.
The sibling `2d Renderer-engine-lab-el1` was created on
`feature/engine-lab-el1` from that exact commit. It adds the normative F4
acceptance record to audited production code at `48a7c677d781543e479b178c6e7b10b139eeb26e`.
Existing worktrees at discovery: owner master, media-library foundation,
media-library UI, psm01-secondary-motion, and effects-projectiles-e1. None was reused.

The current authority is `docs/project/CURRENT_STATE.md` and the F1-F4 contracts
linked by `docs/ARCHITECTURE.md`. F1-F4 are accepted; old candidate wording in
implementation history is historical, as the current authority explicitly says.
`docs/TESTING.md` retains older tier descriptions below its current F4 policy;
the current opening tier table and actual `build/gates.zig` agree and govern EL1.
No contract/code contradiction requiring an architectural amendment was found.

| Area inspected | Supported ownership and EL1 decision |
| --- | --- |
| Executables/build | `build/apps.zig` registers `engine_sandbox` and `engine_smoke`; `build/modules.zig` injects explicit module imports. Root composes apps, tests, evidence, and gates. Add an independent application here. |
| Independent proof | `src/app/engine_smoke.zig` and its client prove RuntimeScene observations, real SDL GPU D3D12/DXIL submission, copied readback and balanced destruction. This remains the bounded GPU diagnostic. |
| Platform/lifecycle | Renderer owns SDL/window/device/shader/buffer lifetimes. `sdl_input.PlatformInput` owns physical input/gamepad lifetime and exposes `RawInputState`; application maps actions. |
| Rendering | `sdl_gpu_renderer.Renderer`, `render_queue.UnifiedRenderQueue`, `sprite_batch.SpriteRequest`, `camera2d.Camera2D`, and `debug_draw.CommandBuffer` are production surfaces. Labels use existing bounded 3x5 glyph sprites. |
| Scene | F `EntityId`, generation-checked handles, RuntimeScene mutation commands, publication, hierarchy and immutable snapshots are authoritative. No access to registry internals. |
| Fixed step | Production `fixed_step.Clock` runs at 240 Hz with capped substeps, pause, single-step and presentation interpolation. |
| Physics | Production character controller/collision world and bounded scalar `spring.State` exist. EL1 selects the spring, without implementing collision or another solver. |
| Animation | `ClipDefinition`, `sampleFromRest`, and `Animator` are reusable, with skeleton compatibility and explicit lifetime. No animation playback is claimed in EL1. |
| Interaction | Opaque `interaction_system.Manager` and supported character bindings exist; require composed character runtimes. Deferred here. |
| Existing clients | Controller, handshake IK, integrated, playground, modular body, equipment, mesh attachment, foundation, wardrobe and environment clients remain. None supplies implementation code to EL1. |
| Determinism | F typed UUIDs, Seed128, canonical Writer and domain-separated SHA-256 are available. No ambient time/RNG enters simulation; arrays provide explicit order. |
| Testing | Focused roots live in build/tests_engine.zig; check includes fast contracts, app compilation, formatting and policy. verify adds full integration/stress and current content qualification. |
| Instructions | Root AGENTS.md is the only repository AGENTS.md. Zig version observed before implementation: 0.16.0. |

RuntimeScene clones storage for mutation and snapshot acquisition. EL1 therefore
constructs a fixed scene hierarchy and copies supported world-transform observations
during initialization. Spring offsets are presentation state attached to these
fixed anchors, not mutations of generic entity roots. No scene allocation is
performed in fixed/render updates. A future dynamic-entity lab must address that
allocation seam explicitly; EL1 does not reopen accepted F contracts.

## Ownership

Production modules -> Engine Lab composition -> Engine Lab application/UI.
The application owns renderer, physical input and LabHost. The headless lab module
owns a stable descriptor registry, sessions, deterministic fixed-step composition
and bounded presentation data. LabContext grants only an allocator used for lifetime
operations; labs receive no application, window, GPU or input-device pointer.

Two environments: Integration Overview combines fixed F hierarchy, seeded spring
presentation motion, render interpolation and batched diagnostic geometry. The
Determinism / Fixed-Step Lab runs a bounded repeatable spring experiment, reports
canonical checkpoint hashes and compares equal tick runs across frame schedules.
No optional third lab or speculative future-system interface is implemented.

## Implemented application and lifecycle

Engine Lab is a permanent integration application, not gameplay, an editor, the
3D Model Lab, or a canonical-character authoring route. The sandbox retains its
existing scenario/evidence responsibilities; engine_smoke retains its short
independent physical proof. Future games remain separate clients.

- `src/app/engine_lab/main.zig`: independent entry, renderer/platform lifetime,
  CLI, physical-event mapping, shell actions, native smoke and full hash logging.
- `labs.zig`: ordered descriptors, fixed-scene adapter, owned Session, Host,
  seed initialization, checkpoints and the repeatability proof.
- `actions.zig`: headless action mapping, key edges, short-tap capture and
  held-key suppression across focus changes, switches and resets.
- `view.zig`: converts lab observations to production sprite/debug requests.
  It borrows a render queue, not the renderer or application.
- `assets/engine_lab/white.png`: application-owned 2x2 opaque RGBA white texture,
  loaded through production ArtPack/WIC and renderer resource ownership. It
  provides neutral tint sampling, not a decorative representation of a subsystem.

Host owns a stable-address Session. A switch first constructs a candidate, then
shuts down/frees the previous session and publishes the new one. If candidate
construction fails, the previous session remains usable. Each Session owns one
RuntimeScene; snapshot leases are released before construction returns. Reset
uses the same construction path, retains the configured seed, clears pending
input/clock/history, and pauses at tick zero. Window, GPU and physical-device
ownership remain in the shell across lab switches. No callbacks or entity
handles are retained by previous labs. The optional lifecycle observer receives
successful initialization and shutdown transitions and is tested against real
sessions, not mock lab implementations.

Context currently grants only a lifetime allocator. Fixed update accepts an
explicit one-shot impulse; the fixed experiment ignores manual impulses. The
renderer receives prepared sprite data. There is no unrestricted application
pointer, global RNG, inherited demo state or reverse production dependency.

The registry is a closed compile-time array with stable string IDs and enum
construction metadata. The two EL1 labs deliberately share spring composition;
the view dispatches their different presentations by kind. This is a small
application framework, not a dynamic plugin loader.

## Initial labs and production behavior

| Lab | Implemented behavior | Production systems exercised |
| --- | --- | --- |
| Integration Overview | A persistent F root and three parent-relative anchors; three seeded vertical spring offsets; recurring tick-based impulses and optional Space impulse; interpolated colored masses, hierarchy lines and rest-position markers | Typed F identities; RuntimeScene construction, hierarchy, persistent promotion, snapshots and cleanup; scalar spring; fixed-step clock and interpolation; physical input; camera; ArtPack/WIC; unified sprite queue; SDL GPU renderer; debug primitives |
| Determinism / Fixed-Step | Three damping responses, impulses at ticks 360 and 720, a bounded 60 Hz history graph, checkpoints at 0/240/480/960, automatic pause at tick 960, repeat/reset and headless schedule comparison | The same production composition, with a controlled deterministic input schedule, canonical Writer and domain-separated SHA-256 |

The vertical line is an anchor-to-displaced-sprite diagnostic. It does not claim
a joint constraint, rope solver, collision body, character, animation clip or
interaction. Generic F roots stay fixed. The spring is the already-existing
bounded scalar physics primitive; this milestone adds no solver.

The reusable diagnostic font initially omitted most letters and all digits, and
its bit-column order mirrored asymmetric glyphs. EL1 adds the missing uppercase,
digit and basic punctuation glyphs and corrects column direction in
`src/debug/debug_draw.zig`. This is the only shared production source change.
The API, buffer bound and submission ownership are unchanged. The broader validation gate includes existing diagnostic consumers. A focused test protects readable L
orientation and distinct numeric glyphs. This small general-purpose correction
was necessary for usable controls and hash diagnostics.

## Deterministic state contract

Simulation uses production 240 Hz fixed steps. Host uses the production clock's
eight-substep cap, discarded-time reporting, pause and single-step behavior.
Frame timing only decides how many fixed updates to execute; it never enters a
spring equation or fingerprint. Paused rendering uses current state exactly;
running rendering interpolates previous/current offsets without mutating either.

Initial offsets derive from the explicit Seed128, stable lab ID and each
anchor's validated persistent F EntityId using
`engine_lab.initial_offset.v1` domain-separated hashing. There is no mutable RNG
or implicit seed. The default seed is `0123456789abcdef0123456789abcdef`.

The `engine_lab.state.v1` fingerprint hashes canonical JSON written through F's
bounded Writer. Object keys are sorted; anchor/spring array order is explicit;
float values are finite and signed zero is normalized by the production writer.
State includes schema version, lab ID, seed, fixed Hz, impulse period, persistent
anchor IDs/positions, spring configurations, current and previous offsets,
velocities, targets and tick. Runtime handles, pointers, GPU state, frame-clock
residue, pause state, diagnostic history and wall-clock time are excluded.
History is presentation-only and is explicitly cleared on reset. The fingerprint
is an experiment-state diagnostic, not a saved-scene or replay format.

Default Fixed-Step Lab checkpoints observed in Debug Windows x64:

| Tick | SHA-256 |
| --- | --- |
| 0 | `446697f66f2529e914645e77d3c4ad1b68646f256f8e8417e145bb988adb3d20` |
| 240 | `6403779e0cc4f4f8aae95c73da221a79acb2b9e2cb76a0494241e362b9d9b818` |
| 480 | `4be7db4096bfb2c906e78ad9121b9613050ff6501f52c051e2babb0a79b5e613` |
| 960 | `e600f8f2399cdc34857065fed30ba8f15f80b47ff2b87cf1fdef13d4b6689a33` |

The headless proof compares all four checkpoints between 60 Hz and a repeating
1/240, 3/240, 1/120 second frame schedule after reconstruction. The same hashes
were observed through the visible window's real frame schedule. No
cross-architecture or cross-compiler floating-point identity is claimed.

## Build, validation and owner review

Run from `C:/Users/Chad/Documents/2d Renderer-engine-lab-el1`:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' version
& '.\.deps\zig-0.16.0\zig.exe' build engine-lab -j1
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 -- --list
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 -- --lab determinism-fixed-step
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 -- --verify
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 -- --smoke
& '.\.deps\zig-0.16.0\zig.exe' build test-engine-lab -j1
& '.\.deps\zig-0.16.0\zig.exe' build test -j1
& '.\.deps\zig-0.16.0\zig.exe' build check -j1
& '.\.deps\zig-0.16.0\zig.exe' build verify -j1
```

EL1's actual recorded compiler invocations append
`--summary all --global-cache-dir '.zig-cache\el1-global'` so build caches stay
inside the new worktree. `engine-lab` installs only its own executable, white
texture, SDL DLL and production shaders; it does not build/install the sandbox
or engine_smoke. Default `zig build`, existing `run` and `gpu-smoke` behavior
remain intact. Routine check now compiles EL1 and includes its headless tests.
`verify` includes the existing full integration, stress and content gates.

Controls and expected observations:

1. Start paused in Integration Overview. Read the active lab, controls, tick zero
   and initial hash prefix. The three differently colored masses begin displaced.
2. P runs/pauses; Space applies a production spring impulse in Overview. T advances
   exactly one tick while paused. R rebuilds tick-zero state and pauses.
3. F2 opens the Fixed-Step Lab paused. P runs it. Three response traces accumulate;
   the lab stops at tick 960. The displayed hash prefix is
   `e600f8f2399cdc34`; the terminal reports the full hash.
4. R returns tick zero and prefix `446697f66f2529e9`; P reproduces the run.
5. F1 returns Overview with its initial prefix `4be55d7e1c6599ec`.
   Held actions must be released after switching/reset before they fire again.
6. Escape or normal window close exits. The terminal reports balanced resource
   counts. Resize uses the existing production camera/viewport policy.

Automated EL1 coverage: 14 headless tests for stable registry/IDs, real lifecycle
ordering, deterministic reset, cross-lab isolation, seed dependence, checkpoint
repeatability, F hierarchy observations, pause/single-step/completion,
presentation-only interpolation, manual-input exclusion, focus/held input,
allocation-free update/render work, failure-safe switching, every construction
allocation boundary, short input taps, and readable numeric/debug glyphs.
Tests use the leak-checking allocator and meaningful public observations.
No production test is removed, weakened or disabled.

## Extension procedure

Add a stable kind/descriptor in explicit registry order, implement the required
state construction/fixed update/fingerprint/destruction dispatch in lab composition,
and add its presentation adapter in view.zig (or a lab-local file imported there).
The current spring-specific configuration fields should move into the new
lab-specific state when a different domain is added. Keep Host's ownership/reset
transaction and the main shell's input/window/renderer loop unchanged. Grant any
new context service explicitly; introduce no service without a concrete consumer.
Register additional production imports visibly in build/modules.zig. Add lifecycle,
reset/fingerprint and allocation tests before enabling the lab. Version incompatible
fingerprint/configuration changes rather than silently replacing v1 semantics.
RuntimeScene's allocating publication seam requires a separately justified
solution before adding steady-state dynamic F entity mutation.

## Legacy overlap, limitations and deferrals

Overview overlaps foundation/integrated clients in scene identity, transforms,
fixed updates and render submission, and character-oriented clients in their use
of scalar spring primitives. It does not reproduce locomotion, collision,
skeleton/clip playback, IK, paired interaction, wardrobe, environment art,
deformable-mesh qualification or historical evidence routes. No existing demo is
renamed, redirected, retired or substantially rewritten. Any later retirement
needs a behavior/controls/evidence coverage map, replacement headless and physical
tests, matching visual review and separate owner authorization.

No third lab was added. Physics expansion, generalized secondary motion,
particles/effects, projectiles, record/replay, world time/weather, canonical-human
work, HM08, 3D Model Lab, editors, gameplay and EL2 remain deferred.

The lab shell uses keyboard controls and compact production diagnostic glyphs,
not a UI framework. The OS window retains the renderer's generic caption; the
in-window active-lab title and controls identify the application. The existing
renderer/debug dependency graph still compiles some character types; no character
runtime or canonical-human content is instantiated. The accepted nonblocking
renderer diagnostics compile coupling remains unchanged.

C: briefly had no free space during dependency setup. The incomplete task-created
copies were removed; after C: regained sufficient space, pinned Zig/SDL/DXC were
copied successfully. Nothing was relocated to D:. One install attempt was denied
while the review executable was still open; normal window close followed by a
rebuild resolved it. Initial Zig name-shadowing and explicit float-conversion
errors were corrected before the first passing focused gate. These are resolved
development failures, not waived checks.


## Validation provenance and checkout bytes

The first complete `verify` invocation exited 1 (78/92 build steps succeeded,
9 failed). All engine/EL1, interaction stress and integration roots passed. The
failed nodes were formatting, exact historical documentation/content audits and
six canonical-content roots. Git's Windows CRLF conversion changed the
byte-sensitive inputs; a malformed-JSON test also encountered a converted
two-byte line ending where it expected one byte.

Restoring LF source files fixed formatting. Eighteen historical exact-document
hashes require mixed line endings retained in the accepted owner's raw files;
plain normalized Git blob bytes alone did not satisfy those protected hashes.
After confirming the owner was clean at the selected base and neither checkout
had Git content edits in those paths, 185 raw authoring/evidence text, PPM and
OBJ files were copied read-only from the owner into this worktree. Git confirms
zero content changes under assets/canonical_model and docs/history. Documentation
and content-policy audits then passed with the existing hashes and assertions.
No historical artifact or canonical schema change is included in the commit.

Fresh Windows worktrees must preserve the accepted raw byte inputs for these
pre-existing exact-byte checks. Repository-wide line-ending policy repair is
outside EL1. This is a validation-environment limitation, not a dependency of the
Engine Lab executable on canonical-human data.

## Recorded validation evidence

All commands below ran in the new sibling worktree. Build commands use the
pinned executable `& '.\.deps\zig-0.16.0\zig.exe'` and append
`-j1 --summary all --global-cache-dir '.zig-cache\el1-global'`.
Logs remain in ignored `.tmp/el1/`; dependencies, caches and outputs are not
committed. No command result is inferred from compilation or a later command.

| Invocation | Exit | Observed result |
| --- | --- | --- |
| `version` | 0 | Exactly 0.16.0, checked before implementation and after copying the pinned compiler |
| `fmt build.zig build/apps.zig build/gates.zig build/modules.zig build/tests_engine.zig src/app/engine_lab src/debug/debug_draw.zig tests/engine_lab_tests.zig` | 0 | Final pass emitted no changed paths |
| `build engine-lab` | 0 | Independent build/install: 10/10 steps; no sandbox or engine_smoke dependency |
| `build test-engine-lab engine-lab` | 0 | Final source: 14/14 steps, all 14 headless tests passed (`ui-final.log`) |
| `build test` | 0 | 21/21 fast aggregate steps passed (`test.log`); final-source EL1 tests also passed in the subsequent full run |
| `& '.\zig-out\bin\engine_lab.exe' --list` | 0 | Both stable lab IDs and controls listed |
| `& '.\zig-out\bin\engine_lab.exe' --verify` | 0 | All four default-seed checkpoints equal across 60 Hz and mixed frame schedules (`determinism.log`) |
| `& '.\zig-out\bin\engine_lab.exe' --smoke` | 0 | Final source: 16 frames, 16 draws, 7,815 changed readback pixels, 26/26 GPU resources, 19/19 fences, zero queue allocations after warmup (`smoke-final.log`) |
| `& '.\zig-out\bin\engine_lab.exe'` | 0 | Visible manual run: 33,182 frames, 25/25 GPU resources, 33,184/33,184 fences, zero queue allocations after warmup; Escape exited normally (`manual.log`) |
| `build verify` (initial run) | 1 | 78/92 steps, 9 failed nodes caused by checkout line endings; preserved in `verify.log`, resolved as documented above |
| `build test-canonical-human-base test-canonical-human-geometry-scaffold test-canonical-human-geometry-refinement test-canonical-human-geometry-adoption test-canonical-human-geometry-r4` | 0 | Recovery gate: 37/37 steps, including transitive geometry and R3 tests (`content-recovery.log`) |

Native inspection used the actual Windows application. F2 selected the fixed-step
lab; P ran it to tick 960; R restored the initial hash; T advanced exactly one tick;
a reset and second run reproduced all four checkpoint hashes; F1 restored Overview;
Escape exited normally. This is developer validation. Owner visual acceptance is
pending; no acceptance on the owner's behalf is claimed.

Resolved development failures include the two initial compile errors, the locked
executable installation, and the first aggregate checkout-byte failures described
above. A Git metadata-refresh permission review timed out; its allowed retry ran.
Refreshing verified-unchanged entries staged zero content changes and removed
stale line-ending status entries. No permission rejection left work blocked.

## Commit scope

Seven files added:

- `src/app/engine_lab/main.zig`
- `src/app/engine_lab/labs.zig`
- `src/app/engine_lab/actions.zig`
- `src/app/engine_lab/view.zig`
- `tests/engine_lab_tests.zig`
- `assets/engine_lab/white.png`
- `docs/implementation/engine_lab_el1.md`

Ten files modified:

- `README.md`
- `assets/manifest.json`
- `build.zig`
- `build/apps.zig`
- `build/gates.zig`
- `build/modules.zig`
- `build/tests_engine.zig`
- `docs/TESTING.md`
- `src/debug/debug_draw.zig`
- `tools/checks/architecture.ps1`

The shared diagnostic-glyph repair and checkout-byte recovery are the only
necessary adjustments beyond the new application/build/test/report additions.
No dependency version, accepted architectural contract, existing application
entry point, historical artifact, or canonical-human implementation is changed.
No optional lab or next-milestone work is included.

## Final aggregate and existing-application validation

| Invocation (same pinned compiler and build flags as above) | Exit | Observed result |
| --- | --- | --- |
| `build verify` (final run) | 0 | 92/92 steps succeeded; 685 reported test executions across 37 test executables; full engine integration/stress/content gates, all three application compilations, formatting, architecture, documentation and content audits passed (`verify-final.log`) |
| `build` | 0 | 22/22 steps; default engine_sandbox and engine_smoke build/install preserved (`default-build.log`) |
| `build run-engine-smoke` | 0 | 24/24 steps; D3D12/DXIL, 6 frames/6 draws, 15,129 changed pixels, 17/17 GPU resources, 8/8 fences, zero steady queue allocations (`engine-smoke.log`) |
| `build run-engine-lab ... -- --verify` | 0 | 13/13 steps; independent run target and all four checkpoint hashes passed (`run-target.log`); build flags occur before `--` |

The repository hygiene gate passed for 365 implementation/policy files. The
architecture audit verified 53 modules reachable from the independent entry and
42 from the headless test graph, with no forbidden application/canonical-human
reachability or reverse Engine Lab import. The final changed-Zig scan found zero
TODO, FIXME, unreachable or SkipZigTest markers. Review found no fake implementations,
placeholder assets, disabled tests, dependency-lock edits, generated-file additions
or unrelated content changes. The white texture is the real neutral sampling asset.

The owner's original worktree remains clean on master at
cb60fc9a9b24ba7d69578ffc721948e9b00de8fd; local master and recorded origin/master
remain at that commit. Work occurred only in the new sibling. No merge, push,
rebase, worktree deletion or branch deletion was performed. The requested focused
commit belongs to feature/engine-lab-el1. No EL2 work was started.

Final standard gate: build check exited 0 with 28/28 steps succeeded after the
report was finalized (check-final.log). All 14 EL1 tests passed again. The staged
diff check also exited 0; exactly the 17 files listed above are included.
