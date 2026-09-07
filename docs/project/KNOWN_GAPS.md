# Known Gaps

Prompt 27's automated integration remains the protected runtime boundary.
Prompt 27A reopened manual visual acceptance, Prompt 27B added measured
contact/framing/parallax/presence evidence, and Prompt 27C measured the
production base anatomy. The original Prompt 27C torso was owner-rejected;
Prompt 27C-R1 supplies the current bounded correction and remains pending
owner review. VF-01 makes rig, projection, component, atlas, and final
submission disagreements inspectable and exportable. VF-02 now makes a
bounded core anatomy set authoritative atlas-to-rig placement while leaving
unmigrated visuals and wardrobe compatibility explicit. VF-03 compiles the
existing appearance/anatomy topology into one immutable typed inspection
authority with bounded direct proofs. The gaps below are
future-content or tooling limitations and
are separate from the specific visual issues that Prompt 27D–27H may address.

| Gap | Impact | Current workaround | Trigger for implementation | Blocks current Prompt 27 acceptance? | Blocks a future editor? |
|---|---|---|---|---|---|
| No runtime-authored side-left/side-right fragment selection policy | Asymmetric side garments cannot be represented without separate generalized selection metadata. | All current production garment side sources are mirror-safe and follow the authoritative body projection. | First milestone that authors a genuinely asymmetric side garment; before garment editor export is finalized. | No | Yes |
| Numeric visual layers are the authored garment-depth mechanism | A future author must know renderer layer numbers; reusable relations such as “behind neck” are not first-class. | Current 30-item wardrobe uses a stable, audited numeric layer table. | Before first multi-depth production garment or garment editor. | No | Yes |
| No stable authored fragment ID independent of recipe ID | Diagnostics identify the component/recipe, but a future editor cannot persist a human-authored fragment identity cleanly. | Logical item + component + typed recipe ID remains deterministic. | Garment schema stabilization. | No | Yes |
| Neck/collar coverage is not first-class | A collared/high-neck garment could pass a generic torso fit while missing the intended collar zone. | Current low-neck/halter/blouse art uses per-item fit landmarks and bounded coverage zones; no accepted item declares a high-neck collar. | Before a high-neck/collared production item or garment editor. | No | Yes |
| Shoulder slope is not represented as a bounded semantic contour | A future fitted garment can satisfy rectangle/span metrics while disagreeing with the visual shoulder descent or armhole. | Current art was manually fitted and Prompt 25D metrics/captures are accepted. | Before new fitted upper-body authoring is generalized. | No | Yes |
| Split skirt is one deformable mesh | It cannot independently order rear/far, central, and front/near fabric around limbs. | Existing `garnet_split_skirt` mesh is accepted for current poses and layers as one unit. | When a production skirt/dress requires limb-crossing depth composition. | No | Yes |
| Hair/headwear is not a three-fragment depth recipe | Hats always use the headwear layer above the single hair presentation, limiting back-hair/headwear/front-hair composition. | Current long hair and hats are visually accepted with fixed order. | Hair/headwear authoring expansion. | No | Yes |
| Current atlas supplies only front and canonical-side wardrobe art | Rear, diagonal, and genuinely directional variants are unavailable. | Front and mirrored canonical side are the supported presentation views. | Content-specific authored-view expansion. | No | Yes, for those views |
| Visual-geometry fit metadata remains authored in Zig | Routine new garments require source edits. | Catalog definitions are bounded, validated, and deterministic. | Garment editor/export schema phase. | No | Yes |
| Only two environment themes are authored | The theme architecture is proven but the world has limited visual variety. | Violet crystal ruin and neutral diagnostic chamber cover production and diagnostic presentation. | New world-content milestone. | No | Yes, for scalable content production |
| Environment placements are authored in source | Artists cannot place parallax or decorative elements interactively. | Theme definitions are immutable, bounded, and validated against collision ownership. | Level/theme editor phase. | No | Yes |
| Interaction presentation has one production contact/occlusion profile | Carrying, lifting, hand-to-prop, multi-contact, or cinematic interactions need additional data contracts and authored animation/views. | The fixed-root handshake uses typed role views, automatic-view suppression, one typed right-hand contact profile, existing IK, and deterministic cleanup. | First production interaction requiring more contacts, a relative-root constraint, or world anchors. | No | Yes, for general interaction authoring |
| No general dynamic character-character collision | Independently controlled characters can pass through each other outside authored routes. | Prompt 27C-R1 measures interactive overlap without terminating; scripted Prompt 27B evidence explicitly enforces the same unchanged acceptance thresholds. No physics or root teleport is hidden behind presentation. | First gameplay milestone requiring free simultaneous character occupancy/avoidance. | No | No |
| No authoring GUI | Artists cannot place pivots, landmarks, zones, fragments, themes, or interaction presentation interactively. | Definitions are authored in source and checked by focused validation plus D3D12 captures. | Phase 6 authoring tools. | No | Yes |
| Registration migration is bounded rather than catalog-wide | Arms, forearms, thighs, shins, feet, shoes, torso, pelvis, nose, eyes, eyebrows, and hair use authoritative registration; hands, head, other face features, and most wardrobe remain transitional or compatibility paths. | VF-01 exports authority status and residuals for every submitted visual; no legacy visual is labeled authoritative. | A later explicitly authorized production-art migration after owner review. | Yes, for visual approval | Yes |
| Component graph has a bounded direct-production migration | VF-03 is the runtime inspection authority, but standard core limb/root components still use labeled compatibility adapters and the technical optional modules are not generalized animation/IK content. | VF-03-R1 fail-closes active optional-arm graph visuals against final production submissions and renders the explicit projected chain in front/side views. Standard two-arm behavior is unchanged. | Future editor/export or arbitrary-topology animation milestone after explicit authorization. | No | Yes |
| No bounded gameplay loop | The repository demonstrates integrated production systems, not a beginning-to-completion game slice. | Prompt 27 foundation supports traversal, jumps, dash, themes, outfits, and three handshakes with reset. | Phase 5 vertical slice after explicit authorization. | No | No |

## Effects and Projectiles integration boundary

The [owner-accepted foundation](../implementation/effects_projectiles_foundation.md)
provides currently 2D projectile and effects cores with a standalone visual
proof. PHY, Engine Lab, RR1, world/environment, 3D presentation and
gameplay-specific integration remain deferred. Acceptance of this parallel
foundation does not renumber or complete M03, M04, Phase D, Phase L or any
editor milestone.

## Windows working-byte reproducibility

**Resolved/closed: owner-accepted on master at
`dca3b331a86abee43a271cc00292021334ab8612`.** Master was fast-forwarded
directly to that commit; no separate merge commit exists.
Mechanics commit `cf094b617ae52be1031d8dde1fda310651c1d84e` passed all nineteen
required commands in a newly created detached Windows worktree, with unchanged
system Git configuration and no tracked-file copying or checkout-byte repair.
The [implementation report](../implementation/reproducible_windows_checkouts.md)
records the policy, prospective ten-file owner decision, exact restorations and
measured results. Acceptance closes this repository-integrity defect only; it
advances no product milestone or deferred cross-system integration.

The following paragraph preserves the integration-time defect and workaround
history. Before the correction, fresh Windows worktrees could
materialize format-sensitive Zig files and immutable historical text artifacts
with working bytes that fail existing validation. At master baseline
`c6892c324ba59f8317886005fe977efce7ac1546`, a fresh detached checkout failed
formatting for 265 Zig paths and 12 historical hashes; the long-lived master
worktree passed both checks. The resolved Effects/Projectiles integration
failed for 275 Zig paths and the same 12 historical artifacts. The merge did
not cause or fix this condition.

The integration used an owner-authorized, uncommitted local byte-materialization
workaround: 279 checked Zig paths came from their exact resolved index blobs,
and the 12 failing historical files came from untouched master bytes verified
against existing expected SHA-256 values. All 20 protected hashes passed after
copying. Full `verify` then exposed byte-sensitive content tests and inventory
mismatches in seven historical families. A further 102 inputs required the
same local workaround: 99 historical text files, the accepted geometry authority
JSON, the human structural report and one parser fixture. Every master copy
matched its raw index blob and every source family matched the existing manifest.
Their working bytes were materialized without changing tracked content or
weakening tests; content policy, affected tests and the full gate were rerun.
Git's cached file sizes also required a metadata refresh with identical existing
index entries; no staged mode/blob/path or merge-tree content changed.
The copied working bytes are not tracked feature changes.

The subsequent correction implements the owner-selected policy: active source
and canonical text use LF, while immutable captured byte streams use scoped
`-text`. Eighteen prompt/report blobs regain their pre-existing accepted raw
hashes. Ten geometry streams use new individual authorities established by the
2026-09-06 owner decision; those individual hashes did not exist before that
decision. Every earlier expected hash and family size remains unchanged.
Current geometry authority and active R4 qualification retain textual LF policy.

The original integration itself changed no attributes or historical expectations;
its [validation record](../implementation/effects_projectiles_foundation.md)
remains historical evidence. Existing pre-policy working directories are not
automatically rewritten by changing attributes. Use a new checkout for the
reproducibility guarantee; no old worktree or local byte copying is required.

## Art-quality status

The historical Prompt 25D character art remains accepted at its stored
640×480 acceptance camera and required pose/view/preset matrix. Prompt 27C's
original torso output was owner-rejected. Prompt 27C-R1 restores the last
accepted chest identity within four audited shoulder regions and supplies
fresh body-only/clothed D3D12 evidence, provenance, composites, and diffs.
Prompt 27A has produced 16 honest combined captures; Prompt 27B adds measured
contact/framing/parallax/presence candidates and supplemental debug evidence.
Their current aesthetic/manual fields are `[PENDING OWNER REVIEW]`; none of
the Prompt 27A, 27B, 27C-R1, VF-01, VF-02, or VF-03 candidates is an approved
golden.
The preserved pre-correction fresh-current-art report retains 24 Prompt 27B
front-foot endpoint-height failures. The VF-02 owner-review correction removes
the surviving wardrobe shoe `+/-78` degree orientation policy and a new fresh
report records 9,752 metrics with zero failures. Neither result is
overwritten, and the corrected automated result does not prove
full heel/toe/sole endpoint registration: front base feet and shoes use one
positional ankle target plus a sole-axis orientation constraint, with
heel/toe/sole landmarks exported as transformed evidence rather than
independent endpoint targets. Closed footwear suppresses covered base-foot
pixels but retains their hidden evidence. It also does not prove aesthetic
approval or
arbitrary future combinations, views, body topologies, morphology ranges,
themes, or interactions. New content must declare and pass its own contracts
rather than inheriting acceptance from the current atlases.

## Interaction-presentation boundary

Prompt 27 completed the planned view-aware handshake presentation. Each
interaction definition can declare a view for each participant role, whether
ordinary automatic view selection is suppressed, and a typed occlusion
profile. The current handshake owns side/side presentation, preserves the
participating right-arm animation/IK plane, applies participant-qualified
body/equipment ordering, and releases every claim on completion,
cancellation, rollback, and reset.

This is deliberately not a general paired-pose or prop-interaction framework.
Future multi-contact, relative-root, world-anchor, back/three-quarter, or
cinematic behavior remains out of scope until real content requires it.

## RR1 replay integration boundary

The [RR1 V1 contract](../architecture/deterministic_record_replay_v1.md)
supports one headless production-controller route, separate causal/observed
streams, mandatory per-tick fingerprints and named checkpoints.
Arbitrary character, animation, interaction, equipment, specialized scene and
sandbox state is not replay-integrated. RuntimeScene publication/snapshot
acquisition still allocate; RR1 retains one immutable initial snapshot.
No arbitrary render-frame, physical-input, cross-platform or cross-compiler
determinism is claimed.

Future clients must provide complete versioned bootstrap/channels/contributors
at their existing tick boundary and address dynamic scene publication.
Screenshots and JSON inspection remain optional future sidecars, correlated
by artifact digest, protocol, checkpoint name, completed tick and state digest.
They must never drive replay. Save-game UX, migration, rewind, networking,
Engine Lab integration and whole-engine replay require separate work.
