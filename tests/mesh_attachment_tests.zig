const std = @import("std");
const math = @import("math");
const mesh = @import("deformable_mesh");
const queue_module = @import("render_queue");
const mesh_catalog = @import("mesh_gpu_catalog");
const sprite = @import("sprite_batch");
const equipment = @import("equipment");
const mesh_demo = @import("mesh_attachment_demo");
const attachment_meshes = @import("attachment_meshes");

test "mesh definition validates finite vertices UVs topology indices capacities and degeneracy" {
    const valid_vertices = [_]mesh.VertexInput{
        vertex(0, 0, 0, 0, 0),
        vertex(1, 0, 1, 0, 0.5),
        vertex(0, 1, 0, 1, 1),
    };
    const valid_indices = [_]u16{ 0, 1, 2 };
    var definition = try mesh.Definition.init(std.testing.allocator, definitionInput(&valid_vertices, &valid_indices));
    defer definition.deinit();
    try definition.view().validate();
    try std.testing.expectEqualStrings("test_triangle_mesh", definition.stable_id.slice());
    try std.testing.expectEqual(@as(usize, 3), definition.vertices.len);
    try std.testing.expectEqual(@as(usize, 3), definition.indices.len);

    var invalid_vertices = valid_vertices;
    invalid_vertices[0].local_position.x = std.math.inf(f32);
    try std.testing.expectError(
        error.NonFiniteMeshVertex,
        mesh.Definition.init(std.testing.allocator, definitionInput(&invalid_vertices, &valid_indices)),
    );
    invalid_vertices = valid_vertices;
    invalid_vertices[0].uv[0] = std.math.nan(f32);
    try std.testing.expectError(
        error.NonFiniteMeshUv,
        mesh.Definition.init(std.testing.allocator, definitionInput(&invalid_vertices, &valid_indices)),
    );
    invalid_vertices = valid_vertices;
    invalid_vertices[0].uv[0] = 1.1;
    try std.testing.expectError(
        error.InvalidMeshUv,
        mesh.Definition.init(std.testing.allocator, definitionInput(&invalid_vertices, &valid_indices)),
    );

    var unsupported = definitionInput(&valid_vertices, &valid_indices);
    unsupported.topology = .triangle_strip;
    try std.testing.expectError(error.UnsupportedMeshTopology, mesh.Definition.init(std.testing.allocator, unsupported));
    const short_indices = [_]u16{ 0, 1 };
    try std.testing.expectError(
        error.InvalidTriangleListIndexCount,
        mesh.Definition.init(std.testing.allocator, definitionInput(&valid_vertices, &short_indices)),
    );
    const out_of_range = [_]u16{ 0, 1, 3 };
    try std.testing.expectError(
        error.MeshIndexOutOfRange,
        mesh.Definition.init(std.testing.allocator, definitionInput(&valid_vertices, &out_of_range)),
    );
    const repeated = [_]u16{ 0, 1, 1 };
    try std.testing.expectError(
        error.DegenerateMeshTriangle,
        mesh.Definition.init(std.testing.allocator, definitionInput(&valid_vertices, &repeated)),
    );
    const collinear_vertices = [_]mesh.VertexInput{
        vertex(0, 0, 0, 0, 0),
        vertex(1, 0, 0.5, 0, 0.5),
        vertex(2, 0, 1, 0, 1),
    };
    try std.testing.expectError(
        error.DegenerateMeshTriangle,
        mesh.Definition.init(std.testing.allocator, definitionInput(&collinear_vertices, &valid_indices)),
    );

    var too_many_vertices: [mesh.maximum_vertices_per_definition + 1]mesh.VertexInput = undefined;
    for (&too_many_vertices, 0..) |*value, index| {
        value.* = vertex(@floatFromInt(index), @floatFromInt(index % 2), 0, 0, 0);
    }
    try std.testing.expectError(
        error.MeshDefinitionCapacityExceeded,
        mesh.Definition.init(std.testing.allocator, definitionInput(&too_many_vertices, &valid_indices)),
    );
}

test "mesh ownership and partial allocation failure cleanup are explicit" {
    const vertices = [_]mesh.VertexInput{
        vertex(0, 0, 0, 0, 0),
        vertex(1, 0, 1, 0, 0.5),
        vertex(0, 1, 0, 1, 1),
    };
    const indices = [_]u16{ 0, 1, 2 };
    var storage: [@sizeOf(mesh.Vertex) * vertices.len]u8 align(@alignOf(mesh.Vertex)) = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    try std.testing.expectError(
        error.AllocationFailure,
        mesh.Definition.init(fixed.allocator(), definitionInput(&vertices, &indices)),
    );
    try std.testing.expectEqual(@as(usize, 0), fixed.end_index);

    var definition = try mesh.Definition.init(std.testing.allocator, definitionInput(&vertices, &indices));
    defer definition.deinit();
    const view = definition.view();
    try std.testing.expectEqual(@intFromPtr(definition.vertices.ptr), view.owner_token);
    var invalid_view = view;
    invalid_view.owner_token +%= 1;
    try std.testing.expectError(error.MeshDefinitionOwnershipMismatch, invalid_view.validate());
}

test "persistent topology catalog owns one immutable copy and cleans partial initialization" {
    var fitted = try attachment_meshes.initFittedGarmentMesh(std.testing.allocator);
    defer fitted.deinit();
    var sleeve = try attachment_meshes.initSleeveMesh(std.testing.allocator);
    defer sleeve.deinit();
    const definitions = [_]mesh.DefinitionView{ fitted.view(), sleeve.view() };
    var catalog = try mesh_catalog.Catalog.init(std.testing.allocator, &definitions);
    defer catalog.deinit();
    try std.testing.expectEqual(@as(usize, 2), catalog.entries.len);
    try std.testing.expectEqual(@as(u32, 0), (try catalog.find(fitted.view())).first_vertex);
    try std.testing.expectEqual(
        @as(u32, @intCast(fitted.vertices.len)),
        (try catalog.find(sleeve.view())).first_vertex,
    );
    try std.testing.expectEqual(
        @as(u32, @intCast((fitted.vertices.len + sleeve.vertices.len) * @sizeOf(mesh.GpuBaseVertex))),
        try catalog.vertexBytes(),
    );

    var storage: [@sizeOf(mesh_catalog.Entry) * 2]u8 align(@alignOf(mesh_catalog.Entry)) = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    try std.testing.expectError(error.AllocationFailure, mesh_catalog.Catalog.init(fixed.allocator(), &definitions));
    try std.testing.expectEqual(@as(usize, 0), fixed.end_index);
}

test "GPU mesh records match the shader contract and weighted deformation is bounded" {
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(mesh.GpuBaseVertex));
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(mesh.GpuInstance));
    try std.testing.expectEqual(@as(usize, 44), @offsetOf(mesh.GpuInstance, "tint"));
    try std.testing.expectEqual(@as(usize, 60), @offsetOf(mesh.GpuInstance, "camera_x_factor"));

    const source = mesh.Vertex{
        .local_position = .{ .x = 2, .y = 1 },
        .uv = .{ 0.5, 0.5 },
        .deformation_weight = 0.5,
    };
    const resolved = math.Transform2D.init(.{ .x = 2, .y = 0 }, 0, .{ .x = 2, .y = 1 });
    const point = try mesh.deformedLocalPoint(source, resolved);
    try std.testing.expectApproxEqAbs(@as(f32, 4), point.x, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 1), point.y, 1e-6);
}

test "unified queue interleaves semantic sprite and mesh order and batches compatible repeated meshes honestly" {
    var definition = try attachment_meshes.initSleeveMesh(std.testing.allocator);
    defer definition.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(std.testing.allocator, 8, 4, 4, 1);
    defer queue.deinit();
    queue.beginFrame();

    _ = try queue.submitSprite(spriteRequest(10));
    _ = try queue.submitMesh(meshRequest(definition.view(), 5, 1, .{ .anatomy_part = 1 }));
    _ = try queue.submitMesh(meshRequest(definition.view(), 23, 1, .{ .anatomy_part = 2 }));
    _ = try queue.submitMesh(meshRequest(definition.view(), 23, 1, .{ .anatomy_part = 3 }));
    _ = try queue.submitSprite(spriteRequest(31));
    const prepared = queue.prepare();

    try std.testing.expectEqual(@as(usize, 4), prepared.ranges.len);
    try std.testing.expectEqual(queue_module.PrimitiveKind.deformable_mesh, prepared.ranges[0].kind);
    try std.testing.expectEqual(queue_module.PrimitiveKind.rigid_sprite, prepared.ranges[1].kind);
    try std.testing.expectEqual(queue_module.PrimitiveKind.deformable_mesh, prepared.ranges[2].kind);
    try std.testing.expectEqual(queue_module.PrimitiveKind.rigid_sprite, prepared.ranges[3].kind);
    try std.testing.expectEqual(@as(usize, 2), prepared.mesh_draws.len);
    try std.testing.expectEqual(@as(u32, 1), prepared.mesh_draws[0].instance_count);
    try std.testing.expectEqual(@as(u32, 2), prepared.mesh_draws[1].instance_count);
    try std.testing.expectEqual(@as(u32, 2), queue.frame_metrics.mesh_ranges);
    try std.testing.expectEqual(@as(u32, 2), queue.frame_metrics.sprite_ranges);
    try std.testing.expectEqual(@as(u32, 2), queue.frame_metrics.mesh_draws);
}

test "topology-expanded equipment owns independent mesh state per binding and character" {
    const storage = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(storage);
    var fixed = std.heap.FixedBufferAllocator.init(storage);
    var scene = try mesh_demo.Scene.init(fixed.allocator());
    defer scene.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(fixed.allocator(), 256, 224, 32, 1);
    defer queue.deinit();
    const stabilized_bytes = fixed.end_index;
    queue.markStabilized();

    queue.beginFrame();
    const submitted = try scene.submit(&queue);
    const prepared = queue.prepare();
    try std.testing.expect(submitted > 0);
    try std.testing.expect(prepared.sprites.len > 0);
    try std.testing.expectEqual(@as(usize, 10), prepared.meshes.len);
    try std.testing.expectEqual(mesh_demo.expected_conventional_sleeves, scene.evidence.conventional_sleeves);
    try std.testing.expectEqual(mesh_demo.expected_nonstandard_sleeves, scene.evidence.nonstandard_sleeves);
    try std.testing.expect(scene.evidence.independent_repeated_state);
    try std.testing.expect(scene.evidence.independent_character_state);
    try std.testing.expect(scene.evidence.mirrored_facing);
    try expectDistinctSleeveState(&scene.nonstandard);

    const cape = try scene.equipment_definition.itemId("upper_back_cape");
    const initial_mesh_count = prepared.meshes.len;
    try scene.conventional.unequipItem(cape);
    queue.beginFrame();
    _ = try scene.submit(&queue);
    try std.testing.expectEqual(initial_mesh_count - 1, queue.prepare().meshes.len);
    try scene.conventional.equipItem(cape);

    try scene.updateFrame(1);
    queue.beginFrame();
    _ = try scene.submit(&queue);
    _ = queue.prepare();
    try std.testing.expect(scene.evidence.breathing_deformation_changed);
    try scene.updateFrame(120);
    queue.beginFrame();
    _ = try scene.submit(&queue);
    _ = queue.prepare();
    try std.testing.expect(scene.evidence.build_deformation_changed);
    try std.testing.expect(scene.evidence.deformation_changed);
    try std.testing.expectEqual(stabilized_bytes, fixed.end_index);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

test "queue capacities and allocation failure are deterministic" {
    var definition = try attachment_meshes.initSleeveMesh(std.testing.allocator);
    defer definition.deinit();
    var queue = try queue_module.UnifiedRenderQueue.init(std.testing.allocator, 2, 1, 1, 1);
    defer queue.deinit();
    queue.beginFrame();
    _ = try queue.submitSprite(spriteRequest(1));
    try std.testing.expectError(error.SpriteCapacityExceeded, queue.submitSprite(spriteRequest(2)));
    _ = try queue.submitMesh(meshRequest(definition.view(), 2, 1, .{ .anatomy_part = 1 }));
    try std.testing.expectError(
        error.RenderQueueCapacityExceeded,
        queue.submitMesh(meshRequest(definition.view(), 3, 1, .{ .anatomy_part = 2 })),
    );
    try std.testing.expectError(
        error.InvalidRenderQueueCapacity,
        queue_module.UnifiedRenderQueue.init(std.testing.allocator, 2, 3, 1, 1),
    );
    var bytes: [1]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&bytes);
    try std.testing.expectError(
        error.CpuAllocationFailure,
        queue_module.UnifiedRenderQueue.init(fixed.allocator(), 2, 1, 1, 1),
    );
}

fn definitionInput(vertices: []const mesh.VertexInput, indices: []const u16) mesh.DefinitionInput {
    return .{
        .stable_id = "test_triangle_mesh",
        .vertices = vertices,
        .indices = indices,
        .material = .{
            .stable_id = "test_material",
            .texture_page = 0,
            .tint = .{ 1, 1, 1, 1 },
        },
    };
}

fn vertex(x: f32, y: f32, u: f32, v: f32, weight: f32) mesh.VertexInput {
    return .{
        .local_position = .{ .x = x, .y = y },
        .uv = .{ u, v },
        .deformation_weight = weight,
    };
}

fn spriteRequest(layer: i32) sprite.SpriteRequest {
    return .{
        .world_position = .{ 0, 0 },
        .rotation = 0,
        .scale = .{ 1, 1 },
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 1, 1 },
        .tint = .{ 1, 1, 1, 1 },
        .texture_page = 0,
        .order = .{
            .scene_layer = 0,
            .interaction_layer = 0,
            .actor_layer = 0,
            .body_part_layer = layer,
        },
    };
}

fn meshRequest(
    definition: mesh.DefinitionView,
    layer: i32,
    owner: u32,
    bound_identity: mesh.BoundIdentity,
) queue_module.MeshRequest {
    return .{
        .definition = definition,
        .binding_world = math.Mat3.identity(),
        .resolved_deformation = math.Transform2D.identity(),
        .owning_character = owner,
        .bound_identity = bound_identity,
        .order = .{
            .scene_layer = 0,
            .interaction_layer = 0,
            .actor_layer = 0,
            .body_part_layer = layer,
        },
    };
}

fn expectDistinctSleeveState(instance: *const @import("character").CharacterInstance) !void {
    const loadout = &instance.equipment_loadout.?;
    const component_id = try loadout.definition.visualComponentId("topology_sleeve_mesh");
    var identities: [mesh_demo.expected_nonstandard_sleeves]u32 = undefined;
    var count: usize = 0;
    for (loadout.visuals()) |visual| {
        const recipe = try loadout.definition.recipe(visual.recipe);
        if (recipe.component != component_id) continue;
        try std.testing.expectEqual(instance.id.raw(), visual.owning_character);
        try std.testing.expectEqual(instance.id.raw(), visual.mesh_state.owning_character);
        for (identities[0..count]) |existing| {
            try std.testing.expect(existing != visual.mesh_state.bound_identity.encoded());
        }
        identities[count] = visual.mesh_state.bound_identity.encoded();
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, mesh_demo.expected_nonstandard_sleeves), count);
}
