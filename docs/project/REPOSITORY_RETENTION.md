# Repository Retention Policy

Status: Current normative F4 retention policy

Effective date: 2026-08-29

Authority: Owner-approved F4A decisions, especially F4A-OD-003,
F4A-OD-004, F4A-OD-010, F4A-OD-011, F4A-OD-013 and F4A-OD-014

## Purpose

Repository age, prompt numbering, file size, low textual reference count and
apparent supersession are not deletion authority. This policy classifies
first-party repository material and defines the evidence required before a
later F4 phase may retire it.

F4B1 applies this policy only to its explicitly approved generated/staging
artifacts, Python bytecode and obsolete Git helper. All other retirement still
requires a dedicated owner-reviewed decision.

## Retention classifications

### ACTIVE_PRODUCTION

Production source, runtime data, shaders, application behavior or other
content required by a supported engine/runtime route. Removal requires an
approved production migration and regression proof.

### ACTIVE_TEST_REGRESSION

Fixtures, goldens, tests and support data that protect a current invariant or
failure mode. Removal requires equivalent named replacement coverage and proof
that the old artifact no longer adds unique regression value.

### PROTECTED_AUTHORITY

Canonical, versioned or hash-sensitive source/evidence whose identity,
lineage or reproducibility must remain intact. Ordinary cleanup may not modify,
rename, relocate or remove it. Any migration requires explicit version/hash/
identity handling and owner approval.

### ACTIVE_AUTHORING_OR_VALIDATION

Current content authoring, qualification, export, validation, diagnostic or
report infrastructure. It may belong outside the fast engine gate while still
remaining active and required.

### HISTORICAL_PROVENANCE

Material retained to explain an accepted decision, rejected result, migration
or historical milestone even though normal engine operation does not consume
it. It may later move to an intentional history/archive boundary.

### ARCHIVE_CANDIDATE

Material that may leave the active repository only after its manifest, hash,
authority, reproducibility, replacement and archive requirements are met.
This classification does not authorize deletion.

### GENERATED_IGNORED

Reproducible or disposable local output that should not be tracked. Examples
include Python bytecode and repository-root `.tmp/` transport/staging output.
Generated output is not automatically disposable when it is an intentional
fixture, golden, canonical artifact or accepted evidence.

### OBSOLETE_APPROVED_FOR_REMOVAL

Material independently confirmed unnecessary and explicitly approved for
removal by an owner-reviewed F4 phase. The approving implementation record
must preserve the pre-deletion path, hash, size, references and rationale.

## Raw-byte identity and checkout policy

Historical raw-byte identity means the originally accepted captured byte stream,
not normalized textual equivalence. Immutable CRLF or mixed-ending captures
must be stored without Git text conversion through scoped `-text` attributes.
Existing accepted hashes may not be changed to fit normalized blobs or a local
checkout. Active source/current canonical structured inputs remain deterministic
LF text; an old directory name does not make current authority historical.

The 2026-09-06 owner decision establishes ten new individual raw SHA-256/size
authorities in the existing [history manifest](../../assets/history/manifest.json).
They previously had accepted family inventory sizes but no individual hash
authorities. Untouched clean-master bytes and exact normalized equivalence to
baseline Git blobs supported this prospective decision; it is not retroactive
evidence. It authorizes no additional artifact or change to an earlier hash.
The [reproducibility report](../implementation/reproducible_windows_checkouts.md)
records each path, old blob, new authority and verification. Repository checks
consume those entries. This policy grants no deletion or future restoration
authority without corresponding provenance and owner scope.

## Future retirement manifest rule

No demo, test, evidence family, asset family, canonical-lineage artifact,
historical package, tool or other first-party path may be removed merely
because it looks old. Its retirement record must answer all of the following:

1. What is it?
2. What currently references it?
3. Does it own production behavior?
4. Does it provide unique regression coverage?
5. Is it authoritative source material?
6. Is it hash/version sensitive?
7. Can it be reproduced?
8. What replaces its behavior or coverage?
9. What provenance remains after deletion?
10. Which owner-reviewed F4 decision authorizes removal?

The record must classify ambiguous findings conservatively. A missing answer,
unresolved authority claim or unknown consumer blocks retirement.

## Deletion and archive rules

- Use the narrowest exact path set approved by the owner.
- Re-run inbound-reference checks before and after removal.
- Preserve hashes and sizes before deletion; do not duplicate disposable bytes
  into a new tracked archive solely to perform cleanup.
- Git history is adequate provenance only for material already classified as
  disposable or obsolete. It is not a substitute for active source authority,
  canonical reproducibility, unique regression coverage or a promised archive.
- `ARCHIVE_CANDIDATE` and `HISTORICAL_PROVENANCE` are retention states, not
  deletion permissions.
- A failed build, test, documentation or reference gate invalidates the
  presumed low-risk classification until the dependency is understood.

## F4B1 application

The first application of this policy is recorded in
[F4B1 Safe Hygiene and Retention](../implementation/f4b1_safe_hygiene_and_retention.md).
That record removes only the F4A-OD-014 set. It neither classifies nor retires
the broader demo, test, evidence, canonical or asset families audited by F4A.
