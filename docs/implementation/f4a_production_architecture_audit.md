# F4A — Whole-Repository Production Architecture Audit

**Status:** OWNER-APPROVED

**Audit date:** 2026-08-29

**Audited commit:** `685383a9012f10769c89b363d2eeff820410e0ae`

**Scope:** Read-only whole-repository production architecture, coupling,
retention and hygiene audit

## 1. Authority and boundary

F1, F2A, F2B, F2C and F3 are owner-approved. The F2C
authority-encapsulation amendment at the audited commit is accepted, and the
Foundation is the architectural substrate for F4.

F4A inspected the complete first-party tracked repository. It changed no
tracked file, began no production refactor and began no downstream feature
track. F4A did not reopen F identity, canonical-data, scene-core ownership,
runtime mutation authority, snapshots, publication, hierarchy, lifecycle or
another accepted F contract.

F4B has not begun. This record approves architecture direction and retention
policy; it is not blanket authorization to delete, rename, archive or refactor
repository content.

## 2. Quantitative audit baseline

The clean audited baseline contained:

- 904 tracked files totaling 804,085,814 bytes, approximately 766.8 MiB;
- 235 Zig files, including 164 under `src/`, 66 test roots/files, four Zig
  tools and `build.zig`;
- 426 files under `assets/` and 129 documentation files;
- 25 command-line demo modes, a separate GPU-smoke route and three report
  executables;
- 129 build-created Zig modules and 818 explicit build import edges;
- 50 named build steps; and
- 629 tests in the full aggregate suite.

All tracked production Zig modules were reachable through build wiring or
source imports. No confirmed Zig import cycle, TODO, FIXME, disabled test or
unfinished production stub was found.

The audit validated the focused Foundation gate, the normal build, the full
CPU suite, the repository check and the documentation check. It did not rerun
physical-GPU or manual visual acceptance because no runtime behavior changed.

## 3. Executive conclusion

The repository is healthy enough to preserve, and the accepted F foundation
remains sound, but the repository is not yet structurally ready for the
post-F4 parallel fan-out.

The primary blockers are:

1. production-relevant definitions and behavior owned by demo modules;
2. a combined application, renderer, GPU-resource, demo and evidence
   composition root centered on `src/graphics/gpu_demo.zig`;
3. broad mutable surfaces outside F, especially in character and interaction
   runtime aggregates;
4. the adoption gap between accepted F `foundation`/`scene_core` contracts and
   the existing legacy demo-driven runtime; and
5. build/test/static-check infrastructure coupled to historical prompt and
   acceptance structure.

F4 must determine what survives before migrating the survivors. Obsolete code
must not be moved onto a new architecture merely to delete it later.

## 4. Critical and major findings

### F4A-CRIT-001 — Demo-owned production capability

Reusable humanoid/anatomy definitions, equipment definitions, fitted garment
and cape mesh factories, current collider inputs and later wardrobe/environment
composition depend on `*_demo.zig` or playground modules. Removing historical
demos today would remove actual engine capabilities. Production logic and
fixtures must first receive domain ownership and replacement coverage.

### F4A-CRIT-002 — Application/renderer/evidence composition root

`src/graphics/gpu_demo.zig` owns SDL/window/device setup, GPU resources,
shaders, pipelines, asset upload, rendering, mode selection, scenario
coordination, capture and evidence/report behavior. Lower-level rendering is
therefore coupled to concrete applications and historical acceptance routes.

### F4A-MAJ-001 — Broad mutable implementation surfaces

Character, interaction, controller, animator, appearance, equipment and GPU
aggregates expose mutable fields that can become accidental contracts. F4C
should preserve useful aggregates while introducing narrow command and read
boundaries.

### F4A-MAJ-002 — F adoption gap

The accepted F runtime is strongly isolated and encapsulated, but the current
production demonstration does not consume it. Legacy character/runtime IDs
remain separate from F identity. F4C requires a bounded adapter; it must not
create a second persistent identity authority or redesign F.

### F4A-MAJ-003 — Build and policy change magnets

`build.zig`, `src/graphics/gpu_demo.zig`, `tools/check_repository.ps1`,
`docs/TESTING.md`, `docs/ARCHITECTURE.md` and `src/main.zig` repeatedly change
with unrelated feature work. Root build code directly knows applications,
tests, tools, assets and milestone evidence. Static checks mix durable
architecture rules with exact prompt-era implementation text.

### F4A-MAJ-004 — Input/application leakage

Platform input types contain wardrobe, presentation, environment and evidence
actions. F4C should retain renderer-independent physical input and
`CharacterIntent` while moving content/application action mapping upward.

### F4A-MAJ-005 — Development-gate taxonomy

The normal CPU/static gate includes permanent engine contracts, canonical
content qualification, prompt art audits and historical evidence rules. F4
must reassign existing coverage to explicit fast, full CPU, content, GPU,
manual and historical gates without weakening it.

## 5. Strengths to preserve

- F2A/F2B/F2C contracts and F2C authority encapsulation are accepted and
  strongly tested.
- RuntimeScene commands, two-phase publication, rollback, snapshots,
  hierarchy, lifecycle, capacity and generational-handle behavior remain
  F-owned.
- Deterministic simulation systems are CPU-testable without a window or GPU.
- External dependencies are pinned exactly and SDL integration is centralized.
- GPU resource ownership and destruction paths are explicit.
- Canonical model and geometry implementations are substantial but generally
  cohesive; their authority must not be weakened by F4 cleanup.
- No tracked production Zig module was classified as dead solely from its
  filename or reference count.

## 6. Approved owner decisions

### F4A-OD-001 — Demo retention matrix: APPROVED

The audit's demo classifications are approved as intended end states, not as
blanket deletion authorization. Production behavior, unique regression value
and required fixtures/assets/evidence must have named dispositions first.

| Current route | Approved intended end state |
|---|---|
| `sprites` | KEEP BUT SIMPLIFY |
| `humanoid` | REPLACE WITH FOCUSED TEST |
| `animation` | REPLACE WITH FOCUSED TEST |
| `controller` | MERGE INTO ENGINE SANDBOX |
| `secondary-motion` | REPLACE WITH INTEGRATION TEST |
| `multi-character` | REPLACE WITH INTEGRATION TEST |
| `handshake` | REPLACE WITH INTEGRATION TEST |
| `handshake-ik` | REPLACE WITH INTEGRATION TEST |
| `foot-planting` | REPLACE WITH INTEGRATION TEST |
| `integrated` | REPLACE WITH INTEGRATION TEST |
| `playground` | MERGE INTO ENGINE SANDBOX |
| `modular-body` | EXTRACT PRODUCTION LOGIC THEN DELETE |
| `equipment` | EXTRACT PRODUCTION LOGIC THEN DELETE |
| `properties` | REPLACE WITH INTEGRATION TEST |
| `breathing` | REPLACE WITH INTEGRATION TEST |
| `mesh-attachments` | EXTRACT PRODUCTION LOGIC THEN DELETE |
| `attachment-secondary` | REPLACE WITH INTEGRATION TEST |
| `side-scroller` | MERGE INTO ENGINE SANDBOX |
| `foundation` | KEEP BUT SIMPLIFY |
| `art-assets` | REPLACE WITH INTEGRATION TEST |
| `character-presentation` | REPLACE WITH INTEGRATION TEST |
| `wardrobe` | MERGE INTO ENGINE SANDBOX |
| `visual-quality` | KEEP BUT SIMPLIFY |
| `anatomy-quality` | KEEP BUT SIMPLIFY |
| `environment` | MERGE INTO ENGINE SANDBOX |
| `gpu-smoke` | KEEP |
| `visual_geometry_report` | KEEP BUT SIMPLIFY |
| `anatomy_quality_report` | KEEP BUT SIMPLIFY |
| `foundation_coherence_report` | KEEP BUT SIMPLIFY |

### F4A-OD-002 — Consolidated engine sandbox: APPROVED

Target one primary engine sandbox, separate GPU smoke, and only genuinely
useful specialized content-validation/report applications.

### F4A-OD-003 — Historical binary evidence: APPROVED IN PRINCIPLE

Retain compact manifests, hashes and provenance in the active repository.
Large binary history may move only through an intentional, reproducible archive
process approved during later F4 work.

### F4A-OD-004 — Canonical authority and lineage: APPROVED

Preserve current canonical authority and sufficient lineage. Repository-size
or test-time savings do not justify loss of reproducibility.

### F4A-OD-005 — Prompt-era active names: APPROVED FOR F4E

Active production-facing names should become domain-based through explicit
manifests, versioning and compatibility where required. Blind replacement and
silent canonical identity/hash changes are prohibited.

### F4A-OD-006 — Character architecture: APPROVED

Retain a useful character coordinator/aggregate. Narrow its ownership and
provide command/read boundaries; do not perform a speculative wholesale ECS
rewrite.

### F4A-OD-007 — Legacy and F identity: APPROVED

F identity remains authoritative. Legacy IDs must eventually be contained
behind a bounded adapter to accepted F identity and RuntimeScene contracts. A
second persistent identity authority is prohibited.

### F4A-OD-008 — Renderer backend scope: APPROVED

D3D12 remains the only required current shipping/runtime backend. Extract a
boundary sufficient for replacement and testing without implementing another
backend merely to prove it.

### F4A-OD-009 — Gate taxonomy: APPROVED

The target gates are:

1. fast engine contract/static;
2. full deterministic CPU integration;
3. canonical/content qualification;
4. GPU smoke;
5. manual/visual acceptance; and
6. historical evidence reproduction on demand.

This reclassification does not authorize removal of coverage.

### F4A-OD-010 — Normative and historical documentation: APPROVED

Current architecture and accepted contracts must be visibly normative.
Prompts, milestone reports, old audits and acceptance records remain historical
and may retain their original terminology and findings.

### F4A-OD-011 — Historical visual goldens: APPROVED

P25D historical goldens must remain until equivalent current-renderer
regression coverage exists.

### F4A-OD-012 — Build modularization: APPROVED

F4 may use explicit domain-owned build helpers. Opaque directory
auto-discovery must not replace visible dependency wiring.

### F4A-OD-013 — Binary asset authority manifests: APPROVED

Active source/runtime atlas relationships require explicit manifests before
predecessor deletion or naming migration. Existing binary authority is not
disposable merely because layered editable source is absent.

### F4A-OD-014 — Low-risk F4B1 hygiene set: APPROVED FOR F4B1 ONLY

The bounded candidate set is tracked `.tmp` staging/generated artifacts,
tracked Python `.pyc` files, the unused typo-named
`tools/git-checkpoing.ps1`, and corresponding ignore corrections. This is not
authorization for broader demo, test, asset, evidence or canonical cleanup.

### F4A-OD-015 — Compatibility policy: APPROVED

Preserve accepted F and protected canonical contracts unless a separate
owner-approved compatibility/versioning migration changes them. Internal
historical demo APIs have no long-term compatibility promise.

## 7. Approved F4 sequence

```text
F4A — whole-repository architecture/retention audit
       STATUS: OWNER-APPROVED
  -> F4-ADMIN — record approval and current state
       STATUS: this administrative update
  -> F4B1 — safe hygiene and retention groundwork
  -> F4B2 — superseded demo/test retirement where replacement coverage exists
  -> F4C — production architecture migration
  -> F4D — independent-engine and decoupling proof
  -> F4E — repository canonicalization and provenance cleanup
  -> final F4 acceptance
  -> post-F4 parallel development
```

F4B through F4E have not begun. Their implementation requires dedicated
authorization.

## 8. Phase intent and completion boundaries

### F4B1 — Safe hygiene and retention groundwork

Prepare manifests and remove only explicitly approved low-risk generated or
unused artifacts. Do not remove production behavior, unique regression
coverage, canonical authority or unrecoverable provenance.

### F4B2 — Superseded demo/test retirement

Retire only scenarios whose production behavior has already moved to a domain
owner and whose useful regression value has named focused or integration
coverage.

### F4C — Production architecture migration

Extract demo-owned production definitions, separate application/rendering/
evidence responsibilities, encapsulate runtime mutation, move application
actions out of platform input, bridge the legacy runtime to F and modularize
explicit build/test registration. Do not redesign F or add downstream
features.

### F4D — Independent-engine and decoupling proof

Prove that production modules build and test without historical demos/evidence,
that at least two thin composition roots can consume supported contracts, and
that lower layers cannot import applications or evidence.

### F4E — Engine 1.0 provenance cleanup

Adopt domain-based active names, distinguish normative documentation from
history, establish asset manifests and archive approved historical material
without silently changing canonical identity or authority.

## 9. Current gate

F4A is complete and owner-approved. F4 overall is not accepted. The next
implementation phase is F4B1, but F4B1 has not started and requires a dedicated
implementation request. SEM, SAF, MAT, CHR, CL, OBJ, PFB, LVL, SCN, PG, AN,
INT, PHY, WRD, ENV, AI, GAME, ED, IMG and every other post-F4 development track
remain blocked until final F4 acceptance.
