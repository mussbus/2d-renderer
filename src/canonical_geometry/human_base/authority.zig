const std = @import("std");
const canonical = @import("canonical_model");
const geometry = @import("canonical_geometry");

pub const authoritative_geometry_path = "assets/canonical_model/human_base/geometry/human_base_geometry.authoring.json";
pub const accepted_structural_hash_hex = "b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda";

pub const Loaded = struct {
    human: canonical.human_base.LoadedHumanBase,
    geometry: geometry.loader.LoadedGeometry,
    structural_sha256: geometry.identity.Sha256Digest,

    pub fn deinit(self: *Loaded) void {
        self.geometry.deinit();
        self.human.deinit();
        self.* = undefined;
    }

    pub fn definition(self: *const Loaded) *const geometry.schema.GeometryDefinition {
        return self.geometry.definition();
    }

    pub fn structuralDefinition(self: *const Loaded) *const canonical.definition.CanonicalCreatureDefinition {
        return self.human.definition();
    }
};

/// The sole supported production-human geometry load route. It first loads
/// the authoritative M02 source, derives its normalized identity, and then
/// validates the independent file-backed M03 geometry authority against it.
pub fn loadAuthoritative(allocator: std.mem.Allocator, io: std.Io) !Loaded {
    return loadPath(allocator, io, authoritative_geometry_path);
}

/// Loads an explicitly selected candidate through the same M02 compatibility,
/// parsing, validation, and normalization path as the authority. This is an
/// offline review tool boundary; it does not promote or rewrite the authority.
pub fn loadCandidate(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Loaded {
    if (std.mem.eql(u8, path, authoritative_geometry_path)) return error.CandidatePathIsAuthoritative;
    return loadPath(allocator, io, path);
}

fn loadPath(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Loaded {
    var human_diagnostics: [256]canonical.diagnostics.Diagnostic = undefined;
    var human = try canonical.human_base.loadAuthoritative(allocator, io, &human_diagnostics);
    errdefer human.deinit();

    const structural_bytes = try canonical.serialization.serializeAlloc(allocator, human.normalized());
    defer allocator.free(structural_bytes);
    const structural_sha256 = geometry.hashing.hashBytes(structural_bytes);
    if (!std.mem.eql(u8, &structural_sha256.toHex(), accepted_structural_hash_hex)) {
        return error.StructuralIdentityMismatch;
    }

    const context = geometry.validation.StructuralContext{
        .definition = human.definition(),
        .normalized_coordinate_contract = human.normalized_coordinate_contract,
        .normalized_source_sha256 = structural_sha256,
    };
    var geometry_diagnostics: ?geometry.diagnostics.OwnedReport = null;
    errdefer if (geometry_diagnostics) |*report| report.deinit();
    var loaded_geometry = try geometry.loader.loadFile(
        allocator,
        io,
        path,
        context,
        .{},
        &geometry_diagnostics,
    );
    errdefer loaded_geometry.deinit();

    return .{
        .human = human,
        .geometry = loaded_geometry,
        .structural_sha256 = structural_sha256,
    };
}
