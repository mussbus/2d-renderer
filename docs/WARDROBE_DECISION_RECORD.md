# Prompt 25 Wardrobe Decision Record

This record captures maintainer-facing conclusions from the Prompt 25 implementation.

## Original production art

The first 26 seconds of the local reference video and both outfit contact sheets were inventoried before implementation. The shipped wardrobe pages were generated as original red/ivory fantasy garment cutouts and then processed through the established chroma-to-alpha pipeline. A first upper-page draft visually included sleeve and lower-garment shapes inside several torso cells; it was rejected and regenerated so torso, sleeve, and lower components remain independently reusable. No extracted reference frame became a runtime asset.

## Stable identity and packing

The catalog uses extensible `PresentationSemanticId` values 25000 through 25035 rather than a closed enum of garment kinds. Each semantic has a distinct side and front region. The three texture pages group upper, layer/accessory, and lower components for practical batching only; page ownership does not define item, slot, layer, coverage, or anatomy identity.

## Occupancy, layer, and coverage

Prompt 17 already supplied independent typed concepts, so no replacement equipment algorithm was added. Prompt 25 adds only data needed by the wardrobe. In particular, blouse and cardigan use different occupancy slots and different draw layers while intentionally overlapping coverage. The custom outfit includes both and is executable proof of this separation.

## Binding and projection

Topology-aware recipes remain authoritative for repeated sleeves, gloves, legwear, and shoes. Front presentation extends the existing bounded Prompt 24 projection to expose appearance-module and anatomy-part bindings; side presentation continues to use the established character transforms. The torso recipe offset is `-0.09 m` because the anatomy torso binding is at `+0.65 m` while the canonical torso visual center is `+0.56 m`.

## Hair and headwear

Long hair remains character presentation rather than equipment. Hats do not remove it. Headwear uses an explicit layer above the current single-piece long-hair art, avoiding item-specific visibility hacks. A future hairstyle may split bounded back/front hair components without changing equipment semantics.

## Long garments

The long split skirt uses two immutable view-specific meshes over the paired art regions plus the existing bounded secondary-motion state. This duplicates only six vertices/twelve indices per view at initialization and avoids runtime topology mutation, upload, allocation, or a generalized cloth solver.

## Hot swapping and controls

`replaceAll` performs copy-validate-commit selection of a complete typed item list. O and P were unused keyboard controls and now generate focus-safe outfit-cycle and pause edges. Q retains Prompt 24 view override and R retains reset. Cycling performs neither decoding nor GPU creation.

## Verification conclusion

The focused tests validate all production IDs, paired views, slot conflicts, independent layer/coverage semantics, topology expansion, semantic feet and invariant foot transforms, hair/headwear coexistence, transactional rollback, custom reuse, cosmetic invariance, two-character isolation, lifecycle cleanup, reset, input edges, and allocation-free queue submission. The real SDL GPU route selected `direct3d12`, consumed DXIL, loaded five PNG pages and two persistent mesh definitions, cycled all 15 presets in front and side, and reported zero steady-state allocation and zero GPU-resource delta. Sequential live-window captures were inspected; this is visual D3D12 evidence, not a claim of physical keyboard testing.

Prompt 25A corrected two presentation-data mistakes without changing these
semantics. The ivory blouse front sleeve and crimson shoe now use alpha-tight
atlas extraction so transparent authoring-cell padding cannot displace the
visible garment. Footwear binds directly at the semantic toe with a toe/sole
pivot instead of combining a center-like product-art pivot with a compensating
translation. The final D3D12 checklist and remaining art-only limitations are
recorded in `VISUAL_ACCEPTANCE_25A.md`.
