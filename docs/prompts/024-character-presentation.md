# Prompt 24 — Side + Front Character Presentation, Original Pixel Character Art, and View-Aware Animation

- Status: **complete, with Prompt 24A and Prompt 25A–D corrections incorporated**.
- Source: **exact** — [`exact/024-source.txt`](exact/024-source.txt).
- Original objective: give male/female characters production front/side visual identity, deterministic presentation-view resolution, original pixel art, and view-aware motion without replacing the authoritative skeleton.
- Major systems: presentation view/profile resolution, front projection, front/side art semantics, character atlas pages, D3D12 visual routes.
- Major files: [`src/scene/character_art.zig`](../../src/scene/character_art.zig), [`src/scene/presentation_pose.zig`](../../src/scene/presentation_pose.zig), [`src/scene/presentation_view.zig`](../../src/scene/presentation_view.zig), [`docs/CHARACTER_PRESENTATION.md`](../CHARACTER_PRESENTATION.md).
- Tests/evidence: front/side determinism, unchanged animation/physics ownership, atlas/resource checks, production captures.
- Implementation report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-24).
- Commit: `0d6a0b9`, corrected in `4937122` and `7ba3687`.
- Downstream: wardrobe and visual-geometry validation.
- Known limitations: only front plus canonical side are authored; no arbitrary 360-degree presentation.
- Superseded assumptions: any baked removable clothing was corrected by Prompt 24A; initial visual acceptance was superseded by Prompts 25A–25D.
