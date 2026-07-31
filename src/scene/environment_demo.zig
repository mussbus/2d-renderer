const std = @import("std");
const math = @import("math");
const input = @import("input");
const character_controller = @import("character_controller");
const foundation_playground = @import("foundation_playground");
const camera2d = @import("camera2d");
const character = @import("character");
const humanoid = @import("humanoid");
const presentation_view = @import("presentation_view");
const environment_art = @import("environment_art");
const environment_theme = @import("environment_theme");
const wardrobe_catalog = @import("wardrobe_catalog");
const wardrobe_demo = @import("wardrobe_demo");
const render_queue = @import("render_queue");
const visual_geometry = @import("visual_geometry");

pub const required_frames: u32 = 720;
pub const fixed_ticks_per_frame: u32 = 4;
pub const character_count: u32 = 2;
pub const mesh_definition_count: usize = wardrobe_demo.mesh_definition_count;
pub const configured_texture_page_count: u32 =
    environment_theme.environment_renderer_offset + environment_art.texture_page_count;
pub const interaction_position = math.Vec2{ .x = -2.275, .y = foundation_playground.player_spawn.y };
pub const presentation_camera_center_y: f32 = camera2d.default_center.y + 0.72;

pub const Evidence = struct {
    violet_observed: bool = false,
    debug_observed: bool = false,
    switch_count: u32 = 0,
    switch_preserved_authoritative_state: bool = true,
    collision_fingerprint: u64 = 0,
    surface_fingerprint: u64 = 0,
    camera_minimum_x: f32 = 0,
    camera_maximum_x: f32 = 0,
    parallax_observed: bool = false,
    front_idle_observed: bool = false,
    side_locomotion_observed: bool = false,
    jump_observed: bool = false,
    landing_observed: bool = false,
    raised_platform_landing_observed: bool = false,
    maximum_airborne_x: f32 = foundation_playground.player_spawn.x,
    last_landing_position: math.Vec2 = foundation_playground.player_spawn,
    last_landing_collider: ?u16 = null,
    raised_platform_landing_frame: ?u32 = null,
    reset_observed: bool = false,
    resize_observed: bool = false,
    decorative_ledges_without_edges: bool = false,
    detailed_debug_observed: bool = false,
};

pub const GameplaySnapshot = struct {
    female_controller: character_controller.State,
    male_world_position: math.Vec2,
    male_facing: humanoid.Facing,
    female_world_position: math.Vec2,
    female_facing: humanoid.Facing,
    male_view: presentation_view.View,
    female_view: presentation_view.View,
    male_view_override: presentation_view.DebugOverride,
    female_view_override: presentation_view.DebugOverride,
    male_interaction_owner: u32,
    female_interaction_owner: u32,
    male_loadout_fingerprint: u64,
    female_loadout_fingerprint: u64,
    current_preset: wardrobe_catalog.OutfitPresetId,
    custom_active: bool,
    paused: bool,
    simulation_tick: u64,
    frame_index: u32,
    clock_accumulator: f64,
    pending_edges: u8,
    camera_center: math.Vec2,
    collision_fingerprint: u64,
    surface_fingerprint: u64,
};

pub const Scene = struct {
    production: wardrobe_demo.Scene,
    environment_art_definition: environment_art.Definition,
    environment: environment_theme.Presentation,
    camera: camera2d.Camera2D,
    camera_follower: camera2d.HorizontalFollower,
    detailed_debug_enabled: bool = false,
    evidence: Evidence,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        return initWithOptionalArmRootContract(allocator, .standard);
    }

    pub fn initWithOptionalArmRootContract(
        allocator: std.mem.Allocator,
        root_contract: @import("modular_body_demo").OptionalArmRootContract,
    ) !Scene {
        const world_inputs = foundation_playground.worldColliderInputs();
        var production = try wardrobe_demo.Scene.initWithConfiguration(allocator, .{
            .collider_inputs = &world_inputs,
            .male_spawn = foundation_playground.partner_spawn,
            .female_spawn = foundation_playground.player_spawn,
            .male_facing = .right,
            .female_facing = .right,
            .optional_arm_root_contract = root_contract,
        });
        errdefer production.deinit();
        try production.enableVisualQualityAcceptance();
        try production.selectPreset(try production.catalog.presetId("wide_brim_crimson"));

        var art_definition = try environment_art.Definition.init(allocator);
        errdefer art_definition.deinit();
        const presentation = try environment_theme.Presentation.init(
            &art_definition,
            &production.world,
        );
        var camera = camera2d.Camera2D.initDefault();
        try camera.setCenter(.{
            .x = foundation_playground.player_spawn.x,
            .y = presentation_camera_center_y,
        });
        const collision_fingerprint = environment_theme.collisionFingerprint(&production.world);
        const surface_fingerprint = presentation.surfaces.fingerprint();
        return .{
            .production = production,
            .environment_art_definition = art_definition,
            .environment = presentation,
            .camera = camera,
            .camera_follower = try camera2d.HorizontalFollower.init(1.55),
            .evidence = .{
                .collision_fingerprint = collision_fingerprint,
                .surface_fingerprint = surface_fingerprint,
                .camera_minimum_x = camera.center.x,
                .camera_maximum_x = camera.center.x,
                .decorative_ledges_without_edges = presentation.surfaces.count == environment_theme.expected_standable_surface_count,
            },
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.environment_art_definition.deinit();
        scene.production.deinit();
        scene.* = undefined;
    }

    pub fn meshDefinitions(
        scene: *const Scene,
    ) [mesh_definition_count]@import("deformable_mesh").DefinitionView {
        return scene.production.meshDefinitions();
    }

    pub fn updateFrame(
        scene: *Scene,
        frame_delta: f64,
        snapshot: input.FrameInputSnapshot,
    ) !void {
        if (snapshot.environment_theme_cycle.pressed) {
            try scene.cycleThemePreservingState();
        }
        if (snapshot.debug_toggle.pressed) {
            scene.detailed_debug_enabled = !scene.detailed_debug_enabled;
        }
        if (snapshot.reset.pressed) scene.environment.reset();

        const was_grounded = scene.production.female.controller.?.state.grounded;
        try scene.production.updateInteractiveFrameDelta(snapshot, frame_delta);
        const state = scene.production.female.controller.?.state;
        const landed = !was_grounded and state.grounded;
        const landed_on_raised_platform =
            landed and state.supporting_collider != null and state.supporting_collider.? != 1;
        try scene.camera_follower.update(&scene.camera, state.position.x);
        scene.evidence.camera_minimum_x = @min(scene.evidence.camera_minimum_x, scene.camera.center.x);
        scene.evidence.camera_maximum_x = @max(scene.evidence.camera_maximum_x, scene.camera.center.x);
        scene.evidence.parallax_observed =
            scene.evidence.parallax_observed or
            scene.evidence.camera_maximum_x - scene.evidence.camera_minimum_x > 0.5;
        scene.evidence.front_idle_observed =
            scene.evidence.front_idle_observed or
            (state.grounded and @abs(state.velocity.x) < 0.0001 and
                scene.production.female.presentationView() == .front);
        scene.evidence.side_locomotion_observed =
            scene.evidence.side_locomotion_observed or
            (@abs(state.velocity.x) > 0.25 and scene.production.female.presentationView() == .side);
        scene.evidence.jump_observed = scene.evidence.jump_observed or !state.grounded;
        if (!state.grounded) {
            scene.evidence.maximum_airborne_x =
                @max(scene.evidence.maximum_airborne_x, state.position.x);
        }
        scene.evidence.landing_observed = scene.evidence.landing_observed or landed;
        if (landed) {
            scene.evidence.last_landing_position = state.position;
            scene.evidence.last_landing_collider = state.supporting_collider;
        }
        scene.evidence.raised_platform_landing_observed =
            scene.evidence.raised_platform_landing_observed or landed_on_raised_platform;
        if (landed_on_raised_platform and scene.evidence.raised_platform_landing_frame == null) {
            scene.evidence.raised_platform_landing_frame = scene.production.frame_index;
        }
        scene.evidence.reset_observed =
            scene.evidence.reset_observed or
            (snapshot.reset.pressed and scene.environment.active_theme == .violet_crystal_ruin);
        scene.evidence.detailed_debug_observed =
            scene.evidence.detailed_debug_observed or scene.detailed_debug_enabled;
        scene.observeTheme();
    }

    pub fn applyViewport(scene: *Scene, width: u32, height: u32) !void {
        const before = scene.gameplaySnapshot();
        try scene.camera.setViewport(width, height);
        const after = scene.gameplaySnapshot();
        if (!snapshotsEqualExceptCameraViewport(before, after)) {
            return error.EnvironmentResizeChangedAuthoritativeState;
        }
        scene.evidence.resize_observed = true;
    }

    pub fn cycleThemePreservingState(scene: *Scene) !void {
        const before = scene.gameplaySnapshot();
        try scene.environment.cycle();
        const after = scene.gameplaySnapshot();
        if (!std.meta.eql(before, after)) {
            scene.evidence.switch_preserved_authoritative_state = false;
            return error.EnvironmentThemeSwitchChangedAuthoritativeState;
        }
        scene.evidence.switch_count = scene.environment.switch_count;
        scene.observeTheme();
    }

    pub fn gameplaySnapshot(scene: *const Scene) GameplaySnapshot {
        return .{
            .female_controller = scene.production.female.controller.?.state,
            .male_world_position = scene.production.male.world_position,
            .male_facing = scene.production.male.facing,
            .female_world_position = scene.production.female.world_position,
            .female_facing = scene.production.female.facing,
            .male_view = scene.production.male.presentationView(),
            .female_view = scene.production.female.presentationView(),
            .male_view_override = scene.production.male.presentationOverride(),
            .female_view_override = scene.production.female.presentationOverride(),
            .male_interaction_owner = scene.production.male.interactionOwnerId(),
            .female_interaction_owner = scene.production.female.interactionOwnerId(),
            .male_loadout_fingerprint = loadoutFingerprint(&scene.production.male),
            .female_loadout_fingerprint = loadoutFingerprint(&scene.production.female),
            .current_preset = scene.production.current_preset,
            .custom_active = scene.production.custom_active,
            .paused = scene.production.paused,
            .simulation_tick = scene.production.simulation_tick,
            .frame_index = scene.production.frame_index,
            .clock_accumulator = scene.production.clock.accumulator,
            .pending_edges = scene.production.pending_input.pendingEdgeCount(),
            .camera_center = scene.camera.center,
            .collision_fingerprint = environment_theme.collisionFingerprint(&scene.production.world),
            .surface_fingerprint = scene.environment.surfaces.fingerprint(),
        };
    }

    pub fn submit(scene: *Scene, queue: *render_queue.UnifiedRenderQueue) !u32 {
        return scene.submitTraced(queue, null, null);
    }

    pub fn submitTraced(
        scene: *Scene,
        queue: *render_queue.UnifiedRenderQueue,
        visual_trace: ?*visual_geometry.Trace,
        parallax_trace: ?*environment_theme.ParallaxTrace,
    ) !u32 {
        var submitted = try scene.environment.submitTraced(
            &scene.production.world,
            queue,
            parallax_trace,
        );
        submitted += try scene.production.submitTraced(queue, visual_trace);
        if (scene.detailed_debug_enabled) {
            submitted += try submitColliderDebug(&scene.production.world, queue);
        }
        scene.observeTheme();
        return submitted;
    }

    pub fn validateComplete(scene: *const Scene) !void {
        if (!scene.evidence.violet_observed) return error.VioletEnvironmentNotObserved;
        if (!scene.evidence.debug_observed) return error.DebugEnvironmentNotObserved;
        if (scene.evidence.switch_count < 2) return error.EnvironmentSwitchCountIncomplete;
        if (!scene.evidence.switch_preserved_authoritative_state)
            return error.EnvironmentSwitchChangedAuthoritativeState;
        if (!scene.evidence.parallax_observed) return error.EnvironmentParallaxNotObserved;
        if (!scene.evidence.front_idle_observed) return error.EnvironmentFrontIdleNotObserved;
        if (!scene.evidence.side_locomotion_observed)
            return error.EnvironmentSideLocomotionNotObserved;
        if (!scene.evidence.jump_observed) return error.EnvironmentJumpNotObserved;
        if (!scene.evidence.landing_observed) return error.EnvironmentLandingNotObserved;
        if (!scene.evidence.raised_platform_landing_observed) {
            std.log.err(
                "Prompt 26 route missed raised platform: maximum_airborne_x={d:.4} last_landing=({d:.4},{d:.4}) support={any}",
                .{
                    scene.evidence.maximum_airborne_x,
                    scene.evidence.last_landing_position.x,
                    scene.evidence.last_landing_position.y,
                    scene.evidence.last_landing_collider,
                },
            );
            return error.EnvironmentRaisedPlatformLandingNotObserved;
        }
        if (!scene.evidence.reset_observed) return error.EnvironmentResetNotObserved;
        if (!scene.evidence.resize_observed) return error.EnvironmentResizeNotObserved;
        if (!scene.evidence.decorative_ledges_without_edges)
            return error.EnvironmentDecorativeBoundaryNotObserved;
        if (!scene.evidence.detailed_debug_observed)
            return error.EnvironmentDetailedDebugNotObserved;
        if (scene.evidence.collision_fingerprint !=
            environment_theme.collisionFingerprint(&scene.production.world) or
            scene.evidence.surface_fingerprint != scene.environment.surfaces.fingerprint() or
            scene.environment.surfaces.count != environment_theme.expected_standable_surface_count)
        {
            return error.EnvironmentWorldAuthorityChanged;
        }
    }

    fn observeTheme(scene: *Scene) void {
        switch (scene.environment.active_theme) {
            .violet_crystal_ruin => scene.evidence.violet_observed = true,
            .neutral_debug => scene.evidence.debug_observed = true,
        }
    }
};

pub const ScriptedInput = struct {
    frame_index: u32 = 0,

    pub fn nextRaw(sequence: *ScriptedInput) input.RawInputState {
        const frame = sequence.frame_index;
        sequence.frame_index +|= 1;
        var keyboard = input.KeyboardState{};
        if (frame >= 120 and frame < 280) keyboard.d = true;
        if (frame == 105) keyboard.o = true;
        if (frame == 60 or frame == 90) keyboard.t = true;
        if (frame == 195) keyboard.space = true;
        if (frame > 195 and frame < 218) keyboard.space = true;
        if (frame == 520) keyboard.f1 = true;
        if (frame == 640) keyboard.r = true;
        return .{ .keyboard = keyboard };
    }
};

fn snapshotsEqualExceptCameraViewport(before: GameplaySnapshot, after: GameplaySnapshot) bool {
    return std.meta.eql(before, after);
}

fn loadoutFingerprint(instance: *const character.CharacterInstance) u64 {
    var hash = std.hash.Fnv1a_64.init();
    if (instance.equipment_loadout) |*loadout| {
        for (loadout.equippedItems()) |item| {
            const raw: u16 = @intFromEnum(item);
            hash.update(std.mem.asBytes(&raw));
        }
    }
    return hash.final();
}

fn submitColliderDebug(
    world: *const @import("collision_world").CollisionWorld,
    queue: *render_queue.UnifiedRenderQueue,
) !u32 {
    var submitted: u32 = 0;
    for (world.colliders, 0..) |static_collider, collider_index| {
        const bounds = static_collider.bounds;
        const color: [4]f32 = if (static_collider.ground_query_eligible)
            .{ 0.10, 0.92, 1.0, 0.88 }
        else
            .{ 1.0, 0.34, 0.12, 0.88 };
        const thickness: f32 = 0.026;
        const width = bounds.maximum.x - bounds.minimum.x;
        const height = bounds.maximum.y - bounds.minimum.y;
        const center_x = (bounds.minimum.x + bounds.maximum.x) * 0.5;
        const center_y = (bounds.minimum.y + bounds.maximum.y) * 0.5;
        const lines = [_]struct { position: [2]f32, scale: [2]f32 }{
            .{ .position = .{ center_x, bounds.minimum.y }, .scale = .{ width, thickness } },
            .{ .position = .{ center_x, bounds.maximum.y }, .scale = .{ width, thickness } },
            .{ .position = .{ bounds.minimum.x, center_y }, .scale = .{ thickness, height } },
            .{ .position = .{ bounds.maximum.x, center_y }, .scale = .{ thickness, height } },
        };
        for (lines, 0..) |line, line_index| {
            _ = try queue.submitSprite(.{
                .world_position = line.position,
                .rotation = 0,
                .scale = line.scale,
                .pivot = .{ 0.5, 0.5 },
                .uv_rect = .{ 0, 0, 1, 1 },
                .tint = color,
                .texture_page = 0,
                .order = .{
                    .scene_layer = character.SceneLayers.debug_overlay,
                    .interaction_layer = 0,
                    .actor_layer = @intCast(collider_index),
                    .body_part_layer = @intCast(line_index),
                },
            });
            submitted += 1;
        }
    }
    return submitted;
}
