# RR1 deterministic record/replay implementation

Status: implementation validated. All required CPU, static and release gates
passed. Commit packaging is recorded by Git and the final implementation report.

Base: `cb60fc9a9b24ba7d69578ffc721948e9b00de8fd` (accepted F4, local master).
Dedicated branch: `codex/rr1-deterministic-record-replay`.
Dedicated sibling worktree: `C:/Users/Chad/Documents/2d-renderer-rr1-record-replay`.
Original checkout: `C:/Users/Chad/Documents/2d Renderer`, clean on master.
At startup the locally recorded origin/master matched master (0 ahead, 0 behind).
No fetch was used to assume a different accepted base.

## Inspected facts

Read the applicable AGENTS contract, current architecture/testing/dependency
and project documents, foundation determinism/canonical data/identity/version,
the production clock/controller/collision/intent and physical/action/pending
input boundaries, RuntimeScene publication/snapshot/read/lifecycle contracts,
module/test/gate registration and documentation/architecture/hygiene policies.
Current RuntimeScene mutations and snapshot creation clone and allocate.
RR1 does not change those contracts; the proof creates a stable-address scene
owner and retains one initial immutable lease. The normative
[V1 contract](../architecture/deterministic_record_replay_v1.md) was written
before the production modules.

## Implemented boundary

The core depends only on foundation/std and owns bounded session storage.
The external proof client uses the existing controller and collision world,
not a second simulation implementation. It has one persistent static scene
anchor, canonical spawn-X envelope, a domain-separated derived speed key,
CharacterIntent commands, and accepted movement-speed assignments.

Format/protocol/derivation framing are 1/1/1 at 240 Hz. Header is 196 bytes,
record prefix 11 bytes, and final artifact integrity is 32 bytes.
Envelope bound is 1024 bytes; payload bound 64 bytes; run bound 65536 ticks.
One command, zero/one event and one post-step checkpoint form each tick.
Duplicate/decreasing/skipped/overflowing ticks and unknown required records
are rejected. The player never advances past a pending or failed checkpoint;
its first mismatch retains tick and both digests until disposal.

All 20 controller state fields participate, with a field-by-field perturbation
test and compile-time schema-growth guard. Configuration, spawn/reset values,
all gameplay properties, derivation context/key, collision world and static
anchor semantics also participate. Snapshot/handle addresses, scene cache
revisions, capacity slack and presentation timing do not. This is not arbitrary
whole-engine replay. V1 encoding bytes are a durable compatibility promise;
future incompatible simulation protocols must fail closed or explicitly migrate.

## Focused observed evidence

- 30/30 Debug tests pass.
- 480-tick artifact: 28567 bytes, 480 matching checkpoints.
- Final state digest:
  `c188fcabd7b0e53ec7c628584d38bcc92b5802ecf5dd5012a469f21f2c93d36a`.
- Artifact digest:
  `b921202614d2b11922853e2b7e8cc525b1f9652c75cebbfe727db91e5cdc65e9`.
- Three 160-tick runs, frame groups 1/7/1: zero byte mismatches.
- 120 record+replay ticks with allocation/resize/remap denied and counted:
  zero attempts; exact final controller-state and checkpoint equality.
- Recorder/decode allocation failures and each proof initialization allocation
  boundary release every acquired allocation.
- All 306 proper prefixes of the independent 306-byte golden artifact reject;
  single-byte corruption at each of its 306 positions rejects.
- Golden vectors were calculated independently with Python 3.13 struct and
  hashlib implementing the documented foundation framing; the encoder was not
  called to derive expected bytes.
- Command mutation first fails at tick 12; event mutation first fails at 50.
  Both tests assert original expected digest, actual current digest, and
  persistent diagnostics after further calls.

## Scope limits and provenance

No SDL/GPU initialization, replay hotkeys, CLI filesystem writer, compression,
rollback, editor, world-time, secondary-motion, morphology, projectile or other
milestone work was added. No existing tests were disabled or weakened.
No historical prompt/evidence content was rewritten. The prompt index only
receives a link to this new implementation record.

During development, Zig reported an explicit f64-to-f32 timestep conversion
and the actual millimetre origin field names; both were corrected. The initial
proof moved a scene owner after acquiring a lease, which failed cleanup with
an alignment panic. The lease is now acquired from the stable allocated owner,
and complete initialization-failure cleanup tests pass. A corruption fixture's
untyped byte literal was corrected to an explicit u32 write. These failed
development commands are not counted as passing acceptance gates.

## Final validation

Every command below returned exit code 0. Build commands ran from the
dedicated RR1 worktree with the pinned compiler and worktree-local caches.

| Exact command | Relevant observed output |
| --- | --- |
| `.\.deps\zig-0.16.0\zig.exe version` | `0.16.0`, verified in original checkout and again after dependency copies in RR1 |
| `.\.deps\zig-0.16.0\zig.exe fmt --check build.zig build.zig.zon build src tests` | No formatting findings; explicit captured format exit 0 |
| `.\.deps\zig-0.16.0\zig.exe build test-record-replay -j1 --summary all --global-cache-dir .zig-cache\rr1-global` | 30/30 tests; 3/3 steps |
| `.\.deps\zig-0.16.0\zig.exe build check -j1 --summary all --global-cache-dir .zig-cache\rr1-global` | 27/27 steps; 414 tests |
| `.\.deps\zig-0.16.0\zig.exe build test-full -j1 --summary all --global-cache-dir .zig-cache\rr1-global` | 40/40 steps; 511 tests including both stress tests |
| `.\.deps\zig-0.16.0\zig.exe build verify -j1 --summary all --global-cache-dir .zig-cache\rr1-global` | 91/91 steps; 701 tests across 37 test executables |
| `.\.deps\zig-0.16.0\zig.exe build test-record-replay -Doptimize=ReleaseSafe -j1 --summary all --global-cache-dir .zig-cache\rr1-global` | 30/30 tests; 3/3 steps |
| `.\.deps\zig-0.16.0\zig.exe build test-record-replay -Doptimize=ReleaseFast -j1 --summary all --global-cache-dir .zig-cache\rr1-global` | 30/30 tests; 3/3 steps |
| `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseSafe -j1 --summary all --global-cache-dir .zig-cache\rr1-global` | 22/22 steps |
| `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseFast -j1 --summary all --global-cache-dir .zig-cache\rr1-global` | 22/22 steps |
| `pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools\check_documentation.ps1` | Documentation audit PASS |
| `pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools\check_content.ps1` | Repository source audit and retained content policies passed |

Debug, ReleaseSafe and ReleaseFast all report the same 480-tick final-state
and artifact digests listed above. Source, formatting, architecture,
documentation, provenance, content and no-unfinished-work policies pass.
No physical GPU gate was required or run.

Full logs, exact execution cells with observed exit codes, and the machine-readable
gate ledger are retained locally under `zig-out/rr1-validation/`:
`command-journal.md`, `gate-results.jsonl`, `check.log`,
`check-final.log`, `test-full.log`, `verify.log`, `verify-final.log`,
`release-safe-tests.log`, `release-fast-tests.log`,
`release-safe-build.log`, and `release-fast-build.log`.
These local diagnostics are ignored build output, not runtime dependencies.

## Checkout materialization and resolved failures

The system Git configuration has `core.autocrlf=true`. Its new-worktree
checkout converted committed LF files to CRLF, causing the first `check`
to fail formatting and twelve frozen document hashes (exit 1).
601 unchanged files were verified as newline-only conversions and materialized
as their exact committed bytes. Formatting then passed. Eighteen exact-history
documents require original mixed newline bytes rather than normalized Git
blobs: their originals were verified against the unchanged frozen SHA-256
policy and against identical normalized text before materialization in RR1.
The documentation audit and subsequent `check` passed.

The first `verify` passed every test executable but failed the historical
inventory policy (88/91 steps, exit 1). Ten historical text artifacts had
newline-only byte differences. The original directory inventories matched the
frozen manifest exactly: 56 files / 34328703 bytes, 77 / 110280975 bytes,
and 64 / 104483991 bytes. The original bytes were copied only after confirming
identical normalized text. The unchanged content-policy audit then passed,
and the full `verify` rerun returned exit 0 with 91/91 steps.
No historical text, hash expectation, manifest, threshold, or test was changed.

This is an existing worktree-materialization limitation: a fresh checkout
must preserve the frozen historical newline bytes. RR1 does not change the
repository's Git line-ending policy. The original checkout and global Git
configuration were never modified. No reset, clean, stash, rebase, checkout
switch, worktree deletion, push or merge was performed.

## Changed files and final audit boundary

Created:

- `src/record_replay/root.zig`
- `src/app/record_replay_proof.zig`
- `tests/record_replay_tests.zig`
- `docs/architecture/deterministic_record_replay_v1.md`
- `docs/implementation/rr1_record_replay.md`

Modified:

- `build/modules.zig`, `build/tests_engine.zig`, `build/gates.zig`
- `docs/ARCHITECTURE.md`, `docs/TESTING.md`
- `docs/project/ARCHITECTURE_MAP.md`, `CURRENT_STATE.md`, `KNOWN_GAPS.md`
- `docs/history/prompts/INDEX.md` (new provenance link only)

No existing Zig declaration or test was removed or weakened. The source audit
found zero TODO, FIXME, unfinished-body, unexplained-unreachable or skipped-test
markers. The diff contains only the RR1 additions listed above. Immutable
historical byte materialization creates no Git content diff.

The primary checkout was checked again after all validation: branch `master`,
HEAD `cb60fc9a9b24ba7d69578ffc721948e9b00de8fd`, empty porcelain status,
matching startup. The final Git packaging check must leave RR1 exactly one
intended commit above that base, clean, and leave the original branch/HEAD/status
unchanged. No push or merge is part of this milestone.

## Startup worktree inventory

Exact `git worktree list --porcelain` output captured before creating RR1:

```text
worktree C:/Users/Chad/Documents/2d Renderer
HEAD cb60fc9a9b24ba7d69578ffc721948e9b00de8fd
branch refs/heads/master

worktree C:/Users/Chad/Documents/2d Renderer-engine-lab-el1
HEAD cb60fc9a9b24ba7d69578ffc721948e9b00de8fd
branch refs/heads/feature/engine-lab-el1

worktree C:/Users/Chad/Documents/2d Renderer-media-library
HEAD ae21349486db5dc55cc09171bd9f52c7692f7231
branch refs/heads/feature/media-library-foundation

worktree C:/Users/Chad/Documents/2d Renderer-media-library-ui
HEAD b636c7a0d452d31087ade9f875c1d2f9d2d4f966
branch refs/heads/feature/media-library-ui

worktree C:/Users/Chad/Documents/2d Renderer-psm01-secondary-motion
HEAD cb60fc9a9b24ba7d69578ffc721948e9b00de8fd
branch refs/heads/psm01-secondary-motion

worktree C:/Users/Chad/Documents/2d-Renderer-wt01-world-time-foundation
HEAD cb60fc9a9b24ba7d69578ffc721948e9b00de8fd
branch refs/heads/wt01-world-time-foundation

worktree C:/Users/Chad/Documents/effects-projectiles-e1
HEAD cb60fc9a9b24ba7d69578ffc721948e9b00de8fd
branch refs/heads/feature/e1-effects-projectiles
```

Git retained stale stat entries for 583 content-identical files after byte
materialization. Their index metadata was refreshed only after excluding all
content differences; the complete index blob listing was verified unchanged
and the staged diff remained empty. The resulting status lists only RR1 files.