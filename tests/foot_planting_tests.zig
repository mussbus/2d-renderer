const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const collision_world = @import("collision_world");
const events = @import("events");
const skeleton = @import("skeleton");
const humanoid = @import("humanoid");
const leg_ik = @import("leg_ik");
const foot_planting = @import("foot_planting");
const authored = @import("authored_clips");
const character = @import("character");
const character_controller = @import("character_controller");
const input = @import("input");
const fixed_step = @import("fixed_step");
const interaction = @import("interaction");
const interaction_system = @import("interaction_system");
const handshake = @import("handshake");
const foot_planting_demo = @import("foot_planting_demo");

const tolerance: f32 = 0.0002;

fn bounds(min_x: f32, min_y: f32, max_x: f32, max_y: f32) collider.Aabb {
    return .{ .minimum = .{ .x = min_x, .y = min_y }, .maximum = .{ .x = max_x, .y = max_y } };
}

fn staticInput(id: collider.ColliderId, value: collider.Aabb, eligible: bool) collider.StaticColliderInput {
    return .{ .id = id, .bounds = value, .ground_query_eligible = eligible };
}

test "ground query hits floor platform exact maximum and exact surface deterministically" {
    const inputs = [_]collider.StaticColliderInput{
        staticInput(8, bounds(-5, -1, 5, 0), true),
        staticInput(4, bounds(1, 0, 3, 1), true),
    };
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &inputs, null);
    defer world.deinit();

    const floor = (try world.queryGroundDown(.{ .x = 0, .y = 0.5 }, 0.5, 0.00001)).?;
    try std.testing.expectEqual(@as(collider.ColliderId, 8), floor.collider_id);
    try std.testing.expectApproxEqAbs(@as(f32, 0), floor.ground_height, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), floor.query_distance, 0);
    try std.testing.expect(floor.normal.approxEqAbs(.{ .x = 0, .y = 1 }, 0));

    const platform = (try world.queryGroundDown(.{ .x = 2, .y = 1.2 }, 0.2, 0.00001)).?;
    try std.testing.expectEqual(@as(collider.ColliderId, 4), platform.collider_id);
    try std.testing.expect(platform.position.approxEqAbs(.{ .x = 2, .y = 1 }, 0));

    const on_surface = (try world.queryGroundDown(.{ .x = 2, .y = 1 }, 0, 0)).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0), on_surface.query_distance, 0);
}

test "ground query rejects no hit beyond range below surface and negative or non finite input" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-1, -1, 1, 0), true)};
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &inputs, null);
    defer world.deinit();

    try std.testing.expect((try world.queryGroundDown(.{ .x = 2, .y = 0.2 }, 1, 0.00001)) == null);
    try std.testing.expect((try world.queryGroundDown(.{ .x = 0, .y = 0.50002 }, 0.5, 0.00001)) == null);
    try std.testing.expect((try world.queryGroundDown(.{ .x = 0, .y = -0.1 }, 1, 0.00001)) == null);
    try std.testing.expectError(error.NegativeGroundQueryDistance, world.queryGroundDown(.{ .x = 0, .y = 1 }, -0.1, 0));
    try std.testing.expectError(error.NonFiniteGroundQuery, world.queryGroundDown(.{ .x = std.math.nan(f32), .y = 1 }, 1, 0));
    try std.testing.expectError(error.NonFiniteGroundQuery, world.queryGroundDown(.{ .x = 0, .y = 1 }, std.math.inf(f32), 0));
}

test "ground query accepts slight height and uses stable collider id tie break" {
    const inputs = [_]collider.StaticColliderInput{
        staticInput(12, bounds(-2, -1, 2, 0), true),
        staticInput(3, bounds(-1, -2, 1, 0), true),
    };
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &inputs, null);
    defer world.deinit();
    const hit = (try world.queryGroundDown(.{ .x = 0, .y = 0.00002 }, 0.1, 0.00001)).?;
    try std.testing.expectEqual(@as(collider.ColliderId, 3), hit.collider_id);
    try std.testing.expectApproxEqAbs(@as(f32, 0.00002), hit.query_distance, 0.0000001);
}

test "ground query never treats side underside or ineligible top as supporting ground" {
    const inputs = [_]collider.StaticColliderInput{
        staticInput(1, bounds(0, 0, 0.2, 3), false),
        staticInput(2, bounds(-1, 2, 1, 2.2), false),
        staticInput(3, bounds(-2, -1, 2, 0), true),
    };
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &inputs, null);
    defer world.deinit();
    try std.testing.expect((try world.queryGroundDown(.{ .x = 0.1, .y = 2.9 }, 0.2, 0)) == null);
    try std.testing.expect((try world.queryGroundDown(.{ .x = 0, .y = 1.9 }, 0.2, 0)) == null);
    try std.testing.expect((try world.queryGroundDown(.{ .x = 2.001, .y = 0.2 }, 1, 0.00001)) == null);
    try std.testing.expect((try world.queryGroundDown(.{ .x = 2, .y = 0.2 }, 1, 0.00001)) != null);
}

test "demo collision world marks only floor and raised platform tops query eligible" {
    var world = try collision_world.CollisionWorld.initDemo(std.testing.allocator, null);
    defer world.deinit();
    try std.testing.expect((try world.queryGroundDown(.{ .x = 0, .y = 2 }, 3, 0.00001)).?.collider_id == @intFromEnum(collision_world.DemoColliderId.raised_platform_1));
    try std.testing.expect((try world.queryGroundDown(.{ .x = 3.65, .y = 6.2 }, 0.3, 0.00001)) == null);
    try std.testing.expect((try world.queryGroundDown(.{ .x = -2.2, .y = 3 }, 0.5, 0.00001)) == null);
}

test "left and right leg bindings use stable anatomical indices immutable rest lengths and forward bend" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    const left = try leg_ik.Binding.initLeft(&definition.skeleton_definition);
    const right = try leg_ik.Binding.initRight(&definition.skeleton_definition);
    try std.testing.expectEqual(leg_ik.AnatomicalFoot.left, left.foot);
    try std.testing.expectEqual(leg_ik.AnatomicalFoot.right, right.foot);
    try std.testing.expectEqual(try definition.skeleton_definition.boneIndex(.left_thigh), left.hip_bone);
    try std.testing.expectEqual(try definition.skeleton_definition.boneIndex(.right_thigh), right.hip_bone);
    try std.testing.expectEqual(try definition.skeleton_definition.socketIndex(.left_foot), left.sole_socket);
    try std.testing.expectEqual(try definition.skeleton_definition.socketIndex(.right_foot), right.sole_socket);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), left.upper_length, 0.000001);
    try std.testing.expectApproxEqAbs(@sqrt(@as(f32, 0.85 * 0.85 + 0.35 * 0.35)), left.lower_length, 0.000001);
    try std.testing.expectApproxEqAbs(left.upper_length, right.upper_length, 0);
    try std.testing.expectApproxEqAbs(left.lower_length, right.lower_length, 0);
    try std.testing.expectEqual(leg_ik.Bend.positive, left.character_local_bend);
    try std.testing.expectEqual(leg_ik.Bend.positive, right.character_local_bend);
}

test "leg binding rejects invalid hip knee ankle sole and anatomical mismatch" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    const valid = leg_ik.BindingInput{
        .hip_bone = try definition.skeleton_definition.boneIndex(.left_thigh),
        .knee_bone = try definition.skeleton_definition.boneIndex(.left_shin),
        .ankle_bone = try definition.skeleton_definition.boneIndex(.left_foot),
        .sole_socket = try definition.skeleton_definition.socketIndex(.left_foot),
        .character_local_bend = .positive,
    };
    var invalid = valid;
    invalid.hip_bone = 999;
    try std.testing.expectError(error.InvalidBoneIndex, leg_ik.Binding.init(&definition.skeleton_definition, .left, invalid));
    invalid = valid;
    invalid.knee_bone = 999;
    try std.testing.expectError(error.InvalidBoneIndex, leg_ik.Binding.init(&definition.skeleton_definition, .left, invalid));
    invalid = valid;
    invalid.ankle_bone = 999;
    try std.testing.expectError(error.InvalidBoneIndex, leg_ik.Binding.init(&definition.skeleton_definition, .left, invalid));
    invalid = valid;
    invalid.sole_socket = 999;
    try std.testing.expectError(error.InvalidSocketIndex, leg_ik.Binding.init(&definition.skeleton_definition, .left, invalid));
    invalid = valid;
    invalid.sole_socket = try definition.skeleton_definition.socketIndex(.right_foot);
    try std.testing.expectError(error.InvalidSoleSocketParent, leg_ik.Binding.init(&definition.skeleton_definition, .left, invalid));
}

const PlantFixture = struct {
    definition: humanoid.HumanoidDefinition,
    world: collision_world.CollisionWorld,
    visual: humanoid.HumanoidCharacter,
    left: leg_ik.Binding,
    right: leg_ik.Binding,
    state: foot_planting.State = .{},
    transform: math.Transform2D,

    fn init(inputs: []const collider.StaticColliderInput, position: math.Vec2, facing_left: bool) !PlantFixture {
        var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
        errdefer definition.deinit();
        var world = try collision_world.CollisionWorld.init(std.testing.allocator, inputs, null);
        errdefer world.deinit();
        var visual = try humanoid.HumanoidCharacter.init(std.testing.allocator, &definition, null);
        errdefer visual.deinit();
        const transform = math.Transform2D.init(position, 0, .{ .x = if (facing_left) -1 else 1, .y = 1 });
        visual.character_to_world = transform;
        try visual.local_and_world_pose.evaluateWorld(&definition.skeleton_definition, transform);
        return .{
            .definition = definition,
            .world = world,
            .visual = visual,
            .left = try leg_ik.Binding.initLeft(&definition.skeleton_definition),
            .right = try leg_ik.Binding.initRight(&definition.skeleton_definition),
            .transform = transform,
        };
    }

    fn deinit(fixture: *PlantFixture) void {
        fixture.visual.deinit();
        fixture.world.deinit();
        fixture.definition.deinit();
        fixture.* = undefined;
    }

    fn setPosition(fixture: *PlantFixture, position: math.Vec2) !void {
        try fixture.restore();
        fixture.transform.translation = position;
        fixture.visual.character_to_world = fixture.transform;
        try fixture.visual.local_and_world_pose.evaluateWorld(&fixture.definition.skeleton_definition, fixture.transform);
    }

    fn restore(fixture: *PlantFixture) !void {
        try foot_planting.restoreApplied(
            &fixture.state,
            &fixture.visual.local_and_world_pose,
            &fixture.definition.skeleton_definition,
            fixture.transform,
            fixture.left,
            fixture.right,
        );
    }

    fn tick(
        fixture: *PlantFixture,
        simulation_tick: u64,
        grounded: bool,
        walking: bool,
        phase: f32,
        emitted: []const events.EmittedEvent,
    ) !void {
        try fixture.restore();
        try foot_planting.updateAndApply(&fixture.state, .{
            .world = &fixture.world,
            .definition = &fixture.definition.skeleton_definition,
            .mutable_pose = &fixture.visual.local_and_world_pose,
            .character_to_world = fixture.transform,
            .left_binding = fixture.left,
            .right_binding = fixture.right,
            .facing_left = fixture.transform.scale.x < 0,
            .physically_grounded = grounded,
            .walking_state = walking,
            .walk_phase = phase,
            .walk_weight = if (walking) 1 else 0,
            .emitted_events = emitted,
            .simulation_tick = simulation_tick,
        });
    }
};

fn contact(foot: leg_ik.AnatomicalFoot, loop_index: u64) events.EmittedEvent {
    return .{
        .clip_id = 1,
        .loop_index = loop_index,
        .record = .{
            .id = if (foot == .left) 1 else 2,
            .timestamp = if (foot == .left) 0 else 0.5,
            .event_type = if (foot == .left) .left_foot_contact else .right_foot_contact,
            .layer_change = .{ .attachment_semantic = 0, .requested_layer = 0, .restoration = .retain },
        },
    };
}

test "leg IK weight zero preserves authored pose and weight one reaches each reachable sole target" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var fixture = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer fixture.deinit();
    const definition = &fixture.definition.skeleton_definition;
    const left_hip_before = fixture.visual.local_and_world_pose.local_transforms[fixture.left.hip_bone];
    const left_knee_before = fixture.visual.local_and_world_pose.local_transforms[fixture.left.knee_bone];
    const sole = try fixture.visual.local_and_world_pose.socketPosition(definition, .left_foot);
    const zero = try leg_ik.apply(fixture.left, &fixture.visual.local_and_world_pose, definition, fixture.transform, sole.add(.{ .x = 0.1, .y = 0 }), .positive, 0);
    try std.testing.expectApproxEqAbs(left_hip_before.rotation_radians, fixture.visual.local_and_world_pose.local_transforms[fixture.left.hip_bone].rotation_radians, 0);
    try std.testing.expectApproxEqAbs(left_knee_before.rotation_radians, fixture.visual.local_and_world_pose.local_transforms[fixture.left.knee_bone].rotation_radians, 0);
    try std.testing.expect(zero.metrics.post_ik_sole_position.approxEqAbs(sole, tolerance));
    try leg_ik.restore(fixture.left, &fixture.visual.local_and_world_pose, definition, fixture.transform, zero.pre_hip_local, zero.pre_knee_local);
    const full = try leg_ik.apply(fixture.left, &fixture.visual.local_and_world_pose, definition, fixture.transform, sole.add(.{ .x = 0.1, .y = 0 }), .positive, 1);
    try std.testing.expectEqual(leg_ik.Reachability.reachable, full.metrics.reachability);
    try std.testing.expect(full.metrics.target_error <= tolerance);
    try std.testing.expectApproxEqAbs(fixture.left.upper_length, full.metrics.solved_upper_length, tolerance);
    try std.testing.expectApproxEqAbs(fixture.left.lower_length, full.metrics.solved_lower_length, tolerance);
}

test "mirrored leg IK preserves anatomical feet and bends both knees character forward" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var right_facing = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer right_facing.deinit();
    var left_facing = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, true);
    defer left_facing.deinit();
    const target_right = try right_facing.visual.local_and_world_pose.socketPosition(&right_facing.definition.skeleton_definition, .left_foot);
    const target_left = try left_facing.visual.local_and_world_pose.socketPosition(&left_facing.definition.skeleton_definition, .left_foot);
    const solved_right = try leg_ik.apply(right_facing.left, &right_facing.visual.local_and_world_pose, &right_facing.definition.skeleton_definition, right_facing.transform, target_right, .positive, 1);
    const solved_left = try leg_ik.apply(left_facing.left, &left_facing.visual.local_and_world_pose, &left_facing.definition.skeleton_definition, left_facing.transform, target_left, .negative, 1);
    try std.testing.expect(solved_right.metrics.knee_position.x > solved_right.metrics.hip_position.x);
    try std.testing.expect(solved_left.metrics.knee_position.x < solved_left.metrics.hip_position.x);
    try std.testing.expect(solved_right.metrics.target_error <= tolerance);
    try std.testing.expect(solved_left.metrics.target_error <= tolerance);
    try std.testing.expectEqual(leg_ik.AnatomicalFoot.left, right_facing.left.foot);
    try std.testing.expectEqual(leg_ik.AnatomicalFoot.left, left_facing.left.foot);
}

test "left then right and right then left leg solves are equivalent from frozen disjoint inputs" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var first = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer first.deinit();
    var second = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer second.deinit();
    const left_target = (try first.visual.local_and_world_pose.socketPosition(&first.definition.skeleton_definition, .left_foot)).add(.{ .x = 0.08, .y = 0.02 });
    const right_target = (try first.visual.local_and_world_pose.socketPosition(&first.definition.skeleton_definition, .right_foot)).add(.{ .x = -0.06, .y = 0.01 });
    _ = try leg_ik.apply(first.left, &first.visual.local_and_world_pose, &first.definition.skeleton_definition, first.transform, left_target, .positive, 1);
    _ = try leg_ik.apply(first.right, &first.visual.local_and_world_pose, &first.definition.skeleton_definition, first.transform, right_target, .positive, 1);
    _ = try leg_ik.apply(second.right, &second.visual.local_and_world_pose, &second.definition.skeleton_definition, second.transform, right_target, .positive, 1);
    _ = try leg_ik.apply(second.left, &second.visual.local_and_world_pose, &second.definition.skeleton_definition, second.transform, left_target, .positive, 1);
    const first_left = try first.visual.local_and_world_pose.socketPosition(&first.definition.skeleton_definition, .left_foot);
    const first_right = try first.visual.local_and_world_pose.socketPosition(&first.definition.skeleton_definition, .right_foot);
    const second_left = try second.visual.local_and_world_pose.socketPosition(&second.definition.skeleton_definition, .left_foot);
    const second_right = try second.visual.local_and_world_pose.socketPosition(&second.definition.skeleton_definition, .right_foot);
    try std.testing.expect(first_left.approxEqAbs(second_left, tolerance));
    try std.testing.expect(first_right.approxEqAbs(second_right, tolerance));
}

test "contact event and valid ground acquires gradually while transition start cannot snap" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var fixture = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer fixture.deinit();
    const emitted = [_]events.EmittedEvent{contact(.left, 0)};
    try fixture.tick(1, true, true, 0, &emitted);
    try std.testing.expectEqual(foot_planting.PlantState.plant_candidate, fixture.state.left.plant_state);
    try std.testing.expect(fixture.state.left.hasLock());
    try std.testing.expect(fixture.state.left.plant_weight > 0 and fixture.state.left.plant_weight < 0.05);
    try std.testing.expectEqual(@as(collider.ColliderId, 1), fixture.state.left.locked_collider_id.?);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fixture.state.left.locked_target.?.y, 0);
}

test "contact without ground beyond range or while airborne never creates a plant" {
    const narrow = [_]collider.StaticColliderInput{staticInput(1, bounds(-1, -1, 1, 0), true)};
    var no_ground = try PlantFixture.init(&narrow, .{ .x = 3, .y = 1.05 }, false);
    defer no_ground.deinit();
    const emitted = [_]events.EmittedEvent{contact(.left, 0)};
    try no_ground.tick(1, true, true, 0, &emitted);
    try std.testing.expectEqual(foot_planting.PlantState.swing, no_ground.state.left.plant_state);
    try std.testing.expectEqual(@as(u32, 1), no_ground.state.left.metrics.rejected_no_ground);

    const floor = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var too_high = try PlantFixture.init(&floor, .{ .x = 0, .y = 3 }, false);
    defer too_high.deinit();
    try too_high.tick(1, true, true, 0, &emitted);
    try std.testing.expect(!too_high.state.left.hasLock());
    try std.testing.expectEqual(@as(u32, 1), too_high.state.left.metrics.rejected_no_ground);

    var airborne = try PlantFixture.init(&floor, .{ .x = 0, .y = 1.05 }, false);
    defer airborne.deinit();
    try airborne.tick(1, false, true, 0, &emitted);
    try std.testing.expect(!airborne.state.left.hasLock());
    try std.testing.expectEqual(@as(u32, 1), airborne.state.left.metrics.rejected_airborne);
}

test "planted target stays world fixed repeated contact does not drift and slip is reduced" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var fixture = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer fixture.deinit();
    const emitted = [_]events.EmittedEvent{contact(.left, 0)};
    try fixture.tick(1, true, true, 0, &emitted);
    var tick: u64 = 2;
    while (tick <= 30) : (tick += 1) try fixture.tick(tick, true, true, 0.2, &.{});
    try std.testing.expectEqual(foot_planting.PlantState.planted, fixture.state.left.plant_state);
    const locked = fixture.state.left.locked_target.?;
    try fixture.setPosition(.{ .x = 0.10, .y = 1.05 });
    const authored_sole = try fixture.visual.local_and_world_pose.socketPosition(&fixture.definition.skeleton_definition, .left_foot);
    const baseline_slip = authored_sole.sub(locked).length();
    const repeated = [_]events.EmittedEvent{contact(.left, 1)};
    try fixture.tick(31, true, true, 0.25, &repeated);
    try std.testing.expect(fixture.state.left.locked_target.?.approxEqAbs(locked, 0));
    try std.testing.expectEqual(@as(?u64, 31), fixture.state.left.metrics.last_semantic_contact_tick);
    const lifecycle = fixture.state.left.metrics.latest_acquired_lifecycle;
    try std.testing.expectEqual(@as(?u64, 1), lifecycle.semantic_contact_tick);
    try std.testing.expectEqual(@as(?u64, 1), lifecycle.candidate_acquisition_tick);
    try std.testing.expect(lifecycle.full_plant_tick != null);
    try std.testing.expect(lifecycle.isChronological());
    try std.testing.expect(fixture.state.left.world_space_slip < baseline_slip * 0.01);
    try std.testing.expect(fixture.state.left.world_space_slip <= tolerance);
    try std.testing.expect(fixture.state.left.penetration <= tolerance);
    try std.testing.expect(fixture.state.left.hover <= tolerance);
}

test "stance exit blends release while jump and reset clear stale locks immediately" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var fixture = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer fixture.deinit();
    const emitted = [_]events.EmittedEvent{contact(.left, 0)};
    try fixture.tick(1, true, true, 0, &emitted);
    var tick: u64 = 2;
    while (tick <= 30) : (tick += 1) try fixture.tick(tick, true, true, 0.2, &.{});
    try fixture.tick(31, true, true, 0.7, &.{});
    try std.testing.expectEqual(foot_planting.PlantState.releasing, fixture.state.left.plant_state);
    try std.testing.expect(fixture.state.left.plant_weight < 1 and fixture.state.left.hasLock());
    try fixture.tick(32, false, false, 0.7, &.{});
    try std.testing.expectEqual(foot_planting.PlantState.swing, fixture.state.left.plant_state);
    try std.testing.expect(!fixture.state.left.hasLock() and fixture.state.left.plant_weight == 0);
    const lifecycle = fixture.state.left.metrics.latest_acquired_lifecycle;
    try std.testing.expect(lifecycle.semantic_contact_tick != null);
    try std.testing.expect(lifecycle.candidate_acquisition_tick != null);
    try std.testing.expect(lifecycle.full_plant_tick != null);
    try std.testing.expectEqual(@as(?u64, 31), lifecycle.release_start_tick);
    try std.testing.expectEqual(@as(?u64, 32), lifecycle.full_release_tick);
    try std.testing.expect(lifecycle.isChronological());
    fixture.state.left.locked_target = .{ .x = 1, .y = 0 };
    fixture.state.left.locked_collider_id = 1;
    fixture.state.left.plant_state = .planted;
    fixture.state.left.plant_weight = 1;
    fixture.state.reset();
    try std.testing.expect(!fixture.state.left.hasLock() and !fixture.state.right.hasLock());
}

test "airborne transition clears an anatomical right foot plant and requires a future fresh contact" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var fixture = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer fixture.deinit();
    const emitted = [_]events.EmittedEvent{contact(.right, 0)};
    try fixture.tick(1, true, true, 0.5, &emitted);
    var tick: u64 = 2;
    while (tick <= 30) : (tick += 1) try fixture.tick(tick, true, true, 0.7, &.{});
    try std.testing.expectEqual(foot_planting.PlantState.planted, fixture.state.right.plant_state);
    const old_target = fixture.state.right.locked_target.?;
    try fixture.tick(31, false, false, 0.7, &.{});
    try std.testing.expect(!fixture.state.right.hasLock() and fixture.state.right.plant_weight == 0);
    try fixture.tick(32, true, true, 0.7, &.{});
    try std.testing.expect(!fixture.state.right.hasLock());
    const fresh = [_]events.EmittedEvent{contact(.right, 1)};
    try fixture.tick(33, true, true, 0.5, &fresh);
    try std.testing.expect(fixture.state.right.hasLock());
    try std.testing.expect(fixture.state.right.locked_target.?.approxEqAbs(old_target, tolerance));
}

test "left right and character plant ownership are isolated" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-10, -1, 10, 0), true)};
    var a = try PlantFixture.init(&inputs, .{ .x = -1, .y = 1.05 }, false);
    defer a.deinit();
    var b = try PlantFixture.init(&inputs, .{ .x = 1, .y = 1.05 }, true);
    defer b.deinit();
    const left_event = [_]events.EmittedEvent{contact(.left, 0)};
    const right_event = [_]events.EmittedEvent{contact(.right, 0)};
    try a.tick(1, true, true, 0, &left_event);
    try b.tick(1, true, true, 0.5, &right_event);
    try std.testing.expect(a.state.left.hasLock() and !a.state.right.hasLock());
    try std.testing.expect(!b.state.left.hasLock() and b.state.right.hasLock());
    const b_target = b.state.right.locked_target.?;
    a.state.reset();
    try std.testing.expect(b.state.right.locked_target.?.approxEqAbs(b_target, 0));
}

test "floor platform and edge samples acquire only real vertical support at fresh heights" {
    const inputs = [_]collider.StaticColliderInput{
        staticInput(1, bounds(-5, -1, 5, 0), true),
        staticInput(4, bounds(1, 0.9, 2, 1.15), true),
    };
    var fixture = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer fixture.deinit();
    const left_event = [_]events.EmittedEvent{contact(.left, 0)};
    try fixture.tick(1, true, true, 0, &left_event);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fixture.state.left.locked_target.?.y, 0);
    try fixture.tick(2, false, false, 0, &.{});
    fixture.state.reset();
    try fixture.setPosition(.{ .x = 1.5, .y = 2.20 });
    const platform_event = [_]events.EmittedEvent{contact(.left, 1)};
    try fixture.tick(3, true, true, 0, &platform_event);
    try std.testing.expectEqual(@as(collider.ColliderId, 4), fixture.state.left.locked_collider_id.?);
    try std.testing.expectApproxEqAbs(@as(f32, 1.15), fixture.state.left.locked_target.?.y, 0.000001);
    fixture.state.reset();
    try fixture.setPosition(.{ .x = 2.20, .y = 2.20 });
    const edge_event = [_]events.EmittedEvent{contact(.left, 2)};
    try fixture.tick(4, true, true, 0, &edge_event);
    try std.testing.expect(!fixture.state.left.hasLock());
}

test "unreachable and dual conflicting locks release without stretch non finite pose or root correction" {
    const inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-20, -1, 20, 0), true)};
    var fixture = try PlantFixture.init(&inputs, .{ .x = 0, .y = 1.05 }, false);
    defer fixture.deinit();
    fixture.state.left = .{ .plant_state = .planted, .plant_weight = 1, .locked_target = .{ .x = -3, .y = 0 }, .locked_collider_id = 1 };
    fixture.state.right = .{ .plant_state = .planted, .plant_weight = 1, .locked_target = .{ .x = 3, .y = 0 }, .locked_collider_id = 1 };
    const root_before = fixture.transform.translation;
    try fixture.tick(1, true, true, 0.52, &.{});
    try std.testing.expectEqual(foot_planting.PlantState.releasing, fixture.state.left.plant_state);
    try std.testing.expectEqual(foot_planting.PlantState.releasing, fixture.state.right.plant_state);
    try std.testing.expectEqual(leg_ik.Reachability.clamped_far, fixture.state.left.reachability.?);
    try std.testing.expectEqual(leg_ik.Reachability.clamped_far, fixture.state.right.reachability.?);
    try std.testing.expect(fixture.state.left.post_ik_sole.isFinite() and fixture.state.right.post_ik_sole.isFinite());
    try std.testing.expect(fixture.transform.translation.approxEqAbs(root_before, 0));
}

fn visualInput(instance: *const character.CharacterInstance, physics: character_controller.StepResult) character.VisualTickInput {
    const controller = instance.controller.?;
    return .{
        .horizontal_velocity = controller.state.velocity.x,
        .physically_grounded = controller.state.grounded,
        .landing_event = if (physics.landed) .{
            .simulation_tick = physics.simulation_tick,
            .impact_speed = physics.landing_impact_speed,
        } else null,
    };
}

fn controllerIntent(tick: u64, jump_tick: ?u64) input.CharacterIntent {
    const jump_now = jump_tick != null and tick == jump_tick.?;
    return .{
        .move_axis = if (tick < 700) 0.55 else 0,
        .jump_pressed = jump_now,
        .jump_held = jump_tick != null and tick >= jump_tick.? and tick < jump_tick.? + 10,
        .jump_released = jump_tick != null and tick == jump_tick.? + 10,
        .interact_pressed = false,
    };
}

test "foot planting preserves controller root velocity collision timing and animator clocks through jump and landing" {
    const world_inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-100, -1, 100, 0), true)};
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &world_inputs, null);
    defer world.deinit();
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var enabled = try character.CharacterInstance.initControlled(
        std.testing.allocator,
        try character.entityIdFromRaw(1),
        &definition,
        &animations,
        &world,
        .{},
        .{ .x = -3, .y = 1.05 },
        .right,
        0,
        null,
    );
    defer enabled.deinit();
    var disabled = try character.CharacterInstance.initControlled(
        std.testing.allocator,
        try character.entityIdFromRaw(2),
        &definition,
        &animations,
        &world,
        .{},
        .{ .x = -3, .y = 1.05 },
        .right,
        1,
        null,
    );
    defer disabled.deinit();
    disabled.foot_plants.setEnabled(false);

    var next_jump: ?u64 = null;
    var jump_tick: ?u64 = null;
    var landing_enabled: u32 = 0;
    var landing_disabled: u32 = 0;
    var false_airborne_locks: u32 = 0;
    var tick: u64 = 0;
    while (tick < 1000) : (tick += 1) {
        if (next_jump == null and tick > 180 and (enabled.foot_plants.left.plant_state == .planted or enabled.foot_plants.right.plant_state == .planted)) {
            next_jump = tick;
            jump_tick = tick;
        }
        const intent_value = controllerIntent(tick, next_jump);
        const enabled_result = try enabled.stepController(&world, intent_value);
        const disabled_result = try disabled.stepController(&world, intent_value);
        try enabled.selectControllerAnimation(enabled_result);
        try disabled.selectControllerAnimation(disabled_result);
        try enabled.advanceVisualTickWithFootPlanting(&world, visualInput(&enabled, enabled_result));
        try disabled.advanceVisualTickWithFootPlanting(&world, visualInput(&disabled, disabled_result));
        if (enabled_result.landed) landing_enabled += 1;
        if (disabled_result.landed) landing_disabled += 1;
        if (!enabled.controller.?.state.grounded and (enabled.foot_plants.left.hasLock() or enabled.foot_plants.right.hasLock())) false_airborne_locks += 1;

        try std.testing.expect(enabled.controller.?.state.position.approxEqAbs(disabled.controller.?.state.position, 0));
        try std.testing.expect(enabled.controller.?.state.velocity.approxEqAbs(disabled.controller.?.state.velocity, 0));
        try std.testing.expectEqual(enabled.controller.?.state.grounded, disabled.controller.?.state.grounded);
        try std.testing.expectEqual(enabled.controller.?.state.supporting_collider, disabled.controller.?.state.supporting_collider);
        try std.testing.expectEqual(enabled.animationState(), disabled.animationState());
        try std.testing.expectApproxEqAbs(enabled.animationTime(), disabled.animationTime(), 0);
        try std.testing.expectEqual(enabled.animator.emittedEvents().len, disabled.animator.emittedEvents().len);
        for (enabled.animator.emittedEvents(), disabled.animator.emittedEvents()) |left_event, right_event| {
            try std.testing.expectEqual(left_event.record.event_type, right_event.record.event_type);
            try std.testing.expectEqual(left_event.loop_index, right_event.loop_index);
        }
    }
    try std.testing.expect(jump_tick != null);
    try std.testing.expectEqual(@as(u32, 1), landing_enabled);
    try std.testing.expectEqual(landing_enabled, landing_disabled);
    try std.testing.expectEqual(@as(u32, 0), false_airborne_locks);
    try std.testing.expect(enabled.foot_plants.left.metrics.first_contact_tick != null);
    try std.testing.expect(enabled.foot_plants.right.metrics.first_contact_tick != null);
    try std.testing.expect(enabled.foot_plants.left.metrics.first_release_tick != null);
    try std.testing.expect(enabled.foot_plants.right.metrics.first_release_tick != null);
    try std.testing.expect(enabled.foot_plants.left.metrics.maximum_world_space_slip <= tolerance);
    try std.testing.expect(enabled.foot_plants.right.metrics.maximum_world_space_slip <= tolerance);
}

test "controlled reset clears both character local foot locks without affecting another character" {
    const world_inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-20, -1, 20, 0), true)};
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &world_inputs, null);
    defer world.deinit();
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var a = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(1), &definition, &animations, &world, .{}, .{ .x = -1, .y = 1.05 }, .right, 0, null);
    defer a.deinit();
    var b = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(2), &definition, &animations, &world, .{}, .{ .x = 1, .y = 1.05 }, .left, 1, null);
    defer b.deinit();
    a.foot_plants.left = .{ .plant_state = .planted, .plant_weight = 1, .locked_target = .{ .x = -1, .y = 0 }, .locked_collider_id = 1 };
    a.foot_plants.right = .{ .plant_state = .planted, .plant_weight = 1, .locked_target = .{ .x = -0.8, .y = 0 }, .locked_collider_id = 1 };
    b.foot_plants.left = .{ .plant_state = .planted, .plant_weight = 1, .locked_target = .{ .x = 0.8, .y = 0 }, .locked_collider_id = 1 };
    const b_target = b.foot_plants.left.locked_target.?;
    try a.resetControlled(&world);
    try std.testing.expect(!a.foot_plants.left.hasLock() and !a.foot_plants.right.hasLock());
    try std.testing.expect(b.foot_plants.left.locked_target.?.approxEqAbs(b_target, 0));
}

const DeterminismEvidence = struct {
    left_contact: ?u64,
    left_plant: ?u64,
    left_release: ?u64,
    right_contact: ?u64,
    right_plant: ?u64,
    right_release: ?u64,
    left_target: ?math.Vec2,
    right_target: ?math.Vec2,
    left_state: foot_planting.PlantState,
    right_state: foot_planting.PlantState,
    left_weight: f32,
    right_weight: f32,
    maximum_slip: f32,
};

fn runPlantSchedule(groups: []const u8) !DeterminismEvidence {
    const world_inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-100, -1, 100, 0), true)};
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &world_inputs, null);
    defer world.deinit();
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var instance = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(1), &definition, &animations, &world, .{}, .{ .x = -2, .y = 1.05 }, .right, 0, null);
    defer instance.deinit();
    var clock = try fixed_step.Clock.init(.{});
    var tick: u64 = 0;
    var group_index: usize = 0;
    while (tick < 480) {
        const requested = groups[group_index % groups.len];
        group_index += 1;
        const remaining = 480 - tick;
        const count: u8 = @intCast(@min(@as(u64, requested), remaining));
        const frame = try clock.beginFrame(@as(f64, @floatFromInt(count)) * fixed_step.fixed_dt_seconds);
        try std.testing.expectEqual(count, frame.substeps);
        for (0..frame.substeps) |_| {
            const intent_value = controllerIntent(tick, null);
            const physics = try instance.stepController(&world, intent_value);
            try instance.selectControllerAnimation(physics);
            try instance.advanceVisualTickWithFootPlanting(&world, visualInput(&instance, physics));
            tick += 1;
        }
    }
    return .{
        .left_contact = instance.foot_plants.left.metrics.first_contact_tick,
        .left_plant = instance.foot_plants.left.metrics.first_plant_tick,
        .left_release = instance.foot_plants.left.metrics.first_release_tick,
        .right_contact = instance.foot_plants.right.metrics.first_contact_tick,
        .right_plant = instance.foot_plants.right.metrics.first_plant_tick,
        .right_release = instance.foot_plants.right.metrics.first_release_tick,
        .left_target = instance.foot_plants.left.locked_target,
        .right_target = instance.foot_plants.right.locked_target,
        .left_state = instance.foot_plants.left.plant_state,
        .right_state = instance.foot_plants.right.plant_state,
        .left_weight = instance.foot_plants.left.plant_weight,
        .right_weight = instance.foot_plants.right.plant_weight,
        .maximum_slip = @max(instance.foot_plants.left.metrics.maximum_world_space_slip, instance.foot_plants.right.metrics.maximum_world_space_slip),
    };
}

test "plant acquisition release targets slip states and weights are invariant across render schedules" {
    const schedule_a = [_]u8{1};
    const schedule_b = [_]u8{4};
    const schedule_c = [_]u8{ 0, 1, 3, 4 };
    const a = try runPlantSchedule(&schedule_a);
    const b = try runPlantSchedule(&schedule_b);
    const c = try runPlantSchedule(&schedule_c);
    try std.testing.expectEqualDeep(a, b);
    try std.testing.expectEqualDeep(a, c);
    try std.testing.expect(a.left_contact != null and a.right_contact != null);
    try std.testing.expect(a.left_plant != null and a.right_plant != null);
    try std.testing.expect(a.left_release != null and a.right_release != null);
    try std.testing.expect(a.maximum_slip <= tolerance);
}

test "arm IK and planted leg IK coexist on disjoint chains without moving the foot lock" {
    const world_inputs = [_]collider.StaticColliderInput{staticInput(1, bounds(-20, -1, 20, 0), true)};
    var world = try collision_world.CollisionWorld.init(std.testing.allocator, &world_inputs, null);
    defer world.deinit();
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var instance = try character.CharacterInstance.initControlled(std.testing.allocator, try character.entityIdFromRaw(1), &definition, &animations, &world, .{}, .{ .x = 0, .y = 1.05 }, .right, 0, null);
    defer instance.deinit();
    var tick: u64 = 0;
    while (tick < 300 and instance.foot_plants.left.plant_state != .planted) : (tick += 1) {
        const physics = try instance.stepController(&world, controllerIntent(tick, null));
        try instance.selectControllerAnimation(physics);
        try instance.advanceVisualTickWithFootPlanting(&world, visualInput(&instance, physics));
    }
    try std.testing.expectEqual(foot_planting.PlantState.planted, instance.foot_plants.left.plant_state);
    const foot_before = try instance.socketPosition(.left_foot);
    const hand_before = try instance.socketPosition(.right_hand);
    const hand_target = hand_before.add(.{ .x = -0.08, .y = 0 });
    const hand_metrics = try instance.applyRightHandIk(hand_target, 1);
    const foot_after = try instance.socketPosition(.left_foot);
    try std.testing.expect(hand_metrics.target_error <= tolerance);
    try std.testing.expect(foot_after.approxEqAbs(foot_before, tolerance));
    try std.testing.expect(instance.foot_plants.left.locked_target != null);
}

test "handshake lifecycle arm IK and character local foot locks coexist without timeline or ownership coupling" {
    var definition = try humanoid.HumanoidDefinition.init(std.testing.allocator, null);
    defer definition.deinit();
    var animations = try authored.Definitions.init(std.testing.allocator, &definition.skeleton_definition, null);
    defer animations.deinit();
    var baseline_a = try character.CharacterInstance.init(std.testing.allocator, try character.entityIdFromRaw(1), &definition, &animations, .{ .x = -1.86, .y = 1.05 }, .right, 0, null);
    defer baseline_a.deinit();
    var baseline_b = try character.CharacterInstance.init(std.testing.allocator, try character.entityIdFromRaw(2), &definition, &animations, .{ .x = 1.86, .y = 1.05 }, .left, 1, null);
    defer baseline_b.deinit();
    var planted_a = try character.CharacterInstance.init(std.testing.allocator, try character.entityIdFromRaw(3), &definition, &animations, .{ .x = -1.86, .y = 1.05 }, .right, 0, null);
    defer planted_a.deinit();
    var planted_b = try character.CharacterInstance.init(std.testing.allocator, try character.entityIdFromRaw(4), &definition, &animations, .{ .x = 1.86, .y = 1.05 }, .left, 1, null);
    defer planted_b.deinit();
    planted_a.foot_plants.left = .{ .plant_state = .planted, .plant_weight = 1, .locked_target = .{ .x = -2, .y = 0 }, .locked_collider_id = 1 };
    planted_b.foot_plants.right = .{ .plant_state = .planted, .plant_weight = 1, .locked_target = .{ .x = 2, .y = 0 }, .locked_collider_id = 1 };

    const definition_value = try handshake.definition(&animations);
    var baseline_manager = interaction_system.Manager.initWithIk(definition_value);
    var planted_manager = interaction_system.Manager.initWithIk(definition_value);
    const baseline_participants = [_]*character.CharacterInstance{ &baseline_a, &baseline_b };
    const planted_participants = [_]*character.CharacterInstance{ &planted_a, &planted_b };
    const baseline_id = try baseline_manager.startPair(baseline_a.id, baseline_b.id, &baseline_participants, 0, .none);
    const planted_id = try planted_manager.startPair(planted_a.id, planted_b.id, &planted_participants, 0, .none);
    var tick: u64 = 1;
    while (tick <= definition_value.event(.complete).elapsed_tick) : (tick += 1) {
        try baseline_manager.updateTick(tick, &baseline_participants);
        try planted_manager.updateTick(tick, &planted_participants);
    }
    const baseline_instance = baseline_manager.instance(baseline_id).?;
    const planted_instance = planted_manager.instance(planted_id).?;
    try std.testing.expectEqual(interaction.Lifecycle.completed, baseline_instance.lifecycle);
    try std.testing.expectEqual(baseline_instance.lifecycle, planted_instance.lifecycle);
    try std.testing.expectEqualDeep(baseline_instance.event_ticks, planted_instance.event_ticks);
    try std.testing.expectEqualDeep(baseline_instance.event_counts, planted_instance.event_counts);
    try std.testing.expectApproxEqAbs(baseline_instance.contact.post_separation, planted_instance.contact.post_separation, tolerance);
    try std.testing.expect(planted_a.foot_plants.left.hasLock());
    try std.testing.expect(planted_b.foot_plants.right.hasLock());
}

test "scripted foot planting demonstration deterministically crosses floor jump landing and raised platform" {
    var scene = try foot_planting_demo.Scene.init(std.testing.allocator);
    defer scene.deinit();
    for (0..foot_planting_demo.required_frames) |_| try scene.updateFrame();
    try scene.validateComplete();
    try std.testing.expectEqual(@as(?collider.ColliderId, @intFromEnum(collision_world.DemoColliderId.raised_platform_1)), scene.enabled.controller.?.state.supporting_collider);
    try std.testing.expect(scene.flat.pre_ik_sole_error > scene.flat.post_ik_sole_error * 100);
    try std.testing.expect(scene.raised.pre_ik_sole_error > scene.raised.post_ik_sole_error * 100);
    try std.testing.expect(scene.physics.positions_agree and scene.physics.velocities_agree);
    try std.testing.expectEqual(@as(u32, 0), scene.jump.false_airborne_plant_count);
}
