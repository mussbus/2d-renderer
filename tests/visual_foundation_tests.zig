const std = @import("std");
const input = @import("input");
const interaction = @import("interaction");
const handshake = @import("handshake");
const presentation_view = @import("presentation_view");
const render_queue = @import("render_queue");
const visual_foundation = @import("visual_foundation");

test "Prompt 27 bounded real-art foundation route proves presentation interaction and reset" {
    var scene = try visual_foundation.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var script = visual_foundation.ScriptedInput{};
    var snapshots = input.SnapshotBuilder{};
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    queue.markStabilized();

    for (0..visual_foundation.required_frames) |_| {
        const snapshot = try snapshots.update(script.nextRaw(&scene));
        try scene.updateFrame(1.0 / 60.0, snapshot);
        try script.observe(&scene);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
        scene.recordRendering(queue.frame_metrics);
    }
    try scene.validateComplete(&script);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

test "interaction presentation data can select front without a second interaction subsystem" {
    var scene = try visual_foundation.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const synthetic = try handshake.definitionWithPresentation(
        &scene.integrated.production.animations,
        interaction.PresentationDefinition{
            .role_views = .{ .front, .front },
            .suppress_automatic_view = true,
            .occlusion_profile = .none,
        },
    );
    try std.testing.expectEqual(
        @as(?presentation_view.View, .front),
        synthetic.presentation.viewForRole(.initiator),
    );
    try std.testing.expectEqual(
        @as(?presentation_view.View, .front),
        synthetic.presentation.viewForRole(.receiver),
    );
    try std.testing.expect(synthetic.presentation.suppress_automatic_view);
}

test "interaction presentation rejects suppression without both role views" {
    try std.testing.expectError(
        error.SuppressedInteractionViewMissing,
        (interaction.PresentationDefinition{
            .role_views = .{ .front, null },
            .suppress_automatic_view = true,
        }).validate(),
    );
}
