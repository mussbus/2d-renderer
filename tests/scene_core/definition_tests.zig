const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const support = @import("support.zig");

test "F2B definitions contain authored identities and no runtime handles" {
    try std.testing.expect(!@hasField(scene_core.entity.EntityInstanceDefinition, "handle"));
    try std.testing.expect(!@hasField(scene_core.level.LevelDefinition, "runtime_scene"));
    try std.testing.expect(@hasField(scene_core.world.WorldDefinition, "persistent_entities"));
    try std.testing.expectEqual(foundation.identity.UuidVersion.v7, scene_core.asset.prefab_schema_id.version());
    try std.testing.expectEqual(foundation.identity.UuidVersion.v7, scene_core.asset.level_schema_id.version());
    try std.testing.expectEqual(foundation.identity.UuidVersion.v7, scene_core.asset.world_schema_id.version());
    const level_schema_text = scene_core.asset.level_schema_id.formatCanonical();
    try std.testing.expectEqualStrings("01a04ad0-e800-7345-a789-abcdef012233", &level_schema_text);
}

test "schema UUIDs are permanent distinct document-family identities" {
    try std.testing.expect(!scene_core.asset.prefab_schema_id.eql(scene_core.asset.level_schema_id));
    try std.testing.expect(!scene_core.asset.level_schema_id.eql(scene_core.asset.world_schema_id));
    try std.testing.expect(!scene_core.asset.prefab_schema_id.eql(scene_core.asset.world_schema_id));
    try std.testing.expectEqualStrings(
        "01a04ad0-e800-7234-9678-9abcdef01122",
        &scene_core.asset.prefab_schema_id.formatCanonical(),
    );
    try std.testing.expectEqualStrings(
        "01a04ad0-e800-7345-a789-abcdef012233",
        &scene_core.asset.level_schema_id.formatCanonical(),
    );
    try std.testing.expectEqualStrings(
        "01a04ad0-e800-7456-b89a-bcdef0123344",
        &scene_core.asset.world_schema_id.formatCanonical(),
    );
    try std.testing.expect(scene_core.asset.isSupportedPreAcceptanceVersion(scene_core.asset.pre_acceptance_schema_version));
    try std.testing.expect(scene_core.asset.isSupportedCurrentVersion(scene_core.asset.current_schema_version));
    try std.testing.expectEqual(@as(u32, 0), scene_core.asset.pre_acceptance_schema_version.major);
    try std.testing.expectEqual(@as(u32, 9), scene_core.asset.pre_acceptance_schema_version.minor);
    try std.testing.expectEqual(@as(u32, 1), scene_core.asset.current_schema_version.major);
}

test "tag grammar and enabled inheritance are bounded and deterministic" {
    const tag = try scene_core.metadata.TagId.init("gameplay:street_lamp");
    try std.testing.expectEqualStrings("gameplay:street_lamp", tag.value);
    try std.testing.expectError(error.InvalidTagId, scene_core.metadata.TagId.init("Gameplay:lamp"));
    try std.testing.expect(scene_core.metadata.effectiveEnabled(true, .inherit));
    try std.testing.expect(!scene_core.metadata.effectiveEnabled(false, .enabled));
}

test "camera contract accepts only neutral perspective or orthographic geometry" {
    const perspective = scene_core.camera.CameraDefinition{
        .projection = .perspective,
        .perspective = .{ .focal_length_mm = 50, .sensor_width_mm = 36, .sensor_height_mm = 24 },
        .near_clip_m = 0.1,
        .far_clip_m = 1000,
    };
    try perspective.validate();
    var invalid = perspective;
    invalid.orthographic = .{ .horizontal_extent_m = 10, .vertical_extent_m = 10 };
    try std.testing.expectError(error.InvalidCameraGeometry, invalid.validate());
    try std.testing.expect(!@hasField(scene_core.camera.CameraDefinition, "exposure"));
    try std.testing.expect(!@hasField(scene_core.camera.CameraDefinition, "viewport"));
}

test "volume shape is a typed asset boundary in entity-local metres" {
    const shape = try support.assetRef("005aa28f-9f5e-57cc-a0ea-e82bf35fd0fd", "f.volume_shape", 0x11);
    const reference = try scene_core.entity.VolumeShapeRef.init(shape);
    try std.testing.expect(reference.asset.eql(shape));
    const wrong = try support.assetRef("005aa28f-9f5e-57cc-a0ea-e82bf35fd0fd", "p.collider", 0x11);
    try std.testing.expectError(error.WrongAssetKind, scene_core.entity.VolumeShapeRef.init(wrong));
}

test "prefab child identity derives from stable node path rather than array order" {
    const root = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d");
    const first = try scene_core.prefab.deriveInstantiatedEntityId(root, "root/lamp_head");
    const second = try scene_core.prefab.deriveInstantiatedEntityId(root, "root/lamp_head");
    const other = try scene_core.prefab.deriveInstantiatedEntityId(root, "root/light");
    try std.testing.expect(first.eql(second));
    try std.testing.expect(!first.eql(other));
}

test "level origins are exact world millimetres while placements remain local metres" {
    const origin = scene_core.level.WorldCoordinateOrigin{ .x_mm = 4_000_000_000, .y_mm = 0, .z_mm = -2_000_000_000 };
    const local = try foundation.spatial.LocalTransform.init(
        try foundation.spatial.Vec3.init(1.25, 0, 2.5),
        .identity,
        .one,
    );
    try std.testing.expectEqual(@as(i64, 4_000_000_000), origin.x_mm);
    try std.testing.expectEqual(@as(f32, 1.25), local.translation.x);
}

test "layer systems remain typed and owned by their subsystem namespaces" {
    const render_layer = scene_core.metadata.LayerAssignment{
        .system = .render,
        .layer = try support.assetRef("64f4e68a-68f4-5210-8cc5-3ebac7d010af", "r.render_layer", 0x71),
    };
    try render_layer.validate();
    var invalid = render_layer;
    invalid.system = .collision;
    try std.testing.expectError(error.WrongLayerKind, invalid.validate());
    try std.testing.expect(!@hasField(scene_core.metadata.LayerAssignment, "mask"));
}

test "visibility intent stays distinct from enabled intent" {
    const instance = scene_core.entity.EntityInstanceDefinition{
        .entity_id = try support.entityId("a0610ba8-d264-5dcd-9c43-7ce374501e0d"),
        .enabled = .disabled,
        .visibility = .visible,
    };
    try std.testing.expectEqual(scene_core.metadata.EnabledIntent.disabled, instance.enabled);
    try std.testing.expectEqual(scene_core.metadata.VisibilityIntent.visible, instance.visibility);
}
