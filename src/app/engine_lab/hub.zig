const std = @import("std");
const foundation = @import("foundation");
const scene_core = @import("scene_core");
const fixed_step = @import("fixed_step");
const spring = @import("spring");
const math = @import("math");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character = @import("character");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const camera2d = @import("camera2d");
pub const impact_module = @import("impact.zig");
pub const calibration_module = @import("calibration.zig");
pub const world_time_module = @import("world_time.zig");

pub const Intent = @import("character_intent").CharacterIntent;
pub const Seed = foundation.determinism.Seed128;
pub const Digest = foundation.canonical_data.Sha256Digest;
pub const default_seed = "0123456789abcdef0123456789abcdef";
pub const neutral_intent = Intent{ .move_axis = 0, .jump_pressed = false, .jump_held = false, .jump_released = false, .interact_pressed = false };
pub const mass_count = 3;
pub const station_count = 2;
pub const station_x = [station_count]f32{ -5.8, 5.8 };
// Destinations stand beside each installation, keeping its diagnostics visible.
pub const destination_x = [station_count]f32{ -4.5, 4.5 };
pub const camera_center_y: f32 = 2.1;
pub const spawn = math.Vec2{ .x = destination_x[0], .y = 1.05 };
pub const Destination = enum { hierarchy, springs };
pub const layout = @import("layout.zig");
pub const collider_inputs = layout.legacy_colliders;

pub const Anchor = struct { id: foundation.identity.EntityId, world: math.Vec2 };

/// Generic static installation authority. Moving actor state belongs to the
/// supported specialized CharacterInstance, not an unpublished F root.
pub const Installations = struct {
    scene: scene_core.runtime_scene.RuntimeScene,
    roots: [station_count]Anchor,
    anchors: [station_count][mass_count]Anchor,

    pub fn init(allocator: std.mem.Allocator) !Installations {
        var scene = try scene_core.runtime_scene.RuntimeScene.init(allocator, .{
            .registry = .{ .initial_entity_capacity = 8, .hard_entity_capacity = 8, .initial_mapping_capacity = 8, .hard_mapping_capacity = 8 },
            .initial_level_capacity = 1,
            .hard_level_capacity = 1,
            .max_snapshot_leases = 1,
        });
        errdefer scene.deinit() catch |err| cleanupFailure(err);
        const ids = [_][]const u8{
            "019a1800-1000-7000-8000-000000000001", "019a1800-1000-7000-8000-000000000002",
            "019a1800-1000-7000-8000-000000000003", "019a1800-1000-7000-8000-000000000004",
            "019a1800-1000-7000-8000-000000000005", "019a1800-1000-7000-8000-000000000006",
            "019a1800-1000-7000-8000-000000000007", "019a1800-1000-7000-8000-000000000008",
        };
        var handles: [8]foundation.identity.EntityHandle = undefined;
        var persistent: [8]foundation.identity.EntityId = undefined;
        for (ids, 0..) |text, index| {
            const local = index % 4;
            const station = index / 4;
            persistent[index] = try foundation.identity.EntityId.parseCanonical(text);
            handles[index] = try scene.spawnTemporary(.{ .authority = .physics_gameplay }, .{
                .owner = .{ .physics_gameplay = null },
                .parent = if (local == 0) null else handles[station * 4],
                .local_transform = .{
                    .translation = .{ .x = if (local == 0) station_x[station] else (@as(f32, @floatFromInt(local)) - 2) * 0.8, .y = if (local == 0) 3.0 else -0.4, .z = 0 },
                    .rotation = .identity,
                    .scale = .one,
                },
                .enabled = .enabled,
                .resolver = .{ .context = null, .resolve_fn = rejectAsset },
            });
            try scene.promoteTemporary(.{ .authority = .physics_gameplay }, handles[index], persistent[index]);
        }
        var snapshot = try scene.acquireSnapshot(.{ .tick = 0, .fixed_delta_seconds = @floatCast(fixed_step.fixed_dt_seconds), .interpolation_alpha = 0 });
        defer snapshot.deinit();
        const view = snapshot.view();
        if (view.entityCount() != 8) return error.InstallationEntityCount;
        var observed: [8]Anchor = undefined;
        for (handles, 0..) |handle, index| {
            const entity = try view.get(handle);
            const resolved = view.resolve(persistent[index]) orelse return error.AnchorIdentityMissing;
            if (!resolved.eql(handle) or !entity.effective_enabled) return error.AnchorIdentityMismatch;
            try entity.world_transform.affine.validate();
            const position = entity.world_transform.affine.translation;
            observed[index] = .{ .id = persistent[index], .world = .{ .x = position.x, .y = position.y } };
        }
        return .{ .scene = scene, .roots = .{ observed[0], observed[4] }, .anchors = .{ observed[1..4].*, observed[5..8].* } };
    }

    pub fn deinit(self: *Installations) !void {
        try self.scene.deinit();
        self.* = undefined;
    }
};

fn rejectAsset(_: ?*anyopaque, _: foundation.reference.AssetRef) anyerror!scene_core.runtime_asset.ResolvedAssetToken {
    return error.UnexpectedInstallationAssetReference;
}
pub fn cleanupFailure(err: anyerror) noreturn {
    std.debug.panic("Engine Lab lifetime cleanup: {s}", .{@errorName(err)});
}

/// Both concrete installations exist for the entire hub lifetime. This bounded
/// spring/history value has no independent session lifecycle or selection API.
pub const Station = struct {
    configurations: [mass_count]spring.Configuration,
    springs: [mass_count]spring.State,
    previous_offsets: [mass_count]f32,
    updates: u64 = 0,
    history: [64][mass_count]f32 = @splat(@splat(0)),
    history_count: usize = 0,
    history_next: usize = 0,

    fn init(seed: Seed, anchors: [mass_count]Anchor, index: usize) !Station {
        const damping = [station_count][mass_count]f32{ .{ 1.2, 3, 7 }, .{ 0.5, 4, 12 } };
        var result: Station = .{ .configurations = undefined, .springs = undefined, .previous_offsets = undefined };
        for (0..mass_count) |mass| {
            result.configurations[mass] = .{ .stiffness = 24, .damping = damping[index][mass], .maximum_displacement = 0.65, .maximum_velocity = 6 };
            const key = try foundation.canonical_data.hashDomainSeparated("engine_lab.hub.initial_offset.v2", &.{ &seed.bytes, &anchors[mass].id.bytes });
            const offset = 0.25 + @as(f32, @floatFromInt(key.bytes[0])) * (0.35 / 255.0);
            result.springs[mass] = try spring.State.init(result.configurations[mass], @floatCast(fixed_step.fixed_dt_seconds), offset, 0, 0);
            result.previous_offsets[mass] = offset;
        }
        return result;
    }

    fn step(self: *Station, tick: u64, index: usize) !void {
        const period: u64 = if (index == 0) 480 else 360;
        for (&self.springs, self.configurations, 0..) |*state, config, mass| {
            self.previous_offsets[mass] = state.offset;
            if (tick % period == 0) try state.applyVelocityImpulse(-2.5, config);
            try state.step(config, @floatCast(fixed_step.fixed_dt_seconds));
        }
        self.updates = try std.math.add(u64, self.updates, 1);
        if (tick % 4 == 0) {
            for (self.springs, 0..) |state, mass| self.history[self.history_next][mass] = state.offset;
            self.history_next = (self.history_next + 1) % self.history.len;
            self.history_count = @min(self.history_count + 1, self.history.len);
        }
    }
};

/// Application view scales relative to the authored traversal presentation.
pub const Zoom = enum {
    current,
    out_2x,
    out_4x,

    pub fn factor(self: Zoom) f32 {
        return switch (self) {
            .current => 1,
            .out_2x => 2,
            .out_4x => 4,
        };
    }
};

/// One world lifetime, one controlled production actor, both live installations.
/// Renderer/platform ownership stays outside this headless composition.
pub const Hub = struct {
    allocator: std.mem.Allocator,
    seed: Seed,
    construction: layout.Construction,
    last_physical: @import("character_controller").StepResult = .{ .simulation_tick = 0 },
    installations: Installations,
    definition: humanoid.HumanoidDefinition,
    animations: authored.Definitions,
    world: collision_world.CollisionWorld,
    actor: character.CharacterInstance,
    stations: [station_count]Station,
    impact: impact_module.Installation,
    calibration: calibration_module.Binding,
    world_time: world_time_module.WorldTime,
    camera: camera2d.Camera2D,
    zoom: Zoom = .current,
    follower: camera2d.HorizontalFollower,
    clock: fixed_step.Clock,
    pending: Intent = neutral_intent,
    tick: u64 = 0,
    visited: [station_count]bool = .{ true, false },
    jumps: u32 = 0,
    landings: u32 = 0,
    wall_contacts: u32 = 0,
    navigation_count: u32 = 0,
    diagnostics_enabled: bool = false,

    /// Compatibility entry for the accepted fixtures. Interactive launch explicitly
    /// selects initExpanded; both constructions share all ownership and tick work.
    pub fn init(allocator: std.mem.Allocator, seed: Seed) !Hub {
        return initLegacy(allocator, seed);
    }
    pub fn initLegacy(allocator: std.mem.Allocator, seed: Seed) !Hub {
        return initConstruction(allocator, seed, .legacy);
    }
    pub fn initExpanded(allocator: std.mem.Allocator, seed: Seed) !Hub {
        return initConstruction(allocator, seed, .expanded);
    }
    fn initConstruction(allocator: std.mem.Allocator, seed: Seed, construction: layout.Construction) !Hub {
        try layout.movement.validate(.{});
        var installations = try Installations.init(allocator);
        errdefer installations.deinit() catch |err| cleanupFailure(err);
        var definition = try humanoid.HumanoidDefinition.init(allocator, null);
        errdefer definition.deinit();
        var animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer animations.deinit();
        var world = try collision_world.CollisionWorld.init(allocator, layout.colliders(construction), null);
        errdefer world.deinit();
        var actor = try character.CharacterInstance.initControlled(allocator, try character.entityIdFromRaw(1), &definition, &animations, &world, .{}, spawn, .right, 0, null);
        errdefer actor.deinit();
        var stations: [station_count]Station = undefined;
        for (&stations, 0..) |*station, index| station.* = try Station.init(seed, installations.anchors[index], index);
        var camera = camera2d.Camera2D.initDefault();
        try camera.setCenter(.{ .x = spawn.x, .y = if (construction == .expanded) spawn.y + vertical_target_offset else camera_center_y });
        var impact = try impact_module.Installation.init(allocator, seed, installations.roots[1].id, installations.roots[1].world, &world);
        errdefer impact.deinit();
        const controller = actor.controllerSnapshot() orelse return error.HubActorHasNoController;
        const calibration = calibration_module.Binding.init(controller.state.position) catch |err| {
            std.log.err("Engine Lab calibration initialization tick 0: {s}", .{@errorName(err)});
            return err;
        };
        const world_time = world_time_module.init() catch |err| {
            std.log.err("Engine Lab World Time initialization tick 0: {s}", .{@errorName(err)});
            return err;
        };
        return .{ .construction = construction, .world_time = world_time, .calibration = calibration, .allocator = allocator, .seed = seed, .installations = installations, .definition = definition, .animations = animations, .world = world, .actor = actor, .stations = stations, .impact = impact, .camera = camera, .follower = try camera2d.HorizontalFollower.init(0.9), .clock = try fixed_step.Clock.init(.{}) };
    }

    pub fn deinit(self: *Hub) !void {
        try self.installations.deinit();
        self.impact.deinit();
        self.actor.deinit();
        self.world.deinit();
        self.animations.deinit();
        self.definition.deinit();
        self.* = undefined;
    }

    pub fn reset(self: *Hub) !void {
        var candidate = try initConstruction(self.allocator, self.seed, self.construction);
        errdefer candidate.deinit() catch |err| cleanupFailure(err);
        try self.deinit();
        self.* = candidate;
    }

    /// Developer respawn of the same actor, with clean controller/foot state.
    /// No allocation, hub replacement, station reset or fixed-clock reset.
    pub fn navigate(self: *Hub, destination: Destination) !void {
        const index: usize = switch (destination) {
            .hierarchy => 0,
            .springs => 1,
        };
        try self.actor.resetControlled(&self.world);
        try self.actor.stageControlledTransform(.{ .x = destination_x[index], .y = spawn.y }, .right);
        const controller = self.actor.controllerSnapshot() orelse return error.HubActorHasNoController;
        self.calibration.reanchor(controller.state.position) catch |err| {
            std.log.err("Engine Lab calibration navigation at hub tick {d}: {s}", .{ self.tick, @errorName(err) });
            return err;
        };
        try self.camera.setCenter(.{ .x = destination_x[index], .y = if (self.construction == .expanded) spawn.y + vertical_target_offset else camera_center_y });
        if (self.zoom != .current) try self.updateCamera();
        self.pending = neutral_intent;
        self.last_physical = .{ .simulation_tick = 0 };
        self.impact.pending_activation = false;
        self.visited[index] = true;
        self.navigation_count = try std.math.add(u32, self.navigation_count, 1);
    }

    pub fn advanceFrame(self: *Hub, seconds: f64, intent: Intent) !void {
        // A late World Time failure leaves a fatal partial hub tick. Reject even
        // zero-step frames before touching input/clock; only whole-hub reset heals it.
        if (self.world_time.snapshot().simulation_ticks != self.tick) return error.WorldTimeTickMismatch;
        try intent.validate();
        self.pending.move_axis = intent.move_axis;
        self.pending.jump_held = intent.jump_held;
        self.pending.jump_pressed = self.pending.jump_pressed or intent.jump_pressed;
        self.pending.jump_released = self.pending.jump_released or intent.jump_released;
        self.pending.dash_pressed = self.pending.dash_pressed or intent.dash_pressed;
        const frame = try self.clock.beginFrame(seconds);
        for (0..frame.substeps) |_| {
            const consumed = self.pending;
            self.pending.jump_pressed = false;
            self.pending.jump_released = false;
            self.pending.dash_pressed = false;
            try self.fixedUpdate(consumed);
        }
    }

    fn fixedUpdate(self: *Hub, intent: Intent) !void {
        if (self.tick != self.impact.projectiles.tick() or self.tick != self.impact.effects.tick()) return error.ImpactTickMismatch;
        const next_tick = try std.math.add(u64, self.tick, 1);
        const observed_actor = self.actor.controllerSnapshot() orelse return error.HubActorHasNoController;
        const launch = try self.impact.consumeActivation(observed_actor.state.position);
        const physical = if (self.construction == .expanded)
            try self.actor.stepControllerWithProperties(&self.world, intent, layout.movement)
        else
            try self.actor.stepController(&self.world, intent);
        self.last_physical = physical;
        try self.actor.selectControllerAnimation(physical);
        const controller = self.actor.controllerSnapshot() orelse return error.HubActorHasNoController;
        try self.actor.advanceVisualTickWithFootPlanting(&self.world, .{
            .horizontal_velocity = controller.state.velocity.x,
            .vertical_velocity = controller.state.velocity.y,
            .physically_grounded = controller.state.grounded,
            .landing_event = if (physical.landed) .{ .simulation_tick = controller.state.simulation_tick, .impact_speed = physical.landing_impact_speed } else null,
        });
        self.tick = next_tick;
        if (physical.jump_accepted) self.jumps = try std.math.add(u32, self.jumps, 1);
        if (physical.landed) self.landings = try std.math.add(u32, self.landings, 1);
        if (physical.wall_collision) self.wall_contacts = try std.math.add(u32, self.wall_contacts, 1);
        for (&self.stations, 0..) |*station, index| {
            try station.step(self.tick, index);
            if (@abs(controller.state.position.x - station_x[index]) <= 1.4) self.visited[index] = true;
        }
        try self.updateCamera();
        self.calibration.step(controller.state.position) catch |err| {
            std.log.err("Engine Lab calibration executing hub tick {d}: {s}; partial hub tick cannot continue", .{ next_tick, @errorName(err) });
            return err;
        };
        self.impact.step(launch, &self.world, next_tick) catch |err| {
            std.log.err("Engine Lab projectile-impact executing hub tick {d}: {s}; partial hub tick cannot continue", .{ next_tick, @errorName(err) });
            return err;
        };
        self.world_time.advanceSimulationTicks(1) catch |err| {
            std.log.err("Engine Lab World Time advanceSimulationTicks executing hub tick {d}: {s}; partial hub tick cannot continue", .{ next_tick, @errorName(err) });
            return err;
        };
    }

    pub const vertical_dead_zone: f32 = 0.15;
    pub const vertical_target_offset: f32 = 0.95;

    /// Camera composition only: completed root, no time source or physics writes.
    pub fn updateCamera(self: *Hub) !void {
        const position = self.actor.worldPosition();
        try self.follower.update(&self.camera, position.x);
        if (self.construction == .legacy) {
            try self.camera.setCenter(.{ .x = std.math.clamp(self.camera.center.x, -5, 5), .y = self.camera.center.y });
            return;
        }
        const half = try self.camera.worldHalfExtents();
        const target_y = position.y + vertical_target_offset;
        const y = std.math.clamp(self.camera.center.y, target_y - vertical_dead_zone, target_y + vertical_dead_zone);
        // Very wide viewports center the complete room rather than invert clamps.
        const x = if (half.x >= 16) -8 else std.math.clamp(self.camera.center.x, -24 + half.x, 8 - half.x);
        // Keep the original screen margin below the floor at each scale. A view
        // taller than the room centers it instead of applying inverted limits.
        const lower_y = (spawn.y + vertical_target_offset) * self.zoom.factor();
        const center_y = if (half.y >= 7) 7 else std.math.clamp(y, lower_y, 14 - half.y);
        try self.camera.setCenter(.{ .x = x, .y = center_y });
    }

    /// Presentation-only state. Whole-hub reset reconstructs the current view.
    pub fn cycleZoom(self: *Hub) !void {
        if (self.construction == .legacy) return;
        self.zoom = switch (self.zoom) {
            .current => .out_2x,
            .out_2x => .out_4x,
            .out_4x => .current,
        };
        try self.setViewport(self.camera.viewport_width, self.camera.viewport_height);
    }

    pub fn setViewport(self: *Hub, width: u32, height: u32) !void {
        try self.camera.setViewport(width, height);
        try self.camera.setZoomScale(1 / self.zoom.factor());
        if (self.construction == .expanded) try self.updateCamera();
    }

    pub fn renderedActorPosition(self: *const Hub) !math.Vec2 {
        const controller = self.actor.controllerSnapshot() orelse return error.HubActorHasNoController;
        return if (self.clock.paused) controller.state.position else controller.interpolatedPosition(self.clock.last_frame.interpolation_alpha);
    }

    /// Traversal observations supplement, never redefine, the EL1 v2 digest.
    /// Explicit fields only; excludes frame grouping residue and render-only camera.
    /// This diagnostic is neither a save format nor whole-hub replay authority.
    pub fn traversalFingerprint(self: *const Hub) !Digest {
        var bytes: [4096]u8 = undefined;
        var writer = foundation.canonical_data.Writer.init(&bytes);
        const state = (self.actor.controllerSnapshot() orelse return error.HubActorHasNoController).state;
        try writer.raw("[");
        try writer.jsonString(layout.identity(self.construction));
        try writer.byte(',');
        try writer.jsonString(layout.profileIdentity(self.construction));
        for ([_]Digest{ try self.fingerprint(), try self.calibration.fingerprint(), try self.impact.fingerprint() }) |digest| {
            try writer.byte(',');
            try writer.jsonString(&digest.formatLowerHex());
        }
        var time_buffer: [world_time_module.diagnostic_capacity]u8 = undefined;
        try writer.byte(',');
        try writer.jsonString(try world_time_module.diagnostic(self.world_time.snapshot(), &time_buffer));
        try writer.byte(',');
        try vector(&writer, state.previous_position);
        try writer.byte(',');
        try vector(&writer, state.ground_normal);
        for ([_]f32{ state.previous_vertical_velocity, state.last_landing_impact_speed, self.pending.move_axis }) |value| {
            try writer.byte(',');
            try writer.f32Value(value);
        }
        for ([_]u64{ state.air_jumps_used, state.dash_ticks_remaining, state.dash_cooldown_ticks_remaining }) |value| {
            try writer.byte(',');
            try writer.u64Value(value);
        }
        try writer.byte(',');
        try writer.jsonString(@tagName(state.dash_direction));
        for ([_]bool{ state.previous_grounded, state.jump_was_consumed, self.pending.jump_pressed, self.pending.jump_held, self.pending.jump_released, self.pending.dash_pressed, self.pending.interact_pressed, self.clock.paused, self.impact.pending_activation }) |value| {
            try writer.byte(',');
            try writer.boolean(value);
        }
        try writer.byte(']');
        return foundation.canonical_data.hashDomainSeparated("engine_lab.traversal.observations.v1", &.{writer.bytes()});
    }

    /// Selected logical state only. Camera, UI, history, pointers, handles and
    /// frame residue are excluded. This is not a restore/replay serialization.
    pub fn fingerprint(self: *const Hub) !Digest {
        var bytes: [8192]u8 = undefined;
        var writer = foundation.canonical_data.Writer.init(&bytes);
        const controller = self.actor.controllerSnapshot() orelse return error.HubActorHasNoController;
        const state = controller.state;
        try writer.raw("{\"actor\":{\"animation\":");
        try writer.jsonString(@tagName(self.actor.animationState()));
        try writer.raw(",\"animation_time\":");
        try writer.f32Value(self.actor.animationTime());
        try writer.raw(",\"coyote_ticks\":");
        try writer.u64Value(state.coyote_ticks_remaining);
        try writer.raw(",\"facing\":");
        try writer.jsonString(@tagName(state.facing));
        try writer.raw(",\"grounded\":");
        try writer.boolean(state.grounded);
        try writer.raw(",\"jump_buffer_ticks\":");
        try writer.u64Value(state.jump_buffer_ticks_remaining);
        try writer.raw(",\"last_jump_tick\":");
        try optionalTick(&writer, state.last_jump_tick);
        try writer.raw(",\"last_landing_tick\":");
        try optionalTick(&writer, state.last_landing_tick);
        try writer.raw(",\"position\":");
        try vector(&writer, state.position);
        try writer.raw(",\"support\":");
        if (state.supporting_collider) |id| try writer.u64Value(id) else try writer.raw("null");
        try writer.raw(",\"tick\":");
        try writer.u64Value(state.simulation_tick);
        try writer.raw(",\"velocity\":");
        try vector(&writer, state.velocity);
        try writer.raw("},\"colliders\":[");
        for (layout.colliders(self.construction), 0..) |item, index| {
            if (index != 0) try writer.byte(',');
            try writer.raw("{\"id\":");
            try writer.u64Value(item.id);
            try writer.raw(",\"maximum\":");
            try vector(&writer, item.bounds.maximum);
            try writer.raw(",\"minimum\":");
            try vector(&writer, item.bounds.minimum);
            try writer.byte('}');
        }
        try writer.raw("],\"fixed_hz\":");
        try writer.u64Value(fixed_step.simulation_hz);
        try writer.raw(",\"jumps\":");
        try writer.u64Value(self.jumps);
        try writer.raw(",\"landings\":");
        try writer.u64Value(self.landings);
        try writer.raw(",\"schema\":2,\"seed\":");
        try writer.jsonString(&self.seed.formatLowerHex());
        try writer.raw(",\"stations\":[");
        for (self.stations, self.installations.roots, self.installations.anchors, 0..) |station, root, anchors, index| {
            if (index != 0) try writer.byte(',');
            try writer.raw("{\"anchors\":[");
            for (anchors, station.configurations, station.springs, 0..) |anchor, config, state_value, mass| {
                if (mass != 0) try writer.byte(',');
                try writer.raw("{\"damping\":");
                try writer.f32Value(config.damping);
                try writer.raw(",\"id\":");
                try writer.uuidValue(anchor.id.bytes);
                try writer.raw(",\"offset\":");
                try writer.f32Value(state_value.offset);
                try writer.raw(",\"position\":");
                try vector(&writer, anchor.world);
                try writer.raw(",\"stiffness\":");
                try writer.f32Value(config.stiffness);
                try writer.raw(",\"target\":");
                try writer.f32Value(state_value.target_offset);
                try writer.raw(",\"velocity\":");
                try writer.f32Value(state_value.velocity);
                try writer.byte('}');
            }
            try writer.raw("],\"root_id\":");
            try writer.uuidValue(root.id.bytes);
            try writer.raw(",\"root_position\":");
            try vector(&writer, root.world);
            try writer.raw(",\"updates\":");
            try writer.u64Value(station.updates);
            try writer.raw(",\"visited\":");
            try writer.boolean(self.visited[index]);
            try writer.byte('}');
        }
        try writer.raw("],\"tick\":");
        try writer.u64Value(self.tick);
        try writer.raw(",\"wall_contacts\":");
        try writer.u64Value(self.wall_contacts);
        try writer.byte('}');
        return foundation.canonical_data.hashDomainSeparated("engine_lab.hub.state.v2", &.{writer.bytes()});
    }
};

fn vector(writer: *foundation.canonical_data.Writer, value: math.Vec2) !void {
    try writer.byte('[');
    try writer.f32Value(value.x);
    try writer.byte(',');
    try writer.f32Value(value.y);
    try writer.byte(']');
}
fn optionalTick(writer: *foundation.canonical_data.Writer, tick: ?u64) !void {
    if (tick) |value| try writer.u64Value(value) else try writer.raw("null");
}
