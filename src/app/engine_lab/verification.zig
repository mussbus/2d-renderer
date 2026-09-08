const std = @import("std");
const hub_module = @import("engine_lab");

pub const checkpoint_ticks = [_]u64{ 0, 480, 960, 1440 };
pub const Checkpoint = struct { tick: u64, digest: hub_module.Digest };
pub const Result = struct { checkpoints: [checkpoint_ticks.len]Checkpoint, jumps: u32, landings: u32, wall_contacts: u32 };

/// Bounded EL1 verification fixture only. No recording, storage or replay API.
/// Edges lie on 120-tick boundaries shared by both permitted frame schedules.
pub fn inputAt(tick: u64) hub_module.Intent {
    return .{
        .move_axis = if (tick < 720) 1 else -1,
        .jump_pressed = tick == 240 or tick == 960,
        .jump_held = (tick >= 240 and tick < 360) or (tick >= 960 and tick < 1080),
        .jump_released = tick == 360 or tick == 1080,
        .interact_pressed = false,
    };
}

fn run(hub: *hub_module.Hub, mixed: bool) !Result {
    var result: Result = .{ .checkpoints = undefined, .jumps = 0, .landings = 0, .wall_contacts = 0 };
    result.checkpoints[0] = .{ .tick = 0, .digest = try hub.fingerprint() };
    var next: usize = 1;
    var frame: usize = 0;
    const schedule = [_]f64{ 1.0 / 240.0, 3.0 / 240.0, 1.0 / 120.0 };
    while (hub.tick < checkpoint_ticks[checkpoint_ticks.len - 1]) : (frame += 1) {
        try hub.advanceFrame(if (mixed) schedule[frame % schedule.len] else 1.0 / 60.0, inputAt(hub.tick));
        if (next < checkpoint_ticks.len and hub.tick >= checkpoint_ticks[next]) {
            if (hub.tick != checkpoint_ticks[next]) return error.VerificationScheduleCrossedCheckpoint;
            result.checkpoints[next] = .{ .tick = hub.tick, .digest = try hub.fingerprint() };
            next += 1;
        }
    }
    if (next != checkpoint_ticks.len or !hub.visited[0] or !hub.visited[1]) return error.HubTravelProofIncomplete;
    if (hub.jumps < 2 or hub.landings < 2 or hub.wall_contacts == 0) return error.HubPhysicsProofIncomplete;
    for (hub.stations) |station| if (station.updates != hub.tick) return error.StationDidNotCoexist;
    result.jumps = hub.jumps;
    result.landings = hub.landings;
    result.wall_contacts = hub.wall_contacts;
    return result;
}

pub fn verify(allocator: std.mem.Allocator, seed: hub_module.Seed) !Result {
    var hub = try hub_module.Hub.init(allocator, seed);
    defer hub.deinit() catch |err| hub_module.cleanupFailure(err);
    const first = try run(&hub, false);
    try hub.reset();
    const second = try run(&hub, true);
    for (first.checkpoints, second.checkpoints) |left, right| {
        if (left.tick != right.tick or !left.digest.eql(right.digest)) return error.HubCheckpointMismatch;
    }
    return second;
}

pub const impact_ticks = [_]u64{ 0, 120, 312, 313, 456, 480, 792, 936 };
pub const ImpactResult = struct { checkpoints: [impact_ticks.len]Checkpoint, launch_tick: u64, contact_tick: u64, contact_sequence: u64 };

/// A separate bounded integration fixture. Compare equivalent executed semantic
/// tick streams only: schedules split at command/checkpoint boundaries. No claim
/// is made for clock discard/clamping or differing raw device sampling.
fn runImpact(hub: *hub_module.Hub, mixed: bool) !ImpactResult {
    const impact = hub_module.impact_module;
    try hub.navigate(.springs);
    var result: ImpactResult = .{ .checkpoints = undefined, .launch_tick = 0, .contact_tick = 0, .contact_sequence = 0 };
    result.checkpoints[0] = .{ .tick = 0, .digest = try hub.impact.fingerprint() };
    const schedule = [_]u64{ 1, 3, 2 };
    var frame: usize = 0;
    var next: usize = 1;
    while (next < impact_ticks.len) : (frame += 1) {
        if (hub.tick == 0 or hub.tick == 480) hub.impact.pending_activation = true;
        if (hub.tick == 120) try hub.navigate(.hierarchy);
        if (hub.tick == 456) try hub.navigate(.springs);
        const steps = @min(impact_ticks[next] - hub.tick, if (mixed) schedule[frame % schedule.len] else 4);
        try hub.advanceFrame(@as(f64, @floatFromInt(steps)) / 240.0, hub_module.neutral_intent);
        if (hub.tick != hub.impact.projectiles.tick() or hub.tick != hub.impact.effects.tick()) return error.ImpactTickMismatch;
        if (mixed) {
            // Repeated extraction/diagnostics and camera changes cannot consume
            // randomness or alter subsequent projectiles, particles or emissions.
            const before = try hub.impact.fingerprint();
            var storage: [impact.particle_capacity]impact.e.RenderInstance = undefined;
            _ = try hub.impact.effects.extract(&storage, 0);
            _ = try hub.impact.effects.extract(&storage, 1);
            try hub.camera.setCenter(.{ .x = 0, .y = 2.1 });
            if (!before.eql(try hub.impact.fingerprint())) return error.ImpactObservationMutation;
        }
        if (hub.tick == impact_ticks[next]) {
            result.checkpoints[next] = .{ .tick = hub.tick, .digest = try hub.impact.fingerprint() };
            next += 1;
        }
    }
    if (hub.impact.observations.launches != 2 or hub.impact.observations.contacts != 2 or
        hub.impact.bridge.metrics.impacts != 2 or hub.impact.bridge.metrics.dropped_effects != 0 or
        hub.impact.effects.metrics().dropped_particles != 0 or hub.impact.projectiles.count() != 0 or
        hub.impact.effects.particleCount() != 0 or hub.clock.lifetime_discarded_time != 0) return error.ImpactFixtureIncomplete;
    result.launch_tick = hub.impact.observations.last_launch.?.tick;
    result.contact_tick = hub.impact.observations.last_contact.?.tick;
    result.contact_sequence = hub.impact.observations.last_contact.?.sequence;
    if (result.launch_tick != 480 or result.contact_tick != 792 or result.contact_sequence != 627) return error.ImpactEventBoundaryMismatch;
    return result;
}

pub fn verifyImpact(allocator: std.mem.Allocator, seed: hub_module.Seed) !ImpactResult {
    var hub = try hub_module.Hub.init(allocator, seed);
    defer hub.deinit() catch |err| hub_module.cleanupFailure(err);
    const first = try runImpact(&hub, false);
    try hub.reset();
    const second = try runImpact(&hub, true);
    for (first.checkpoints, second.checkpoints) |left, right| if (left.tick != right.tick or !left.digest.eql(right.digest)) return error.ImpactCheckpointMismatch;
    return second;
}
