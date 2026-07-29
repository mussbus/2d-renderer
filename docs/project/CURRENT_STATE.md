# Current State

Snapshot basis: Prompt 27C worktree based on HEAD
`3259f79db18659746ca97bde96456da086a40126`, inspected on 2026-07-29.

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
| Fixed-step simulation, animation, physics, and controller | complete | One authoritative 240 Hz deterministic simulation; renderer interpolation does not own simulation. |
| Input and character intent | complete | Keyboard/gamepad state becomes a bounded intent structure; pending edges survive zero-substep frames. |
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
| Current production character visuals | complete | Prompt 25D production report has zero failures; 12 approved D3D12/DXIL goldens are stored. |
| Environment themes | complete | Prompt 26 supplies violet-crystal and neutral-diagnostic themes, collision-derived white standable tops, bounded hot swapping, and seven D3D12 captures over the unchanged world. |
| Integrated Prompt 27 presentation | complete | The visible `foundation` route composes the two production characters, all current wardrobe, both themes, movement, jumping, three measured fixed-root handshakes, view/ordering cleanup, debug, reset, and real D3D12 rendering. |
| Prompt 27A evidence integrity | complete, owner review pending | Sixteen captures are selected by authoritative/presentation/interaction predicates, bound to validated semantic metadata and independent D3D12 pixel hashes, packaged into contact sheets, and repeated byte-exactly. Aesthetic acceptance is `[PENDING OWNER REVIEW]`. |
| Prompt 27B contact/framing/parallax/presence | complete, owner review pending | One fail-closed chain measures support, post-IK sole, alpha-derived submitted visual sole, camera projection, render ordering, and real D3D12 pixels. Existing-camera safe framing, actual-factor parallax, and non-teleport scripted presence pass semantic and readback metrics. |
| Prompt 27C production anatomy | superseded torso result | The anatomy ruler, limb/joint/foot corrections, 102-case matrix, and evidence route remain protected; the original torso pixels were owner-rejected and are preserved only as negative evidence. |
| Prompt 27C-R1 torso/presence corrective pass | complete, owner review pending | Restores the pre-27C chest identity with 2,743 bounded shoulder pixels and zero outside-page changes; preserves the component page; classifies every review visual; and separates interactive presence measurement from fail-closed scripted acceptance without changing thresholds. |
| Semantic body-relative garment depth schema | documented only | Current content resolves numeric visual layers. Required reusable depth relations are defined in [AUTHORING_CONTRACTS.md](AUTHORING_CONTRACTS.md), but no current accepted item requires a runtime extension. |
| Authored side-left/side-right garment variants | documented only | Current production side art is mirror-safe. Directional and mixed-fragment policies are defined for future content. |
| First-class collar coverage and shoulder-slope contour | documented only | Current validator has point/span fit and per-item coverage zones, but not the richer semantic contour contract required by a future editor. |
| Narrow gameplay vertical slice | not started | No beginning/objective/completion/replay loop exists beyond the systems-oriented foundation route. |
| Character, wardrobe, level, and mission editors | not started | No GUI or second authoring model exists. |

## Current integrated acceptance

Prompt 27B's focused `test-visual-foundation` gate passes 28/28 tests. The
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

The Prompt 27B semantic report contains 9,714 metrics and zero failures. Two
isolated D3D12 runs and their review packages are byte-identical; each review
contains 55 independent pixel metrics and zero failures. The direct
960×540-to-640×480 first-post frame retains 37.50 px headroom and 36.77 px
footroom; subsequent camera movement peaks at 15.566496 px under the unchanged
16 px bound. All 314 inventoried
historical Prompt 27/27A evidence files remain present and hash-identical.
The inherited Prompt 27B Debug aggregate and `check` gates passed 381/381
tests; ReleaseSafe, ReleaseFast, and D3D12/DXIL GPU smoke passed. See
[../TESTING.md](../TESTING.md) for exact commands and evidence boundaries.

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

## Focused demonstrations

- `--demo animation`, `--demo controller`, and the focused
  character/physics/interaction diagnostic routes.
- Anatomy, equipment, deformation, secondary-motion, properties, and the
  retained Prompt 22 `foundation_playground.Scene` regression.
- Prompt 23 art-pack acceptance.
- Prompt 24 front/side character presentation.
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

Prompt 27C-R1 is the current bounded corrective authority. Prompt 27A,
Prompt 27B, and Prompt 27C-R1 owner/manual visual acceptance remains
`[PENDING OWNER REVIEW]`. Prompt 27D, Prompt 28, gameplay vertical slice,
editor, combat, mission, or other expansion has not started. Future work
requires an explicit user request and must preserve the existing authority
boundaries.
