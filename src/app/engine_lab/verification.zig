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
