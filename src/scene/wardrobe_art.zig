const std = @import("std");
const art_pack = @import("art_pack");
const equipment = @import("equipment");
const wardrobe_catalog = @import("wardrobe_catalog");

pub const texture_page_count: usize = 3;
pub const regions_per_visual: usize = 2;
pub const region_count: usize = wardrobe_catalog.visual_count * regions_per_visual;
pub const binding_count: usize = region_count;

pub const upper_page_id: art_pack.TexturePageId = @enumFromInt(61);
pub const layers_page_id: art_pack.TexturePageId = @enumFromInt(62);
pub const lower_page_id: art_pack.TexturePageId = @enumFromInt(63);

pub const page_inputs = [_]art_pack.TexturePageInput{
    .{
        .id = upper_page_id,
        .stable_name = "p25_wardrobe_upper_atlas",
        .asset_path = "art/p25_wardrobe_upper_atlas.png",
        .sampling = .linear,
        .expected_width = 1536,
        .expected_height = 1024,
    },
    .{
        .id = layers_page_id,
        .stable_name = "p25_wardrobe_layers_atlas",
        .asset_path = "art/p25_wardrobe_layers_atlas.png",
        .sampling = .linear,
        .expected_width = 1536,
        .expected_height = 1024,
    },
    .{
        .id = lower_page_id,
        .stable_name = "p25_wardrobe_lower_atlas",
        .asset_path = "art/p25_wardrobe_lower_atlas.png",
        .sampling = .linear,
        .expected_width = 1536,
        .expected_height = 1024,
    },
};

pub const region_inputs = makeRegionInputs();
pub const binding_inputs = makeBindingInputs();

pub fn definitionInput() art_pack.DefinitionInput {
    return .{
        .stable_name = "prompt25_modular_wardrobe_art",
        .pages = &page_inputs,
        .regions = &region_inputs,
        .bindings = &binding_inputs,
    };
}

pub const Definition = struct {
    art: art_pack.Definition,

    pub fn init(allocator: std.mem.Allocator) !Definition {
        return .{ .art = try art_pack.Definition.init(allocator, definitionInput()) };
    }

    pub fn deinit(definition: *Definition) void {
        definition.art.deinit();
        definition.* = undefined;
    }

    pub fn resolve(
        definition: *const Definition,
        semantic: equipment.PresentationSemanticId,
        front: bool,
    ) !art_pack.ResolvedVisual {
        return definition.art.resolve(
            .equipment,
            artSemantic(semantic),
            if (front) art_pack.front_view else art_pack.side_view,
        );
    }

    pub fn validateCatalog(
        definition: *const Definition,
        catalog: *const wardrobe_catalog.Catalog,
    ) !void {
        if (definition.art.pages.len != texture_page_count or
            definition.art.regions.len != region_count or
            definition.art.bindings.len != binding_count)
        {
            return error.WardrobeArtCountMismatch;
        }
        for (catalog.equipment_definition.visual_components) |component| {
            const semantic = component.presentation_semantic orelse
                return error.MissingPresentationSemantic;
            const side = try definition.resolve(semantic, false);
            const front = try definition.resolve(semantic, true);
            if (side.semantic_id != front.semantic_id or side.region_id == front.region_id) {
                return error.InvalidWardrobeViewPair;
            }
        }
    }
};

fn artSemantic(id: equipment.PresentationSemanticId) art_pack.VisualSemanticId {
    return @enumFromInt(@intFromEnum(id));
}

fn pageFor(index: usize) art_pack.TexturePageId {
    return ([_]art_pack.TexturePageId{
        upper_page_id,
        layers_page_id,
        lower_page_id,
    })[index / 12];
}

fn regionId(index: usize, front: bool) art_pack.AtlasRegionId {
    return @enumFromInt(7_000 + index * 2 + @intFromBool(front));
}

fn sourceRect(index: usize, front: bool) art_pack.PixelRect {
    // These two production components need alpha-tight extraction rather than
    // the generic 256 px authoring cell. The fixed cells contain substantial
    // transparent padding that made the shoe read as detached toe trim and
    // held the front blouse sleeve away from its shoulder anchor.
    if (index == 11) {
        return if (front)
            .{ .x = 1288, .y = 811, .width = 172, .height = 151 }
        else
            .{ .x = 1041, .y = 826, .width = 186, .height = 124 };
    }
    if (index == 17) {
        return if (front)
            .{ .x = 1281, .y = 307, .width = 120, .height = 205 }
        else
            .{ .x = 1054, .y = 256, .width = 133, .height = 256 };
    }
    const page_index = index % 12;
    const row = page_index / 3;
    const pair_column = page_index % 3;
    return .{
        .x = @intCast((pair_column * 2 + @intFromBool(front)) * 256),
        .y = @intCast(row * 256),
        .width = 256,
        .height = 256,
    };
}

fn makeRegionInputs() [region_count]art_pack.AtlasRegionInput {
    @setEvalBranchQuota(20_000);
    var result: [region_count]art_pack.AtlasRegionInput = undefined;
    for (wardrobe_catalog.visual_specs, 0..) |spec, index| {
        result[index * 2] = .{
            .id = regionId(index, false),
            .stable_name = std.fmt.comptimePrint("{s}_side", .{spec.stable_id}),
            .page_id = pageFor(index),
            .source = sourceRect(index, false),
            .authored_size = spec.authored_size,
            .pivot = spec.pivot,
        };
        result[index * 2 + 1] = .{
            .id = regionId(index, true),
            .stable_name = std.fmt.comptimePrint("{s}_front", .{spec.stable_id}),
            .page_id = pageFor(index),
            .source = sourceRect(index, true),
            .authored_size = spec.authored_size,
            .pivot = spec.pivot,
        };
    }
    return result;
}

fn makeBindingInputs() [binding_count]art_pack.VisualBindingInput {
    @setEvalBranchQuota(20_000);
    var result: [binding_count]art_pack.VisualBindingInput = undefined;
    for (wardrobe_catalog.visual_specs, 0..) |spec, index| {
        result[index * 2] = .{
            .kind = .equipment,
            .semantic_id = artSemantic(spec.semantic),
            .semantic_name = spec.stable_id,
            .view_id = art_pack.side_view,
            .region_id = regionId(index, false),
        };
        result[index * 2 + 1] = .{
            .kind = .equipment,
            .semantic_id = artSemantic(spec.semantic),
            .semantic_name = spec.stable_id,
            .view_id = art_pack.front_view,
            .region_id = regionId(index, true),
        };
    }
    return result;
}
