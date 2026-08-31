const std = @import("std");
const math = @import("math");
const input = @import("input");
const fixed_step = @import("fixed_step");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const humanoid = @import("humanoid");
const animation_system = @import("animation_system");
const state_machine = @import("state_machine");
const procedural_motion = @import("procedural_motion");
const sprite = @import("sprite_batch");
const fault_injection = @import("fault_injection");

pub const spawn_position = math.Vec2{ .x = -3.15, .y = 1.05 };

pub const HotPathMetrics = struct {
    clock_allocations: u64 = 0,
    input_allocations: u64 = 0,
    intent_allocations: u64 = 0,
    controller_allocations: u64 = 0,
    collision_allocations: u64 = 0,
    animation_selection_allocations: u64 = 0,
    animator_allocations: u64 = 0,
    render_interpolation_allocations: u64 = 0,
    simulation_ticks: u64 = 0,
    animator_ticks: u64 = 0,
    jump_events: u32 = 0,
    coyote_jumps: u32 = 0,
    buffered_jumps: u32 = 0,
    landing_events: u32 = 0,
    wall_collisions: u32 = 0,
    ceiling_collisions: u32 = 0,
};

pub const TickResult = struct {
    physics: character_controller.StepResult,
    animation_before: state_machine.StateId,
    animation_after: state_machine.StateId,
};

pub const Runtime = struct {
    world: collision_world.CollisionWorld,
    controller: character_controller.CharacterController,
    clock: fixed_step.Clock,
    pending_input: input.PendingInput = .{},
    procedural: procedural_motion.State,
    metrics: HotPathMetrics = .{},

    pub fn init(allocator: std.mem.Allocator, injector: ?fault_injection.Injector) !Runtime {
        var world = try collision_world.CollisionWorld.initDemo(allocator, injector);
        errdefer world.deinit();
        const controller = try character_controller.CharacterController.init(.{}, &world, spawn_position, .right);
        const clock = try fixed_step.Clock.init(.{});
        const procedural = try procedural_motion.State.init();
        try after(injector, .partial_controller_demo_creation);
        return .{ .world = world, .controller = controller, .clock = clock, .procedural = procedural };
    }

    pub fn deinit(runtime: *Runtime) void {
        runtime.world.deinit();
        runtime.* = undefined;
    }

    pub fn acceptFrameInput(runtime: *Runtime, snapshot: input.FrameInputSnapshot) !void {
        try runtime.pending_input.acceptFrame(snapshot);
    }

    pub fn beginFrame(runtime: *Runtime, raw_delta: f64) !fixed_step.FrameMetrics {
        return runtime.clock.beginFrame(raw_delta);
    }

    pub fn simulateTick(
        runtime: *Runtime,
        animation: *animation_system.Runtime,
        character: *humanoid.HumanoidCharacter,
        definition: *const humanoid.HumanoidDefinition,
    ) !TickResult {
        const intent = runtime.pending_input.consumeTick();
        const physics_result = try runtime.controller.step(&runtime.world, intent);
        const before = animation.animator.currentState(&animation.definitions.machine);
        try selectAnimation(animation, &runtime.controller, physics_result);
        try animation.animator.update(
            &animation.definitions.machine,
            animation.definitions.library.clips,
            animation.definitions.library.token(),
            &definition.skeleton_definition,
            @floatCast(fixed_step.fixed_dt_seconds),
            &character.local_and_world_pose,
        );
        const walk_sample = currentWalkSample(animation);
        try runtime.procedural.update(.{
            .horizontal_velocity = runtime.controller.state.velocity.x,
            .physically_grounded = runtime.controller.state.grounded,
            .walk_cycle_phase = walk_sample.phase,
            .walk_layer_weight = walk_sample.weight,
            .landing_event = if (physics_result.landed) .{
                .simulation_tick = physics_result.simulation_tick,
                .impact_speed = physics_result.landing_impact_speed,
            } else null,
        });
        try runtime.procedural.composePose(
            &definition.skeleton_definition,
            &character.local_and_world_pose,
            runtime.controller.state.simulation_tick,
        );
        character.character_to_world = math.Transform2D.init(runtime.controller.state.position, 0, math.Vec2.one);
        try character.local_and_world_pose.evaluateWorld(&definition.skeleton_definition, character.character_to_world);
        try character.evaluateAppearance(definition);
        const after_state = animation.animator.currentState(&animation.definitions.machine);

        runtime.metrics.simulation_ticks += 1;
        runtime.metrics.animator_ticks += 1;
        if (physics_result.jump_accepted) runtime.metrics.jump_events += 1;
        if (physics_result.jump_source == .coyote) runtime.metrics.coyote_jumps += 1;
        if (physics_result.jump_source == .buffered) runtime.metrics.buffered_jumps += 1;
        if (physics_result.landed) runtime.metrics.landing_events += 1;
        if (physics_result.wall_collision) runtime.metrics.wall_collisions += 1;
        if (physics_result.ceiling_collision) runtime.metrics.ceiling_collisions += 1;
        return .{ .physics = physics_result, .animation_before = before, .animation_after = after_state };
    }

    pub fn renderPosition(runtime: *const Runtime) !math.Vec2 {
        return runtime.controller.interpolatedPosition(runtime.clock.last_frame.interpolation_alpha);
    }

    pub fn evaluateRenderPose(
        runtime: *Runtime,
        character: *humanoid.HumanoidCharacter,
        definition: *const humanoid.HumanoidDefinition,
    ) !void {
        const render_position = try runtime.renderPosition();
        character.character_to_world = math.Transform2D.init(render_position, 0, math.Vec2.one);
        try character.local_and_world_pose.evaluateWorld(&definition.skeleton_definition, character.character_to_world);
        try character.evaluateAppearance(definition);
    }

    pub fn reset(
        runtime: *Runtime,
        animation: *animation_system.Runtime,
        character: *humanoid.HumanoidCharacter,
        definition: *const humanoid.HumanoidDefinition,
    ) !void {
        try runtime.controller.reset(&runtime.world);
        runtime.clock.reset();
        runtime.pending_input.reset();
        runtime.metrics = .{};
        try runtime.procedural.reset(runtime.controller.state.velocity.x);
        try animation.animator.enterState(&animation.definitions.machine, .idle);
        try animation.animator.update(
            &animation.definitions.machine,
            animation.definitions.library.clips,
            animation.definitions.library.token(),
            &definition.skeleton_definition,
            0,
            &character.local_and_world_pose,
        );
        character.character_to_world = math.Transform2D.init(runtime.controller.state.position, 0, math.Vec2.one);
        try character.local_and_world_pose.evaluateWorld(&definition.skeleton_definition, character.character_to_world);
        try character.appearance_runtime.reset(definition.visual_definition.view());
        try character.evaluateAppearance(definition);
    }

    pub fn setProceduralEnabled(runtime: *Runtime, enabled: bool) !void {
        try runtime.procedural.setEnabled(enabled, runtime.controller.state.velocity.x);
    }

    pub fn submitCollisionGeometry(runtime: Runtime, batch: *sprite.SpriteBatch) !u32 {
        var submitted: u32 = 0;
        for (runtime.world.colliders) |static_collider| {
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
                .order = .{
                    .scene_layer = -10,
                    .interaction_layer = 0,
                    .actor_layer = 0,
                    .body_part_layer = static_collider.id,
                },
            });
            submitted += 1;
        }
        return submitted;
    }
};

pub const ScriptPhase = enum {
    idle,
    ceiling_press,
    ceiling_hold,
    ceiling_wait,
    platform_approach,
    platform_jump_hold,
    platform_wait,
    walk_off_first,
    coyote_delay,
    coyote_press,
    coyote_hold,
    coyote_wait,
    walk_off_second,
    buffer_fall,
    buffer_press,
    buffered_wait,
    buffered_hold,
    wall_and_land,
    settle,
};

pub const ScriptedInput = struct {
    builder: input.SnapshotBuilder = .{},
    phase: ScriptPhase = .idle,
    phase_frames: u32 = 0,
    ceiling_seen: bool = false,
    first_platform_landed: bool = false,
    second_platform_landed: bool = false,
    coyote_jump_seen: bool = false,
    buffered_jump_seen: bool = false,
    wall_seen: bool = false,

    pub fn nextFrame(script: *ScriptedInput, controller: *const character_controller.CharacterController) !input.FrameInputSnapshot {
        var raw = input.RawInputState{};
        switch (script.phase) {
            .idle => {
                if (script.phase_frames >= 30) script.advance(.ceiling_press);
            },
            .ceiling_press => {
                raw.keyboard.d = true;
                raw.keyboard.space = true;
                script.advance(.ceiling_hold);
            },
            .ceiling_hold => {
                raw.keyboard.d = true;
                raw.keyboard.space = script.phase_frames < 3;
                if (script.phase_frames >= 3) script.advance(.ceiling_wait);
            },
            .ceiling_wait => {
                raw.keyboard.d = true;
                if (script.ceiling_seen and controller.state.grounded) script.advance(.platform_approach);
            },
            .platform_approach => {
                raw.keyboard.d = true;
                if (controller.state.grounded and controller.state.position.x >= -1.75) {
                    raw.keyboard.space = true;
                    script.advance(.platform_jump_hold);
                }
            },
            .platform_jump_hold => {
                raw.keyboard.d = true;
                raw.keyboard.space = script.phase_frames < 20;
                if (script.phase_frames >= 20) script.advance(.platform_wait);
            },
            .platform_wait => {
                raw.keyboard.d = true;
                if (script.first_platform_landed) script.advance(.walk_off_first);
            },
            .walk_off_first => raw.keyboard.d = true,
            .coyote_delay => {
                raw.keyboard.d = true;
                if (script.phase_frames >= 2) script.advance(.coyote_press);
            },
            .coyote_press => {
                raw.keyboard.d = true;
                raw.keyboard.space = true;
                script.advance(.coyote_hold);
            },
            .coyote_hold => {
                raw.keyboard.space = script.phase_frames < 18;
                if (script.phase_frames >= 18) script.advance(.coyote_wait);
            },
            .coyote_wait => {
                if (script.second_platform_landed) script.advance(.walk_off_second);
            },
            .walk_off_second => raw.keyboard.d = true,
            .buffer_fall => {
                raw.keyboard.d = true;
                if (controller.state.velocity.y < 0 and controller.state.position.y < 1.42) script.advance(.buffer_press);
            },
            .buffer_press => {
                raw.keyboard.d = true;
                raw.keyboard.space = true;
                script.advance(.buffered_wait);
            },
            .buffered_wait => raw.keyboard.d = true,
            .buffered_hold => {
                raw.keyboard.d = true;
                raw.keyboard.space = script.phase_frames < 4;
                if (script.phase_frames >= 4) script.advance(.wall_and_land);
            },
            .wall_and_land => {
                raw.keyboard.d = true;
                if (script.wall_seen and controller.state.grounded) script.advance(.settle);
            },
            .settle => {},
        }
        script.phase_frames += 1;
        return script.builder.update(raw);
    }

    pub fn observe(script: *ScriptedInput, tick: TickResult, controller: *const character_controller.CharacterController) void {
        if (tick.physics.ceiling_collision) script.ceiling_seen = true;
        if (tick.physics.landed and controller.state.supporting_collider == @intFromEnum(collision_world.DemoColliderId.raised_platform_1)) script.first_platform_landed = true;
        if (tick.physics.landed and controller.state.supporting_collider == @intFromEnum(collision_world.DemoColliderId.raised_platform_2)) script.second_platform_landed = true;
        if (tick.physics.ground_left and script.phase == .walk_off_first) script.advance(.coyote_delay);
        if (tick.physics.jump_source == .coyote) script.coyote_jump_seen = true;
        if (script.coyote_jump_seen and tick.physics.ground_left and script.phase == .walk_off_second) script.advance(.buffer_fall);
        if (tick.physics.jump_source == .buffered) {
            script.buffered_jump_seen = true;
            script.advance(.buffered_hold);
        }
        if (tick.physics.wall_collision) script.wall_seen = true;
    }

    pub fn completed(script: ScriptedInput) bool {
        return script.phase == .settle and script.phase_frames >= 60;
    }

    pub fn reset(script: *ScriptedInput) void {
        script.* = .{};
    }

    fn advance(script: *ScriptedInput, phase: ScriptPhase) void {
        script.phase = phase;
        script.phase_frames = 0;
    }
};

pub const SecondaryMotionScriptedInput = struct {
    builder: input.SnapshotBuilder = .{},
    controller_sequence: ScriptedInput = .{},
    prelude_frame: u32 = 0,

    pub fn nextFrame(
        script: *SecondaryMotionScriptedInput,
        controller: *const character_controller.CharacterController,
    ) !input.FrameInputSnapshot {
        if (script.prelude_frame > 180) return script.controller_sequence.nextFrame(controller);

        var raw = input.RawInputState{};
        if (script.prelude_frame >= 30 and script.prelude_frame < 90) {
            raw.gamepad_left_x = 0.60;
        } else if (script.prelude_frame >= 90 and script.prelude_frame < 150) {
            raw.gamepad_left_x = -1.0;
        } else if (script.prelude_frame == 180) {
            raw.keyboard.r = true;
        }
        script.prelude_frame += 1;
        return script.builder.update(raw);
    }

    pub fn observe(
        script: *SecondaryMotionScriptedInput,
        tick: TickResult,
        controller: *const character_controller.CharacterController,
    ) void {
        if (script.prelude_frame > 180) script.controller_sequence.observe(tick, controller);
    }

    pub fn completed(script: SecondaryMotionScriptedInput) bool {
        return script.prelude_frame > 180 and script.controller_sequence.completed();
    }

    pub fn reset(script: *SecondaryMotionScriptedInput) void {
        script.* = .{};
    }
};

pub fn runFaultInjectionChecks(allocator: std.mem.Allocator) !void {
    for (fault_injection.controller_initialization_stages) |stage| {
        var attempt = Runtime.init(allocator, .{ .fail_after = stage }) catch |err| {
            if (err != error.InjectedInitializationFailure) return err;
            var clean = try Runtime.init(allocator, null);
            clean.deinit();
            std.log.info("controller fault-injection cleanup check passed after {s}", .{@tagName(stage)});
            continue;
        };
        attempt.deinit();
        return error.FaultInjectionDidNotTrigger;
    }
}

fn selectAnimation(animation: *animation_system.Runtime, controller: *const character_controller.CharacterController, physics: character_controller.StepResult) !void {
    const machine = &animation.definitions.machine;
    if (physics.jump_accepted) {
        try animation.animator.enterState(machine, .jump_start);
        return;
    }
    if (physics.landed) {
        try animation.animator.enterState(machine, .landing);
        return;
    }

    const current = animation.animator.currentState(machine);
    if (current == .jump_start or current == .landing) return;
    if (animation.animator.active_transition) |transition| {
        const source = machine.states[transition.source_state_index].id;
        if (source == .jump_start or source == .landing) return;
        return;
    }

    if (!controller.state.grounded) {
        const desired: state_machine.StateId = if (controller.state.velocity.y > 0.05) .rising else .falling;
        if (current != desired) try animation.animator.enterState(machine, desired);
        return;
    }

    const desired: state_machine.StateId = if (@abs(controller.state.velocity.x) < 0.10) .idle else .walk;
    if (current == desired) return;
    if ((current == .idle and desired == .walk) or (current == .walk and desired == .idle)) {
        try animation.animator.requestState(machine, desired);
    } else {
        try animation.animator.enterState(machine, desired);
    }
}

const WalkSample = struct {
    phase: f32 = 0,
    weight: f32 = 0,
};

fn currentWalkSample(animation: *const animation_system.Runtime) WalkSample {
    const animator = animation.animator;
    const machine = &animation.definitions.machine;
    const clips = animation.definitions.library.clips;
    if (animator.active_transition) |transition| {
        const weight = if (transition.duration == 0) 1 else @min(1, transition.elapsed / transition.duration);
        if (machine.states[transition.destination_state_index].id == .walk) {
            return .{
                .phase = playbackPhase(machine, clips, transition.destination_state_index, transition.destination_playback.current_time),
                .weight = weight,
            };
        }
        if (machine.states[transition.source_state_index].id == .walk) {
            return .{
                .phase = playbackPhase(machine, clips, transition.source_state_index, transition.source_playback.current_time),
                .weight = 1 - weight,
            };
        }
        return .{};
    }
    if (machine.states[animator.current_state_index].id != .walk) return .{};
    return .{
        .phase = playbackPhase(machine, clips, animator.current_state_index, animator.playback.current_time),
        .weight = 1,
    };
}

fn playbackPhase(machine: *const state_machine.Definition, clips: anytype, state_index: u16, current_time: f32) f32 {
    const animation_state = machine.states[state_index];
    const duration = clips[animation_state.clip_index].duration;
    return if (duration > 0) current_time / duration else 0;
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
