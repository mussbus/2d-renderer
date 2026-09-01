# Prompt 25A — Visual Quality Correction and Hard Acceptance Gate

- Status: **superseded by Prompts 25B–25D**.
- Source: **exact** — [`exact/025A-source.txt`](exact/025A-source.txt).
- Original objective: preserve Prompt 25 architecture while rejecting schematic/poor production presentation and requiring real D3D12 visual acceptance.
- Major systems: visual-quality decision/evidence routes, authored-size/pivot/aspect corrections, stronger acceptance discipline.
- Major files: production art/presentation corrections, [`docs/PROMPT25A_DECISION_RECORD.md`](../decisions/PROMPT25A_DECISION_RECORD.md), [`docs/VISUAL_ACCEPTANCE_25A.md`](../../VISUAL_ACCEPTANCE_25A.md).
- Tests/evidence: focused visual-quality tests, real D3D12 captures, aggregate regressions at the time.
- Implementation report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-25a).
- Commit: `4937122` lineage.
- Downstream: Prompt 25B.
- Known limitation: the resulting output still had obvious footwear, clothing, and articulation defects.
- Superseding work: Prompt 25B explicitly rejected test-led acceptance; Prompt 25C built the semantic validator; Prompt 25D closed production failures.
