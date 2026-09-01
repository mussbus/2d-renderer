# Prompt 25B — Fix the Character Art, Not the Tests

- Status: **superseded by Prompts 25C and 25D**.
- Source: **exact** — [`exact/025B-source.txt`](exact/025B-source.txt).
- Original objective: correct source art and presentation root causes without weakening tests, using front visual acceptance first.
- Major systems: revised anatomy/equipment art, alpha-tight regions, authored size/pivot and attachment corrections, visual inspection workflow.
- Major files: production art/presentation definitions, [`docs/PROMPT25B_DECISION_RECORD.md`](../decisions/PROMPT25B_DECISION_RECORD.md).
- Tests/evidence: focused captures and then proportionate regressions.
- Implementation report: [archive entry](../reports/prompt-implementation-reports/INDEX.md#prompt-25b).
- Commit: `4937122`.
- Downstream: Prompt 25C.
- Known limitation: human review still exposed shoe direction/fit and geometric inconsistencies that existing tests could not measure.
- Superseding work: Prompt 25C intentionally froze the bad output and built a measuring instrument.
