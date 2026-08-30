# F4B1 — Safe Hygiene and Retention Groundwork

**Status:** F4B1 implementation candidate — awaiting owner review

**Date:** 2026-08-29

**Starting commit:** `a05118e7ec69bf6b8485a536f83413d298febb5d`

**Starting branch/upstream:** `master` / `origin/master`, synchronized at the
starting commit

## 1. Authority and scope

F1 through F3 and F4A are owner-approved. F4-ADMIN is present in the committed
starting baseline. F4A-OD-014 authorizes F4B1 to remove only:

- the six tracked generated/staging files beneath repository-root `.tmp/`;
- the three tracked Python `.pyc` cache files;
- the obsolete typo-named `tools/git-checkpoing.ps1` helper; and
- corresponding narrow ignore rules and retention/status documentation.

This phase does not authorize demo, test, production, build, evidence,
canonical, asset-name or architecture changes. F4B2, F4C and downstream feature
work have not begun.

## 2. Starting repository inventory

- Tracked files: 905.
- Tracked worktree bytes: 804,106,076.
- Worktree: clean.
- Branch relation: zero commits ahead and zero behind `origin/master`.
- Compiler: Zig 0.16.0.

## 3. Pre-deletion provenance

Git blob IDs below identify the exact committed objects. SHA-256 is also
recorded independently. Every candidate was introduced as part of its stated
historical commit and remains recoverable from Git history.

### Generated `.tmp` transport/staging images

All six files have valid WebP or PNG signatures. Repository-wide searches
found no build, source, test, tool or documentation consumer of the directory,
complete paths or basenames. The four named review/inspection transports have
retained PNG evidence counterparts under
`assets/canonical_model/human_base/geometry/evidence/`. The two `test_*` files
are codec/transport probes; `test_bgra.lossless.webp` is byte-identical to the
sheet-A WebP. None is canonical source authority or an active fixture.

| Repository-relative path | Bytes | Git blob | SHA-256 | Classification and retained authority |
|---|---:|---|---|---|
| `.tmp/prompt2c_lossless_transport/human_base_main_body_mobile_sheet_a_whole_body.lossless.webp` | 194,300 | `2ceb9f620963b27c399580cca7386d57f6486b2a` | `53759cd289d85358533149f6ebcc5e48d8d62d5aae108587778dcd3de2b19f95` | GENERATED_IGNORED; derived transport for retained Prompt 2C whole-body PNG evidence |
| `.tmp/prompt2c_lossless_transport/human_base_main_body_mobile_sheet_b_topology.lossless.webp` | 962,116 | `ab932575ab15a82de534b9cef5d674cef7087c74` | `8b096a483ad65b4a08896c9bce818c3d8abfdcbaac97ca8898b503623552b093` | GENERATED_IGNORED; derived transport for retained Prompt 2C topology PNG evidence |
| `.tmp/prompt2c_lossless_transport/human_base_main_body_mobile_sheet_c_anatomy.lossless.webp` | 696,346 | `f322d5f69f10389630ae3fb22dd9252b4f81e80e` | `d4439f269cc7b4ed5c9b52c99974ceb073c82480e1c55e20b9f0534f3bdf9df3` | GENERATED_IGNORED; derived transport for retained Prompt 2C anatomy PNG evidence |
| `.tmp/prompt2c_lossless_transport/human_base_main_body_owner_review_contact_sheet.lossless.webp` | 540,870 | `e9b77822f5edb98b851090fbef14bc4ef8b981ed` | `171a714a5f18a1aa6f6c9c219646213072e778ac42f8ce43d3f4a35b43fcf8df` | GENERATED_IGNORED; derived transport for retained owner-review PNG evidence |
| `.tmp/prompt2c_lossless_transport/test_bgra.lossless.webp` | 194,300 | `2ceb9f620963b27c399580cca7386d57f6486b2a` | `53759cd289d85358533149f6ebcc5e48d8d62d5aae108587778dcd3de2b19f95` | GENERATED_IGNORED; duplicate codec probe, identical to sheet A |
| `.tmp/prompt2c_lossless_transport/test_optimized.png` | 203,959 | `88611f549a3299f635aa92abec7a399a47abc222` | `8aee1ca5ed6032680e863d79f06e4f4ac8de30b1b113b1ee4c9f9ec013eeb5fc` | GENERATED_IGNORED; unreferenced codec optimization probe with no authority role |

These files total 2,791,891 bytes and were introduced by commit
`58a72005a94c49660b96f94cc54be75f37ad65e9` on 2026-08-11.

### Generated Python bytecode

All three files carry CPython bytecode magic and have zero live inbound
references. They are interpreter-version-specific caches, not intentional
binary fixtures.

| Repository-relative path | Bytes | Git blob | SHA-256 | Classification and source disposition |
|---|---:|---|---|---|
| `tools/hm08_adoption/__pycache__/adoption.cpython-313.pyc` | 69,796 | `4565c8e869a0d048426e97d4aaaec559c63771cf` | `38cb9183752ee1305ba6ced3f383546dd00120e86e858cc28230c1a04cf3c3c5` | GENERATED_IGNORED; Python 3.13 cache. Its original `adoption.py` was never tracked; current adoption evidence uses retained `render_hm08_adoption_evidence.py` and `qualification.py`. The exact cache blob remains in Git history but is not authority. |
| `tools/hm08_qualification/__pycache__/qualification.cpython-311.pyc` | 102,160 | `04f7ef74903bb9e2e148a3ce65c0edc182968b7d` | `08250ddd1ae8198a8c820119263e9644fb95a80ea60cef2eac6acc784d30f941` | GENERATED_IGNORED; Python 3.11 cache generated from retained `tools/hm08_qualification/qualification.py` |
| `tools/hm08_qualification/__pycache__/qualification.cpython-313.pyc` | 84,149 | `5333f1406169e003d1a08063f24f73684a69a300` | `473f5ee0f467503af10ea38518a48f9b7c343b042d13b38952673de5b09c4e90` | GENERATED_IGNORED; Python 3.13 cache generated from retained `tools/hm08_qualification/qualification.py` |

These files total 256,105 bytes and were introduced by commit
`58a72005a94c49660b96f94cc54be75f37ad65e9` on 2026-08-11.

### Obsolete Git helper

| Repository-relative path | Bytes | Git blob | SHA-256 | Classification and reference disposition |
|---|---:|---|---|---|
| `tools/git-checkpoing.ps1` | 2,238 | `2cc2d1fdd82a8acf7ed8cc89e411df374c220407` | `b3b015af1e895a66324ff7374bb3818832ba168f23551f9f30bc8294790a793d` | OBSOLETE_APPROVED_FOR_REMOVAL; generic stage/commit/push wrapper with accidental `checkpoing` spelling and no engine-specific behavior or live caller |

The helper was introduced by commit
`7e6404c2137ac2446f840f80fc324e555a81c4f8` on 2026-07-29. Searches for
`git-checkpoing`, `checkpoing`, `Invoke-Git` and `NoPush` found no consumer;
the only external mention is F4A-OD-014 authorizing this removal. Its internal
function names occur only inside the script.

## 4. Pre-deletion reference disposition

- Exact `.tmp` paths and basenames: zero inbound references.
- `.tmp/` and `prompt2c_lossless_transport`: zero repository references.
- Exact `.pyc` paths and basenames: zero inbound references.
- `__pycache__`: zero repository references.
- `.pyc`: one policy mention in the F4A audit; no runtime/tool consumer.
- Git-helper path/spelling: one F4A authorization mention; no invocation.
- Unique helper symbols: self-references only.

The reference evidence confirms that deletion does not require source, test,
build, documentation-history or workflow repair.

## 5. Files deleted

Only these approved paths were deleted:

- `.tmp/prompt2c_lossless_transport/human_base_main_body_mobile_sheet_a_whole_body.lossless.webp`
- `.tmp/prompt2c_lossless_transport/human_base_main_body_mobile_sheet_b_topology.lossless.webp`
- `.tmp/prompt2c_lossless_transport/human_base_main_body_mobile_sheet_c_anatomy.lossless.webp`
- `.tmp/prompt2c_lossless_transport/human_base_main_body_owner_review_contact_sheet.lossless.webp`
- `.tmp/prompt2c_lossless_transport/test_bgra.lossless.webp`
- `.tmp/prompt2c_lossless_transport/test_optimized.png`
- `tools/hm08_adoption/__pycache__/adoption.cpython-313.pyc`
- `tools/hm08_qualification/__pycache__/qualification.cpython-311.pyc`
- `tools/hm08_qualification/__pycache__/qualification.cpython-313.pyc`
- `tools/git-checkpoing.ps1`

No parent directory was recursively removed. No other tracked file was
deleted.

## 6. Ignore rules

The repository `.gitignore` now contains:

```gitignore
.tmp/
__pycache__/
*.py[cod]
```

`.tmp/` is anchored by its slash and names only the repository-root temporary
tree. `__pycache__/` and `*.py[cod]` cover conventional Python bytecode/cache
artifacts without ignoring Python sources, canonical data, fixtures, evidence
or general generated outputs.

`git check-ignore -v --no-index` resolved all three representative paths to
the intended rules without creating probe files:

- `.tmp/f4b1_probe.tmp` -> `.tmp/`;
- `some_package/__pycache__/module.cpython-316.pyc` -> `__pycache__/`; and
- `some_package/module.pyc` -> `*.py[cod]`.

## 7. Retention policy

F4B1 creates the current
[Repository Retention Policy](../project/REPOSITORY_RETENTION.md). It defines
`ACTIVE_PRODUCTION`, `ACTIVE_TEST_REGRESSION`, `PROTECTED_AUTHORITY`,
`ACTIVE_AUTHORING_OR_VALIDATION`, `HISTORICAL_PROVENANCE`,
`ARCHIVE_CANDIDATE`, `GENERATED_IGNORED` and
`OBSOLETE_APPROVED_FOR_REMOVAL`.

Future retirement requires a path-specific record answering ownership,
references, production behavior, regression value, authority, hash/version
sensitivity, reproducibility, replacement, preserved provenance and the exact
owner-reviewed F4 authorization. Classification alone never authorizes
deletion.

## 8. Repository delta

| Measure | Before | F4B1 candidate |
|---|---:|---:|
| Tracked files after the candidate is committed | 905 | 897 |
| Tracked repository content | 804,106,076 bytes | 801,073,019 bytes / 764.0 MiB |

Ten tracked files totaling 3,050,234 bytes were removed. Two documentation
records were added; `.gitignore` and `docs/project/CURRENT_STATE.md` were
modified. The size reduction is informational and did not drive additional
cleanup.

## 9. Post-deletion reference and artifact checks

- `git ls-files .tmp`: zero paths.
- `git ls-files '*.pyc'`: zero paths.
- Tracked `__pycache__` content: zero paths.
- `git ls-files tools/git-checkpoing.ps1`: zero paths.
- Removed `.tmp` basenames/paths: present only in this historical deletion
  record.
- Removed `.pyc` basenames/paths: present only in this historical deletion
  record.
- `git-checkpoing.ps1`: present only in this deletion record and the F4A
  authorization record.
- No build, source, test, tool or active workflow reference became dangling.

## 10. Validation

All required gates were run against the deletion candidate:

| Gate | Result |
|---|---|
| `git check-ignore -v --no-index` representative paths | PASS; all three paths matched their intended rule |
| Post-deletion tracked-artifact and reference scans | PASS; no live consumer or tracked generated candidate remains |
| `tools/check_documentation.ps1` | PASS |
| `zig build -j1 --summary all` with isolated F4B1 caches | PASS, 20/20 steps |
| `zig build check -j1 --summary all` with isolated F4B1 caches | PASS, 53/53 steps and 518/518 tests |
| `zig build test-full -j1 --summary all` with isolated F4B1 caches | PASS, 60/60 steps and 629/629 tests |
| `git diff --check` | PASS |

The first sandboxed normal-build attempt reached Zig's known Windows cache
`manifest_create AccessDenied` condition. The identical command passed outside
the sandbox using repository-local `.zig-cache/f4b1` and
`.zig-cache/f4b1-global` paths. This was an environment permission issue, not a
missing-file or product failure.

GPU smoke was not required because no GPU/runtime implementation changed.

## 11. Unexpected finding

`adoption.cpython-313.pyc` contains generated bytecode for an
`tools/hm08_adoption/adoption.py` source path that was never tracked. This does
not contradict its generated-cache classification: nothing consumes the
bytecode, the current adoption evidence route uses retained source tools, the
accepted canonical outputs/evidence remain unchanged, and interpreter cache
files are not durable source authority. The exact deleted blob remains in Git
history. No attempt was made to reconstruct or adopt its embedded logic.

## 12. Scope attestation

- No production Zig source changed.
- No demo changed or was deleted.
- No test changed or was deleted.
- No build logic changed.
- No renderer or application architecture changed.
- No evidence family was archived or deleted beyond the six approved `.tmp`
  staging/transport outputs.
- No canonical model, canonical geometry, topology, hash, asset ID or source
  authority changed.
- No asset or prompt-era production name changed.
- No accepted F contract changed.
- F4B2 and F4C did not begin.
- No downstream feature track began.

F4B1 stops at this owner-review candidate. It does not accept itself and does
not authorize F4B2.
