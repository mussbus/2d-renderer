# Reproducible Windows checkouts (unnumbered repository correction)

Status: mechanics validated in a fresh detached Windows checkout; documentation reconciliation candidate for owner review. This work changes repository integrity and status records only. No gameplay, human, editor or roadmap milestone is advanced.

## Root cause and decision

At baseline `d71c4ae439d0b04019734cd3f45b7a6366a6a00f`, system `core.autocrlf=true` and absent repository attributes produced checkout-dependent validation. A new Windows worktree failed formatting on 279 Zig/ZON paths, the documentation check on 12 exact hashes, and content qualification: 50/60 steps succeeded, eight steps failed, 269 tests passed, ten failed, zero skipped. The complete audit classified 393 failing or implicated paths among 1,004 tracked files. The existing 282 Zig blobs and one ZON blob were already LF.

Active source and current canonical structured text use deterministic LF checkout bytes. Immutable retained captures preserve accepted raw byte streams under targeted `-text` exceptions. PNG, P6 PPM and ZIP files are binary; PPM can lack NUL bytes and must not be detected as text. Ordinary documentation remains text. No universal `* text` rule or repository-wide renormalization is used.

## Prospective owner authority, 2026-09-06

The ten geometry artifacts below had accepted family inventory sizes but no prior individual SHA-256 authority. The initial audit stopped for that reason. Through an explicit continuation decision the owner established exactly these ten measured hashes as new raw-byte restoration authorities. The original clean master supplied their CRLF byte streams, whose normalized bytes equal the committed baseline blobs exactly. Cross-worktree comparisons agreed wherever the same content and raw form existed. This is a prospective decision, not retroactive evidence or discovery of prior individual hash authorities.

The existing [history manifest](../../assets/history/manifest.json) is extended with `raw_byte_integrity`: references to pre-existing authorities, plus a separate dated/baselined owner-established decision and ten path/hash/size entries. Existing families, inventory sizes and binary hash arrays remain unchanged. Each entry retains its old Git object, old blob SHA-256, accepted family size and provenance. The initial audit report SHA-256 identifies the preserved local report used in the owner decision. No additional artifact gains a new restoration authority.

| Newly owner-authorized path | Raw SHA-256 | Raw bytes | Pre-correction blob SHA-256 |
| --- | --- | ---: | --- |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c/mobile_text_exports/human_base_main_body_mobile_sheet_a_whole_body.png.base64.txt` | `325104f7f2857752e885516a50ecdf6f20b22bcab536827728e7b7ba2d7f2a16` | 368888 | `207ba472b4a9fb177e132fd32bbf3c6c8444ee9d8fcc75c542762645920a697f` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c/mobile_text_exports/human_base_main_body_mobile_sheet_b_topology.png.base64.txt` | `2f9a6b81fbad7619192d30f6040ebe105f053daac2accdf31a9986fd34f28fae` | 2294190 | `d8c1e682b4c43cf7b657afd2acd79b191b9f6150812613d20a065fa7540e4585` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c/mobile_text_exports/human_base_main_body_mobile_sheet_c_anatomy.png.base64.txt` | `d58277585df8f5f0ee8cd5f971a6784165d2a99409b982ac35360f5454745b0b` | 1538530 | `b77605d7c48732338e2e3e080adef70b46513fadf95aed5423f7d001af4f9110` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c/mobile_text_exports/human_base_main_body_owner_review_contact_sheet.png.base64.txt` | `766daf6ad7ac7d08bd782fb8cc0c93dd7772f34885fcb4cd1296e0ba4e3a9bff` | 1393902 | `dd06d78fa64b7220132523190e1dc7b3feaa51802e6bf114efd79b8b53f5fff0` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation/human_base_main_body_r3_adaptation.json` | `5130293639d99fba83ffd9de328e5a29d71d897c033ab64acfff6cf67f92960c` | 1775 | `9940ac45abcf184f86222ac01c449903f36e3a978f287830a592c77ffdc64ee6` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation/human_base_main_body_r3_self_intersection.json` | `885935cfc8f4d207c6ef1192cf936297a4f4cc3563a149b9a01049db9947cf18` | 154 | `c0bf54f66cbf6e522c578cdde82ace64696460c458956ee0319e5161ce9a1401` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/hm08.provenance.json` | `f1372b446c2b88b1cb3b6748bf7d2afb007abd6131cbb1ad78663ee9dce8e141` | 2833 | `3e7a2a2fa24ddf5fc5903b910fdb338526d8816c84a6a076937644cec26457bf` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/hm08.qualification_metrics.json` | `83709b750bf50ee0bebb872a7ed5ae166ab9f9b59764a57cd3ff503f3d27e2ad` | 119644 | `e202424a7bf3bbc38a2e4c711f6d3f1e8c23c1f45221103c2339dcb3adc0b8bb` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/hm08.seam_candidates.json` | `2e768b3a59c796c1c10deba4959a327730a928fdb9d5d024c9917c651c14f93d` | 10836 | `494e7a5f862b145b489b0f07cafa5244023ffe6376cac6495e92f273fb3d64d8` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/hm08.visual_index.json` | `21a2351e9c8c934e2bb7572b1112b117c9c6225fb5e2b711b28d5455ed0dcdf3` | 3008 | `053e8f75b03e1cac331d6b491d5f5594bd3ba7bd1eaec7eed6b5fa52f95ed2da` |

All ten restorations satisfy exact raw size/hash and CRLF-to-LF equality with the old blob. There is no textual, numeric, structural, ordering or other whitespace change. Binary reads/writes preserve their bytes; none was reconstructed.

## Attribute boundaries and restored blobs

Root [.gitattributes](../../.gitattributes) defines LF for Zig/ZON, scripts, HLSL, JSON, Markdown, plain text, TSV and textual OBJ, then overrides only exact captured documents and the six retained historical geometry packages. Current geometry authoring JSON, human structural reports, parser fixtures and the active R4 package remain canonical text. Retained Effects/Projectiles history uses its existing raw capture hashes. Binary formats remain binary.

Exactly 28 existing historical artifact blobs are restored: 18 exact prompt/report artifacts (eight CRLF and ten mixed ending streams) to their pre-existing accepted hashes, and the ten newly owner-authorized geometry streams. The other two protected document blobs were already correct. No source or active canonical blob changes. Existing exact document expectations in check_documentation.ps1 and capture hashes in Effects/Projectiles validation.json are unchanged.

| Restored artifact | Authority | Raw bytes | Raw SHA-256 |
| --- | --- | ---: | --- |
| `docs/history/prompts/exact/023-027-roadmap-source.txt` | pre_existing | 63521 | `9d8dde03c10c2b9b64e532896a025cac2144c6bf817c76d1b5c2f81874cc9cb8` |
| `docs/history/prompts/exact/023-source.txt` | pre_existing | 13323 | `3deabb54518313869c3e81d91b6b8848c6d156f1a42477b2d1d8c2a1920d97bd` |
| `docs/history/prompts/exact/024-source.txt` | pre_existing | 11177 | `366d96ddf9e43b8c1fb098cc1a6e7598cca47e4d6f5c369c773b49c2ebeb61b0` |
| `docs/history/prompts/exact/024A-source.txt` | pre_existing | 4620 | `42487e8bd09c86d6a693806a361d9c8ce477c8f1bbda4772e3d30b0f4ddc2d7a` |
| `docs/history/prompts/exact/025-source.txt` | pre_existing | 11128 | `4090101f2ce3399dddbe34b406655affc4cd9f79d9c835cae16adeb442c0c39c` |
| `docs/history/prompts/exact/025B-source.txt` | pre_existing | 5530 | `fd57b8ed703816503956cd403bf67a5dcb507ffaf6a07593809b9a4be6ab4029` |
| `docs/history/prompts/exact/025C-source.txt` | pre_existing | 29364 | `354d810f85c3b20a9f2ba140b2c9e221ad6eddcf2970a8dde62674a94c3607fe` |
| `docs/history/prompts/exact/025D-source.txt` | pre_existing | 26755 | `8b114d87eb5b3c97c50bbecfd05cdbb7e79a3533d78b74b695f5bf218d05e7fb` |
| `docs/history/prompts/exact/026-source.txt` | pre_existing | 8709 | `e6e19c484fcd79d0ab8eea1030a1aa037c3a569a44abaf31ece3e3a4d5f1a532` |
| `docs/history/prompts/exact/027-source.txt` | pre_existing | 17128 | `66ce11018f66dbf004ad6a5723bad2d6c94fabb6f9b15b93b39ab893a5f610dd` |
| `docs/history/reports/prompt-implementation-reports/exact/023-implementation-report.md` | pre_existing | 9623 | `8a153a766f1b2b01bae7316c951fdfed98a3dac44cd19212868b6b1897d4042d` |
| `docs/history/reports/prompt-implementation-reports/exact/024-implementation-report.md` | pre_existing | 12484 | `6be2939ede3805c6d94600936ae42adfae494283d2d84bf92df1110b8cc3d6a3` |
| `docs/history/reports/prompt-implementation-reports/exact/024A-025-implementation-report.md` | pre_existing | 12463 | `958fdc0ae76c2fe96d0d0f476b109c3da043dfdf05eb9e3430307a6438410575` |
| `docs/history/reports/prompt-implementation-reports/exact/025A-implementation-report.md` | pre_existing | 13088 | `87220f1f14a2ef10d7794435c001599c3cdaec734e7fccfadd53a329a4ab5335` |
| `docs/history/reports/prompt-implementation-reports/exact/025B-final-visual-gate-report.md` | pre_existing | 6698 | `37261074658c10abdf2d95a829a746ed2628f39d5cf5bf6dc795f9124333f525` |
| `docs/history/reports/prompt-implementation-reports/exact/025B-implementation-report.md` | pre_existing | 8968 | `d41e28914733792216b441e52acdf233a1bb1e18b8f2904979ee779d5624996c` |
| `docs/history/reports/prompt-implementation-reports/exact/025C-implementation-report.md` | pre_existing | 12523 | `301feba6f46e4731305ec88d04fa5b815b6e3dcef1822395ac9bce8ec03741bb` |
| `docs/history/reports/prompt-implementation-reports/exact/025D-implementation-report.md` | pre_existing | 10142 | `ce5c11c8a95b53172038e3abdf6728d6979d5fa2650bbf20b7e4ab7c0add9a4a` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c/mobile_text_exports/human_base_main_body_mobile_sheet_a_whole_body.png.base64.txt` | new_owner_established | 368888 | `325104f7f2857752e885516a50ecdf6f20b22bcab536827728e7b7ba2d7f2a16` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c/mobile_text_exports/human_base_main_body_mobile_sheet_b_topology.png.base64.txt` | new_owner_established | 2294190 | `2f9a6b81fbad7619192d30f6040ebe105f053daac2accdf31a9986fd34f28fae` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c/mobile_text_exports/human_base_main_body_mobile_sheet_c_anatomy.png.base64.txt` | new_owner_established | 1538530 | `d58277585df8f5f0ee8cd5f971a6784165d2a99409b982ac35360f5454745b0b` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c/mobile_text_exports/human_base_main_body_owner_review_contact_sheet.png.base64.txt` | new_owner_established | 1393902 | `766daf6ad7ac7d08bd782fb8cc0c93dd7772f34885fcb4cd1296e0ba4e3a9bff` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation/human_base_main_body_r3_adaptation.json` | new_owner_established | 1775 | `5130293639d99fba83ffd9de328e5a29d71d897c033ab64acfff6cf67f92960c` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation/human_base_main_body_r3_self_intersection.json` | new_owner_established | 154 | `885935cfc8f4d207c6ef1192cf936297a4f4cc3563a149b9a01049db9947cf18` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/hm08.provenance.json` | new_owner_established | 2833 | `f1372b446c2b88b1cb3b6748bf7d2afb007abd6131cbb1ad78663ee9dce8e141` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/hm08.qualification_metrics.json` | new_owner_established | 119644 | `83709b750bf50ee0bebb872a7ed5ae166ab9f9b59764a57cd3ff503f3d27e2ad` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/hm08.seam_candidates.json` | new_owner_established | 10836 | `2e768b3a59c796c1c10deba4959a327730a928fdb9d5d024c9917c651c14f93d` |
| `assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/hm08.visual_index.json` | new_owner_established | 3008 | `21a2351e9c8c934e2bb7572b1112b117c9c6225fb5e2b711b28d5455ed0dcdf3` |

## Regression protection

[checkout_bytes.py](../../tools/checks/checkout_bytes.py) runs through the existing [repository check](../../tools/check_repository.ps1), and therefore check, test-full and verify. It checks index and working-tree attributes, LF source/structured bytes, raw index and checkout hashes for the 20 pre-existing exact document artifacts, 16 existing archived capture hashes, and the ten new owner-established authorities. It also validates the new sizes, provenance fields and normalized baseline content. It requires Git and Python but no network, GPU, fixed machine path or old working directory. The existing content gate continues checking all accepted family inventory totals.

`--index-only` supports staged-policy review in the original correction checkout. It is not used by routine gates or fresh acceptance. No existing test or expectation is weakened, skipped or replaced.

## Validation and remaining limits

Mechanics commit `cf094b617ae52be1031d8dde1fda310651c1d84e` was checked out into
a genuinely new detached worktree, `2d Renderer-reproducibility-policy-proof`.
All 1,007 tracked files matched their raw Git blobs immediately after checkout
and after all nineteen commands. System `core.autocrlf=true` remained unchanged;
no line-ending configuration override, tracked-file copy or post-checkout repair
was used. Only the existing pinned ignored `.deps` installation was shared by
junction. The checkout used its own `.zig-cache` and `.tmp/zig-global-cache`.

The new integrity audit passed 545 LF-classified paths, all 20 pre-existing
exact document hashes, 16 pre-existing archived capture hashes, and the ten
newly owner-established authorities. Content qualification reproduced every
existing family inventory size. Six deliberate faults in separate temporary
indexes were rejected before the mechanics commit: missing Zig attributes,
historical text conversion, active canonical misclassification, CRLF Zig blobs,
changed existing hashes, and changed new-authority hashes. The real index was
unchanged by these probes.

There are zero Zig/build/application/test blob changes. The existing repository
check gains one helper invocation; the new helper is repository validation only.
Attributes alone correct 643 previously converted working representations while
preserving those existing blobs. The large line count in the historical diff
is solely raw newline restoration; all 28 normalized comparisons pass. During
development Git rechecked out one unstaged malformed-PNG fixture under its binary
attribute, without changing or staging its blob. This occurred only in the
correction worktree; neither fresh proof checkout receives a byte workaround.
Frozen captures explicitly allow CR-at-EOL for Git diff checking while retaining
the other default whitespace checks.

The table below records observed policy-commit results. The final documentation
candidate receives the same full command sequence in a second new detached
worktree; its exact commit and results are recorded in the owner-facing delivery
report, without amending this history.

All five parallel foundations remain architecturally independent. PHY, Engine Lab, RR1, world/environment, 3D presentation, gameplay, representation bindings, EL2 and PSM02 integrations remain deferred or separately authorized. This correction does not renumber any milestone or alter feature behavior.

## Fresh policy-commit validation results

| Exact command | Exit | Steps | Passed tests |
| --- | ---: | --- | ---: |
| `.\.deps\zig-0.16.0\zig.exe version` | 0 | not a build-step summary | not reported |
| `.\.deps\zig-0.16.0\zig.exe fmt --check build.zig build.zig.zon build src tests` | 0 | not a build-step summary | not reported |
| `pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tools/check_documentation.ps1` | 0 | not a build-step summary | not reported |
| `.\.deps\zig-0.16.0\zig.exe build test-effects-projectiles test-record-replay test-psm01 test-world test-engine-lab -j1 --summary all` | 0 | Build Summary: 15/15 steps succeeded | 181 |
| `.\.deps\zig-0.16.0\zig.exe build test-effects-projectiles test-record-replay test-psm01 test-world test-engine-lab -Doptimize=ReleaseSafe -j1 --summary all` | 0 | Build Summary: 15/15 steps succeeded | 181 |
| `.\.deps\zig-0.16.0\zig.exe build test-effects-projectiles test-record-replay test-psm01 test-world test-engine-lab -Doptimize=ReleaseFast -j1 --summary all` | 0 | Build Summary: 15/15 steps succeeded | 181 |
| `.\.deps\zig-0.16.0\zig.exe build check -j1 --summary all` | 0 | Build Summary: 37/37 steps succeeded | 565 |
| `.\.deps\zig-0.16.0\zig.exe build test-full -j1 --summary all` | 0 | Build Summary: 50/50 steps succeeded | 662 |
| `.\.deps\zig-0.16.0\zig.exe build test-content -j1 --summary all` | 0 | Build Summary: 60/60 steps succeeded | 279 |
| `.\.deps\zig-0.16.0\zig.exe build verify -j1 --summary all` | 0 | Build Summary: 101/101 steps succeeded | 852 |
| `.\.deps\zig-0.16.0\zig.exe build -j1 --summary all` | 0 | Build Summary: 24/24 steps succeeded | not reported |
| `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseSafe -j1 --summary all` | 0 | Build Summary: 24/24 steps succeeded | not reported |
| `.\.deps\zig-0.16.0\zig.exe build -Doptimize=ReleaseFast -j1 --summary all` | 0 | Build Summary: 24/24 steps succeeded | not reported |
| `.\.deps\zig-0.16.0\zig.exe build gpu-smoke -j1 --summary all` | 0 | Build Summary: 26/26 steps succeeded | not reported |
| `.\.deps\zig-0.16.0\zig.exe build effects-projectiles-smoke -j1 --summary all` | 0 | Build Summary: 26/26 steps succeeded | not reported |
| `python tools/effects_projectiles_review.py --compare evidence/effects_projectiles` | 0 | not a build-step summary | not reported |
| `.\.deps\zig-0.16.0\zig.exe build run-engine-lab -j1 -- --verify` | 0 | not a build-step summary | not reported |
| `.\.deps\zig-0.16.0\zig.exe build run-engine-lab -j1 -- --smoke` | 0 | not a build-step summary | not reported |
| `.\.deps\zig-0.16.0\zig.exe build evidence-history-check -j1 --summary all` | 0 | Build Summary: 2/2 steps succeeded | not reported |

The five combined lanes passed 181 tests (54 Effects/Projectiles, 50 RR1,
40 PSM01, 21 World Time and 16 Engine Lab) in each optimization mode. Physical
GPU and standalone application proofs retain their existing ownership. Timing
and exact pixel repeatability apply to this reference machine/driver; they do
not grant new visual acceptance or cross-platform determinism.

## Post-parallel reconciliation

CURRENT_STATE, MASTER_ROADMAP, ARCHITECTURE_MAP, KNOWN_GAPS, TESTING,
REPOSITORY_RETENTION, the World Time report and the Effects/Projectiles report now identify the five
accepted independent lanes on master and the completed Effects/Projectiles
merge/acceptance-document fast-forward. Historical milestone-time wording is
preserved as history. No phase, M03/M04 or editor milestone is renumbered; no
EL2, PSM02, gameplay or deferred integration is authorized by this record.

Remaining limits: the correction is unpushed and unmerged pending owner review;
pre-policy checkouts are not automatically rematerialized; repository gates
require Git/Python; GPU evidence is reference-machine scoped. No dependency is
updated and no branch or worktree is deleted.
