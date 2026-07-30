# VF-01 Decision Record — Visual Truth Debugger and Manual Capture Bundles

## Status

Implemented for automated inspection. Manual visual acceptance remains
`[PENDING OWNER REVIEW]`.

## Scope boundary

VF-01 observes existing production authority. It does not reauthor anatomy,
face, hair, garments, animation, locomotion, interaction, camera, collision,
or source atlases. VF-02, VF-03, and Prompt 28 were not started.

## Authority chain

The debugger records, without feeding back into:

1. authoritative controller root and collider;
2. canonical skeleton and sockets;
3. the exact view projection used by production presentation;
4. existing appearance/anatomy/module topology;
5. atlas region, alpha-visible bounds, and landmarks;
6. actual final sprite/mesh trace and queue submission identity.

`character_art.Presentation.projectionFor` is the shared projection boundary.
There is no debug-only transform formula.

## F1 and reset

F1 cycles:

```text
Off
→ Rig
→ Rig + Visual Registration
→ All Diagnostics
→ Off
```

Reset preserves the selected mode so inspection does not disappear. The
mode is frame presentation state and cannot enter gameplay intent.

## Fixed capacities and ownership

The complete production All Diagnostics frame overflowed the former
512-command buffer at command 513. The fixed capacity is therefore 2,048.
Overflow remains an explicit error. The buffer, alpha catalog, and truth
snapshot are initialization-owned diagnostic resources. Moving the enlarged
buffer and foundation scene to explicit heap ownership prevents the Windows
main-stack overflow observed by the real executable without adding
steady-state allocation.

## Category colors

- physics root/collider: red;
- canonical skeleton: yellow;
- projected skeleton: cyan;
- sockets/attachments: green;
- module joints/sockets: purple;
- pivots: orange;
- atlas landmarks: white;
- alpha-visible bounds: blue;
- passing clothing/hair anchor links: teal;
- mismatch/error links: magenta.

## F4 atomicity and identity

F4 is a one-shot frame diagnostic edge. The clean image is read from the
prepared production queue. The debug image is built from the same frozen
snapshot with All Diagnostics. No fixed tick occurs between them.
Finalization requires equality of render frame, simulation tick, live
authoritative state, authoritative snapshot, presentation snapshot, and
capture fingerprint.

Bundles are first written as hidden `.incomplete` directories. Required PNGs
are validated, JSON and summary are written, file and source-atlas SHA-256
values are calculated, hashes are re-read, and only then is the directory
renamed with preserve semantics. Final directories use UTC plus a global
monotonic counter. Existing deterministic automated evidence names remain
untimestamped.

## Allocation boundary

Normal F1 execution has no image decode, file I/O, allocation, or persistent
GPU creation after stabilization. Explicit F4 capture may use bounded
diagnostic file/process/hash allocations outside the fixed-tick simulation
path.

## Current-art finding

A fresh current-art Prompt 27B report contains 9,714 metrics and 24
front-foot endpoint-height failures at `-13.645128 px` and `+13.645128 px`.
The preserved older zero-failure Prompt 27B report is historical evidence
only and is not current-art proof. VF-01 reports rather than corrects these
and other registration disagreements.

