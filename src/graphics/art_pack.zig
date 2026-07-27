const std = @import("std");

pub const maximum_texture_pages: usize = 8;
pub const maximum_atlas_regions: usize = 128;
pub const maximum_visual_bindings: usize = 256;
pub const maximum_stable_name_bytes: usize = 63;
pub const maximum_asset_path_bytes: usize = 191;

pub const TexturePageId = enum(u16) { _ };
pub const AtlasRegionId = enum(u32) { _ };
pub const VisualSemanticId = enum(u32) { _ };
pub const ViewId = enum(u16) { _ };

pub const side_view: ViewId = @enumFromInt(1);
pub const front_view: ViewId = @enumFromInt(2);

pub const SamplingPolicy = enum(u8) {
    nearest,
    linear,
};

pub const AssetKind = enum(u8) {
    character,
    equipment,
    environment,
};

pub const StableName = struct {
    bytes: [maximum_stable_name_bytes]u8 = [_]u8{0} ** maximum_stable_name_bytes,
    length: u8 = 0,

    pub fn init(source: []const u8) !StableName {
        if (source.len == 0) return error.EmptyStableName;
        if (source.len > maximum_stable_name_bytes) return error.StableNameTooLong;
        for (source) |byte| {
            if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '-' and byte != '.') {
                return error.InvalidStableName;
            }
        }
        var name = StableName{};
        @memcpy(name.bytes[0..source.len], source);
        name.length = @intCast(source.len);
        return name;
    }

    pub fn slice(name: *const StableName) []const u8 {
        return name.bytes[0..name.length];
    }

    pub fn eql(left: StableName, right: StableName) bool {
        return std.mem.eql(u8, left.slice(), right.slice());
    }
};

pub const AssetPath = struct {
    bytes: [maximum_asset_path_bytes]u8 = [_]u8{0} ** maximum_asset_path_bytes,
    length: u8 = 0,

    pub fn init(source: []const u8) !AssetPath {
        if (source.len == 0) return error.EmptyAssetPath;
        if (source.len > maximum_asset_path_bytes) return error.AssetPathTooLong;
        if (source[0] == '/' or source[0] == '\\' or std.mem.indexOfScalar(u8, source, ':') != null) {
            return error.AbsoluteAssetPath;
        }
        if (std.mem.indexOfScalar(u8, source, '\\') != null) return error.NonCanonicalAssetPath;
        if (!std.ascii.endsWithIgnoreCase(source, ".png")) return error.UnsupportedAssetExtension;

        var segments = std.mem.splitScalar(u8, source, '/');
        while (segments.next()) |segment| {
            if (segment.len == 0 or std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) {
                return error.NonCanonicalAssetPath;
            }
            if (std.ascii.eqlIgnoreCase(segment, "reference")) return error.ReferenceAssetPathForbidden;
        }

        var path = AssetPath{};
        @memcpy(path.bytes[0..source.len], source);
        path.length = @intCast(source.len);
        return path;
    }

    pub fn slice(path: *const AssetPath) []const u8 {
        return path.bytes[0..path.length];
    }
};

pub const PixelRect = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

pub const TexturePageInput = struct {
    id: TexturePageId,
    stable_name: []const u8,
    asset_path: []const u8,
    sampling: SamplingPolicy,
    expected_width: u32,
    expected_height: u32,
};

pub const AtlasRegionInput = struct {
    id: AtlasRegionId,
    stable_name: []const u8,
    page_id: TexturePageId,
    source: PixelRect,
    authored_size: [2]f32,
    pivot: [2]f32,
};

pub const VisualBindingInput = struct {
    kind: AssetKind,
    semantic_id: VisualSemanticId,
    semantic_name: []const u8,
    view_id: ViewId,
    region_id: AtlasRegionId,
};

pub const DefinitionInput = struct {
    stable_name: []const u8,
    pages: []const TexturePageInput,
    regions: []const AtlasRegionInput,
    bindings: []const VisualBindingInput,
};

pub const TexturePageDefinition = struct {
    id: TexturePageId,
    stable_name: StableName,
    asset_path: AssetPath,
    sampling: SamplingPolicy,
    expected_width: u32,
    expected_height: u32,
    runtime_index: u16,

    pub fn rgbaByteSize(page: TexturePageDefinition) !u32 {
        const pixels = std.math.mul(u32, page.expected_width, page.expected_height) catch return error.ImagePixelCountOverflow;
        return std.math.mul(u32, pixels, 4) catch return error.ImageByteSizeOverflow;
    }
};

pub const AtlasRegion = struct {
    id: AtlasRegionId,
    stable_name: StableName,
    page_id: TexturePageId,
    texture_page: u32,
    source: PixelRect,
    uv_rect: [4]f32,
    authored_size: [2]f32,
    pivot: [2]f32,
};

pub const VisualBinding = struct {
    kind: AssetKind,
    semantic_id: VisualSemanticId,
    semantic_name: StableName,
    view_id: ViewId,
    region_id: AtlasRegionId,
    region_index: u16,
};

pub const ResolvedVisual = struct {
    semantic_id: VisualSemanticId,
    view_id: ViewId,
    region_id: AtlasRegionId,
    texture_page: u32,
    uv_rect: [4]f32,
    authored_size: [2]f32,
    pivot: [2]f32,
};

pub const Definition = struct {
    allocator: std.mem.Allocator,
    stable_name: StableName,
    pages: []TexturePageDefinition,
    regions: []AtlasRegion,
    bindings: []VisualBinding,

    pub fn init(allocator: std.mem.Allocator, input: DefinitionInput) !Definition {
        if (input.pages.len == 0) return error.MissingTexturePages;
        if (input.pages.len > maximum_texture_pages or
            input.regions.len > maximum_atlas_regions or
            input.bindings.len > maximum_visual_bindings)
        {
            return error.ArtPackCapacityExceeded;
        }

        const pack_name = try StableName.init(input.stable_name);
        const pages = allocator.alloc(TexturePageDefinition, input.pages.len) catch return error.AllocationFailure;
        errdefer allocator.free(pages);
        for (input.pages, 0..) |page_input, index| {
            if (page_input.expected_width == 0 or page_input.expected_height == 0) return error.ZeroImageDimensions;
            for (pages[0..index]) |existing| {
                if (existing.id == page_input.id) return error.DuplicateTexturePageId;
            }
            const stable_name = try StableName.init(page_input.stable_name);
            for (pages[0..index]) |existing| {
                if (StableName.eql(existing.stable_name, stable_name)) return error.DuplicateTexturePageName;
            }
            pages[index] = .{
                .id = page_input.id,
                .stable_name = stable_name,
                .asset_path = try AssetPath.init(page_input.asset_path),
                .sampling = page_input.sampling,
                .expected_width = page_input.expected_width,
                .expected_height = page_input.expected_height,
                .runtime_index = @intCast(index),
            };
            _ = try pages[index].rgbaByteSize();
        }

        const regions = allocator.alloc(AtlasRegion, input.regions.len) catch return error.AllocationFailure;
        errdefer allocator.free(regions);
        for (input.regions, 0..) |region_input, index| {
            for (regions[0..index]) |existing| {
                if (existing.id == region_input.id) return error.DuplicateAtlasRegionId;
            }
            const stable_name = try StableName.init(region_input.stable_name);
            for (regions[0..index]) |existing| {
                if (StableName.eql(existing.stable_name, stable_name)) return error.DuplicateAtlasRegionName;
            }
            const page_index = findPageIndex(pages, region_input.page_id) orelse return error.MissingTexturePage;
            const page = pages[page_index];
            const uv_rect = try normalizedUv(page, region_input.source);
            try validateAuthoredGeometry(region_input.authored_size, region_input.pivot);
            regions[index] = .{
                .id = region_input.id,
                .stable_name = stable_name,
                .page_id = region_input.page_id,
                .texture_page = page.runtime_index,
                .source = region_input.source,
                .uv_rect = uv_rect,
                .authored_size = region_input.authored_size,
                .pivot = region_input.pivot,
            };
        }

        const bindings = allocator.alloc(VisualBinding, input.bindings.len) catch return error.AllocationFailure;
        errdefer allocator.free(bindings);
        for (input.bindings, 0..) |binding_input, index| {
            for (bindings[0..index]) |existing| {
                if (existing.kind == binding_input.kind and
                    existing.semantic_id == binding_input.semantic_id and
                    existing.view_id == binding_input.view_id)
                {
                    return error.DuplicateVisualBinding;
                }
            }
            const region_index = findRegionIndex(regions, binding_input.region_id) orelse return error.MissingAtlasRegion;
            const semantic_name = try StableName.init(binding_input.semantic_name);
            for (bindings[0..index]) |existing| {
                if (existing.semantic_id == binding_input.semantic_id and
                    !StableName.eql(existing.semantic_name, semantic_name))
                {
                    return error.ConflictingSemanticName;
                }
            }
            bindings[index] = .{
                .kind = binding_input.kind,
                .semantic_id = binding_input.semantic_id,
                .semantic_name = semantic_name,
                .view_id = binding_input.view_id,
                .region_id = binding_input.region_id,
                .region_index = @intCast(region_index),
            };
        }

        return .{
            .allocator = allocator,
            .stable_name = pack_name,
            .pages = pages,
            .regions = regions,
            .bindings = bindings,
        };
    }

    pub fn deinit(definition: *Definition) void {
        definition.allocator.free(definition.bindings);
        definition.allocator.free(definition.regions);
        definition.allocator.free(definition.pages);
        definition.* = undefined;
    }

    pub fn resolve(
        definition: *const Definition,
        kind: AssetKind,
        semantic_id: VisualSemanticId,
        view_id: ViewId,
    ) !ResolvedVisual {
        for (definition.bindings) |binding| {
            if (binding.kind == kind and binding.semantic_id == semantic_id and binding.view_id == view_id) {
                const region = definition.regions[binding.region_index];
                return .{
                    .semantic_id = semantic_id,
                    .view_id = view_id,
                    .region_id = region.id,
                    .texture_page = region.texture_page,
                    .uv_rect = region.uv_rect,
                    .authored_size = region.authored_size,
                    .pivot = region.pivot,
                };
            }
        }
        return error.MissingVisualBinding;
    }

    pub fn regionById(definition: *const Definition, id: AtlasRegionId) !*const AtlasRegion {
        const index = findRegionIndex(definition.regions, id) orelse return error.MissingAtlasRegion;
        return &definition.regions[index];
    }
};

fn findPageIndex(pages: []const TexturePageDefinition, id: TexturePageId) ?usize {
    for (pages, 0..) |page, index| {
        if (page.id == id) return index;
    }
    return null;
}

fn findRegionIndex(regions: []const AtlasRegion, id: AtlasRegionId) ?usize {
    for (regions, 0..) |region, index| {
        if (region.id == id) return index;
    }
    return null;
}

fn normalizedUv(page: TexturePageDefinition, source: PixelRect) ![4]f32 {
    if (source.width == 0 or source.height == 0) return error.ZeroAtlasRegion;
    const right = std.math.add(u32, source.x, source.width) catch return error.AtlasRectangleOverflow;
    const bottom = std.math.add(u32, source.y, source.height) catch return error.AtlasRectangleOverflow;
    if (right > page.expected_width or bottom > page.expected_height) return error.AtlasRectangleOutOfBounds;

    const width: f32 = @floatFromInt(page.expected_width);
    const height: f32 = @floatFromInt(page.expected_height);
    const result = [4]f32{
        @as(f32, @floatFromInt(source.x)) / width,
        @as(f32, @floatFromInt(source.y)) / height,
        @as(f32, @floatFromInt(right)) / width,
        @as(f32, @floatFromInt(bottom)) / height,
    };
    for (result) |value| {
        if (!std.math.isFinite(value) or value < 0 or value > 1) return error.InvalidNormalizedUv;
    }
    return result;
}

fn validateAuthoredGeometry(authored_size: [2]f32, pivot: [2]f32) !void {
    for (authored_size) |value| {
        if (!std.math.isFinite(value) or value <= 0) return error.InvalidAuthoredSize;
    }
    for (pivot) |value| {
        if (!std.math.isFinite(value) or value < 0 or value > 1) return error.InvalidPivot;
    }
}
