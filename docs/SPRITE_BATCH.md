# Sprite Batch Contract

## One authoritative path

`src/graphics/sprite_batch.zig` owns deterministic submission validation, capacity, stable ordering, draw-range generation, metrics, and conversion to transferred data. `src/graphics/gpu_demo.zig` owns the SDL GPU resources and contains one sprite draw site. Both the 1,000-sprite application and `gpu-smoke` pass a `PreparedBatch` to `encodeAuthoritativeSpriteBatch`; there is no retained Prompt 1 direct-quad submission path.

The actual draw is `SDL_DrawGPUIndexedPrimitives(render_pass, 6, range.instance_count, 0, 0, range.first_instance)`. The demonstration has one texture page, one range, and `range.instance_count == 1000`. The shared geometry remains four `QuadVertex` records and six `u16` indices; CPU code never expands sprites into unique quad vertices.

## CPU submission layout

`SpriteRequest` is the validated API input. It contains fixed-size values only. Accepted requests become the explicit `extern struct` `SpriteSubmission`, whose compile-time-asserted stride is 80 bytes and alignment is 8 bytes.

| Absolute offset | Bytes | Required alignment | Scalar representation | Field | Use |
| ---: | ---: | ---: | --- | --- | --- |
| 0 | 8 | 4 | two `f32` | `world_position` | Transferred after sorting |
| 8 | 4 | 4 | `f32` | `rotation` in radians | Transferred |
| 12 | 8 | 4 | two `f32` | `scale` | Transferred; this is both local sprite size and nonuniform scale |
| 20 | 8 | 4 | two `f32` | `pivot` in unit-quad coordinates | Transferred |
| 28 | 16 | 4 | four `f32` | `uv_rect = (min_u, min_v, max_u, max_v)` | Transferred |
| 44 | 16 | 4 | four `f32` | straight-alpha RGBA `tint` | Transferred |
| 60 | 4 | 4 | `u32` | `texture_page` | CPU-only; creates consecutive draw ranges and selects compatible GPU state |
| 64 | 2 | 2 | `i16` | `order.scene_layer` | CPU-only stable ordering |
| 66 | 2 | 2 | `i16` | `order.interaction_layer` | CPU-only stable ordering |
| 68 | 2 | 2 | `u16` | `order.actor_layer` | CPU-only stable ordering |
| 70 | 2 | 2 | `u16` | `order.body_part_layer` | CPU-only stable ordering |
| 72 | 8 | 8 | `u64` | `order.submission_index` | CPU-only final stable tie-breaker |

There is no CPU padding between semantic fields. The first four order fields occupy exactly eight bytes before the naturally required eight-byte alignment of `submission_index`. `@sizeOf`, `@alignOf`, and important `@offsetOf` values are compile-time assertions. No pointer, slice, optional, Zig `bool`, or unspecified enum representation is transferred.

## GPU and HLSL layout

Sorting converts each CPU record into the padding-free `extern struct` `GpuInstance`. Its compile-time-asserted stride is 60 bytes and alignment is 4 bytes.

| Byte offset | Bytes | Required alignment | Zig field | HLSL input | SDL format |
| ---: | ---: | ---: | --- | --- | --- |
| 0 | 8 | 4 | `world_position: [2]f32` | `float2 world_position : TEXCOORD1` | `FLOAT2` |
| 8 | 4 | 4 | `rotation: f32` | `float rotation : TEXCOORD2` | `FLOAT` |
| 12 | 8 | 4 | `scale: [2]f32` | `float2 scale : TEXCOORD3` | `FLOAT2` |
| 20 | 8 | 4 | `pivot: [2]f32` | `float2 pivot : TEXCOORD4` | `FLOAT2` |
| 28 | 16 | 4 | `uv_rect: [4]f32` | `float4 uv_rect : TEXCOORD5` | `FLOAT4` |
| 44 | 16 | 4 | `tint: [4]f32` | `float4 tint : TEXCOORD6` | `FLOAT4` |

The shared quad supplies only `float2 local_position : TEXCOORD0` from vertex slot 0. Instance slot 1 has pitch 60, `SDL_GPU_VERTEXINPUTRATE_INSTANCE`, and the pinned-header-required `instance_step_rate = 0`. D3D12 advances slot 1 once per instance. HLSL does not need `SV_InstanceID` because the per-instance input slot itself performs unique record selection.

The vertex camera is one 16-byte `float4` pushed to DXIL vertex uniform slot `b0, space1`; its `.xy` values contain the 640 by 480 viewport. Fragment resources retain Prompt 1's pinned DXIL mapping at `t0, space2` and `s0, space2`.

## Transform and UV semantics

The unit quad uses local corners `(0,0)` through `(1,1)`, with positive local Y upward. The shader evaluates this sequence:

1. Multiply the unit coordinate by `scale`; `scale` explicitly represents sprite size and nonuniform scaling.
2. Subtract `pivot * scale`, making rotation occur around that pivot.
3. Apply the two-dimensional rotation.
4. Add `world_position` after rotation.
5. Divide by viewport size and convert to clip space.

Negative scale is supported for deliberate mirroring. Zero scale is valid and collapses the quad to `world_position`. Every transform component must be finite. Pivot values are finite unit-quad coordinates; values outside `[0,1]` are allowed for deliberate off-sprite rotation centers.

UV origin is texture top-left, positive V points down, and bounds must be finite, ordered, and inside `[0,1]`. Reversed, empty, non-finite, or out-of-range rectangles fail before submission. Because the local quad's Y points up, HLSL interpolates V from `max_v` at local Y zero to `min_v` at local Y one. The smoke sprites select the red and yellow quadrants of the same uploaded procedural texture through distinct UV rectangles.

Tint and texture values use straight alpha. The graphics pipeline blends RGB as source-alpha/one-minus-source-alpha and alpha as one/one-minus-source-alpha. The opaque smoke texels therefore retain exact channel values within a one-code-value readback tolerance.

## Stable integer ordering and batching

The comparator is lexicographic: signed 16-bit scene layer, signed 16-bit interaction layer, unsigned 16-bit actor layer, unsigned 16-bit body-part layer, then unsigned 64-bit submission index. Public inputs use `i32` so invalid negative unsigned layers and values outside each destination range can be rejected without truncation. No field packing or arithmetic composition occurs, so comparison cannot overflow.

`submission_index` starts at zero in `beginFrame`, advances once for each accepted request, and is reset every frame. A frame accepts at most 16,384 submissions, so wraparound is unreachable by construction. Equal semantic keys preserve original submission order through the unique final index, even though the allocation-free sorting implementation need not itself be stable.

Ranges are generated only after semantic sorting. Consecutive equal texture pages form one range; page transitions form new ranges, and returning to an earlier page creates another range rather than reordering through an intervening page. Production currently exposes one page, so any nonzero identifier fails before GPU work and all 1,000 demonstration sprites form one range.

## Capacity and ownership

Initial CPU submission capacity, sorted capacity, range capacity, and each GPU instance slot are 1,024 records. The maximum is 16,384. Growth doubles capacity until the request fits, caps at the maximum, and uses overflow-checked byte multiplication. Empty and exactly-full batches are valid; one-past capacity grows to 2,048. Requests beyond the maximum and byte counts beyond `u32` fail meaningfully.

CPU growth allocates complete replacement submission, sorted, and range arrays before freeing old arrays, then copies accepted submissions and makes the replacement authoritative. Allocation failure leaves the old batch intact. The demonstration is preallocated for 1,000 records and marks the batch stabilized before its frame loop, so no steady-state CPU allocation occurs.

GPU growth creates all six replacement resources for three slots before touching old resources. An injected failure releases only the replacements. Successful replacement waits only the old slot fences, releases those fences and buffers, swaps the complete set, and then increments the growth counter. Old resources are never released while an in-flight slot can reference them.

## Frames in flight

The application asks SDL for three frames in flight and owns three fixed `FrameSlot` records. Each slot owns one 60-byte-stride GPU instance buffer, one upload transfer buffer of the same capacity, and at most one submission fence. Mapping and `SDL_UploadToGPUBuffer` use `cycle = false` because a slot cannot be reused until its own fence is signaled.

At slot reuse, `SDL_QueryGPUFence` first checks completion. A wait and the `frame_slot_fence_waits` increment occur only if that reused slot is still busy. The fence is then released. Successful submission stores the newly acquired fence and advances the ring. A failed frame does not advance the slot. Fence-acquisition fault injection waits and releases the acquired fence before returning. Device-idle waits occur only during final destruction or an exceptional submitted-command cleanup path, never in the ordinary frame loop.

Persistent shaders, pipeline, sampler, textures, shared quad buffers, and all six frame-slot buffers are created during initialization. Ordinary frames acquire command buffers, swapchain textures, and per-submit fences but create no persistent GPU resources. Runtime counters distinguish persistent resource creation/release from fence acquisition/release.

## Metrics

Per-frame metrics reset in `beginFrame`: submitted, visible, culled, sorted, ranges, actual submitted sprite draws, and uploaded bytes. Lifetime metrics separately track CPU capacity growth, allocation attempts, post-stabilization allocation attempts, GPU slot growth, frame-slot waits, frames, persistent resource creation/release, and fences.

Draw calls are committed only after a command buffer returns a valid submission fence. The window title is formatted into stack storage and displays current actual values. Copies, render-pass boundaries, blits, readback, and debug work do not increment sprite draw calls.
