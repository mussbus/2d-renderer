const std = @import("std");
const math = @import("math");
const anatomy = @import("anatomy");
const appearance = @import("appearance");
const component_graph = @import("component_graph");
const humanoid = @import("humanoid");
const modular_body = @import("modular_body_demo");
const presentation_pose = @import("presentation_pose");

const tolerance: f32 = 0.00001;

test "compiled graph exposes typed eye brow hair module and intentional gap proofs" {
    var scene = try modular_body.Scene.init(std.testing.allocator);
    defer scene.deinit();

    const appearance_definition = scene.definition.visual_definition.view();
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const compiled = scene.definition.component_graph_definition orelse
        return error.ComponentGraphMissing;
    const graph = try compiled.view(
        appearance_definition,
        anatomy_definition,
    );

    const left_eye_id = try anatomy_definition.partInstanceId("left_eye");
    const left_brow_id = try anatomy_definition.partInstanceId("left_eyebrow");
    const left_eye = try graph.component(left_eye_id);
    const left_brow = try graph.component(left_brow_id);
    try std.testing.expectEqual(left_eye_id, left_brow.parent_component.?);
    const brow_socket = anatomy_definition.instance_sockets[
        left_brow.parent_socket.?.index()
    ];
    try std.testing.expectEqualStrings("brow", brow_socket.stable_id.slice());
    try std.testing.expectEqualStrings("eye_brow", brow_socket.role.?.slice());
    try std.testing.expectEqual(anatomy.BindingMode.point, left_eye.definition.binding_mode);
    try std.testing.expectEqual(anatomy.TopologyStatus.direct, left_brow.instance.topology_status);
    const left_brow_visuals = try graph.boundVisuals(
        left_brow_id,
        scene.conventional_male.character.anatomy_runtime.?.selected_presentation_profile,
    );
    try std.testing.expectEqual(@as(usize, 1), left_brow_visuals.len);
    try std.testing.expectEqualStrings(
        "left_eyebrow",
        appearance_definition.visuals[left_brow_visuals[0].index()].debug_name.slice(),
    );

    const long_hair_id = try anatomy_definition.partInstanceId("long_hair");
    const long_hair = try graph.component(long_hair_id);
    const head_id = try anatomy_definition.partInstanceId("head");
    try std.testing.expectEqual(head_id, long_hair.parent_component.?);
    try std.testing.expectEqualStrings(
        "head_scalp",
        anatomy_definition.instance_sockets[
            long_hair.parent_socket.?.index()
        ].role.?.slice(),
    );
    const hair_visuals = try graph.boundVisuals(
        long_hair_id,
        scene.conventional_female.character.anatomy_runtime.?.selected_presentation_profile,
    );
    try std.testing.expectEqual(@as(usize, 1), hair_visuals.len);

    const extra_arm_id = try anatomy_definition.partInstanceId("extra_arm");
    const extra_arm = try graph.component(extra_arm_id);
    try std.testing.expectEqual(
        try anatomy_definition.partInstanceId("torso"),
        extra_arm.parent_component.?,
    );
    const articulation = (try graph.articulation(extra_arm_id)).?;
    try std.testing.expectEqual(@as(usize, 3), articulation.joints.len);
    try std.testing.expectEqual(@as(usize, 1), articulation.sockets.len);
    try std.testing.expectEqualStrings("shoulder", articulation.joints[0].debug_name.slice());
    try std.testing.expectEqualStrings("elbow", articulation.joints[1].debug_name.slice());
    try std.testing.expectEqualStrings("wrist", articulation.joints[2].debug_name.slice());
    try std.testing.expectEqualStrings("hand_tip", articulation.sockets[0].debug_name.slice());

    const detached_id = try anatomy_definition.partInstanceId("extra_arm_second");
    const detached = try graph.component(detached_id);
    try std.testing.expectEqual(
        anatomy.ConnectionMode.intentional_gap,
        std.meta.activeTag(detached.instance.connection),
    );
    try std.testing.expectApproxEqAbs(
        @as(f32, 0.08),
        component_graph.measuredGap(detached.instance),
        tolerance,
    );
}

test "continuous and intentional gap contracts keep world-metre separation fail closed" {
    const continuous = anatomy.Connection{
        .continuous = .{ .maximum_gap = 0.02 },
    };
    const intentional = anatomy.Connection{
        .intentional_gap = .{
            .minimum_gap = 0.07,
            .maximum_gap = 0.09,
        },
    };
    try anatomy.validateConnectionGeometry(continuous, 0);
    try anatomy.validateConnectionGeometry(continuous, 0.00001);
    try std.testing.expectError(
        error.ContinuousConnectionGapExceeded,
        anatomy.validateConnectionGeometry(continuous, 0.08),
    );
    try anatomy.validateConnectionGeometry(intentional, 0.08);
    try std.testing.expectError(
        error.InvalidIntentionalGapBounds,
        anatomy.validateConnectionGeometry(intentional, 0.069),
    );
    try std.testing.expectError(
        error.InvalidIntentionalGapBounds,
        anatomy.validateConnectionGeometry(intentional, 0.091),
    );

    const scaled_parent = math.Mat3.translation(.{ .x = 2, .y = 3 })
        .mul(math.Mat3.rotation(0.6))
        .mul(math.Mat3.nonuniformScale(.{ .x = 1.25, .y = 0.8 }));
    const local_gap = math.Transform2D.init(
        .{ .x = 0.08, .y = 0 },
        0,
        math.Vec2.one,
    );
    const bound = try anatomy.connectionBindingWorld(
        scaled_parent,
        local_gap,
        intentional,
    );
    const gap = bound.translationPart().sub(
        scaled_parent.translationPart(),
    );
    try std.testing.expect(gap.isFinite());
    try std.testing.expectApproxEqAbs(@as(f32, 0.08), gap.length(), tolerance);

    const reflected_parent = math.Mat3.translation(.{ .x = 2, .y = 3 })
        .mul(math.Mat3.rotation(std.math.pi));
    const reflected = try anatomy.connectionBindingWorld(
        reflected_parent,
        local_gap,
        intentional,
    );
    const reflected_gap = reflected.translationPart().sub(
        reflected_parent.translationPart(),
    );
    try std.testing.expectApproxEqAbs(
        @as(f32, 0.08),
        reflected_gap.length(),
        tolerance,
    );
    try std.testing.expect(reflected_gap.x < 0);
}

test "eye deformation moves its eyebrow child and topology remains immutable" {
    var scene = try modular_body.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const appearance_definition = scene.definition.visual_definition.view();
    const compiled = scene.definition.component_graph_definition.?;
    const runtime = &scene.conventional_male.character.anatomy_runtime.?;

    try scene.conventional_male.character.evaluateAppearance(&scene.definition);
    const eye_id = try anatomy_definition.partInstanceId("left_eye");
    const brow_id = try anatomy_definition.partInstanceId("left_eyebrow");
    const brow_socket_id = switch (anatomy_definition.part_instances[brow_id.index()].parent) {
        .body_part_socket => |socket_id| socket_id,
        else => return error.EyebrowMissingTypedParent,
    };
    const before = runtime.part_world[brow_id.index()].translationPart();

    runtime.part_deformation_local[eye_id.index()] = math.Transform2D.init(
        .{ .x = 0.06, .y = 0.03 },
        0.12,
        .{ .x = 1.15, .y = 0.90 },
    );
    try runtime.evaluateHierarchy(
        anatomy_definition,
        appearance_definition,
        &scene.conventional_male.character.appearance_runtime,
    );
    const after = runtime.part_world[brow_id.index()].translationPart();
    try std.testing.expect(!before.approxEqAbs(after, tolerance));
    try std.testing.expect(runtime.part_world[brow_id.index()].approxEqAbs(
        runtime.socket_world[brow_socket_id.index()],
        tolerance,
    ));

    var mutated_instances = [_]anatomy.BodyPartInstance{undefined} **
        anatomy.maximum_part_instances;
    @memcpy(
        mutated_instances[0..anatomy_definition.part_instances.len],
        anatomy_definition.part_instances,
    );
    mutated_instances[eye_id.index()].local_to_parent.translation.x += 0.01;
    var mutated_view = anatomy_definition;
    mutated_view.part_instances =
        mutated_instances[0..anatomy_definition.part_instances.len];
    try std.testing.expectError(
        error.RuntimeTopologyMutation,
        compiled.validateCompatibility(appearance_definition, mutated_view),
    );
}

test "front side-left and side-right projections retain graph and module sources" {
    var scene = try modular_body.Scene.init(std.testing.allocator);
    defer scene.deinit();
    try scene.nonstandard.character.evaluateAppearance(&scene.definition);
    const anatomy_definition = scene.definition.anatomy_definition.?.view();
    const appearance_definition = scene.definition.visual_definition.view();
    const instance = &scene.nonstandard;
    const front = try presentation_pose.FrontProjection.init(
        &scene.definition.skeleton_definition,
        instance.character.local_and_world_pose,
        appearance_definition,
        instance.character.appearance_runtime,
        instance.world_position,
    );
    const side_right = try presentation_pose.FrontProjection.initSide(
        &scene.definition.skeleton_definition,
        instance.character.local_and_world_pose,
        appearance_definition,
        instance.character.appearance_runtime,
        instance.world_position,
        false,
    );
    const side_left = try presentation_pose.FrontProjection.initSide(
        &scene.definition.skeleton_definition,
        instance.character.local_and_world_pose,
        appearance_definition,
        instance.character.appearance_runtime,
        instance.world_position,
        true,
    );
    const extra_visual = try scene.definition.visual_definition.visualId(
        "extra_upper_arm",
    );
    const front_world = try front.visualWorld(
        instance.character.appearance_runtime,
        appearance_definition.visuals[extra_visual.index()],
    );
    const right_world = try side_right.visualWorld(
        instance.character.appearance_runtime,
        appearance_definition.visuals[extra_visual.index()],
    );
    const left_world = try side_left.visualWorld(
        instance.character.appearance_runtime,
        appearance_definition.visuals[extra_visual.index()],
    );
    try std.testing.expect(front_world.isFinite());
    try std.testing.expect(right_world.isFinite());
    try std.testing.expect(left_world.isFinite());
    try std.testing.expect(!right_world.approxEqAbs(left_world, tolerance));

    const front_anatomy = try presentation_pose.FrontAnatomyProjection.init(
        front,
        anatomy_definition,
        instance.character.anatomy_runtime.?,
    );
    const detached = try anatomy_definition.partInstanceId("extra_arm_second");
    try std.testing.expect(front_anatomy.part_world[detached.index()].isFinite());
}

test "typed component inputs fail closed across invalid topology contracts" {
    inline for (std.enums.values(InvalidFixture)) |fixture| {
        try expectInvalidFixture(fixture);
    }
}

test "compiled graph rejects missing module members unsupported front and child-follow drift" {
    var scene = try modular_body.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const base_appearance = scene.definition.visual_definition.view();
    const base_anatomy = scene.definition.anatomy_definition.?.view();

    const extra_module = try scene.definition.visual_definition.rigModuleId(
        "extra_arm_module",
    );
    var modules = [_]appearance.RigModule{undefined} **
        appearance.maximum_rig_modules;
    @memcpy(modules[0..base_appearance.rig_modules.len], base_appearance.rig_modules);
    modules[extra_module.index()].joint_count = 2;
    var bad_appearance = base_appearance;
    bad_appearance.rig_modules = modules[0..base_appearance.rig_modules.len];
    try std.testing.expectError(
        error.RigModuleJointMissing,
        component_graph.Definition.init(bad_appearance, base_anatomy),
    );

    @memcpy(modules[0..base_appearance.rig_modules.len], base_appearance.rig_modules);
    modules[extra_module.index()].socket_count = 0;
    bad_appearance.rig_modules = modules[0..base_appearance.rig_modules.len];
    try std.testing.expectError(
        error.RigModuleEndSocketMissing,
        component_graph.Definition.init(bad_appearance, base_anatomy),
    );

    var definitions = [_]anatomy.BodyPartDefinition{undefined} **
        anatomy.maximum_part_definitions;
    @memcpy(
        definitions[0..base_anatomy.part_definitions.len],
        base_anatomy.part_definitions,
    );
    definitions[0].projected_views.front = false;
    var bad_anatomy = base_anatomy;
    bad_anatomy.part_definitions =
        definitions[0..base_anatomy.part_definitions.len];
    try std.testing.expectError(
        error.UnsupportedFrontProjectionSource,
        component_graph.Definition.init(base_appearance, bad_anatomy),
    );

    var instances = [_]anatomy.BodyPartInstance{undefined} **
        anatomy.maximum_part_instances;
    @memcpy(
        instances[0..base_anatomy.part_instances.len],
        base_anatomy.part_instances,
    );
    const left_brow = try base_anatomy.partInstanceId("left_eyebrow");
    const head = try base_anatomy.partInstanceId("head");
    const face_socket = findSocket(base_anatomy, head, "face").?;
    instances[left_brow.index()].parent = .{ .body_part_socket = face_socket };
    bad_anatomy = base_anatomy;
    bad_anatomy.part_instances = instances[0..base_anatomy.part_instances.len];
    try std.testing.expectError(
        error.ParentSocketRoleMismatch,
        component_graph.Definition.init(base_appearance, bad_anatomy),
    );
}

const InvalidFixture = enum {
    unknown_parent_socket,
    invalid_child_tag,
    socket_capacity,
    component_multiplicity,
    children_forbidden,
    self_parent,
    hierarchy_cycle,
    inactive_parent,
    duplicate_component_id,
    duplicate_socket_id,
    unsupported_connection,
    invalid_intentional_gap,
    missing_soft_bridge,
};

fn expectInvalidFixture(fixture: InvalidFixture) !void {
    var base = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer base.deinit();

    const channels = [_]anatomy.MorphologyChannelInput{.{
        .stable_id = "width",
    }};
    const ranges = [_]anatomy.MorphologyRangeInput{.{
        .channel = "width",
        .low = 1,
        .high = 1,
    }};
    const presets = [_]anatomy.MorphologyPresetInput{.{
        .stable_id = "average",
        .ranges = &ranges,
    }};
    const profiles = [_]anatomy.PresentationProfileInput{.{
        .stable_id = "simple",
        .detail_tag = "technical",
    }};
    var sockets = [_]anatomy.ChildSocketInput{
        .{
            .stable_id = "child",
            .local_to_part = math.Transform2D.identity(),
            .accepted_child_tag = "accepted",
            .role = "typed_child",
        },
        .{
            .stable_id = "second",
            .local_to_part = math.Transform2D.identity(),
            .accepted_child_tag = "accepted",
            .role = "typed_child",
        },
    };
    var definitions = [_]anatomy.BodyPartDefinitionInput{
        .{
            .stable_id = "root_definition",
            .category_tag = "root",
            .type_tag = "root",
            .tags = &.{"root"},
            .child_sockets = sockets[0..1],
            .morphology_bindings = &.{},
        },
        .{
            .stable_id = "child_definition",
            .category_tag = "component",
            .type_tag = "child_component",
            .tags = &.{ "child", "accepted" },
            .child_sockets = &.{},
            .morphology_bindings = &.{},
            .component = .{ .allowed_parent_socket_role = "typed_child" },
        },
        .{
            .stable_id = "bridge_definition",
            .category_tag = "bridge",
            .type_tag = "bridge",
            .tags = &.{"bridge"},
            .child_sockets = &.{},
            .morphology_bindings = &.{},
            .component = .{ .binding_mode = .mesh },
        },
    };
    const empty_visuals = [_][]const u8{};
    const root_variants = [_]anatomy.VisualVariantInput{.{
        .presentation_profile = "simple",
        .visuals = &empty_visuals,
    }};
    const child_a_variants = root_variants;
    const child_b_variants = root_variants;
    const bridge_variants = root_variants;
    var instances = [_]anatomy.BodyPartInstanceInput{
        minimalInstance("root", "root_definition", .{ .attachment_point = "chest" }, &root_variants),
        minimalInstance("child_a", "child_definition", .{ .body_part_socket = .{
            .part_instance = "root",
            .socket = "child",
        } }, &child_a_variants),
        minimalInstance("child_b", "child_definition", .{ .body_part_socket = .{
            .part_instance = "root",
            .socket = "second",
        } }, &child_b_variants),
        minimalInstance("bridge", "bridge_definition", .{ .attachment_point = "chest" }, &bridge_variants),
    };
    var instance_count: usize = 2;
    const definition_count: usize = 3;
    var active_names = [_][]const u8{ "root", "child_a", "child_b", "bridge" };
    var active_count: usize = 2;
    var expected: anyerror = error.UnknownPartSocket;

    switch (fixture) {
        .unknown_parent_socket => instances[1].parent.body_part_socket.socket = "missing",
        .invalid_child_tag => {
            definitions[1].tags = &.{"rejected"};
            expected = error.ChildTagRejected;
        },
        .socket_capacity => {
            instance_count = 3;
            active_count = 3;
            instances[2].parent.body_part_socket.socket = "child";
            expected = error.SocketCapacityExceeded;
        },
        .component_multiplicity => {
            instance_count = 3;
            active_count = 3;
            definitions[1].validation.maximum_instances = 1;
            expected = error.PartMultiplicityExceeded;
        },
        .children_forbidden => {
            definitions[0].validation.allow_children = false;
            expected = error.BodyPartChildrenForbidden;
        },
        .self_parent => {
            instances[0].parent = .{ .body_part_socket = .{
                .part_instance = "root",
                .socket = "child",
            } };
            expected = error.BodyPartSelfParent;
        },
        .hierarchy_cycle => {
            instance_count = 2;
            definitions[0].tags = &.{ "root", "accepted" };
            instances[0].parent = .{ .body_part_socket = .{
                .part_instance = "child_a",
                .socket = "second",
            } };
            definitions[1].child_sockets = sockets[1..2];
            expected = error.BodyPartHierarchyCycle;
        },
        .inactive_parent => {
            active_names[0] = "child_a";
            active_count = 1;
            expected = error.ActiveBodyPartParentInactive;
        },
        .duplicate_component_id => {
            instance_count = 2;
            instances[1].stable_id = "root";
            expected = error.DuplicateStableId;
        },
        .duplicate_socket_id => {
            sockets[1].stable_id = "child";
            definitions[0].child_sockets = &sockets;
            expected = error.DuplicatePartSocketId;
        },
        .unsupported_connection => {
            definitions[1].component.supported_connections.intentional_gap = false;
            instances[1].connection = .{ .intentional_gap = .{
                .minimum_gap = 0,
                .maximum_gap = 0,
            } };
            expected = error.UnsupportedConnectionMode;
        },
        .invalid_intentional_gap => {
            definitions[1].component.supported_connections.intentional_gap = true;
            sockets[0].supported_connections.intentional_gap = true;
            instances[1].local_to_parent.translation.x = 0.05;
            instances[1].connection = .{ .intentional_gap = .{
                .minimum_gap = 0.10,
                .maximum_gap = 0.20,
            } };
            expected = error.InvalidIntentionalGapBounds;
        },
        .missing_soft_bridge => {
            definitions[1].component.supported_connections.soft_bridge = true;
            sockets[0].supported_connections.soft_bridge = true;
            instances[1].connection = .{ .soft_bridge = .{
                .bridge_component = "missing_bridge",
            } };
            expected = error.SoftBridgeMissing;
        },
    }

    const body_presets = [_]anatomy.BodyPresetInput{.{
        .stable_id = "body",
        .active_parts = active_names[0..active_count],
        .faces = &.{},
        .hair = null,
        .morphology_preset = "average",
        .global_build = 50,
        .presentation_profile = "simple",
    }};
    try std.testing.expectError(expected, anatomy.Definition.init(
        std.testing.allocator,
        base.visual_definition.view(),
        .{
            .morphology_channels = &channels,
            .morphology_presets = &presets,
            .presentation_profiles = &profiles,
            .part_definitions = definitions[0..definition_count],
            .part_instances = instances[0..instance_count],
            .faces = &.{},
            .hair_definitions = &.{},
            .body_presets = &body_presets,
            .default_body_preset = "body",
        },
        null,
    ));
}

fn minimalInstance(
    stable_id: []const u8,
    definition: []const u8,
    parent: anatomy.BodyPartParentInput,
    variants: []const anatomy.VisualVariantInput,
) anatomy.BodyPartInstanceInput {
    return .{
        .stable_id = stable_id,
        .definition = definition,
        .parent = parent,
        .local_to_parent = math.Transform2D.identity(),
        .body_region = "torso",
        .visual_group = "body",
        .base_render_layer = 0,
        .presentation_variants = variants,
    };
}

fn findSocket(
    definition: anatomy.DefinitionView,
    owner: anatomy.BodyPartInstanceId,
    name: []const u8,
) ?anatomy.PartSocketId {
    const instance = definition.part_instances[owner.index()];
    for (definition.instance_sockets[instance.instance_socket_start .. instance.instance_socket_start + instance.instance_socket_count]) |socket| {
        if (std.mem.eql(u8, socket.stable_id.slice(), name)) return socket.id;
    }
    return null;
}
