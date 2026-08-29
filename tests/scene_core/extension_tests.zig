const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const support = @import("support.zig");

test "extension namespace requires a governed track prefix" {
    _ = try scene_core.extension.ComponentTypeId.init("r.light");
    try std.testing.expectError(error.InvalidComponentTypeId, scene_core.extension.ComponentTypeId.init("light"));
    try std.testing.expectError(error.InvalidComponentTypeId, scene_core.extension.ComponentTypeId.init("x.light"));
}

test "descriptor registration freezes in deterministic type and version order" {
    var storage: [2]scene_core.extension.Descriptor = undefined;
    var registry = scene_core.extension.DescriptorRegistry.init(&storage);
    try registry.register(.{
        .type_id = try scene_core.extension.ComponentTypeId.init("u.presentation_link"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .validate = support.acceptPayload,
    });
    try registry.register(.{
        .type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .validate = support.acceptPayload,
    });
    registry.freeze();
    try std.testing.expectEqualStrings("r.light", registry.descriptors()[0].type_id.value);
    try std.testing.expectError(error.FrozenRegistry, registry.register(registry.descriptors()[0]));
}

test "unknown optional extensions preserve canonical bytes while required extensions fail" {
    var storage: [1]scene_core.extension.Descriptor = undefined;
    var registry = scene_core.extension.DescriptorRegistry.init(&storage);
    registry.freeze();
    const type_id = try scene_core.extension.ComponentTypeId.init("e.fog");
    const optional = scene_core.extension.ExtensionRecord{
        .type_id = type_id,
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .optional_preserve,
        .canonical_payload = "{\"density\":0.5}",
    };
    try std.testing.expectEqual(@as(usize, optional.canonical_payload.len), try scene_core.extension.validateRecords(&.{optional}, &registry));
    var required = optional;
    required.criticality = .required;
    try std.testing.expectError(error.UnknownRequiredExtension, scene_core.extension.validateRecords(&.{required}, &registry));
}

test "extension limits reject record and payload overflow" {
    var descriptor_storage: [1]scene_core.extension.Descriptor = undefined;
    const registry = try support.frozenRegistry(&descriptor_storage);
    var records: [scene_core.extension.max_records_per_entity + 1]scene_core.extension.ExtensionRecord = undefined;
    const type_id = try scene_core.extension.ComponentTypeId.init("r.light");
    for (&records) |*record| record.* = .{
        .type_id = type_id,
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .required,
        .canonical_payload = "{}",
    };
    try std.testing.expectError(error.TooManyExtensions, scene_core.extension.validateRecords(&records, &registry));
}

test "extension payloads must already be canonical and descriptor dependency reports are checked" {
    var descriptor_storage: [1]scene_core.extension.Descriptor = undefined;
    const registry = try support.frozenRegistry(&descriptor_storage);
    const type_id = try scene_core.extension.ComponentTypeId.init("r.light");
    const noncanonical = scene_core.extension.ExtensionRecord{
        .type_id = type_id,
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .required,
        .canonical_payload = "{ \"intensity\": 12 }",
    };
    try std.testing.expectError(error.InvalidCanonicalPayload, scene_core.extension.validateRecords(&.{noncanonical}, &registry));
    const canonical = scene_core.extension.ExtensionRecord{
        .type_id = type_id,
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .required,
        .canonical_payload = "{\"intensity\":12}",
    };
    try std.testing.expectEqual(@as(usize, canonical.canonical_payload.len), try scene_core.extension.validateRecords(&.{canonical}, &registry));
}

test "duplicate and ambiguous descriptor version routes fail before freeze" {
    var storage: [3]scene_core.extension.Descriptor = undefined;
    var registry = scene_core.extension.DescriptorRegistry.init(&storage);
    const descriptor = scene_core.extension.Descriptor{
        .type_id = try scene_core.extension.ComponentTypeId.init("p.collider"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .validate = support.acceptPayload,
    };
    try registry.register(descriptor);
    try std.testing.expectError(error.DuplicateDescriptor, registry.register(descriptor));
    var ambiguous = descriptor;
    ambiguous.schema_version = foundation.version.SchemaVersion.init(1, 0, 1);
    try std.testing.expectError(error.AmbiguousVersionRoute, registry.register(ambiguous));
}

fn requireSemanticDependency(
    payload: []const u8,
    dependencies: []const foundation.reference.DirectDependency,
) scene_core.extension.DescriptorError!void {
    if (payload.len == 0) return error.InvalidPayload;
    if (dependencies.len != 1 or dependencies[0].class != .semantic_runtime_required) {
        return error.DependencyReportMismatch;
    }
}

test "descriptor validates declared direct dependency class before any future compilation" {
    var storage: [1]scene_core.extension.Descriptor = undefined;
    var registry = scene_core.extension.DescriptorRegistry.init(&storage);
    try registry.register(.{
        .type_id = try scene_core.extension.ComponentTypeId.init("p.collider"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .validate = requireSemanticDependency,
    });
    registry.freeze();
    const dependency_asset = try support.assetRef("e780eb86-d412-513e-8f61-99a7f1d4e153", "p.shape", 0x81);
    const valid = scene_core.extension.ExtensionRecord{
        .type_id = try scene_core.extension.ComponentTypeId.init("p.collider"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .criticality = .required,
        .canonical_payload = "{\"shape\":\"box\"}",
        .dependencies = &.{.{ .asset = dependency_asset, .class = .semantic_runtime_required }},
    };
    _ = try scene_core.extension.validateRecords(&.{valid}, &registry);
    var invalid_dependency = valid.dependencies[0];
    invalid_dependency.class = .tooling_only;
    var invalid = valid;
    invalid.dependencies = &.{invalid_dependency};
    try std.testing.expectError(error.DependencyReportMismatch, scene_core.extension.validateRecords(&.{invalid}, &registry));
}

test "registration order cannot change the frozen descriptor sequence" {
    const light = scene_core.extension.Descriptor{
        .type_id = try scene_core.extension.ComponentTypeId.init("r.light"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .validate = support.acceptPayload,
    };
    const fog = scene_core.extension.Descriptor{
        .type_id = try scene_core.extension.ComponentTypeId.init("e.fog"),
        .schema_version = foundation.version.SchemaVersion.init(1, 0, 0),
        .validate = support.acceptPayload,
    };
    var first_storage: [2]scene_core.extension.Descriptor = undefined;
    var first = scene_core.extension.DescriptorRegistry.init(&first_storage);
    try first.register(light);
    try first.register(fog);
    first.freeze();
    var second_storage: [2]scene_core.extension.Descriptor = undefined;
    var second = scene_core.extension.DescriptorRegistry.init(&second_storage);
    try second.register(fog);
    try second.register(light);
    second.freeze();
    for (first.descriptors(), second.descriptors()) |a, b| try std.testing.expect(a.type_id.eql(b.type_id));
}
