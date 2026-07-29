# Prompt 27B — Ground Contact, Camera Framing, Parallax Evidence, and Character Presence

- Status: **automated and evidence-integrity complete; owner review pending**.
- Source:
  [`../../prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md`](../../prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md).
- Baseline: Prompt 27A state on
  `0e29e0cbf9644a4284ab791c2bed6dcc366acabf`.
- Objective delivered: one fail-closed measurement chain spanning supporting
  collider, post-IK anatomical sole, alpha-derived submitted footwear sole,
  production camera, render ordering, and D3D12 pixels; safe camera framing;
  measured far/mid/gameplay parallax; and non-teleport scripted character
  presence.
- Runtime authority: the existing fixed-step controller, collision world,
  skeleton/IK, `Camera2D`, environment scene, `UnifiedRenderQueue`, and SDL3
  GPU D3D12/DXIL renderer remain authoritative.
- Character-art boundary: no anatomy, garment, footwear, or atlas art was
  reauthored. Submission traces expose actual queue indices so only rendered
  visual records receive the bounded ground-contact correction.
- Presence boundary: the scripted partner uses normal controller input to
  walk clear and return. A visible-bounds detector rejects uncontrolled
  overlap. General interactive dynamic character collision remains deferred.
- Automated evidence: 9,714 semantic metrics and 55 independent D3D12 pixel
  metrics pass with zero failures. The additive direct 960×540-to-640×480
  fixture validates its first post-resize projection and keeps subsequent
  camera motion under the unchanged 16 px limit. Two semantic runs and two
  isolated D3D12 runs repeat identically.
- Preservation: 314 pre-Prompt-27B Prompt 27/27A evidence files remain
  present and hash-identical. Rejected Prompt 27B development candidates are
  retained.
- Review boundary: clean/debug captures are candidates, not approved goldens.
  Prompt 27A and Prompt 27B owner/manual visual acceptance remain
  `[PENDING OWNER REVIEW]`.
- Decision record:
  [`../PROMPT27B_DECISION_RECORD.md`](../PROMPT27B_DECISION_RECORD.md).
- Tests:
  [`../TESTING.md#prompt-27b-contact-framing-parallax-and-presence`](../TESTING.md#prompt-27b-contact-framing-parallax-and-presence).
- Scope boundary: Prompt 27C and Prompt 28 were not started.
