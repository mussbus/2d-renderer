# Historical development records

Everything below this directory is non-normative provenance. It preserves the
prompt ledger, exact source prompts, milestone decision records, and historical
implementation reports that explain how the repository evolved. These records
must not override current contracts or be treated as required reading for normal
engine work.

Current authority is, in descending order:

1. `AGENTS.md` and the accepted subsystem contracts under `docs/architecture`;
2. `README.md`, `docs/ARCHITECTURE.md`, `docs/DEPENDENCIES.md`,
   `docs/TESTING.md`, and `docs/CONTROLS.md`;
3. `docs/project/CURRENT_STATE.md` and the current project maps/policies;
4. current source, tests, asset manifests, and build/check policy.

Historical material is organized as follows:

- `prompts/`: reconstructed and exact development requests;
- `source-prompts/`: preserved source-roadmap bundles;
- `decisions/`: prompt-era owner decisions;
- `reports/`: implementation and acceptance reports.

Git history preserves former paths and any removed historical bytes. Active
runtime art is indexed by `assets/manifest.json`; deliberately retained art and
canonical-geometry lineage is indexed by `assets/history/manifest.json`.
