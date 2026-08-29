# F3 Shared Foundation Independent Acceptance Audit

Status: Rejected at the public-contract and mutation-authority gate; candidate
fix implemented, independent F3 rerun required

Revision: 1

Date: 2026-08-29

Audited base: `29b01df8c2e39e0447b5270faa23708afcd6b99d`

## 1. Scope and stop condition

This record audits the committed F1/F2A/F2B/F2C shared foundation as an
independent acceptance gate before parallel W/R/P/E/U/C/A/H development.
It does not authorize or begin any downstream milestone.

The F3 request requires the audit to stop for owner review when a foundation
defect is found. The audit therefore stopped after finding F3-MAJ-001. Later
F3 protocols and broad aggregate gates were deliberately not run. Their status
is **not evaluated**, not pass or fail.

## 2. Starting-state evidence

- The worktree was clean before this audit record was created.
- `master` was one commit ahead of `origin/master`.
- `HEAD` was the committed F2C change `29b01df foundation: implement F2C
  runtime scene assembly`.
- The active compiler reported Zig `0.16.0`.
- No production, canonical-asset, topology, evidence, runtime-route, or
  downstream-track file was modified.

## 3. Focused milestone gates

| Gate | Command | Result |
| --- | --- | --- |
| F2A | `zig build test-foundation-primitives -j1 --summary all --seed 0x6f084e2a` | PASS, 27/27 tests |
| F2B | `zig build test-scene-core-authored -j1 --summary all --seed 0x6f084e2a` | PASS, 39/39 tests |
| F2C | `zig build test-scene-core-runtime -j1 --summary all --seed 0x6f084e2a` | PASS, 25/25 tests |

Each command used an isolated audit cache. These passes establish only the
existing focused test behavior; they do not waive the public-contract defect
below.

## 4. Finding F3-MAJ-001: writable F-owned internals are public

Severity: **MAJOR; foundation-freeze blocking**

Affected gate: Public API inventory and mutation-authority conformance

Disposition: **FAIL**

Amendment status: **CANDIDATE FIX IMPLEMENTED — REQUIRES F3 RERUN**

### Contract

The accepted F2C implementation record states that F2C owns registry slots,
generation counters, identity mappings, hierarchy adjacency, cached
transforms, Level records, runtime-owned values, and snapshots. It further
states that downstream code receives opaque read views and cannot obtain a
writable registry or generation counter.

### Implementation evidence

- `src/scene_core/root.zig:11-14` publicly exports `registry`,
  `runtime_asset`, `runtime_entity`, and `runtime_scene`.
- `src/scene_core/registry.zig:98-106` declares public `EntityRegistry` with
  directly accessible storage, logical-capacity, mapping-count, active-count,
  and retired-count fields.
- `src/scene_core/registry.zig:164-245` publicly exposes `insert`, `destroy`,
  `getMutable`, `resolve`, and `assignPersistentId`.
- `src/scene_core/runtime_entity.zig:247-275` publicly exposes
  `WorldTransform` and the directly mutable `RuntimeEntity`, including handle,
  persistent identity, parent, children, local/world transforms, dirty and
  revision state, enabled state, tags, extensions, assets, and prefab data.
- `src/scene_core/runtime_scene.zig:269-275` publicly exposes
  `RuntimeScene` bookkeeping fields such as publication generation, snapshot
  lease count, lease limit, and growth sink.
- `tests/scene_core/registry_tests.zig:3-5` imports `scene_core` exactly as a
  downstream module can and aliases `scene_core.registry.EntityRegistry`.
  Lines 43-60 then call its mutating registry methods. This proves that the
  exposure is reachable through the supported module root, not merely an
  internal source-file detail.

### Consequence

A downstream track can construct and mutate the F-owned registry and runtime
records without the F-owned mutation context. It can bypass authority checks,
candidate-state validation, two-phase publication, growth reporting, snapshot
lease rules, and coordinated publication of track-owned compiled extension
tables. Direct writes can also desynchronize handles, persistent-ID mappings,
hierarchy adjacency, cached transforms, revisions, and counters.

This is the request's explicit MAJOR category of an overexposed mutable API.
An unresolved MAJOR prohibits foundation freeze even though the focused tests
pass.

### Candidate amendment evidence

The dedicated F2C/F3 authority-encapsulation amendment removes `registry` and
`runtime_entity` from `scene_core/root.zig`, places `RuntimeScene` state and
bookkeeping behind a const opaque implementation context, changes snapshot
contexts to const pointers, routes registry white-box tests through a separate
test-only internal module, and adds public-root plus repository import-policy
regression coverage. Existing mock R/P/gameplay/C consumers continue to use
the supported `scene_core` root and read-only snapshot views.

This paragraph records implementation evidence only. It does not change the
failed F3 disposition, approve the Foundation freeze, or substitute for the
required independent F3 rerun from a clean committed amendment base.

## 5. Minimal required amendment

The amendment should change visibility and test routing, not redesign F2C:

1. Remove public downstream access to `registry` and `runtime_entity` through
   the `scene_core` root, or replace those exports with a narrow contract-only
   façade.
2. Keep public value/configuration types genuinely needed by consumers, such
   as mutation authority, lifetime, growth diagnostics, and read-only world
   transform data, in a dedicated public contract module or selected façade
   exports.
3. Make `EntityRegistry`, writable `RuntimeEntity`, `getMutable`, identity
   assignment, insertion/destruction, generation state, and hierarchy storage
   internal to the F-owned implementation.
4. Make runtime-scene publication and snapshot bookkeeping opaque or
   accessor-only; public consumers must not be able to write it directly.
5. Route registry implementation tests through an internal test import rather
   than retaining downstream visibility solely for testing.
6. Add a public-surface conformance check that compiles an external-style
   consumer and proves it cannot import or mutate those internals while the
   approved façade remains usable.
7. Re-run F2C focused tests and the aggregate/check/full gates, commit the
   approved amendment separately, and restart F3 from a clean committed base.

H compatibility approval remains required if the amendment changes any
protected H-facing API or behavior. No such change is made by this audit.

## 6. Gate disposition

| F3 area | Disposition | Evidence or reason |
| --- | --- | --- |
| Clean committed base | PASS | Clean at entry; F2C was `HEAD` |
| Zig version | PASS | Exactly `0.16.0` |
| F2A focused suite | PASS | 27/27 |
| F2B focused suite | PASS | 39/39 |
| F2C focused suite | PASS | 25/25 |
| Public API and mutation authority | **FAIL** | F3-MAJ-001 |
| F1 contract conformance | **FAIL for affected ownership rule** | Public implementation contradicts accepted opaque-read-view contract |
| Dependency-direction audit | NOT EVALUATED | Mandatory stop reached |
| Competing-concept classification | NOT EVALUATED | Mandatory stop reached |
| Independent authored determinism protocol | NOT RUN | Mandatory stop reached |
| Independent runtime transaction protocol | NOT RUN | Mandatory stop reached |
| Capacity/allocation/thread audit | NOT RUN | Mandatory stop reached |
| Aggregate `test`/`check`/`test-full` gates | NOT RUN | Mandatory stop reached |
| Parallel-development freeze | **REJECT** | One unresolved freeze-blocking MAJOR |

## 7. Recommendation

**REJECT FOUNDATION FREEZE.** Do not authorize parallel W/R/P/E/U/C/A/H
implementation against the current public F2C surface. Owner review and a
dedicated, minimal F2C visibility amendment are required first. After that
amendment is accepted and committed, repeat the complete F3 audit from a clean
base.

No F2, F3 repair, downstream implementation, commit, or push was performed by
this audit.
