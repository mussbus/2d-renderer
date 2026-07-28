# Current State

Snapshot basis: Prompt 27 HEAD
`1de0d1d6fe1b4a953e1bbba47e1216fd56a724eb`, inspected on 2026-07-28.

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
| Semantic body-relative garment depth schema | documented only | Current content resolves numeric visual layers. Required reusable depth relations are defined in [AUTHORING_CONTRACTS.md](AUTHORING_CONTRACTS.md), but no current accepted item requires a runtime extension. |
| Authored side-left/side-right garment variants | documented only | Current production side art is mirror-safe. Directional and mixed-fragment policies are defined for future content. |
| First-class collar coverage and shoulder-slope contour | documented only | Current validator has point/span fit and per-item coverage zones, but not the richer semantic contour contract required by a future editor. |
| Narrow gameplay vertical slice | not started | No beginning/objective/completion/replay loop exists beyond the systems-oriented foundation route. |
| Character, wardrobe, level, and mission editors | not started | No GUI or second authoring model exists. |

## Current integrated acceptance

Prompt 27's focused `test-visual-foundation` gate passes 3/3 tests. The
2,100-frame production route uses:

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
back to ordinary front presentation. Peak work was 125 sprites, one mesh, 16
sprite ranges/draws, one mesh range/draw, 8,000 sprite upload bytes, and 64
mesh upload bytes. The route reports zero post-stabilization update,
submission, queue, or GPU-resource growth and writes nine D3D12 captures to
`zig-out/p27_visual_foundation`.

The aggregate Prompt 0–27 gate passes 356/356 tests in Debug and ReleaseFast.
See [../TESTING.md](../TESTING.md) for exact commands and evidence boundaries.

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

Prompt 27 changed the visible `--demo foundation` CLI owner to
`visual_foundation.Scene`. The older procedural Prompt 22 scene remains a
focused headless regression and collider-data authority; it is not the
current rendered application.

## Provisional or incomplete areas

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

Prompt 27 is complete. No Prompt 28, gameplay vertical slice, editor, combat,
mission, or other expansion is authorized by the current documentation.
Future work requires an explicit user request and must preserve the existing
authority boundaries.
