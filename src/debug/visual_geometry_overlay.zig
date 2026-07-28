const std = @import("std");
const math = @import("math");
const camera2d = @import("camera2d");
const image_decode = @import("image_decode");
const character_art = @import("character_art");
const wardrobe_art = @import("wardrobe_art");
const debug_draw = @import("debug_draw");
const sprite = @import("sprite_batch");
const visual = @import("visual_geometry");

pub const alpha_entry_capacity: usize =
    character_art.region_inputs.len + wardrobe_art.region_inputs.len;

const AlphaEntry = struct {
    region_id: u32,
    alpha: visual.AlphaGeometry,
};

pub const AlphaCatalog = struct {
    entries: [alpha_entry_capacity]AlphaEntry = undefined,
    count: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !AlphaCatalog {
        var catalog = AlphaCatalog{};
        for (character_art.page_inputs, 0..) |page, page_index| {
            var path_buffer: [256]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_buffer, "assets/{s}", .{page.asset_path});
            var decoded = try image_decode.decodePngFile(allocator, path, null);
            defer decoded.deinit();
            for (character_art.region_inputs) |region| {
                if (region.page_id != page.id) continue;
                try catalog.append(
                    @intFromEnum(region.id),
                    try visual.deriveAlphaGeometry(
                        decoded.pixels,
                        decoded.layout.width,
                        decoded.layout.height,
                        decoded.layout.row_bytes,
                        .{
                            .x = region.source.x,
                            .y = region.source.y,
                            .width = region.source.width,
                            .height = region.source.height,
                        },
                    ),
                );
            }
            _ = page_index;
        }
        for (wardrobe_art.page_inputs) |page| {
            var path_buffer: [256]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_buffer, "assets/{s}", .{page.asset_path});
            var decoded = try image_decode.decodePngFile(allocator, path, null);
            defer decoded.deinit();
            for (wardrobe_art.region_inputs) |region| {
                if (region.page_id != page.id) continue;
                try catalog.append(
                    @intFromEnum(region.id),
                    try visual.deriveAlphaGeometry(
                        decoded.pixels,
                        decoded.layout.width,
                        decoded.layout.height,
                        decoded.layout.row_bytes,
                        .{
                            .x = region.source.x,
                            .y = region.source.y,
                            .width = region.source.width,
                            .height = region.source.height,
                        },
                    ),
                );
            }
        }
        return catalog;
    }

    fn append(catalog: *AlphaCatalog, region_id: u32, alpha: visual.AlphaGeometry) !void {
        if (catalog.count == catalog.entries.len) return error.VisualGeometryAlphaCatalogCapacityExceeded;
        catalog.entries[catalog.count] = .{ .region_id = region_id, .alpha = alpha };
        catalog.count += 1;
    }

    pub fn find(catalog: *const AlphaCatalog, region_id: u32) !visual.AlphaGeometry {
        for (catalog.entries[0..catalog.count]) |entry| {
            if (entry.region_id == region_id) return entry.alpha;
        }
        return error.MissingVisualGeometryAlphaEntry;
    }
};

pub fn build(
    commands: *debug_draw.CommandBuffer,
    trace: *const visual.Trace,
    alpha_catalog: *const AlphaCatalog,
    camera: camera2d.Camera2D,
) !void {
    commands.beginFrame();
    for (trace.records[0..trace.count]) |record| {
        if (!overlayRole(record.role)) continue;
        const alpha = try alpha_catalog.find(record.region_id);
        const color = ownerColor(record.owner);
        if (record.mesh) |mesh_trace| {
            var index: usize = 0;
            while (index + 2 < mesh_trace.index_count) : (index += 3) {
                const a = mesh_trace.vertices[mesh_trace.indices[index]].world;
                const b = mesh_trace.vertices[mesh_trace.indices[index + 1]].world;
                const c = mesh_trace.vertices[mesh_trace.indices[index + 2]].world;
                try commands.addLine(a, b, color);
                try commands.addLine(b, c, color);
                try commands.addLine(c, a, color);
            }
        } else {
            const local_corners = [_][2]f32{
                alpha.visibleUvToLocal(.{ 0, 0 }),
                alpha.visibleUvToLocal(.{ 1, 0 }),
                alpha.visibleUvToLocal(.{ 1, 1 }),
                alpha.visibleUvToLocal(.{ 0, 1 }),
            };
            var corners: [4]math.Vec2 = undefined;
            for (local_corners, 0..) |local, index| {
                const world = sprite.localPointToWorld(record.request, local);
                corners[index] = .{ .x = world[0], .y = world[1] };
            }
            for (0..4) |index| {
                try commands.addLine(corners[index], corners[(index + 1) % 4], color);
            }
        }
        try commands.addMarker(.{
            .x = record.request.world_position[0],
            .y = record.request.world_position[1],
        }, .{ 1, 0.86, 0.1, 1 });
        for (record.geometry.landmarks[0..record.geometry.landmark_count]) |landmark| {
            const resolved = try visual.resolveLandmark(record, alpha, landmark.kind, camera);
            try commands.addMarker(resolved.world, landmarkColor(landmark.kind));
        }
        try addRoleAxes(commands, record, alpha, camera);
    }

    for ([_]u32{ 1, 2 }) |character_id| {
        for ([_]visual.Side{ .left, .right }) |side| {
            const foot = findRecord(trace, character_id, .foot, side) orelse continue;
            const shoe = findRecord(trace, character_id, .shoe, side) orelse continue;
            const foot_alpha = try alpha_catalog.find(foot.region_id);
            const shoe_alpha = try alpha_catalog.find(shoe.region_id);
            for ([_]visual.LandmarkKind{ .ankle, .heel, .toe }) |kind| {
                const foot_point = try visual.resolveLandmark(foot.*, foot_alpha, kind, camera);
                const shoe_point = try visual.resolveLandmark(shoe.*, shoe_alpha, kind, camera);
                try commands.addLine(foot_point.world, shoe_point.world, .{ 1, 0.1, 0.1, 1 });
            }
        }
    }
}

fn overlayRole(role: visual.Role) bool {
    return switch (role) {
        .torso,
        .pelvis,
        .upper_arm,
        .forearm,
        .hand,
        .thigh,
        .shin,
        .foot,
        .torso_garment,
        .lower_garment,
        .sleeve,
        .glove,
        .legwear,
        .shoe,
        .headwear,
        => true,
        else => false,
    };
}

fn ownerColor(owner: visual.Owner) debug_draw.Color {
    return switch (owner) {
        .anatomy => .{ 0.1, 1, 0.3, 1 },
        .base_presentation => .{ 0.4, 1, 0.4, 1 },
        .clothing => .{ 0.1, 0.8, 1, 1 },
        .equipment => .{ 1, 0.2, 0.2, 1 },
        .accessory => .{ 0.8, 0.3, 1, 1 },
    };
}

fn landmarkColor(kind: visual.LandmarkKind) debug_draw.Color {
    return switch (kind) {
        .heel, .sole_back => .{ 1, 0.2, 0.2, 1 },
        .toe, .sole_front => .{ 1, 0.65, 0.1, 1 },
        .ankle, .wrist, .elbow, .knee, .shoulder, .hip => .{ 1, 1, 0.15, 1 },
        else => .{ 0.9, 0.9, 0.9, 1 },
    };
}

fn addRoleAxes(
    commands: *debug_draw.CommandBuffer,
    record: visual.TraceRecord,
    alpha: visual.AlphaGeometry,
    camera: camera2d.Camera2D,
) !void {
    const axis = switch (record.role) {
        .foot, .shoe => .{ visual.LandmarkKind.heel, visual.LandmarkKind.toe },
        .upper_arm => .{ visual.LandmarkKind.shoulder, visual.LandmarkKind.elbow },
        .forearm => .{ visual.LandmarkKind.elbow, visual.LandmarkKind.wrist },
        .thigh => .{ visual.LandmarkKind.hip, visual.LandmarkKind.knee },
        .shin => .{ visual.LandmarkKind.knee, visual.LandmarkKind.ankle },
        .sleeve => .{
            visual.LandmarkKind.proximal,
            visual.LandmarkKind.distal,
        },
        .legwear => .{ visual.LandmarkKind.proximal, visual.LandmarkKind.ankle },
        else => return,
    };
    const from = visual.resolveLandmark(record, alpha, axis[0], camera) catch return;
    const to = visual.resolveLandmark(record, alpha, axis[1], camera) catch return;
    try commands.addLine(from.world, to.world, .{ 1, 0, 1, 1 });
    if (record.role == .foot or record.role == .shoe) {
        const sole_back = try visual.resolveLandmark(record, alpha, .sole_back, camera);
        const sole_front = try visual.resolveLandmark(record, alpha, .sole_front, camera);
        try commands.addLine(sole_back.world, sole_front.world, .{ 0.1, 1, 1, 1 });
    }
}

fn findRecord(
    trace: *const visual.Trace,
    character_id: u32,
    role: visual.Role,
    side: visual.Side,
) ?*const visual.TraceRecord {
    for (trace.records[0..trace.count]) |*record| {
        if (record.character_id == character_id and record.role == role and record.side == side) return record;
    }
    return null;
}
