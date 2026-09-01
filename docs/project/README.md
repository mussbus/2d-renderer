# Project Documentation

These live handoff documents describe the implemented repository and current
architecture after owner acceptance of F4 — Production Architecture
Hardening. Historical prompt/report archives preserve their milestone-time
claims and are not rewritten as current-state prose.

F1 through F4 are accepted. F4A, F4B1, F4B2, F4C1, F4C2, F4C3, F4C4, F4C5,
F4D, and F4E are owner-approved. The final independent audit of commit
`48a7c677d781543e479b178c6e7b10b139eeb26e` found no CRITICAL or MAJOR
blocker and passed every required final gate. Post-F4 development is no longer
blocked by F4, but every downstream track still requires its own dedicated
implementation request and dependency gates.

- [Master roadmap](MASTER_ROADMAP.md)
- [Current state](CURRENT_STATE.md)
- [Architecture map](ARCHITECTURE_MAP.md)
- [F4A production-architecture audit](../implementation/f4a_production_architecture_audit.md)
- [F4C1 production-definition extraction](../implementation/f4c1_production_definition_extraction.md)
- [F4E repository canonicalization](../implementation/f4e_repository_canonicalization.md)
- [Unified authoring contracts](AUTHORING_CONTRACTS.md)
- [Production wardrobe audit](WARDROBE_AUDIT.md)
- [Scope boundaries](SCOPE_BOUNDARIES.md)
- [Known gaps](KNOWN_GAPS.md)
- [Prompt ledger](../history/prompts/INDEX.md)
- [Architecture decisions](../decisions/README.md)
- [Implementation reports](../history/reports/README.md)

Existing subsystem documents under `docs/` remain authoritative for detailed algorithms and acceptance routes. This directory supplies the cross-project map and status needed to find them.
