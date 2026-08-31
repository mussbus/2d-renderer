# F4C2 Renderer, Application, and Evidence Boundary Extraction

Date: 2026-08-30

Status: **IMPLEMENTED / AWAITING OWNER REVIEW**

F4A, F4B1, F4B2, and F4C1 are owner-approved. F4 overall is not accepted.
F4C3, F4C4, F4C5, F4D, and F4E have not begun.

## Scope and starting gate

F4C2 began only after the required gate established:

| Gate | Observed result |
|---|---|
| HEAD | `ed6982d26eaf3c11a54ed2f371b61271efea8467` |
| Branch | `master` |
| Upstream | `origin/master` at the same commit |
| Ahead / behind | `0 / 0` |
| Worktree | Clean |
| Compiler | Zig `0.16.0` |
| F4C1 modules | Present |
| Baseline repository audit | Passed, including F4C1 ownership policy |

The installed SDL 3.4.10 GPU header was inspected before the extraction. The
used creation, claim, swapchain, submission, transfer-download, and transfer-map
entry points are declared by that header. F4C2 preserves the existing
SDL3/D3D12/DXIL route and does not add a backend.

## Pre-F4C2 `GpuDemo` responsibility inventory

| Category | Fields / behavior before extraction | Why it was misplaced or mixed |
|---|---|---|
| A. Application composition | `DemoMode`, 15 surviving routes, per-mode construction and teardown, frame loop, input selection, result checks | Correct application work, but colocated with raw backend lifetime |
| B. Platform / window lifecycle | SDL video/gamepad initialization, window creation/destruction, event-driven drawable refresh, minimize/restore state | Reusable platform state existed only inside a demo-named type |
| C. GPU backend ownership | Device, claimed window, swapchain format, shaders, pipelines, sampler, textures, buffers, transfer buffers, three frame slots, fences | Raw implementation handles were application fields |
| D. Renderer logic | Sprite batch and unified queue execution, camera consumption, GPU capacity, upload encoding, sprite/mesh range drawing | Reusable renderer capability was inseparable from mode routing |
| E. Asset upload / catalog | WIC decode coordination, texture-page creation/upload, sampling policy, mesh topology catalog and buffers, metrics | Application selected assets and also implemented GPU creation/upload |
| F. Evidence / capture | Historical directories, capture scheduling, D3D12 readback, PPM/PNG writing, hashes, manifests, owner-review metadata | Generic readback and prompt-specific reporting were one operation |
| G. Scenario integration | Controller, handshake, integrated, playground, modular-body, equipment, mesh, foundation, art, wardrobe, anatomy, and environment branches | Concrete scenarios sat beside backend code in the same owner |
| H. Diagnostics / metrics | Production resource/fence/frame metrics plus acceptance observations and manifest data | Production diagnostics and acceptance reporting were not distinguishable by dependency direction |

The major lifecycle sequence was also mixed in one type: allocate batch; start
SDL; create window and GPU device; claim the window; load shaders; create
sampler/textures/buffers/transfers/frame slots/pipelines; initialize a selected
scenario; render and optionally capture; write reports; then release every GPU
resource, device, window, SDL state, queue, catalog, and batch.

## Target ownership decisions

| Responsibility | Old owner | New owner | Public contract | Mutable-state owner | Consumers |
|---|---|---|---|---|---|
| Scenario selection and lifetime | `GpuDemo` | `DemoApplication` | `DemoMode`, `init`, `runVisible`, `deinit` | Application | `main.zig` |
| SDL platform/window state | `GpuDemo` fields | Renderer-private `PlatformWindow` within the SDL backend | Drawable snapshot and window-event method | Renderer private state | Application through renderer methods |
| Device and raw GPU handles | `GpuDemo` fields | Renderer-private `State` | `Renderer` methods only | Renderer | Application |
| Sprite and mixed-frame execution | `GpuDemo` methods | `Renderer` | batch/queue access plus prepared-frame render methods | Renderer | Application and production submitters |
| Camera policy | Mixed | Application/scenario policy; renderer stores resolved input | `camera()` render-facing value | Renderer stores current resolved value; application mutates policy | Application |
| Texture and mesh upload | `GpuDemo` methods | `Renderer` | definition-based initialization and metadata snapshots | Renderer | Application selects definitions |
| Generic GPU readback | `GpuDemo` path-writing methods | `Renderer` plus `CapturedFrame` | `captureUnified` returns owned copied RGBA8 | Renderer owns transfer; caller owns returned pixels | Application |
| PPM/PNG output and pixel evidence | `GpuDemo` | `capture_writer` | `writePpm`, `writePng`, `PixelEvidence` | Evidence writer owns files; capture caller owns copied pixels | Application evidence route |
| Capture scheduling and manifests | `GpuDemo` | `DemoApplication` | Application-private functions | Application | Named validation scenarios |
| Production resource metrics | `GpuDemo` fields | `Renderer` | copied `ResourceMetrics` and resource snapshot | Renderer | Application diagnostics |
| Acceptance observations | `GpuDemo` | `DemoApplication` and existing evidence modules | copied observation/artifact values | Application/evidence | Report writers |

The four-line `gpu_demo.zig` file remains only as a compatibility alias from
`GpuDemo`/`DemoMode` to `DemoApplication`. The executable imports
`DemoApplication` directly; no behavior is implemented by the alias.

## Before / after responsibility matrix

| Responsibility | Before owner | After owner | Still in `GpuDemo`? | Reason |
|---|---|---|---|---|
| Application composition | `GpuDemo` | `DemoApplication` | No | Application concern |
| Mode routing | `GpuDemo` | `DemoApplication` | No | Concrete route choice is not rendering |
| SDL lifecycle | `GpuDemo` | Renderer-private platform state | No | Reusable SDL GPU construction prerequisite |
| Window | `GpuDemo` | Renderer-private platform state | No | Backend-bound swapchain/window lifetime |
| GPU device | `GpuDemo` | Renderer-private state | No | Raw backend authority |
| Swapchain interaction | `GpuDemo` | Renderer | No | GPU execution detail |
| Shader/pipeline creation | `GpuDemo` | Renderer | No | Backend resource ownership |
| Buffers | `GpuDemo` | Renderer | No | Backend resource ownership |
| Textures/samplers | `GpuDemo` | Renderer | No | Backend resource ownership |
| Asset upload | `GpuDemo` | Renderer; selection remains application-owned | No | Separates what to load from how to upload |
| Render submission execution | `GpuDemo` | Renderer | No | Reusable production behavior |
| Render queue storage | `GpuDemo` | Renderer | No | One production queue and lifetime |
| Camera | `GpuDemo` | Application policy through renderer-facing resolved value | No | Backend consumes rather than selects camera policy |
| Asset selection | `GpuDemo` | `DemoApplication` | No | Scenario/application policy |
| Evidence scheduling | `GpuDemo` | `DemoApplication` | No | Validation policy |
| GPU readback | `GpuDemo` | Renderer generic capture | No | Reusable backend operation |
| Screenshot writing | `GpuDemo` | `capture_writer` | No | Evidence/file concern |
| Acceptance observations | `GpuDemo` | Application plus existing evidence modules | No | Read-only validation concern |
| Scene-specific branches | `GpuDemo` | `DemoApplication` | No | Application composition |
| Production metrics | `GpuDemo` | Renderer | No | Resource owner reports its state |
| Compatibility names | `GpuDemo` | Four-line alias | Yes, names only | Avoids unnecessary downstream source breakage |

## Renderer/backend architecture

`sdl_gpu_renderer.Renderer` owns one allocation whose type is private to its
module. The exported value contains no raw SDL GPU handle. Private state owns:

- SDL initialization and the resizable/hidden window;
- the D3D12-only SDL GPU device and window claim;
- sprite and mesh shaders and target-compatible pipelines;
- shared quad and mesh topology buffers;
- procedural and image-backed textures and samplers;
- upload and download transfer buffers;
- three fenced frame slots and transactional capacity replacement;
- `SpriteBatch`, `UnifiedRenderQueue`, and `mesh_gpu_catalog.Catalog`;
- current resolved camera/drawable values and production metrics.

Initialization and destruction retain the old order and failure cleanup.
`Renderer.deinit` invokes private state cleanup before freeing the state
allocation. The existing initialization fault injector and runtime replacement
failure checks now exercise this production owner through `Renderer`.

The application submits requests to the existing `SpriteBatch` or
`UnifiedRenderQueue`. A prepared value is passed back to the renderer, which
acquires the appropriate frame slot, uploads instances, resolves texture pages
and persistent mesh topology, encodes the existing indexed-instanced draws,
submits a fence, and advances the slot. Shader behavior, ordering keys, atlas
coordinates, blend state, draw ranges, and camera transforms are unchanged.

## Application composition architecture

`DemoApplication` is the surviving executable's composition root. It owns:

- mode selection and all 15 current routes;
- scenario construction/destruction and fixed-frame orchestration;
- platform input routing and scripted-input selection;
- application camera/follow policy and resolved camera publication;
- selection of art definitions and mesh definition views to initialize;
- capture requests, historical path selection, observations, and manifests;
- route-specific completion diagnostics.

It does not declare or manipulate an `SDL_GPU*` handle. The simple animated
sprite pattern is also application-owned; it builds requests in the production
batch and is not a renderer mode.

No surviving route was deleted or renamed: `sprites`, `controller`,
`handshake_ik`, `integrated`, `playground`, `modular_body`, `equipment`,
`mesh_attachments`, `side_scroller`, `foundation`, `art_assets`, `wardrobe`,
`visual_quality`, `anatomy_quality`, and `environment` remain registered.

## Evidence/capture architecture

The generic flow is:

```text
DemoApplication capture schedule
        -> Renderer.captureUnified(prepared queue)
        -> GPU transfer and fence completion
        -> copied, tightly packed RGBA8 CapturedFrame
        -> capture_writer PPM/PNG output
        -> application-owned observations/manifests
```

`CapturedFrame` owns its copied pixel allocation and has explicit `deinit`.
The renderer maps its transfer buffer only long enough to copy rows, then
unmaps before returning. The evidence writer receives a const capture pointer;
it imports the capture contract, not the SDL renderer. Its one documented
exception is the existing `visual_truth` PNG encoder, which receives copied
bytes and no production authority. Historical output directories and names are
kept in `DemoApplication` to avoid F4E archival or naming work.

## Scenario-specific branch result

All former mode branches moved together to `DemoApplication.runVisible`.
Wardrobe, visual-quality, anatomy-quality, environment, foundation, art-asset,
mesh-attachment, character, interaction, and minimal-sprite decisions are
absent from the renderer. Evidence frame predicates and overlay staging also
remain application/scenario work. The renderer branches only on generic
prepared sprite/mesh ranges, drawable availability, resource availability, and
texture/mesh identifiers.

## Asset upload and camera results

The application still selects the exact current art-pack definitions. The
renderer decodes through the existing `image_decode` module, transactionally
creates pages, performs the same aligned upload/fence wait, releases decoded
pixels, and publishes only texture-page metadata. Mesh definitions similarly
enter the existing persistent catalog and buffers. No asset, region, atlas, or
hash changed.

Scenarios still select/follow/reset the camera. The renderer supplies the
drawable-derived viewport and consumes the resolved `Camera2D` during
encoding. It does not inspect a scenario to choose a camera.

## Static dependency policy

`tools/check_repository.ps1` now fails if:

- the production SDL renderer imports any of the twelve scenario modules;
- the renderer imports evidence/report/application modules;
- the renderer contains historical prompt directories, manifests, report
  writers, or `DemoMode`;
- renderer state becomes public instead of private behind `Renderer`;
- generic capture owns a file/directory or output encoder;
- application/evidence/capture-contract code owns raw SDL GPU resources;
- evidence imports the SDL renderer rather than `frame_capture`;
- `GpuDemo` grows beyond its compatibility alias role;
- the four boundary modules or focused capture-contract test disappear from
  build wiring.

The scenario-import allowlist now names `src/app/demo_application.zig` instead
of `src/graphics/gpu_demo.zig`. The only new evidence exception is
`capture_writer -> visual_truth` for the established PNG encoder.

## Before / after metrics

| Metric | Before | After |
|---|---:|---:|
| `GpuDemo` source lines | 4,709 | 4 compatibility lines |
| `GpuDemo` source bytes | 255,076 | 157 |
| `GpuDemo` direct source imports | 39 | 1 (`demo_application`) |
| `GpuDemo` build-injected dependencies | 60 on the executable root | 0 on the alias; executable root has 3 |
| Application composition lines / bytes | Embedded | 2,860 / 159,799 |
| Application direct source imports | Embedded | 41 |
| Application build-injected dependencies | Embedded in the 60 root edges | 62, deliberately containing the surviving scenario graph |
| Application scenario imports | 12 | 12 |
| SDL renderer lines / bytes | Embedded | 2,064 / 101,223 |
| SDL renderer direct/build dependencies | Embedded | 12 source imports / 11 injected modules |
| Renderer -> demo/scenario edges | 12 colocated imports | 0 |
| Renderer -> evidence/report edges | 4+ colocated imports | 0 |
| Evidence -> backend edges | Direct methods on the same object | 0; evidence imports capture contract only |
| Raw public backend fields | All raw handles on public `GpuDemo` | 0 raw handles; one private-typed state pointer in `Renderer` |
| New boundary modules | 0 | 4: renderer, frame capture, evidence writer, application |
| Focused boundary tests | 0 | 3 copied-frame ownership/shape/lifetime tests |

Line count is evidence of movement, not the objective. The important result is
that backend and evidence dependencies point through production contracts and
the application retains the scenario fan-out.

## Backend replaceability probe

If SDL's current D3D12 implementation is replaced behind the same contract,
the primary changes should be `sdl_gpu_renderer.zig`, its construction/build
dependencies, and backend/GPU tests. `frame_capture.zig`, the application,
wardrobe, environment, anatomy, character, interaction, and evidence writers
should not change unless the generic prepared-frame or capture-result contract
itself changes. Remaining unavoidable coupling is that `Renderer` currently
exposes SDL window events and is explicitly Windows/SDL3/D3D12/DXIL; F4C2 did
not create a backend plugin interface.

## Second-application readiness probe

Yes, architecturally. A second executable can import `sdl_gpu_renderer`, call
`Renderer.init`, submit a trivial frame through `spriteBatch`, render it, and
deinitialize without importing `GpuDemo` or any scenario. Its build must still
provide the pinned SDL library and installed DXIL shader files. F4C2 does not
create that second executable; F4D owns the independent-app proof.

## Remaining architectural debt

- **F4C3:** `CharacterInstance` authority decomposition and interaction-facing
  surfaces remain unchanged.
- **F4C4:** RuntimeScene/F adoption and the broader platform/domain action
  boundary remain unchanged.
- **F4C5:** `build.zig` remains monolithic; F4C2 adds only the modules and one
  focused target necessary for this boundary.
- **F4D:** no independent second application was created.
- **F4E:** historical prompt directories, filenames, reports, and evidence
  archives remain intact.

`DemoApplication` remains intentionally substantial because it contains every
surviving scenario and historical evidence route. Splitting each scenario into
new app packages would cross into broader application/build modularization and
was not required to remove renderer authority.

## Validation record

- Focused renderer-boundary tests: `3/3` tests passed.
- Normal build: `20/20` steps passed.
- Repository audit: passed across 262 source files, including the new F4C2
  dependency-direction rules.
- Complete non-GPU check: `55/55` steps and `519/519` tests passed.
- Full regression: the first aggregate run encountered a transient Zig test
  listener timeout after reporting `620/620` assertions passed. The implicated
  structural (`80/80`) and visual-geometry (`15/15`) targets then passed in
  isolation. The unchanged exact aggregate command was rerun and passed
  `62/62` steps and `630/630` tests.
- Physical GPU smoke: `22/22` steps passed on the actual SDL `direct3d12`
  backend with DXIL, fault-injection cleanup, one instanced draw, and RGBA8
  readback verification.
- Surviving-route samples: the two-frame sprite route, complete 720-frame
  handshake/IK route, and complete 720-frame environment route passed on
  `direct3d12`/DXIL. Deliberately shortened foundation and handshake evidence
  invocations were rejected by their existing exact-route contracts, after
  which the complete handshake route passed.
- Documentation audit: passed with 46 required files, 42 Markdown files, and
  106 valid local Markdown targets.

The first full-suite listener timeout and the exact-frame negative route checks
changed no code, tests, thresholds, or acceptance contracts.

## No-scope-expansion attestation

- No surviving demo was retired, including `art_assets`.
- No `CharacterInstance` decomposition occurred.
- No interaction-authority redesign occurred.
- No F-adoption or RuntimeScene adapter was implemented.
- No platform/domain action redesign occurred.
- No build-system modularization occurred beyond required registrations.
- No canonical authority, canonical asset, hash, topology, or route changed.
- No asset naming migration occurred.
- No broad evidence archival or prompt-name cleanup occurred.
- F4C3, F4C4, F4C5, F4D, F4E, and downstream feature work did not begin.
- No commit or push is part of this implementation.
