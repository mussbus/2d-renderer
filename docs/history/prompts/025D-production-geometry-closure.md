# Prompt 25D — Make the Production Character Actually Pass Visual Geometry

- Status: **complete and accepted**.
- Source: **exact** — [`exact/025D-source.txt`](exact/025D-source.txt).
- Original objective: harden the Prompt 25C validator, correct production root causes, require zero production failures, retain at least 129 focused tests, visually inspect real D3D12 captures, and approve only accepted goldens.
- Major systems: design-specific fit/coverage, multi-record audit, corrected landmarks/art/bindings/projection, pre/final reports, 12 approved D3D12/DXIL goldens.
- Major files: visual-geometry/audit/presentation/catalog code and art, [`docs/PROMPT25D_DECISION_RECORD.md`](../decisions/PROMPT25D_DECISION_RECORD.md), [`tests/goldens/p25d/manifest.json`](../../../tests/goldens/p25d/manifest.json).
- Tests/evidence: focused gate, production report with zero failures, golden check, Debug/Release/GPU/full regression.
- Implementation report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-25d).
- Commit: `7ba3687`.
- Downstream: Prompt 25E consolidation; all later art/content.
- Known limitation: acceptance covers the declared current views, content, pose/morphology matrix, and acceptance camera—not arbitrary future garments.
- Superseding work: none. Prompt 25E documents but does not alter the accepted visuals.
