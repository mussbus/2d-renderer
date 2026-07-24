const std = @import("std");

pub const initial_capacity: usize = 1024;
pub const maximum_capacity: usize = 16_384;
pub const growth_factor: usize = 2;

pub const OrderInput = struct {
    scene_layer: i32,
    interaction_layer: i32,
    actor_layer: i32,
    body_part_layer: i32,
};

pub const DrawOrderKey = extern struct {
    scene_layer: i16,
    interaction_layer: i16,
    actor_layer: u16,
    body_part_layer: u16,
    submission_index: u64,
};

pub const SpriteRequest = struct {
    world_position: [2]f32,
    rotation: f32,
    scale: [2]f32,
    pivot: [2]f32,
    uv_rect: [4]f32,
    tint: [4]f32,
    texture_page: u32,
    camera_x_factor: f32 = 1.0,
    order: OrderInput,
};

pub const SpriteSubmission = extern struct {
    world_position: [2]f32,
    rotation: f32,
    scale: [2]f32,
    pivot: [2]f32,
    uv_rect: [4]f32,
    tint: [4]f32,
    texture_page: u32,
    camera_x_factor: f32,
    order: DrawOrderKey,
};

pub const GpuInstance = extern struct {
    world_position: [2]f32,
    rotation: f32,
    scale: [2]f32,
    pivot: [2]f32,
    uv_rect: [4]f32,
    tint: [4]f32,
    camera_x_factor: f32,

    pub fn fromSubmission(sprite: SpriteSubmission) GpuInstance {
        return .{
            .world_position = sprite.world_position,
            .rotation = sprite.rotation,
            .scale = sprite.scale,
            .pivot = sprite.pivot,
            .uv_rect = sprite.uv_rect,
            .tint = sprite.tint,
            .camera_x_factor = sprite.camera_x_factor,
        };
    }
};

comptime {
    if (@sizeOf(DrawOrderKey) != 16 or @alignOf(DrawOrderKey) != 8) @compileError("DrawOrderKey layout must remain explicit");
    if (@offsetOf(DrawOrderKey, "submission_index") != 8) @compileError("DrawOrderKey.submission_index offset mismatch");
    if (@sizeOf(SpriteSubmission) != 88 or @alignOf(SpriteSubmission) != 8) @compileError("SpriteSubmission CPU stride mismatch");
    if (@offsetOf(SpriteSubmission, "texture_page") != 60) @compileError("SpriteSubmission.texture_page offset mismatch");
    if (@offsetOf(SpriteSubmission, "camera_x_factor") != 64) @compileError("SpriteSubmission.camera_x_factor offset mismatch");
    if (@offsetOf(SpriteSubmission, "order") != 72) @compileError("SpriteSubmission.order offset mismatch");
    if (@sizeOf(GpuInstance) != 64) @compileError("GpuInstance must have a 64-byte HLSL-matched stride");
    if (@alignOf(GpuInstance) != 4) @compileError("GpuInstance must be aligned to one f32 scalar");
    if (@offsetOf(GpuInstance, "world_position") != 0) @compileError("GpuInstance.world_position offset mismatch");
    if (@offsetOf(GpuInstance, "rotation") != 8) @compileError("GpuInstance.rotation offset mismatch");
    if (@offsetOf(GpuInstance, "scale") != 12) @compileError("GpuInstance.scale offset mismatch");
    if (@offsetOf(GpuInstance, "pivot") != 20) @compileError("GpuInstance.pivot offset mismatch");
    if (@offsetOf(GpuInstance, "uv_rect") != 28) @compileError("GpuInstance.uv_rect offset mismatch");
    if (@offsetOf(GpuInstance, "tint") != 44) @compileError("GpuInstance.tint offset mismatch");
    if (@offsetOf(GpuInstance, "camera_x_factor") != 60) @compileError("GpuInstance.camera_x_factor offset mismatch");
}

pub const DrawRange = struct {
    texture_page: u32,
    first_instance: u32,
    instance_count: u32,
};

pub const FrameMetrics = struct {
    submitted_sprites: u32 = 0,
    visible_sprites: u32 = 0,
    culled_sprites: u32 = 0,
    sorted_sprites: u32 = 0,
    draw_ranges: u32 = 0,
    draw_calls: u32 = 0,
    upload_bytes: u32 = 0,
};

pub const LifetimeMetrics = struct {
    cpu_submission_capacity_growths: u32 = 0,
    cpu_allocation_attempts: u64 = 0,
    cpu_allocations_after_stabilization: u64 = 0,
};

pub const PreparedBatch = struct {
    sprites: []const SpriteSubmission,
    ranges: []const DrawRange,
};

pub const BatchError = error{
    InvalidInitialCapacity,
    InvalidTexturePageCount,
    InvalidNonFiniteTransform,
    InvalidUvRectangle,
    InvalidTint,
    InvalidCameraXFactor,
    InvalidTexturePage,
    InvalidSceneLayer,
    InvalidInteractionLayer,
    InvalidActorLayer,
    InvalidBodyPartLayer,
    InstanceCapacityOverflow,
    ByteSizeOverflow,
    CpuAllocationFailure,
};

pub const SpriteBatch = struct {
    allocator: std.mem.Allocator,
    submissions: []SpriteSubmission,
    sorted: []SpriteSubmission,
    ranges: []DrawRange,
    count: usize = 0,
    range_count: usize = 0,
    texture_page_count: u32,
    stabilized: bool = false,
    frame_metrics: FrameMetrics = .{},
    lifetime_metrics: LifetimeMetrics = .{},

    pub fn init(allocator: std.mem.Allocator, requested_capacity: usize, texture_page_count: u32) BatchError!SpriteBatch {
        if (requested_capacity == 0 or requested_capacity > maximum_capacity) return error.InvalidInitialCapacity;
        if (texture_page_count == 0) return error.InvalidTexturePageCount;

        const submissions = allocator.alloc(SpriteSubmission, requested_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(submissions);
        const sorted = allocator.alloc(SpriteSubmission, requested_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(sorted);
        const ranges = allocator.alloc(DrawRange, requested_capacity) catch return error.CpuAllocationFailure;
        return .{
            .allocator = allocator,
            .submissions = submissions,
            .sorted = sorted,
            .ranges = ranges,
            .texture_page_count = texture_page_count,
            .lifetime_metrics = .{ .cpu_allocation_attempts = 3 },
        };
    }

    pub fn deinit(self: *SpriteBatch) void {
        self.allocator.free(self.ranges);
        self.allocator.free(self.sorted);
        self.allocator.free(self.submissions);
        self.* = undefined;
    }

    pub fn beginFrame(self: *SpriteBatch) void {
        self.count = 0;
        self.range_count = 0;
        self.frame_metrics = .{};
    }

    pub fn markStabilized(self: *SpriteBatch) void {
        self.stabilized = true;
    }

    pub fn submit(self: *SpriteBatch, request: SpriteRequest) BatchError!void {
        _ = try self.submitWithKey(request);
    }

    pub fn submitWithKey(self: *SpriteBatch, request: SpriteRequest) BatchError!DrawOrderKey {
        try validateRequest(request, self.texture_page_count);
        if (self.count >= maximum_capacity) return error.InstanceCapacityOverflow;
        try self.ensureCapacity(self.count + 1);

        const resolved_order = try validateOrder(request.order, @intCast(self.count));

        self.submissions[self.count] = .{
            .world_position = request.world_position,
            .rotation = request.rotation,
            .scale = request.scale,
            .pivot = request.pivot,
            .uv_rect = request.uv_rect,
            .tint = request.tint,
            .texture_page = request.texture_page,
            .camera_x_factor = request.camera_x_factor,
            .order = resolved_order,
        };
        self.count += 1;
        self.frame_metrics.submitted_sprites += 1;
        return resolved_order;
    }

    pub fn prepare(self: *SpriteBatch) PreparedBatch {
        @memcpy(self.sorted[0..self.count], self.submissions[0..self.count]);
        std.mem.sort(SpriteSubmission, self.sorted[0..self.count], {}, lessThanSubmission);
        self.range_count = generateRanges(self.sorted[0..self.count], self.ranges);

        self.frame_metrics.visible_sprites = @intCast(self.count);
        self.frame_metrics.culled_sprites = 0;
        self.frame_metrics.sorted_sprites = @intCast(self.count);
        self.frame_metrics.draw_ranges = @intCast(self.range_count);
        return .{
            .sprites = self.sorted[0..self.count],
            .ranges = self.ranges[0..self.range_count],
        };
    }

    pub fn recordUpload(self: *SpriteBatch, bytes: u32) void {
        self.frame_metrics.upload_bytes = bytes;
    }

    pub fn recordDraw(self: *SpriteBatch) void {
        self.frame_metrics.draw_calls += 1;
    }

    pub fn capacity(self: SpriteBatch) usize {
        return self.submissions.len;
    }

    fn ensureCapacity(self: *SpriteBatch, required: usize) BatchError!void {
        if (required <= self.submissions.len) return;
        const replacement_capacity = try nextCapacity(self.submissions.len, required, maximum_capacity);

        self.lifetime_metrics.cpu_allocation_attempts += 1;
        if (self.stabilized) self.lifetime_metrics.cpu_allocations_after_stabilization += 1;
        const new_submissions = self.allocator.alloc(SpriteSubmission, replacement_capacity) catch return error.CpuAllocationFailure;
        errdefer self.allocator.free(new_submissions);

        self.lifetime_metrics.cpu_allocation_attempts += 1;
        if (self.stabilized) self.lifetime_metrics.cpu_allocations_after_stabilization += 1;
        const new_sorted = self.allocator.alloc(SpriteSubmission, replacement_capacity) catch return error.CpuAllocationFailure;
        errdefer self.allocator.free(new_sorted);

        self.lifetime_metrics.cpu_allocation_attempts += 1;
        if (self.stabilized) self.lifetime_metrics.cpu_allocations_after_stabilization += 1;
        const new_ranges = self.allocator.alloc(DrawRange, replacement_capacity) catch return error.CpuAllocationFailure;

        @memcpy(new_submissions[0..self.count], self.submissions[0..self.count]);
        self.allocator.free(self.ranges);
        self.allocator.free(self.sorted);
        self.allocator.free(self.submissions);
        self.submissions = new_submissions;
        self.sorted = new_sorted;
        self.ranges = new_ranges;
        self.lifetime_metrics.cpu_submission_capacity_growths += 1;
    }
};

pub fn validateRequest(request: SpriteRequest, texture_page_count: u32) BatchError!void {
    try validateTransform(request);
    if (!allFinite(&request.uv_rect) or request.uv_rect[0] < 0 or request.uv_rect[1] < 0 or
        request.uv_rect[2] > 1 or request.uv_rect[3] > 1 or
        request.uv_rect[0] >= request.uv_rect[2] or request.uv_rect[1] >= request.uv_rect[3])
    {
        return error.InvalidUvRectangle;
    }
    if (!allFinite(&request.tint)) return error.InvalidTint;
    for (request.tint) |component| {
        if (component < 0 or component > 1) return error.InvalidTint;
    }
    if (!std.math.isFinite(request.camera_x_factor) or request.camera_x_factor < 0 or request.camera_x_factor > 1) {
        return error.InvalidCameraXFactor;
    }
    if (request.texture_page >= texture_page_count) return error.InvalidTexturePage;
    _ = try validateOrder(request.order, 0);
}

pub fn validateOrder(input: OrderInput, submission_index: u64) BatchError!DrawOrderKey {
    if (input.scene_layer < std.math.minInt(i16) or input.scene_layer > std.math.maxInt(i16)) return error.InvalidSceneLayer;
    if (input.interaction_layer < std.math.minInt(i16) or input.interaction_layer > std.math.maxInt(i16)) return error.InvalidInteractionLayer;
    if (input.actor_layer < 0 or input.actor_layer > std.math.maxInt(u16)) return error.InvalidActorLayer;
    if (input.body_part_layer < 0 or input.body_part_layer > std.math.maxInt(u16)) return error.InvalidBodyPartLayer;
    return .{
        .scene_layer = @intCast(input.scene_layer),
        .interaction_layer = @intCast(input.interaction_layer),
        .actor_layer = @intCast(input.actor_layer),
        .body_part_layer = @intCast(input.body_part_layer),
        .submission_index = submission_index,
    };
}

pub fn transformLocalPoint(request: SpriteRequest, local_point: [2]f32) BatchError![2]f32 {
    try validateTransform(request);
    if (!allFinite(&local_point)) return error.InvalidNonFiniteTransform;
    const pivoted_x = (local_point[0] - request.pivot[0]) * request.scale[0];
    const pivoted_y = (local_point[1] - request.pivot[1]) * request.scale[1];
    const sine = @sin(request.rotation);
    const cosine = @cos(request.rotation);
    return .{
        cosine * pivoted_x - sine * pivoted_y + request.world_position[0],
        sine * pivoted_x + cosine * pivoted_y + request.world_position[1],
    };
}

pub fn keyLessThan(left: DrawOrderKey, right: DrawOrderKey) bool {
    if (left.scene_layer != right.scene_layer) return left.scene_layer < right.scene_layer;
    if (left.interaction_layer != right.interaction_layer) return left.interaction_layer < right.interaction_layer;
    if (left.actor_layer != right.actor_layer) return left.actor_layer < right.actor_layer;
    if (left.body_part_layer != right.body_part_layer) return left.body_part_layer < right.body_part_layer;
    return left.submission_index < right.submission_index;
}

pub fn nextCapacity(current: usize, required: usize, maximum: usize) BatchError!usize {
    if (current == 0 or maximum == 0) return error.InvalidInitialCapacity;
    if (required > maximum) return error.InstanceCapacityOverflow;
    if (required <= current) return current;
    var candidate = current;
    while (candidate < required) {
        candidate = std.math.mul(usize, candidate, growth_factor) catch maximum;
        if (candidate > maximum) candidate = maximum;
        if (candidate < required and candidate == maximum) return error.InstanceCapacityOverflow;
    }
    return candidate;
}

pub fn instanceByteSize(count: usize) BatchError!u32 {
    const bytes = std.math.mul(usize, count, @sizeOf(GpuInstance)) catch return error.ByteSizeOverflow;
    if (bytes > std.math.maxInt(u32)) return error.ByteSizeOverflow;
    return @intCast(bytes);
}

fn generateRanges(sprites: []const SpriteSubmission, output: []DrawRange) usize {
    if (sprites.len == 0) return 0;
    var range_count: usize = 0;
    var first: usize = 0;
    var page = sprites[0].texture_page;
    for (sprites[1..], 1..) |sprite, index| {
        if (sprite.texture_page != page) {
            output[range_count] = .{
                .texture_page = page,
                .first_instance = @intCast(first),
                .instance_count = @intCast(index - first),
            };
            range_count += 1;
            first = index;
            page = sprite.texture_page;
        }
    }
    output[range_count] = .{
        .texture_page = page,
        .first_instance = @intCast(first),
        .instance_count = @intCast(sprites.len - first),
    };
    return range_count + 1;
}

fn lessThanSubmission(_: void, left: SpriteSubmission, right: SpriteSubmission) bool {
    return keyLessThan(left.order, right.order);
}

fn validateTransform(request: SpriteRequest) BatchError!void {
    if (!allFinite(&request.world_position) or !std.math.isFinite(request.rotation) or
        !allFinite(&request.scale) or !allFinite(&request.pivot))
    {
        return error.InvalidNonFiniteTransform;
    }
}

fn allFinite(values: []const f32) bool {
    for (values) |value| {
        if (!std.math.isFinite(value)) return false;
    }
    return true;
}
