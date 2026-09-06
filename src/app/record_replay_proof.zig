const std = @import("std");
const replay = @import("record_replay");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const math = @import("math");
const controller = @import("character_controller");
const collision = @import("collision_world");
const intent_module = @import("character_intent");
const fixed = @import("fixed_step");

pub const CharacterIntent = intent_module.CharacterIntent;
pub const SetMaximumRunSpeed = struct { metres_per_second: f32 };
pub const schema = replay.Identity{ .id = 1, .version = 1 };
pub const channels = replay.Channels{
    .command = .{ .identity = schema, .maximum_size = 5, .validate_fn = validateCommand },
    .event = .{ .identity = schema, .maximum_size = 4, .validate_fn = validateEvent },
};

pub fn metadata() !replay.Metadata {
    return .{
        .derivation = .{
            .root_seed = try foundation.determinism.Seed128.parseLowerHex("00112233445566778899aabbccddeeff"),
            .generator_id = try foundation.identity.GeneratorId.parseCanonical("0195d5b8-4100-7000-8000-000000000001"),
            .generator_version = .init(1, 0, 0),
            .algorithm_id = try foundation.identity.AlgorithmId.parseCanonical("0195d5b8-4100-7000-8000-000000000002"),
            .algorithm_version = .init(1, 0, 0),
        },
        .initial_schema = schema,
        .command = schema,
        .event = schema,
    };
}

pub fn initialEnvelope(spawn_x: f32) replay.Error![4]u8 {
    if (!std.math.isFinite(spawn_x) or @abs(spawn_x) > 50) return error.InvalidPayload;
    var output: [4]u8 = undefined;
    var writer = replay.Bytes.init(&output);
    try writer.float(spawn_x);
    return output;
}

pub fn encodeCommand(intent: CharacterIntent) replay.Error![5]u8 {
    intent.validate() catch return error.InvalidPayload;
    var output: [5]u8 = undefined;
    var writer = replay.Bytes.init(&output);
    try writer.float(intent.move_axis);
    try writer.int(u8, @as(u8, @intFromBool(intent.jump_pressed)) |
        (@as(u8, @intFromBool(intent.jump_held)) << 1) |
        (@as(u8, @intFromBool(intent.jump_released)) << 2) |
        (@as(u8, @intFromBool(intent.dash_pressed)) << 3) |
        (@as(u8, @intFromBool(intent.interact_pressed)) << 4));
    return output;
}

pub fn decodeCommand(payload: []const u8) replay.Error!CharacterIntent {
    if (payload.len != 5) return error.InvalidPayload;
    var reader = replay.Reader{ .input = payload };
    const axis = try reader.float();
    const flags = try reader.int(u8);
    if (flags & 0xe0 != 0) return error.InvalidPayload;
    const intent = CharacterIntent{
        .move_axis = axis,
        .jump_pressed = flags & 1 != 0,
        .jump_held = flags & 2 != 0,
        .jump_released = flags & 4 != 0,
        .dash_pressed = flags & 8 != 0,
        .interact_pressed = flags & 16 != 0,
    };
    intent.validate() catch return error.InvalidPayload;
    return intent;
}

pub fn encodeEvent(event: SetMaximumRunSpeed) replay.Error![4]u8 {
    if (!std.math.isFinite(event.metres_per_second) or
        event.metres_per_second < 0.5 or event.metres_per_second > 20) return error.InvalidPayload;
    var output: [4]u8 = undefined;
    var writer = replay.Bytes.init(&output);
    try writer.float(event.metres_per_second);
    return output;
}

pub fn decodeEvent(payload: []const u8) replay.Error!SetMaximumRunSpeed {
    if (payload.len != 4) return error.InvalidPayload;
    var reader = replay.Reader{ .input = payload };
    const event = SetMaximumRunSpeed{ .metres_per_second = try reader.float() };
    _ = try encodeEvent(event);
    return event;
}

fn validateCommand(payload: []const u8) replay.Error!void {
    _ = try decodeCommand(payload);
}

fn validateEvent(payload: []const u8) replay.Error!void {
    _ = try decodeEvent(payload);
}

const State = struct {
    scene: scene_core.runtime_scene.RuntimeScene,
    snapshot: scene_core.runtime_scene.SceneSnapshot,
    world: collision.CollisionWorld,
    character: controller.CharacterController,
    properties: controller.GameplayProperties,
    bootstrap: replay.Digest,
    key: [32]u8,
};

/// External headless client; controller is the only moving simulation authority.
pub const Proof = struct {
    allocator: std.mem.Allocator,
    state: *State,

    pub fn init(allocator: std.mem.Allocator, session_metadata: replay.Metadata, envelope: []const u8) !Proof {
        try session_metadata.validate();
        const expected = try metadata();
        if (session_metadata.start_tick != 0) return error.InvalidTick;
        if (!session_metadata.initial_schema.eql(schema) or !session_metadata.command.eql(schema) or
            !session_metadata.event.eql(schema)) return error.UnsupportedChannel;
        const context = session_metadata.derivation;
        if (!context.generator_id.eql(expected.derivation.generator_id) or
            !context.algorithm_id.eql(expected.derivation.algorithm_id) or
            !context.generator_version.eql(expected.derivation.generator_version) or
            !context.algorithm_version.eql(expected.derivation.algorithm_version))
            return error.DerivationMismatch;
        if (envelope.len != 4) return error.InvalidPayload;
        var reader = replay.Reader{ .input = envelope };
        const spawn_x = try reader.float();
        _ = try initialEnvelope(spawn_x);
        const key = try foundation.determinism.deriveKey(context, &.{ "rr1.controller", "speed" });
        var world = try collision.CollisionWorld.init(allocator, &.{.{
            .id = 1,
            .bounds = .{ .minimum = .{ .x = -100, .y = -2 }, .maximum = .{ .x = 100, .y = 0 } },
        }}, null);
        errdefer world.deinit();
        const character = try controller.CharacterController.init(.{}, &world, .{ .x = spawn_x, .y = 1.05 }, .right);
        var scene = try scene_core.runtime_scene.RuntimeScene.init(allocator, .{
            .registry = .{
                .initial_entity_capacity = 1,
                .hard_entity_capacity = 1,
                .initial_mapping_capacity = 1,
                .hard_mapping_capacity = 1,
            },
            .initial_level_capacity = 1,
            .hard_level_capacity = 1,
            .max_snapshot_leases = 1,
        });
        // All leases are released by the later errdefer before scene destruction.
        errdefer scene.deinit() catch |err| std.debug.panic("RR1 scene cleanup invariant: {s}", .{@errorName(err)});
        const entity_id = try foundation.identity.EntityId.parseCanonical("0195d5b8-4100-7000-8000-000000000003");
        const handle = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
            .owner = .{ .physics_gameplay = null },
            .local_transform = .identity,
            .enabled = .enabled,
            .resolver = .{ .context = null, .resolve_fn = rejectAsset },
        });
        try scene.promoteTemporary(.{ .authority = .physics_gameplay }, handle, entity_id);
        const state = try allocator.create(State);
        errdefer allocator.destroy(state);
        state.scene = scene;
        var snapshot = try state.scene.acquireSnapshot(.{
            .tick = 0,
            .fixed_delta_seconds = @floatCast(fixed.fixed_dt_seconds),
            .interpolation_alpha = 0,
        });
        errdefer snapshot.deinit();
        const view = snapshot.view();
        const anchor = try view.get(handle);
        if (view.entityCount() != 1 or view.levelCount() != 0 or
            !anchor.lifetime.isPersistentWorld() or anchor.parent != null or
            anchor.childCount() != 0 or anchor.tagCount() != 0 or anchor.extensionCount() != 0 or
            anchor.assetCount() != 0 or anchor.overrideCount() != 0 or anchor.camera_definition != null or
            anchor.prefabNodePath() != null or anchor.persistent_id == null or
            !anchor.persistent_id.?.eql(entity_id)) return error.UnsupportedProofScene;
        state.* = .{
            .scene = scene,
            .snapshot = snapshot,
            .world = world,
            .character = character,
            .properties = .{
                .maximum_run_speed = 3 + @as(f32, @floatFromInt(key[0] % 3)),
                .jump_speed = character.configuration.jump_speed,
                .double_jump = true,
                .dash = true,
            },
            .bootstrap = undefined,
            .key = key,
        };
        state.bootstrap = try bootstrapDigest(state, context, envelope, anchor);
        return .{ .allocator = allocator, .state = state };
    }

    pub fn deinit(self: *Proof) void {
        self.state.snapshot.deinit();
        // This client owns exactly one lease and has just released it.
        self.state.scene.deinit() catch |err| std.debug.panic("RR1 scene cleanup invariant: {s}", .{@errorName(err)});
        self.state.world.deinit();
        self.allocator.destroy(self.state);
        self.* = undefined;
    }

    pub fn tick(self: *const Proof) u64 {
        return self.state.character.state.simulation_tick;
    }

    pub fn controllerState(self: *const Proof) controller.State {
        return self.state.character.state;
    }

    pub fn derivedKey(self: *const Proof) [32]u8 {
        return self.state.key;
    }

    pub fn digest(self: *const Proof) !replay.Digest {
        var fields: [32]u8 = undefined;
        var writer = replay.Bytes.init(&fields);
        const properties = self.state.properties;
        try writer.float(properties.maximum_run_speed);
        try writer.float(properties.jump_speed);
        try writer.boolean(properties.double_jump);
        try writer.boolean(properties.dash);
        return replay.stateDigest(&.{
            .{ .identity = .{ .id = 1, .version = 1 }, .digest = self.state.bootstrap },
            .{ .identity = .{ .id = 2, .version = 1 }, .digest = try controllerDigest(self.state.character.state) },
            .{ .identity = .{ .id = 3, .version = 1 }, .digest = try replay.contributorDigest(.{ .id = 3, .version = 1 }, writer.slice()) },
        });
    }

    /// The same existing production controller call is used in both modes.
    pub fn step(self: *Proof, tick_number: u64, command: CharacterIntent, event: ?SetMaximumRunSpeed) !void {
        if (tick_number != self.tick()) return error.InvalidTick;
        if (tick_number == std.math.maxInt(u64)) return error.TickOverflow;
        _ = try encodeCommand(command);
        if (event) |accepted| {
            _ = try encodeEvent(accepted);
            self.state.properties.maximum_run_speed = accepted.metres_per_second;
        }
        _ = try self.state.character.stepWithProperties(&self.state.world, command, self.state.properties);
    }

    pub fn recordTick(self: *Proof, session: *replay.Session, command: CharacterIntent, event: ?SetMaximumRunSpeed) !void {
        const tick_number = self.tick();
        const command_bytes = try encodeCommand(command);
        const event_bytes: ?[4]u8 = if (event) |accepted| try encodeEvent(accepted) else null;
        // Preflight avoids advancing the controller when the recorder is already full/closed.
        if (session.finished) return error.SessionFinished;
        if (session.count == session.storage.len) return error.CapacityExceeded;
        if (session.metadata.start_tick + session.count != tick_number) return error.InvalidTick;
        try self.step(tick_number, command, event);
        try session.append(tick_number, &command_bytes, if (event_bytes) |*bytes| bytes else null, try self.digest());
    }

    pub fn replayTick(self: *Proof, player: *replay.Player) !bool {
        const record = (try player.next()) orelse return false;
        const command = try decodeCommand(record.commandBytes());
        const event = if (record.eventBytes()) |bytes| try decodeEvent(bytes) else null;
        try self.step(record.tick, command, event);
        try player.verify(try self.digest());
        return true;
    }
};

pub fn controllerDigest(state: controller.State) !replay.Digest {
    // A new production field requires reviewing and versioning this explicit schema.
    comptime {
        if (@typeInfo(controller.State).@"struct".fields.len != 20)
            @compileError("Review RR1 controller state schema after production State changes");
    }
    var output: [256]u8 = undefined;
    var writer = replay.Bytes.init(&output);
    try vector(&writer, state.position);
    try vector(&writer, state.previous_position);
    try vector(&writer, state.velocity);
    try facing(&writer, state.facing);
    try writer.boolean(state.grounded);
    try writer.boolean(state.previous_grounded);
    try vector(&writer, state.ground_normal);
    try writer.boolean(state.supporting_collider != null);
    if (state.supporting_collider) |id| try writer.int(u16, id);
    try writer.float(state.previous_vertical_velocity);
    try writer.float(state.last_landing_impact_speed);
    try optionalTick(&writer, state.last_landing_tick);
    try optionalTick(&writer, state.last_jump_tick);
    try writer.int(u16, state.coyote_ticks_remaining);
    try writer.int(u16, state.jump_buffer_ticks_remaining);
    try writer.int(u8, state.air_jumps_used);
    try writer.boolean(state.jump_was_consumed);
    try writer.int(u16, state.dash_ticks_remaining);
    try writer.int(u16, state.dash_cooldown_ticks_remaining);
    try facing(&writer, state.dash_direction);
    try writer.int(u64, state.simulation_tick);
    return replay.contributorDigest(.{ .id = 2, .version = 1 }, writer.slice());
}

fn bootstrapDigest(state: *const State, context: foundation.determinism.DerivationContext, envelope: []const u8, anchor: scene_core.runtime_scene.EntityView) !replay.Digest {
    comptime {
        if (@typeInfo(controller.Configuration).@"struct".fields.len != 18 or
            @typeInfo(controller.GameplayProperties).@"struct".fields.len != 4)
            @compileError("Review RR1 configuration schema after production fields change");
    }
    var output: [1024]u8 = undefined;
    var writer = replay.Bytes.init(&output);
    try writer.raw(envelope);
    try writer.raw(&context.root_seed.bytes);
    try writer.raw(&context.generator_id.bytes);
    try writer.int(u32, context.generator_version.major);
    try writer.int(u32, context.generator_version.minor);
    try writer.int(u32, context.generator_version.patch);
    try writer.raw(&context.algorithm_id.bytes);
    try writer.int(u32, context.algorithm_version.major);
    try writer.int(u32, context.algorithm_version.minor);
    try writer.int(u32, context.algorithm_version.patch);
    try writer.raw(&state.key);
    const config = state.character.configuration;
    for ([_]f32{
        config.fixed_dt,             config.gravity,                  config.ground_acceleration,     config.air_acceleration,
        config.ground_deceleration,  config.maximum_run_speed,        config.jump_speed,              config.jump_release_speed,
        config.dash_speed,           config.dash_duration,            config.dash_reuse_delay,        config.coyote_duration,
        config.jump_buffer_duration, config.maximum_fall_speed,       config.collider_half_extents.x, config.collider_half_extents.y,
        config.ground_epsilon,       config.landing_impact_threshold, config.facing_threshold,
    }) |value| try writer.float(value);
    try vector(&writer, state.character.spawn_position);
    try facing(&writer, state.character.spawn_facing);
    try writer.int(u32, @intCast(state.world.colliders.len));
    for (state.world.colliders) |item| {
        try writer.int(u16, item.id);
        try vector(&writer, item.bounds.minimum);
        try vector(&writer, item.bounds.maximum);
        try writer.boolean(item.solid);
        try writer.boolean(item.ground_query_eligible);
    }
    try writer.raw(&anchor.persistent_id.?.bytes);
    try writer.int(u8, 1); // V1 world-persistent lifetime.
    try writer.boolean(anchor.effective_enabled);
    try writer.int(u8, switch (anchor.authored_enabled) {
        .inherit => 0,
        .enabled => 1,
        .disabled => 2,
    });
    try writer.int(u8, switch (anchor.visibility) {
        .inherit => 0,
        .visible => 1,
        .hidden => 2,
    });
    const local = anchor.local_transform;
    for ([_]f32{
        local.translation.x, local.translation.y, local.translation.z,
        local.rotation.x,    local.rotation.y,    local.rotation.z,
        local.rotation.w,    local.scale.x,       local.scale.y,
        local.scale.z,
    }) |value| try writer.float(value);
    const world = anchor.world_transform;
    const affine = world.affine;
    for ([_]f32{
        affine.x_axis.x,      affine.x_axis.y,      affine.x_axis.z,
        affine.y_axis.x,      affine.y_axis.y,      affine.y_axis.z,
        affine.z_axis.x,      affine.z_axis.y,      affine.z_axis.z,
        affine.translation.x, affine.translation.y, affine.translation.z,
    }) |value| try writer.float(value);
    try writer.int(i64, world.origin.x_mm);
    try writer.int(i64, world.origin.y_mm);
    try writer.int(i64, world.origin.z_mm);
    return replay.contributorDigest(.{ .id = 1, .version = 1 }, writer.slice());
}

fn vector(writer: *replay.Bytes, value: math.Vec2) !void {
    try writer.float(value.x);
    try writer.float(value.y);
}

fn facing(writer: *replay.Bytes, value: controller.Facing) !void {
    try writer.int(u8, switch (value) {
        .left => 0,
        .right => 1,
    });
}

fn optionalTick(writer: *replay.Bytes, value: ?u64) !void {
    try writer.boolean(value != null);
    if (value) |tick_number| try writer.int(u64, tick_number);
}

fn rejectAsset(_: ?*anyopaque, _: foundation.reference.AssetRef) anyerror!scene_core.runtime_asset.ResolvedAssetToken {
    return error.UnexpectedReplayAsset;
}
