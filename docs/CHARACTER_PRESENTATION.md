# Character Presentation

## Facing and view authority

Gameplay `Facing` remains the authoritative left/right direction. Prompt 24 adds a separate presentation `View` with `side` and `front` values. A grounded idle character automatically uses front; walking, dashing, jumping, rising, falling, and landing use side. The decision reads fixed-tick controller and animation state, never render delta.

An interaction definition may require a presentation view. The existing handshake requires side for both roles, claims that view when its participant locks are reserved, and releases it on completion, cancellation, or rollback. Interaction authority has precedence over the bounded debug override; the debug override has precedence over automatic policy. A release immediately resumes ordinary policy.

View changes are presentation-only. They do not modify the character root, controller velocity, collider, grounding/support, jump or dash state, resolved properties, equipment, interaction lock, animation clock, or anatomy topology. The last meaningful gameplay facing is retained while a character is shown from the front.

## Shared pose interpretation

Side presentation uses the existing evaluated appearance world transforms and the established single character-root X reflection. Only one side atlas is authored; anatomical left/right IDs, sockets, attachments, IK targets, equipment bindings, and spring ownership remain stable.

Front presentation is a fixed-capacity projection of the same authoritative local pose. It preserves the character world position, vertical pose motion, torso/head animation, breathing deformation, attachment-local deformation, and attachment secondary transform. View-specific arm rest offsets are presentation data; there is no front gameplay animator or second simulation.

Front projection never applies facing reflection. Its explicit semantic layers place anatomical left limbs behind the trunk and anatomical right limbs in front, independent of submission order. Anatomy names do not change according to screen position.

Every actual view transition clears bounded visual secondary state. The next fixed visual tick initializes springs from the new view's resolved rest configuration. This prevents stale side displacement from being mirrored into front space, avoids one-frame wrong-view hair, and leaves independent characters unchanged.

## Corrected base-anatomy production art pack

Prompt 24A replaced the clothing-baked pages. Prompt 25A re-authored that
separated content for continuous external presentation as two RGBA
nearest-sampled atlases:

- `assets/art/p25a_male_base_anatomy_atlas.png`, 1600 by 983: adult
  lean/athletic base anatomy, open overlap connectors, original buzz-cut art,
  and separate training-vest overlays;
- `assets/art/p25a_female_base_anatomy_atlas.png`, 1599 by 984: adult curvy base
  anatomy, open overlap connectors, original long-hair art, and separate
  training-vest overlays.

Before the correction, the torso pixels contained a top, arms contained sleeves/cuffs, pelvis and legs contained trousers/shorts/stockings, and feet contained shoes or boots. Those images are no longer build inputs or installed assets. The corrected canonical torso, upper arm, forearm, pelvis, thigh, shin, foot, and hand regions contain only base-form pixels. Arms, legs, hands, and feet are bare neutral anatomy. Torso and pelvis use a smooth, opaque, skin-adjacent permanent modesty surface with no fabric edge, seam, waistband, neckline, or equipped-garment identity. That surface is classified as `base_presentation`: it is not an equipment item, cannot be unequipped, and preserves a neutral silhouette beneath arbitrary future clothing.

Each physical page deliberately co-packs 32 character/presentation regions and two garment-only vest regions. Across both pages, `character_art.zig` defines 68 tight atlas regions, 92 `.character` semantic/view bindings, and four `.equipment` vest bindings. Texture-page equality therefore proves batching policy only; the typed binding kind, semantic ID, and region ID retain ownership. `Presentation` resolves all canonical body parts without resolving a garment. `Definition.validateAnatomyClothingBoundary` rejects character/equipment identity crossover and verifies that the distinct torso and vest identities genuinely share each production page.

Each style resolves side and front head, torso, pelvis, segmented arms/hands, segmented legs/feet, face features, and its supported hair. Bald means no active hair visual. Buzz cut and long hair are real view-specific regions. Authored region size, pivot, overlap, and rest rotation are content metadata; the engine does not impose pixel density or nearest sampling on future packs.

Prompt 25A adds deliberate connector overlap and view-appropriate projected arm
spacing. The side view still selects separately authored profile regions; the
bounded projection only moves arm roots into a coherent profile silhouette.
Male pelvis/thigh/shin order covers internal connector ends. These are
presentation decisions over the existing semantic parts, not new anatomy,
animation, or rendering paths.

The supplied reference images informed only broad adult proportions, build, limb length, and silhouette. No source pixels, logos, text, clothing catalog, or source-game assets were traced or copied. The third reference is explicit and was not supplied to image generation; only the brief's broad non-explicit body-shape requirements were used.

Both characters submit through the existing global `UnifiedRenderQueue`. The final scripted frame has 46 sprites across the two atlas pages, two page ranges, and two indexed-instanced draws. There is no per-character renderer and no per-part command submission.

## Demonstration

The deterministic D3D12/DXIL evidence route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo character-presentation --scripted-input --frames 360
```

At four 240 Hz simulation ticks per rendered frame, it demonstrates male front idle, left side movement, front idle retaining left facing, right side movement, jump/fall/land, bald/buzz switching, female front idle and side movement, breathing, long-hair motion, forced views, a side-view IK handshake, and return to front. It rejects missing evidence, incomplete interaction cleanup, post-stabilization CPU allocation, and GPU-resource growth.

The open-ended inspection route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo character-presentation --interactive
```

`Q` cycles automatic, force side, and force front for the controlled character without changing facing. `H` toggles its bald/buzz choice. Movement, jump, dash, interaction, reset, and exit retain their production mappings.
