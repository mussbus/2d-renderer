# Prompt 27 — Integrated Visual Foundation, View-Aware Interaction Presentation, and Final Art/Gameplay Acceptance

- Status: **automated integration complete; manual visual acceptance reopened
  by Prompt 27A**.
- Source: **exact roadmap text** — [`exact/027-source.txt`](exact/027-source.txt).
- Objective delivered: one production `foundation` route proving that accepted
  character, wardrobe, environment, animation, physics, and interaction
  presentation operate together through the established runtime and renderer.
- Major systems: `visual_foundation.Scene`; definition-owned per-role
  interaction views, automatic-view suppression, and typed occlusion profile;
  participant-qualified equipment ordering; interaction-aware side-arm
  projection; combined fixed-root handshake, traversal, theme, outfit, reset,
  resource, and visual acceptance.
- Major runtime files:
  [`../../src/scene/visual_foundation.zig`](../../src/scene/visual_foundation.zig),
  [`../../src/interaction/interaction.zig`](../../src/interaction/interaction.zig),
  [`../../src/interaction/interaction_system.zig`](../../src/interaction/interaction_system.zig),
  [`../../src/interaction/handshake.zig`](../../src/interaction/handshake.zig),
  [`../../src/scene/presentation_pose.zig`](../../src/scene/presentation_pose.zig),
  and
  [`../../src/scene/wardrobe_presentation.zig`](../../src/scene/wardrobe_presentation.zig).
- Major test/documentation files:
  [`../../tests/visual_foundation_tests.zig`](../../tests/visual_foundation_tests.zig),
  [`../ARCHITECTURE.md`](../ARCHITECTURE.md),
  [`../INTERACTIONS.md`](../INTERACTIONS.md), and
  [`../PROMPT27_DECISION_RECORD.md`](../PROMPT27_DECISION_RECORD.md).
- Tests/evidence: `test-visual-foundation` passes 3/3. The 2,100-frame real
  D3D12/DXIL route completes three data-declared side-view handshakes across
  the required outfits and both themes, writes nine captures under
  `zig-out/p27_visual_foundation`, and reports zero post-stabilization update,
  submission, queue, or GPU-resource growth. The aggregate Prompt 0–27 gate
  passes 356/356 tests in Debug and ReleaseFast.
- Implementation report: no verbatim completion message is archived; current
  evidence is indexed in
  [the report archive](../reports/prompt-implementation-reports/INDEX.md#prompt-27).
- Commit: `1de0d1d`.
- Dependencies: accepted Prompt 0–26 systems and art.
- Known limitations: the production handshake remains one fixed-root,
  one-contact interaction; front/front behavior is a validated definition
  proof rather than a second authored visible interaction; Prompt 27 is an
  integrated foundation acceptance route, not a beginning-to-completion game
  loop.
- Scope boundary: Prompt 28 or other later work was not started.

## Prompt 27A follow-on

Prompt 27A does not replace the integrated runtime. It preserves this
milestone's nine original captures and report as historical evidence, while
replacing phase/frame-selected review captures with a 16-case
state-conditioned matrix, per-capture semantic metadata, a bounded same-queue
HUD, deterministic PNG/contact-sheet tooling, and repeatability comparison.
See [`027A-evidence-integrity.md`](027A-evidence-integrity.md). Owner visual
acceptance is `[PENDING OWNER REVIEW]`.

## Prompt 27B follow-on

Prompt 27B preserves Prompt 27A evidence and adds measured production
ground-contact, collision-derived white-edge ordering, camera safe framing,
actual parallax displacement, and scripted character-presence validation.
The real foundation route remains the only composition root and D3D12
renderer. It changes no anatomy/garment art, locomotion clip, or handshake
definition. See
[`027B-ground-contact-camera-parallax-presence.md`](027B-ground-contact-camera-parallax-presence.md).
Owner/manual acceptance remains `[PENDING OWNER REVIEW]`.
