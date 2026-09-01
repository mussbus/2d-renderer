const art_pack = @import("art_pack");

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
        .asset_path = "art/mechanical_atlas.png",
        .sampling = .nearest,
        .expected_width = 256,
        .expected_height = 256,
    },
    .{
        .id = energy_page_id,
        .stable_name = "energy_atlas",
        .asset_path = "art/energy_atlas.png",
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
