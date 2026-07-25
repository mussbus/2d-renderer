const std = @import("std");
const mesh = @import("deformable_mesh");

pub const maximum_mesh_definitions: usize = 32;
pub const maximum_catalog_vertices: usize = 4096;
pub const maximum_catalog_indices: usize = 12_288;

pub const Entry = struct {
    definition_token: usize,
    first_vertex: u32,
    vertex_count: u32,
    first_index: u32,
    index_count: u32,
    texture_page: u32,
};

pub const Catalog = struct {
    allocator: std.mem.Allocator,
    entries: []const Entry,
    vertices: []const mesh.GpuBaseVertex,
    indices: []const u16,

    pub fn init(allocator: std.mem.Allocator, definitions: []const mesh.DefinitionView) !Catalog {
        if (definitions.len == 0 or definitions.len > maximum_mesh_definitions) {
            return error.MeshDefinitionCatalogCapacityExceeded;
        }
        var total_vertices: usize = 0;
        var total_indices: usize = 0;
        for (definitions, 0..) |definition, index| {
            try definition.validate();
            for (definitions[0..index]) |existing| {
                if (existing.owner_token == definition.owner_token) return error.DuplicateMeshDefinition;
                if (existing.stable_id.eql(&definition.stable_id)) return error.DuplicateMeshStableId;
            }
            total_vertices = std.math.add(usize, total_vertices, definition.vertices.len) catch
                return error.MeshCatalogSizeOverflow;
            total_indices = std.math.add(usize, total_indices, definition.indices.len) catch
                return error.MeshCatalogSizeOverflow;
        }
        if (total_vertices > maximum_catalog_vertices or total_indices > maximum_catalog_indices) {
            return error.MeshCatalogCapacityExceeded;
        }

        const entries = allocator.alloc(Entry, definitions.len) catch return error.AllocationFailure;
        errdefer allocator.free(entries);
        const vertices = allocator.alloc(mesh.GpuBaseVertex, total_vertices) catch return error.AllocationFailure;
        errdefer allocator.free(vertices);
        const indices = allocator.alloc(u16, total_indices) catch return error.AllocationFailure;
        errdefer allocator.free(indices);

        var vertex_cursor: usize = 0;
        var index_cursor: usize = 0;
        for (definitions, 0..) |definition, definition_index| {
            entries[definition_index] = .{
                .definition_token = definition.owner_token,
                .first_vertex = @intCast(vertex_cursor),
                .vertex_count = @intCast(definition.vertices.len),
                .first_index = @intCast(index_cursor),
                .index_count = @intCast(definition.indices.len),
                .texture_page = definition.material.texture_page,
            };
            for (definition.vertices) |vertex| {
                vertices[vertex_cursor] = mesh.GpuBaseVertex.fromVertex(vertex);
                vertex_cursor += 1;
            }
            @memcpy(indices[index_cursor .. index_cursor + definition.indices.len], definition.indices);
            index_cursor += definition.indices.len;
        }

        return .{
            .allocator = allocator,
            .entries = entries,
            .vertices = vertices,
            .indices = indices,
        };
    }

    pub fn deinit(catalog: *Catalog) void {
        catalog.allocator.free(catalog.indices);
        catalog.allocator.free(catalog.vertices);
        catalog.allocator.free(catalog.entries);
        catalog.* = undefined;
    }

    pub fn find(catalog: *const Catalog, definition: mesh.DefinitionView) !Entry {
        try definition.validate();
        for (catalog.entries) |entry| {
            if (entry.definition_token == definition.owner_token) return entry;
        }
        return error.MeshDefinitionNotRegistered;
    }

    pub fn vertexBytes(catalog: Catalog) !u32 {
        return byteSize(mesh.GpuBaseVertex, catalog.vertices.len);
    }

    pub fn indexBytes(catalog: Catalog) !u32 {
        return byteSize(u16, catalog.indices.len);
    }

    pub fn uploadBytes(catalog: Catalog) !u32 {
        return std.math.add(u32, try catalog.vertexBytes(), try catalog.indexBytes()) catch
            return error.MeshCatalogSizeOverflow;
    }
};

fn byteSize(comptime T: type, count: usize) !u32 {
    const bytes = std.math.mul(usize, @sizeOf(T), count) catch return error.MeshCatalogSizeOverflow;
    if (bytes > std.math.maxInt(u32)) return error.MeshCatalogSizeOverflow;
    return @intCast(bytes);
}
