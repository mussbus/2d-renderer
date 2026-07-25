const std = @import("std");
const math = @import("math");
const mesh = @import("deformable_mesh");
const sprite = @import("sprite_batch");

pub const default_entry_capacity: usize = 2048;
pub const default_sprite_capacity: usize = 1792;
pub const default_mesh_capacity: usize = 256;
pub const maximum_entry_capacity: usize = sprite.maximum_capacity;
pub const maximum_mesh_capacity: usize = 1024;

pub const PrimitiveKind = enum(u8) {
    rigid_sprite,
    deformable_mesh,
};

pub const MeshRequest = struct {
    definition: mesh.DefinitionView,
    binding_world: math.Mat3,
    resolved_deformation: math.Transform2D,
    owning_character: u32,
    bound_identity: mesh.BoundIdentity,
    camera_x_factor: f32 = 1,
    order: sprite.OrderInput,
};

pub const MeshSubmission = struct {
    definition: mesh.DefinitionView,
    gpu_instance: mesh.GpuInstance,
    owning_character: u32,
    bound_identity: mesh.BoundIdentity,
    order: sprite.DrawOrderKey,
};

pub const MeshDraw = struct {
    definition: mesh.DefinitionView,
    first_instance: u32,
    instance_count: u32,
};

pub const Range = struct {
    kind: PrimitiveKind,
    texture_page: u32,
    first: u32,
    count: u32,
};

pub const FrameMetrics = struct {
    submitted_sprites: u32 = 0,
    submitted_meshes: u32 = 0,
    sorted_primitives: u32 = 0,
    sprite_ranges: u32 = 0,
    mesh_ranges: u32 = 0,
    sprite_draws: u32 = 0,
    mesh_draws: u32 = 0,
    sprite_upload_bytes: u32 = 0,
    mesh_upload_bytes: u32 = 0,
};

pub const LifetimeMetrics = struct {
    cpu_allocation_attempts: u64 = 0,
    cpu_allocations_after_stabilization: u64 = 0,
};

pub const PreparedQueue = struct {
    sprites: []const sprite.SpriteSubmission,
    meshes: []const MeshSubmission,
    mesh_draws: []const MeshDraw,
    ranges: []const Range,
};

const Entry = struct {
    kind: PrimitiveKind,
    source_index: u32,
    order: sprite.DrawOrderKey,
};

pub const UnifiedRenderQueue = struct {
    allocator: std.mem.Allocator,
    texture_page_count: u32,
    entries: []Entry,
    sorted_entries: []Entry,
    sprite_submissions: []sprite.SpriteSubmission,
    sorted_sprites: []sprite.SpriteSubmission,
    mesh_submissions: []MeshSubmission,
    sorted_meshes: []MeshSubmission,
    mesh_draws: []MeshDraw,
    ranges: []Range,
    entry_count: usize = 0,
    sprite_count: usize = 0,
    mesh_count: usize = 0,
    sorted_sprite_count: usize = 0,
    sorted_mesh_count: usize = 0,
    mesh_draw_count: usize = 0,
    range_count: usize = 0,
    stabilized: bool = false,
    frame_metrics: FrameMetrics = .{},
    lifetime_metrics: LifetimeMetrics = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        entry_capacity: usize,
        sprite_capacity: usize,
        mesh_capacity: usize,
        texture_page_count: u32,
    ) !UnifiedRenderQueue {
        if (entry_capacity == 0 or entry_capacity > maximum_entry_capacity or
            sprite_capacity == 0 or sprite_capacity > entry_capacity or
            mesh_capacity == 0 or mesh_capacity > maximum_mesh_capacity or
            mesh_capacity > entry_capacity or sprite_capacity + mesh_capacity < entry_capacity)
        {
            return error.InvalidRenderQueueCapacity;
        }
        if (texture_page_count == 0) return error.InvalidTexturePageCount;

        const entries = allocator.alloc(Entry, entry_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(entries);
        const sorted_entries = allocator.alloc(Entry, entry_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(sorted_entries);
        const sprite_submissions = allocator.alloc(sprite.SpriteSubmission, sprite_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(sprite_submissions);
        const sorted_sprites = allocator.alloc(sprite.SpriteSubmission, sprite_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(sorted_sprites);
        const mesh_submissions = allocator.alloc(MeshSubmission, mesh_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(mesh_submissions);
        const sorted_meshes = allocator.alloc(MeshSubmission, mesh_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(sorted_meshes);
        const mesh_draws = allocator.alloc(MeshDraw, mesh_capacity) catch return error.CpuAllocationFailure;
        errdefer allocator.free(mesh_draws);
        const ranges = allocator.alloc(Range, entry_capacity) catch return error.CpuAllocationFailure;

        return .{
            .allocator = allocator,
            .texture_page_count = texture_page_count,
            .entries = entries,
            .sorted_entries = sorted_entries,
            .sprite_submissions = sprite_submissions,
            .sorted_sprites = sorted_sprites,
            .mesh_submissions = mesh_submissions,
            .sorted_meshes = sorted_meshes,
            .mesh_draws = mesh_draws,
            .ranges = ranges,
            .lifetime_metrics = .{ .cpu_allocation_attempts = 8 },
        };
    }

    pub fn deinit(queue: *UnifiedRenderQueue) void {
        queue.allocator.free(queue.ranges);
        queue.allocator.free(queue.mesh_draws);
        queue.allocator.free(queue.sorted_meshes);
        queue.allocator.free(queue.mesh_submissions);
        queue.allocator.free(queue.sorted_sprites);
        queue.allocator.free(queue.sprite_submissions);
        queue.allocator.free(queue.sorted_entries);
        queue.allocator.free(queue.entries);
        queue.* = undefined;
    }

    pub fn beginFrame(queue: *UnifiedRenderQueue) void {
        queue.entry_count = 0;
        queue.sprite_count = 0;
        queue.mesh_count = 0;
        queue.sorted_sprite_count = 0;
        queue.sorted_mesh_count = 0;
        queue.mesh_draw_count = 0;
        queue.range_count = 0;
        queue.frame_metrics = .{};
    }

    pub fn markStabilized(queue: *UnifiedRenderQueue) void {
        queue.stabilized = true;
    }

    pub fn submitSprite(queue: *UnifiedRenderQueue, request: sprite.SpriteRequest) !sprite.DrawOrderKey {
        try sprite.validateRequest(request, queue.texture_page_count);
        if (queue.entry_count >= queue.entries.len) return error.RenderQueueCapacityExceeded;
        if (queue.sprite_count >= queue.sprite_submissions.len) return error.SpriteCapacityExceeded;
        const key = try sprite.validateOrder(request.order, @intCast(queue.entry_count));
        queue.sprite_submissions[queue.sprite_count] = .{
            .world_position = request.world_position,
            .rotation = request.rotation,
            .scale = request.scale,
            .pivot = request.pivot,
            .uv_rect = request.uv_rect,
            .tint = request.tint,
            .texture_page = request.texture_page,
            .camera_x_factor = request.camera_x_factor,
            .order = key,
        };
        queue.entries[queue.entry_count] = .{
            .kind = .rigid_sprite,
            .source_index = @intCast(queue.sprite_count),
            .order = key,
        };
        queue.sprite_count += 1;
        queue.entry_count += 1;
        queue.frame_metrics.submitted_sprites += 1;
        return key;
    }

    pub fn submitMesh(queue: *UnifiedRenderQueue, request: MeshRequest) !sprite.DrawOrderKey {
        try request.definition.validate();
        if (request.definition.material.texture_page >= queue.texture_page_count) return error.InvalidTexturePage;
        if (request.owning_character == 0) return error.InvalidMeshCharacterOwner;
        if (!request.binding_world.isFinite()) return error.InvalidMeshInstanceTransform;
        if (queue.entry_count >= queue.entries.len) return error.RenderQueueCapacityExceeded;
        if (queue.mesh_count >= queue.mesh_submissions.len) return error.MeshCapacityExceeded;
        const key = try sprite.validateOrder(request.order, @intCast(queue.entry_count));
        const gpu_instance = try mesh.makeGpuInstance(
            request.binding_world,
            request.resolved_deformation,
            request.definition.material.tint,
            request.camera_x_factor,
        );
        queue.mesh_submissions[queue.mesh_count] = .{
            .definition = request.definition,
            .gpu_instance = gpu_instance,
            .owning_character = request.owning_character,
            .bound_identity = request.bound_identity,
            .order = key,
        };
        queue.entries[queue.entry_count] = .{
            .kind = .deformable_mesh,
            .source_index = @intCast(queue.mesh_count),
            .order = key,
        };
        queue.mesh_count += 1;
        queue.entry_count += 1;
        queue.frame_metrics.submitted_meshes += 1;
        return key;
    }

    pub fn prepare(queue: *UnifiedRenderQueue) PreparedQueue {
        @memcpy(queue.sorted_entries[0..queue.entry_count], queue.entries[0..queue.entry_count]);
        std.mem.sort(Entry, queue.sorted_entries[0..queue.entry_count], {}, lessThanEntry);
        queue.sorted_sprite_count = 0;
        queue.sorted_mesh_count = 0;
        queue.mesh_draw_count = 0;
        queue.range_count = 0;

        for (queue.sorted_entries[0..queue.entry_count]) |entry| {
            switch (entry.kind) {
                .rigid_sprite => queue.appendPreparedSprite(entry),
                .deformable_mesh => queue.appendPreparedMesh(entry),
            }
        }
        queue.frame_metrics.sorted_primitives = @intCast(queue.entry_count);
        queue.frame_metrics.sprite_ranges = 0;
        queue.frame_metrics.mesh_ranges = 0;
        for (queue.ranges[0..queue.range_count]) |range| {
            switch (range.kind) {
                .rigid_sprite => queue.frame_metrics.sprite_ranges += 1,
                .deformable_mesh => queue.frame_metrics.mesh_ranges += 1,
            }
        }
        queue.frame_metrics.mesh_draws = @intCast(queue.mesh_draw_count);
        return .{
            .sprites = queue.sorted_sprites[0..queue.sorted_sprite_count],
            .meshes = queue.sorted_meshes[0..queue.sorted_mesh_count],
            .mesh_draws = queue.mesh_draws[0..queue.mesh_draw_count],
            .ranges = queue.ranges[0..queue.range_count],
        };
    }

    pub fn recordUploads(queue: *UnifiedRenderQueue, sprite_bytes: u32, mesh_bytes: u32) void {
        queue.frame_metrics.sprite_upload_bytes = sprite_bytes;
        queue.frame_metrics.mesh_upload_bytes = mesh_bytes;
    }

    pub fn recordDraws(queue: *UnifiedRenderQueue, sprite_draws: u32, mesh_draws: u32) void {
        queue.frame_metrics.sprite_draws += sprite_draws;
        queue.frame_metrics.mesh_draws = mesh_draws;
    }

    fn appendPreparedSprite(queue: *UnifiedRenderQueue, entry: Entry) void {
        const source = queue.sprite_submissions[entry.source_index];
        const destination_index = queue.sorted_sprite_count;
        queue.sorted_sprites[destination_index] = source;
        queue.sorted_sprite_count += 1;

        if (queue.range_count > 0) {
            const previous = &queue.ranges[queue.range_count - 1];
            if (previous.kind == .rigid_sprite and
                previous.texture_page == source.texture_page and
                @as(usize, previous.first + previous.count) == destination_index)
            {
                previous.count += 1;
                return;
            }
        }
        queue.ranges[queue.range_count] = .{
            .kind = .rigid_sprite,
            .texture_page = source.texture_page,
            .first = @intCast(destination_index),
            .count = 1,
        };
        queue.range_count += 1;
    }

    fn appendPreparedMesh(queue: *UnifiedRenderQueue, entry: Entry) void {
        const source = queue.mesh_submissions[entry.source_index];
        const mesh_destination = queue.sorted_mesh_count;
        queue.sorted_meshes[mesh_destination] = source;
        queue.sorted_mesh_count += 1;

        var range_index: usize = undefined;
        if (queue.range_count > 0) {
            const previous_range = &queue.ranges[queue.range_count - 1];
            if (previous_range.kind == .deformable_mesh and
                previous_range.texture_page == source.definition.material.texture_page)
            {
                range_index = queue.range_count - 1;
            } else {
                range_index = queue.startMeshRange(source.definition.material.texture_page);
            }
        } else {
            range_index = queue.startMeshRange(source.definition.material.texture_page);
        }

        const range = &queue.ranges[range_index];
        if (range.count > 0) {
            const previous_draw = &queue.mesh_draws[range.first + range.count - 1];
            if (previous_draw.definition.owner_token == source.definition.owner_token and
                @as(usize, previous_draw.first_instance + previous_draw.instance_count) == mesh_destination)
            {
                previous_draw.instance_count += 1;
                return;
            }
        }
        queue.mesh_draws[queue.mesh_draw_count] = .{
            .definition = source.definition,
            .first_instance = @intCast(mesh_destination),
            .instance_count = 1,
        };
        queue.mesh_draw_count += 1;
        range.count += 1;
    }

    fn startMeshRange(queue: *UnifiedRenderQueue, texture_page: u32) usize {
        const index = queue.range_count;
        queue.ranges[index] = .{
            .kind = .deformable_mesh,
            .texture_page = texture_page,
            .first = @intCast(queue.mesh_draw_count),
            .count = 0,
        };
        queue.range_count += 1;
        return index;
    }
};

pub fn meshInstanceByteSize(count: usize) !u32 {
    const bytes = std.math.mul(usize, count, @sizeOf(mesh.GpuInstance)) catch return error.ByteSizeOverflow;
    if (bytes > std.math.maxInt(u32)) return error.ByteSizeOverflow;
    return @intCast(bytes);
}

fn lessThanEntry(_: void, left: Entry, right: Entry) bool {
    return sprite.keyLessThan(left.order, right.order);
}
