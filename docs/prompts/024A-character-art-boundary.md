# Prompt 24A — Anatomy/Clothing Character-Art Boundary Correction

- Status: **complete**.
- Source: **exact** — [`exact/024A-source.txt`](exact/024A-source.txt).
- Original objective: ensure non-sexual base anatomy and removable clothing/equipment are independently addressable in actual production art and bindings.
- Major systems: semantic anatomy ownership, base-presentation modesty classification, separate garment/equipment visuals, deterministic front/side resolution.
- Major files: character art/bindings plus [`docs/CHARACTER_ART_BOUNDARY_DECISION.md`](../CHARACTER_ART_BOUNDARY_DECISION.md).
- Tests/evidence: base anatomy without equipment, identity separation, shared-page semantic separation, front/side determinism, allocation/render-path invariants, D3D12 inspection.
- Implementation report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-24a).
- Commit: correction lineage represented by `4937122`.
- Downstream: Prompt 25 wardrobe and all future customization.
- Known limitations: a neutral permanent modesty surface remains base presentation, not an equipped garment.
- Superseding work: Prompt 25D corrected later geometry/art without weakening this ownership boundary.
