const std = @import("std");
const math = @import("math");
const appearance = @import("appearance");
const anatomy = @import("anatomy");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const collision_world = @import("collision_world");
const modular = @import("modular_body_demo");

const tolerance: f32 = 0.000001;

test "morphology interpolates exactly and override precedence reset and preset isolation are deterministic" {
    var definition = try modular.initDefinition(std.testing.allocator);
    defer definition.deinit();
    const anatomy_definition = definition.anatomy_definition.?.view();
    var runtime = try anatomy.Runtime.init(std.testing.allocator, anatomy_definition, null);
    defer runtime.deinit();

    const torso_width = try anatomy_definition.morphologyChannelId("torso_width");
    const tail_thickness = try anatomy_definition.morphologyChannelId("tail_thickness");
    const tail = try anatomy_definition.partInstanceId("tail");
    const average = try anatomy_definition.morphologyPresetId("average");
    try runtime.selectMorphologyPreset(anatomy_definition, average);

    try runtime.setGlobalBuild(anatomy_definition, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.88), try runtime.resolvedChannel(anatomy_definition, torso_width), tolerance);
    try runtime.setGlobalBuild(anatomy_definition, 50);
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), try runtime.resolvedChannel(anatomy_definition, torso_width), tolerance);
    try runtime.setGlobalBuild(anatomy_definition, 100);
    try std.testing.expectApproxEqAbs(@as(f32, 1.12), try runtime.resolvedChannel(anatomy_definition, torso_width), tolerance);

    try runtime.setChannelOverride(anatomy_definition, torso_width, 25);
    try std.testing.expectApproxEqAbs(@as(f32, 0.94), try runtime.resolvedChannel(anatomy_definition, torso_width), tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 1.12), try runtime.resolvedChannel(anatomy_definition, tail_thickness), tolerance);
    try runtime.setChannelOverride(anatomy_definition, tail_thickness, 75);
    try runtime.setInstanceOverride(anatomy_definition, tail, tail_thickness, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.88), try runtime.resolvedChannelForPart(anatomy_definition, tail, tail_thickness), tolerance);
    try runtime.setInstanceOverride(anatomy_definition, tail, tail_thickness, null);
    try std.testing.expectApproxEqAbs(@as(f32, 1.06), try runtime.resolvedChannelForPart(anatomy_definition, tail, tail_thickness), tolerance);

    try runtime.reset(anatomy_definition);
    try std.testing.expectApproxEqAbs(@as(f32, 1.00), try runtime.resolvedChannel(anatomy_definition, torso_width), tolerance);
    try runtime.selectMorphologyPreset(anatomy_definition, try anatomy_definition.morphologyPresetId("slim"));
    try std.testing.expectApproxEqAbs(@as(f32, 0.83), try runtime.resolvedChannel(anatomy_definition, torso_width), tolerance);
    try runtime.selectMorphologyPreset(anatomy_definition, try anatomy_definition.morphologyPresetId("broad_heavy"));
    try std.testing.expectApproxEqAbs(@as(f32, 1.15), try runtime.resolvedChannel(anatomy_definition, torso_width), tolerance);
}

test "morphology rejects invalid user values and invalid preset ranges" {
    var definition = try modular.initDefinition(std.testing.allocator);
    defer definition.deinit();
    const anatomy_definition = definition.anatomy_definition.?.view();
    var runtime = try anatomy.Runtime.init(std.testing.allocator, anatomy_definition, null);
    defer runtime.deinit();
    const channel = try anatomy_definition.morphologyChannelId("hip_width");
    const part = try anatomy_definition.partInstanceId("pelvis");

    try std.testing.expectError(error.InvalidUserMorphologyValue, runtime.setGlobalBuild(anatomy_definition, -0.01));
    try std.testing.expectError(error.InvalidUserMorphologyValue, runtime.setGlobalBuild(anatomy_definition, 100.01));
    try std.testing.expectError(error.InvalidUserMorphologyValue, runtime.setChannelOverride(anatomy_definition, channel, std.math.nan(f32)));
    try std.testing.expectError(error.InvalidUserMorphologyValue, runtime.setInstanceOverride(anatomy_definition, part, channel, std.math.inf(f32)));

    var base = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer base.deinit();
    try expectMinimalDefinitionError(
        base.visual_definition.view(),
        1.2,
        0.8,
        .{ .attachment_point = "chest" },
        .{ .attachment_point = "chest" },
        error.InvalidMorphologyRange,
    );
}

test "repeated adult modules and conventional presets are compositional data" {
    var definition = try modular.initDefinition(std.testing.allocator);
    defer definition.deinit();
    const anatomy_definition = definition.anatomy_definition.?.view();
    var runtime = try anatomy.Runtime.init(std.testing.allocator, anatomy_definition, null);
    defer runtime.deinit();

    try runtime.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("two_penises"));
    try expectActive(&runtime, anatomy_definition, "penis_a", true);
    try expectActive(&runtime, anatomy_definition, "penis_b", true);
    try expectActive(&runtime, anatomy_definition, "vulva", false);

    try runtime.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("dual_genital_configuration"));
    try expectActive(&runtime, anatomy_definition, "penis_a", true);
    try expectActive(&runtime, anatomy_definition, "vulva", true);

    try runtime.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("three_breasts"));
    try expectActive(&runtime, anatomy_definition, "left_breast", true);
    try expectActive(&runtime, anatomy_definition, "right_breast", true);
    try expectActive(&runtime, anatomy_definition, "center_breast", true);

    try runtime.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("feminine_with_penis"));
    try expectActive(&runtime, anatomy_definition, "left_breast", true);
    try expectActive(&runtime, anatomy_definition, "right_breast", true);
    try expectActive(&runtime, anatomy_definition, "penis_a", true);
    try expectActive(&runtime, anatomy_definition, "vulva", false);
}

test "hierarchical anatomy rejects dangling parents and cycles" {
    var base = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer base.deinit();
    const view = base.visual_definition.view();
    try expectMinimalDefinitionError(
        view,
        0.8,
        1.2,
        .{ .body_part_socket = .{ .part_instance = "missing", .socket = "child" } },
        .{ .attachment_point = "chest" },
        error.UnknownBodyPartInstance,
    );
    try expectMinimalDefinitionError(
        view,
        0.8,
        1.2,
        .{ .body_part_socket = .{ .part_instance = "part_b", .socket = "child" } },
        .{ .body_part_socket = .{ .part_instance = "part_a", .socket = "child" } },
        error.BodyPartHierarchyCycle,
    );
}

test "faces and hair are per-head groups with independently addressable features" {
    var definition = try modular.initDefinition(std.testing.allocator);
    defer definition.deinit();
    const anatomy_definition = definition.anatomy_definition.?.view();
    var runtime = try anatomy.Runtime.init(std.testing.allocator, anatomy_definition, null);
    defer runtime.deinit();

    try runtime.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("conventional_male"));
    for ([_][]const u8{ "head", "left_eye", "right_eye", "left_eyebrow", "right_eyebrow", "nose", "mouth", "left_ear", "right_ear", "long_hair" }) |name| {
        try expectActive(&runtime, anatomy_definition, name, !std.mem.eql(u8, name, "long_hair"));
    }
    try expectActive(&runtime, anatomy_definition, "eyebrows", false);
    for ([_][]const u8{ "angular_left_eye", "angular_right_eye", "angular_left_eyebrow", "angular_right_eyebrow", "angular_eyebrows", "angular_nose", "angular_mouth", "angular_left_ear", "angular_right_ear" }) |name| {
        try expectActive(&runtime, anatomy_definition, name, false);
    }
    try runtime.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("conventional_female"));
    for ([_][]const u8{ "left_eye", "right_eye", "left_eyebrow", "right_eyebrow", "eyebrows", "nose", "mouth", "left_ear", "right_ear", "short_hair" }) |name| {
        try expectActive(&runtime, anatomy_definition, name, false);
    }
    for ([_][]const u8{ "head", "angular_left_eye", "angular_right_eye", "angular_left_eyebrow", "angular_right_eyebrow", "angular_nose", "angular_mouth", "angular_left_ear", "angular_right_ear", "long_hair" }) |name| {
        try expectActive(&runtime, anatomy_definition, name, true);
    }
    try expectActive(&runtime, anatomy_definition, "angular_eyebrows", false);
    try runtime.selectHair(anatomy_definition, try anatomy_definition.hairDefinitionId("ponytail"));
    try expectActive(&runtime, anatomy_definition, "long_hair", false);
    try expectActive(&runtime, anatomy_definition, "ponytail_hair", true);
    try runtime.selectHair(anatomy_definition, null);
    try expectActive(&runtime, anatomy_definition, "ponytail_hair", false);
    try expectActive(&runtime, anatomy_definition, "head", true);
}

test "two facial configurations use shared modular data and derive distinct independent visuals" {
    var scene = try modular.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const appearance_definition = scene.definition.visual_definition.view();
    try std.testing.expectEqual(@as(usize, 2), anatomy_definition.faces.len);

    const conventional_face = try faceByName(anatomy_definition, "conventional_face");
    const angular_face = try faceByName(anatomy_definition, "angular_face");
    try std.testing.expectEqual(conventional_face.head_part, angular_face.head_part);
    try std.testing.expectEqual(@as(u16, 8), conventional_face.feature_count);
    try std.testing.expectEqual(conventional_face.feature_count, angular_face.feature_count);
    const conventional_features = anatomy_definition.face_features[conventional_face.feature_start .. conventional_face.feature_start + conventional_face.feature_count];
    const angular_features = anatomy_definition.face_features[angular_face.feature_start .. angular_face.feature_start + angular_face.feature_count];
    for (conventional_features, angular_features) |conventional_part_id, angular_part_id| {
        try std.testing.expect(conventional_part_id != angular_part_id);
        try std.testing.expectEqual(
            anatomy_definition.part_instances[conventional_part_id.index()].definition,
            anatomy_definition.part_instances[angular_part_id.index()].definition,
        );
    }

    const conventional_eye_id = try scene.definition.visual_definition.visualId("left_eye");
    const angular_eye_id = try scene.definition.visual_definition.visualId("angular_left_eye");
    const conventional_eye = appearance_definition.visuals[conventional_eye_id.index()];
    const angular_eye = appearance_definition.visuals[angular_eye_id.index()];
    try std.testing.expect(!conventional_eye.local_to_source.approxEqAbs(angular_eye.local_to_source, tolerance));
    try std.testing.expect(!conventional_eye.sprite_size.approxEqAbs(angular_eye.sprite_size, tolerance));
    try std.testing.expect(conventional_eye.tint[1] != angular_eye.tint[1]);

    try std.testing.expect(try scene.conventional_male.character.appearance_runtime.isVisible(appearance_definition, conventional_eye_id));
    try std.testing.expect(!try scene.conventional_male.character.appearance_runtime.isVisible(appearance_definition, angular_eye_id));
    try std.testing.expect(!try scene.conventional_female.character.appearance_runtime.isVisible(appearance_definition, conventional_eye_id));
    try std.testing.expect(try scene.conventional_female.character.appearance_runtime.isVisible(appearance_definition, angular_eye_id));

    try scene.conventional_male.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_female"));
    try std.testing.expect(try scene.conventional_male.character.appearance_runtime.isVisible(appearance_definition, angular_eye_id));
    try scene.conventional_male.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_male"));
    try std.testing.expect(try scene.conventional_male.character.appearance_runtime.isVisible(appearance_definition, conventional_eye_id));
    try std.testing.expect(!try scene.conventional_male.character.appearance_runtime.isVisible(appearance_definition, angular_eye_id));
    try std.testing.expect(!try scene.conventional_female.character.appearance_runtime.isVisible(appearance_definition, conventional_eye_id));
    try std.testing.expect(try scene.conventional_female.character.appearance_runtime.isVisible(appearance_definition, angular_eye_id));
}

test "presentation switching changes visuals without changing anatomy topology" {
    var definition = try modular.initDefinition(std.testing.allocator);
    defer definition.deinit();
    var character_state = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer character_state.deinit();
    try character_state.local_and_world_pose.restoreAllToRest(&definition.skeleton_definition);
    try character_state.local_and_world_pose.evaluateWorld(&definition.skeleton_definition, math.Transform2D.identity());
    try character_state.evaluateAppearance(&definition);

    const anatomy_definition = definition.anatomy_definition.?.view();
    const runtime = if (character_state.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
    const before_topology = try runtime.topologyFingerprint(anatomy_definition);
    const before_count = try runtime.activePartCount(anatomy_definition);
    const simplified_torso = try definition.visual_definition.visualId("torso");
    const modest_torso = try definition.visual_definition.visualId("torso_modest");
    try std.testing.expect(try character_state.appearance_runtime.isVisible(definition.visual_definition.view(), simplified_torso));
    try std.testing.expect(!try character_state.appearance_runtime.isVisible(definition.visual_definition.view(), modest_torso));

    try runtime.selectPresentationProfile(anatomy_definition, try anatomy_definition.presentationProfileId("modest"));
    try character_state.evaluateAppearance(&definition);
    try std.testing.expect(!try character_state.appearance_runtime.isVisible(definition.visual_definition.view(), simplified_torso));
    try std.testing.expect(try character_state.appearance_runtime.isVisible(definition.visual_definition.view(), modest_torso));
    try std.testing.expectEqual(before_topology, try runtime.topologyFingerprint(anatomy_definition));
    try std.testing.expectEqual(before_count, try runtime.activePartCount(anatomy_definition));
}

test "module articulation morphology and presentation leave canonical controller animation interaction and IK state unchanged" {
    var definition = try modular.initDefinition(std.testing.allocator);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    var instance = try character.CharacterInstance.initControlled(
        std.testing.allocator,
        try character.entityIdFromRaw(1),
        &definition,
        &animations,
        &world,
        .{},
        .{ .x = -1, .y = 1.05 },
        .right,
        0,
        null,
    );
    defer instance.deinit();
    const anatomy_definition = definition.anatomy_definition.?.view();
    try instance.selectBodyPreset(try anatomy_definition.bodyPresetId("nonstandard_humanoid"));

    const controller_before = instance.controller.?.state;
    const animation_time_before = instance.animationTime();
    const interaction_owner_before = instance.interaction_owner_id;
    const upper_length_before = instance.right_arm_binding.upper_length;
    const lower_length_before = instance.right_arm_binding.lower_length;
    const canonical_rest_before = (try definition.skeleton_definition.bone(try definition.skeleton_definition.boneIndex(.right_forearm))).rest_local;

    try instance.setGlobalBuild(100);
    try instance.setMorphologyChannelOverride(try anatomy_definition.morphologyChannelId("shoulder_width"), 10);
    try instance.selectPresentationProfile(try anatomy_definition.presentationProfileId("adult_detailed"));
    const anatomy_runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
    const extra_arm = try anatomy_definition.partInstanceId("extra_arm");
    const module_id = try definition.visual_definition.rigModuleId("extra_arm_module");
    const elbow = try definition.visual_definition.moduleJointId(module_id, "elbow");
    const local_before = try instance.character.appearance_runtime.moduleJointLocal(definition.visual_definition.view(), module_id, elbow);
    var local_after = local_before;
    local_after.rotation_radians += 0.2;
    try anatomy_runtime.setPartModuleJointLocal(
        anatomy_definition,
        definition.visual_definition.view(),
        &instance.character.appearance_runtime,
        extra_arm,
        elbow,
        local_after,
    );

    try std.testing.expectEqualDeep(controller_before, instance.controller.?.state);
    try std.testing.expectEqual(animation_time_before, instance.animationTime());
    try std.testing.expectEqual(interaction_owner_before, instance.interaction_owner_id);
    try std.testing.expectEqual(upper_length_before, instance.right_arm_binding.upper_length);
    try std.testing.expectEqual(lower_length_before, instance.right_arm_binding.lower_length);
    try std.testing.expect(canonical_rest_before.approxEqAbs(
        (try definition.skeleton_definition.bone(try definition.skeleton_definition.boneIndex(.right_forearm))).rest_local,
        0,
    ));
    try std.testing.expectEqual(@as(usize, 16), definition.skeleton_definition.boneCount());
}

test "characters share immutable presets but own independent anatomy runtime state" {
    var definition = try modular.initDefinition(std.testing.allocator);
    defer definition.deinit();
    const anatomy_definition = definition.anatomy_definition.?.view();
    var first = try anatomy.Runtime.init(std.testing.allocator, anatomy_definition, null);
    defer first.deinit();
    var second = try anatomy.Runtime.init(std.testing.allocator, anatomy_definition, null);
    defer second.deinit();
    try first.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("conventional_male"));
    try second.selectBodyPreset(anatomy_definition, try anatomy_definition.bodyPresetId("conventional_female"));
    try first.setGlobalBuild(anatomy_definition, 0);
    try second.setGlobalBuild(anatomy_definition, 100);
    const channel = try anatomy_definition.morphologyChannelId("hip_width");
    try std.testing.expect(try first.resolvedChannel(anatomy_definition, channel) != try second.resolvedChannel(anatomy_definition, channel));
    try first.selectHair(anatomy_definition, null);
    try expectActive(&first, anatomy_definition, "short_hair", false);
    try expectActive(&second, anatomy_definition, "long_hair", true);
}

test "modular body evidence route is deterministic and allocation free after initialization" {
    const storage = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(storage);
    var fixed = std.heap.FixedBufferAllocator.init(storage);
    var scene = try modular.Scene.init(fixed.allocator());
    defer scene.deinit();
    const initialized_bytes = fixed.end_index;
    for (0..modular.required_frames) |frame| {
        try scene.updateFrame(@intCast(frame));
        try std.testing.expectEqual(initialized_bytes, fixed.end_index);
    }
    try scene.validateComplete();
    try std.testing.expectEqual(initialized_bytes, fixed.end_index);

    var first = try modular.Scene.init(std.testing.allocator);
    defer first.deinit();
    var second = try modular.Scene.init(std.testing.allocator);
    defer second.deinit();
    for (0..modular.required_frames) |frame| {
        try first.updateFrame(@intCast(frame));
        try second.updateFrame(@intCast(frame));
    }
    try first.validateComplete();
    try second.validateComplete();
    try std.testing.expectEqual(first.total_visual_ticks, second.total_visual_ticks);
    try std.testing.expectEqual(first.presentation_switches, second.presentation_switches);
    try std.testing.expectEqual(first.hair_switches, second.hair_switches);
    inline for (.{ "conventional_male", "conventional_female", "nonstandard" }) |field_name| {
        const left: *const character.CharacterInstance = &@field(first, field_name);
        const right: *const character.CharacterInstance = &@field(second, field_name);
        try std.testing.expectEqual(left.animationTime(), right.animationTime());
        try std.testing.expectEqual(try topology(left), try topology(right));
    }
}

fn expectActive(
    runtime: *const anatomy.Runtime,
    definition: anatomy.DefinitionView,
    part_name: []const u8,
    expected: bool,
) !void {
    try std.testing.expectEqual(expected, try runtime.isPartActive(definition, try definition.partInstanceId(part_name)));
}

fn topology(instance: *const character.CharacterInstance) !u64 {
    const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
    const runtime = instance.character.anatomy_runtime orelse return error.CharacterHasNoAnatomy;
    return runtime.topologyFingerprint(definition);
}

fn faceByName(definition: anatomy.DefinitionView, name: []const u8) !anatomy.FaceDefinition {
    for (definition.faces) |face| {
        if (std.mem.eql(u8, face.stable_id.slice(), name)) return face;
    }
    return error.FaceDefinitionNotFound;
}

fn expectMinimalDefinitionError(
    appearance_definition: appearance.DefinitionView,
    low: f32,
    high: f32,
    parent_a: anatomy.BodyPartParentInput,
    parent_b: anatomy.BodyPartParentInput,
    expected_error: anyerror,
) !void {
    const channels = [_]anatomy.MorphologyChannelInput{.{ .stable_id = "width" }};
    const ranges = [_]anatomy.MorphologyRangeInput{.{ .channel = "width", .low = low, .high = high }};
    const presets = [_]anatomy.MorphologyPresetInput{.{ .stable_id = "average", .ranges = &ranges }};
    const profiles = [_]anatomy.PresentationProfileInput{.{ .stable_id = "simple", .detail_tag = "non_explicit" }};
    const child_sockets = [_]anatomy.ChildSocketInput{.{
        .stable_id = "child",
        .local_to_part = math.Transform2D.identity(),
    }};
    const definitions = [_]anatomy.BodyPartDefinitionInput{.{
        .stable_id = "part",
        .category_tag = "test",
        .type_tag = "test_part",
        .tags = &.{"test"},
        .child_sockets = &child_sockets,
        .morphology_bindings = &.{},
    }};
    const no_visuals = [_][]const u8{};
    const variants_a = [_]anatomy.VisualVariantInput{.{ .presentation_profile = "simple", .visuals = &no_visuals }};
    const variants_b = [_]anatomy.VisualVariantInput{.{ .presentation_profile = "simple", .visuals = &no_visuals }};
    const instances = [_]anatomy.BodyPartInstanceInput{
        .{
            .stable_id = "part_a",
            .definition = "part",
            .parent = parent_a,
            .local_to_parent = math.Transform2D.identity(),
            .body_region = "torso",
            .visual_group = "body",
            .base_render_layer = 0,
            .presentation_variants = &variants_a,
        },
        .{
            .stable_id = "part_b",
            .definition = "part",
            .parent = parent_b,
            .local_to_parent = math.Transform2D.identity(),
            .body_region = "torso",
            .visual_group = "body",
            .base_render_layer = 0,
            .presentation_variants = &variants_b,
        },
    };
    const active_parts = [_][]const u8{ "part_a", "part_b" };
    const body_presets = [_]anatomy.BodyPresetInput{.{
        .stable_id = "body",
        .active_parts = &active_parts,
        .faces = &.{},
        .hair = null,
        .morphology_preset = "average",
        .global_build = 50,
        .presentation_profile = "simple",
    }};
    try std.testing.expectError(expected_error, anatomy.Definition.init(
        std.testing.allocator,
        appearance_definition,
        .{
            .morphology_channels = &channels,
            .morphology_presets = &presets,
            .presentation_profiles = &profiles,
            .part_definitions = &definitions,
            .part_instances = &instances,
            .faces = &.{},
            .hair_definitions = &.{},
            .body_presets = &body_presets,
            .default_body_preset = "body",
        },
        null,
    ));
}
