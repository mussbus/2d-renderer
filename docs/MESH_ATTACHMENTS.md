# Topology-aware deformable mesh attachments

## Immutable data

`deformable_mesh.Definition` is CPU-owned immutable visual data. It copies and validates:

- one bounded stable definition ID;
- at most 256 finite local vertices;
- finite normalized UVs and normalized per-vertex deformation weights;
- at most 768 16-bit indices in nondegenerate triangle-list topology;
- one stable material reference, texture page, and normalized tint;
- one bounded affine anatomy-deformation influence per vertex.

Unsupported topology, non-triangle index counts, out-of-range/repeated indices, near-zero-area triangles, non-finite values, invalid UVs/weights/materials, and capacity overflow fail initialization. The definition owns its vertex and index arrays and releases both explicitly. A view carries the owning vertex pointer as a compatibility token; stale or substituted ownership is rejected.

The initial content is `fitted_garment_mesh_v1`, `reusable_sleeve_mesh_v1`, and `upper_back_cape_mesh_v1`. Prompt 20 drives the cape's weighted local deformation through the generic bounded attachment-secondary primitive. Its clasp-edge weights are zero, intermediate body weights are partial, and hem weights are one. This remains one bounded affine result, not cloth: there is no constraint fabric, wind, world collision, self-collision, tearing, or topology mutation.

## Runtime ownership and topology expansion

Mesh and sprite components share `equipment.VisualComponent`, `EquipmentItem`, `ItemVisualRecipe`, slots, anatomy roles, coverage, and semantic layers. The `tailored_mesh_set` item deliberately mixes two mesh recipes with a rigid sprite clasp.

`every_compatible` expands the single sleeve recipe in ascending active `BodyPartInstanceId` order. Each `ResolvedVisualInstance` stores its owning character, exact typed binding source, its own `deformable_mesh.InstanceState`, and its own optional attachment-secondary state. Immutable sleeve, cape, and motion definitions are shared, while binding matrix, resolved deformation, motion nodes, and update serial are not. Equip, unequip, reset, and rebind rebuild the same bounded loadout transactionally and explicitly clear removed runtime state.

## Unified ordering

`render_queue.UnifiedRenderQueue` is the minimum mixed-primitive layer above the existing sprite fast path. Every sprite and mesh receives the established lexicographic key:

```text
scene layer
interaction layer
actor layer
body/visual layer
global submission index
```

The queue sorts that one stream and only then compacts GPU data. Adjacent compatible sprites become sprite ranges. Adjacent mesh entries using the same texture page remain a mesh range; consecutive instances of the same mesh definition become one instanced mesh draw. A primitive change or semantic interleave starts another range. No floating-point Z value or type-specific sort pass exists.

The demonstration layers place capes at 5, sleeves at 23, fitted torso garments at 33, and rigid clasps at 70. Existing body sprites remain at their authored 10–62 layers. This proves cape-behind-body, sleeve/body interleaving, fitted-garment-over-torso, and accessory-over-clothing ordering.

Legacy sprite-only scenes still use `SpriteBatch` directly and retain their one-page/one-range/one-draw guarantees. Mixed scenes make no one-draw claim.

## GPU ownership and batching

The renderer inspects and uses the pinned SDL 3.4.10 GPU API. At mixed-scene initialization:

1. `mesh_gpu_catalog.Catalog` validates unique mesh definitions and builds bounded CPU staging arrays;
2. one persistent GPU vertex buffer and one persistent 16-bit index buffer receive all immutable topology;
3. one mesh vertex shader and offscreen/window pipelines are created;
4. each of the existing three frame slots receives one 64-byte-record instance buffer and one upload transfer buffer.

The catalog supports at most 32 definitions, 4,096 vertices, and 12,288 indices. Topology buffers are never recreated or uploaded in the frame loop. Each mesh instance uploads one 64-byte record containing the world affine columns, the shared resolved deformation components, tint, and camera factor. A frame slot is reused only after its existing fence completes.

The HLSL mesh vertex shader applies the weighted local deformation and world/camera vertex transforms. The existing fragment shader samples the same texture and performs the same tint/straight-alpha pipeline. Mesh draws call `SDL_DrawGPUIndexedPrimitives` with the catalog's real index range and `num_instances > 1` for compatible repeated sleeves. Sprite and mesh ranges bind their actual pipelines and buffers in unified semantic order.

Initialization stores every acquired resource in the `GpuDemo` owner or a scoped transfer owner. Errors unwind to reverse-order cleanup. Destruction waits for in-flight work, releases both mesh pipelines, topology buffers, per-slot transfer/instance buffers, shader, CPU catalog, and queue, then continues through the established sprite/device cleanup.

## Metrics and evidence

The queue reports submitted sprite/mesh counts, sorted primitive count, sprite/mesh ranges, sprite/mesh draws, and separate upload bytes. The renderer additionally reports the immutable topology upload, definition count, two persistent topology buffers, three frame slots, and GPU creation delta after stabilization.

Pure coverage is in `tests/mesh_attachment_tests.zig`. The GPU-backed route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo mesh-attachments
```

Success requires real sprite and mesh work, fitted garments, two/four topology-expanded sleeves, capes, rigid clasps, separately measured build and breathing deformation, mirrored facing, deterministic cape unequip/re-equip, nonzero honest ranges/draws, and zero steady-state allocator or GPU-resource growth.

The Prompt 20 alias `--demo attachment-secondary` runs the same GPU path with additional required evidence for cape acceleration/sustained/reversal/stop/jump/fall/landing response, long hair, ponytail, repeated flexible-sleeve state, lifecycle reset, and facing reset. Detailed ownership and equations are in `docs/ATTACHMENT_SECONDARY_MOTION.md`.

## Prompt 22 focused foundation integration

The retained Prompt 22 `foundation_playground.Scene` registers three immutable
mesh definitions once in its persistent topology catalog. Its controlled
character, handshake partner, and nonstandard showcase submit fitted torso,
topology-expanded sleeve, and cape instances through
`CharacterInstance.submitUnified`. All body sprites, rigid equipment sprites,
environment sprites, debug primitives, and mesh instances enter one semantic
queue; reported sprite ranges, mesh ranges, indexed-instanced draws, and
upload bytes are the actual encoded counts.

Body/build/hair changes, breathing, loadout property resolution, movement abilities, and secondary motion update only CPU instance records. They do not create topology buffers, shaders, pipelines, textures, samplers, transfer buffers, or frame slots. Reset clears each loadout's `InstanceState` and secondary state before the restored loadout can repopulate valid current-character handles on the next submission.

Prompt 27's visible `--demo foundation` route instead preloads the two
production long-garment mesh definitions used by the current wardrobe. The
2,100-frame route reaches a peak of one active mesh and one mesh range/draw
while body, equipment, environment, standable-edge, and debug sprites remain
in the same `UnifiedRenderQueue`. The two topology definitions and their GPU
buffers persist across all outfit and theme changes; the route reports zero
post-stabilization GPU-resource growth.
