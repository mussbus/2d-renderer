# Prompt 25C — Build the Visual Geometry Validator Before Touching the Art

- Status: **complete measuring instrument; production-failure expectation superseded by Prompt 25D**.
- Source: **exact** — [`exact/025C-source.txt`](exact/025C-source.txt).
- Original objective: build reusable semantic landmark, orientation, fit, coverage, continuity, pose/morphology, diagnostic, overlay, and golden support that quantitatively rejected the current bad production output.
- Major systems: local semantic geometry, alpha-visible metadata, production-transform traces, typed fit contracts, structured reports, clean/debug D3D12 capture support, controlled good/bad fixtures.
- Major files: [`src/scene/visual_geometry.zig`](../../src/scene/visual_geometry.zig), [`src/scene/visual_geometry_audit.zig`](../../src/scene/visual_geometry_audit.zig), visual-geometry tests/tools, [`docs/VISUAL_GEOMETRY.md`](../VISUAL_GEOMETRY.md).
- Tests/evidence: `zig build test-visual-geometry -j1`, intentional Prompt 25B failure report, clean/debug captures.
- Implementation report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-25c).
- Commit: `7ba3687` lineage.
- Downstream: Prompt 25D and future content authoring.
- Known limitation: first-pass generic contracts required hardening before they could become final production acceptance.
- Superseding work: Prompt 25D retained negative fixtures but changed current production to zero-failure acceptance.
