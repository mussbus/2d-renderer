# Prompt 25A Decision Record

## Root-cause conclusions

The rejected result was a combination failure, not an image-generation-only
failure.

- Source artwork used narrow or capped limbs whose alpha ended before the
  semantic joints. The original male and female pages also mixed detailed heads
  with comparatively crude limb pieces.
- Several region rectangles retained padding or selected the wrong authored
  orientation. The wardrobe shoe and front ivory sleeve were especially
  affected by transparent 256-pixel cell padding.
- Base limb pivots described nominal cell ends rather than the useful connector
  pixels. The shoe used a product-cutout center pivot while equipment actually
  binds at the semantic toe.
- The side presentation exposed front-rest arm spacing, which made profile arms
  float beside the torso. Front and side art were distinct, but their projected
  root spacing was not view-appropriate.
- Parent-first body layering exposed straight connector edges at the male
  pelvis/knee. The relevant child overlap needed to cover those internal ends.
- Wardrobe sleeves inherited correct topology but their padded alpha made them
  appear to start near the elbow. Correct equipment semantics therefore
  produced visibly incorrect clothing until extraction and pivots were fixed.

## Accepted implementation decisions

The final production pages are:

- `assets/art/p25a_male_base_anatomy_atlas.png`, 1600 by 983 RGBA;
- `assets/art/p25a_female_base_anatomy_atlas.png`, 1599 by 984 RGBA.

They retain distinct side/front regions, neutral non-explicit base anatomy,
featureless permanent `base_presentation` surfaces, independent hair, and
independent garment bindings. Male straight connector cells are hidden through
intentional overlap and layer order; they are not a second skeleton or renderer.

`FrontProjection.initSide` still consumes the same authoritative pose. It uses
the existing front rest remap as bounded pose input, then applies a side-only arm
root compression appropriate to the separately authored profile sprites. It
does not reuse or compress a front sprite, mutate simulation, or create a side
animation system. The female/male source regions selected for side presentation
remain distinct side artwork.

The male pelvis renders beneath the thigh connector ends, and shin ends render
over thigh ends. This style-local presentation ordering conceals generated
internal connector pixels without changing semantic body ownership, interaction
ordering, or equipment layers.

The ivory blouse front sleeve and crimson shoe now use audited alpha-tight
source rectangles. The shoe uses a toe/sole pivot and no compensating local
translation. This preserves topology-aware bilateral binding while making the
visible cutout follow the underlying foot.

## Image-generation record

The built-in image-generation workflow was used in `stylized-concept` mode.
Sources were generated on a flat `#1bd136` chroma background, copied into
`zig-out/p25a_art_work`, converted to RGBA alpha, visually inspected, and only
then copied to `assets/art`.

Final normalized prompt set:

```text
Asset type: production modular pixel-art character atlas.
Primary request, male: re-author an exact 1600 by 983 segmented adult male
atlas with distinct side and front anatomy, athletic coherent proportions, and
straight open connector extensions for isolated upper arm, forearm, thigh, and
shin cells. Keep every body region independently segmentable.

Primary request, female: re-author an exact 1599 by 984 segmented adult female
atlas with distinct side and front anatomy, coherent curvy adult proportions,
independent limb/hand/foot cells, and open connector overlap around every
articulation.

Style: coherent high-quality pixel art with one skin/shading/outline language.
Scene: perfectly flat solid #1bd136 chroma background.
Constraints: neutral non-explicit featureless base presentation; no removable
clothing baked into anatomy; independent hair and training-vest regions; no
sexual pose or explicit anatomical detail; no text, watermark, shadow, floor,
checkerboard, or background variation.
```

Installed male source:
`C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_bxUDdQG0uf0XQktylCNuY9ue.png`,
processed as `zig-out/p25a_art_work/male_v4_open_connectors_alpha.png`.

Installed female source:
`C:\Users\Chad\.codex\generated_images\019f9ef4-c5ad-71f1-83a9-749677822134\call_6fDGTOPZVbZCDST62LlL2b4g.png`,
processed as `zig-out/p25a_art_work/female_v4_alpha.png`.

Rejected generated/edit candidates remain outside production bindings:

- `call_16NKDe0s7ZiU1dcDcbdwAuvO.png` introduced checkerboard/dimension/layout
  problems and retained capped joints;
- `call_YcBSaw5MWwLofSGAi7Oi9bz2.png` did not improve connector integration over
  the selected male source;
- male/female v1-v3 alpha candidates retained less coherent proportions,
  closed connector pixels, or poorer source-region separation.

A runtime joint-overlay sprite experiment was also rejected because its
rectangular cuffs were more conspicuous than the original seam. A UV reversal
experiment was rejected by the Prompt 23 monotonic-UV validation. Neither
experiment remains in production code or region counts.

## Capture decision

Desktop GDI and ffmpeg window-copy attempts after the resumed Windows session
returned black/invalid captures. They were not used as evidence. The accepted
route instead copies the exact 640 by 480 D3D12 acceptance target to one
persistent transfer buffer after encoding the same prepared global queue. This
is stronger pixel provenance than a desktop screenshot and preserves the
visible SDL window path. Capture writes are bounded acceptance-route I/O and are
absent from ordinary demos.

## Architecture preservation

- Anatomy and equipment retain distinct typed semantics and region IDs even
  when co-packed on one page.
- The 30 items, 36 reusable components, 15 presets, independent occupancy,
  visual layer, and body coverage records are unchanged.
- Sleeves, gloves, legwear, and footwear still expand through anatomy roles;
  there are no outfit-specific draw calls.
- Presentation remains CPU-side bounded math over the authoritative character
  pose. Physics, animation, IK, foot planting, interaction, and character roots
  remain unchanged.
- All sprites and meshes still enter one ordered `UnifiedRenderQueue`.
- The persistent capture buffer is initialized before the resource checkpoint;
  steady update, submission, queue, and GPU-resource deltas remain zero.

## Remaining visual limitations

At nearest-neighbor 2x, the male torso has denser generated shading than the
female base and some joint transitions show one- to two-pixel tonal steps. The
crimson shoe source uses richer three-quarter product shading than the simpler
base foot, and a narrow skin-colored sole fringe can be visible behind it in
some side pixels. At intended normal scale these do not form background gaps,
detached feet, or conspicuous rig boundaries, but a future art-only pass could
harmonize shading density and author flatter orthographic shoe cutouts.
