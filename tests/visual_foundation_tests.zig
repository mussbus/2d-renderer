const std = @import("std");
const input = @import("input");
const interaction = @import("interaction");
const handshake = @import("handshake");
const presentation_view = @import("presentation_view");
const render_queue = @import("render_queue");
const camera2d = @import("camera2d");
const acceptance_hud = @import("acceptance_hud");
const foundation_evidence = @import("foundation_evidence");
const visual_foundation = @import("visual_foundation");

test "Prompt 27 bounded real-art foundation route proves presentation interaction and reset" {
    var scene = try visual_foundation.Scene.init(std.testing.allocator);
    defer scene.deinit();
    var script = visual_foundation.ScriptedInput{};
    var snapshots = input.SnapshotBuilder{};
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    queue.markStabilized();

    for (0..visual_foundation.required_frames) |_| {
        const snapshot = try snapshots.update(script.nextRaw(&scene));
        try scene.updateFrame(1.0 / 60.0, snapshot);
        try script.observe(&scene);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
        scene.recordRendering(queue.frame_metrics);
    }
    try scene.validateComplete(&script);
    try std.testing.expectEqual(@as(u64, 0), queue.lifetime_metrics.cpu_allocations_after_stabilization);
}

test "interaction presentation data can select front without a second interaction subsystem" {
    var scene = try visual_foundation.Scene.init(std.testing.allocator);
    defer scene.deinit();
    const synthetic = try handshake.definitionWithPresentation(
        &scene.integrated.production.animations,
        interaction.PresentationDefinition{
            .role_views = .{ .front, .front },
            .suppress_automatic_view = true,
            .occlusion_profile = .none,
        },
    );
    try std.testing.expectEqual(
        @as(?presentation_view.View, .front),
        synthetic.presentation.viewForRole(.initiator),
    );
    try std.testing.expectEqual(
        @as(?presentation_view.View, .front),
        synthetic.presentation.viewForRole(.receiver),
    );
    try std.testing.expect(synthetic.presentation.suppress_automatic_view);
}

test "interaction presentation rejects suppression without both role views" {
    try std.testing.expectError(
        error.SuppressedInteractionViewMissing,
        (interaction.PresentationDefinition{
            .role_views = .{ .front, null },
            .suppress_automatic_view = true,
        }).validate(),
    );
}

fn validObservation() foundation_evidence.Observation {
    return .{
        .render_frame = 1,
        .simulation_tick = 4,
        .female_entity = 2,
        .male_entity = 1,
        .animation_state = "idle",
        .body = "conventional_female",
        .morphology = "curvy",
        .hair = "long_rigid",
        .outfit = "wide_brim_crimson",
        .theme = "violet_crystal_ruin",
        .texture_pages = 9,
    };
}

test "Prompt 27A stop front predicate rejects side view and residual velocity" {
    const spec = foundation_evidence.specs[
        @intFromEnum(
            foundation_evidence.CaptureId.stopped_front_facing_left,
        )
    ];
    var observation = validObservation();
    observation.stage = .stop_left;
    observation.facing = .left;
    observation.view = .front;
    try std.testing.expect(foundation_evidence.matches(spec, observation));

    observation.view = .side;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.view = .front;
    observation.velocity[0] = foundation_evidence.idle_velocity_threshold_mps + 0.0001;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.velocity[0] = 2;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
}

test "Prompt 27A rise and fall predicates reject wrong authoritative motion" {
    const rise = foundation_evidence.specs[
        @intFromEnum(
            foundation_evidence.CaptureId.short_jump_rise,
        )
    ];
    const fall = foundation_evidence.specs[
        @intFromEnum(
            foundation_evidence.CaptureId.jump_fall,
        )
    ];
    var observation = validObservation();
    observation.stage = .short_jump_release;
    observation.view = .side;
    observation.grounded = false;
    observation.airborne_clearance_m =
        foundation_evidence.airborne_clearance_threshold_m;
    observation.velocity[1] = foundation_evidence.jump_vertical_threshold_mps + 0.001;
    try std.testing.expect(foundation_evidence.matches(rise, observation));
    observation.grounded = true;
    try std.testing.expect(!foundation_evidence.matches(rise, observation));
    observation.grounded = false;
    observation.velocity[1] = foundation_evidence.jump_vertical_threshold_mps;
    try std.testing.expect(!foundation_evidence.matches(fall, observation));
    observation.velocity[1] = -foundation_evidence.jump_vertical_threshold_mps - 0.001;
    try std.testing.expect(foundation_evidence.matches(fall, observation));
    observation.velocity[1] = 5;
    try std.testing.expect(!foundation_evidence.matches(fall, observation));
}

test "Prompt 27A debug predicate fails closed without every submitted category" {
    const spec = foundation_evidence.specs[
        @intFromEnum(
            foundation_evidence.CaptureId.detailed_debug,
        )
    ];
    var observation = validObservation();
    observation.stage = .second_wait;
    observation.presentation_mode = .interaction_owned;
    observation.view = .side;
    observation.grounded = true;
    observation.detailed_debug_enabled = true;
    observation.debug_enabled_ticks = foundation_evidence.inspection_stable_ticks;
    observation.interaction_id = 2;
    observation.interaction_lifecycle = .active;
    observation.interaction_phase = .contact;
    observation.active_interactions = 1;
    observation.contact_tick = 4;
    observation.ik_active = true;
    observation.ordering_valid = true;
    observation.debug_counts = .{
        .collider = 1,
        .root = 1,
        .ground = 1,
        .ik = 1,
        .participant_link = 1,
    };
    try std.testing.expect(foundation_evidence.matches(spec, observation));
    observation.debug_counts.ik = 0;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.debug_counts = .{};
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
}

test "Prompt 27A contact cannot fire before first contact semantic" {
    const spec = foundation_evidence.specs[
        @intFromEnum(
            foundation_evidence.CaptureId.interaction_first_contact,
        )
    ];
    var observation = validObservation();
    observation.stage = .first_wait;
    observation.presentation_mode = .interaction_owned;
    observation.view = .side;
    observation.interaction_id = 1;
    observation.interaction_lifecycle = .active;
    observation.interaction_phase = .contact;
    observation.active_interactions = 1;
    observation.contact_tick = observation.simulation_tick;
    observation.ik_active = true;
    observation.ordering_valid = true;
    try std.testing.expect(foundation_evidence.matches(spec, observation));
    observation.contact_tick = 0;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.interaction_phase = .approach;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
}

test "Prompt 27A cleanup rejects every retained interaction owner" {
    const spec = foundation_evidence.specs[
        @intFromEnum(
            foundation_evidence.CaptureId.interaction_cleanup_front,
        )
    ];
    var observation = validObservation();
    observation.stage = .first_cleanup_hold;
    try std.testing.expect(foundation_evidence.matches(spec, observation));

    observation.active_ik_constraints = 1;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.active_ik_constraints = 0;
    observation.active_overrides = 1;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.active_overrides = 0;
    observation.participant_owner_count = 1;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.participant_owner_count = 0;
    observation.presentation_mode = .interaction_owned;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
}

test "Prompt 27A stable ticks reset after an invalid observation" {
    var tracker = foundation_evidence.Tracker{};
    var observation = validObservation();
    observation.stage = .idle;
    observation.simulation_tick = 4;
    try std.testing.expect((try tracker.observe(observation)) == null);
    try std.testing.expectEqual(@as(u32, 1), tracker.stable_ticks);
    observation.simulation_tick = 8;
    observation.velocity[0] = 1;
    try std.testing.expect((try tracker.observe(observation)) == null);
    try std.testing.expectEqual(@as(u32, 0), tracker.stable_ticks);
    observation.simulation_tick = 12;
    observation.velocity[0] = 0;
    try std.testing.expect((try tracker.observe(observation)) == null);
    try std.testing.expectEqual(@as(u32, 4), tracker.stable_ticks);
}

test "Prompt 27A timeout fails instead of omitting a capture" {
    var tracker = foundation_evidence.Tracker{ .log_timeouts = false };
    var observation = validObservation();
    observation.stage = .move_left;
    observation.velocity[0] = 1;
    var index: u32 = 0;
    while (index < foundation_evidence.specs[0].timeout_render_frames) : (index += 1) {
        observation.render_frame = index;
        observation.simulation_tick = @as(u64, index) * 4;
        try std.testing.expect((try tracker.observe(observation)) == null);
    }
    observation.render_frame += 1;
    observation.simulation_tick += 4;
    try std.testing.expectError(
        error.CapturePredicateTimeout,
        tracker.observe(observation),
    );
}

test "Prompt 27A metadata validation rejects missing and nonfinite fields" {
    var observation = validObservation();
    try observation.validate();
    observation.outfit = "";
    try std.testing.expectError(error.MissingCaptureMetadata, observation.validate());
    observation = validObservation();
    observation.velocity[1] = std.math.nan(f32);
    try std.testing.expectError(
        error.NonFiniteCaptureObservation,
        observation.validate(),
    );
}

test "Prompt 27A stability is independent of duplicate render observations" {
    var ordinary = foundation_evidence.Tracker{};
    var doubled = foundation_evidence.Tracker{};
    var ordinary_candidate: ?foundation_evidence.Candidate = null;
    var doubled_candidate: ?foundation_evidence.Candidate = null;
    var observation = validObservation();
    observation.stage = .idle;

    var tick: u64 = 4;
    while (tick <= 244) : (tick += 4) {
        observation.simulation_tick = tick;
        observation.render_frame += 1;
        ordinary_candidate = try ordinary.observe(observation);
        doubled_candidate = try doubled.observe(observation);
        observation.render_frame += 1;
        doubled_candidate = try doubled.observe(observation);
    }

    try std.testing.expect(ordinary_candidate != null);
    try std.testing.expect(doubled_candidate != null);
    try std.testing.expectEqual(
        ordinary_candidate.?.stable_ticks,
        doubled_candidate.?.stable_ticks,
    );
    try std.testing.expectEqual(
        foundation_evidence.inspection_stable_ticks + 1,
        ordinary_candidate.?.stable_ticks,
    );
}

test "Prompt 27A capture commit validates order and current metadata" {
    var tracker = foundation_evidence.Tracker{};
    var observation = validObservation();
    observation.stage = .idle;
    observation.simulation_tick = 4;
    try std.testing.expect((try tracker.observe(observation)) == null);
    observation.simulation_tick =
        foundation_evidence.inspection_stable_ticks + 4;
    const candidate = (try tracker.observe(observation)).?;

    var mismatched = observation;
    mismatched.velocity[0] = 1;
    try std.testing.expectError(
        error.CaptureCommitStateMismatch,
        tracker.commit(candidate, mismatched),
    );
    var wrong_order = candidate;
    wrong_order.spec_index += 1;
    try std.testing.expectError(
        error.CaptureCommitOrderMismatch,
        tracker.commit(wrong_order, observation),
    );
    try tracker.commit(candidate, observation);
    try std.testing.expectEqual(@as(usize, 1), tracker.next_index);
}

test "Prompt 27A acceptance HUD is bounded and allocation free after initialization" {
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        1_600,
        1_599,
        1,
        1,
    );
    defer queue.deinit();
    queue.markStabilized();
    queue.beginFrame();
    const submitted = try acceptance_hud.submit(
        &queue,
        camera2d.Camera2D.initDefault(),
        validObservation(),
        .initial_front_idle,
    );
    const prepared = queue.prepare();
    try std.testing.expect(submitted > 0);
    try std.testing.expect(submitted <= acceptance_hud.maximum_hud_sprites);
    try std.testing.expectEqual(@as(usize, submitted), prepared.sprites.len);
    try std.testing.expectEqual(
        @as(u64, 0),
        queue.lifetime_metrics.cpu_allocations_after_stabilization,
    );
}

test "Prompt 27A locomotion and apex predicates reject boundary violations" {
    const locomotion = foundation_evidence.specs[
        @intFromEnum(foundation_evidence.CaptureId.side_left_walk)
    ];
    var observation = validObservation();
    observation.stage = .move_left;
    observation.view = .side;
    observation.facing = .left;
    observation.velocity[0] =
        -foundation_evidence.locomotion_speed_threshold_mps;
    try std.testing.expect(foundation_evidence.matches(locomotion, observation));
    observation.velocity[0] =
        -foundation_evidence.locomotion_speed_threshold_mps + 0.0001;
    try std.testing.expect(!foundation_evidence.matches(locomotion, observation));
    observation.velocity[0] = 3;
    try std.testing.expect(!foundation_evidence.matches(locomotion, observation));

    const apex = foundation_evidence.specs[
        @intFromEnum(foundation_evidence.CaptureId.jump_apex)
    ];
    observation = validObservation();
    observation.stage = .short_jump_release;
    observation.view = .side;
    observation.grounded = false;
    observation.airborne_clearance_m =
        foundation_evidence.airborne_clearance_threshold_m;
    observation.velocity[1] =
        foundation_evidence.apex_velocity_threshold_mps;
    try std.testing.expect(foundation_evidence.matches(apex, observation));
    observation.velocity[1] =
        foundation_evidence.apex_velocity_threshold_mps + 0.0001;
    try std.testing.expect(!foundation_evidence.matches(apex, observation));
    observation.velocity[1] = 8;
    try std.testing.expect(!foundation_evidence.matches(apex, observation));
}

test "Prompt 27A raised landing requires measured bilateral surface contact" {
    const spec = foundation_evidence.specs[
        @intFromEnum(foundation_evidence.CaptureId.raised_platform_landing)
    ];
    var observation = validObservation();
    observation.stage = .wait_raised_landing;
    observation.supporting_collider = 4;
    observation.landed_this_frame = true;
    observation.landing_support = 4;
    observation.raised_support = 4;
    observation.left_surface_error_m =
        foundation_evidence.landing_surface_contact_threshold_m;
    observation.right_surface_error_m =
        foundation_evidence.landing_surface_contact_threshold_m;
    observation.feet_surface_contact_valid = true;
    try std.testing.expect(foundation_evidence.matches(spec, observation));
    observation.left_surface_error_m =
        foundation_evidence.landing_surface_contact_threshold_m + 0.0001;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.left_surface_error_m = 2;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.left_surface_error_m = 0;
    observation.feet_surface_contact_valid = false;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
}

test "Prompt 27A theme transition requires invariant root camera and fingerprint" {
    const spec = foundation_evidence.specs[
        @intFromEnum(foundation_evidence.CaptureId.theme_switch_in_place)
    ];
    var observation = validObservation();
    observation.stage = .theme_hold;
    observation.theme_changed = true;
    observation.theme_transition_count = 1;
    observation.theme_fingerprint_unchanged = true;
    try std.testing.expect(foundation_evidence.matches(spec, observation));
    observation.theme_root_delta_m = 0.0000011;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.theme_root_delta_m = -1;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
    observation.theme_root_delta_m = 0;
    observation.theme_fingerprint_unchanged = false;
    try std.testing.expect(!foundation_evidence.matches(spec, observation));
}

test "Prompt 27A approach reach and release require their lifecycle semantics" {
    const approach = foundation_evidence.specs[
        @intFromEnum(foundation_evidence.CaptureId.interaction_approach)
    ];
    var observation = validObservation();
    observation.stage = .approach_hold;
    observation.interaction_eligible = true;
    try std.testing.expect(foundation_evidence.matches(approach, observation));
    observation.active_interactions = 1;
    try std.testing.expect(!foundation_evidence.matches(approach, observation));

    const reach = foundation_evidence.specs[
        @intFromEnum(foundation_evidence.CaptureId.interaction_reach)
    ];
    observation = validObservation();
    observation.stage = .first_wait;
    observation.presentation_mode = .interaction_owned;
    observation.view = .side;
    observation.interaction_id = 1;
    observation.interaction_lifecycle = .active;
    observation.interaction_phase = .approach;
    observation.interaction_elapsed_ticks = 1;
    observation.active_interactions = 1;
    try std.testing.expect(foundation_evidence.matches(reach, observation));
    observation.contact_tick = observation.simulation_tick;
    try std.testing.expect(!foundation_evidence.matches(reach, observation));
    observation.contact_tick = 0;
    observation.interaction_elapsed_ticks = 0;
    try std.testing.expect(!foundation_evidence.matches(reach, observation));

    const release = foundation_evidence.specs[
        @intFromEnum(foundation_evidence.CaptureId.interaction_release)
    ];
    observation.interaction_elapsed_ticks = 1;
    observation.interaction_phase = .released;
    observation.simulation_tick = 1_000;
    observation.release_tick = observation.simulation_tick;
    try std.testing.expect(foundation_evidence.matches(release, observation));
    observation.release_tick = 0;
    try std.testing.expect(!foundation_evidence.matches(release, observation));
    observation.release_tick = observation.simulation_tick - 100;
    try std.testing.expect(!foundation_evidence.matches(release, observation));
}
