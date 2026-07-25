const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const skeleton = @import("skeleton");

pub const maximum_vertices_per_definition: usize = 256;
pub const maximum_indices_per_definition: usize = 768;
pub const maximum_triangles_per_definition: usize = maximum_indices_per_definition / 3;
pub const minimum_triangle_double_area: f32 = 1e-7;

pub const Topology = enum(u8) {
    triangle_list,
    triangle_strip,
    line_list,
};

pub const BindingKind = enum(u8) {
    bound_anatomy_affine,
};

pub const DeformationBindingMetadata = struct {
    kind: BindingKind = .bound_anatomy_affine,
    maximum_influences_per_vertex: u8 = 1,

    pub fn validate(metadata: DeformationBindingMetadata) !void {
        if (metadata.kind != .bound_anatomy_affine) return error.UnsupportedDeformationBinding;
        if (metadata.maximum_influences_per_vertex != 1) return error.UnsupportedInfluenceCount;
    }
};

pub const MaterialReferenceInput = struct {
    stable_id: []const u8,
    texture_page: u32,
    tint: [4]f32,
};

pub const MaterialReference = struct {
    stable_id: skeleton.DebugName,
    texture_page: u32,
    tint: [4]f32,
};

pub const VertexInput = struct {
    local_position: math.Vec2,
    uv: [2]f32,
    deformation_weight: f32,
};

pub const Vertex = extern struct {
    local_position: math.Vec2,
    uv: [2]f32,
    deformation_weight: f32,
};

pub const DefinitionInput = struct {
    stable_id: []const u8,
    vertices: []const VertexInput,
    indices: []const u16,
    topology: Topology = .triangle_list,
    material: MaterialReferenceInput,
    deformation_binding: DeformationBindingMetadata = .{},
};

pub const DefinitionView = struct {
    stable_id: skeleton.DebugName,
    vertices: []const Vertex,
    indices: []const u16,
    topology: Topology,
    material: MaterialReference,
    deformation_binding: DeformationBindingMetadata,
    owner_token: usize,

    pub fn validate(view: DefinitionView) !void {
        if (view.owner_token == 0 or view.owner_token != @intFromPtr(view.vertices.ptr)) {
            return error.MeshDefinitionOwnershipMismatch;
        }
        try validateDefinitionData(
            view.vertices,
            view.indices,
            view.topology,
            view.material.tint,
            view.deformation_binding,
        );
    }
};

pub const Definition = struct {
    allocator: std.mem.Allocator,
    stable_id: skeleton.DebugName,
    vertices: []const Vertex,
    indices: []const u16,
    topology: Topology,
    material: MaterialReference,
    deformation_binding: DeformationBindingMetadata,

    pub fn init(allocator: std.mem.Allocator, input: DefinitionInput) !Definition {
        if (input.vertices.len == 0 or input.vertices.len > maximum_vertices_per_definition or
            input.indices.len == 0 or input.indices.len > maximum_indices_per_definition)
        {
            return error.MeshDefinitionCapacityExceeded;
        }
        const stable_id = try skeleton.DebugName.init(input.stable_id);
        const material_id = try skeleton.DebugName.init(input.material.stable_id);
        try validateMaterial(input.material.tint);
        try input.deformation_binding.validate();
        if (input.topology != .triangle_list) return error.UnsupportedMeshTopology;
        if (input.indices.len % 3 != 0) return error.InvalidTriangleListIndexCount;

        const vertices = allocator.alloc(Vertex, input.vertices.len) catch return error.AllocationFailure;
        errdefer allocator.free(vertices);
        for (input.vertices, 0..) |vertex, index| {
            try validateVertexInput(vertex);
            vertices[index] = .{
                .local_position = vertex.local_position,
                .uv = vertex.uv,
                .deformation_weight = vertex.deformation_weight,
            };
        }

        const indices = allocator.alloc(u16, input.indices.len) catch return error.AllocationFailure;
        errdefer allocator.free(indices);
        @memcpy(indices, input.indices);
        try validateIndexTopology(vertices, indices);

        return .{
            .allocator = allocator,
            .stable_id = stable_id,
            .vertices = vertices,
            .indices = indices,
            .topology = input.topology,
            .material = .{
                .stable_id = material_id,
                .texture_page = input.material.texture_page,
                .tint = input.material.tint,
            },
            .deformation_binding = input.deformation_binding,
        };
    }

    pub fn deinit(definition: *Definition) void {
        definition.allocator.free(definition.indices);
        definition.allocator.free(definition.vertices);
        definition.* = undefined;
    }

    pub fn view(definition: *const Definition) DefinitionView {
        return .{
            .stable_id = definition.stable_id,
            .vertices = definition.vertices,
            .indices = definition.indices,
            .topology = definition.topology,
            .material = definition.material,
            .deformation_binding = definition.deformation_binding,
            .owner_token = @intFromPtr(definition.vertices.ptr),
        };
    }
};

pub const BoundIdentity = union(enum) {
    anatomy_part: u16,
    attachment_point: u16,

    pub fn encoded(identity: BoundIdentity) u32 {
        return switch (identity) {
            .anatomy_part => |value| value,
            .attachment_point => |value| 0x1_0000 + @as(u32, value),
        };
    }
};

pub const InstanceState = struct {
    owning_character: u32 = 0,
    bound_identity: BoundIdentity = .{ .anatomy_part = 0 },
    binding_world: math.Mat3 = math.Mat3.identity(),
    resolved_deformation: math.Transform2D = math.Transform2D.identity(),
    update_serial: u64 = 0,

    pub fn update(
        state: *InstanceState,
        owning_character: u32,
        bound_identity: BoundIdentity,
        binding_world: math.Mat3,
        resolved_deformation: math.Transform2D,
    ) !void {
        if (owning_character == 0) return error.InvalidMeshCharacterOwner;
        if (!binding_world.isFinite() or !resolved_deformation.isFinite() or
            resolved_deformation.scale.x <= 0 or resolved_deformation.scale.y <= 0)
        {
            return error.InvalidMeshInstanceTransform;
        }
        state.owning_character = owning_character;
        state.bound_identity = bound_identity;
        state.binding_world = binding_world;
        state.resolved_deformation = resolved_deformation;
        state.update_serial +%= 1;
    }
};

pub const GpuBaseVertex = extern struct {
    local_position: [2]f32,
    uv: [2]f32,
    deformation_weight: f32,

    pub fn fromVertex(vertex: Vertex) GpuBaseVertex {
        return .{
            .local_position = vertex.local_position.toArray(),
            .uv = vertex.uv,
            .deformation_weight = vertex.deformation_weight,
        };
    }
};

pub const GpuInstance = extern struct {
    world_column_0: [2]f32,
    world_column_1: [2]f32,
    world_translation: [2]f32,
    deformation_translation: [2]f32,
    deformation_rotation: f32,
    deformation_scale: [2]f32,
    tint: [4]f32,
    camera_x_factor: f32,
};

comptime {
    if (@sizeOf(Vertex) != 20 or @alignOf(Vertex) != 4) @compileError("mesh Vertex layout changed unexpectedly");
    if (@sizeOf(GpuBaseVertex) != 20 or @alignOf(GpuBaseVertex) != 4) @compileError("GpuBaseVertex layout must match HLSL");
    if (@sizeOf(GpuInstance) != 64 or @alignOf(GpuInstance) != 4) @compileError("GpuInstance layout must be a 64-byte HLSL record");
    if (@offsetOf(GpuInstance, "world_column_0") != 0) @compileError("GpuInstance.world_column_0 offset mismatch");
    if (@offsetOf(GpuInstance, "world_column_1") != 8) @compileError("GpuInstance.world_column_1 offset mismatch");
    if (@offsetOf(GpuInstance, "world_translation") != 16) @compileError("GpuInstance.world_translation offset mismatch");
    if (@offsetOf(GpuInstance, "deformation_translation") != 24) @compileError("GpuInstance.deformation_translation offset mismatch");
    if (@offsetOf(GpuInstance, "deformation_rotation") != 32) @compileError("GpuInstance.deformation_rotation offset mismatch");
    if (@offsetOf(GpuInstance, "deformation_scale") != 36) @compileError("GpuInstance.deformation_scale offset mismatch");
    if (@offsetOf(GpuInstance, "tint") != 44) @compileError("GpuInstance.tint offset mismatch");
    if (@offsetOf(GpuInstance, "camera_x_factor") != 60) @compileError("GpuInstance.camera_x_factor offset mismatch");
}

pub fn makeGpuInstance(
    binding_world: math.Mat3,
    resolved_deformation: math.Transform2D,
    tint: [4]f32,
    camera_x_factor: f32,
) !GpuInstance {
    if (!binding_world.isFinite() or !resolved_deformation.isFinite() or
        resolved_deformation.scale.x <= 0 or resolved_deformation.scale.y <= 0)
    {
        return error.InvalidMeshInstanceTransform;
    }
    try validateMaterial(tint);
    if (!std.math.isFinite(camera_x_factor) or camera_x_factor < 0 or camera_x_factor > 1) {
        return error.InvalidCameraXFactor;
    }
    return .{
        .world_column_0 = .{ binding_world.values[0], binding_world.values[1] },
        .world_column_1 = .{ binding_world.values[3], binding_world.values[4] },
        .world_translation = .{ binding_world.values[6], binding_world.values[7] },
        .deformation_translation = resolved_deformation.translation.toArray(),
        .deformation_rotation = resolved_deformation.rotation_radians,
        .deformation_scale = resolved_deformation.scale.toArray(),
        .tint = tint,
        .camera_x_factor = camera_x_factor,
    };
}

pub fn deformedLocalPoint(vertex: Vertex, resolved_deformation: math.Transform2D) !math.Vec2 {
    if (!resolved_deformation.isFinite() or resolved_deformation.scale.x <= 0 or resolved_deformation.scale.y <= 0) {
        return error.InvalidMeshInstanceTransform;
    }
    const scaled = vertex.local_position.componentMul(resolved_deformation.scale);
    const sine = @sin(resolved_deformation.rotation_radians);
    const cosine = @cos(resolved_deformation.rotation_radians);
    const fully_deformed = math.Vec2{
        .x = cosine * scaled.x - sine * scaled.y + resolved_deformation.translation.x,
        .y = sine * scaled.x + cosine * scaled.y + resolved_deformation.translation.y,
    };
    return vertex.local_position.add(fully_deformed.sub(vertex.local_position).scale(vertex.deformation_weight));
}

fn validateDefinitionData(
    vertices: []const Vertex,
    indices: []const u16,
    topology: Topology,
    tint: [4]f32,
    binding: DeformationBindingMetadata,
) !void {
    if (vertices.len == 0 or vertices.len > maximum_vertices_per_definition or
        indices.len == 0 or indices.len > maximum_indices_per_definition)
    {
        return error.MeshDefinitionCapacityExceeded;
    }
    if (topology != .triangle_list) return error.UnsupportedMeshTopology;
    if (indices.len % 3 != 0) return error.InvalidTriangleListIndexCount;
    try validateMaterial(tint);
    try binding.validate();
    for (vertices) |vertex| {
        try validateVertexInput(.{
            .local_position = vertex.local_position,
            .uv = vertex.uv,
            .deformation_weight = vertex.deformation_weight,
        });
    }
    try validateIndexTopology(vertices, indices);
}

fn validateVertexInput(vertex: VertexInput) !void {
    if (!vertex.local_position.isFinite()) return error.NonFiniteMeshVertex;
    if (!allFinite(&vertex.uv)) return error.NonFiniteMeshUv;
    if (vertex.uv[0] < 0 or vertex.uv[0] > 1 or vertex.uv[1] < 0 or vertex.uv[1] > 1) {
        return error.InvalidMeshUv;
    }
    if (!std.math.isFinite(vertex.deformation_weight) or
        vertex.deformation_weight < 0 or vertex.deformation_weight > 1)
    {
        return error.InvalidDeformationWeight;
    }
}

fn validateIndexTopology(vertices: []const Vertex, indices: []const u16) !void {
    var triangle_start: usize = 0;
    while (triangle_start < indices.len) : (triangle_start += 3) {
        const first = @as(usize, indices[triangle_start]);
        const second = @as(usize, indices[triangle_start + 1]);
        const third = @as(usize, indices[triangle_start + 2]);
        if (first >= vertices.len or second >= vertices.len or third >= vertices.len) {
            return error.MeshIndexOutOfRange;
        }
        if (first == second or second == third or first == third) return error.DegenerateMeshTriangle;
        const a = vertices[first].local_position;
        const b = vertices[second].local_position;
        const c = vertices[third].local_position;
        const double_area = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
        if (!std.math.isFinite(double_area) or @abs(double_area) < minimum_triangle_double_area) {
            return error.DegenerateMeshTriangle;
        }
    }
}

fn validateMaterial(tint: [4]f32) !void {
    if (!allFinite(&tint)) return error.InvalidMeshMaterial;
    for (tint) |component| {
        if (component < 0 or component > 1) return error.InvalidMeshMaterial;
    }
}

fn allFinite(values: []const f32) bool {
    for (values) |value| {
        if (!std.math.isFinite(value)) return false;
    }
    return true;
}
