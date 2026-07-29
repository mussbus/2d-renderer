# SDL3 GPU 2D Skeletal Character Prototype

This repository contains the reproducible Prompt 1 build foundation for Zig 0.16.0, Windows 11 x64, SDL 3.4.10, the SDL3 GPU API with an explicit Direct3D 12 backend, and offline DXIL compilation with DXC v1.9.2602.24.

Project navigation:

- [roadmap, current state, architecture, scope, and authoring contracts](docs/project/README.md);
- [prompt ledger and exact/reconstructed source status](docs/prompts/INDEX.md);
- [architecture decisions](docs/decisions/README.md);
- [implementation-report archive](docs/reports/README.md).

Bootstrap the exact dependencies once from PowerShell, then normal build operations are offline:

```powershell
& '.\tools\bootstrap_dependencies.ps1'
zig build
zig build test
zig build run
zig build gpu-smoke
zig build check
```

The default build compiles and validates both HLSL stages with repository-local DXC, installs `SDL3.dll` beside `skeletal_gpu_demo.exe`, and installs DXIL under `zig-out/bin/shaders`. `zig build run` launches that installed layout. The default visible demonstration submits 1,000 deterministic procedural sprites through one authoritative instanced batch and one actual GPU draw. `zig build run -- --frames 300 --demo humanoid` instead runs the deterministic 16-bone, four-socket, 15-attachment segmented humanoid through that same batch. `gpu-smoke` uses the batch for fault cleanup, presentation, two UV-selected sprites, and fenced render-target readback. It fails rather than skipping when the required graphical session, D3D12 backend, DXIL support, pipeline, or readback is unavailable.

The batch is the production rendering foundation, not a parallel demonstration renderer. Prompt 3 adds foundational math, immutable skeleton definitions, independent mutable poses, hierarchical sockets, render attachments, and programmatic pose manipulation. Prompt 4 adds eight immutable authored clips, typed events, deterministic sampling, component-space blending, one-shot fallbacks, and the finite `zig build run -- --frames 360 --demo animation` idle/walk demonstration. Prompt 5 adds one authoritative 240 Hz physics/animation clock, SDL keyboard/gamepad input, edge-preserving `CharacterIntent`, swept static AABB collision, gravity, variable-height jump, coyote time, jump buffering, landing reporting, render interpolation, and the interactive `zig build run -- --demo controller` mode. Its deterministic GPU-backed acceptance route is `zig build run -- --frames 600 --demo controller --scripted-input`. Prompt 6 layers contact-relative speed-scaled walk bounce, physics-impact landing compression, and acceleration-driven head lag entirely into the visual local pose; its deterministic evidence route is `zig build run -- --frames 900 --demo secondary-motion --scripted-input`. Prompt 7 adds stable entity IDs, independently owned character runtime state, character-local reflection, bounded semantic layer overrides, and globally interleaved two-character ordering; its evidence route is `zig build run -- --frames 720 --demo multi-character`. Prompt 8 adds the allocation-free shared paired-interaction manager and deterministic fixed-position handshake; its non-IK evidence route remains `zig build run -- --frames 720 --demo handshake --scripted-input`. Prompt 9 adds analytical two-bone arm IK, stable humanoid bindings, symmetric pre-IK midpoint constraints, deterministic timeline weighting, mirrored bend control, and perturbed-contact proof through `zig build run -- --frames 720 --demo handshake-ik --scripted-input`. Prompt 10 adds authoritative-world ground probes, anatomical per-foot world locks, immutable leg bindings, analytical visual leg IK, fixed-tick acquisition/release, and measured floor/platform quality through `zig build run -- --frames 1200 --demo foot-planting --scripted-input`. Prompt 11 composes every production path into `zig build run -- --frames 2400 --demo integrated --scripted-input`, adds bounded read-only diagnostics and milestone snapshots, and optionally appends debug primitives with `--debug-visualization` through the same one-draw sprite batch. Prompt 14 moves every sprite submission into world metres, adds a pure `Camera2D`, resizable/high-DPI swapchain rendering, deterministic dead-zone following, an extended cave playground, and three-layer parallax. Its bounded evidence route is `zig build run -- --frames 1100 --demo side-scroller --scripted-input`; the fixed 640×480 GPU readback target remains independent.

Prompt 16 adds data-defined adult anatomy modules, repeated hierarchical body parts, parametric build morphology, per-channel and per-instance overrides, independently addressable face features, short/long/ponytail hair, and topology-independent presentation profiles. Its non-sexual evidence route is `zig build run -- --frames 240 --demo modular-body`: the conventional male and female visibly select different compositional face definitions, while those presets and the articulated extra-arms/tail/horn preset share one canonical skeleton, animation library, global sprite batch, and draw path.

Prompt 17 adds topology-aware layered clothing and equipment, transactional per-character loadouts, separate logical slots and coverage metadata, bounded one/every/specific anatomy binding, deterministic numeric attribute modifiers, and declarative capability grants. Its evidence route is `zig build run -- --frames 240 --demo equipment`: one sweatshirt definition produces two sleeves on the conventional body and four on the modular four-arm body while layered clothing, bilateral armor, multi-slot replacement, conflict rejection, restoration, modifiers, and capabilities remain on the existing global sprite batch.

Prompt 18 adds drift-resistant per-character breathing and one resolved appearance-deformation pipeline shared by anatomy and topology-generated clothing/equipment. Exact anatomy-instance bindings drive every generated sleeve, flexible visuals use declarative response strengths, rigid equipment can opt out, and physics/controller/IK/interaction/effect state remains invariant. Its bounded GPU evidence route is `zig build run -- --frames 240 --demo breathing`.

Prompt 19 generalizes an equipment visual to either the established rigid sprite or a validated immutable deformable mesh without adding a second character/item architecture. Its unified semantic queue interleaves both primitive kinds, while persistent topology buffers and three bounded dynamic instance slots support fitted garments, topology-expanded sleeves, and capes. Its honest mixed-render evidence route is `zig build run -- --frames 240 --demo mesh-attachments`.

Prompt 20 adds one reusable fixed-capacity attachment secondary-motion primitive shared by equipment and anatomy visuals. Mutable nodes live in resolved character visual instances, never shared cape/hair/mesh definitions. The equipment cape, topology-expanded loose sleeves, long hair, and ponytail use the same bounded fixed-step path; short hair remains rigid. Equip/unequip/re-equip and facing changes reset deterministically, and controller/physics/interaction state remains invariant. Its GPU-backed evidence route is `zig build run -- --frames 240 --demo attachment-secondary`.

Prompt 21 adds data-defined finite numeric attributes, source-counted capabilities, stable-source additive/multiplicative resolution, and character-owned recomputation after loadout changes. Movement speed and jump strength feed the existing controller, double jump grants exactly one air jump, and Left Shift/gamepad right shoulder produces a bounded collision-aware dash only when granted. Carrying capacity, armor, and physical damage reduction remain queryable for future inventory/combat consumers. Appearance never implies gameplay properties. Its GPU-backed evidence route is `zig build run -- --frames 240 --demo properties`.

Prompt 22 added the focused Character + World Foundation Playground. One
modular controlled character, a canonical handshake partner, and a
nonstandard-topology showcase share the established skeleton, animation,
controller, collision, interaction, IK, foot-planting, deformation,
secondary-motion, equipment, and unified sprite/mesh paths in a traversable
cave. Prompt 27 later promoted the visible `foundation` CLI to the production
art composition. The original 1,800-frame Prompt 22 scene remains covered by:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-foundation
```

Prompt 23 adds a production-oriented PNG/atlas presentation boundary without changing gameplay or creating another renderer. Windows Imaging Component decodes alpha-bearing installed PNGs, immutable art-pack definitions resolve numeric semantic/view IDs to validated regions, and bounded persistent texture/sampler pages are shared by sprite and mesh ranges. Two original nearest-sampled technical pixel-art atlases prove eight regions, synthetic view extensibility, alpha, honest page-transition draws, cleanup, and allocation-free steady state; a definition test proves that a future pack may instead select linear filtering:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-art
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo art-assets --frames 240
```

Prompt 24 adds original segmented male and female side/front pixel-art atlases, separates gameplay left/right facing from presentation view, projects the shared authoritative pose into front art, keeps reflection side-only, gives interactions view authority, and integrates breathing, long-hair secondary motion, IK, foot planting, explicit front layering, bald/buzz selection, and bounded view overrides without another animator or renderer:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo character-presentation --scripted-input --frames 360
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo character-presentation --interactive
```

Prompt 24A separates the shipped neutral base anatomy from removable clothing. Prompt 25 adds 30 reusable cosmetic wardrobe items, 36 side/front components, 15 typed outfit presets, topology-aware sleeves/gloves/legwear/footwear, layered blouse-plus-cardigan composition, a deformable long skirt with bounded secondary motion, and transactional hot swapping through the existing global queue:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo wardrobe --scripted-input --frames 600
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo wardrobe --interactive
```

Prompt 25A re-authors the separated male/female production atlases, corrects
view spacing, joint overlap, internal connector layering, padded sleeve/shoe
extraction, and footwear registration, and adds an exact D3D12 capture gate.
It preserves the Prompt 24A anatomy boundary and Prompt 25 reusable wardrobe:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation
& '.\.deps\zig-0.16.0\zig.exe' build test-wardrobe
& '.\zig-out\bin\skeletal_gpu_demo.exe' --frames 600 --demo visual-quality --scripted-input
```

Prompt 25B completes the remaining footwear, shoulder, elbow, pelvis/thigh,
and hand corrections. Prompt 25C builds the semantic visual-geometry
measuring system, and Prompt 25D hardens that ruler, reauthors the actual
production content, retains controlled failing fixtures, reaches zero
production geometry failures, and approves 12 real D3D12 goldens. Prompt 25E
then consolidates project history, authority boundaries, authoring contracts,
known gaps, exact prompt provenance, and documentation auditing without
changing accepted art or runtime behavior.

Prompt 26 adds two original layered environment themes over the unchanged
Prompt 22 world: a violet crystal ruin and a neutral diagnostic chamber.
Far/mid/terrain/foreground art uses the existing camera and global queue, both
theme pages preload before steady state, and `T` swaps them without changing
physics, animation, view, wardrobe, clock, pending input, interaction
ownership, camera, collision, or GPU resources. Thin white standable tops are
derived exactly from `ground_query_eligible` collider tops; walls and
decorative ledges receive none:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-environment -j1
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo environment --scripted-input --frames 720
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo environment --interactive
```

The open-ended primary foundation route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo foundation --interactive
```

Prompt 27 promotes that same `foundation` route to the complete real-art
integration root. Prompt 27A retains the original 2,100-frame report and nine
captures under `zig-out/p27_visual_foundation` as historical evidence, while
reopening manual visual acceptance and replacing phase/frame capture timing
with a 2,400-frame, 16-case state-conditioned evidence matrix. The current
route records authoritative controller, presentation, interaction, foot
surface, theme, debug, renderer, resource, and allocation metadata beside
each real D3D12 readback under `zig-out/p27a_evidence/candidate`.

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --scripted-input --frames 2400
& '.\.deps\zig-0.16.0\zig.exe' build p27a-review
```

`p27a-review` validates capture order, metadata, PPM payloads, independent
pixel hashes, semantic thresholds, and steady-state counters, then writes
PNG conversions, five labeled contact sheets, an ordered review manifest, and
260 or more raw metrics to `zig-out/p27a_evidence/review_package`. It does not
approve aesthetics or promote goldens. Prompt 27A manual visual acceptance is
`[PENDING OWNER REVIEW]`.

Prompt 27B keeps that 16-case matrix and adds one measured
contact/framing/parallax/presence contract over the same production scene.
Ground evidence connects immutable collider tops, post-IK sole sockets,
alpha-derived footwear endpoints, actual queue submissions, and real D3D12
pixels. One existing camera applies a bounded vertical safe-region correction
from actual submitted character bounds. Actual far/mid/gameplay anchors and
camera factors are traced and checked semantically and from readback pixels.
The script uses ordinary controller movement to avoid uncontrolled
character-character overlap; general interactive character collision is not
claimed.

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-visual-foundation -j1 --global-cache-dir '.zig-cache\p27b-global'
& '.\.deps\zig-0.16.0\zig.exe' build p27b-coherence-report -j1 --global-cache-dir '.zig-cache\p27b-global'
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --scripted-input --frames 2400
& '.\.deps\zig-0.16.0\zig.exe' build p27b-review
```

The current semantic report contains 9,714 metrics with zero failures. The
independent D3D12 review contains 55 pixel metrics with zero failures, and two
isolated runs are byte-identical. Prompt 27B adds four supplemental captures
without overwriting the 16 Prompt 27A cases. The fourth is a diagnostic
readback of the first frame after a direct 960×540 to 640×480 resize; it
proves 37.50 px headroom, 36.77 px footroom, and projection agreement while
subsequent world-camera movement remains below the unchanged 16 px bound.
The review candidates are not approved goldens; owner/manual acceptance
remains `[PENDING OWNER REVIEW]`.

## Interactive playground

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo playground --interactive
```

| Control | Action |
| --- | --- |
| `A` / Left Arrow | Move left |
| `D` / Right Arrow | Move right |
| Space | Jump; hold for a higher jump or release early for a shorter jump |
| Left Shift | Dash when granted by resolved character capabilities |
| `E` | Interact |
| `R` | Reset the playground |
| `F1` | Toggle debug visualization |
| `F2` | Cycle normal, quarter-speed, and paused controller time modes where exposed |
| `F3` | Single-step a paused controller route where exposed |
| `C` | Cycle the controlled character body preset in the foundation playground |
| `V` | Cycle the controlled character global build value in the foundation playground |
| `H` | Cycle hair in the foundation playground |
| `L` | Legacy alias for cycling complete equipment/outfit loadouts in the foundation route |
| `Q` | Cycle automatic, force side, and force front in presentation routes |
| `O` | Cycle complete outfit presets in wardrobe and foundation routes |
| `P` | Pause or resume wardrobe/foundation simulation for inspection |
| `T` | Cycle the preloaded environment theme in environment and foundation routes |
| Escape | Exit |

Walk right toward the passive character and stop near the authored handshake position. Both characters must be grounded and facing one another; spacing remains deliberately strict, and pressing `E` never snaps or warps either root. The raised platforms, short/held jump behavior, foot planting, arm IK, reset, and debug overlay all use the production runtime paths.

The window can be resized without changing character scale. Walk left beyond the original view to exercise camera following and the distant, midground, and gameplay cave layers.

The bounded automated route uses synthetic raw key state through the identical keyboard mapping:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 1800 --demo playground --scripted-input
```

`playground`, `side-scroller`, `equipment`, `properties`, `breathing`, `mesh-attachments`, and `attachment-secondary` remain focused regression/evidence routes. `foundation` composes their production implementations; it does not replace them.

Start with:

- [`AGENTS.md`](AGENTS.md) for binding requirements and prohibitions.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for system boundaries and conventions.
- [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md) for exact versions, hashes, and backend policy.
- [`docs/TESTING.md`](docs/TESTING.md) for test layers and acceptance checks.
- [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) for staged implementation and the final build interface.
- [`docs/SPRITE_BATCH.md`](docs/SPRITE_BATCH.md) for exact CPU/HLSL layout, ordering, capacity, and frame-safety contracts.
- [`docs/HUMANOID.md`](docs/HUMANOID.md) for transform, hierarchy, attachment, body-proportion, and deterministic-demo contracts.
- [`docs/ANATOMY.md`](docs/ANATOMY.md) for compositional adult anatomy, multiplicity, morphology, presentation, face/hair, ownership, and alternative-rig boundaries.
- [`docs/EQUIPMENT.md`](docs/EQUIPMENT.md) for typed equipment definitions, topology-aware visual recipes, transactional loadouts, layered coverage, effect declarations, rendering integration, and evidence.
- [`docs/CHARACTER_PROPERTIES.md`](docs/CHARACTER_PROPERTIES.md) for attribute metadata, deterministic stacking, capability sources, controller consumers, dash/double-jump state, and evidence.
- [`docs/DEFORMATION.md`](docs/DEFORMATION.md) for fixed-tick breathing, shared instance-resolved deformation, clothing response, composition order, gameplay invariants, and evidence.
- [`docs/MESH_ATTACHMENTS.md`](docs/MESH_ATTACHMENTS.md) for mesh validation, topology-aware runtime ownership, unified ordering, GPU resources, batching, metrics, and evidence.
- [`docs/ATTACHMENT_SECONDARY_MOTION.md`](docs/ATTACHMENT_SECONDARY_MOTION.md) for bounded visual control points, per-instance ownership, lifecycle/facing reset, composition, and evidence.
- [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md) for PNG decoding, immutable art packs, stable semantic/view identity, atlas validation, multi-page GPU ownership, installed assets, and the future offline authoring boundary.
- [`docs/ENVIRONMENT_THEMES.md`](docs/ENVIRONMENT_THEMES.md) for layered theme ownership, parallax, collision-derived white standable edges, hot-swap invariants, bounds, and the future level-editor boundary.
- [`docs/CHARACTER_PRESENTATION.md`](docs/CHARACTER_PRESENTATION.md) for facing/view separation, interaction authority, shared-pose interpretation, original character art, layers, secondary reset, and evidence.
- [`docs/WARDROBE.md`](docs/WARDROBE.md) for garment semantics, view/topology binding, presets, controls, and the future authoring workflow.
- [`docs/VISUAL_GEOMETRY.md`](docs/VISUAL_GEOMETRY.md) for semantic landmarks, visible-alpha geometry, anatomy-relative fit contracts, pose/morphology sweeps, quantitative failure reports, debug overlays, and golden policy.
- [`docs/PROMPT25D_DECISION_RECORD.md`](docs/PROMPT25D_DECISION_RECORD.md) for validator hardening, production root-cause corrections, before/after metrics, golden evidence, and the no-test-gaming audit.
- [`docs/PROMPT26_DECISION_RECORD.md`](docs/PROMPT26_DECISION_RECORD.md) for environment composition, collision-derived edges, art provenance, and evidence staging.
- [`docs/PROMPT27_DECISION_RECORD.md`](docs/PROMPT27_DECISION_RECORD.md) for production composition, interaction presentation, side projection, property ownership, and bounds.
- [`docs/OUTFIT_REFERENCE_INVENTORY.md`](docs/OUTFIT_REFERENCE_INVENTORY.md) for the required reference-cluster inventory and project-local IDs.
- [`docs/ANIMATION.md`](docs/ANIMATION.md) for clip, key, event, playback, blending, fallback, authored-timeline, and animation-demo contracts.
- [`docs/PHYSICS.md`](docs/PHYSICS.md) for the 240 Hz clock, controller configuration, collision, jump, landing, and allocation contracts.
- [`docs/SECONDARY_MOTION.md`](docs/SECONDARY_MOTION.md) for procedural walk, landing, spring, composition, reset, and evidence contracts.
- [`docs/MULTI_CHARACTER.md`](docs/MULTI_CHARACTER.md) for entity IDs, instance ownership, facing reflection, global ordering, overrides, and two-character evidence.
- [`docs/INTERACTIONS.md`](docs/INTERACTIONS.md) for paired definitions, eligibility, shared timing, event authority, locks, overrides, cancellation, and handshake evidence.
- [`docs/IK.md`](docs/IK.md) for analytical geometry, reachability, arm binding, pose-pipeline order, shared-target ownership, weighting, and quantitative evidence.
- [`docs/FOOT_PLANTING.md`](docs/FOOT_PLANTING.md) for ground-query inclusion rules, anatomical leg bindings, fixed-tick plant/release semantics, visual-only ownership, and quantitative slip/contact evidence.
- [`docs/DIAGNOSTICS.md`](docs/DIAGNOSTICS.md) for the integrated fixed-tick order, bounded observer model, debug-command capacity, reset policy, invariance, and resource accounting.
- [`docs/CONTROLS.md`](docs/CONTROLS.md) for keyboard/gamepad controls, pending-edge semantics, pause, and deterministic scripted input.
