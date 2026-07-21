const std = @import("std");
const math = @import("math");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const state_machine = @import("state_machine");
const sprite = @import("sprite_batch");
const fault_injection = @import("fault_injection");

pub const character_count: usize = 2;
pub const phase_count: usize = 9;
pub const frames_per_phase: u32 = 80;
pub const required_frames: u32 = phase_count * frames_per_phase;

pub const Phase = enum(u8) {
    a_behind_b,
    b_behind_a,
    a_hand_over_b_hand,
    b_hand_over_a_hand,
    a_forearm_over_b_torso,
    restore_defaults,
    mirror_a,
    mirror_b,
    stable_final,
};

pub const IndependenceEvidence = struct {
    captured: bool = false,
    a_animation_time: f32 = 0,
    b_animation_time: f32 = 0,
    a_right_hand: math.Vec2 = math.Vec2.zero,
    b_right_hand: math.Vec2 = math.Vec2.zero,
    a_procedural_offset: f32 = 0,
    b_procedural_offset: f32 = 0,
};

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    shared_animations: authored.Definitions,
    id_allocator: character.EntityIdAllocator,
    registry: character.EntityRegistry,
    character_a: character.CharacterInstance,
    character_b: character.CharacterInstance,
    current_phase: ?Phase = null,
    phase_logged: [phase_count]bool = [_]bool{false} ** phase_count,
    independence: IndependenceEvidence = .{},
    total_visual_ticks: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, second_character_injector: ?fault_injection.Injector) !Scene {
        var definition = try humanoid.HumanoidDefinition.init(allocator, null);
        errdefer definition.deinit();
        var shared_animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer shared_animations.deinit();

        var id_allocator = character.EntityIdAllocator{};
        const a_id = try id_allocator.allocate();
        const b_id = try id_allocator.allocate();
        var registry = character.EntityRegistry{};
        try registry.insert(a_id);

        var character_a = try character.CharacterInstance.init(
            allocator,
            a_id,
            &definition,
            &shared_animations,
            .{ .x = -0.72, .y = 1.05 },
            .right,
            0,
            null,
        );
        errdefer character_a.deinit();
        var character_b = try character.CharacterInstance.init(
            allocator,
            b_id,
            &definition,
            &shared_animations,
            .{ .x = 0.72, .y = 1.05 },
            .left,
            1,
            second_character_injector,
        );
        errdefer character_b.deinit();
        try registry.insert(b_id);

        try character_a.enterAnimationState(.walk);
        return .{
            .definition = definition,
            .shared_animations = shared_animations,
            .id_allocator = id_allocator,
            .registry = registry,
            .character_a = character_a,
            .character_b = character_b,
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.character_b.deinit();
        scene.character_a.deinit();
        scene.shared_animations.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene, frame: u32) !void {
        const phase = phaseForFrame(frame);
        if (scene.current_phase == null or scene.current_phase.? != phase) try scene.applyPhase(phase);

        if (frame == 200) try scene.character_b.enterAnimationState(.walk);
        if (frame == 360) try scene.character_a.enterAnimationState(.idle);
        if (frame == 520) try scene.character_b.enterAnimationState(.idle);
        if (frame == 640) {
            if (scene.character_a.animationState() != .idle) try scene.character_a.enterAnimationState(.idle);
            if (scene.character_b.animationState() != .idle) try scene.character_b.enterAnimationState(.idle);
        }

        for (0..4) |_| {
            const a_velocity: f32 = if (scene.character_a.animationState() == .walk) 2.4 else 0;
            const b_velocity: f32 = if (scene.character_b.animationState() == .walk) -1.6 else 0;
            try scene.character_a.advanceVisualTick(.{ .horizontal_velocity = a_velocity });
            try scene.character_b.advanceVisualTick(.{ .horizontal_velocity = b_velocity });
            scene.total_visual_ticks += 2;
        }

        if (!scene.independence.captured and
            @abs(scene.character_a.procedural.walk_bounce_offset) > 0.0001 and
            @abs(scene.character_b.procedural.walk_bounce_offset) <= 0.000001 and
            @abs(scene.character_a.animationTime() - scene.character_b.animationTime()) > 0.0001)
        {
            scene.independence = .{
                .captured = true,
                .a_animation_time = scene.character_a.animationTime(),
                .b_animation_time = scene.character_b.animationTime(),
                .a_right_hand = try scene.character_a.socketPosition(.right_hand),
                .b_right_hand = try scene.character_b.socketPosition(.right_hand),
                .a_procedural_offset = scene.character_a.procedural.walk_bounce_offset,
                .b_procedural_offset = scene.character_b.procedural.walk_bounce_offset,
            };
        }
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        const instances = [_]*character.CharacterInstance{ &scene.character_b, &scene.character_a };
        const submitted = try character.submitGlobally(&instances, batch);
        try scene.logAndValidateCurrentPhase();
        return submitted;
    }

    pub fn validateComplete(scene: Scene) !void {
        for (scene.phase_logged) |logged| {
            if (!logged) return error.MultiCharacterPhaseMissing;
        }
        if (!scene.independence.captured) return error.CharacterIndependenceEvidenceMissing;
        if (@abs(scene.independence.a_animation_time - scene.independence.b_animation_time) <= 0.0001) {
            return error.AnimationTimesNotIndependent;
        }
        if (scene.independence.a_right_hand.approxEqAbs(scene.independence.b_right_hand, 0.0001)) {
            return error.PosesNotIndependent;
        }
        if (@abs(scene.independence.a_procedural_offset) <= 0.0001 or @abs(scene.independence.b_procedural_offset) > 0.000001) {
            return error.ProceduralStatesNotIndependent;
        }
        if (scene.character_a.overrides.activeCount() != 0 or scene.character_b.overrides.activeCount() != 0) {
            return error.LayerOverridesNotRestored;
        }
        if (scene.character_a.facing != .right or scene.character_b.facing != .left) return error.FacingNotRestored;
        if (scene.character_a.actor_layer != 0 or scene.character_b.actor_layer != 1) return error.ActorLayersNotRestored;
        if (scene.current_phase != .stable_final) return error.FinalPhaseNotReached;
    }

    fn applyPhase(scene: *Scene, phase: Phase) !void {
        scene.character_a.clearOverrides();
        scene.character_b.clearOverrides();
        try scene.character_a.setFacing(.right);
        try scene.character_b.setFacing(.left);
        switch (phase) {
            .a_behind_b, .restore_defaults, .stable_final => {
                try scene.character_a.setActorLayer(0);
                try scene.character_b.setActorLayer(1);
            },
            .b_behind_a => {
                try scene.character_a.setActorLayer(1);
                try scene.character_b.setActorLayer(0);
            },
            .a_hand_over_b_hand => {
                try scene.character_a.setActorLayer(0);
                try scene.character_b.setActorLayer(1);
                _ = try scene.character_a.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 });
            },
            .b_hand_over_a_hand => {
                try scene.character_a.setActorLayer(1);
                try scene.character_b.setActorLayer(0);
                _ = try scene.character_b.applySemanticOverride(.right_hand, .{ .interaction_layer = 1 });
            },
            .a_forearm_over_b_torso => {
                try scene.character_a.setActorLayer(0);
                try scene.character_b.setActorLayer(1);
                _ = try scene.character_a.applySemanticOverride(.right_forearm, .{ .interaction_layer = 1 });
            },
            .mirror_a => {
                try scene.character_a.setActorLayer(0);
                try scene.character_b.setActorLayer(1);
                try scene.character_a.setFacing(.left);
            },
            .mirror_b => {
                try scene.character_a.setActorLayer(0);
                try scene.character_b.setActorLayer(1);
                try scene.character_a.setFacing(.left);
                try scene.character_b.setFacing(.right);
            },
        }
        scene.current_phase = phase;
        std.log.info("multi-character phase transition phase={d} name={s}", .{ @intFromEnum(phase), @tagName(phase) });
    }

    fn logAndValidateCurrentPhase(scene: *Scene) !void {
        const phase = scene.current_phase orelse return error.MultiCharacterPhaseMissing;
        const phase_index = @intFromEnum(phase);
        if (scene.phase_logged[phase_index]) return;

        const a_torso = try scene.character_a.submittedKey(.torso);
        const a_forearm = try scene.character_a.submittedKey(.right_forearm);
        const a_hand = try scene.character_a.submittedKey(.right_hand);
        const b_torso = try scene.character_b.submittedKey(.torso);
        const b_forearm = try scene.character_b.submittedKey(.right_forearm);
        const b_hand = try scene.character_b.submittedKey(.right_hand);
        logResolvedKey("A.torso", a_torso);
        logResolvedKey("A.right_forearm", a_forearm);
        logResolvedKey("A.right_hand", a_hand);
        logResolvedKey("B.torso", b_torso);
        logResolvedKey("B.right_forearm", b_forearm);
        logResolvedKey("B.right_hand", b_hand);

        switch (phase) {
            .a_behind_b, .restore_defaults, .stable_final, .mirror_a, .mirror_b => {
                try expectBelow(a_torso, b_torso);
                std.log.info("multi-character comparison A.torso < B.torso result=true", .{});
            },
            .b_behind_a => {
                try expectBelow(b_torso, a_torso);
                std.log.info("multi-character comparison B.torso < A.torso result=true", .{});
            },
            .a_hand_over_b_hand => {
                try expectBelow(a_torso, b_torso);
                try expectBelow(b_hand, a_hand);
                std.log.info("multi-character comparison A.torso < B.torso result=true A.right_hand > B.right_hand result=true", .{});
            },
            .b_hand_over_a_hand => {
                try expectBelow(b_torso, a_torso);
                try expectBelow(a_hand, b_hand);
                std.log.info("multi-character comparison B.torso < A.torso result=true B.right_hand > A.right_hand result=true", .{});
            },
            .a_forearm_over_b_torso => {
                try expectBelow(a_torso, b_torso);
                try expectBelow(b_torso, a_forearm);
                std.log.info("multi-character comparison A.torso < B.torso result=true A.right_forearm > B.torso result=true", .{});
            },
        }
        if (phase == .mirror_a or phase == .mirror_b or phase == .stable_final) {
            const a_socket = try scene.character_a.socketPosition(.right_hand);
            const b_socket = try scene.character_b.socketPosition(.right_hand);
            std.log.info("multi-character facing proof phase={s} A={s} A.right_hand=({d:.5},{d:.5}) B={s} B.right_hand=({d:.5},{d:.5})", .{
                @tagName(phase),
                @tagName(scene.character_a.facing),
                a_socket.x,
                a_socket.y,
                @tagName(scene.character_b.facing),
                b_socket.x,
                b_socket.y,
            });
        }
        scene.phase_logged[phase_index] = true;
    }
};

pub fn phaseForFrame(frame: u32) Phase {
    const raw = @min(frame / frames_per_phase, phase_count - 1);
    return @enumFromInt(raw);
}

fn expectBelow(lower: sprite.DrawOrderKey, upper: sprite.DrawOrderKey) !void {
    if (!sprite.keyLessThan(lower, upper)) return error.UnexpectedResolvedOrder;
}

fn logResolvedKey(label: []const u8, key: sprite.DrawOrderKey) void {
    std.log.info("multi-character resolved key {s}: scene={d} interaction={d} actor={d} body={d} submission={d}", .{
        label,
        key.scene_layer,
        key.interaction_layer,
        key.actor_layer,
        key.body_part_layer,
        key.submission_index,
    });
}

comptime {
    if (@intFromEnum(Phase.stable_final) + 1 != phase_count) @compileError("multi-character phase count mismatch");
    if (required_frames != 720) @compileError("multi-character demonstration must remain exactly 720 frames");
    if (@intFromEnum(state_machine.StateId.walk) == @intFromEnum(state_machine.StateId.idle)) @compileError("animation states must remain distinct");
}
