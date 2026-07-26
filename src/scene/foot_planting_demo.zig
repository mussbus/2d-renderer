const std = @import("std");
const math = @import("math");
const input = @import("input");
const fixed_step = @import("fixed_step");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const events = @import("events");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const foot_planting = @import("foot_planting");
const leg_ik = @import("leg_ik");
const sprite = @import("sprite_batch");

pub const required_frames: u32 = 1200;
pub const character_count: u32 = 1;
pub const contact_tick_capacity: usize = 64;

pub const FootEvidence = struct {
    captured: bool = false,
    first_contact_tick: u64 = 0,
    first_plant_tick: u64 = 0,
    collider_id: collider.ColliderId = collider.invalid_collider_id,
    locked_target: math.Vec2 = math.Vec2.zero,
};

pub const SurfaceEvidence = struct {
    captured: bool = false,
    ground_height: f32 = 0,
    pre_ik_sole_error: f32 = 0,
    post_ik_sole_error: f32 = 0,
};

pub const JumpEvidence = struct {
    jump_tick: ?u64 = null,
    left_lock_before_jump: bool = false,
    right_lock_before_jump: bool = false,
    left_lock_after_takeoff: bool = false,
    right_lock_after_takeoff: bool = false,
    false_airborne_plant_count: u32 = 0,
    landing_tick: ?u64 = null,
    fresh_post_landing_plant: bool = false,
};

pub const PhysicsEvidence = struct {
    positions_agree: bool = true,
    velocities_agree: bool = true,
    grounded_agrees: bool = true,
    support_agrees: bool = true,
    animation_state_agrees: bool = true,
    animation_time_agrees: bool = true,
    landing_count_enabled: u32 = 0,
    landing_count_disabled: u32 = 0,
};

const ScriptPhase = enum(u8) {
    idle,
    flat_walk,
    jump_press,
    jump_hold,
    airborne_wait,
    post_landing_walk,
    platform_approach,
    platform_jump_press,
    platform_jump_hold,
    platform_wait,
    platform_walk,
    settle,
};

const Script = struct {
    builder: input.SnapshotBuilder = .{},
    phase: ScriptPhase = .idle,
    phase_frames: u32 = 0,
    direction_right: bool = true,

    fn nextFrame(script: *Script, instance: *const character.CharacterInstance) !input.FrameInputSnapshot {
        const controller = instance.controller.?;
        var raw = input.RawInputState{};
        switch (script.phase) {
            .idle => if (script.phase_frames >= 30) script.advance(.flat_walk),
            .flat_walk => {
                const interval = (script.phase_frames / 90) % 2;
                raw.gamepad_move_axis = if (interval == 0) 0.45 else -0.45;
                if (script.phase_frames >= 180 and
                    instance.foot_plants.left.metrics.first_plant_tick != null and
                    instance.foot_plants.right.metrics.first_plant_tick != null)
                {
                    script.advance(.jump_press);
                }
            },
            .jump_press => {
                raw.keyboard.space = true;
                script.advance(.jump_hold);
            },
            .jump_hold => {
                raw.keyboard.space = script.phase_frames < 8;
                if (script.phase_frames >= 8) script.advance(.airborne_wait);
            },
            .airborne_wait => {},
            .post_landing_walk => {
                const interval = (script.phase_frames / 60) % 2;
                raw.gamepad_move_axis = if (interval == 0) 0.45 else -0.45;
                if (script.phase_frames >= 120) script.advance(.platform_approach);
            },
            .platform_approach => {
                raw.keyboard.d = true;
                if (controller.state.grounded and controller.state.position.x >= -1.75) script.advance(.platform_jump_press);
            },
            .platform_jump_press => {
                raw.keyboard.d = true;
                raw.keyboard.space = true;
                script.advance(.platform_jump_hold);
            },
            .platform_jump_hold => {
                raw.keyboard.d = true;
                raw.keyboard.space = script.phase_frames < 20;
                if (script.phase_frames >= 20) script.advance(.platform_wait);
            },
            .platform_wait => raw.keyboard.d = true,
            .platform_walk => {
                if (controller.state.position.x > -0.05) script.direction_right = false;
                if (controller.state.position.x < -0.25) script.direction_right = true;
                raw.gamepad_move_axis = if (script.direction_right) 0.30 else -0.30;
            },
            .settle => {},
        }
        script.phase_frames += 1;
        return script.builder.update(raw);
    }

    fn advance(script: *Script, phase: ScriptPhase) void {
        script.phase = phase;
        script.phase_frames = 0;
    }
};

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,
    world: collision_world.CollisionWorld,
    enabled: character.CharacterInstance,
    disabled: character.CharacterInstance,
    clock: fixed_step.Clock,
    pending_input: input.PendingInput = .{},
    script: Script = .{},
    simulation_tick: u64 = 0,
    left: FootEvidence = .{},
    right: FootEvidence = .{},
    flat: SurfaceEvidence = .{},
    raised: SurfaceEvidence = .{},
    jump: JumpEvidence = .{},
    physics: PhysicsEvidence = .{},
    enabled_contact_ticks: [contact_tick_capacity]u64 = [_]u64{0} ** contact_tick_capacity,
    disabled_contact_ticks: [contact_tick_capacity]u64 = [_]u64{0} ** contact_tick_capacity,
    enabled_contact_count: usize = 0,
    disabled_contact_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var definition = try humanoid.HumanoidDefinition.init(allocator, null);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
        var world = try collision_world.CollisionWorld.initDemo(allocator, null);
        errdefer world.deinit();
        var enabled = try character.CharacterInstance.initControlled(
            allocator,
            try character.entityIdFromRaw(1),
            &definition,
            &animations,
            &world,
            .{},
            .{ .x = -3.15, .y = 1.05 },
            .right,
            0,
            null,
        );
        errdefer enabled.deinit();
        var disabled = try character.CharacterInstance.initControlled(
            allocator,
            try character.entityIdFromRaw(2),
            &definition,
            &animations,
            &world,
            .{},
            .{ .x = -3.15, .y = 1.05 },
            .right,
            1,
            null,
        );
        errdefer disabled.deinit();
        disabled.foot_plants.setEnabled(false);
        return .{
            .definition = definition,
            .animations = animations,
            .world = world,
            .enabled = enabled,
            .disabled = disabled,
            .clock = try fixed_step.Clock.init(.{}),
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.disabled.deinit();
        scene.enabled.deinit();
        scene.world.deinit();
        scene.animations.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene) !void {
        const snapshot = try scene.script.nextFrame(&scene.enabled);
        try scene.pending_input.acceptFrame(snapshot);
        const frame = try scene.clock.beginFrame(1.0 / 60.0);
        for (0..frame.substeps) |_| try scene.updateTick();
    }

    fn updateTick(scene: *Scene) !void {
        const intent_value = scene.pending_input.consumeTick();
        if (intent_value.jump_pressed) {
            scene.jump.left_lock_before_jump = scene.enabled.foot_plants.left.hasLock();
            scene.jump.right_lock_before_jump = scene.enabled.foot_plants.right.hasLock();
        }
        const enabled_result = try scene.enabled.stepController(&scene.world, intent_value);
        const disabled_result = try scene.disabled.stepController(&scene.world, intent_value);
        try scene.enabled.selectControllerAnimation(enabled_result);
        try scene.disabled.selectControllerAnimation(disabled_result);
        try scene.enabled.advanceVisualTickWithFootPlanting(&scene.world, makeVisualInput(&scene.enabled, enabled_result));
        try scene.disabled.advanceVisualTickWithFootPlanting(&scene.world, makeVisualInput(&scene.disabled, disabled_result));
        scene.simulation_tick += 1;

        try scene.recordContactTicks();
        try scene.recordFootEvidence(.left);
        try scene.recordFootEvidence(.right);
        scene.recordSurfaceEvidence();
        scene.recordPhysicsEvidence(enabled_result, disabled_result);

        if (enabled_result.jump_accepted) {
            scene.jump.jump_tick = enabled_result.simulation_tick;
            scene.jump.left_lock_after_takeoff = scene.enabled.foot_plants.left.hasLock();
            scene.jump.right_lock_after_takeoff = scene.enabled.foot_plants.right.hasLock();
        }
        if (!scene.enabled.controller.?.state.grounded and
            (scene.enabled.foot_plants.left.hasLock() or scene.enabled.foot_plants.right.hasLock()))
        {
            scene.jump.false_airborne_plant_count += 1;
        }
        if (enabled_result.landed) {
            scene.physics.landing_count_enabled += 1;
            scene.jump.landing_tick = enabled_result.simulation_tick;
            if (scene.script.phase == .airborne_wait) scene.script.advance(.post_landing_walk);
        }
        if (disabled_result.landed) scene.physics.landing_count_disabled += 1;
        if (scene.jump.landing_tick != null and
            ((scene.enabled.foot_plants.left.metrics.last_plant_tick orelse 0) > scene.jump.landing_tick.? or
                (scene.enabled.foot_plants.right.metrics.last_plant_tick orelse 0) > scene.jump.landing_tick.?))
        {
            scene.jump.fresh_post_landing_plant = true;
        }
        if (enabled_result.landed and scene.enabled.controller.?.state.supporting_collider == @intFromEnum(collision_world.DemoColliderId.raised_platform_1)) {
            scene.script.advance(.platform_walk);
        }
    }

    fn recordContactTicks(scene: *Scene) !void {
        for (scene.enabled.animator.emittedEvents()) |emitted| {
            if (isFootContact(emitted.record.event_type)) {
                if (scene.enabled_contact_count >= scene.enabled_contact_ticks.len) return error.ContactEvidenceOverflow;
                scene.enabled_contact_ticks[scene.enabled_contact_count] = scene.simulation_tick;
                scene.enabled_contact_count += 1;
            }
        }
        for (scene.disabled.animator.emittedEvents()) |emitted| {
            if (isFootContact(emitted.record.event_type)) {
                if (scene.disabled_contact_count >= scene.disabled_contact_ticks.len) return error.ContactEvidenceOverflow;
                scene.disabled_contact_ticks[scene.disabled_contact_count] = scene.simulation_tick;
                scene.disabled_contact_count += 1;
            }
        }
    }

    fn recordFootEvidence(scene: *Scene, foot: leg_ik.AnatomicalFoot) !void {
        const runtime = scene.enabled.foot_plants.footConst(foot);
        const evidence = if (foot == .left) &scene.left else &scene.right;
        if (evidence.first_contact_tick == 0) evidence.first_contact_tick = runtime.metrics.first_contact_tick orelse 0;
        if (!evidence.captured and runtime.plant_state == .planted and runtime.locked_target != null) {
            evidence.* = .{
                .captured = true,
                .first_contact_tick = runtime.metrics.first_contact_tick.?,
                .first_plant_tick = runtime.metrics.first_plant_tick.?,
                .collider_id = runtime.locked_collider_id.?,
                .locked_target = runtime.locked_target.?,
            };
        }
    }

    fn recordSurfaceEvidence(scene: *Scene) void {
        for ([_]*const foot_planting.FootRuntime{ &scene.enabled.foot_plants.left, &scene.enabled.foot_plants.right }) |runtime| {
            if (runtime.plant_state != .planted or runtime.plant_weight != 1 or runtime.locked_target == null) continue;
            const destination = if (runtime.locked_collider_id == @intFromEnum(collision_world.DemoColliderId.floor))
                &scene.flat
            else if (runtime.locked_collider_id == @intFromEnum(collision_world.DemoColliderId.raised_platform_1))
                &scene.raised
            else
                continue;
            if (!destination.captured) {
                const target = runtime.locked_target.?;
                destination.* = .{
                    .captured = true,
                    .ground_height = target.y,
                    .pre_ik_sole_error = @abs(runtime.pre_ik_sole.y - target.y),
                    .post_ik_sole_error = @abs(runtime.post_ik_sole.y - target.y),
                };
            }
        }
        if (scene.raised.captured and scene.script.phase == .platform_walk and scene.script.phase_frames >= 60) scene.script.advance(.settle);
    }

    fn recordPhysicsEvidence(
        scene: *Scene,
        enabled_result: character_controller.StepResult,
        disabled_result: character_controller.StepResult,
    ) void {
        const enabled_state = scene.enabled.controller.?.state;
        const disabled_state = scene.disabled.controller.?.state;
        scene.physics.positions_agree = scene.physics.positions_agree and enabled_state.position.approxEqAbs(disabled_state.position, 0);
        scene.physics.velocities_agree = scene.physics.velocities_agree and enabled_state.velocity.approxEqAbs(disabled_state.velocity, 0);
        scene.physics.grounded_agrees = scene.physics.grounded_agrees and enabled_state.grounded == disabled_state.grounded;
        scene.physics.support_agrees = scene.physics.support_agrees and enabled_state.supporting_collider == disabled_state.supporting_collider;
        scene.physics.animation_state_agrees = scene.physics.animation_state_agrees and scene.enabled.animationState() == scene.disabled.animationState();
        scene.physics.animation_time_agrees = scene.physics.animation_time_agrees and scene.enabled.animationTime() == scene.disabled.animationTime();
        if (enabled_result.jump_accepted != disabled_result.jump_accepted or enabled_result.landed != disabled_result.landed) {
            scene.physics.grounded_agrees = false;
        }
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        var submitted = try scene.enabled.submitAttachments(batch);
        for (scene.world.colliders) |static_collider| {
            const center = static_collider.bounds.center();
            const size = static_collider.bounds.size();
            try batch.submit(.{
                .world_position = center.toArray(),
                .rotation = 0,
                .scale = size.toArray(),
                .pivot = .{ 0.5, 0.5 },
                .uv_rect = .{ 0, 0.5, 0.5, 1 },
                .tint = .{ 0.30, 0.38, 0.48, 0.75 },
                .texture_page = 0,
                .order = .{ .scene_layer = -10, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = static_collider.id },
            });
            submitted += 1;
        }
        return submitted;
    }

    pub fn validateComplete(scene: *const Scene) !void {
        const left_metrics = scene.enabled.foot_plants.left.metrics;
        const right_metrics = scene.enabled.foot_plants.right.metrics;
        if (scene.script.phase != .settle or scene.script.phase_frames < 60 or
            !scene.left.captured or !scene.right.captured or !scene.flat.captured or !scene.raised.captured or
            scene.jump.jump_tick == null or scene.jump.landing_tick == null or
            scene.jump.left_lock_after_takeoff or scene.jump.right_lock_after_takeoff or
            scene.jump.false_airborne_plant_count != 0 or !scene.jump.fresh_post_landing_plant or
            !scene.physics.positions_agree or !scene.physics.velocities_agree or !scene.physics.grounded_agrees or
            !scene.physics.support_agrees or !scene.physics.animation_state_agrees or !scene.physics.animation_time_agrees or
            scene.physics.landing_count_enabled != scene.physics.landing_count_disabled or
            scene.enabled_contact_count != scene.disabled_contact_count or
            !std.mem.eql(u64, scene.enabled_contact_ticks[0..scene.enabled_contact_count], scene.disabled_contact_ticks[0..scene.disabled_contact_count]) or
            left_metrics.maximum_world_space_slip > foot_planting.full_plant_error_tolerance or
            right_metrics.maximum_world_space_slip > foot_planting.full_plant_error_tolerance or
            left_metrics.maximum_penetration > foot_planting.full_plant_error_tolerance or
            right_metrics.maximum_penetration > foot_planting.full_plant_error_tolerance or
            left_metrics.maximum_hover > foot_planting.full_plant_error_tolerance or
            right_metrics.maximum_hover > foot_planting.full_plant_error_tolerance or
            scene.enabled.foot_plants.left.hasLock() or scene.enabled.foot_plants.right.hasLock())
        {
            std.log.err("foot planting evidence incomplete: phase={s} phase_frames={d} left={} right={} flat={} raised={} jump={any} landing={any} locks_after={}/{} airborne_false={d} fresh={} physics={}/{}/{}/{}/{}/{} landings={d}/{d} contacts={d}/{d} final_locks={}/{} slip={d}/{d} penetration={d}/{d} hover={d}/{d}", .{
                @tagName(scene.script.phase),          scene.script.phase_frames,              scene.left.captured,                scene.right.captured,                scene.flat.captured,                      scene.raised.captured,
                scene.jump.jump_tick,                  scene.jump.landing_tick,                scene.jump.left_lock_after_takeoff, scene.jump.right_lock_after_takeoff, scene.jump.false_airborne_plant_count,    scene.jump.fresh_post_landing_plant,
                scene.physics.positions_agree,         scene.physics.velocities_agree,         scene.physics.grounded_agrees,      scene.physics.support_agrees,        scene.physics.animation_state_agrees,     scene.physics.animation_time_agrees,
                scene.physics.landing_count_enabled,   scene.physics.landing_count_disabled,   scene.enabled_contact_count,        scene.disabled_contact_count,        scene.enabled.foot_plants.left.hasLock(), scene.enabled.foot_plants.right.hasLock(),
                left_metrics.maximum_world_space_slip, right_metrics.maximum_world_space_slip, left_metrics.maximum_penetration,   right_metrics.maximum_penetration,   left_metrics.maximum_hover,               right_metrics.maximum_hover,
            });
            std.log.err("foot planting route state: controller=({d},{d}) grounded={} support={any} foot_states={s}/{s} sample_hits={}/{} sample_colliders={d}/{d}", .{
                scene.enabled.controller.?.state.position.x,                    scene.enabled.controller.?.state.position.y,            scene.enabled.controller.?.state.grounded,
                scene.enabled.controller.?.state.supporting_collider,           @tagName(scene.enabled.foot_plants.left.plant_state),   @tagName(scene.enabled.foot_plants.right.plant_state),
                scene.enabled.foot_plants.left.last_ground_sample.hit,          scene.enabled.foot_plants.right.last_ground_sample.hit, scene.enabled.foot_plants.left.last_ground_sample.collider_id,
                scene.enabled.foot_plants.right.last_ground_sample.collider_id,
            });
            std.log.err("foot planting route metrics: contacts={d}/{d} last_plants={any}/{any} rejected_ground={d}/{d} rejected_reach={d}/{d} animation={s} velocity_x={d}", .{
                left_metrics.contact_events,              right_metrics.contact_events,                left_metrics.last_plant_tick,      right_metrics.last_plant_tick,
                left_metrics.rejected_no_ground,          right_metrics.rejected_no_ground,            left_metrics.rejected_unreachable, right_metrics.rejected_unreachable,
                @tagName(scene.enabled.animationState()), scene.enabled.controller.?.state.velocity.x,
            });
            return error.FootPlantingEvidenceIncomplete;
        }
    }
};

fn makeVisualInput(instance: *const character.CharacterInstance, physics: character_controller.StepResult) character.VisualTickInput {
    const controller = instance.controller.?;
    return .{
        .horizontal_velocity = controller.state.velocity.x,
        .vertical_velocity = controller.state.velocity.y,
        .physically_grounded = controller.state.grounded,
        .landing_event = if (physics.landed) .{
            .simulation_tick = physics.simulation_tick,
            .impact_speed = physics.landing_impact_speed,
        } else null,
    };
}

fn isFootContact(event_type: events.EventType) bool {
    return event_type == .left_foot_contact or event_type == .right_foot_contact;
}
