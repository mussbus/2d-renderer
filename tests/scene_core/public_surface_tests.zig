const std = @import("std");
const scene_core = @import("scene_core");

test "supported scene_core root hides F-owned mutable runtime storage" {
    try std.testing.expect(!@hasDecl(scene_core, "registry"));
    try std.testing.expect(!@hasDecl(scene_core, "runtime_entity"));
    try std.testing.expect(@hasDecl(scene_core, "runtime_scene"));
    try std.testing.expect(!@hasDecl(scene_core.runtime_scene, "EntityRegistry"));
    try std.testing.expect(!@hasDecl(scene_core.runtime_scene, "RuntimeEntity"));

    const RuntimeScene = scene_core.runtime_scene.RuntimeScene;
    try std.testing.expect(!@hasField(RuntimeScene, "state"));
    try std.testing.expect(!@hasField(RuntimeScene, "registry"));
    try std.testing.expect(!@hasField(RuntimeScene, "publication_generation"));
    try std.testing.expect(!@hasField(RuntimeScene, "snapshot_leases"));
    try std.testing.expect(!@hasField(RuntimeScene, "growth_sink"));
    try std.testing.expect(@FieldType(RuntimeScene, "opaque_context") == *const anyopaque);

    const SceneSnapshot = scene_core.runtime_scene.SceneSnapshot;
    try std.testing.expect(@FieldType(SceneSnapshot, "owner_context") == *const anyopaque);
    try std.testing.expect(@FieldType(SceneSnapshot, "storage_context") == *const anyopaque);
    try std.testing.expect(@FieldType(scene_core.runtime_scene.SceneReadView, "context") == *const anyopaque);
    try std.testing.expect(@FieldType(scene_core.runtime_scene.EntityView, "context") == *const anyopaque);
    try std.testing.expect(@FieldType(scene_core.runtime_scene.ExtensionView, "context") == *const anyopaque);
}
