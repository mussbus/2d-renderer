# Prompt Ledger

This ledger distinguishes exact prompt sources from reconstructed milestone records. Exact sources are byte-preserved under [`exact/`](exact/README.md). Reconstructed records are evidence-based summaries and are never presented as original wording.

| ID | Milestone | Implementation status | Source status | Record | Commit |
|---|---|---|---|---|---|
| 0 | Architecture and engineering contract | complete | reconstructed | [Prompts 0–22 ledger](000-022-reconstructed-ledger.md#prompt-0) | `3df0ace` |
| 1 | SDL3 GPU bootstrap and smoke validation | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-1) | `cba01a6` |
| 2 | Instanced sprite batching | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-2) | `2c4dcec` |
| 3 | Hierarchical humanoid skeleton | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-3) | `44db24d` |
| 4 | Skeletal animation | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-4) | `70be8a7` |
| 5 | Fixed-step controller and collision | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-5) | `8490b29` |
| 6 | Procedural secondary motion | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-6) | `93d4d13` |
| 7 | Multi-character ownership and global ordering | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-7) | `f936311` |
| 8 | Synchronized handshake interaction | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-8) | `f936311` |
| 9 | Handshake arm IK | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-9) | `f936311` |
| 10 | Foot planting and leg IK | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-10) | `f936311` |
| 11 | Integrated demo and diagnostics | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-11) | `f936311` |
| 12 | Adversarial production-readiness audit | complete with known limitations | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-12) | `f936311` |
| 13 | Production input and interactive playground | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-13) | `611d54f` |
| 14 | Resizable camera and side-scrolling world | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-14) | `7f56f23` |
| 15 | Generalized character visuals and rig modules | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-15) | `c3ce753` |
| 16 | Modular anatomy, morphology, face, and hair | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-16) | `ddd6e36` |
| 17 | Topology-aware equipment and loadouts | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-17) | `74a4e4b` |
| 18 | Breathing and shared deformation | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-18) | `0a6cb3a` |
| 19 | Deformable mesh attachments and unified ordering | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-19) | `90e36e7` |
| 20 | Attachment secondary motion | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-20) | `3cf06f1` |
| 21 | Character properties and capabilities | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-21) | `3cf06f1` |
| 22 | Character + World Foundation Playground | complete | reconstructed | [ledger](000-022-reconstructed-ledger.md#prompt-22) | `3cf06f1` |
| 23 | Real art pipeline | complete | exact | [record](023-real-art-pipeline.md) · [source](exact/023-source.txt) | `0d6a0b9` |
| 24 | Front/side character presentation | complete; later corrected | exact | [record](024-character-presentation.md) · [source](exact/024-source.txt) | `0d6a0b9` |
| 24A | Anatomy/clothing boundary correction | complete | exact | [record](024A-character-art-boundary.md) · [source](exact/024A-source.txt) | `4937122` lineage |
| 25 | Modular wardrobe | complete; later corrected | exact | [record](025-wardrobe.md) · [source](exact/025-source.txt) | `0d6a0b9` |
| 25A | Visual-quality correction/gate | superseded by 25B–25D | exact | [record](025A-visual-quality-correction.md) · [source](exact/025A-source.txt) | `4937122` lineage |
| 25B | Fix character art, not tests | superseded by 25C/25D | exact | [record](025B-character-art-correction.md) · [source](exact/025B-source.txt) | `4937122` |
| 25C | Semantic visual-geometry validator | complete measuring instrument | exact | [record](025C-visual-geometry-validator.md) · [source](exact/025C-source.txt) | `7ba3687` lineage |
| 25D | Production geometry closure | complete and accepted | exact | [record](025D-production-geometry-closure.md) · [source](exact/025D-source.txt) | `7ba3687` |
| 25E | Consolidation and authoring contracts | complete | exact | [record](025E-consolidation.md) · [source](exact/025E-source.txt) | `e328ec0` |
| 26 | Environment themes | complete | exact roadmap source | [record](026-environments.md) · [source](exact/026-source.txt) | `0dd0f21` |
| 27 | Integrated visual foundation | automated complete; manual review reopened | exact roadmap source | [record](027-integrated-foundation.md) · [source](exact/027-source.txt) | `1de0d1d` |
| 27A | Evidence integrity and owner-review harness | automated complete; owner review pending | exact user-supplied roadmap | [record](027A-evidence-integrity.md) · [source](../../prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md) | worktree on `7c4721a` |
| 27B | Ground contact, framing, parallax, and presence | automated complete; owner review pending | exact user-supplied roadmap | [record](027B-ground-contact-camera-parallax-presence.md) · [source](../../prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md) | worktree on `0e29e0c` |
| 27C | Production anatomy silhouette, proportion, and joint continuity | torso result owner-rejected; superseded by 27C-R1 | exact user-supplied roadmap | [record](027C-production-anatomy.md) · [source](../../prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md) | worktree on `3259f79` |
| 27C-R1 | Owner-rejected torso and interactive presence crash | automated corrective pass complete; owner review pending | copied exact user request | [record](027C-R1-owner-rejected-torso-presence.md) | worktree on `3259f79` |

## Evidence and reports

- The report archive index is [`../reports/prompt-implementation-reports/INDEX.md`](../reports/prompt-implementation-reports/INDEX.md).
- Existing topic documents remain authoritative for detailed subsystem design; this ledger links rather than rewrites them.
- The original combined Prompt 23–27 roadmap is preserved as [`exact/023-027-roadmap-source.txt`](exact/023-027-roadmap-source.txt).
- The user-supplied Prompt 27A–27H reopened visual-foundation roadmap is
  preserved as
  [`../../prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md`](../../prompts/Prompts_27A_27H_Reopened_Visual_Foundation.md);
  Prompts 27A and 27B are implemented; Prompt 27C's rejected torso result is
  superseded by the bounded 27C-R1 corrective pass. Prompt 27D and later work
  has not started.
