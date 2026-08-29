const std = @import("std");
const foundation = @import("foundation");

pub const prefab_kind = foundation.reference.AssetKind{ .name = "f.prefab" };
pub const level_kind = foundation.reference.AssetKind{ .name = "f.level" };
pub const world_kind = foundation.reference.AssetKind{ .name = "f.world" };
pub const presentation_kind = foundation.reference.AssetKind{ .name = "u.presentation" };
pub const volume_shape_kind = foundation.reference.AssetKind{ .name = "f.volume_shape" };

pub const current_schema_version = foundation.version.SchemaVersion.init(1, 0, 0);
pub const pre_acceptance_schema_version = foundation.version.SchemaVersion.init(0, 9, 0);

const schema_creation_unix_milliseconds: u64 = 1_787_961_600_000;
/// Permanent opaque document-family identities. The UUIDv7 construction inputs
/// allocate stable protocol constants; their version and timestamp bits carry
/// no schema semantics and must not be inspected by consumers.
pub const prefab_schema_id = schemaId(.{ 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x11, 0x22 });
pub const level_schema_id = schemaId(.{ 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x22, 0x33 });
pub const world_schema_id = schemaId(.{ 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0, 0x12, 0x33, 0x44 });

pub const SchemaIdentity = struct {
    id: foundation.identity.AssetId,
    version: foundation.version.SchemaVersion,
};

pub const ProducerIdentity = struct {
    id: foundation.identity.ProducerId,
    version: foundation.version.ProducerVersion,
};

pub const PresentationRef = struct {
    asset: foundation.reference.AssetRef,

    pub fn init(reference: foundation.reference.AssetRef) error{WrongAssetKind}!PresentationRef {
        if (!reference.expected_kind.eql(presentation_kind)) return error.WrongAssetKind;
        return .{ .asset = reference };
    }
};

pub const GenerationProvenance = struct {
    root_seed: foundation.determinism.Seed128,
    generator_id: foundation.identity.GeneratorId,
    generator_version: foundation.version.GeneratorVersion,
    algorithm_id: foundation.identity.AlgorithmId,
    algorithm_version: foundation.version.AlgorithmVersion,
    stable_generation_key: []const u8,

    pub fn validate(self: GenerationProvenance) error{InvalidGenerationKey}!void {
        if (!validStableKey(self.stable_generation_key)) return error.InvalidGenerationKey;
    }
};

pub const AssetHeader = struct {
    schema: SchemaIdentity,
    asset_id: foundation.identity.AssetId,
    asset_version: foundation.version.AssetVersion,
    kind: foundation.reference.AssetKind,
    slug: ?[]const u8 = null,
    producer: ProducerIdentity,
    dependencies: []const foundation.reference.DirectDependency = &.{},
    provenance: ?GenerationProvenance = null,
    presentation: ?PresentationRef = null,
};

pub fn isSupportedCurrentVersion(value: foundation.version.SchemaVersion) bool {
    // Patch releases preserve the 1.0 wire contract. Future minor support is
    // explicit rather than inferred from a matching major version.
    return value.major == current_schema_version.major and value.minor == current_schema_version.minor;
}

pub fn isSupportedPreAcceptanceVersion(value: foundation.version.SchemaVersion) bool {
    return value.eql(pre_acceptance_schema_version);
}

pub fn expectedSchemaId(kind: foundation.reference.AssetKind) ?foundation.identity.AssetId {
    if (kind.eql(prefab_kind)) return prefab_schema_id;
    if (kind.eql(level_kind)) return level_schema_id;
    if (kind.eql(world_kind)) return world_schema_id;
    return null;
}

pub fn validSlug(value: []const u8) bool {
    if (value.len == 0 or value.len > 63) return false;
    var segment_start = true;
    for (value) |byte| {
        if (byte == '-') {
            if (segment_start) return false;
            segment_start = true;
            continue;
        }
        if (segment_start) {
            if (byte < 'a' or byte > 'z') return false;
            segment_start = false;
        } else if (!((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_')) {
            return false;
        }
    }
    return !segment_start;
}

fn validStableKey(value: []const u8) bool {
    if (value.len == 0 or value.len > 127 or !std.unicode.utf8ValidateSlice(value)) return false;
    for (value) |byte| if (byte < 0x20) return false;
    return true;
}

fn schemaId(comptime entropy: [10]u8) foundation.identity.AssetId {
    return foundation.identity.uuidV7(
        foundation.identity.AssetId,
        schema_creation_unix_milliseconds,
        entropy,
    ) catch |generation_error| @compileError(@errorName(generation_error));
}
