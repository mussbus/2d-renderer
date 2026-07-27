const std = @import("std");
const art_asset_demo = @import("art_asset_demo");
const art_pack = @import("art_pack");
const render_queue = @import("render_queue");

fn expectApproxArray(expected: []const f32, actual: []const f32, tolerance: f32) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_value, actual_value| {
        try std.testing.expectApproxEqAbs(expected_value, actual_value, tolerance);
    }
}

test "art pack owns immutable copied data and resolves stable semantic ids across arbitrary views" {
    var definition = try art_pack.Definition.init(std.testing.allocator, art_asset_demo.definitionInput());
    defer definition.deinit();

    try std.testing.expectEqual(@as(usize, 2), definition.pages.len);
    try std.testing.expectEqual(art_pack.SamplingPolicy.nearest, definition.pages[0].sampling);
    try std.testing.expectEqual(art_pack.SamplingPolicy.nearest, definition.pages[1].sampling);
    try std.testing.expectEqual(@as(u32, 256 * 256 * 4), try definition.pages[0].rgbaByteSize());

    const side = try definition.resolve(.character, art_asset_demo.character_emblem_id, art_pack.side_view);
    const front = try definition.resolve(.character, art_asset_demo.character_emblem_id, art_pack.front_view);
    const arbitrary = try definition.resolve(.character, art_asset_demo.character_emblem_id, art_asset_demo.arbitrary_detail_view);
    try std.testing.expect(side.region_id != front.region_id);
    try std.testing.expect(arbitrary.region_id != side.region_id);
    try std.testing.expectEqual(@as(u32, 0), side.texture_page);
    try std.testing.expectEqual(@as(u32, 1), front.texture_page);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0 / 256.0), side.uv_rect[0], 1e-7);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0 / 256.0), side.uv_rect[1], 1e-7);
    try std.testing.expectApproxEqAbs(@as(f32, 111.0 / 256.0), side.uv_rect[2], 1e-7);
    try std.testing.expectApproxEqAbs(@as(f32, 110.0 / 256.0), side.uv_rect[3], 1e-7);
    try std.testing.expectError(
        error.MissingVisualBinding,
        definition.resolve(.equipment, art_asset_demo.equipment_module_id, art_asset_demo.arbitrary_detail_view),
    );
}

test "sampling policy accepts a smooth future art page without changing renderer identity" {
    var pages = art_asset_demo.page_inputs;
    pages[1].sampling = .linear;
    var definition = try art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "future_smooth_pack",
        .pages = &pages,
        .regions = &.{},
        .bindings = &.{},
    });
    defer definition.deinit();
    try std.testing.expectEqual(art_pack.SamplingPolicy.nearest, definition.pages[0].sampling);
    try std.testing.expectEqual(art_pack.SamplingPolicy.linear, definition.pages[1].sampling);
}

test "atlas UV normalization and semantic resolution survive source declaration reordering" {
    var regions = art_asset_demo.region_inputs;
    std.mem.swap(art_pack.AtlasRegionInput, &regions[0], &regions[7]);
    var bindings = art_asset_demo.binding_inputs;
    std.mem.swap(art_pack.VisualBindingInput, &bindings[1], &bindings[6]);

    var reordered = try art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "reordered_pack",
        .pages = &art_asset_demo.page_inputs,
        .regions = &regions,
        .bindings = &bindings,
    });
    defer reordered.deinit();
    var canonical = try art_pack.Definition.init(std.testing.allocator, art_asset_demo.definitionInput());
    defer canonical.deinit();

    const expected = try canonical.resolve(.character, art_asset_demo.character_emblem_id, art_pack.front_view);
    const actual = try reordered.resolve(.character, art_asset_demo.character_emblem_id, art_pack.front_view);
    try std.testing.expectEqual(expected.region_id, actual.region_id);
    try expectApproxArray(&expected.uv_rect, &actual.uv_rect, 1e-7);
    try expectApproxArray(&expected.authored_size, &actual.authored_size, 1e-7);
    try expectApproxArray(&expected.pivot, &actual.pivot, 1e-7);
}

test "art metadata rejects duplicate ids names bindings and conflicting semantic names" {
    var duplicate_pages = art_asset_demo.page_inputs;
    duplicate_pages[1].id = duplicate_pages[0].id;
    try std.testing.expectError(error.DuplicateTexturePageId, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "duplicate_page_ids",
        .pages = &duplicate_pages,
        .regions = &.{},
        .bindings = &.{},
    }));

    duplicate_pages = art_asset_demo.page_inputs;
    duplicate_pages[1].stable_name = duplicate_pages[0].stable_name;
    try std.testing.expectError(error.DuplicateTexturePageName, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "duplicate_page_names",
        .pages = &duplicate_pages,
        .regions = &.{},
        .bindings = &.{},
    }));

    var duplicate_regions = art_asset_demo.region_inputs;
    duplicate_regions[1].id = duplicate_regions[0].id;
    try std.testing.expectError(error.DuplicateAtlasRegionId, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "duplicate_region_ids",
        .pages = &art_asset_demo.page_inputs,
        .regions = &duplicate_regions,
        .bindings = &.{},
    }));

    var duplicate_bindings = art_asset_demo.binding_inputs;
    duplicate_bindings[1] = duplicate_bindings[0];
    try std.testing.expectError(error.DuplicateVisualBinding, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "duplicate_bindings",
        .pages = &art_asset_demo.page_inputs,
        .regions = &art_asset_demo.region_inputs,
        .bindings = &duplicate_bindings,
    }));

    var conflicting_bindings = art_asset_demo.binding_inputs;
    conflicting_bindings[1].semantic_name = "wrong_semantic_name";
    try std.testing.expectError(error.ConflictingSemanticName, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "conflicting_names",
        .pages = &art_asset_demo.page_inputs,
        .regions = &art_asset_demo.region_inputs,
        .bindings = &conflicting_bindings,
    }));
}

test "art metadata rejects malformed paths dimensions regions geometry and references" {
    var pages = art_asset_demo.page_inputs;
    pages[0].asset_path = "reference/forbidden.png";
    try std.testing.expectError(error.ReferenceAssetPathForbidden, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "reference_path",
        .pages = &pages,
        .regions = &.{},
        .bindings = &.{},
    }));

    pages = art_asset_demo.page_inputs;
    pages[0].expected_width = 0;
    try std.testing.expectError(error.ZeroImageDimensions, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "zero_dimension",
        .pages = &pages,
        .regions = &.{},
        .bindings = &.{},
    }));

    var regions = art_asset_demo.region_inputs;
    regions[0].source.width = 0;
    try std.testing.expectError(error.ZeroAtlasRegion, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "zero_region",
        .pages = &art_asset_demo.page_inputs,
        .regions = &regions,
        .bindings = &.{},
    }));

    regions = art_asset_demo.region_inputs;
    regions[0].source.x = 250;
    try std.testing.expectError(error.AtlasRectangleOutOfBounds, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "out_of_bounds_region",
        .pages = &art_asset_demo.page_inputs,
        .regions = &regions,
        .bindings = &.{},
    }));

    regions = art_asset_demo.region_inputs;
    regions[0].source.x = std.math.maxInt(u32);
    try std.testing.expectError(error.AtlasRectangleOverflow, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "overflow_region",
        .pages = &art_asset_demo.page_inputs,
        .regions = &regions,
        .bindings = &.{},
    }));

    regions = art_asset_demo.region_inputs;
    regions[0].page_id = @enumFromInt(65_000);
    try std.testing.expectError(error.MissingTexturePage, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "missing_page",
        .pages = &art_asset_demo.page_inputs,
        .regions = &regions,
        .bindings = &.{},
    }));

    regions = art_asset_demo.region_inputs;
    regions[0].pivot[0] = 1.1;
    try std.testing.expectError(error.InvalidPivot, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "bad_pivot",
        .pages = &art_asset_demo.page_inputs,
        .regions = &regions,
        .bindings = &.{},
    }));

    var bindings = art_asset_demo.binding_inputs;
    bindings[0].region_id = @enumFromInt(4_000_000_000);
    try std.testing.expectError(error.MissingAtlasRegion, art_pack.Definition.init(std.testing.allocator, .{
        .stable_name = "missing_region",
        .pages = &art_asset_demo.page_inputs,
        .regions = &art_asset_demo.region_inputs,
        .bindings = &bindings,
    }));
}

test "art definition initialization exposes bounded allocation failure" {
    var bytes: [1]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&bytes);
    try std.testing.expectError(
        error.AllocationFailure,
        art_pack.Definition.init(fixed.allocator(), art_asset_demo.definitionInput()),
    );
    try std.testing.expectEqual(@as(usize, 0), fixed.end_index);
}

test "focused art scene submits sprites and mesh across pages without steady-state allocation" {
    var scene = try art_asset_demo.Scene.init(std.testing.allocator, 0);
    defer scene.deinit();
    const definitions = scene.meshDefinitions();
    try definitions[0].validate();

    var queue = try render_queue.UnifiedRenderQueue.init(std.testing.allocator, 32, 24, 8, 2);
    defer queue.deinit();
    queue.markStabilized();
    for (0..4) |frame| {
        queue.beginFrame();
        try std.testing.expectEqual(@as(u32, 7), try scene.submit(&queue, @intCast(frame)));
        const prepared = queue.prepare();
        try std.testing.expectEqual(@as(usize, 6), prepared.sprites.len);
        try std.testing.expectEqual(@as(usize, 1), prepared.meshes.len);
        try std.testing.expect(prepared.ranges.len >= 4);
        var page_zero = false;
        var page_one = false;
        for (prepared.ranges) |range| {
            page_zero = page_zero or range.texture_page == 0;
            page_one = page_one or range.texture_page == 1;
        }
        try std.testing.expect(page_zero and page_one);
    }
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}
