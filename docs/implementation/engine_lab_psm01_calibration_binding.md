# Engine Lab PSM01 calibration binding

Status: **OWNER ACCEPTED** at
`cfb2876c29df78f0cfa034d3df45ebe19764b141`, recorded on 2026-09-08.
The owner explicitly accepted the LAG marker. Independent source/evidence
review passed: the reviewer inspected patches, source, logs and captures;
the Windows/Zig/D3D12 executions were performed by the implementation owner,
not independently reexecuted by the reviewer.

Acceptance covers one application-owned horizontal binding, completed-controller
driver sampling, lifecycle and production presentation, and the generic
`Renderer.initializeUnifiedQueueWithCapacities` API. Existing solver and renderer
defaults are preserved. The conservative bound is 1,827/1,856 sprites, three
batches and 29 sprites of headroom. This acceptance applies to the feature
branch and does not imply incorporation into master. Original evidence manifests
retain their historical pending status and original raw bytes. The implementation
and execution record below describes the accepted checkpoint.
Engine Lab Integration is an unnumbered application integration track. Original
EL1 remains closed. The projectile-impact checkpoint at
`6e4f7c2aadf24c2336ab3cba2d60ff127e750e0e` remains owner accepted; the owner
also reports passing independent source/evidence review. Acceptance on this
feature branch does not imply incorporation into master.

## Local authority and acceptance bookkeeping

Worktree: `C:\Users\Chad\Documents\2d Renderer-engine-lab-integration`.
Branch: `feature/engine-lab-integration`. Starting HEAD was the clean expected
`6e4f7c2aadf24c2336ab3cba2d60ff127e750e0e`, with the three earlier accepted
integration revisions in its ancestry. The first local commit,
`44e79eccd7932737360fafeebc87e1c93571c8d2`, changes six documentation files
only and records that exact projectile-impact acceptance. Its formatting,
architecture/checkout, documentation and `check` gates passed before any
calibration source edit. Earlier evidence is preserved, including the corrected
1,751 observed / 1,792 conservative preexisting sprite count and zero headroom.

The second local commit implements the binding described here. Neither commit
is authorized for push or merge. Dependency pins and installed inputs remain
unchanged: Zig 0.16.0, SDL3 3.4.10 and DXC 1.9.2602.24. The task preflight
verified installed file hashes and archive identities. Other worktrees are
preserved. Fresh evidence lives under `.tmp/engine-lab-psm01-binding`.

## Ownership, coordinates and authored profile

[`calibration.zig`](../../src/app/engine_lab/calibration.zig) is one small
application-owned value stored inline in `Hub`. It directly owns one accepted
physics `secondary_motion.State`, plus previous/current reference and response
presentation samples. It owns no allocation, resource handle, clock, wall time,
accumulator, rate control, collider, attachment or scene entity. Physics gains
no dependency on this binding. Existing solver, rate resolver, legacy
attachments, character profiles and projectile/effect cores are unchanged.

The frame is the fixed hub world frame with its existing origin. The axis is
world +X, independent of facing. Length/displacement use metres; velocity uses
metres/second. The constant mount is `(0, 3.4)` metres above the completed
production controller root, clearing the provisional actor's head. The driver
is `completed_root.x + mount.x`; no moving actor origin is subtracted. The
reference is `completed_root + mount`, and the response marker is the reference
plus `(response.offset, 0)`. Vertical controller motion moves both markers
rigidly. This uses supported controller access, not a skeletal socket or a
published generic RuntimeScene actor transform.

| Authored value | Setting and purpose |
| --- | --- |
| Stiffness | 64 s^-2; natural frequency 8 rad/s |
| Damping | 6 s^-1; damping ratio 0.375 gives readable overshoot |
| Inertial gain | 0.65; visible response to ordinary controller acceleration |
| External gain / acceleration | 1 / exactly 0 m/s^2; no duplicated driver acceleration |
| Maximum displacement | 0.4 m in either horizontal direction |
| Maximum velocity | 3 m/s |
| Settling thresholds | 0.001 m and 0.01 m/s; accepted solver snaps to rest |

The accepted `Profile.validate` path runs during initialization, reset and solver
steps. Only this new profile is tuned. Retiming driver motion changes the input
trajectory; tuning an authored profile changes its response; scaling the whole
simulation changes how all systems advance in wall time. This binding does none
of those dynamically: it uses one fixed profile at ordinary simulation speed,
and adds no controls or rate policy.

## Tick order and failure policy

The original relative order remains intact. Each executed hub tick consumes a
pending projectile activation at the prior boundary, then executes controller,
animation, station and camera work. The binding samples that completed
controller root and executes exactly one public `State.step`, with the existing
1/240-second fixed duration and zero external acceleration. PSM01 owns its
internal integration stages. The existing integration then executes unchanged:
effects step, optional native-N projectile spawn, projectile step to N+1,
ordered event/color observation, one bridge consumption, event clearing.
Successful hub/projectile/effect tick alignment and age-zero impact births are
preserved. Binding failures log binding and tick context and propagate. The
existing fatal partial-tick policy remains; there is no whole-hub rollback claim.

Rendering interpolates the stored reference and response using the same alpha
as the actor. The running clock's supported alpha interval is `[0, 1)`; paused
rendering uses completed samples directly. Rendering never samples a new driver,
steps secondary motion, mutates the hub or applies the offset twice. Separate
`engine_lab.calibration.observations.v1` diagnostics include solver and stored
presentation history. These are diagnostic observations, not RR1 or save/replay
state. Selected hub-state v2 and projectile-impact observation identities stay
unchanged.

## Lifecycle

Initialization is at rest. Pause executes zero updates; paused single-step
executes exactly one binding step and the original one-tick effects/projectile
behavior. Facing reversal is ordinary fixed-axis motion, with no reset or sign
flip. Focus loss suppresses input through the existing mapper and does not reset
the binding. Any subsequent executed braking ticks still drive the solver.

Navigation first uses the supported actor repositioning path, then calls the
accepted `State.reset` API at the new root. Response, driver derivatives and both
presentation endpoints collapse to the new rest reference immediately, including
while paused, without advancing the hub clock. `State.fixed_ticks` counts steps
since the latest binding reset; navigation deliberately resets that diagnostic
counter while the hub tick continues. It is never rewritten to manufacture
clock equality.

Whole-hub reset keeps candidate-before-teardown reconstruction. Reset dominates
same-frame movement, activation, pause, step and navigation and executes no
reset-frame ticks. Success recreates the binding and both integration cores at
rest. Every allocation failure during reconstruction must retain the old live
hub, binding, projectiles and particles, and release the candidate prefix.

## Presentation and shared renderer API

The white vertical reference and orange response square are joined by a guide
with displacement-limit end ticks and a short `LAG` label. Existing labels,
particles, station histories, textures and actor content remain present. The
reference line remains distinguishable through the square at rest.

Budget constants live in [`view.zig`](../../src/app/engine_lab/view.zig), outside
the headless binding's physics dependencies. The accepted preexisting bound stays
1,792, with zero old headroom. The additional allowance is 64, giving an Engine
Lab CPU sprite queue ceiling of 1,856. Entry and mesh capacities stay 2,048 and
256. The view measures its own added primitives and production-font glyphs.

The only shared production API addition is
`Renderer.initializeUnifiedQueueWithCapacities(entries, sprites, meshes)` in
[`sdl_gpu_renderer.zig`](../../src/graphics/sdl_gpu_renderer.zig). It delegates to
existing queue validation/allocation, publishes only a successfully constructed
queue, and retains renderer ownership and reinitialization rejection. The old
`initializeUnifiedQueue` API still supplies the unchanged shared defaults.
Other clients are unchanged. The existing explicit `ensureGpuCapacity(1856)`
request runs before stabilization; its existing geometric allocation policy
rounds GPU storage to 2,048. The CPU admission limit remains 1,856. No graphics
API, resource lifetime, mesh-storage policy or renderer redesign is introduced.

The budget test separately measures all old content and all new content across
0..8 active projectiles with 192 particles, full station histories, run/pause,
diagnostics off/on, full-u64 ticks, font-derived worst counters and saturated
values, plus settled and both displacement limits. Every old <=1,792 assertion
is retained after subtracting the measured addition. Conservative hash costs
still come from the production font. Current measured addition is 35 sprites:
old observed 1,751, old conservative 1,792, combined observed 1,786, combined
conservative 1,827, with exactly three batches. Remaining combined conservative
headroom is 29; it is not assigned to future features.

## Verification and evidence

New headless integration tests use actual hub/controller execution and the public
solver to cover acceleration, braking, reversal, settling, completed driver
samples, exactly one update, equivalent frame grouping, interpolation purity,
pause/step, moving and paused navigation, focus suppression, live-effects reset
and allocation failure at every reconstruction point. Existing warm simulation
and rendering allocation guards execute with the binding enabled. Original EL1
tests and selected-state v2 fingerprint implementation bytes are preserved.

Focused renderer tests execute the public default/custom initialization methods
on an unstarted CPU-only renderer state, testing invalid capacities, duplicate
initialization, every allocation-failure prefix, cleanup and retry. They run
through `test-renderer-boundary`, and hence `check` and `test-full`, without a
window or GPU device. Physical GPU proof remains a separate required gate.

The existing `--verify` and `--smoke` fixtures remain. A separate bounded 1,440-tick
calibration fixture compares 60 Hz and mixed tick groupings. Native captures
cover acceleration, braking, reversal, pause, single-step, settled state,
navigation reanchoring, coexistence with projectiles/particles and reset. Native
checkpoint hashes are compared with the headless fixture. Captures use production
SDL3/D3D12 `captureUnified`, copied RGBA readback and lossless RGB PNG encoding.
Capture allocations are outside measured warm simulation/render frames. Still
captures temporarily select completed-state presentation, just as the earlier
impact fixture does; their HUD therefore reads PAUSED. The capture log separately
records the actual simulation pause flag before that temporary presentation
override, and the original flag is restored.

Fresh final gate results were recorded on 2026-09-08 against source SHA-256
`62506383fc7529be3ee63872f6e8e30cd36a55beca99e632a4d641ac75f72001`.
This identity hashes sorted source/build/test paths and their raw file hashes;
the package separately verifies all changed committed file bytes, including docs.
All commands use Zig 0.16.0, `-j1`, the existing `.zig-cache` and the established
`.tmp/projectile-impact/global-cache` / `.tmp/projectile-impact/install` family.
Each gate is a fresh command invocation; cache hits are visible in its raw log.

| Executed gate | Observed result, exit 0 |
| --- | --- |
| Engine Lab + PSM01 + effects/projectiles, Debug | 56 + 40 + 58 tests; 9/9 steps |
| Same focused targets, ReleaseSafe | 56 + 40 + 58 tests; 9/9 steps |
| Same focused targets, ReleaseFast | 56 + 40 + 58 tests; 9/9 steps |
| Focused renderer boundary / queue initialization | 6 tests across two roots; 5/5 steps |
| `check` | 612 tests across 15 roots; 39/39 steps |
| `test-full` | 709 tests across 21 roots; 52/52 steps |
| Default application, all three modes | 24/24 steps in each mode |
| Explicit `engine-lab`, all three modes | 11/11 steps in each mode |
| Physical `gpu-smoke` | 26/26 steps, D3D12 readback and injected cleanup checks |
| Engine Lab `--verify` | 13/13 steps; old fixtures plus 1,440-tick calibration |
| Engine Lab `--smoke` | 13/13 steps; original fixtures plus nine calibration captures |
| Lossless encoding | 7 single-impact + 8 multi-impact + 9 calibration captures |
| Formatting, architecture, documentation, checkout integrity | Passed; final staged receipts are in the ledger |

The 47 original headless checkpoint records exactly match the prior
accepted evidence. New binding observations use their own schema and do not
replace them. Grouping comparisons are within each tested binary/mode; no
universal cross-platform floating-point identity is claimed.

The final native run reports 26 GPU creations / 26 releases and 1,858 fence
acquisitions / 1,858 releases. Warm simulation/render frames have zero allocation
or resize growth and no dropped effects or particles; reconstruction and capture
allocations are outside that steady-state claim. Eight-projectile native maximum
was 1,489 combined sprites, separate from the deliberately saturated headless
1,786 observed / 1,827 conservative budget proof. The 35-sprite calibration
contribution, 1,856 CPU ceiling, 2,048 actual GPU capacity and three batches are
reported separately. Navigation evidence records hub tick 1472 and zero binding
steps since reset; the paused single step records 330 to 331.

The byte audit preserves all 16 original EL1 tests and the entire selected-state
v2 fingerprint function/helper suffix, original verification fixture bytes,
accepted solver/rate/legacy attachment code, impact module, action mapping,
projectile/effect cores, dependency pins and shared queue defaults. It also
rechecks 44 original-impact and 117 follow-up evidence files against preflight
hashes. No new TODO, FIXME, stub, placeholder, unexplained unreachable, disabled
or skipped test was found in added code.

Development logs remain honest: the first compile exposed the new input test's
incorrect `focused` field name; it was corrected to the installed
`keyboard_focused` contract. A new interpolation test initially requested
running alpha 1, outside the existing `[0,1)` interval; its inputs were corrected
to that supported range. The renderer tests were registered as their own CPU
test root. Final gates pass without modifying or weakening original tests.

The command ledger, raw logs, validation manifest, engineering inspection note,
reproduction scripts, ordered full-index binary patches and all 24 final native
readbacks/PNGs are in the task-local review ZIP. The exporter verifies that the
two ordered patches reconstruct the exact committed tree through a separate
temporary index, verifies committed-file bytes, and rechecks ZIP member hashes.
No branch, working index, prior evidence or other worktree is reset or cleaned.

## Reproduction and limits

From the dedicated worktree, after building, launch:

```powershell
& '.\.tmp\projectile-impact\install\bin\engine_lab.exe'
```

For fresh native evidence, supply both task-local capture destinations:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run-engine-lab -j1 --global-cache-dir .tmp/projectile-impact/global-cache -p .tmp/projectile-impact/install -- --smoke --impact-capture-dir .tmp/engine-lab-psm01-binding/captures/impact --calibration-capture-dir .tmp/engine-lab-psm01-binding/captures/calibration
```

No anatomy, garment migration, new force model, dynamic publication, World Time,
combat, editor or mode shell is included. This is a calibration object in the
existing camera; it follows vertical jumps rigidly and can travel beyond the
viewport along with the actor. Automated and engineering visual checks are
separate from independent review and owner visual acceptance, both now passed for the exact checkpoint above; the original evidence retains
its historical pending status. Projectile-impact acceptance is retained.
