const std = @import("std");
const client_module = @import("engine_smoke_client");
const renderer_module = @import("sdl_gpu_renderer");
const fault_injection = @import("fault_injection");

pub const proof_frame_count: u32 = 6;

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    if (arguments.len > 1) {
        if (arguments.len == 2 and std.mem.eql(u8, arguments[1], "--gpu-smoke")) {
            try runGpuSmoke(init.io);
            return;
        }
        return error.UnknownArgument;
    }
    const allocator = std.heap.page_allocator;

    var client = try client_module.Client.init(allocator);
    var client_live = true;
    defer if (client_live) client.deinit() catch |err| {
        std.debug.panic("engine-smoke RuntimeScene cleanup failed: {s}", .{@errorName(err)});
    };

    const initial_observation = try client.observe(0);
    if (!initial_observation.handle.eql(client.entity_handle) or
        !initial_observation.entity_id.eql(client.entity_id) or
        !initial_observation.effective_enabled)
    {
        return error.InitialRuntimeSceneObservationMismatch;
    }
    try client.setPosition(client_module.moved_position);
    const moved_observation = try client.observe(1);
    if (moved_observation.publication_generation <= initial_observation.publication_generation or
        moved_observation.local_transform.translation.x != client_module.moved_position[0] or
        moved_observation.local_transform.translation.y != client_module.moved_position[1])
    {
        return error.RuntimeSceneMutationNotObserved;
    }
    const render_request = try client.renderRequest(moved_observation);

    var renderer = try renderer_module.Renderer.init(allocator, true, null);
    var renderer_live = true;
    defer if (renderer_live) renderer.deinit();
    try renderer.initializeUnifiedQueue();
    try renderer.initializeCapture();
    const backend = try renderer.backendName();
    if (!std.mem.eql(u8, backend, "direct3d12")) return error.WrongGpuDriver;

    const initial_resources = renderer.metrics();
    const queue = renderer.renderQueue();
    queue.markStabilized();
    var rendered_frames: u32 = 0;
    var draw_calls: u32 = 0;
    for (0..proof_frame_count) |_| {
        queue.beginFrame();
        _ = try queue.submitSprite(render_request);
        const prepared = queue.prepare();
        if (prepared.sprites.len != 1 or prepared.ranges.len != 1) {
            return error.InvalidPreparedRenderWork;
        }
        const rendered = try renderer.renderUnifiedToWindow(prepared);
        renderer.recordFrameResult(rendered);
        if (!rendered) return error.IndependentWindowFrameUnavailable;
        if (queue.frame_metrics.sprite_draws != 1 or
            queue.frame_metrics.submitted_sprites != 1)
        {
            return error.IndependentDrawSubmissionMismatch;
        }
        rendered_frames += 1;
        draw_calls += queue.frame_metrics.sprite_draws;
    }

    const steady_resources = renderer.metrics();
    if (steady_resources.gpu_resource_creations != initial_resources.gpu_resource_creations or
        steady_resources.upload_buffer_growths != initial_resources.upload_buffer_growths or
        queue.lifetime_metrics.cpu_allocations_after_stabilization != 0)
    {
        return error.UnexpectedSteadyStateGrowth;
    }
    const steady_queue_allocations =
        queue.lifetime_metrics.cpu_allocations_after_stabilization;

    queue.beginFrame();
    _ = try queue.submitSprite(render_request);
    var capture = try renderer.captureUnified(queue.prepare());
    const distinct_pixels = countPixelsDifferentFromFirst(capture.bytes());
    capture.deinit();
    if (distinct_pixels == 0) return error.IndependentReadbackWasUniform;
    const post_capture_resources = renderer.metrics();
    if (post_capture_resources.gpu_resource_creations != initial_resources.gpu_resource_creations) {
        return error.ReadbackCreatedUnexpectedGpuResource;
    }

    const final_observation = try client.observe(proof_frame_count + 1);
    if (!final_observation.entity_id.eql(initial_observation.entity_id) or
        !final_observation.handle.eql(initial_observation.handle) or
        final_observation.local_transform.translation.x != client_module.moved_position[0] or
        final_observation.local_transform.translation.y != client_module.moved_position[1])
    {
        return error.FinalRuntimeSceneObservationMismatch;
    }
    try client.deinit();
    client_live = false;

    const final_resources = renderer.deinitWithMetrics();
    renderer_live = false;
    if (final_resources.gpu_resource_creations != final_resources.gpu_resource_releases or
        final_resources.fence_acquisitions != final_resources.fence_releases)
    {
        return error.RendererResourceLeak;
    }

    std.log.info(
        "engine smoke passed: backend={s} frames={d} draw_calls={d} readback_changed_pixels={d} entity_handle_valid={} lifecycle=world_persistent publication_generation={d}",
        .{
            "direct3d12",
            rendered_frames,
            draw_calls,
            distinct_pixels,
            final_observation.handle.isValid(),
            final_observation.publication_generation,
        },
    );
    std.log.info(
        "engine smoke resources: initial_created={d} initial_released={d} steady_created={d} steady_queue_allocations={d} final_created={d} final_released={d} final_fences_acquired={d} final_fences_released={d}",
        .{
            initial_resources.gpu_resource_creations,
            initial_resources.gpu_resource_releases,
            steady_resources.gpu_resource_creations,
            steady_queue_allocations,
            final_resources.gpu_resource_creations,
            final_resources.gpu_resource_releases,
            final_resources.fence_acquisitions,
            final_resources.fence_releases,
        },
    );
}

fn runGpuSmoke(io: std.Io) !void {
    for (fault_injection.initialization_stages) |stage| {
        var attempt = renderer_module.Renderer.init(
            std.heap.page_allocator,
            true,
            .{ .fail_after = stage },
        ) catch |err| {
            if (err != error.InjectedInitializationFailure) {
                std.log.err(
                    "renderer initialization cleanup check failed before {s}: {s}",
                    .{ @tagName(stage), @errorName(err) },
                );
                return err;
            }
            std.log.info(
                "renderer initialization cleanup check passed after {s}",
                .{@tagName(stage)},
            );
            continue;
        };
        attempt.deinit();
        return error.FaultInjectionDidNotTrigger;
    }

    _ = io;
    var renderer = try renderer_module.Renderer.init(
        std.heap.page_allocator,
        true,
        null,
    );
    var renderer_live = true;
    defer if (renderer_live) renderer.deinit();
    try renderer.runRuntimeFaultChecks();
    try renderer.runSmoke();
    const final_resources = renderer.deinitWithMetrics();
    renderer_live = false;
    if (final_resources.gpu_resource_creations != final_resources.gpu_resource_releases or
        final_resources.fence_acquisitions != final_resources.fence_releases)
    {
        return error.RendererResourceLeak;
    }
}

fn countPixelsDifferentFromFirst(rgba: []const u8) usize {
    if (rgba.len < 4 or rgba.len % 4 != 0) return 0;
    const first = rgba[0..4];
    var count: usize = 0;
    var offset: usize = 4;
    while (offset < rgba.len) : (offset += 4) {
        if (!std.mem.eql(u8, first, rgba[offset .. offset + 4])) count += 1;
    }
    return count;
}
