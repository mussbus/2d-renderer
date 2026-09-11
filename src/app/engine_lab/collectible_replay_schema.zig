//! Application schema v1 for one fresh, bounded Engine Lab collectible run.
const std = @import("std");
pub const rr = @import("record_replay");
pub const lab = @import("engine_lab");
const f = @import("foundation");
const math = @import("math");
const fixed = @import("fixed_step");
const character = @import("character");
const proc = @import("procedural_motion");
const feet = @import("foot_planting");
const secondary = @import("attachment_secondary_motion");
const arm = @import("arm_ik");
const leg = @import("leg_ik");

pub const version: u16 = 1;
pub const record_count: u32 = 1469;
pub const envelope_size = 88;
pub const scratch_capacity = 16384;
pub const artifact_capacity = 344976;
pub const nominal_artifact_size = 88079;
pub const capacities = rr.Capacities{ .ticks = 2048, .causal_events = 1, .observed_events = 8192, .named_checkpoints = 10 };
pub const contributor_maximum = [12]usize{ 32, 231, 1382, 838, 4419, 1760, 48, 52, 319, 14786, 220, 26 };
pub const envelope_identity = id(0x454C0101);
pub const command_identity = id(0x454C0102);
pub const causal_identity = id(0x454C0103);
pub const observed_identity = id(0x454C0104);
pub const start_identity = id(0x454C0201);
pub const jump_identity = id(0x454C0301);
pub const dash_identity = id(0x454C0302);
pub const land_identity = id(0x454C0303);
pub const collect_identity = id(0x454C0304);
pub const scenario = f.identity.EntityId.parseCanonical("1326918e-056e-5844-8045-3001cf7b07cf") catch @compileError("scenario UUID");
pub const seed = lab.Seed.parseLowerHex(lab.default_seed) catch @compileError("scenario seed");
pub const metadata = rr.Metadata{
    .derivation = .{
        .root_seed = seed,
        .generator_id = f.identity.GeneratorId.parseCanonical("588a012e-bac2-526e-b0b6-d5a9a58be794") catch @compileError("generator UUID"),
        .generator_version = .{ .major = 1, .minor = 0, .patch = 0 },
        .algorithm_id = f.identity.AlgorithmId.parseCanonical("ba014e85-8d7b-5879-89df-7ef3d860f13b") catch @compileError("algorithm UUID"),
        .algorithm_version = .{ .major = 1, .minor = 0, .patch = 0 },
    },
    .initial_schema = envelope_identity,
    .command = command_identity,
    .causal = causal_identity,
    .observed = observed_identity,
};
pub const names = [10][]const u8{ "run_started", "collected_1", "collected_2", "collected_3", "collected_4", "collected_5", "collected_6", "challenge_complete", "effects_drained", "final_state" };
const causes = [_]rr.Channel{.{ .identity = start_identity, .maximum_size = 0, .validate_fn = empty }};
const outcomes = [_]rr.Channel{
    .{ .identity = jump_identity, .maximum_size = 1, .validate_fn = jump },
    .{ .identity = dash_identity, .maximum_size = 0, .validate_fn = empty },
    .{ .identity = land_identity, .maximum_size = 4, .validate_fn = land },
    .{ .identity = collect_identity, .maximum_size = 28, .validate_fn = collect },
};
pub const channels = rr.Channels{
    .command = .{ .identity = command_identity, .maximum_size = 5, .validate_fn = command },
    .causal = .{ .identity = causal_identity, .types = &causes },
    .observed = .{ .identity = observed_identity, .types = &outcomes },
};
pub fn id(number: u32) rr.Identity {
    return .{ .id = number, .version = version };
}
pub fn u32Count(number: usize) !u32 {
    return std.math.cast(u32, number) orelse error.CountOverflow;
}

/// Only instantiated for the audited initialized value tree. Resources are never values.
/// Semantic IDs retain their width; other enum tags are one byte (Bend is signed).
pub fn value(w: *rr.Bytes, v: anytype) anyerror!void {
    const T = @TypeOf(v);
    if (T == usize) return w.int(u32, try u32Count(v));
    switch (@typeInfo(T)) {
        .bool => try w.boolean(v),
        .int => |info| {
            if (info.bits % 8 != 0) @compileError("explicit byte-width integer required");
            try w.int(T, v);
        },
        .comptime_int => try w.int(u32, std.math.cast(u32, v) orelse return error.CountOverflow),
        .float => |info| {
            if (info.bits == 32) {
                try w.float(v);
            } else if (info.bits == 64) {
                if (!std.math.isFinite(v)) return error.NonCanonicalFloat;
                try w.int(u64, @bitCast(if (v == 0) @as(f64, 0) else v));
            } else @compileError("unsupported float");
        },
        .@"enum" => |info| {
            const I = info.tag_type;
            if (@typeInfo(I).int.signedness == .signed) {
                const tag = @intFromEnum(v);
                if (tag != -1 and tag != 1) return error.InvalidBend;
                try w.int(i8, @intCast(tag));
            } else if (@bitSizeOf(I) > 8) {
                try w.int(I, @intFromEnum(v));
            } else try w.int(u8, @intCast(@intFromEnum(v)));
        },
        .optional => {
            try w.boolean(v != null);
            if (v) |item| try value(w, item);
        },
        .array => {
            for (v) |item| try value(w, item);
        },
        .pointer => |info| {
            if (info.size == .slice) {
                try w.int(u32, try u32Count(v.len));
                for (v) |item| try value(w, item);
            } else if (info.size == .one and @typeInfo(info.child) == .array and @typeInfo(info.child).array.child == u8) {
                try value(w, @as([]const u8, v));
            } else @compileError("borrowed pointer is not canonical state");
        },
        .@"struct" => |info| {
            if (@hasField(T, "length") and @hasField(T, "bytes") and @hasDecl(T, "slice")) {
                try value(w, v.slice());
            } else {
                inline for (info.fields) |field| {
                    try value(w, @field(v, field.name));
                }
            }
        },
        .@"union" => |info| {
            const tag = std.meta.activeTag(v);
            // Union payload uses declared ordinal, independently of enum backing width.
            inline for (info.fields, 0..) |field, index| {
                if (tag == @field(info.tag_type.?, field.name)) {
                    try w.int(u8, @intCast(index));
                    try value(w, @field(v, field.name));
                }
            }
        },
        .void => {},
        else => @compileError("non-value replay field: " ++ @typeName(T)),
    }
}
pub fn encodeCommand(intent: lab.Intent) ![5]u8 {
    try intent.validate();
    if (intent.interact_pressed) return error.UnsupportedInput;
    var bytes: [5]u8 = undefined;
    var w = rr.Bytes.init(&bytes);
    try w.float(intent.move_axis);
    try w.int(u8, @as(u8, @intFromBool(intent.jump_pressed)) | (@as(u8, @intFromBool(intent.jump_held)) << 1) | (@as(u8, @intFromBool(intent.jump_released)) << 2) | (@as(u8, @intFromBool(intent.dash_pressed)) << 3));
    return bytes;
}
pub fn decodeCommand(bytes: []const u8) rr.Error!lab.Intent {
    try command(bytes);
    var r = rr.Reader{ .input = bytes };
    const axis = try r.float();
    const flags = try r.int(u8);
    return .{ .move_axis = axis, .jump_pressed = flags & 1 != 0, .jump_held = flags & 2 != 0, .jump_released = flags & 4 != 0, .dash_pressed = flags & 8 != 0, .interact_pressed = false };
}
fn command(bytes: []const u8) rr.Error!void {
    if (bytes.len != 5) return error.InvalidPayload;
    var r = rr.Reader{ .input = bytes };
    const axis = try r.float();
    if (axis < -1 or axis > 1 or (try r.int(u8)) & 0xf0 != 0) return error.InvalidPayload;
}
fn empty(bytes: []const u8) rr.Error!void {
    if (bytes.len != 0) return error.InvalidPayload;
}
fn jump(bytes: []const u8) rr.Error!void {
    if (bytes.len != 1 or bytes[0] > 3) return error.InvalidPayload;
}
fn land(bytes: []const u8) rr.Error!void {
    if (bytes.len != 4) return error.InvalidPayload;
    var r = rr.Reader{ .input = bytes };
    if (try r.float() < 0) return error.InvalidPayload;
}
fn collect(bytes: []const u8) rr.Error!void {
    if (bytes.len != 28) return error.InvalidPayload;
    var r = rr.Reader{ .input = bytes };
    if (try r.int(u64) != 1) return error.InvalidPayload;
    const spawn_id = try r.int(u16);
    const ordinal = try r.int(u8);
    if (ordinal < 1 or ordinal > 6) return error.InvalidPayload;
    const target = lab.collectibles_module.content.spawns[ordinal - 1];
    if (spawn_id != @intFromEnum(target.id)) return error.InvalidPayload;
    const tick = try r.int(u64);
    if (tick == 0 or tick > record_count) return error.InvalidPayload;
    if (try r.float() != target.position.x or try r.float() != target.position.y or try r.int(u8) > 1) return error.InvalidPayload;
}
pub fn envelope(content: rr.Digest, output: *[envelope_size]u8) !void {
    var w = rr.Bytes.init(output);
    try value(&w, scenario);
    try value(&w, content);
    try value(&w, seed);
    try w.int(u32, record_count);
    try w.int(u32, 1);
    try value(&w, lab.spawn);
    try w.int(u8, 1);
    try w.int(u8, 1);
    try w.int(u16, 0);
    try w.int(u32, fixed.simulation_hz);
    if (w.length != envelope_size) return error.EnvelopeSize;
}

/// Streaming field fold. Paths and scalar leaves, not native struct bytes, are authority.
const Fold = struct {
    digest: rr.Digest,
    count: u32 = 0,
    scratch: []u8,
    fn leaf(self: *Fold, section: u16, path: []const u8, index: u32, item: anytype) !void {
        var w = rr.Bytes.init(self.scratch);
        try value(&w, path);
        try value(&w, item);
        var n: [4]u8 = undefined;
        std.mem.writeInt(u32, &n, self.count, .little);
        var s: [2]u8 = undefined;
        std.mem.writeInt(u16, &s, section, .little);
        var i: [4]u8 = undefined;
        std.mem.writeInt(u32, &i, index, .little);
        self.digest = try f.canonical_data.hashDomainSeparated("engine_lab.replay.content.record.v1", &.{ &self.digest.bytes, &n, &s, &i, w.slice() });
        self.count = try std.math.add(u32, self.count, 1);
    }
    fn walk(self: *Fold, section: u16, path: []const u8, index: u32, item: anytype) anyerror!void {
        const T = @TypeOf(item);
        if (T == math.Vec2 or T == math.Transform2D or T == math.Mat3) return self.leaf(section, path, index, item);
        switch (@typeInfo(T)) {
            .@"struct" => |info| {
                if ((@hasField(T, "bytes") and info.fields.len == 1) or (@hasField(T, "length") and @hasDecl(T, "slice"))) return self.leaf(section, path, index, item);
                inline for (info.fields) |field| {
                    if (comptime !std.mem.eql(u8, field.name, "allocator") and !std.mem.endsWith(u8, field.name, "_token")) {
                        var buffer: [256]u8 = undefined;
                        try self.walk(section, try std.fmt.bufPrint(&buffer, "{s}.{s}", .{ path, field.name }), index, @field(item, field.name));
                    }
                }
            },
            .array => {
                try self.leaf(section, path, std.math.maxInt(u32), try u32Count(item.len));
                for (item, 0..) |entry, j| {
                    var buffer: [256]u8 = undefined;
                    try self.walk(section, try std.fmt.bufPrint(&buffer, "{s}.{d}", .{ path, j }), try u32Count(j), entry);
                }
            },
            .pointer => |info| {
                if (info.size == .slice) {
                    if (info.child == u8) return self.leaf(section, path, index, item);
                    try self.leaf(section, path, std.math.maxInt(u32), try u32Count(item.len));
                    for (item, 0..) |entry, j| {
                        var buffer: [256]u8 = undefined;
                        try self.walk(section, try std.fmt.bufPrint(&buffer, "{s}.{d}", .{ path, j }), try u32Count(j), entry);
                    }
                } else if (info.size == .one and @typeInfo(info.child) == .array and @typeInfo(info.child).array.child == u8) {
                    try self.leaf(section, path, index, @as([]const u8, item));
                } else @compileError("resource reached content fold: " ++ @typeName(T));
            },
            .optional => {
                try self.leaf(section, path, index, item != null);
                if (item) |v| try self.walk(section, path, index, v);
            },
            .@"union" => |info| {
                const tag = std.meta.activeTag(item);
                inline for (info.fields, 0..) |field, j| if (tag == @field(info.tag_type.?, field.name)) {
                    try self.leaf(section, path, index, @as(u8, @intCast(j)));
                    var buffer: [256]u8 = undefined;
                    try self.walk(section, try std.fmt.bufPrint(&buffer, "{s}.{s}", .{ path, field.name }), index, @field(item, field.name));
                };
            },
            else => try self.leaf(section, path, index, item),
        }
    }
    fn root(self: *Fold, section: u16, path: []const u8, item: anytype) !void {
        try self.walk(section, path, 0, item);
    }
    fn finish(self: *Fold) !rr.Digest {
        var n: [4]u8 = undefined;
        std.mem.writeInt(u32, &n, self.count, .little);
        return f.canonical_data.hashDomainSeparated("engine_lab.replay.content.end.v1", &.{ &self.digest.bytes, &n });
    }
};

pub fn contentIdentity(hub: *const lab.Hub, scratch: []u8) !rr.Digest {
    var fold = Fold{ .digest = try f.canonical_data.hashDomainSeparated("engine_lab.replay.content.v1", &.{}), .scratch = scratch };
    const actor = hub.actor.read();
    const controller = hub.actor.controllerSnapshot() orelse return error.MissingController;
    const definition = hub.actor.definitionView();
    const animations = hub.actor.animationDefinitionsView();
    if (definition.anatomy_definition != null or definition.component_graph_definition != null) return error.UnsupportedContent;
    try fold.root(1, "bootstrap", .{ .scenario = scenario, .seed = hub.seed, .record_count = record_count, .actor_id = actor.id, .spawn = controller.spawn_position, .facing = controller.spawn_facing, .construction = hub.construction, .reserved = @as(u16, 0), .simulation_hz = fixed.simulation_hz, .actor_layer = actor.actor_layer, .controller_configuration = controller.configuration, .movement = lab.layout.movement, .clock_configuration = hub.clock.configuration, .world_time = lab.world_time_module.initial_snapshot, .capacities = capacities, .contributors = @as(u32, 12), .canonical_scratch = @as(u32, scratch_capacity), .emitters = @as(u32, 6), .particles = @as(u32, 72), .artifact = @as(u32, artifact_capacity) });
    try fold.root(2, "world.colliders", hub.world.colliders);
    try fold.root(2, "world.layout_identity", lab.layout.identity(hub.construction));
    try fold.root(2, "world.profile_identity", lab.layout.profileIdentity(hub.construction));
    try fold.root(3, "installations", .{ .roots = hub.installations.roots, .anchors = hub.installations.anchors, .count = @as(u32, 8) });
    try fold.root(4, "skeleton_definition", definition.skeleton_definition);
    try fold.root(5, "visual_definition", definition.visual_definition);
    try fold.root(5, "attachments", definition.attachments);
    try fold.root(5, "attachment_semantic_indices", definition.attachment_semantic_indices);
    try fold.root(5, "anatomy_definition", false);
    try fold.root(5, "component_graph_definition", false);
    try fold.root(6, "animations.clips", animations.clips);
    try fold.root(6, "animations.machine", animations.machine);
    // Constants are explicitly enumerated in file order and lexical identifier order.
    try visualConstants(&fold);
    try fold.root(7, "movement_visual_constants.landing_spring_configuration", proc.landing_spring_configuration);
    try fold.root(7, "movement_visual_constants.secondary_spring_configuration", proc.secondary_spring_configuration);
    try fold.root(7, "movement_visual_constants.arm", try arm.Binding.initRightArm(&definition.skeleton_definition));
    try fold.root(7, "movement_visual_constants.left_leg", try leg.Binding.initLeft(&definition.skeleton_definition));
    try fold.root(7, "movement_visual_constants.right_leg", try leg.Binding.initRight(&definition.skeleton_definition));
    try fold.root(8, "stations", .{ .configurations = [2][3]@TypeOf(hub.stations[0].configurations[0]){ hub.stations[0].configurations, hub.stations[1].configurations }, .impulse = @as(f32, -2.5), .periods = [2]u64{ 480, 360 }, .history_interval = @as(u64, 4), .offset_domain = "engine_lab.hub.initial_offset.v2" });
    try fold.root(9, "calibration", .{ .mount = lab.calibration_module.mount, .profile = lab.calibration_module.profile });
    try fold.root(9, "world_time", .{ .configuration = lab.world_time_module.configuration, .initial = lab.world_time_module.initial_snapshot });
    const collection = lab.collectibles_module;
    try fold.root(10, "collection", .{ .spawns = collection.content.spawns, .reaction_ticks = collection.content.reaction_ticks, .definition = collection.content.reaction, .emitters = @as(u32, 6), .particles = @as(u32, 72), .namespace = try f.identity.NamespaceId.parseCanonical("c7cd2000-0771-5a66-b205-90e5e0121f06"), .domain = "engine_lab.collection.v1", .generator = try f.identity.GeneratorId.parseCanonical("24f9a3ce-5076-5520-949f-0a57a3cabd21"), .algorithm = try f.identity.AlgorithmId.parseCanonical("b8d2af34-fb7c-5390-a655-3fbd83f70142"), .generator_version = collection.e.generator_version, .algorithm_version = collection.e.algorithm_version, .algorithm_name = collection.e.algorithm_name, .emitter_namespace = try f.identity.NamespaceId.parseCanonical("8cd4a7b7-a2ab-528c-81cb-06e3703c9207"), .emitter_domain = "e.emitter.v1", .derivation_version = rr.derivation_version });
    const impact = lab.impact_module;
    try fold.root(11, "impact", .{ .projectile_namespace = try f.identity.NamespaceId.parseCanonical(impact.projectile_namespace), .bridge_namespace = try f.identity.NamespaceId.parseCanonical(impact.bridge_namespace), .source = hub.impact.source, .launcher = hub.impact.launcher, .wall_marker = hub.impact.wall_marker, .projectile_capacity = @as(u32, impact.projectile_capacity), .event_capacity = @as(u32, impact.event_capacity), .definition = impact.definition, .velocity = impact.velocity, .bridge = hub.impact.bridge.config, .palette = impact.palette, .color_context = hub.impact.color_context, .emitters = @as(u32, impact.emitter_capacity), .particles = @as(u32, impact.particle_capacity), .trails = @as(u32, impact.projectile_capacity) });
    return fold.finish();
}

fn visualConstants(fold: *Fold) !void {
    try fold.root(7, "movement_visual_constants.procedural_motion.landing_maximum_impulse", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.landing_maximum_impulse });
    try fold.root(7, "movement_visual_constants.procedural_motion.landing_maximum_mapped_impact", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.landing_maximum_mapped_impact });
    try fold.root(7, "movement_visual_constants.procedural_motion.landing_minimum_impulse", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.landing_minimum_impulse });
    try fold.root(7, "movement_visual_constants.procedural_motion.landing_minimum_trigger_impact", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.landing_minimum_trigger_impact });
    try fold.root(7, "movement_visual_constants.procedural_motion.landing_nominal_impact", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.landing_nominal_impact });
    try fold.root(7, "movement_visual_constants.procedural_motion.maximum_visual_root_offset_y", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.maximum_visual_root_offset_y });
    try fold.root(7, "movement_visual_constants.procedural_motion.minimum_visual_root_offset_y", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.minimum_visual_root_offset_y });
    try fold.root(7, "movement_visual_constants.procedural_motion.procedural_fixed_dt", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.procedural_fixed_dt });
    try fold.root(7, "movement_visual_constants.procedural_motion.secondary_target_radians_per_acceleration", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.secondary_target_radians_per_acceleration });
    try fold.root(7, "movement_visual_constants.procedural_motion.walk_blend_in_rate", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.walk_blend_in_rate });
    try fold.root(7, "movement_visual_constants.procedural_motion.walk_blend_out_rate", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.walk_blend_out_rate });
    try fold.root(7, "movement_visual_constants.procedural_motion.walk_full_amplitude_speed", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.walk_full_amplitude_speed });
    try fold.root(7, "movement_visual_constants.procedural_motion.walk_maximum_amplitude", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.walk_maximum_amplitude });
    try fold.root(7, "movement_visual_constants.procedural_motion.walk_minimum_active_speed", .{ .width = @as(u16, @bitSizeOf(f32)), .value = proc.walk_minimum_active_speed });
    try fold.root(7, "movement_visual_constants.foot_planting.fixed_dt", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.fixed_dt });
    try fold.root(7, "movement_visual_constants.foot_planting.full_plant_error_tolerance", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.full_plant_error_tolerance });
    try fold.root(7, "movement_visual_constants.foot_planting.ground_query_epsilon", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.ground_query_epsilon });
    try fold.root(7, "movement_visual_constants.foot_planting.ground_query_origin_lift", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.ground_query_origin_lift });
    try fold.root(7, "movement_visual_constants.foot_planting.left_stance_end_phase", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.left_stance_end_phase });
    try fold.root(7, "movement_visual_constants.foot_planting.maximum_ground_query_distance", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.maximum_ground_query_distance });
    try fold.root(7, "movement_visual_constants.foot_planting.plant_acquisition_duration", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.plant_acquisition_duration });
    try fold.root(7, "movement_visual_constants.foot_planting.plant_release_duration", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.plant_release_duration });
    try fold.root(7, "movement_visual_constants.foot_planting.reach_release_margin", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.reach_release_margin });
    try fold.root(7, "movement_visual_constants.foot_planting.right_stance_start_phase", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.right_stance_start_phase });
    try fold.root(7, "movement_visual_constants.foot_planting.sole_offset", .{ .width = @as(u16, @bitSizeOf(f32)), .value = feet.sole_offset });
    try fold.root(7, "movement_visual_constants.attachment_secondary_motion.fixed_dt", .{ .width = @as(u16, @bitSizeOf(f32)), .value = secondary.fixed_dt });
    try fold.root(7, "movement_visual_constants.attachment_secondary_motion.maximum_damping_step", .{ .width = @as(u16, @bitSizeOf(f32)), .value = secondary.maximum_damping_step });
    try fold.root(7, "movement_visual_constants.attachment_secondary_motion.maximum_dynamic_points", .{ .width = @as(u16, 32), .value = secondary.maximum_dynamic_points });
    try fold.root(7, "movement_visual_constants.attachment_secondary_motion.maximum_stiffness_step", .{ .width = @as(u16, @bitSizeOf(f32)), .value = secondary.maximum_stiffness_step });
    try fold.root(7, "movement_visual_constants.attachment_secondary_motion.minimum_rest_offset_length", .{ .width = @as(u16, @bitSizeOf(f32)), .value = secondary.minimum_rest_offset_length });
}
