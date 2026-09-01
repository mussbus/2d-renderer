const std = @import("std");
const art_pack = @import("art_pack");
const equipment = @import("equipment");
const wardrobe_catalog = @import("wardrobe_catalog");
const visual_geometry = @import("visual_geometry");
const image_decode = @import("image_decode");

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
        .asset_path = "art/wardrobe_upper_atlas.png",
        .sampling = .linear,
        .expected_width = 1536,
        .expected_height = 1024,
    },
    .{
        .id = layers_page_id,
        .stable_name = "p25_wardrobe_layers_atlas",
        .asset_path = "art/wardrobe_layers_atlas.png",
        .sampling = .linear,
        .expected_width = 1536,
        .expected_height = 1024,
    },
    .{
        .id = lower_page_id,
        .stable_name = "p25_wardrobe_lower_atlas",
        .asset_path = "art/wardrobe_lower_atlas.png",
        .sampling = .linear,
        .expected_width = 1536,
        .expected_height = 1024,
    },
};

pub const region_inputs = makeRegionInputs();
pub const binding_inputs = makeBindingInputs();

const RegistrationAlphaEntry = struct {
    region_id: art_pack.AtlasRegionId,
    alpha: visual_geometry.AlphaGeometry,
};

const RegistrationAlphaCatalog = struct {
    entries: [region_inputs.len]RegistrationAlphaEntry = undefined,
    count: usize = 0,

    fn init() !RegistrationAlphaCatalog {
        var catalog = RegistrationAlphaCatalog{};
        for (page_inputs) |page| {
            var path_buffer: [256]u8 = undefined;
            const path = try std.fmt.bufPrint(
                &path_buffer,
                "assets/{s}",
                .{page.asset_path},
            );
            var decoded = try image_decode.decodePngFile(
                std.heap.smp_allocator,
                path,
                null,
            );
            defer decoded.deinit();
            for (region_inputs) |region| {
                if (region.page_id != page.id) continue;
                if (catalog.count == catalog.entries.len) {
                    return error.RegistrationAlphaCatalogCapacityExceeded;
                }
                catalog.entries[catalog.count] = .{
                    .region_id = region.id,
                    .alpha = try visual_geometry.deriveAlphaGeometry(
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
                };
                catalog.count += 1;
            }
        }
        if (catalog.count != catalog.entries.len) {
            return error.IncompleteRegistrationAlphaCatalog;
        }
        return catalog;
    }

    fn find(
        catalog: RegistrationAlphaCatalog,
        region_id: art_pack.AtlasRegionId,
    ) !visual_geometry.AlphaGeometry {
        for (catalog.entries[0..catalog.count]) |entry| {
            if (entry.region_id == region_id) return entry.alpha;
        }
        return error.MissingRegistrationAlphaGeometry;
    }
};

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
    registration_alpha: RegistrationAlphaCatalog,

    pub fn init(allocator: std.mem.Allocator) !Definition {
        var art = try art_pack.Definition.init(allocator, definitionInput());
        errdefer art.deinit();
        return .{
            .art = art,
            .registration_alpha = try RegistrationAlphaCatalog.init(),
        };
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

    pub fn registrationAlpha(
        definition: *const Definition,
        region_id: art_pack.AtlasRegionId,
    ) !visual_geometry.AlphaGeometry {
        return definition.registration_alpha.find(region_id);
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
    return alpha_tight_source_bounds[index][@intFromBool(front)];
}

// Deterministically derived at alpha >= 8 from the production atlases, with
// two source pixels of bounded sampling guard where cell bounds permit it.
// Authored sizes therefore describe visible garments rather than transparent
// 256 px authoring cells. The old padded cells were the root cause of clothing
// that rendered half-size and visibly off-center.
const alpha_tight_source_bounds = [_][2]art_pack.PixelRect{
    .{ .{ .x = 29, .y = 110, .width = 227, .height = 135 }, .{ .x = 256, .y = 116, .width = 256, .height = 131 } },
    .{ .{ .x = 512, .y = 24, .width = 191, .height = 232 }, .{ .x = 781, .y = 20, .width = 167, .height = 236 } },
    .{ .{ .x = 1086, .y = 102, .width = 116, .height = 154 }, .{ .x = 1301, .y = 101, .width = 143, .height = 155 } },
    .{ .{ .x = 79, .y = 353, .width = 141, .height = 95 }, .{ .x = 324, .y = 354, .width = 148, .height = 104 } },
    .{ .{ .x = 592, .y = 256, .width = 129, .height = 232 }, .{ .x = 799, .y = 256, .width = 131, .height = 233 } },
    .{ .{ .x = 1073, .y = 256, .width = 123, .height = 231 }, .{ .x = 1301, .y = 256, .width = 138, .height = 231 } },
    .{ .{ .x = 75, .y = 557, .width = 153, .height = 147 }, .{ .x = 324, .y = 559, .width = 147, .height = 153 } },
    .{ .{ .x = 598, .y = 531, .width = 115, .height = 172 }, .{ .x = 804, .y = 535, .width = 126, .height = 172 } },
    .{ .{ .x = 1059, .y = 523, .width = 132, .height = 200 }, .{ .x = 1290, .y = 524, .width = 154, .height = 205 } },
    .{ .{ .x = 79, .y = 775, .width = 127, .height = 181 }, .{ .x = 312, .y = 780, .width = 143, .height = 180 } },
    .{ .{ .x = 588, .y = 773, .width = 113, .height = 172 }, .{ .x = 796, .y = 771, .width = 127, .height = 178 } },
    .{ .{ .x = 1041, .y = 826, .width = 186, .height = 124 }, .{ .x = 1288, .y = 811, .width = 172, .height = 151 } },
    .{ .{ .x = 70, .y = 38, .width = 152, .height = 215 }, .{ .x = 256, .y = 38, .width = 228, .height = 215 } },
    .{ .{ .x = 582, .y = 50, .width = 130, .height = 206 }, .{ .x = 795, .y = 48, .width = 166, .height = 208 } },
    .{ .{ .x = 1052, .y = 38, .width = 228, .height = 218 }, .{ .x = 1280, .y = 35, .width = 174, .height = 221 } },
    .{ .{ .x = 93, .y = 302, .width = 137, .height = 197 }, .{ .x = 298, .y = 303, .width = 142, .height = 200 } },
    .{ .{ .x = 613, .y = 290, .width = 99, .height = 222 }, .{ .x = 846, .y = 289, .width = 69, .height = 223 } },
    .{ .{ .x = 1054, .y = 256, .width = 133, .height = 256 }, .{ .x = 1281, .y = 307, .width = 120, .height = 205 } },
    .{ .{ .x = 89, .y = 531, .width = 124, .height = 221 }, .{ .x = 298, .y = 536, .width = 133, .height = 213 } },
    .{ .{ .x = 608, .y = 512, .width = 88, .height = 245 }, .{ .x = 850, .y = 512, .width = 61, .height = 246 } },
    .{ .{ .x = 1060, .y = 512, .width = 118, .height = 250 }, .{ .x = 1304, .y = 512, .width = 72, .height = 252 } },
    .{ .{ .x = 88, .y = 821, .width = 118, .height = 120 }, .{ .x = 295, .y = 822, .width = 139, .height = 125 } },
    .{ .{ .x = 555, .y = 809, .width = 158, .height = 167 }, .{ .x = 780, .y = 813, .width = 185, .height = 160 } },
    .{ .{ .x = 1036, .y = 829, .width = 244, .height = 101 }, .{ .x = 1280, .y = 826, .width = 175, .height = 115 } },
    .{ .{ .x = 60, .y = 39, .width = 150, .height = 171 }, .{ .x = 260, .y = 37, .width = 203, .height = 172 } },
    .{ .{ .x = 555, .y = 43, .width = 213, .height = 167 }, .{ .x = 768, .y = 49, .width = 179, .height = 163 } },
    .{ .{ .x = 1039, .y = 30, .width = 241, .height = 226 }, .{ .x = 1280, .y = 29, .width = 149, .height = 227 } },
    .{ .{ .x = 59, .y = 262, .width = 147, .height = 231 }, .{ .x = 262, .y = 263, .width = 196, .height = 233 } },
    .{ .{ .x = 545, .y = 275, .width = 223, .height = 174 }, .{ .x = 768, .y = 284, .width = 177, .height = 168 } },
    .{ .{ .x = 1077, .y = 256, .width = 203, .height = 248 }, .{ .x = 1280, .y = 256, .width = 112, .height = 248 } },
    .{ .{ .x = 91, .y = 521, .width = 97, .height = 237 }, .{ .x = 278, .y = 520, .width = 123, .height = 238 } },
    .{ .{ .x = 555, .y = 539, .width = 213, .height = 180 }, .{ .x = 768, .y = 546, .width = 256, .height = 218 } },
    .{ .{ .x = 1024, .y = 524, .width = 256, .height = 244 }, .{ .x = 1280, .y = 525, .width = 147, .height = 243 } },
    .{ .{ .x = 98, .y = 771, .width = 93, .height = 218 }, .{ .x = 295, .y = 773, .width = 85, .height = 217 } },
    .{ .{ .x = 588, .y = 769, .width = 97, .height = 220 }, .{ .x = 789, .y = 772, .width = 88, .height = 218 } },
    .{ .{ .x = 1070, .y = 778, .width = 210, .height = 212 }, .{ .x = 1280, .y = 768, .width = 117, .height = 222 } },
};

fn makeRegionInputs() [region_count]art_pack.AtlasRegionInput {
    @setEvalBranchQuota(20_000);
    var result: [region_count]art_pack.AtlasRegionInput = undefined;
    for (wardrobe_catalog.visual_specs, 0..) |spec, index| {
        result[index * 2] = .{
            .id = regionId(index, false),
            .stable_name = std.fmt.comptimePrint("{s}_side", .{spec.stable_id}),
            .page_id = pageFor(index),
            .source = sourceRect(index, false),
            .authored_size = spec.side_authored_size orelse spec.authored_size,
            .pivot = spec.side_pivot orelse spec.pivot,
        };
        result[index * 2 + 1] = .{
            .id = regionId(index, true),
            .stable_name = std.fmt.comptimePrint("{s}_front", .{spec.stable_id}),
            .page_id = pageFor(index),
            .source = sourceRect(index, true),
            .authored_size = spec.front_authored_size orelse spec.authored_size,
            .pivot = spec.front_pivot orelse spec.pivot,
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
