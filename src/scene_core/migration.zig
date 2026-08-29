const std = @import("std");
const asset = @import("asset.zig");
const level = @import("level.zig");

pub const MigrationCode = enum(u16) {
    origin_metres_to_millimetres = 2000,
    materialized_authored_defaults = 2001,
};

pub const MigrationNote = struct {
    code: MigrationCode,
    object_path: []const u8,
    message: []const u8,
};

pub const MigrationReport = struct {
    storage: []MigrationNote,
    length: usize = 0,

    pub fn add(self: *MigrationReport, note: MigrationNote) error{CapacityExceeded}!void {
        if (self.length == self.storage.len) return error.CapacityExceeded;
        self.storage[self.length] = note;
        self.length += 1;
    }

    pub fn notes(self: *const MigrationReport) []const MigrationNote {
        return self.storage[0..self.length];
    }
};

pub const MigrationError = error{
    CapacityExceeded,
    OriginOverflow,
    UnsupportedSourceVersion,
};

pub fn levelV0_9ToCurrent(
    source: level.PreAcceptanceLevelDefinitionV0_9,
    report: *MigrationReport,
) MigrationError!level.LevelDefinition {
    if (!asset.isSupportedPreAcceptanceVersion(source.header.schema.version)) return error.UnsupportedSourceVersion;
    const x_mm = std.math.mul(i64, source.origin_m[0], 1000) catch return error.OriginOverflow;
    const y_mm = std.math.mul(i64, source.origin_m[1], 1000) catch return error.OriginOverflow;
    const z_mm = std.math.mul(i64, source.origin_m[2], 1000) catch return error.OriginOverflow;
    try report.add(.{
        .code = .origin_metres_to_millimetres,
        .object_path = "payload.origin",
        .message = "converted exact integer metres to exact integer millimetres",
    });
    try report.add(.{
        .code = .materialized_authored_defaults,
        .object_path = "payload.entities",
        .message = "materialized F2B activation, visibility, classification, and optional-boundary defaults",
    });
    var header = source.header;
    header.schema.version = asset.current_schema_version;
    return .{
        .header = header,
        .origin = .{ .x_mm = x_mm, .y_mm = y_mm, .z_mm = z_mm },
        .entities = source.entities,
    };
}
