# Prompt 25 — Modular Visual Wardrobe Catalog, View-Aware Equipment Art, and Outfit Presets

- Status: **complete, with visual corrections superseded by Prompts 25A–25D**.
- Source: **exact** — [`exact/025-source.txt`](exact/025-source.txt).
- Original objective: stress-test Prompt 17 equipment with reusable original clothing/equipment art, front/side bindings, layered combinations, presets, and custom recombination.
- Major systems: 30 cosmetic logical items, 36 visual components, 15 presets, custom outfit, wardrobe art pages, view-aware presentation, garment fit metadata.
- Major files: [`src/scene/wardrobe_catalog.zig`](../../src/scene/wardrobe_catalog.zig), [`src/scene/wardrobe_art.zig`](../../src/scene/wardrobe_art.zig), [`src/scene/wardrobe_presentation.zig`](../../src/scene/wardrobe_presentation.zig), [`docs/WARDROBE.md`](../WARDROBE.md).
- Tests/evidence: wardrobe catalog/loadout/view tests, resource/allocation checks, D3D12 wardrobe route.
- Implementation report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-25).
- Commit: `0d6a0b9`.
- Downstream: Prompts 25A–25E.
- Known limitations: initial visual fit/art was not accepted; current accepted state is Prompt 25D.
- Superseding work: 25A art gate, 25B art correction, 25C measuring instrument, 25D production closure.
