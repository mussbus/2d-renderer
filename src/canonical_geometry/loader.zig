const std = @import("std");
const diagnostics = @import("diagnostics.zig");
const normalization = @import("normalization.zig");
const parsing = @import("parsing.zig");
const schema = @import("schema.zig");
const validation = @import("validation.zig");

/// Initial tooling safety ceiling. This is an explicit OPEN/TUNING value, not
/// part of canonical_geometry_schema or a limit on the source format.
pub const default_maximum_source_bytes: usize = 128 * 1024 * 1024;

pub const LoadOptions = struct {
    maximum_source_bytes: usize = default_maximum_source_bytes,
};

pub const LoadError = parsing.ParseError || error{
    GeometrySourceTooLarge,
    InvalidGeometrySource,
};

/// Owns the source byte buffer, parsed JSON arena, and every string/slice
/// referenced by `definition`. The caller must keep this wrapper alive while
/// using the definition and release it with `deinit`.
pub const LoadedGeometry = struct {
    allocator: std.mem.Allocator,
    source_bytes: []u8,
    parsed: parsing.ParsedGeometry,

    pub fn deinit(self: *LoadedGeometry) void {
        self.parsed.deinit();
        self.allocator.free(self.source_bytes);
        self.* = undefined;
    }

    pub fn definition(self: *const LoadedGeometry) *const schema.GeometryDefinition {
        return &self.parsed.value;
    }

    pub fn normalized(self: *const LoadedGeometry) normalization.NormalizedGeometry {
        return .{ .source = &self.parsed.value };
    }
};

/// Reads a caller-selected geometry source through the public parse, validate,
/// and normalize route. Invalid documents return their allocator-owned sorted
/// diagnostics through `diagnostic_report`; callers own and deinitialize it.
pub fn loadFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    structural: validation.StructuralContext,
    options: LoadOptions,
    diagnostic_report: *?diagnostics.OwnedReport,
) !LoadedGeometry {
    diagnostic_report.* = null;
    const bytes = std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(options.maximum_source_bytes),
    ) catch |read_error| switch (read_error) {
        error.StreamTooLong => return error.GeometrySourceTooLarge,
        else => return read_error,
    };
    errdefer allocator.free(bytes);
    return loadOwnedBytes(allocator, bytes, structural, options, diagnostic_report);
}

/// Copies caller-provided source bytes before parsing so the returned wrapper
/// has one explicit ownership boundary.
pub fn loadBytes(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    structural: validation.StructuralContext,
    options: LoadOptions,
    diagnostic_report: *?diagnostics.OwnedReport,
) !LoadedGeometry {
    diagnostic_report.* = null;
    if (bytes.len > options.maximum_source_bytes) return error.GeometrySourceTooLarge;
    const owned = try allocator.dupe(u8, bytes);
    errdefer allocator.free(owned);
    return loadOwnedBytes(allocator, owned, structural, options, diagnostic_report);
}

fn loadOwnedBytes(
    allocator: std.mem.Allocator,
    owned_bytes: []u8,
    structural: validation.StructuralContext,
    options: LoadOptions,
    diagnostic_report: *?diagnostics.OwnedReport,
) !LoadedGeometry {
    if (owned_bytes.len > options.maximum_source_bytes) return error.GeometrySourceTooLarge;
    var parsed = try parsing.parse(allocator, owned_bytes);
    errdefer parsed.deinit();

    var report = try validation.validateAlloc(allocator, &parsed.value, structural);
    if (!report.isValid()) {
        diagnostic_report.* = report;
        return error.InvalidGeometrySource;
    }
    report.deinit();

    const normalized = normalization.normalize(&parsed.value);
    if (normalized.source != &parsed.value) return error.InvalidGeometrySource;

    return .{
        .allocator = allocator,
        .source_bytes = owned_bytes,
        .parsed = parsed,
    };
}
