const std = @import("std");
const art_pack = @import("art_pack");

pub const texture_page_count: usize = 2;
pub const visual_count: usize = 7;
pub const theme_count: usize = 2;
pub const region_count: usize = visual_count * theme_count;
pub const binding_count: usize = region_count;

pub const ThemeId = enum(u8) {
    violet_crystal_ruin,
    neutral_debug,

    pub fn next(value: ThemeId) ThemeId {
        return switch (value) {
            .violet_crystal_ruin => .neutral_debug,
            .neutral_debug => .violet_crystal_ruin,
        };
    }
};

pub const VisualRole = enum(u8) {
    far_backdrop,
    midground_structure,
    terrain_body,
    foreground_frame,
    decorative_ledge,
    accent_cluster,
    surface_white,
};

pub const violet_page_id: art_pack.TexturePageId = @enumFromInt(71);
pub const debug_page_id: art_pack.TexturePageId = @enumFromInt(72);
pub const violet_view: art_pack.ViewId = @enumFromInt(71);
pub const debug_view: art_pack.ViewId = @enumFromInt(72);

pub const page_inputs = [_]art_pack.TexturePageInput{
    .{
        .id = violet_page_id,
        .stable_name = "p26_violet_crystal_ruin_atlas",
        .asset_path = "art/environment_violet_crystal_ruin_atlas.png",
        .sampling = .nearest,
        .expected_width = 1024,
        .expected_height = 1024,
    },
    .{
        .id = debug_page_id,
        .stable_name = "p26_neutral_debug_atlas",
        .asset_path = "art/environment_neutral_debug_atlas.png",
        .sampling = .nearest,
        .expected_width = 1024,
        .expected_height = 1024,
    },
};

const source_rects = [_]art_pack.PixelRect{
    .{ .x = 0, .y = 0, .width = 1024, .height = 512 },
    .{ .x = 0, .y = 512, .width = 512, .height = 256 },
    .{ .x = 512, .y = 512, .width = 512, .height = 256 },
    .{ .x = 0, .y = 768, .width = 512, .height = 256 },
    .{ .x = 512, .y = 768, .width = 256, .height = 256 },
    .{ .x = 768, .y = 768, .width = 256, .height = 256 },
    .{ .x = 1020, .y = 1020, .width = 4, .height = 4 },
};

const authored_sizes = [_][2]f32{
    .{ 24, 12 },
    .{ 12, 6 },
    .{ 12, 4 },
    .{ 10, 5 },
    .{ 4.6, 3.0 },
    .{ 4.6, 4.6 },
    .{ 1, 1 },
};

const semantic_names = [_][]const u8{
    "environment_far_backdrop",
    "environment_midground_structure",
    "environment_terrain_body",
    "environment_foreground_frame",
    "environment_decorative_ledge",
    "environment_accent_cluster",
    "environment_surface_white",
};

pub const region_inputs = makeRegionInputs();
pub const binding_inputs = makeBindingInputs();

pub fn definitionInput() art_pack.DefinitionInput {
    return .{
        .stable_name = "prompt26_environment_theme_art",
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
        theme: ThemeId,
        role: VisualRole,
    ) !art_pack.ResolvedVisual {
        return definition.art.resolve(
            .environment,
            semanticId(role),
            viewId(theme),
        );
    }

    pub fn validateComplete(definition: *const Definition) !void {
        if (definition.art.pages.len != texture_page_count or
            definition.art.regions.len != region_count or
            definition.art.bindings.len != binding_count)
        {
            return error.EnvironmentArtCountMismatch;
        }
        for (std.enums.values(ThemeId)) |theme| {
            for (std.enums.values(VisualRole)) |role| {
                const visual = try definition.resolve(theme, role);
                if (visual.texture_page != @intFromEnum(theme)) {
                    return error.EnvironmentArtPageMismatch;
                }
            }
        }
    }
};

pub fn semanticId(role: VisualRole) art_pack.VisualSemanticId {
    return @enumFromInt(@as(u32, 26_000) + @as(u32, @intFromEnum(role)));
}

pub fn viewId(theme: ThemeId) art_pack.ViewId {
    return switch (theme) {
        .violet_crystal_ruin => violet_view,
        .neutral_debug => debug_view,
    };
}

fn regionId(theme: ThemeId, role: VisualRole) art_pack.AtlasRegionId {
    return @enumFromInt(
        @as(u32, 26_000) +
            @as(u32, @intFromEnum(theme)) * @as(u32, visual_count) +
            @as(u32, @intFromEnum(role)),
    );
}

fn makeRegionInputs() [region_count]art_pack.AtlasRegionInput {
    var result: [region_count]art_pack.AtlasRegionInput = undefined;
    for (std.enums.values(ThemeId)) |theme| {
        for (std.enums.values(VisualRole)) |role| {
            const index: usize =
                @as(usize, @intFromEnum(theme)) * visual_count + @as(usize, @intFromEnum(role));
            result[index] = .{
                .id = regionId(theme, role),
                .stable_name = std.fmt.comptimePrint(
                    "{s}_{s}",
                    .{ @tagName(theme), @tagName(role) },
                ),
                .page_id = switch (theme) {
                    .violet_crystal_ruin => violet_page_id,
                    .neutral_debug => debug_page_id,
                },
                .source = source_rects[@intFromEnum(role)],
                .authored_size = authored_sizes[@intFromEnum(role)],
                .pivot = .{ 0.5, 0.5 },
            };
        }
    }
    return result;
}

fn makeBindingInputs() [binding_count]art_pack.VisualBindingInput {
    var result: [binding_count]art_pack.VisualBindingInput = undefined;
    for (std.enums.values(ThemeId)) |theme| {
        for (std.enums.values(VisualRole)) |role| {
            const index: usize =
                @as(usize, @intFromEnum(theme)) * visual_count + @as(usize, @intFromEnum(role));
            result[index] = .{
                .kind = .environment,
                .semantic_id = semanticId(role),
                .semantic_name = semantic_names[@intFromEnum(role)],
                .view_id = viewId(theme),
                .region_id = regionId(theme, role),
            };
        }
    }
    return result;
}
