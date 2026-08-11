const std = @import("std");

pub const Code = enum {
    schema_identity_mismatch,
    structural_compatibility_mismatch,
    missing_structural_reference,
    duplicate_mesh_id,
    duplicate_vertex_id,
    invalid_allocation_cursor,
    non_finite_position,
    duplicate_face_id,
    invalid_vertex_reference,
    duplicate_face_vertex,
    degenerate_quad,
    duplicate_face,
    inconsistent_winding,
    non_manifold_edge,
    unexpected_boundary,
    malformed_boundary_loop,
    disconnected_mesh,
    missing_surface,
    missing_region,
    missing_owning_region,
    unknown_material,
    invalid_surface_coordinate,
    invalid_texture_uv,
    malformed_seam_loop,
    invalid_seam_semantics,
    invalid_geometry_binding,
    invalid_face_set,
    invalid_module_interface,
    invalid_proxy_owner,
    invalid_proxy_driver,
    invalid_proxy_dimensions,
    topology_compatibility_mismatch,
};

pub const Diagnostic = struct {
    code: Code,
    object_type: []const u8,
    object_id: ?[]const u8,
    property: ?[]const u8,
    reference_type: ?[]const u8,
    reference_id: ?[]const u8,
    message: []const u8,
};

pub const OwnedReport = struct {
    allocator: std.mem.Allocator,
    diagnostics: []Diagnostic,

    pub fn deinit(self: *OwnedReport) void {
        for (self.diagnostics) |diagnostic| freeDiagnostic(self.allocator, diagnostic);
        self.allocator.free(self.diagnostics);
        self.* = undefined;
    }

    pub fn isValid(self: OwnedReport) bool {
        return self.diagnostics.len == 0;
    }
};

pub const Collector = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(Diagnostic) = .empty,

    pub fn init(allocator: std.mem.Allocator) Collector {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Collector) void {
        for (self.items.items) |diagnostic| freeDiagnostic(self.allocator, diagnostic);
        self.items.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn add(self: *Collector, diagnostic: Diagnostic) !void {
        const owned = try cloneDiagnostic(self.allocator, diagnostic);
        errdefer freeDiagnostic(self.allocator, owned);
        try self.items.append(self.allocator, owned);
    }

    pub fn finish(self: *Collector) !OwnedReport {
        insertionSort(self.items.items);
        const owned = try self.items.toOwnedSlice(self.allocator);
        return .{ .allocator = self.allocator, .diagnostics = owned };
    }
};

fn cloneDiagnostic(allocator: std.mem.Allocator, source: Diagnostic) !Diagnostic {
    const object_type = try allocator.dupe(u8, source.object_type);
    errdefer allocator.free(object_type);
    const object_id = try cloneOptional(allocator, source.object_id);
    errdefer freeOptional(allocator, object_id);
    const property = try cloneOptional(allocator, source.property);
    errdefer freeOptional(allocator, property);
    const reference_type = try cloneOptional(allocator, source.reference_type);
    errdefer freeOptional(allocator, reference_type);
    const reference_id = try cloneOptional(allocator, source.reference_id);
    errdefer freeOptional(allocator, reference_id);
    const message = try allocator.dupe(u8, source.message);
    errdefer allocator.free(message);
    return .{
        .code = source.code,
        .object_type = object_type,
        .object_id = object_id,
        .property = property,
        .reference_type = reference_type,
        .reference_id = reference_id,
        .message = message,
    };
}

fn freeDiagnostic(allocator: std.mem.Allocator, diagnostic: Diagnostic) void {
    allocator.free(diagnostic.object_type);
    freeOptional(allocator, diagnostic.object_id);
    freeOptional(allocator, diagnostic.property);
    freeOptional(allocator, diagnostic.reference_type);
    freeOptional(allocator, diagnostic.reference_id);
    allocator.free(diagnostic.message);
}

fn cloneOptional(allocator: std.mem.Allocator, value: ?[]const u8) !?[]const u8 {
    return if (value) |bytes| try allocator.dupe(u8, bytes) else null;
}

fn freeOptional(allocator: std.mem.Allocator, value: ?[]const u8) void {
    if (value) |bytes| allocator.free(bytes);
}

fn insertionSort(items: []Diagnostic) void {
    var index: usize = 1;
    while (index < items.len) : (index += 1) {
        const item = items[index];
        var destination = index;
        while (destination > 0 and lessThan(item, items[destination - 1])) : (destination -= 1) {
            items[destination] = items[destination - 1];
        }
        items[destination] = item;
    }
}

fn lessThan(a: Diagnostic, b: Diagnostic) bool {
    const code_order = std.math.order(@intFromEnum(a.code), @intFromEnum(b.code));
    if (code_order != .eq) return code_order == .lt;
    if (stringOrder(a.object_type, b.object_type)) |result| return result;
    if (optionalStringOrder(a.object_id, b.object_id)) |result| return result;
    if (optionalStringOrder(a.property, b.property)) |result| return result;
    if (optionalStringOrder(a.reference_type, b.reference_type)) |result| return result;
    if (optionalStringOrder(a.reference_id, b.reference_id)) |result| return result;
    return std.mem.order(u8, a.message, b.message) == .lt;
}

fn stringOrder(a: []const u8, b: []const u8) ?bool {
    return switch (std.mem.order(u8, a, b)) {
        .lt => true,
        .gt => false,
        .eq => null,
    };
}

fn optionalStringOrder(a: ?[]const u8, b: ?[]const u8) ?bool {
    if (a == null and b != null) return true;
    if (a != null and b == null) return false;
    if (a == null) return null;
    return stringOrder(a.?, b.?);
}
