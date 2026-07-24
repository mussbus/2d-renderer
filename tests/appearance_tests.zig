const std = @import("std");
const math = @import("math");
const appearance = @import("appearance");
const humanoid = @import("humanoid");
const sprite = @import("sprite_batch");

const tolerance: f32 = 1e-5;
const extended_visual_count: usize = humanoid.default_visual_count + 6;

fn extraVisual(
    name: []const u8,
    source: appearance.TransformSourceInput,
    layer: u16,
) appearance.VisualAttachmentInput {
    return .{
        .debug_name = name,
        .canonical_semantic = null,
        .transform_source = source,
        .local_to_source = math.Transform2D.identity(),
        .body_region = "decorative",
        .visual_group = "test_accessory",
        .sprite_size = .{ .x = 0.16, .y = 0.12 },
        .pivot = .{ 0.5, 0.5 },
        .uv_rect = .{ 0, 0, 0.5, 0.5 },
        .tint = .{ 1, 1, 1, 1 },
        .texture_page = 0,
        .body_part_layer = layer,
    };
}

fn makeExtendedDefinition(allocator: std.mem.Allocator) !humanoid.HumanoidDefinition {
    const bones = humanoid.boneInputs();
    const sockets = humanoid.socketInputs();

    const default_points = humanoid.attachmentPointInputs();
    var points: [humanoid.conventional_attachment_point_count + 1]appearance.AttachmentPointInput = undefined;
    @memcpy(points[0..default_points.len], &default_points);
    points[default_points.len] = .{
        .debug_name = "custom_mount",
        .parent = .{ .attachment_point = "chest" },
        .local_to_parent = math.Transform2D.init(.{ .x = 0.42, .y = 0.18 }, 0.12, math.Vec2.one),
    };

    const default_regions = humanoid.bodyRegionInputs();
    var regions: [humanoid.default_body_region_count + 1]appearance.BodyRegionInput = undefined;
    @memcpy(regions[0..default_regions.len], &default_regions);
    regions[default_regions.len] = .{ .debug_name = "decorative" };

    const default_groups = humanoid.visualGroupInputs();
    var groups: [humanoid.default_visual_group_count + 1]appearance.VisualGroupInput = undefined;
    @memcpy(groups[0..default_groups.len], &default_groups);
    groups[default_groups.len] = .{ .debug_name = "test_accessory" };

    const joints = [_]appearance.ModuleJointInput{
        .{
            .debug_name = "hinge",
            .parent_joint = null,
            .rest_local = math.Transform2D.init(.{ .x = 0.20, .y = 0 }, 0, math.Vec2.one),
        },
        .{
            .debug_name = "tip",
            .parent_joint = "hinge",
            .rest_local = math.Transform2D.init(.{ .x = 0.30, .y = 0 }, 0, math.Vec2.one),
        },
    };
    const module_sockets = [_]appearance.ModuleSocketInput{
        .{
            .debug_name = "tip_socket",
            .parent_joint = "tip",
            .local_to_parent = math.Transform2D.init(.{ .x = 0.14, .y = 0 }, 0, math.Vec2.one),
        },
    };
    const modules = [_]appearance.RigModuleInput{
        .{
            .debug_name = "test_chain",
            .parent_attachment_point = "custom_mount",
            .local_to_attachment_point = math.Transform2D.identity(),
            .joints = &joints,
            .sockets = &module_sockets,
        },
    };

    const default_visuals = humanoid.attachmentInputs();
    var visuals: [extended_visual_count]appearance.VisualAttachmentInput = undefined;
    @memcpy(visuals[0..default_visuals.len], &default_visuals);
    visuals[humanoid.default_visual_count] = extraVisual("custom_badge_a", .{ .attachment_point = "custom_mount" }, 80);
    visuals[humanoid.default_visual_count + 1] = extraVisual("custom_badge_b", .{ .attachment_point = "custom_mount" }, 80);
    visuals[humanoid.default_visual_count + 2] = extraVisual("module_tip_marker", .{
        .module_socket = .{ .module_name = "test_chain", .member_name = "tip_socket" },
    }, 81);
    visuals[humanoid.default_visual_count + 3] = extraVisual("module_joint_marker", .{
        .module_joint = .{ .module_name = "test_chain", .member_name = "tip" },
    }, 81);
    visuals[humanoid.default_visual_count + 4] = extraVisual("module_tip_marker_b", .{
        .module_socket = .{ .module_name = "test_chain", .member_name = "tip_socket" },
    }, 81);
    visuals[humanoid.default_visual_count + 5] = extraVisual("badge_child", .{ .visual_attachment = "custom_badge_a" }, 82);
    visuals[humanoid.default_visual_count + 5].local_to_source =
        math.Transform2D.init(.{ .x = 0.10, .y = 0.08 }, 0, .{ .x = 0.75, .y = 0.75 });

    return humanoid.HumanoidDefinition.initFromVisualDefinition(allocator, &bones, &sockets, .{
        .attachment_points = &points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &modules,
        .visuals = &visuals,
    }, null);
}

fn evaluateRest(
    character: *humanoid.HumanoidCharacter,
    definition: *const humanoid.HumanoidDefinition,
    character_to_world: math.Transform2D,
) !void {
    try character.local_and_world_pose.restoreAllToRest(&definition.skeleton_definition);
    character.character_to_world = character_to_world;
    try character.local_and_world_pose.evaluateWorld(&definition.skeleton_definition, character_to_world);
    try character.evaluateAppearance(definition);
}

test "generalized definition keeps canonical rig invariant and assigns stable custom ids" {
    var first = try makeExtendedDefinition(std.testing.allocator);
    defer first.deinit();
    var second = try makeExtendedDefinition(std.testing.allocator);
    defer second.deinit();

    try std.testing.expectEqual(@as(usize, 16), first.skeleton_definition.bones.len);
    const canonical_inputs = humanoid.boneInputs();
    for (first.skeleton_definition.bones, canonical_inputs) |bone, input| {
        try std.testing.expectEqual(input.parent_index orelse std.math.maxInt(u16), bone.parent_index);
        try std.testing.expect(bone.rest_local.approxEqAbs(input.rest_local, tolerance));
        try std.testing.expectEqual(input.semantic, @intFromEnum(bone.semantic));
    }
    try std.testing.expectEqual(@as(usize, extended_visual_count), first.attachments.len);

    const first_point = try first.visual_definition.attachmentPointId("custom_mount");
    const second_point = try second.visual_definition.attachmentPointId("custom_mount");
    try std.testing.expectEqual(first_point, second_point);
    try std.testing.expectEqual(@as(u16, humanoid.conventional_attachment_point_count), @intFromEnum(first_point));

    const first_visual = try first.visual_definition.visualId("custom_badge_a");
    const second_visual = try second.visual_definition.visualId("custom_badge_a");
    try std.testing.expectEqual(first_visual, second_visual);
    try std.testing.expectEqual(@as(u16, humanoid.default_visual_count), @intFromEnum(first_visual));
    try std.testing.expectEqual(@as(u16, humanoid.default_body_region_count), @intFromEnum(try first.visual_definition.bodyRegionId("decorative")));
    try std.testing.expectEqual(@as(u16, humanoid.default_visual_group_count), @intFromEnum(try first.visual_definition.visualGroupId("test_accessory")));

    const module_id = try first.visual_definition.rigModuleId("test_chain");
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(module_id));
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(try first.visual_definition.moduleJointId(module_id, "hinge")));
    try std.testing.expectEqual(@as(u16, 1), @intFromEnum(try first.visual_definition.moduleJointId(module_id, "tip")));
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(try first.visual_definition.moduleSocketId(module_id, "tip_socket")));
}

test "zero visuals and variable counts initialize submit and clean up without a special path" {
    const bones = humanoid.boneInputs();
    const sockets = humanoid.socketInputs();
    const points = humanoid.attachmentPointInputs();
    const regions = humanoid.bodyRegionInputs();
    const groups = humanoid.visualGroupInputs();
    const modules = [_]appearance.RigModuleInput{};
    const visuals = [_]appearance.VisualAttachmentInput{};
    var definition = try humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &modules,
        .visuals = &visuals,
    }, null);
    defer definition.deinit();
    try std.testing.expectEqual(@as(usize, 0), definition.attachments.len);
    try std.testing.expectError(error.MissingCanonicalVisual, definition.attachment(.right_hand));

    var character = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer character.deinit();
    try evaluateRest(&character, &definition, math.Transform2D.identity());
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 1, 1);
    defer batch.deinit();
    batch.beginFrame();
    try std.testing.expectEqual(@as(u32, 0), try character.submitAttachments(&definition, &batch, 0));
    try std.testing.expectEqual(@as(usize, 0), batch.prepare().sprites.len);
}

test "multiple visuals share one data-defined attachment point and visual hierarchy is bounded" {
    var definition = try makeExtendedDefinition(std.testing.allocator);
    defer definition.deinit();
    var character = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer character.deinit();
    try evaluateRest(&character, &definition, math.Transform2D.identity());

    const badge_a = try definition.visual_definition.visualId("custom_badge_a");
    const badge_b = try definition.visual_definition.visualId("custom_badge_b");
    const child = try definition.visual_definition.visualId("badge_child");
    const a_world = try character.appearance_runtime.visualWorld(definition.visual_definition.view(), badge_a);
    const b_world = try character.appearance_runtime.visualWorld(definition.visual_definition.view(), badge_b);
    const child_world = try character.appearance_runtime.visualWorld(definition.visual_definition.view(), child);
    const module_socket_visual = try definition.visual_definition.visualId("module_tip_marker");
    const second_module_socket_visual = try definition.visual_definition.visualId("module_tip_marker_b");
    const module_joint_visual = try definition.visual_definition.visualId("module_joint_marker");
    const module_socket_world = try character.appearance_runtime.visualWorld(definition.visual_definition.view(), module_socket_visual);
    const second_module_socket_world = try character.appearance_runtime.visualWorld(definition.visual_definition.view(), second_module_socket_visual);
    const module_joint_world = try character.appearance_runtime.visualWorld(definition.visual_definition.view(), module_joint_visual);
    try std.testing.expect(a_world.approxEqAbs(b_world, tolerance));
    try std.testing.expect(!a_world.approxEqAbs(child_world, tolerance));
    try std.testing.expect(module_socket_world.approxEqAbs(second_module_socket_world, tolerance));
    try std.testing.expect(!module_socket_world.approxEqAbs(module_joint_world, tolerance));
    try std.testing.expectEqual(@as(u8, 2), definition.attachments[child.index()].hierarchy_depth);
}

test "invalid duplicate dangling and cyclic definitions fail transactionally" {
    const bones = humanoid.boneInputs();
    const sockets = humanoid.socketInputs();
    const regions = humanoid.bodyRegionInputs();
    const groups = humanoid.visualGroupInputs();
    const no_modules = [_]appearance.RigModuleInput{};
    const no_visuals = [_]appearance.VisualAttachmentInput{};

    var duplicate_points = humanoid.attachmentPointInputs();
    duplicate_points[1].debug_name = duplicate_points[0].debug_name;
    try std.testing.expectError(error.DuplicateAttachmentPointId, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &duplicate_points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &no_modules,
        .visuals = &no_visuals,
    }, null));

    var dangling_points = humanoid.attachmentPointInputs();
    dangling_points[0].parent = .{ .attachment_point = "not_defined" };
    try std.testing.expectError(error.DanglingAttachmentPointReference, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &dangling_points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &no_modules,
        .visuals = &no_visuals,
    }, null));

    var duplicate_regions = humanoid.bodyRegionInputs();
    duplicate_regions[1].debug_name = duplicate_regions[0].debug_name;
    const valid_points = humanoid.attachmentPointInputs();
    try std.testing.expectError(error.DuplicateBodyRegionId, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &valid_points,
        .body_regions = &duplicate_regions,
        .visual_groups = &groups,
        .rig_modules = &no_modules,
        .visuals = &no_visuals,
    }, null));

    var cyclic_points = humanoid.attachmentPointInputs();
    cyclic_points[0].parent = .{ .attachment_point = "face" };
    cyclic_points[1].parent = .{ .attachment_point = "head_scalp" };
    try std.testing.expectError(error.AttachmentPointCycle, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &cyclic_points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &no_modules,
        .visuals = &no_visuals,
    }, null));

    const deep_names = [_][]const u8{
        "depth_00", "depth_01", "depth_02", "depth_03", "depth_04", "depth_05",
        "depth_06", "depth_07", "depth_08", "depth_09", "depth_10", "depth_11",
        "depth_12", "depth_13", "depth_14", "depth_15", "depth_16",
    };
    var deep_points: [appearance.maximum_hierarchy_depth + 1]appearance.AttachmentPointInput = undefined;
    for (&deep_points, 0..) |*point, index| {
        point.* = .{
            .debug_name = deep_names[index],
            .parent = if (index == 0)
                .{ .canonical_bone = 0 }
            else
                .{ .attachment_point = deep_names[index - 1] },
            .local_to_parent = math.Transform2D.identity(),
        };
    }
    try std.testing.expectError(error.AttachmentHierarchyTooDeep, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &deep_points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &no_modules,
        .visuals = &no_visuals,
    }, null));

    const points = humanoid.attachmentPointInputs();
    var duplicate_visuals = [_]appearance.VisualAttachmentInput{
        extraVisual("duplicate", .{ .attachment_point = "chest" }, 80),
        extraVisual("duplicate", .{ .attachment_point = "chest" }, 81),
    };
    for (&duplicate_visuals) |*visual| {
        visual.body_region = "head";
        visual.visual_group = "body";
    }
    try std.testing.expectError(error.DuplicateVisualAttachmentId, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &no_modules,
        .visuals = &duplicate_visuals,
    }, null));

    duplicate_visuals[1].debug_name = "second";
    duplicate_visuals[0].transform_source = .{ .visual_attachment = "second" };
    duplicate_visuals[1].transform_source = .{ .visual_attachment = "duplicate" };
    try std.testing.expectError(error.VisualAttachmentCycle, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &no_modules,
        .visuals = &duplicate_visuals,
    }, null));

    duplicate_visuals[0].transform_source = .{ .attachment_point = "missing_point" };
    duplicate_visuals[1].transform_source = .{ .attachment_point = "chest" };
    try std.testing.expectError(error.DanglingAttachmentPointReference, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &no_modules,
        .visuals = &duplicate_visuals,
    }, null));

    const cyclic_joints = [_]appearance.ModuleJointInput{
        .{ .debug_name = "a", .parent_joint = "b", .rest_local = math.Transform2D.identity() },
        .{ .debug_name = "b", .parent_joint = "a", .rest_local = math.Transform2D.identity() },
    };
    const no_module_sockets = [_]appearance.ModuleSocketInput{};
    const cyclic_modules = [_]appearance.RigModuleInput{
        .{
            .debug_name = "cyclic_module",
            .parent_attachment_point = "chest",
            .local_to_attachment_point = math.Transform2D.identity(),
            .joints = &cyclic_joints,
            .sockets = &no_module_sockets,
        },
    };
    try std.testing.expectError(error.ModuleJointCycle, humanoid.HumanoidDefinition.initFromVisualDefinition(std.testing.allocator, &bones, &sockets, .{
        .attachment_points = &points,
        .body_regions = &regions,
        .visual_groups = &groups,
        .rig_modules = &cyclic_modules,
        .visuals = &no_visuals,
    }, null));

    var clean = try makeExtendedDefinition(std.testing.allocator);
    clean.deinit();
}

test "appearance and module mutable state are instance-owned and resettable" {
    var definition = try makeExtendedDefinition(std.testing.allocator);
    defer definition.deinit();
    var a = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer a.deinit();
    var b = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer b.deinit();
    try evaluateRest(&a, &definition, math.Transform2D.identity());
    try evaluateRest(&b, &definition, math.Transform2D.identity());

    const view = definition.visual_definition.view();
    const badge = try definition.visual_definition.visualId("custom_badge_a");
    const marker = try definition.visual_definition.visualId("module_tip_marker");
    const module_id = try definition.visual_definition.rigModuleId("test_chain");
    const hinge_id = try definition.visual_definition.moduleJointId(module_id, "hinge");
    const a_initial_badge = try a.appearance_runtime.visualWorld(view, badge);
    const b_initial_badge = try b.appearance_runtime.visualWorld(view, badge);
    const b_initial_marker = try b.appearance_runtime.visualWorld(view, marker);

    try a.appearance_runtime.setVisible(view, badge, false);
    try a.appearance_runtime.setVisualDeformation(
        view,
        badge,
        math.Transform2D.init(.{ .x = 0.35, .y = 0 }, 0.2, math.Vec2.one),
    );
    var hinge = try a.appearance_runtime.moduleJointLocal(view, module_id, hinge_id);
    hinge.rotation_radians = 0.7;
    try a.appearance_runtime.setModuleJointLocal(view, module_id, hinge_id, hinge);
    try a.appearance_runtime.evaluate(view, &definition.skeleton_definition, &a.local_and_world_pose);

    try std.testing.expect(!try a.appearance_runtime.isVisible(view, badge));
    try std.testing.expect(try b.appearance_runtime.isVisible(view, badge));
    try std.testing.expect(!a_initial_badge.approxEqAbs(try a.appearance_runtime.visualWorld(view, badge), tolerance));
    try std.testing.expect(b_initial_badge.approxEqAbs(try b.appearance_runtime.visualWorld(view, badge), tolerance));
    try std.testing.expect(b_initial_marker.approxEqAbs(try b.appearance_runtime.visualWorld(view, marker), tolerance));
    try std.testing.expectApproxEqAbs(@as(f32, 0), (try b.appearance_runtime.moduleJointLocal(view, module_id, hinge_id)).rotation_radians, tolerance);

    try a.appearance_runtime.reset(view);
    try a.appearance_runtime.evaluate(view, &definition.skeleton_definition, &a.local_and_world_pose);
    try std.testing.expect(try a.appearance_runtime.isVisible(view, badge));
    try std.testing.expect(a_initial_badge.approxEqAbs(try a.appearance_runtime.visualWorld(view, badge), tolerance));
    try std.testing.expectApproxEqAbs(@as(f32, 0), (try a.appearance_runtime.moduleJointLocal(view, module_id, hinge_id)).rotation_radians, tolerance);
}

test "custom attachment and module visuals mirror with the canonical character root" {
    var definition = try makeExtendedDefinition(std.testing.allocator);
    defer definition.deinit();
    var right = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer right.deinit();
    var left = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer left.deinit();

    try evaluateRest(&right, &definition, math.Transform2D.identity());
    try evaluateRest(&left, &definition, math.Transform2D.init(math.Vec2.zero, 0, .{ .x = -1, .y = 1 }));
    const view = definition.visual_definition.view();
    for ([_][]const u8{ "custom_badge_a", "module_tip_marker", "badge_child" }) |name| {
        const id = try definition.visual_definition.visualId(name);
        const right_position = (try right.appearance_runtime.visualWorld(view, id)).translationPart();
        const left_position = (try left.appearance_runtime.visualWorld(view, id)).translationPart();
        try std.testing.expectApproxEqAbs(-right_position.x, left_position.x, tolerance);
        try std.testing.expectApproxEqAbs(right_position.y, left_position.y, tolerance);
    }
}

test "extended visuals preserve deterministic input order for equal draw layers" {
    var definition = try makeExtendedDefinition(std.testing.allocator);
    defer definition.deinit();
    var character = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
    defer character.deinit();
    try evaluateRest(&character, &definition, math.Transform2D.identity());
    var batch = try sprite.SpriteBatch.init(std.testing.allocator, 32, 1);
    defer batch.deinit();

    var previous_indices: [2]u64 = undefined;
    for (0..2) |pass| {
        batch.beginFrame();
        try std.testing.expectEqual(@as(u32, extended_visual_count), try character.submitAttachments(&definition, &batch, 3));
        const prepared = batch.prepare();
        var equal_layer_indices: [2]u64 = undefined;
        var count: usize = 0;
        for (prepared.sprites) |submission| {
            if (submission.order.body_part_layer != 80) continue;
            equal_layer_indices[count] = submission.order.submission_index;
            count += 1;
        }
        try std.testing.expectEqual(@as(usize, 2), count);
        try std.testing.expect(equal_layer_indices[0] < equal_layer_indices[1]);
        if (pass == 1) try std.testing.expectEqual(previous_indices, equal_layer_indices);
        previous_indices = equal_layer_indices;
    }
}

test "appearance evaluation and mutation allocate zero bytes after initialization" {
    var storage: [192 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var definition = try makeExtendedDefinition(fixed.allocator());
    defer definition.deinit();
    var character = try humanoid.HumanoidCharacter.init(fixed.allocator(), &definition, null);
    defer character.deinit();
    try evaluateRest(&character, &definition, math.Transform2D.identity());
    var batch = try sprite.SpriteBatch.init(fixed.allocator(), 32, 1);
    defer batch.deinit();
    batch.markStabilized();
    const initialized_bytes = fixed.end_index;

    const view = definition.visual_definition.view();
    const badge = try definition.visual_definition.visualId("custom_badge_a");
    const module_id = try definition.visual_definition.rigModuleId("test_chain");
    const hinge_id = try definition.visual_definition.moduleJointId(module_id, "hinge");
    for (0..128) |index| {
        try character.appearance_runtime.setVisible(view, badge, index % 2 == 0);
        try character.appearance_runtime.setVisualDeformation(
            view,
            badge,
            math.Transform2D.init(.{ .x = @as(f32, @floatFromInt(index)) * 0.001, .y = 0 }, 0, math.Vec2.one),
        );
        var hinge = try character.appearance_runtime.moduleJointLocal(view, module_id, hinge_id);
        hinge.rotation_radians = @as(f32, @floatFromInt(index)) * 0.002;
        try character.appearance_runtime.setModuleJointLocal(view, module_id, hinge_id, hinge);
        try character.appearance_runtime.evaluate(view, &definition.skeleton_definition, &character.local_and_world_pose);
        batch.beginFrame();
        _ = try character.submitAttachments(&definition, &batch, 0);
        _ = batch.prepare();
    }
    try std.testing.expectEqual(initialized_bytes, fixed.end_index);
    try std.testing.expectEqual(@as(u64, 0), batch.lifetime_metrics.cpu_allocations_after_stabilization);
}
