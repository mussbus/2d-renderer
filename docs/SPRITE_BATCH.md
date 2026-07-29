# Sprite Batch Contract

## One authoritative path

`src/graphics/sprite_batch.zig` owns deterministic submission validation, capacity, stable ordering, draw-range generation, metrics, and conversion to transferred data. `src/graphics/gpu_demo.zig` owns the SDL GPU resources and contains one sprite draw site. Both the 1,000-sprite application and `gpu-smoke` pass a `PreparedBatch` to `encodeAuthoritativeSpriteBatch`; there is no retained Prompt 1 direct-quad submission path.

The actual draw is `SDL_DrawGPUIndexedPrimitives(render_pass, 6, range.instance_count, 0, 0, range.first_instance)`. The demonstration has one texture page, one range, and `range.instance_count == 1000`. The shared geometry remains four `QuadVertex` records and six `u16` indices; CPU code never expands sprites into unique quad vertices.

## CPU submission layout

`SpriteRequest` is the validated API input. It contains fixed-size values only. Accepted requests become the explicit `extern struct` `SpriteSubmission`, whose compile-time-asserted stride is 88 bytes and alignment is 8 bytes.

| Absolute offset | Bytes | Required alignment | Scalar representation | Field | Use |
| ---: | ---: | ---: | --- | --- | --- |
| 0 | 8 | 4 | two `f32` | `world_position` | Transferred after sorting |
| 8 | 4 | 4 | `f32` | `rotation` in radians | Transferred |
| 12 | 8 | 4 | two `f32` | `scale` | Transferred; this is both local sprite size and nonuniform scale |
| 20 | 8 | 4 | two `f32` | `pivot` in unit-quad coordinates | Transferred |
| 28 | 16 | 4 | four `f32` | `uv_rect = (min_u, min_v, max_u, max_v)` | Transferred |
| 44 | 16 | 4 | four `f32` | straight-alpha RGBA `tint` | Transferred |
| 60 | 4 | 4 | `u32` | `texture_page` | CPU-only; creates consecutive draw ranges and selects compatible GPU state |
| 64 | 4 | 4 | `f32` | `camera_x_factor` | Transferred; validated in `[0,1]` |
| 68 | 4 | 8 | padding | aligns `DrawOrderKey` |
| 72 | 2 | 2 | `i16` | `order.scene_layer` | CPU-only stable ordering |
| 74 | 2 | 2 | `i16` | `order.interaction_layer` | CPU-only stable ordering |
| 76 | 2 | 2 | `u16` | `order.actor_layer` | CPU-only stable ordering |
| 78 | 2 | 2 | `u16` | `order.body_part_layer` | CPU-only stable ordering |
| 80 | 8 | 8 | `u64` | `order.submission_index` | CPU-only final stable tie-breaker |

The only CPU padding is the explicit layout gap before the eight-byte-aligned ordering record. The first four order fields occupy exactly eight bytes before the naturally required eight-byte alignment of `submission_index`. `@sizeOf`, `@alignOf`, and important `@offsetOf` values are compile-time assertions. No pointer, slice, optional, Zig `bool`, or unspecified enum representation is transferred.

## GPU and HLSL layout

Sorting converts each CPU record into the padding-free `extern struct` `GpuInstance`. Its compile-time-asserted stride is 64 bytes and alignment is 4 bytes.

| Byte offset | Bytes | Required alignment | Zig field | HLSL input | SDL format |
| ---: | ---: | ---: | --- | --- | --- |
| 0 | 8 | 4 | `world_position: [2]f32` | `float2 world_position : TEXCOORD1` | `FLOAT2` |
| 8 | 4 | 4 | `rotation: f32` | `float rotation : TEXCOORD2` | `FLOAT` |
| 12 | 8 | 4 | `scale: [2]f32` | `float2 scale : TEXCOORD3` | `FLOAT2` |
| 20 | 8 | 4 | `pivot: [2]f32` | `float2 pivot : TEXCOORD4` | `FLOAT2` |
| 28 | 16 | 4 | `uv_rect: [4]f32` | `float4 uv_rect : TEXCOORD5` | `FLOAT4` |
| 44 | 16 | 4 | `tint: [4]f32` | `float4 tint : TEXCOORD6` | `FLOAT4` |
| 60 | 4 | 4 | `camera_x_factor: f32` | `float camera_x_factor : TEXCOORD7` | `FLOAT` |

The shared quad supplies only `float2 local_position : TEXCOORD0` from vertex slot 0. Instance slot 1 has pitch 64, `SDL_GPU_VERTEXINPUTRATE_INSTANCE`, and the pinned-header-required `instance_step_rate = 0`. D3D12 advances slot 1 once per instance. HLSL does not need `SV_InstanceID` because the per-instance input slot itself performs unique record selection.

The vertex camera is one 16-byte block pushed to DXIL vertex uniform slot `b0, space1`: `camera_center.xy` is the world-space center and `clip_scale.xy` is `2 * pixels_per_metre / drawable_pixels`. The visible path updates this block from current swapchain pixel dimensions. The fixed 640×480 readback path uses the default camera independently. Fragment resources retain Prompt 1's pinned DXIL mapping at `t0, space2` and `s0, space2`.

## Transform and UV semantics

The unit quad uses local corners `(0,0)` through `(1,1)`, with positive local Y upward. The shader evaluates this sequence:

1. Multiply the unit coordinate by `scale`; `scale` explicitly represents sprite size in world metres and nonuniform scaling.
2. Subtract `pivot * scale`, making rotation occur around that pivot.
3. Apply the two-dimensional rotation.
4. Add `world_position` after rotation.
5. Subtract full vertical camera center and horizontal camera center multiplied by the instance's parallax factor.
6. Multiply by `clip_scale` to produce clip space.

Negative scale is supported for deliberate mirroring. Zero scale is valid and collapses the quad to `world_position`. Every transform component must be finite. Pivot values are finite unit-quad coordinates; values outside `[0,1]` are allowed for deliberate off-sprite rotation centers.

UV origin is texture top-left, positive V points down, and bounds must be finite, ordered, and inside `[0,1]`. Reversed, empty, non-finite, or out-of-range rectangles fail before submission. Because the local quad's Y points up, HLSL interpolates V from `max_v` at local Y zero to `min_v` at local Y one. The smoke sprites select the red and yellow quadrants of the same uploaded procedural texture through distinct UV rectangles.

Tint and texture values use straight alpha. The graphics pipeline blends RGB as source-alpha/one-minus-source-alpha and alpha as one/one-minus-source-alpha. The opaque smoke texels therefore retain exact channel values within a one-code-value readback tolerance.

## Stable integer ordering and batching

The comparator is lexicographic: signed 16-bit scene layer, signed 16-bit interaction layer, unsigned 16-bit actor layer, unsigned 16-bit body-part layer, then unsigned 64-bit submission index. Public inputs use `i32` so invalid negative unsigned layers and values outside each destination range can be rejected without truncation. No field packing or arithmetic composition occurs, so comparison cannot overflow.

`submission_index` starts at zero in `beginFrame`, advances once for each accepted request, and is reset every frame. A frame accepts at most 16,384 submissions, so wraparound is unreachable by construction. Equal semantic keys preserve original submission order through the unique final index, even though the allocation-free sorting implementation need not itself be stable.

Prompt 7's `submitGlobally` orders a fixed maximum of eight characters by stable numeric entity ID before calling `submitWithKey` for their immutable attachment order. The returned key is the exact key stored in the submission and is retained per character for bounded evidence logging. All character parts are therefore globally sortable and can interleave; there is no character-local batch, pass, GPU buffer, or draw call.

Ranges are generated only after semantic sorting. Consecutive equal texture
pages form one range; page transitions form new ranges, and returning to an
earlier page creates another range rather than reordering through an
intervening page. The focused Prompt 2 procedural demonstration exposes only
page zero, so its 1,000 sprites form one range. Current production supports a
bounded table of atlas pages; Prompt 27 configures nine renderer pages and
reports every page/primitive transition honestly.

The focused Prompt 7 two-character demonstration adds 30 page-zero humanoid
instances to this same rule. Actor and body-part interleaving cannot split
that historical route's range because every sorted record still names page
zero, so character count remains independent from draw-call count.

Prompt 19 preserves that sprite-only contract and adds `UnifiedRenderQueue` only for mixed scenes. Sprites and deformable meshes receive the same lexicographic key and are sorted once. The prepared queue retains semantic range order while compacting sprite records, mesh instance records, and mesh-definition draws into their own bounded buffers. The renderer walks those ranges in semantic order, binding the sprite or mesh pipeline as required. A primitive transition can therefore split work even when the texture page is unchanged; mixed scenes report their actual sprite and mesh ranges/draws separately and make no one-draw claim. See `docs/MESH_ATTACHMENTS.md` for the mesh layouts and persistent-topology contract.

## Capacity and ownership

Initial CPU submission capacity, sorted capacity, range capacity, and each GPU instance slot are 1,024 records. The maximum is 16,384. Growth doubles capacity until the request fits, caps at the maximum, and uses overflow-checked byte multiplication. Empty and exactly-full batches are valid; one-past capacity grows to 2,048. Requests beyond the maximum and byte counts beyond `u32` fail meaningfully.

CPU growth allocates complete replacement submission, sorted, and range arrays before freeing old arrays, then copies accepted submissions and makes the replacement authoritative. Allocation failure leaves the old batch intact. The demonstration is preallocated for 1,000 records and marks the batch stabilized before its frame loop, so no steady-state CPU allocation occurs.

GPU growth creates all six replacement resources for three slots before touching old resources. An injected failure releases only the replacements. Successful replacement waits only the old slot fences, releases those fences and buffers, swaps the complete set, and then increments the growth counter. Old resources are never released while an in-flight slot can reference them.

## Frames in flight

The application asks SDL for three frames in flight and owns three fixed `FrameSlot` records. Each slot owns one 64-byte-stride GPU instance buffer, one upload transfer buffer of the same capacity, and at most one submission fence. Mapping and `SDL_UploadToGPUBuffer` use `cycle = false` because a slot cannot be reused until its own fence is signaled.

At slot reuse, `SDL_QueryGPUFence` first checks completion. A wait and the `frame_slot_fence_waits` increment occur only if that reused slot is still busy. The fence is then released. Successful submission stores the newly acquired fence and advances the ring. A failed frame does not advance the slot. Fence-acquisition fault injection waits and releases the acquired fence before returning. Device-idle waits occur only during final destruction or an exceptional submitted-command cleanup path, never in the ordinary frame loop.

Persistent shaders, the fixed-readback and swapchain-format pipelines, sampler, textures, shared quad buffers, and all six frame-slot buffers are created during initialization. Ordinary frames acquire command buffers, swapchain textures, and per-submit fences but create no persistent GPU resources. Resize events update camera scalars only. Runtime counters distinguish persistent resource creation/release from fence acquisition/release.

## Metrics

Per-frame metrics reset in `beginFrame`: submitted, visible, culled, sorted, ranges, actual submitted sprite draws, and uploaded bytes. Lifetime metrics separately track CPU capacity growth, allocation attempts, post-stabilization allocation attempts, GPU slot growth, frame-slot waits, frames, persistent resource creation/release, and fences.

Draw calls are committed only after a command buffer returns a valid submission fence. The window title is formatted into stack storage and displays current actual values. Copies, render-pass boundaries, readback, skipped zero-drawable frames, and debug work do not increment sprite draw calls.
## Real texture-page ranges

Prompt 23 makes the existing `texture_page` field authoritative for retained image-backed pages. Prepared sprite and unified sprite/mesh ranges preserve semantic order and split at page transitions. Immediately before each range draw, the renderer binds that page's persistent texture and sampler. This remains range batching, not one independent submission per body part or atlas region; honest draw counts rise when sorted content alternates pages. Sprite and deformable-mesh materials share the same page table. Definition, upload, ownership, and failure details are in `docs/ART_PIPELINE.md`.

Prompt 27A's 2,400-frame integrated route peaks at 139 clean production
sprites, one active mesh, 17 sprite ranges/draws, one mesh range/draw, 85,824
window sprite-upload bytes with the same-queue HUD, and 64 mesh-upload bytes.
Those are actual prepared and encoded counts after global
semantic sorting of environment, surfaces, two characters, wardrobe,
interaction-qualified equipment, foreground, and optional debug work. The
route does not claim one draw across incompatible page or primitive
transitions.

Prompt 27B adds no renderer or per-character draw path. Character and
wardrobe trace records carry the queue index returned by their actual
submission, enabling bounded ground-contact adjustment of those same
submitted records. Debug-only contact, safe-frame, and parallax markers use
the existing procedural page and global sort/range path. The final D3D12
route reports 149 sprites, one mesh, 36 sprite ranges/draws, one mesh
range/draw, and zero post-stabilization queue or submission allocations.
