# Current State

Current F4 acceptance basis: the Final F4 Independent Production Architecture
Acceptance Audit inspected clean, synchronized `master` at
`48a7c677d781543e479b178c6e7b10b139eeb26e`. It found no CRITICAL or MAJOR
blocker, verified every original F4A CRITICAL/MAJOR finding as resolved, and
passed every required final validation gate. The owner accepts the audit and
F4 — Production Architecture Hardening is accepted.

The production-system inventory below distinguishes current engine authority
from protected historical visual lineage. Historical names identify accepted
provenance only and do not define current production architecture.

## Foundation and current architecture track

| Milestone | Current status |
|---|---|
| F1 | **ACCEPTED** |
| F2A | **ACCEPTED** |
| F2B | **ACCEPTED** |
| F2C | **ACCEPTED**, including the authority-encapsulation amendment at `685383a9012f10769c89b363d2eeff820410e0ae` |
| F3 | **ACCEPTED** after independent follow-up and owner review |
| F4A | **OWNER-APPROVED** whole-repository production-architecture audit |
| F4B1 | **OWNER-APPROVED** |
| F4B2 | **OWNER-APPROVED** |
| F4C1 | **OWNER-APPROVED** |
| F4C2 | **OWNER-APPROVED** |
| F4C3 | **OWNER-APPROVED** |
| F4C4 | **OWNER-APPROVED** |
| F4C5 | **OWNER-APPROVED** |
| F4D | **OWNER-APPROVED** |
| F4E | **OWNER-APPROVED** |
| F4 — Production Architecture Hardening | **ACCEPTED** |

Current architecture foundation: **F4 — Production Architecture Hardening,
ACCEPTED**.

Post-F4 feature development is unblocked at the architecture gate. No
downstream track begins through this administrative record; each requires a
dedicated implementation request and must respect the dependency gates below.

F4B1 removed only the F4A-OD-014 low-risk hygiene set and established the
[repository retention policy](REPOSITORY_RETENTION.md). F4B2 retired ten
historical runnable scenario shells after permanent regression coverage was
mapped, retained one candidate because production extraction is required in
F4C, and retained two candidates for active coverage/debugging value. The
[F4B2 implementation record](../implementation/f4b2_superseded_demo_retirement.md)
remains the milestone-time implementation history; the owner now approves it.
F4C1 moves reusable humanoid, equipment, attachment-mesh, art-asset, and
foundation-world definitions out of demo ownership. Nine source edges that
borrowed production authority from a demo were removed. Three deliberate
cross-demo scenario-composition edges and sixteen application/report routing
edges remain explicitly classified. See the
[F4C1 implementation record](../implementation/f4c1_production_definition_extraction.md).
F4C2 moves reusable SDL3/D3D12 device, resource, upload, queue execution, and
generic readback ownership into `src/graphics/sdl_gpu_renderer.zig`. The
surviving executable is composed by `src/app/demo_application.zig`; copied
readback data crosses `frame_capture.CapturedFrame` into the evidence writer.
The renderer remains independent of application and evidence ownership. See
the [F4C2 implementation record](../implementation/f4c2_renderer_application_evidence_boundaries.md).
F4C3 keeps `CharacterInstance` as a coordinator while placing all semantic
mutable state behind private inline storage and command/read surfaces. The
interaction manager now similarly owns private slots, lifecycle, IDs and
metrics, with transactional participant rollback and test-only white-box
routing. See the
[F4C3 implementation record](../implementation/f4c3_character_interaction_authority.md).
F4C4 makes F `EntityId`/`EntityHandle` and RuntimeScene authoritative for the
two characters in the representative `integrated` route through one bounded,
private adapter. F enabled/lifecycle gates simulation, interaction and render
submission; generic transforms synchronize at frame/batch publication
boundaries; F snapshots expose generic identity, transform and enabled state.
Legacy character IDs remain runtime-only specialized lookup/order keys.
Platform input now exposes only physical state, application/demo actions live
in `src/app/demo_actions.zig`, and physics owns `CharacterIntent`. See the
[F4C4 implementation record](../implementation/f4c4_scene_core_adoption_and_input_boundaries.md).
F4C5 separates explicit production-module, fast-engine-test, content-test,
evidence/report, and aggregate-gate build ownership. Routine `check` now owns
current architecture/hygiene, documentation, application compilation, and the
fast engine contract. Full deterministic CPU integration, current content
qualification, GPU smoke, manual visual review, and historical reproduction
are explicit separate gates. See the
[F4C5 implementation record](../implementation/f4c5_build_test_policy_modularization.md).
F4D proves a second application can create and observe a generic F entity,
derive production render data, execute the real SDL3/D3D12/DXIL renderer,
inspect generic readback, and shut down with balanced resources without
importing `DemoApplication`, `GpuDemo`, scenario modules, or evidence
orchestration. Independent CPU tests also cover F-to-character binding and
production interaction lifecycle. See the
[F4D implementation record](../implementation/f4d_independent_engine_composition.md).
F4E canonicalizes active atlas and executable names, removes the obsolete
`GpuDemo` alias, routes physical GPU smoke directly through `engine_smoke`,
retires the redundant `art_assets` scenario while preserving its integration
fixture, establishes active/history asset manifests, and moves prompt-era
records under the explicitly non-normative `docs/history` boundary. See the
[F4E implementation record](../implementation/f4e_repository_canonicalization.md).

The accepted F4 dependency direction, ownership boundaries, runtime authority,
independent-client proof, and modular validation architecture now govern
post-F4 work. See the
[owner-approved F4A record](../implementation/f4a_production_architecture_audit.md)
and the milestone-time F4 implementation records for provenance.

## Final F4 acceptance

The owner-approved final independent audit established:

- audited commit: `48a7c677d781543e479b178c6e7b10b139eeb26e`;
- CRITICAL findings: **0**;
- MAJOR findings: **0**;
- original F4A CRITICAL/MAJOR findings: **all RESOLVED**;
- required final validation gates: **all PASS**;
- final disposition: **F4 ACCEPTED**;
- post-F4 feature fan-out: **unblocked after owner acceptance**, subject to the
  dedicated-request and dependency rules below.

Historical implementation and audit records retain their original
milestone-time candidate wording. They do not override this current normative
status.

## Post-F4 architecture debt

### POST-F4-DEBT-001 — Renderer diagnostics compile coupling

**MODERATE, nonblocking.** Renderer resource reporting imports a diagnostics
module whose dependency graph also reaches character and interaction types.
This is compile-graph coupling, not a runtime-authority violation. Narrow it
only when renderer/diagnostics work naturally provides the appropriate scope.

### POST-F4-DEBT-002 — Explicit module catalog growth

**MINOR, monitor.** `build/modules.zig` remains a large explicit module
catalog. Its visible ownership is preferable to hidden directory discovery.
Revisit it only if future parallel-domain additions make it a meaningful
change magnet.

## Accepted post-F4 foundations on master (2026-09-06)

Master at `d71c4ae439d0b04019734cd3f45b7a6366a6a00f` contains all five accepted
parallel foundations. Effects/Projectiles merge
`493549cfc31b3d768b680f7284b6bd7fae517c7a` and its acceptance-document commit
`d71c4ae439d0b04019734cd3f45b7a6366a6a00f` are on master after the completed
fast-forward and push. The unnumbered
[checkout reproducibility correction](../implementation/reproducible_windows_checkouts.md)
is owner-accepted and present on master at
`dca3b331a86abee43a271cc00292021334ab8612`. Master was fast-forwarded to that
commit, which includes mechanics commit
`cf094b617ae52be1031d8dde1fda310651c1d84e`; no separate merge commit exists.
This unnumbered repository-integrity acceptance does not advance or renumber
M03, M04, any product phase or editor milestone, or authorize EL2, PSM02 or
cross-system integration.

| Accepted lane | Implementation on master | Bounded ownership |
| --- | --- | --- |
| [PSM01 Secondary Motion](../implementation/psm01_secondary_motion.md) | `43ae062867d8bda79b1ba364ad6e934c0beee8c7` | Generic scalar solver and authored rate resolution; anatomical tuning, production bindings, PSM02 and baking remain outside acceptance |
| [World Time Foundation](../implementation/world_time_foundation.md) | `89faed3b416e8d9aa4665e39ff72f5cb7ee93bb9` | Caller-owned deterministic logical time and snapshots; no climate, weather, environment or application integration |
| [Engine Lab EL1](../implementation/engine_lab_el1.md) | `7b3eb3a4b90093656167dc65082b62fa6378c963` | Independent persistent hub, provisional actor and existing engine clients; EL1 is accepted, canonical-generated characters and later EL2 work are separate |
| [RR1 Record/Replay](../implementation/rr1_record_replay.md) | `fb0526ddbd268be0befef9694b1b1dc03ad7fb68` | Bounded deterministic V1 protocol and headless production-controller proof; arbitrary scenes, dynamic publication and whole-engine replay remain deferred |
| [Effects and Projectiles Foundation](../implementation/effects_projectiles_foundation.md) | `c0421e5182b9adb5fece7fb38520c9181bf8b038` | Independent 2D cores, optional event composition and standalone GPU proof; other subsystem adoption remains deferred |

Sharing master records accepted repository integration; it does not make these
five lanes consume one another. Their existing engine dependencies and authority
boundaries remain intact. No EL2, PSM02, gameplay integration, new representation
binding or other implementation is authorized here. Historical feature-time
candidate/review wording retains its original meaning and does not supersede
this current acceptance record. M03, M04, phases and editor milestones retain
their existing numbering and gates.

## Accepted post-F4 secondary-motion foundation

**PSM01 is ACCEPTED by the owner at
43ae062867d8bda79b1ba364ad6e934c0beee8c7.** Acceptance covers the generic
scalar solver, authored rate-response resolver, fixed-step and determinism
contracts, synthetic calibration, and offline/runtime proof. See the
[PSM01 contract and evidence](../implementation/psm01_secondary_motion.md).

This is acceptance of the bounded PSM01 milestone within PHY, not acceptance
of the whole PHY track. Final anatomical tuning and production bindings are
outside acceptance. Existing 2D consumers remain current. No PSM02, binding
migration, baking work or change to M03/M04 status follows from acceptance.

## Accepted parallel Effects and Projectiles Foundation

The owner accepted feature commit `c0421e5182b9adb5fece7fb38520c9181bf8b038`.
It is integrated through merge `493549cfc31b3d768b680f7284b6bd7fae517c7a`
and acceptance-document commit `d71c4ae439d0b04019734cd3f45b7a6366a6a00f`
on master. The integration branch remains retained.
The [implementation record](../implementation/effects_projectiles_foundation.md)
contains measured integration gates and preserved feature-time evidence.

This owner-authorized parallel foundation was pulled forward from later roadmap
work. It neither renumbers nor completes M03, M04, Phase D, Phase L or any
editor milestone. Both cores are currently 2D, and the visual proof is standalone.
PHY, Engine Lab, RR1, world/environment, 3D presentation and gameplay-specific
integration remain deferred. PSM01, World Time, Engine Lab and RR1 retain their
existing registrations and authority boundaries.

## Post-F4 track readiness

The separately approved [Engine Lab projectile-impact integration](../implementation/engine_lab_projectile_impact.md)
is implemented on its dedicated integration branch and awaits owner acceptance.
It composes one static-wall installation through a generic physics sweep,
the accepted projectile/effects cores and bridge, and production presentation.
This bounded candidate supersedes the general Engine Lab-adoption deferral
only for that slice. Closed EL1 acceptance and all other deferred tracks remain
unchanged; no new milestone number is assigned.

Immediately architecture-ready for dedicated implementation requests:

```text
SEM  SAF  MAT  CHR  CL  OBJ  LVL  AN  INT  PHY  WRD  ENV  IMG
```

Dependency-gated:

- **PFB** — after the OBJ authored-object contract;
- **SCN** — after the intended LVL/PFB composition contract;
- **PG** — after the LVL loading/origin/streaming boundary;
- **AI** — after SEM, OBJ, and the required PHY query contracts;
- **GAME** — after the selected LVL/SCN/OBJ gameplay dependencies;
- **ED** — after the first authored schemas it is intended to edit are
  accepted.

The PSM01 acceptance above records separately authorized work. This status record authorizes no additional downstream work.

Status vocabulary:

- **complete** — implemented and protected by appropriate tests/evidence;
- **complete but visually provisional** — functional, but art or presentation
  has not received final visual acceptance;
- **partially implemented** — useful production behavior exists, but the
  stated concept is incomplete;
- **documented only** — contract exists in documentation, not in the runtime
  schema;
- **deferred** — intentionally postponed;
- **not started** — no implementation should be inferred.

## Production systems

| System | Status | Current evidence and boundary |
|---|---|---|
| SDL3 GPU renderer and D3D12/DXIL route | complete | Atlas-backed sprites and deformable meshes use the global unified queue; Prompt 25D goldens and Prompt 26/27 captures were produced through the real production route. |
| Height-relative production camera | automated complete, owner resize review pending | The 640×480 composition remains 82 px/m and fixes the vertical world span at 480/82 m. Positive drawable heights derive scale as 82×height/480 from actual SDL drawable/swapchain pixels; width changes horizontal visibility only. Zero drawables preserve the last valid camera. |
| Fixed-step simulation, animation, physics, and controller | complete | One authoritative 240 Hz deterministic simulation; renderer interpolation does not own simulation. |
| F-backed representative scene route | complete | `integrated` owns two persistent RuntimeScene entities through a bounded character adapter; F lifecycle/enabled/transform and snapshot semantics are live in production composition. Other routes remain explicitly transitional or specialized. |
| Independent engine client | complete | `engine_smoke` owns one generic RuntimeScene entity, consumes the supported renderer/queue/capture surfaces directly, and has no demo or evidence dependency. |
| Input and character intent | complete | SDL/platform owns physical keys, buttons, axes, focus and window close only; application mapping owns semantic actions and pending edges; physics owns `CharacterIntent`. |
| Interactions, handshake, and IK | complete | Interaction coordination owns fixed-root handshakes; visual IK does not replace root physics. Prompt 27 makes view and occlusion policy definition data. |
| Semantic anatomy and morphology | complete | One authoritative skeleton, typed anatomy instances, body presets, and bounded morphology channels. |
| Equipment and loadouts | complete | Typed slots, topology-aware bindings, bounded recipe expansion, transactional equip/unequip, and cosmetic/gameplay separation. |
| Deformation, mesh visuals, and secondary motion | complete | Shared deformation and fixed-capacity visual state; no per-character renderer. |
| Character properties/capabilities | complete | Generic resolved attributes and counted capability sources. Prompt 27 production characters receive movement/jump/double-jump/dash from base properties while wardrobe items remain cosmetic. |
| Art-pack and atlas pipeline | complete | Typed pages, regions, semantic view bindings, alpha-visible metadata, and explicit resource ownership. |
| Front/side character presentation | complete | Front plus canonical side presentation, deterministic gameplay-facing projection, male/female production art, and interaction-owned role views. |
| Base anatomy/clothing separation | complete | Base anatomy resolves without an equipped garment; removable equipment never owns or replaces anatomy identity. |
| Wardrobe catalog and presets | complete | 30 logical items, 36 visual components, 15 presets, and a custom recombined outfit. |
| Semantic visual-geometry validator | complete | Production transforms, semantic landmarks, fit/coverage, proportions, pose/morphology sweeps, structured reports, D3D12 debug overlays, and golden support. |
| Current production character visuals | not owner-approved | Historical Prompt 25D evidence remains preserved, but current production art must not inherit visual approval from filenames, stored goldens, reports, or automated tests. |
| Environment themes | complete | Prompt 26 supplies violet-crystal and neutral-diagnostic themes, collision-derived white standable tops, bounded hot swapping, and seven D3D12 captures over the unchanged world. |
| Integrated Prompt 27 presentation | complete | The visible `foundation` route composes the two production characters, all current wardrobe, both themes, movement, jumping, three measured fixed-root handshakes, view/ordering cleanup, debug, reset, and real D3D12 rendering. |
| Prompt 27A evidence integrity | complete, owner review pending | Sixteen captures are selected by authoritative/presentation/interaction predicates, bound to validated semantic metadata and independent D3D12 pixel hashes, packaged into contact sheets, and repeated byte-exactly. Aesthetic acceptance is `[PENDING OWNER REVIEW]`. |
| Prompt 27B contact/framing/parallax/presence | complete, owner review pending | One fail-closed chain measures support, post-IK sole, alpha-derived submitted visual sole, camera projection, render ordering, and real D3D12 pixels. Existing-camera safe framing, actual-factor parallax, and non-teleport scripted presence pass semantic and readback metrics. |
| Prompt 27C production anatomy | superseded torso result | The anatomy ruler, limb/joint/foot corrections, 102-case matrix, and evidence route remain protected; the original torso pixels were owner-rejected and are preserved only as negative evidence. |
| Prompt 27C-R1 torso/presence corrective pass | complete, owner review pending | Restores the pre-27C chest identity with 2,743 bounded shoulder pixels and zero outside-page changes; preserves the component page; classifies every review visual; and separates interactive presence measurement from fail-closed scripted acceptance without changing thresholds. |
| VF-01 visual truth debugger | automated complete, owner review pending | F1 exposes canonical/projected rig and final atlas-registration truth through one production snapshot; F4 atomically writes same-state D3D12 clean/debug bundles with JSON, summary, manifest, and source hashes. |
| VF-02 authoritative rig-to-art registration | automated complete, owner review pending | One fail-closed point/point-axis/segment/frame solver owns final placement for both arms, forearms, thighs, shins, feet, shoes, torso, pelvis, and nose across both styles and front/side-left/side-right. The fresh fail-closed Prompt 27B ruler passes 9,752 metrics with zero failures. |
| VF-03 typed modular component graph | automated complete after R1, owner review pending | One immutable compiled graph facade exposes typed component parents/sockets, connection modes, selected visuals, and explicit optional rig modules. R1 requires each active optional arm's three declared visuals to become exactly three graph-linked production submissions and supplies visibly distinct continuous/intentional-gap front and side D3D12/DXIL proof. |
| Semantic body-relative garment depth schema | documented only | Current content resolves numeric visual layers. Required reusable depth relations are defined in [AUTHORING_CONTRACTS.md](AUTHORING_CONTRACTS.md), but no current accepted item requires a runtime extension. |
| Authored side-left/side-right garment variants | documented only | Current production side art is mirror-safe. Directional and mixed-fragment policies are defined for future content. |
| First-class collar coverage and shoulder-slope contour | documented only | Current validator has point/span fit and per-item coverage zones, but not the richer semantic contour contract required by a future editor. |
| Narrow gameplay vertical slice | not started | No beginning/objective/completion/replay loop exists beyond the systems-oriented foundation route. |
| Character, wardrobe, level, and mission editors | not started | No GUI or second authoring model exists. |

## Current integrated acceptance

The focused `test-visual-foundation` gate now passes 50/50 tests, including
the VF-02 production-registration and VF-03 component-topology assertions. The
2,400-frame production route uses:

- two production characters;
- 30 wardrobe items and 15 outfit presets;
- two environment themes;
- eight decoded image-backed atlas pages and one procedural renderer page;
- two persistent garment mesh definitions;
- eight static colliders and six collision-derived white standable segments;
- one `UnifiedRenderQueue` and the existing SDL3 GPU renderer.

It completes three data-declared side-view handshakes in
`wide_brim_crimson`, `garnet_formal`, and `ivory_blouse_red_shorts`, records
pre/post-IK and projected contact separation, and verifies completion cleanup
back to ordinary front presentation. Peak clean production work is 139
sprites and one mesh. The same-queue HUD raises bounded window submission
without adding a renderer or resource path. The route reports zero
post-stabilization update, submission, queue, or GPU-resource growth and
writes the preserved 16 Prompt 27A D3D12 captures plus four Prompt 27B
supplemental captures and semantic metadata.

The preserved final Prompt 27B semantic report contains 9,714 metrics and zero
failures at its historical art hashes. A fresh-current-art VF-01 baseline
contains 9,714 metrics and 24 failures: front-foot heel/toe endpoint-height
errors are `-13.645128 px` and `+13.645128 px`. The historical zero-failure
report is not cited as current-art proof. Historical isolated D3D12 runs and
their review packages remain byte-identical; each historical review contains
55 independent pixel metrics and zero failures. The direct
960×540-to-640×480 first-post frame retains 37.50 px headroom and 36.77 px
footroom; subsequent camera movement peaks at 15.566496 px under the unchanged
16 px bound. All 314 inventoried
historical Prompt 27/27A evidence files remain present and hash-identical.
The inherited Prompt 27B Debug aggregate and `check` gates passed 381/381
tests; ReleaseSafe, ReleaseFast, and D3D12/DXIL GPU smoke passed. See
[../TESTING.md](../TESTING.md) for exact commands and evidence boundaries.

VF-02 adds a focused registration gate and extends the VF-01 production gate
to front, side-right, and side-left authoritative-placement proof. Body-only
production frames contain 26 migrated registered submissions; equipped frames
contain 30 because all four shoes now use authoritative point registration.
The final D3D12 set `_0068` / `_0069` / `_0070` and `_0071` / `_0072` /
`_0073` covers male and female front / side-left / side-right body-only and
equipped presentation. Every schema-3 manifest and clean/debug state identity
validates. Equipped frames export four authoritative rendered shoes and four
explicitly suppressed registered base-foot evidence records. The initial
independent current-pixel
ruler result is not overwritten: it passed 13/15 tests while reporting eight
current baseline failure categories and 116
pose/morphology/legacy-wardrobe findings. The owner-review correction also
preserves the earlier fresh Prompt 27B 24-failure report. A new
fresh-current-art Prompt 27B run now emits 9,752 metrics with zero failures:
the former endpoint failures were registration-policy defects from the
surviving wardrobe shoe `+/-78` degree branch. They are not reclassified as
source-art defects or owner approval. Front base feet use a `point_axis`
contract with one positional ankle target and one authored sole-axis
orientation constraint. The 16-degree male / 13-degree female toe-out remains
physical ground-plane policy, while front projection maps its signed lateral
component to a horizontal support tangent. Heel/toe/sole landmarks remain
transformed, non-target evidence.

VF-03 compiles the established appearance/anatomy definitions into one
immutable component inspection authority. Typed socket roles/tags/capacities
and explicit connection modes fail closed at initialization. The conventional
and angular faces expose head → eye → eyebrow chains with one bound visual per
eyebrow child; hair follows the typed scalp relationship. The nonstandard
technical preset exports explicit shoulder/elbow/wrist/hand-tip arm modules,
including one continuous and one declared `0.08 m` intentional-gap
connection. Standard two-arm characters remain unchanged.

The original automated VF-03 proof passed because it validated declared
optional-arm `bound_visuals` without requiring the production slot resolver
to submit them. Clean captures showed only the standard arms, side proof
modules were inactive, and the continuous/gap pixels were indistinguishable.
R1 closes that gap: active optional modules now submit upper arm, forearm, and
hand through `character_art` using the projected shoulder/elbow/wrist/hand-tip
chain. The invariant is declared = resolved = expected = actual, with exactly
three submissions per active module. Inactive modules explicitly have no
final indices and are not classified missing.

Corrective D3D12/DXIL bundles `_0083`, `_0091–_0097` cover disabled,
continuous/intentional-gap front, both active side directions, reflection,
and two modules. Singles contain exactly three submissions; `_0097` contains
six. The `0.08 m` gap remains within `0.07–0.09 m` and derives approximately
`6.56 px` from the captured `82 px/m` camera. Every accepted schema-4
manifest, file hash/size, and clean/debug state identity validates.
Historical `_0074–_0082` are unchanged. Invalid-JSON `_0084–_0090` attempts
are preserved but are not completion evidence. A fresh current-art Prompt
27B report remains fail-closed and passes 9,752 metrics with zero failures.
The current aggregate is `428/428`.

Prompt 27C extends the focused visual-geometry gate to 158/158 checks and the
Debug aggregate to 386/386 tests. Its final semantic report contains 102
cases, 2,450 production trace records, 3,788 metrics, and zero failures; the
frozen pre-correction baseline retains 817 failures. Two isolated eight-frame
D3D12/DXIL anatomy runs and their 18-file review packages are byte-identical.
The route reports zero post-initialization update, submission, queue, and GPU
resource growth. All 314 frozen Prompt 27/27A artifacts remain present and
hash-identical. Prompt 27B's incremental/direct resize fixtures and unchanged
16 px world-camera bound pass inside the retained 28/28 foundation gate.

Prompt 27C-R1 supersedes only the rejected torso output. Its page audit records
1,509 male and 1,234 female changed pixels inside four explicit shoulder
rectangles and zero changes outside them. The component page remains
byte-identical. The foundation route exposes one presence measurement under
an explicit policy: unrestricted interactive movement is measure-only, while
scripted evidence remains fail-closed. The `0.02` ordinary, `0.15`
active-interaction, and 16 px camera bounds are unchanged.
The current aggregate passes 389/389 Debug tests, including 31/31 focused
foundation tests.

VF-01 adds the production truth snapshot, four-mode F1 cycle, and atomic F4
bundle path without changing controller, collision, pose, interaction,
camera, allocation, or renderer authority. Its focused gate passes 40/40. Ten
final D3D12/DXIL bundles ending `_0020` through `_0029` cover front idle,
side idle/walk, airborne, landing/grounded, face/shoulder/leg disagreements,
and All Diagnostics. All manifest hashes and same-state identities validate.
These are diagnostic candidates, not approved goldens.

## Focused demonstrations

- `--demo controller`, `--demo handshake-ik`, `--demo integrated`, and the
  focused character/physics/interaction diagnostic routes.
- Anatomy, equipment, mesh-attachment, wardrobe, environment, and the retained
  Prompt 22 `foundation_playground.Scene` regression.
- Prompt 23 art-pack acceptance.
- Prompt 24 front/side character presentation through permanent tests and the
  retained production foundation/anatomy routes.
- Prompt 25 wardrobe presets and custom outfit.
- Prompt 25C/25D visual-geometry reports, debug overlays, and approved goldens.
- Prompt 26 `environment` theme/collision-readability route.
- Prompt 27 production `foundation` integration route.
- Prompt 27A state-conditioned capture and owner-review package.
- Prompt 27B semantic coherence report and D3D12 contact/framing/parallax
  review package.
- Prompt 27C semantic anatomy report, body-only D3D12 route, before/after
  comparison, and anatomical close-up review sheets.
- Prompt 27C-R1 classified provenance, changed-pixel torso audit,
  native/enlarged/directional/composite/diff review, and explicit
  measure-only interactive presence route.
- VF-03 compiled component graph, typed-socket and connection fixtures,
  child-follow proof, explicit optional arm modules, and schema-4 D3D12
  capture route.

Prompt 27 changed the visible `--demo foundation` CLI owner to
`visual_foundation.Scene`. The older procedural Prompt 22 scene remains a
focused headless regression and collider-data authority; it is not the
current rendered application.

## Provisional or incomplete areas

- Prompt 27A aesthetic/manual acceptance is `[PENDING OWNER REVIEW]`; no new
  capture has been promoted to a golden.
- Prompt 27B clean/debug candidates also await owner/manual review and are not
  approved goldens.
- The original Prompt 27C torso candidate is owner-rejected. Prompt 27C-R1
  corrective candidates await owner/manual review and are not approved
  goldens.
- VF-01 truth bundles await owner/manual review and are not approved goldens.
- VF-02 registration bundles await owner/manual review and are not approved
  goldens.
- VF-03-R1 rendered optional-arm bundles await owner/manual review and are not
  approved goldens. Historical `_0074–_0082` and invalid corrective attempts
  `_0084–_0090` remain preserved diagnostic candidates.
- The preserved pre-correction fresh-current-art Prompt 27B report has 24
  front-foot endpoint-height failures. The owner-review correction resolves
  that policy defect in a new 9,752-metric zero-failure run; neither report is
  overwritten or rebaselined.
- General interactive character-character collision is not implemented. The
  deterministic Prompt 27B route uses ordinary controller input to walk the
  partner clear/return plus an overlap detector; this is not a general
  collision response.

- Current garment fragments are recipes, but they expose no authored stable
  fragment name independent of the recipe ID.
- Current production uses numeric visual layers; semantic body-relative depth
  relations remain a documented authoring requirement.
- Current side art is canonical and reflected with the character. No
  production garment exercises authored directional variants.
- Collar intent is represented indirectly by garment-specific fit
  landmarks/coverage zones rather than a first-class neck/collar declaration.
- Shoulder fit uses semantic points and spans, not a slope-aware contour from
  neck base through shoulder root and armhole.
- The split skirt is one deformable mesh, not a reusable
  rear/central/front-fragment composition.
- Hair is independently addressable but currently one presentation visual;
  headwear is a higher numeric layer rather than a reusable
  back-hair/headwear/front-hair recipe.
- Only two environment themes and front/canonical-side character views are
  authored.
- The current paired interaction has one contact and fixed roots. It does not
  implement multi-contact carrying, world-anchor interactions, full-body
  paired solving, or cinematic view assets.

The impact and intended future milestones are in
[KNOWN_GAPS.md](KNOWN_GAPS.md).

## Next authorized milestone

F4 is accepted. The architecture-ready post-F4 tracks listed above may begin
only through dedicated implementation requests; dependency-gated tracks must
first satisfy their recorded prerequisites. Prompt 27A, Prompt 27B, Prompt
27C-R1, VF-01, VF-02, and VF-03 owner/manual visual acceptance remains
`[PENDING OWNER REVIEW]` as a separate presentation matter. PSM01 is accepted
within the bounded generic scope recorded above; no further milestone or
production binding is authorized by this acceptance bookkeeping.

## RR1 deterministic record/replay foundation

RR1 uses the corrected V1 from fb0526ddbd268be0befef9694b1b1dc03ad7fb68;
the original candidate and corrective pass remain separate commits in history.
Container, protocol, derivation framing, initial schema and named encoding
are version 1 at exactly 240 Hz. Command, causal and observed channel
identities are 1/1.
CharacterIntent is the dense per-tick command; SetMaximumRunSpeed is causal
type 1/1. Observed types 1/1, 2/1, 3/1 are JumpAccepted, DashStarted and Landed
from the real production StepResult, never reinjected.

The half-open interval contains one command and one post-tick fingerprint
per tick, ordered same-tick events and bounded globally unique named markers.
The proof marks jump_accepted, speed_changed and final_state. Playback compares
observations, fingerprints and names before permitting another tick.
Tick-batch grouping independence assumes identical semantic streams, not
arbitrary frame schedules or raw input sampling.

State coverage retains all 20 controller State fields, four gameplay
properties, configuration/spawn/reset data, seed/derived key, collision world,
and immutable scene-anchor semantics. No per-tick snapshot publication is used.
The [contract](../architecture/deterministic_record_replay_v1.md) and
[implementation record](../implementation/rr1_record_replay.md) define exact
compatibility, evidence and remaining limits. This is a supported headless
proof; other engine systems and screenshot/JSON sidecars remain unintegrated.
Earlier F4 administrative and visual records retain their historical meaning.
