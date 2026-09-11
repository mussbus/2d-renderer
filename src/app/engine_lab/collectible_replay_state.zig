//! Canonical contributors for the admitted lifecycle. All borrows end on return.
const std = @import("std");
pub const schema = @import("engine_lab_replay_schema");
const rr = schema.rr;
const lab = schema.lab;
const character = @import("character");
const controller = @import("character_controller");
const procedural = @import("procedural_motion");
const feet = @import("foot_planting");
const presentation = @import("presentation_view");
const animator = @import("animator");
const f = @import("foundation");
const effects = lab.collectibles_module.e;
const v = schema.value;

comptime {
    if (@sizeOf(character.AnimationPlaybackSnapshot) > 128 or @alignOf(character.AnimationPlaybackSnapshot) > 8) @compileError("animation snapshot exceeds reviewed reservation");
}
/// Allocated once by the adapter. No tick trace or automatic particle/pose arrays.
pub const Scratch = struct {
    canonical: [schema.scratch_capacity]u8 = undefined,
    particles: [72]effects.ParticleSnapshot = undefined,
    emitters: [6]effects.EmitterSnapshot = undefined,
    contributors: [12]rr.Contributor = undefined,
    lengths: [12]usize = @splat(0),
    maximum_lengths: [12]usize = @splat(0),
    controller_copy: controller.CharacterController = undefined,
    playback: character.AnimationPlaybackSnapshot = undefined,
    procedural_copy: procedural.State = undefined,
    feet_copy: feet.State = undefined,
    presentation_copy: presentation.Runtime = undefined,
    observed: [4]rr.Event = undefined,
    causal: [1]rr.Event = undefined,
    names: [4]rr.CheckpointName = undefined,
    envelope: [88]u8 = undefined,
};

pub fn capture(hub: *const lab.Hub, content: rr.Digest, scratch: *Scratch) !rr.Digest {
    for (0..12) |index| {
        const bytes = try contributor(hub, content, scratch, index);
        scratch.lengths[index] = bytes.len;
        scratch.maximum_lengths[index] = @max(scratch.maximum_lengths[index], bytes.len);
        if (bytes.len > schema.contributor_maximum[index]) return error.ContributorBudgetExceeded;
        const identity = schema.id(0x454C1001 + @as(u32, @intCast(index)));
        scratch.contributors[index] = .{ .identity = identity, .digest = try rr.contributorDigest(identity, bytes) };
    }
    return rr.stateDigest(&scratch.contributors);
}

/// Useful independently for contributor audits; returned bytes borrow Scratch.
pub fn contributor(h: *const lab.Hub, content: rr.Digest, s: *Scratch, index: usize) ![]const u8 {
    var w = rr.Bytes.init(&s.canonical);
    const challenge = if (h.challenge) |*value| value else return error.MissingChallenge;
    switch (index) {
        0 => try v(&w, content),
        1 => {
            const read = h.actor.read();
            try v(&w, read.id);
            try v(&w, read.world_position);
            try v(&w, read.facing);
            try v(&w, read.actor_layer);
            try v(&w, read.simulation_tick);
            try v(&w, read.grounded);
            s.controller_copy = h.actor.controllerSnapshot() orelse return error.MissingController;
            try w.boolean(true);
            try v(&w, s.controller_copy);
            try v(&w, h.pending);
            try v(&w, h.last_physical);
        },
        2 => {
            s.playback = h.actor.animationPlaybackSnapshot();
            try animationValues(s.playback, h.actor.animationDefinitionsView().machine.states.len);
            try v(&w, s.playback);
            const events = h.actor.emittedAnimationEvents();
            if (events.len > 64) return error.AnimationEventCapacity;
            try v(&w, events);
        },
        3 => {
            s.procedural_copy = h.actor.proceduralSnapshot();
            s.feet_copy = h.actor.footPlantingSnapshot();
            try footHistory(s.feet_copy.left, h.tick);
            try footHistory(s.feet_copy.right, h.tick);
            try v(&w, s.procedural_copy);
            try v(&w, s.feet_copy);
        },
        4 => {
            try inactiveActor(h);
            const human = h.actor.humanoidView();
            const pose = &human.local_and_world_pose;
            const appearance = &human.appearance_runtime;
            // Transform2D: translation, rotation_radians, scale = 20 bytes.
            try v(&w, human.character_to_world);
            try v(&w, pose.evaluated);
            try v(&w, pose.local_transforms);
            try v(&w, pose.world_transforms);
            try v(&w, appearance.attachment_point_world);
            try v(&w, appearance.module_joint_local);
            try v(&w, appearance.module_joint_world);
            try v(&w, appearance.module_socket_world);
            try v(&w, appearance.visual_states);
            try v(&w, appearance.visual_world);
            s.presentation_copy = h.actor.presentationRuntimeSnapshot();
            try v(&w, s.presentation_copy);
            // Private inactive arm/passive state is reconstructed only under exclusive lifecycle.
            try w.boolean(false);
            try w.boolean(false);
            try w.boolean(false);
            try w.int(u32, try schema.u32Count(h.actor.activeOverrideCount()));
            try w.int(u32, h.actor.interactionOwnerId());
            try w.boolean(h.actor.hasEquipment());
            try w.boolean(h.actor.resolvedPropertiesSnapshot() != null);
            try w.boolean(true);
        },
        5 => for (&h.stations) |*station| {
            if (station.history_count > 64 or station.history_next >= 64 or station.history_count != @min(station.updates / 4, 64) or station.history_next != (station.updates / 4) % 64) return error.HistoryBoundary;
            try v(&w, station.configurations);
            try v(&w, station.springs);
            try v(&w, station.previous_offsets);
            try v(&w, station.updates);
            try v(&w, station.history_count);
            try v(&w, station.history_next);
            for (station.history[0..station.history_count]) |slot| try v(&w, slot);
        },
        6 => try v(&w, h.calibration),
        7 => {
            const time = h.world_time.snapshot();
            try time.validate();
            try v(&w, time);
        },
        8 => {
            try challengeValues(challenge, h.tick);
            try v(&w, challenge.phase);
            try v(&w, challenge.run);
            try v(&w, challenge.progress);
            try v(&w, challenge.born_tick);
            try v(&w, challenge.reaction_remaining);
            try v(&w, challenge.pending_start);
            try v(&w, challenge.last);
            for (challenge.observations[0..challenge.progress]) |event| try v(&w, event);
            try v(&w, challenge.effect_ids);
        },
        9 => try collectionEffects(h, s, &w),
        10 => {
            try inactiveImpact(h);
            const impact = &h.impact;
            try v(&w, impact.projectiles.tick());
            try v(&w, impact.projectiles.count());
            try v(&w, impact.projectiles.events().len);
            try w.int(u64, 1);
            try w.int(u64, 0);
            try v(&w, impact.effects.tick());
            try v(&w, impact.effects.emitterCount());
            try v(&w, impact.effects.particleCount());
            try v(&w, impact.effects.metrics());
            try v(&w, impact.bridge.count);
            try v(&w, impact.bridge.last_sequence);
            // All seven actual fields, including truncated_segments: C11 is 220 bytes.
            try v(&w, impact.bridge.metrics);
            try v(&w, impact.pending_activation);
            try v(&w, impact.next_shot_ordinal);
            const o = &impact.observations;
            try v(&w, o.launches);
            try v(&w, o.busy);
            try v(&w, o.out_of_range);
            try v(&w, o.contacts);
            try v(&w, o.executing_tick);
            try w.boolean(o.last_launch != null);
            try w.boolean(o.last_contact != null);
            try v(&w, o.batch_count);
            try v(&w, o.events_digest);
        },
        11 => {
            try v(&w, h.tick);
            try v(&w, h.visited);
            try v(&w, h.jumps);
            try v(&w, h.landings);
            try v(&w, h.wall_contacts);
            try v(&w, h.navigation_count);
        },
        else => return error.InvalidContributor,
    }
    return w.slice();
}

pub fn animationValues(snapshot: character.AnimationPlaybackSnapshot, state_count: usize) !void {
    if (snapshot.current_state_index >= state_count) return error.AnimationState;
    try playbackValues(snapshot.playback);
    if (snapshot.active_transition) |transition| {
        if (transition.source_state_index >= state_count or transition.destination_state_index >= state_count or !std.math.isFinite(transition.elapsed) or !std.math.isFinite(transition.duration) or transition.elapsed < 0 or transition.duration <= 0 or transition.elapsed > transition.duration) return error.AnimationTransition;
        try playbackValues(transition.source_playback);
        try playbackValues(transition.destination_playback);
    }
}
fn playbackValues(playback: animator.PlaybackState) !void {
    if (!std.math.isFinite(playback.previous_time) or !std.math.isFinite(playback.current_time) or !std.math.isFinite(playback.playback_speed) or playback.previous_time < 0 or playback.current_time < 0 or playback.playback_speed <= 0) return error.AnimationPlayback;
}
fn footHistory(foot: feet.FootRuntime, tick: u64) !void {
    if (foot.plant_weight < 0 or foot.plant_weight > 1 or !foot.metrics.latest_acquired_lifecycle.isChronological()) return error.FootHistory;
    if (foot.pending_contact_tick) |t| if (t > tick) return error.FootHistory;
    inline for (@typeInfo(@TypeOf(foot.metrics)).@"struct".fields) |field| {
        if (field.type == ?u64) {
            if (@field(foot.metrics, field.name)) |t| if (t > tick) return error.FootHistory;
        }
    }
    inline for (@typeInfo(feet.LifecycleRecord).@"struct".fields) |field| {
        if (@field(foot.metrics.latest_acquired_lifecycle, field.name)) |t| if (t > tick) return error.FootHistory;
    }
}
pub fn inactiveActor(h: *const lab.Hub) !void {
    const definition = h.actor.definitionView();
    const human = h.actor.humanoidView();
    const presentation_state = h.actor.presentationRuntimeSnapshot();
    if (definition.anatomy_definition != null or definition.component_graph_definition != null or human.anatomy_runtime != null or h.actor.anatomyRuntimeSnapshot() != null or h.actor.hasEquipment() or h.actor.equipmentView() != null or h.actor.resolvedPropertiesSnapshot() != null or h.actor.activeOverrideCount() != 0 or h.actor.interactionOwnerId() != 0 or h.actor.isInteractionLocked() or h.actor.rightHandIkMetrics() != null or presentation_state.debug_override != .automatic or presentation_state.interaction_owner != 0) return error.UnsupportedActorFeature;
    const pose = &human.local_and_world_pose;
    const appearance = &human.appearance_runtime;
    if (!pose.evaluated or pose.local_transforms.len != 16 or pose.world_transforms.len != 16 or appearance.attachment_point_world.len != 16 or appearance.module_joint_local.len != 0 or appearance.module_joint_world.len != 0 or appearance.module_socket_world.len != 0 or appearance.visual_states.len != 15 or appearance.visual_world.len != 15) return error.ActorShape;
    for (definition.visual_definition.visuals) |visual| if (visual.secondary_motion != null) return error.UnsupportedSecondary;
    for (appearance.visual_states) |visual| if (!std.meta.eql(visual.secondary, @as(@TypeOf(visual.secondary), .{}))) return error.UnsupportedSecondary;
    const metrics = h.actor.hotPathMetrics();
    inline for (@typeInfo(@TypeOf(metrics)).@"struct".fields) |field| if (@field(metrics, field.name) != 0) return error.ActorAllocation;
}
pub fn challengeValues(c: *const lab.collectibles_module.Challenge, tick: u64) !void {
    if (c.progress > 6 or c.born_tick > tick or c.reaction_remaining > 24 or c.pending_start or (c.phase == .reaction) != (c.reaction_remaining > 0)) return error.ChallengeState;
    if ((tick == 0 and (c.run != 0 or c.phase != .idle or c.progress != 0)) or (tick > 0 and (c.run != 1 or c.phase == .idle))) return error.ChallengeLineage;
    var previous: u64 = 0;
    for (c.observations[0..c.progress], 0..) |observation, j| {
        const target = lab.collectibles_module.content.spawns[j];
        if (observation.run != 1 or observation.ordinal != j + 1 or observation.spawn_id != target.id or !std.meta.eql(observation.position, target.position) or observation.tick <= previous or observation.tick > tick) return error.CollectionObservation;
        previous = observation.tick;
    }
    if (c.last) |event| if (c.progress == 0 or event.tick != tick or !std.meta.eql(event, c.observations[c.progress - 1])) return error.CollectionObservation;
    for (c.effect_ids, 0..) |maybe, j| {
        if (j < c.progress) {
            const actual = maybe orelse return error.CollectionIdentity;
            if (!actual.eql(try lab.collectibles_module.effectId(1, @intCast(j + 1)))) return error.CollectionIdentity;
        } else if (maybe != null) return error.CollectionIdentity;
    }
}
fn emitterLess(_: void, a: effects.EmitterSnapshot, b: effects.EmitterSnapshot) bool {
    return a.effect_id.byteOrder(b.effect_id) == .lt;
}
fn particleLess(_: void, a: effects.ParticleSnapshot, b: effects.ParticleSnapshot) bool {
    return if (a.effect_id.eql(b.effect_id)) a.ordinal < b.ordinal else a.effect_id.byteOrder(b.effect_id) == .lt;
}
fn collectionEffects(h: *const lab.Hub, s: *Scratch, w: *rr.Bytes) !void {
    const c = if (h.challenge) |*value| value else return error.MissingChallenge;
    try challengeValues(c, h.tick);
    if (!h.seed.eql(schema.seed)) return error.SeedMismatch;
    const count = c.effects.emitterCount();
    const particle_count = c.effects.particleCount();
    if (count > 6 or particle_count > 72) return error.CollectionCapacity;
    var found: usize = 0;
    for (c.effect_ids, 0..) |maybe, j| if (maybe) |effect_id| {
        const age = h.tick - c.observations[j].tick;
        if (c.effects.emitter(effect_id)) |emitter| {
            if (found >= s.emitters.len or age >= 120 or !emitter.effect_id.eql(effect_id) or !std.meta.eql(emitter.definition, lab.collectibles_module.content.reaction) or !std.meta.eql(emitter.position, c.observations[j].position) or emitter.emitted != 12 or emitter.remainder != 0 or emitter.age_ticks != @min(age, 1) or emitter.emitting != (age == 0)) return error.EmitterLifecycle;
            const namespace = try f.identity.NamespaceId.parseCanonical("8cd4a7b7-a2ab-528c-81cb-06e3703c9207");
            const expected = try f.identity.uuidV5Fields(effects.Id, namespace, &.{ "e.emitter.v1", &effect_id.bytes });
            if (!expected.eql(emitter.emitter_id)) return error.EmitterIdentity;
            s.emitters[found] = emitter;
            found += 1;
        } else if (age < 120) return error.MissingEmitter;
    };
    if (found != count or particle_count != count * 12) return error.OrphanEffect;
    std.mem.sort(effects.EmitterSnapshot, s.emitters[0..found], {}, emitterLess);
    _ = try c.effects.copyParticles(&s.particles);
    const particles = s.particles[0..particle_count];
    std.mem.sort(effects.ParticleSnapshot, particles, {}, particleLess);
    for (particles, 0..) |particle, j| {
        const emitter = s.emitters[j / 12];
        if (!particle.effect_id.eql(emitter.effect_id) or !particle.emitter_id.eql(emitter.emitter_id) or particle.ordinal != j % 12 or !std.meta.eql(particle.definition, emitter.definition) or particle.age_ticks >= 120) return error.ParticleIdentity;
        var birth: ?u64 = null;
        for (c.effect_ids, 0..) |maybe, k| if (maybe) |id| {
            if (id.eql(particle.effect_id)) birth = c.observations[k].tick;
        };
        if (birth == null or particle.age_ticks != h.tick - birth.?) return error.ParticleAge;
    }
    const metrics = c.effects.metrics();
    if (metrics.dropped_particles != 0 or metrics.rejected_emitters != 0 or metrics.peak_particles > 72 or metrics.peak_emitters > 6) return error.EffectMetrics;
    try v(w, h.seed);
    try v(w, c.effects.tick());
    try v(w, count);
    try v(w, particle_count);
    for (s.emitters[0..count]) |emitter| try v(w, emitter);
    for (particles) |particle| try v(w, particle);
    try v(w, metrics);
}
pub fn inactiveImpact(h: *const lab.Hub) !void {
    const impact = &h.impact;
    const o = &impact.observations;
    if (impact.projectiles.count() != 0 or impact.projectiles.events().len != 0 or impact.effects.emitterCount() != 0 or impact.effects.particleCount() != 0 or !std.meta.eql(impact.effects.metrics(), @as(effects.Metrics, .{})) or impact.bridge.count != 0 or impact.bridge.last_sequence != null or !std.meta.eql(impact.bridge.metrics, @as(@TypeOf(impact.bridge.metrics), .{})) or impact.pending_activation or impact.next_shot_ordinal != 0 or o.launches != 0 or o.busy != 0 or o.out_of_range != 0 or o.contacts != 0 or o.last_launch != null or o.last_contact != null or o.batch_count != 0 or !std.mem.allEqual(u8, &o.events_digest, 0)) return error.UnsupportedImpact;
}

pub fn observations(h: *const lab.Hub, output: *[4]rr.Event) ![]const rr.Event {
    if (h.tick == 0) return error.InvalidTick;
    var count: usize = 0;
    const p = h.last_physical;
    var payload: [28]u8 = undefined;
    var w = rr.Bytes.init(&payload);
    if (p.jump_accepted) {
        try v(&w, p.jump_source orelse return error.MissingJumpSource);
        output[count] = try rr.Event.init(h.tick - 1, @intCast(count), schema.jump_identity, w.slice());
        count += 1;
    }
    if (p.dash_started) {
        output[count] = try rr.Event.init(h.tick - 1, @intCast(count), schema.dash_identity, &.{});
        count += 1;
    }
    if (p.landed) {
        w.length = 0;
        try w.float(p.landing_impact_speed);
        output[count] = try rr.Event.init(h.tick - 1, @intCast(count), schema.land_identity, w.slice());
        count += 1;
    }
    if (h.challenge.?.last) |event| {
        w.length = 0;
        try v(&w, event);
        output[count] = try rr.Event.init(h.tick - 1, @intCast(count), schema.collect_identity, w.slice());
        count += 1;
    }
    return output[0..count];
}
