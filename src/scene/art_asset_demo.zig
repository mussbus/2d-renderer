const std = @import("std");
const art_pack = @import("art_pack");
const mesh = @import("deformable_mesh");
const math = @import("math");
const render_queue = @import("render_queue");
const sprite = @import("sprite_batch");

pub const mechanical_page_id: art_pack.TexturePageId = @enumFromInt(11);
pub const energy_page_id: art_pack.TexturePageId = @enumFromInt(29);

pub const character_emblem_id: art_pack.VisualSemanticId = @enumFromInt(101);
pub const equipment_module_id: art_pack.VisualSemanticId = @enumFromInt(205);
pub const environment_beacon_id: art_pack.VisualSemanticId = @enumFromInt(309);
pub const arbitrary_detail_view: art_pack.ViewId = @enumFromInt(37);

const region_mechanical_disc: art_pack.AtlasRegionId = @enumFromInt(1001);
const region_mechanical_gear: art_pack.AtlasRegionId = @enumFromInt(1002);
const region_mechanical_panel: art_pack.AtlasRegionId = @enumFromInt(1003);
const region_mechanical_badge: art_pack.AtlasRegionId = @enumFromInt(1004);
const region_energy_swirl: art_pack.AtlasRegionId = @enumFromInt(2001);
const region_energy_rings: art_pack.AtlasRegionId = @enumFromInt(2002);
const region_energy_burst: art_pack.AtlasRegionId = @enumFromInt(2003);
const region_energy_flame: art_pack.AtlasRegionId = @enumFromInt(2004);

pub const page_inputs = [_]art_pack.TexturePageInput{
    .{
        .id = mechanical_page_id,
        .stable_name = "mechanical_atlas",
        .asset_path = "art/p23_mechanical_atlas.png",
        .sampling = .nearest,
        .expected_width = 256,
        .expected_height = 256,
    },
    .{
        .id = energy_page_id,
        .stable_name = "energy_atlas",
        .asset_path = "art/p23_energy_atlas.png",
        .sampling = .nearest,
        .expected_width = 256,
        .expected_height = 256,
    },
};

pub const region_inputs = [_]art_pack.AtlasRegionInput{
    .{ .id = region_mechanical_disc, .stable_name = "mechanical_disc", .page_id = mechanical_page_id, .source = .{ .x = 16, .y = 14, .width = 95, .height = 96 }, .authored_size = .{ 1.18, 1.20 }, .pivot = .{ 0.50, 0.50 } },
    .{ .id = region_mechanical_gear, .stable_name = "mechanical_gear", .page_id = mechanical_page_id, .source = .{ .x = 150, .y = 15, .width = 90, .height = 95 }, .authored_size = .{ 1.14, 1.20 }, .pivot = .{ 0.50, 0.50 } },
    .{ .id = region_mechanical_panel, .stable_name = "mechanical_panel", .page_id = mechanical_page_id, .source = .{ .x = 17, .y = 140, .width = 91, .height = 102 }, .authored_size = .{ 1.10, 1.24 }, .pivot = .{ 0.47, 0.54 } },
    .{ .id = region_mechanical_badge, .stable_name = "mechanical_badge", .page_id = mechanical_page_id, .source = .{ .x = 145, .y = 143, .width = 97, .height = 86 }, .authored_size = .{ 1.20, 1.06 }, .pivot = .{ 0.52, 0.48 } },
    .{ .id = region_energy_swirl, .stable_name = "energy_swirl", .page_id = energy_page_id, .source = .{ .x = 27, .y = 19, .width = 78, .height = 93 }, .authored_size = .{ 1.02, 1.20 }, .pivot = .{ 0.50, 0.52 } },
    .{ .id = region_energy_rings, .stable_name = "energy_rings", .page_id = energy_page_id, .source = .{ .x = 151, .y = 16, .width = 70, .height = 96 }, .authored_size = .{ 0.96, 1.22 }, .pivot = .{ 0.48, 0.51 } },
    .{ .id = region_energy_burst, .stable_name = "energy_burst", .page_id = energy_page_id, .source = .{ .x = 23, .y = 143, .width = 87, .height = 88 }, .authored_size = .{ 1.14, 1.14 }, .pivot = .{ 0.50, 0.50 } },
    .{ .id = region_energy_flame, .stable_name = "energy_flame", .page_id = energy_page_id, .source = .{ .x = 145, .y = 141, .width = 84, .height = 95 }, .authored_size = .{ 1.08, 1.22 }, .pivot = .{ 0.50, 0.56 } },
};

pub const binding_inputs = [_]art_pack.VisualBindingInput{
    .{ .kind = .character, .semantic_id = character_emblem_id, .semantic_name = "character_emblem", .view_id = art_pack.side_view, .region_id = region_mechanical_disc },
    .{ .kind = .character, .semantic_id = character_emblem_id, .semantic_name = "character_emblem", .view_id = art_pack.front_view, .region_id = region_energy_swirl },
    .{ .kind = .character, .semantic_id = character_emblem_id, .semantic_name = "character_emblem", .view_id = arbitrary_detail_view, .region_id = region_mechanical_badge },
    .{ .kind = .equipment, .semantic_id = equipment_module_id, .semantic_name = "equipment_module", .view_id = art_pack.side_view, .region_id = region_mechanical_panel },
    .{ .kind = .equipment, .semantic_id = equipment_module_id, .semantic_name = "equipment_module", .view_id = art_pack.front_view, .region_id = region_energy_rings },
    .{ .kind = .environment, .semantic_id = environment_beacon_id, .semantic_name = "environment_beacon", .view_id = art_pack.side_view, .region_id = region_energy_burst },
    .{ .kind = .environment, .semantic_id = environment_beacon_id, .semantic_name = "environment_beacon", .view_id = art_pack.front_view, .region_id = region_energy_flame },
    .{ .kind = .environment, .semantic_id = environment_beacon_id, .semantic_name = "environment_beacon", .view_id = arbitrary_detail_view, .region_id = region_mechanical_gear },
};

pub fn definitionInput() art_pack.DefinitionInput {
    return .{
        .stable_name = "prompt23_original_art_pack",
        .pages = &page_inputs,
        .regions = &region_inputs,
        .bindings = &binding_inputs,
    };
}

const displayed_visual_count: usize = 6;
pub const mesh_definition_count: usize = 1;
pub const required_frames: u32 = 240;

pub const Scene = struct {
    definition: art_pack.Definition,
    displayed: [displayed_visual_count]art_pack.ResolvedVisual,
    energy_mesh: mesh.Definition,
    renderer_page_offset: u32,

    pub fn init(allocator: std.mem.Allocator, renderer_page_offset: u32) !Scene {
        var definition = try art_pack.Definition.init(allocator, definitionInput());
        errdefer definition.deinit();

        const displayed = [displayed_visual_count]art_pack.ResolvedVisual{
            try definition.resolve(.character, character_emblem_id, art_pack.side_view),
            try definition.resolve(.character, character_emblem_id, art_pack.front_view),
            try definition.resolve(.equipment, equipment_module_id, art_pack.side_view),
            try definition.resolve(.equipment, equipment_module_id, art_pack.front_view),
            try definition.resolve(.environment, environment_beacon_id, arbitrary_detail_view),
            try definition.resolve(.environment, environment_beacon_id, art_pack.side_view),
        };
        const mesh_visual = try definition.resolve(.environment, environment_beacon_id, art_pack.front_view);
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
