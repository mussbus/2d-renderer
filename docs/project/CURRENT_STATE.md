# Current State

Snapshot basis: Prompt 25D HEAD `7ba368716f80340179492956ed7a86049671cfd2`, inspected by Prompt 25E on 2026-07-27.

Status vocabulary:

- **complete** — implemented and protected by appropriate tests/evidence;
- **complete but visually provisional** — functional, but art or presentation has not received final visual acceptance;
- **partially implemented** — useful production behavior exists, but the stated concept is incomplete;
- **documented only** — contract exists in documentation, not in the runtime schema;
- **deferred** — intentionally postponed;
- **not started** — no implementation should be inferred.

## Production systems

| System | Status | Current evidence and boundary |
|---|---|---|
| SDL3 GPU renderer and D3D12/DXIL route | complete | Atlas-backed sprites and deformable meshes use the global unified queue; Prompt 25D goldens were captured through the real production route. |
| Fixed-step simulation, animation, physics, and controller | complete | 240 Hz deterministic simulation; renderer interpolation does not own simulation. |
| Input and character intent | complete | Keyboard/gamepad state becomes a bounded intent structure; pending edges survive zero-substep frames. |
| Interactions, handshake, and IK | complete | Interaction coordination owns handshakes; visual IK does not replace root physics. |
| Semantic anatomy and morphology | complete | One authoritative skeleton, typed anatomy instances, body presets, and bounded morphology channels. |
| Equipment and loadouts | complete | Typed slots, topology-aware bindings, bounded recipe expansion, transactional equip/unequip, cosmetic/gameplay separation. |
| Deformation, mesh visuals, secondary motion | complete | Shared deformation and fixed-capacity visual state; no per-character renderer. |
| Character properties/capabilities | complete | Generic resolved attributes and counted capability sources. |
| Art-pack and atlas pipeline | complete | Typed pages, regions, semantic view bindings, alpha-visible metadata, and explicit resource ownership. |
| Front/side character presentation | complete | Front plus canonical side presentation, deterministic gameplay-facing projection, male/female production art. |
| Base anatomy/clothing separation | complete | Base anatomy resolves without an equipped garment; removable equipment never owns or replaces anatomy identity. |
| Wardrobe catalog and presets | complete | 30 logical items, 36 visual components, 15 presets, and a custom recombined outfit. |
| Semantic visual-geometry validator | complete | Production transforms, semantic landmarks, fit/coverage, proportions, pose/morphology sweeps, structured reports, D3D12 debug overlays, and golden support. |
| Current Prompt 25D production visuals | complete | Focused gate and production report pass with zero failures; 12 approved D3D12/DXIL goldens are stored. |
| Semantic body-relative garment depth schema | documented only | Current content resolves numeric visual layers. Required reusable depth relations are defined in [AUTHORING_CONTRACTS.md](AUTHORING_CONTRACTS.md), but no current accepted item requires a runtime extension. |
| Authored side-left/side-right garment variants | documented only | Current production side art is mirror-safe. Directional and mixed-fragment policies are defined for future content. |
| First-class collar coverage and shoulder-slope contour | documented only | Current validator has point/span fit and per-item coverage zones, but not the richer semantic contour contract required by a future editor. |
| Environment themes | not started | Prompt 26 scope only. |
| Integrated Prompt 27 presentation | not started | Planned acceptance composition only. |
| Narrow gameplay vertical slice | not started | No beginning/objective/completion/replay loop exists. |
| Character, wardrobe, level, and mission editors | not started | No GUI or second authoring model exists. |

## Focused demonstrations

- `--demo animation`, `--demo interactive`, and later character/physics/interaction diagnostics.
- Anatomy, equipment, deformation, secondary-motion, properties, and foundation playground routes.
- Prompt 23 art-pack acceptance route.
- Prompt 24 front/side character presentation route.
- Prompt 25 wardrobe route with presets and custom outfit.
- Prompt 25C/25D visual-quality route, report generator, geometry-debug overlay, and D3D12 golden checker.

See [../TESTING.md](../TESTING.md) for commands and [../prompts/INDEX.md](../prompts/INDEX.md) for milestone ownership.

## What Prompt 25D changed

Prompt 25D hardened the Prompt 25C measuring instrument, retained controlled negative fixtures, changed production acceptance to require zero failures, corrected production anatomy/equipment art and bindings, generated before/after reports, and approved only the final D3D12 captures as goldens. Its rationale is preserved in [../PROMPT25D_DECISION_RECORD.md](../PROMPT25D_DECISION_RECORD.md).

## Provisional or incomplete areas

- Current garment fragments are recipes, but they expose no authored stable fragment name independent of the recipe ID.
- Current production uses numeric visual layers; semantic body-relative depth relations remain a documented authoring requirement.
- Current side art is canonical and reflected with the character. No production garment exercises authored directional variants.
- Collar intent is represented indirectly by garment-specific fit landmarks/coverage zones rather than a first-class neck/collar declaration.
- Shoulder fit uses semantic points and spans, not a slope-aware contour from neck base through shoulder root and armhole.
- The split skirt is one deformable mesh, not a reusable rear/central/front fragment composition.
- Hair is independently addressable but currently one presentation visual; headwear is a higher numeric layer rather than a reusable back-hair/headwear/front-hair recipe.

The impact and intended milestones are in [KNOWN_GAPS.md](KNOWN_GAPS.md).

## Next authorized milestone

Prompt 25E is the active consolidation milestone. After it is accepted, Prompt 26 is the next **planned** milestone, but it is not authorized by this document and was not started. No editor or gameplay-loop work is implied.
