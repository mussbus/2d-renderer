# Prompt 26 — Layered Environment Art, Hot-Swappable Themes, and Collision-Derived Gameplay Readability

- Status: **complete**.
- Source: **exact roadmap text** — [`exact/026-source.txt`](exact/026-source.txt).
- Objective delivered: production-quality layered environment presentation
  with two preloaded image-backed themes derived around the authoritative
  world/collision data.
- Major systems: typed environment themes and art packs, far/mid/terrain/
  foreground presentation, parallax, collision-derived white standable tops,
  decorative non-collision ledges, detailed collider debug, allocation-free
  theme switching, and focused environment acceptance.
- Major runtime files:
  [`../../../src/scene/environment_art.zig`](../../../src/scene/environment_art.zig),
  [`../../../src/scene/environment_theme.zig`](../../../src/scene/environment_theme.zig),
  and
  [`../../../src/scene/environment_demo.zig`](../../../src/scene/environment_demo.zig).
- Major test/documentation files:
  [`../../../tests/environment_tests.zig`](../../../tests/environment_tests.zig),
  [`../../ENVIRONMENT_THEMES.md`](../../ENVIRONMENT_THEMES.md), and
  [`../decisions/PROMPT26_DECISION_RECORD.md`](../decisions/PROMPT26_DECISION_RECORD.md).
- Production art:
  `assets/art/p26_violet_crystal_ruin_atlas.png` and
  `assets/art/p26_neutral_debug_atlas.png`.
- Tests/evidence: `test-environment` passes 13/13; the 720-frame real
  D3D12/DXIL route preloads eight image-backed pages into nine renderer pages,
  writes seven 640×480 captures under `zig-out/p26_environment_gpu`, records
  two theme switches and a raised-platform landing, and reports zero
  post-initialization allocation/resource growth.
- Implementation report: no verbatim completion message is archived; current
  evidence is indexed in
  [the report archive](../reports/prompt-implementation-reports/INDEX.md#prompt-26).
- Commit: `0dd0f21`.
- Dependencies: accepted Prompt 0–25E character/world/render contracts.
- Known limitation: two themes are authored; environment placement remains
  source-authored rather than editor-authored.
- Scope boundary: themes are presentation only. Collision, support eligibility,
  camera, character state, interactions, and GPU ownership remain with their
  existing authorities.
