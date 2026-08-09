const std = @import("std");
const coordinate = @import("coordinate.zig");
const definition_module = @import("definition.zig");
const diagnostics = @import("diagnostics.zig");
const human_structural_validation = @import("human_structural_validation.zig");
const normalization = @import("normalization.zig");
const parsing = @import("parsing.zig");
const validation = @import("validation.zig");

pub const authoritative_authoring_path = "assets/canonical_model/human_base/human_base.authoring.json";
pub const maximum_authoring_bytes: usize = 2 * 1024 * 1024;

pub const LoadError = parsing.ParseError ||
    validation.ValidationError ||
    human_structural_validation.Error ||
    error{
        InvalidCanonicalSource,
    };

/// Owns every allocation and byte buffer referenced by the parsed canonical
/// definition. Callers must keep this wrapper alive while using `definition`
/// or `normalized` and must release it with `deinit`.
pub const LoadedHumanBase = struct {
    allocator: std.mem.Allocator,
    authoring_bytes: []u8,
    parsed: parsing.ParsedDefinition,
    normalized_coordinate_contract: coordinate.CoordinateContract,

    pub fn deinit(self: *LoadedHumanBase) void {
        self.parsed.deinit();
        self.allocator.free(self.authoring_bytes);
        self.* = undefined;
    }

    pub fn definition(self: *const LoadedHumanBase) *const definition_module.CanonicalCreatureDefinition {
        return &self.parsed.value;
    }

    pub fn normalized(self: *const LoadedHumanBase) normalization.NormalizedDefinition {
        return .{
            .source = &self.parsed.value,
            .coordinate_contract = self.normalized_coordinate_contract,
        };
    }
};

/// Loads the sole authoritative repository `human_base` source. The caller
/// owns the returned wrapper and the diagnostic storage remains caller-owned.
pub fn loadAuthoritative(
    allocator: std.mem.Allocator,
    io: std.Io,
    diagnostic_storage: []diagnostics.Diagnostic,
) !LoadedHumanBase {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        authoritative_authoring_path,
        allocator,
        .limited(maximum_authoring_bytes),
    );
    errdefer allocator.free(bytes);
    return loadOwnedAuthoritativeBytes(allocator, bytes, diagnostic_storage);
}

/// Parses caller-provided authoritative bytes through the same fail-closed
/// path after copying them into the returned wrapper's explicit ownership.
pub fn loadAuthoritativeBytes(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    diagnostic_storage: []diagnostics.Diagnostic,
) !LoadedHumanBase {
    const owned = try allocator.dupe(u8, bytes);
    errdefer allocator.free(owned);
    return loadOwnedAuthoritativeBytes(allocator, owned, diagnostic_storage);
}

fn loadOwnedAuthoritativeBytes(
    allocator: std.mem.Allocator,
    owned_bytes: []u8,
    diagnostic_storage: []diagnostics.Diagnostic,
) LoadError!LoadedHumanBase {
    var parsed = try parsing.parse(allocator, owned_bytes);
    errdefer parsed.deinit();

    const generic_report = try validation.validate(&parsed.value, .{}, diagnostic_storage);
    if (!generic_report.isValid()) return error.InvalidCanonicalSource;
    try human_structural_validation.validatePrompt2D(&parsed.value);

    const normalized_result = try normalization.normalize(&parsed.value, .{}, diagnostic_storage);
    if (!normalized_result.isValid()) return error.InvalidCanonicalSource;

    return .{
        .allocator = allocator,
        .authoring_bytes = owned_bytes,
        .parsed = parsed,
        .normalized_coordinate_contract = normalized_result.normalized.?.coordinate_contract,
    };
}
