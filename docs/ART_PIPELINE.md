# Art Asset Pipeline

## Runtime boundary

Prompt 23 adds one production presentation path:

```text
installed PNG
  -> Windows Imaging Component decode to RGBA8
  -> validated immutable art-pack definition
  -> bounded SDL GPU texture page and sampler
  -> existing unified sprite/mesh queue
```

`src/graphics/art_pack.zig` owns style-independent presentation definitions. `src/graphics/image_decode.zig` owns PNG decoding and decoded CPU pixels. `GpuDemo` owns the corresponding SDL GPU textures and samplers. `src/scene/art_asset_demo.zig` is focused technical evidence; it is not a second renderer and does not replace character, anatomy, equipment, animation, physics, interaction, camera, sprite-batch, or deformable-mesh systems.

The runtime consumes 2D images, stable region IDs, semantic/view bindings, authored dimensions, and pivots. It does not care whether an offline source was a human drawing, an image editor, a procedural tool, or a future 3D-to-2D authoring tool. A future exporter must emit the same validated definition data. Atlas coordinates are derived presentation data and are never gameplay identity.

## PNG decoding

Windows Imaging Component (WIC), already part of Windows 11, is the decoder. No image-decoding package or game framework is added. The implementation dynamically resolves `CoInitializeEx`, `CoUninitialize`, and `CoCreateInstance` from the installed `ole32.dll`; it uses the WIC COM interfaces inspected in the Zig 0.16.0 MinGW `objbase.h` and `wincodec.h` headers. This avoids shipping or acquiring another library.

Required files must end in `.png`. WIC must report the PNG container, exactly one frame, nonzero bounded dimensions, and a source layout convertible to 32-bit RGBA. The decoder checks row/pixel byte arithmetic and caps decoded data at 256 MiB. Missing, malformed, unsupported, unconvertible, oversized, and allocation-failed inputs return distinct errors. There is no fallback texture.

A decoded image owns one allocator-backed RGBA slice. The caller destroys it after its synchronous GPU upload fence completes. No decoded image is retained during rendering.

## Immutable definitions and stable identity

An `art_pack.Definition` copies and owns bounded immutable arrays:

- at most 8 texture-page definitions;
- at most 128 atlas regions;
- at most 256 semantic/view bindings.

`TexturePageId`, `AtlasRegionId`, `VisualSemanticId`, and `ViewId` are typed numeric IDs. Stable names and relative asset paths exist only in definition/init diagnostics. Rendering uses resolved numeric data and never performs a string lookup.

Each page declares its own dimensions and `nearest` or `linear` sampling policy. Each region declares a stable ID, page ID, checked pixel rectangle, derived normalized UV rectangle, authored dimensions, and normalized pivot. Initialization rejects duplicate page/region IDs and names, duplicate semantic/view bindings, conflicting semantic names, missing pages/regions, zero or overflowing rectangles, out-of-bounds regions, invalid dimensions, invalid pivots, and noncanonical or `reference/` asset paths.

Bindings combine an extensible numeric `ViewId` with an asset kind and semantic ID. Side and front are ordinary predefined IDs; the evidence pack also resolves synthetic view 37. Adding back, three-quarter, or cinematic views does not change storage shape or renderer code.

Repacking an atlas changes a region's pixel rectangle and derived UVs. It does not change the region ID or the semantic binding that points to it. Tests also reorder region and binding declarations and prove that the same semantic/view request resolves to the same stable region and presentation metadata.

## GPU ownership and page binding

The installed demonstration retains the original procedural page as diagnostic page 0 and initializes two image-backed pages as renderer pages 1 and 2. This offset is renderer-local; the art pack itself retains dense page indices 0 and 1.

Every image-backed page owns:

- its stable `TexturePageId`;
- decoded width and height;
- one persistent `SDL_GPUTexture`;
- one persistent `SDL_GPUSampler`;
- its sampling policy.

Initialization decodes and uploads each page exactly once. Rows use an explicitly aligned upload pitch. A submitted fence is waited and released before decoded pixels are freed. Transactional page-set construction releases every earlier texture and sampler if a later page fails. Focused D3D12 fault checks inject failure after retained texture creation and immediately before upload submission; a third case uploads page 1, fails page 2, and rolls the whole candidate page set back. Every case requires acquired-resource counts to match released-resource counts.

The existing sprite batch and unified sprite/mesh range construction remain authoritative. Before every prepared range, the renderer resolves `texture_page` to the retained texture/sampler pair and calls `SDL_BindGPUFragmentSamplers`. Consecutive compatible instances may batch; a real page or primitive-kind transition legitimately creates another range and draw. Mesh material page IDs use the same page table as rigid sprites.

## Installed assets

The build installs:

```text
zig-out/bin/art/p23_mechanical_atlas.png
zig-out/bin/art/p23_energy_atlas.png
```

Runtime paths are resolved from `SDL_GetBasePath()`, so the process working directory is irrelevant. Both 256×256 RGBA atlases are original project technical pixel art with transparent backgrounds and four nontrivial regions each. Both pages request nearest filtering. Definition tests also construct a future smooth pack whose second page requests linear filtering, proving that filtering is pack policy rather than a renderer-wide assumption.

Local `reference/` media is ignored, is not installed, and is rejected by art-pack asset-path validation. None of its pixels, logos, text, or extracted source-game sprites are present in the committed atlases.

Prompt 24 additionally installs:

```text
zig-out/bin/art/p25a_male_base_anatomy_atlas.png
zig-out/bin/art/p25a_female_base_anatomy_atlas.png
```

The Prompt 25A visual correction re-authored these as original 1600x983 male
and 1599x984 female RGBA nearest-sampled segmented pixel-art atlases. They were
created with the built-in image-generation workflow from textual, non-explicit
silhouette and connector guidance, then converted from exact chroma backgrounds
to real alpha. Canonical body regions contain neutral base anatomy, with a
smooth permanent `base_presentation` modesty surface on torso and pelvis.
Garment pixels do not occur in canonical arm, leg, foot, pelvis, or torso
bindings. Each page also contains side/front garment-only training-vest overlays
as independent `.equipment` bindings. Source reference images were not passed
to the generator, no source pixels were traced, and explicit reference material
was deliberately excluded. The accepted/rejected generation paths and prompt
set are recorded in `PROMPT25A_DECISION_RECORD.md`.

`character_art.zig` supplies 68 tight atlas rectangles: 64 body/face/hair rectangles plus four garment-only rectangles. Its 96 bindings comprise 92 `.character` bindings and four `.equipment` bindings. The two kinds intentionally resolve regions from the same two pages, proving that packing does not establish semantic ownership. Region metadata defines each part's authored dimensions and pivot. Pixel style and nearest filtering remain properties of this pack, not engine-wide rules.

## Steady-state contract

After art-pack, GPU page, mesh topology, and render-queue initialization:

- no file is opened;
- no PNG is decoded;
- no semantic string is searched;
- no texture or sampler is created or destroyed;
- no ordinary submission allocates.

The 240-frame route asserts these invariants:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo art-assets --frames 240
```

It resolves eight semantic bindings during initialization and displays six rigid sprites plus one deformable mesh across both real pages. The final deterministic frame contains six sprite ranges/draws, one mesh range/draw, 448 uploaded instance bytes, two retained nearest-sampled image-backed pages, zero fixed-buffer movement, zero post-stabilization queue allocations, and zero steady-state GPU-resource creation.

The focused non-GPU suite is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-art
```

It covers definitions, IDs, page policy, normalized UVs, bounds and overflow, missing references, duplicate metadata, declaration reordering, arbitrary views, WIC decode/alpha/errors, allocation failure, multi-page range generation, mesh compatibility, and steady-state submission.

The Prompt 24 character pack uses the same decoder, GPU page owner, texture table, and global queue:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-presentation
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo character-presentation --scripted-input --frames 360
```

Semantic strings are resolved once while `Presentation` is initialized. Each frame selects fixed numeric side/front bindings and submits ordinary sprite requests; it does not reopen an atlas, search a name, allocate, or create a GPU object.

## Prompt 25 wardrobe pages

The production wardrobe adds:

- `assets/art/p25_wardrobe_upper_atlas.png`;
- `assets/art/p25_wardrobe_layers_atlas.png`;
- `assets/art/p25_wardrobe_lower_atlas.png`.

Each 1536 by 1024 RGBA8 page contains 12 logical components with paired 256-pixel side/front cells. The 36 component semantics resolve to 72 distinct regions. The pages contain original fantasy wardrobe cutouts produced for this project; extracted reference frames and contact sheets remain reference-only and are not decoded by the application.

The upper atlas was visually audited for component ownership. Torso cells end at the shoulder and waist; sleeves and lower pieces have separate semantic regions. This prevents a torso visual from becoming a hidden full-outfit sprite and keeps blouse/cardigan/lower recombination real.

Wardrobe initialization combines the two Prompt 24A character pages and three wardrobe pages into one bounded renderer table. Image decode and upload happen once before the loop. The view-specific long-skirt meshes are also uploaded once. Preset selection changes only pre-resolved typed loadout and presentation records; it performs no decode, texture creation, mesh upload, or sampler creation.

Prompt 25A keeps the 256-pixel logical cells as the general packing layout but
uses audited alpha-tight rectangles for the shoe and front ivory sleeve. Their
whole-cell padding had reduced the useful pixels and displaced the apparent
anchor even though the semantic recipe was correct. Region extraction remains
presentation metadata; it does not change item, anatomy, occupancy, layer, or
coverage identity.

See `WARDROBE.md` for ordinary garment/view authoring,
`WARDROBE_DECISION_RECORD.md` for the packing and art-boundary decisions, and
`VISUAL_ACCEPTANCE_25A.md` for the final D3D12 pixel review.
