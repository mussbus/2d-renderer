const std = @import("std");
const identity = @import("identity.zig");
const version = @import("version.zig");

pub const Severity = enum(u8) {
    error_severity = 0,
    warning = 1,
    information = 2,
};

pub const Code = enum(u16) {
    invalid_identity = 1000,
    duplicate_identity = 1001,
    invalid_version = 1100,
    invalid_reference = 1200,
    dependency_cycle = 1201,
    invalid_canonical_data = 1300,
    invalid_spatial_value = 1400,
    capacity_exceeded = 1500,
};

pub const SchemaContext = struct {
    id: identity.AssetId,
    version: version.SchemaVersion,
};

pub const ReferenceKind = enum(u8) {
    none = 0,
    asset = 1,
    entity = 2,
};

pub const ReferenceIdentity = struct {
    kind: ReferenceKind = .none,
    bytes: [16]u8 = [_]u8{0} ** 16,

    pub fn asset(id: identity.AssetId) ReferenceIdentity {
        return .{ .kind = .asset, .bytes = id.bytes };
    }

    pub fn entity(id: identity.EntityId) ReferenceIdentity {
        return .{ .kind = .entity, .bytes = id.bytes };
    }
};

pub const Diagnostic = struct {
    severity: Severity,
    code: Code,
    schema: ?SchemaContext = null,
    object_path: []const u8,
    property_path: []const u8 = "",
    reference: ReferenceIdentity = .{},
    message: []const u8,
};

pub const Collector = struct {
    storage: []Diagnostic,
    length: usize = 0,

    pub fn init(storage: []Diagnostic) Collector {
        return .{ .storage = storage };
    }

    pub fn add(self: *Collector, diagnostic: Diagnostic) error{CapacityExceeded}!void {
        if (self.length == self.storage.len) return error.CapacityExceeded;
        self.storage[self.length] = diagnostic;
        self.length += 1;
    }

    pub fn sorted(self: *Collector) []const Diagnostic {
        insertionSort(self.storage[0..self.length]);
        return self.storage[0..self.length];
    }
};

fn insertionSort(diagnostics: []Diagnostic) void {
    var index: usize = 1;
    while (index < diagnostics.len) : (index += 1) {
        const value = diagnostics[index];
        var position = index;
        while (position > 0 and order(value, diagnostics[position - 1]) == .lt) : (position -= 1) {
            diagnostics[position] = diagnostics[position - 1];
        }
        diagnostics[position] = value;
    }
}

fn order(a: Diagnostic, b: Diagnostic) std.math.Order {
    var result = std.math.order(@intFromEnum(a.severity), @intFromEnum(b.severity));
    if (result != .eq) return result;
    result = std.math.order(@intFromEnum(a.code), @intFromEnum(b.code));
    if (result != .eq) return result;
    result = optionalSchemaOrder(a.schema, b.schema);
    if (result != .eq) return result;
    result = std.mem.order(u8, a.object_path, b.object_path);
    if (result != .eq) return result;
    result = std.mem.order(u8, a.property_path, b.property_path);
    if (result != .eq) return result;
    result = std.math.order(@intFromEnum(a.reference.kind), @intFromEnum(b.reference.kind));
    if (result != .eq) return result;
    result = std.mem.order(u8, &a.reference.bytes, &b.reference.bytes);
    if (result != .eq) return result;
    return std.mem.order(u8, a.message, b.message);
}

fn optionalSchemaOrder(a: ?SchemaContext, b: ?SchemaContext) std.math.Order {
    if (a == null and b == null) return .eq;
    if (a == null) return .lt;
    if (b == null) return .gt;
    const id_order = a.?.id.byteOrder(b.?.id);
    if (id_order != .eq) return id_order;
    return a.?.version.order(b.?.version);
}
