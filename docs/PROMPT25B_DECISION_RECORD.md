# Prompt 25B Decision Record

## A. Actual causes

Prompt 25A passed structural tests but its production pixels and bindings were
not visually acceptable.

- `keyForSlot` intentionally resolved bilateral anatomy to one view region, but
  front submission did not mirror either anatomical side. Both feet, hands,
  shoulder shading, and other asymmetric pixels therefore pointed the same way.
- Male `side_forearm` selected the `side_upper_arm` source rectangle. Female
  `side_shin` and `front_shin` selected their corresponding thigh rectangles.
  Those were different semantic IDs over duplicate pixels, not authored
  forearms or calves.
- The female front hand alpha was approximately 162 by 67 pixels while its
  runtime quad was 0.24 by 0.38 metres. Its authored/source aspect ratio was
  approximately 0.26. The old pelvis ratios reached approximately 2.45. The
  renderer was being asked to hide unsuitable art through anisotropic stretch.
- Front arm roots were compressed to 90 percent of their authoritative spacing.
  Rectangular limb silhouettes then showed through the torso overlap as square
  shoulder transitions.
- The first corrected upper-arm study still duplicated the deltoid mass already
  authored into both torso sprites. Its broad shoulder bulb made the body read
  as two overlapping shoulder pieces even after front compression was removed.
- `FrontProjection.initSide` called the complete front projection, including
  front rest remapping and front compression, and then applied side
  compression. Side placement therefore accumulated two view corrections.
- Pelvis ordering concealed connector ends only for the male style. The female
  pelvis remained in front of its thigh overlap and exposed the crop edge.

## B. Corrections

`assets/art/p25b_anatomy_components_atlas.png` is a 1792 by 1024 RGBA,
nearest-sampled production page. It contains 28 alpha-tight pelvis, arm, hand,
leg, and foot regions: seven semantic components for each style and each view.
The page deliberately co-packs male/female and front/side anatomy; the page does
not define semantic ownership.

Examples proving that the production bindings no longer alias unsuitable art:

- male front upper arm: `(209,317,42,124)`;
- male side upper arm: `(72,103,112,50)`;
- male side forearm: `(335,111,97,33)`;
- male front forearm: `(364,334,33,102)`;
- male front thigh: `(869,306,54,156)`;
- male front shin: `(1123,313,58,142)`;
- female side thigh: `(854,563,84,154)`;
- female side shin: `(1125,567,54,145)`;
- female front upper arm: `(209,827,30,126)`;
- female front forearm: `(364,845,24,102)`;
- female front hand: `(624,864,31,64)`;
- female front thigh: `(855,819,82,154)`;
- female front shin: `(1126,817,51,151)`; Prompt 25D retains six
  transparent proximal rows so the thigh-owned knee cap does not stack with
  the independently articulated lower leg;
- female front foot: `(1379,868,58,56)`.

Every one of those regions has its own atlas rectangle and region ID. The
runtime quad dimensions follow the alpha silhouette. The automated accepted
ratio band is 0.82 through 1.20; the old 0.26 hand and 2.45 pelvis values cannot
pass it. Component packing preserves each accepted source silhouette within the
audited 0.82 through 1.20 authored-to-alpha aspect band. Runtime dimensions are
recorded independently from source pixels and are not used to disguise
materially unsuitable art.

Front presentation mirrors the signed X scale for anatomical left arms, hands,
legs, and feet. The same rule is applied to equipment bound to a left anatomy
part, so shoes, sleeves, gloves, and legwear agree with the body beneath them.
Side presentation retains the established single character-root reflection.

`FrontProjection.initSide` starts from a copy of the authoritative local pose,
applies the projected arm rest once, evaluates the hierarchy once, projects
bilateral arm and leg roots onto the strict profile centerline, and rebuilds
derived attachment/module worlds. Semantic side identity and ordering remain
distinct. It does not invoke front initialization. Front presentation never
compresses shoulder roots.

The torso art now owns the front deltoid silhouette. The accepted front
upper-arm sources are narrow, featureless mannequin-style pieces with curved
shoulder ends rather than a second shoulder bulb. A transparent atlas lead-in
above each source registers that curved end beneath the torso while preserving
the elbow endpoint, authored bone length, centered pivot, and authoritative
shoulder transform. It is source packing, not a mask, connector sprite, or pose
offset.

The component page also applies a bounded per-style palette transfer: male
components were brought up to the male torso's value range and female
components were brought down to the female torso's warmer, darker range. This
removes the false cut line caused by two independently generated skin palettes
without changing alpha, geometry, or semantic ownership.

Pelvis/thigh/shin connector ordering is style-independent. The final front
pelvis regions use their authored two-leg openings instead of ending on a
continuous horizontal crop row.

No skeleton, clip, animation state, controller, physics state, IK solve,
interaction ownership, texture sampler policy, or renderer path was replaced.
All sprites and meshes still use `UnifiedRenderQueue`; the new page changes
batch ranges only.

## C. Image-generation and packing record

The built-in image-generation workflow created two corrected full-page studies
and two focused component sheets. The sources were chroma-keyed with the
standard image-generation helper, visually inspected, uniformly resampled by
semantic world length, and packed into the production RGBA page.

Source files:

- male full-page study:
  `C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_WirEl56E9A9JNC31AVvq7jX2.png`;
- male focused components:
  `C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_BqAFjE5DsGjrH0gPq298GN8P.png`;
- female full-page study:
  `C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_r2ERHf12qlp8H9ZuKV2Fh2u5.png`;
- female focused components:
  `C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_0TbaHiJ1HgPjaINNEGZ9sVcw.png`.
- accepted curved-end featureless upper-arm study:
  `C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_LrLbgQKGETqumR785FnYvb4B.png`.

The normalized requests were for isolated orthographic neutral components with
real upper-arm/forearm and thigh/calf separation, rounded overlap zones,
coherent pixel-art shading, compact feet, a flat chroma background, no
clothing, no explicit anatomical detail, and non-sexual presentation. The
final shoulder correction was deliberately phrased and authored as
featureless painted-clay mannequin pieces. The permanent modesty surface
remains classified as `base_presentation`; it is not equipped clothing.

Final production file:
`assets/art/p25b_anatomy_components_atlas.png`.

## D. Visual comparison

Same-pixel-scale comparisons are retained at:

- `zig-out/p25b_visual/prompt25a_vs_prompt25b_same_scale.png`;
- `zig-out/p25b_visual/prompt25a_vs_prompt25b_anatomy_detail.png`.

The comparisons cover front and side shoulder transitions, authored
upper-arm/forearm differences, elbow and wrist/hand continuity, thigh/knee and
calf/shin silhouettes, ankle/foot proportions, bilateral feet/hands, and the
whole-character read.

The accepted real D3D12/DXIL captures are retained under
`zig-out/p25b_visual`. They include neutral front/side, clothed front/side,
stride, jump-rise, and jump-fall frames from the same prepared global queue.

## E. Automated evidence

- `tools/audit_p25b_art.ps1` opens the actual production PNG and audits all 28
  corrected component rectangles for bounds, alpha, packing margin, unique
  source identity, and authored/alpha aspect ratio.
- Character-presentation tests verify page bounds, distinct upper-arm/forearm
  and thigh/shin UVs, component-page routing, base-region aspect bounds,
  rig-length/pivot compatibility, single side-root compression, deterministic
  front mirroring, anatomy/equipment identity separation, and steady-state
  allocation behavior.
- Wardrobe tests verify bilateral front equipment mirrored submission metadata
  and retain the existing topology, coarse joint registration, preset,
  secondary-motion, and allocation contracts. Prompt 25C establishes that
  this does not prove visual registration, orientation, fit, or coverage.

## F. Remaining limitations and milestone boundary

Side presentation deliberately shows both semantic legs rather than collapsing
them into one profile leg. At nearest-neighbor 2x inspection, the permanent
`base_presentation` modesty boundary and some one-pixel joint outlines remain
visible; at the authored presentation scale they do not create background gaps,
detached anatomy, duplicate shoulder mass, or square crop edges. No source is
used outside the audited aspect band, and no second render path exists.

Prompt 26 was not started.

## G. Final hard-gate follow-up

The authoritative rejected front capture exposed five remaining issues after
the first Prompt 25B pass.

- The female shoes had correct semantic left/right foot bindings 0.40 metres
  apart, but the left submission negated scale X without reflecting the
  shoe's authored `pivot.x = 0.95`. Both transformed shoe centers therefore
  collapsed to roughly 0.08 metres apart. Front equipment mirroring now
  complements the pivot to `0.05` when it negates scale X. The artwork and
  equipment recipe were not moved.
- The first production front torsos still contained short sleeve-like shoulder
  stubs. The actual male front torso is now
  `(248,430,150,182)` on the male base page at `1.06 x 1.30 m`; the female
  front torso is `(224,446,124,182)` on the female base page at
  `0.95 x 1.30 m`. Their compact torso-owned deltoids end in rounded overlap
  contours over the independently bound upper arms. Front shoulder transforms
  remain authoritative and uncompressed; no connector sprites were added.
- The accepted front upper arms and forearms are independently addressable.
  Front forearms resolve to layers 23 and 27, immediately above their upper-arm
  layers 22 and 26, so their soft source ends cover the dark transverse
  articulation edge. Side ordering is unchanged.
- The male permanent-modesty base bridge is
  `(1608,293,103,143)` at `0.76 x 1.05 m` with pivot `(0.50,0.38)`.
  It remains behind the thighs and torso. The actual male front thigh was
  re-authored as `(869,306,54,156)` at `0.36 x 1.00 m` without the bright
  circular proximal cap. Together those real pixels produce one lower-torso,
  pelvis, and thigh read without making the bridge look like shorts or an
  equipped garment. A rejected iteration that drew the pelvis above both
  thighs was discarded precisely because it resembled permanent shorts.
- The female front hand keeps its independently addressable source
  `(624,864,31,64)` but now uses `0.17 x 0.34 m`, preserving the source aspect
  while correcting its wrist/forearm proportion.

The final accepted generation sources for this follow-up are:

- compact front torsos and neutral bridge:
  `C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_8nuEqTjT8erzAh6dinIpm5Sg.png`;
- smooth front upper-arm and forearm components:
  `C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_F5IgJLUU5KbFQj8kJd0vtjmv.png`;
- corrected male front thigh:
  `C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_pWqmSyGDoBRlqPhNZCjHAI0T.png`.

The standard image-generation chroma-key helper produced real alpha before
the bounded components were packed. A first torso/pelvis edit request was
rejected by the image safety service and changed no repository file. A second
pelvis-over-thigh layering study and two earlier shoulder studies were visually
rejected before the final gate.

The accepted D3D12/DXIL evidence is under
`zig-out/p25b_followup_final`. `01_base_front.png` was accepted first.
Only afterward were `02_base_side.png`, `06_ivory_blouse_side.png`,
`09_locomotion_stride.png`, `10_jump_rise.png`, and `11_jump_fall.png`
inspected once. The equipped front capture proves two independently registered
female shoes. The route still reports 60 sprites, 15 indexed-instanced sprite
draws, zero steady-state update/submission/queue allocations, and zero GPU
resource delta. Prompt 26 was not started.
