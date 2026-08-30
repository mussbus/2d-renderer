const std = @import("std");
const art_pack = @import("art_pack");
const art_asset_catalog = @import("art_asset_catalog");
const mesh = @import("deformable_mesh");
const math = @import("math");
const render_queue = @import("render_queue");

const displayed_visual_count: usize = 6;
pub const mesh_definition_count: usize = 1;
pub const required_frames: u32 = 240;

pub const Scene = struct {
    definition: art_pack.Definition,
    displayed: [displayed_visual_count]art_pack.ResolvedVisual,
    energy_mesh: mesh.Definition,
    renderer_page_offset: u32,

    pub fn init(allocator: std.mem.Allocator, renderer_page_offset: u32) !Scene {
        var definition = try art_pack.Definition.init(allocator, art_asset_catalog.definitionInput());
        errdefer definition.deinit();

        const displayed = [displayed_visual_count]art_pack.ResolvedVisual{
            try definition.resolve(.character, art_asset_catalog.character_emblem_id, art_pack.side_view),
            try definition.resolve(.character, art_asset_catalog.character_emblem_id, art_pack.front_view),
            try definition.resolve(.equipment, art_asset_catalog.equipment_module_id, art_pack.side_view),
            try definition.resolve(.equipment, art_asset_catalog.equipment_module_id, art_pack.front_view),
            try definition.resolve(.environment, art_asset_catalog.environment_beacon_id, art_asset_catalog.arbitrary_detail_view),
            try definition.resolve(.environment, art_asset_catalog.environment_beacon_id, art_pack.side_view),
        };
        const mesh_visual = try definition.resolve(.environment, art_asset_catalog.environment_beacon_id, art_pack.front_view);
        const uv = mesh_visual.uv_rect;
        const vertices = [_]mesh.VertexInput{
            .{ .local_position = .{ .x = -0.70, .y = -0.62 }, .uv = .{ uv[0], uv[1] }, .deformation_weight = 0.20 },
            .{ .local_position = .{ .x = 0.70, .y = -0.62 }, .uv = .{ uv[2], uv[1] }, .deformation_weight = 0.20 },
            .{ .local_position = .{ .x = 0.82, .y = 0.25 }, .uv = .{ uv[2], (uv[1] + uv[3]) * 0.58 }, .deformation_weight = 0.75 },
            .{ .local_position = .{ .x = 0.00, .y = 0.76 }, .uv = .{ (uv[0] + uv[2]) * 0.5, uv[3] }, .deformation_weight = 1.00 },
            .{ .local_position = .{ .x = -0.82, .y = 0.25 }, .uv = .{ uv[0], (uv[1] + uv[3]) * 0.58 }, .deformation_weight = 0.75 },
        };
        const indices = [_]u16{ 0, 1, 2, 0, 2, 4, 4, 2, 3 };
        var energy_mesh = try mesh.Definition.init(allocator, .{
            .stable_id = "p23_energy_deformable_mesh",
            .vertices = &vertices,
            .indices = &indices,
            .material = .{
                .stable_id = "p23_energy_atlas_material",
                .texture_page = renderer_page_offset + mesh_visual.texture_page,
                .tint = .{ 1, 1, 1, 0.92 },
            },
        });
        errdefer energy_mesh.deinit();

        return .{
            .definition = definition,
            .displayed = displayed,
            .energy_mesh = energy_mesh,
            .renderer_page_offset = renderer_page_offset,
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.energy_mesh.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn meshDefinitions(scene: *const Scene) [mesh_definition_count]mesh.DefinitionView {
        return .{scene.energy_mesh.view()};
    }

    pub fn submit(scene: *const Scene, queue: *render_queue.UnifiedRenderQueue, frame: u32) !u32 {
        const positions = [displayed_visual_count][2]f32{
            .{ -2.55, 0.62 },
            .{ -0.85, 0.62 },
            .{ 0.85, 0.62 },
            .{ 2.55, 0.62 },
            .{ -1.35, 2.20 },
            .{ 1.35, 2.20 },
        };
        const pulse = 1.0 + 0.035 * @sin(@as(f32, @floatFromInt(frame)) * 0.08);
        for (scene.displayed, 0..) |visual, index| {
            const scale_multiplier: f32 = if (visual.texture_page == 1) pulse else 1.0;
            _ = try queue.submitSprite(.{
                .world_position = positions[index],
                .rotation = if (index == 4) -0.08 else 0,
                .scale = .{
                    visual.authored_size[0] * scale_multiplier,
                    visual.authored_size[1] * scale_multiplier,
                },
                .pivot = visual.pivot,
                .uv_rect = visual.uv_rect,
                .tint = .{ 1, 1, 1, 1 },
                .texture_page = scene.renderer_page_offset + visual.texture_page,
                .order = .{
                    .scene_layer = 0,
                    .interaction_layer = 0,
                    .actor_layer = 1,
                    .body_part_layer = @intCast(index),
                },
            });
        }

        _ = try queue.submitMesh(.{
            .definition = scene.energy_mesh.view(),
            .binding_world = math.Mat3.translation(.{ .x = 0, .y = 3.72 }),
            .resolved_deformation = math.Transform2D.init(
                .{ .x = 0, .y = 0.04 * @sin(@as(f32, @floatFromInt(frame)) * 0.10) },
                0.05 * @sin(@as(f32, @floatFromInt(frame)) * 0.06),
                .{ .x = 1, .y = pulse },
            ),
            .owning_character = 1,
            .bound_identity = .{ .attachment_point = 37 },
            .order = .{
                .scene_layer = 0,
                .interaction_layer = 0,
                .actor_layer = 1,
                .body_part_layer = displayed_visual_count,
            },
        });
        return displayed_visual_count + 1;
    }
};
