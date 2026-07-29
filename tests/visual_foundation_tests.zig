const std = @import("std");
const math = @import("math");
const input = @import("input");
const interaction = @import("interaction");
const handshake = @import("handshake");
const presentation_view = @import("presentation_view");
const render_queue = @import("render_queue");
const camera2d = @import("camera2d");
const acceptance_hud = @import("acceptance_hud");
const foundation_evidence = @import("foundation_evidence");
const foundation_coherence = @import("foundation_coherence");
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

test "Prompt 27B contact ruler accepts boundaries and rejects wrong sole and pivot" {
    const camera = camera2d.Camera2D.initDefault();
    const pixels_per_meter = camera.pixels_per_meter;
    const valid = try foundation_coherence.measureGroundContact(camera, .{
        .planted = true,
        .canonical_sole_world = .{
            .x = 0,
            .y = foundation_coherence.semantic_sole_tolerance_px /
                pixels_per_meter,
        },
        .supporting_top_y = 0,
        .heel_side_sole_world = .{
            .x = -0.2,
            .y = foundation_coherence.sole_endpoint_maximum_height_px /
                pixels_per_meter,
        },
        .toe_side_sole_world = .{
            .x = 0.2,
            .y = foundation_coherence.sole_endpoint_minimum_height_px /
                pixels_per_meter,
        },
    });
    try std.testing.expect(valid.passes());

    const wrong_sole = try foundation_coherence.measureGroundContact(camera, .{
        .planted = true,
        .canonical_sole_world = .{
            .x = 0,
            .y = (foundation_coherence.semantic_sole_tolerance_px + 0.001) /
                pixels_per_meter,
        },
        .supporting_top_y = 0,
        .heel_side_sole_world = .{ .x = -0.2, .y = 0 },
        .toe_side_sole_world = .{ .x = 0.2, .y = 0 },
    });
    try std.testing.expect(!wrong_sole.passes());

    const wrong_pivot = try foundation_coherence.measureGroundContact(camera, .{
        .planted = true,
        .canonical_sole_world = .{ .x = 0, .y = 0 },
        .supporting_top_y = 0,
        .heel_side_sole_world = .{
            .x = -0.2,
            .y = (foundation_coherence.visual_sole_tolerance_px + 0.001) /
                pixels_per_meter,
        },
        .toe_side_sole_world = .{
            .x = 0.2,
            .y = (foundation_coherence.visual_sole_tolerance_px + 0.001) /
                pixels_per_meter,
        },
    });
    try std.testing.expect(!wrong_pivot.passes());

    const clearly_invalid = try foundation_coherence.measureGroundContact(camera, .{
        .planted = true,
        .canonical_sole_world = .{ .x = 0, .y = 1 },
        .supporting_top_y = 0,
        .heel_side_sole_world = .{ .x = -0.2, .y = 1 },
        .toe_side_sole_world = .{ .x = 0.2, .y = 1 },
    });
    try std.testing.expect(!clearly_invalid.passes());

    const swinging = try foundation_coherence.measureGroundContact(camera, .{
        .planted = false,
        .canonical_sole_world = .{ .x = 0, .y = 100 },
        .supporting_top_y = 0,
        .heel_side_sole_world = .{ .x = -0.2, .y = 100 },
        .toe_side_sole_world = .{ .x = 0.2, .y = 100 },
    });
    try std.testing.expect(!swinging.applicable);
    try std.testing.expect(swinging.passes());
}

test "Prompt 27B left and right planted contacts are accepted independently" {
    const camera = camera2d.Camera2D.initDefault();
    const pixels_per_meter = camera.pixels_per_meter;
    const left = try foundation_coherence.measureGroundContact(camera, .{
        .planted = true,
        .canonical_sole_world = .{ .x = -0.25, .y = 0 },
        .supporting_top_y = 0,
        .heel_side_sole_world = .{ .x = -0.4, .y = 0 },
        .toe_side_sole_world = .{ .x = -0.1, .y = 0 },
    });
    const right = try foundation_coherence.measureGroundContact(camera, .{
        .planted = true,
        .canonical_sole_world = .{
            .x = 0.25,
            .y = (foundation_coherence.semantic_sole_tolerance_px + 0.001) /
                pixels_per_meter,
        },
        .supporting_top_y = 0,
        .heel_side_sole_world = .{ .x = 0.1, .y = 0 },
        .toe_side_sole_world = .{ .x = 0.4, .y = 0 },
    });
    try std.testing.expect(left.passes());
    try std.testing.expect(!right.passes());
    try std.testing.expect(
        (left.canonical_error_px + right.canonical_error_px) * 0.5 <
            foundation_coherence.semantic_sole_tolerance_px,
    );
}

test "Prompt 27B surface order keeps truthful edge below characters and debug" {
    try std.testing.expect(foundation_coherence.surfaceOrderingValid(
        -10_000,
        -9_500,
        0,
        30_000,
    ));
    try std.testing.expect(!foundation_coherence.surfaceOrderingValid(
        -10_000,
        1,
        0,
        30_000,
    ));
    try std.testing.expect(!foundation_coherence.surfaceOrderingValid(
        -10_000,
        31_000,
        0,
        30_000,
    ));
}

test "Prompt 27B camera safe region accepts exact margins and corrects clipping" {
    var camera = try camera2d.Camera2D.init(
        math.Vec2.zero,
        640,
        480,
        camera2d.default_pixels_per_meter,
    );
    const half_safe_world =
        (240 - foundation_coherence.minimum_top_headroom_px) /
        camera.pixels_per_meter;
    const valid_bounds = foundation_coherence.Bounds{
        .minimum = .{ .x = -1, .y = -half_safe_world },
        .maximum = .{ .x = 1, .y = half_safe_world },
    };
    const exact = try foundation_coherence.framingMeasurement(
        valid_bounds,
        camera,
    );
    try std.testing.expectApproxEqAbs(
        foundation_coherence.minimum_top_headroom_px,
        exact.top_headroom_px,
        0.0001,
    );
    try std.testing.expect(exact.passes());

    const clipped = foundation_coherence.Bounds{
        .minimum = .{ .x = -1, .y = -1 },
        .maximum = .{ .x = 1, .y = half_safe_world + 0.01 },
    };
    const before = try foundation_coherence.framingMeasurement(clipped, camera);
    try std.testing.expect(
        before.top_headroom_px <
            foundation_coherence.minimum_top_headroom_px,
    );
    const correction = try foundation_coherence.applyVerticalSafeRegion(
        &camera,
        clipped,
    );
    try std.testing.expect(correction.measurement.passes());

    const impossible = foundation_coherence.Bounds{
        .minimum = .{ .x = -1, .y = -4 },
        .maximum = .{ .x = 1, .y = 4 },
    };
    try std.testing.expectError(
        error.VisibleBoundsExceedSafeViewport,
        foundation_coherence.applyVerticalSafeRegion(&camera, impossible),
    );
}

test "Prompt 27B camera safe region remains deterministic at resized viewport" {
    var first = try camera2d.Camera2D.init(
        .{ .x = 3, .y = 0 },
        960,
        540,
        camera2d.default_pixels_per_meter,
    );
    var second = first;
    const raised_jump_bounds = foundation_coherence.Bounds{
        .minimum = .{ .x = 1.2, .y = 0.9 },
        .maximum = .{ .x = 4.8, .y = 6.2 },
    };
    const first_correction = try foundation_coherence.applyVerticalSafeRegion(
        &first,
        raised_jump_bounds,
    );
    const second_correction = try foundation_coherence.applyVerticalSafeRegion(
        &second,
        raised_jump_bounds,
    );
    try std.testing.expect(first_correction.measurement.passes());
    try std.testing.expect(second_correction.measurement.passes());
    try std.testing.expectEqual(first.center, second.center);
    try std.testing.expectApproxEqAbs(
        first_correction.delta_px,
        second_correction.delta_px,
        0.000001,
    );
}

test "Prompt 27B abrupt resize separates first-frame reprojection from subsequent camera motion" {
    var previous = try camera2d.Camera2D.init(
        .{ .x = 3, .y = 0 },
        foundation_coherence.abrupt_resize_from_width,
        foundation_coherence.abrupt_resize_from_height,
        camera2d.default_pixels_per_meter,
    );
    var first_post = previous;
    try first_post.setViewport(
        foundation_coherence.abrupt_resize_to_width,
        foundation_coherence.abrupt_resize_to_height,
    );
    const bounds = foundation_coherence.Bounds{
        .minimum = .{ .x = 1.2, .y = 0 },
        .maximum = .{ .x = 4.8, .y = 5.4 },
    };
    const correction = try foundation_coherence.applyVerticalSafeRegion(
        &first_post,
        bounds,
    );
    const abrupt = try foundation_coherence.measureAbruptResize(
        previous,
        first_post,
        bounds,
    );
    try std.testing.expect(abrupt.passes());
    try std.testing.expect(correction.measurement.passes());
    try std.testing.expect(
        abrupt.world_camera_delta_px >
            foundation_coherence.maximum_camera_step_px,
    );
    try std.testing.expectError(
        error.ViewportReprojectionIsNotWorldCameraStep,
        foundation_coherence.worldCameraVerticalStepPx(previous, first_post),
    );

    previous = first_post;
    var within_bound = first_post;
    try within_bound.setCenter(.{
        .x = within_bound.center.x,
        .y = within_bound.center.y +
            (foundation_coherence.maximum_camera_step_px - 0.001) /
                within_bound.pixels_per_meter,
    });
    try std.testing.expect(
        try foundation_coherence.worldCameraVerticalStepPasses(
            previous,
            within_bound,
        ),
    );
    var minimally_invalid = first_post;
    try minimally_invalid.setCenter(.{
        .x = minimally_invalid.center.x,
        .y = minimally_invalid.center.y +
            (foundation_coherence.maximum_camera_step_px + 0.001) /
                minimally_invalid.pixels_per_meter,
    });
    try std.testing.expect(
        !try foundation_coherence.worldCameraVerticalStepPasses(
            previous,
            minimally_invalid,
        ),
    );
}

test "Prompt 27B transformed parallax rejects zero and reversed displacement" {
    const anchors = [3]foundation_coherence.ParallaxAnchor{
        .{
            .role = .far,
            .world = .{ .x = 0, .y = 0 },
            .camera_x_factor = 0.12,
        },
        .{
            .role = .midground,
            .world = .{ .x = 0, .y = 0 },
            .camera_x_factor = 0.46,
        },
        .{
            .role = .gameplay,
            .world = .{ .x = 0, .y = 0 },
            .camera_x_factor = 1,
        },
    };
    const start_camera = camera2d.Camera2D.initDefault();
    var finish_camera = start_camera;
    try finish_camera.setCenter(.{
        .x = start_camera.center.x + 2.5,
        .y = start_camera.center.y,
    });
    const start = try foundation_coherence.sampleParallaxFrame(
        start_camera,
        anchors,
    );
    const finish = try foundation_coherence.sampleParallaxFrame(
        finish_camera,
        anchors,
    );
    const valid = try foundation_coherence.measureParallax(
        start,
        finish,
        anchors,
        start_camera.pixels_per_meter,
    );
    try std.testing.expect(valid.passes());

    var configuration_only = finish;
    configuration_only.screen_x = start.screen_x;
    const zero = try foundation_coherence.measureParallax(
        start,
        configuration_only,
        anchors,
        start_camera.pixels_per_meter,
    );
    try std.testing.expect(!zero.passes());

    var reversed = finish;
    reversed.screen_x = .{
        start.screen_x[0] - 100,
        start.screen_x[1] - 40,
        start.screen_x[2] - 20,
    };
    const wrong_order = try foundation_coherence.measureParallax(
        start,
        reversed,
        anchors,
        start_camera.pixels_per_meter,
    );
    try std.testing.expect(!wrong_order.passes());
}

test "Prompt 27B presence ruler rejects minimally excessive and full overlap" {
    const first = foundation_coherence.Bounds{
        .minimum = .{ .x = 0, .y = 0 },
        .maximum = .{ .x = 1, .y = 2 },
    };
    const exact_boundary = foundation_coherence.Bounds{
        .minimum = .{ .x = 0.98, .y = 0 },
        .maximum = .{ .x = 1.98, .y = 2 },
    };
    const minimally_invalid = foundation_coherence.Bounds{
        .minimum = .{ .x = 0.9799, .y = 0 },
        .maximum = .{ .x = 1.9799, .y = 2 },
    };
    const full = first;
    const boundary_ratio = try foundation_coherence.overlapRatio(
        first,
        exact_boundary,
    );
    const minimal_ratio = try foundation_coherence.overlapRatio(
        first,
        minimally_invalid,
    );
    const full_ratio = try foundation_coherence.overlapRatio(first, full);
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), boundary_ratio, 0.00001);
    try std.testing.expect(
        foundation_coherence.overlapPasses(boundary_ratio, false),
    );
    try std.testing.expect(
        !foundation_coherence.overlapPasses(minimal_ratio, false),
    );
    try std.testing.expect(
        !foundation_coherence.overlapPasses(full_ratio, false),
    );
    try std.testing.expect(
        foundation_coherence.overlapPasses(@as(f32, 0.15), true),
    );
    try std.testing.expect(
        !foundation_coherence.overlapPasses(@as(f32, 0.1501), true),
    );
}

test "Prompt 27B root-step ruler accepts controller motion and rejects teleport" {
    const fixed_dt: f32 = 1.0 / 240.0;
    const maximum_speed: f32 = 8;
    const maximum_step =
        maximum_speed * fixed_dt + foundation_coherence.root_step_slack_m;
    try std.testing.expect(foundation_coherence.controlledRootStepPasses(
        math.Vec2.zero,
        .{ .x = maximum_step, .y = 0 },
        maximum_speed,
        fixed_dt,
    ));
    try std.testing.expect(!foundation_coherence.controlledRootStepPasses(
        math.Vec2.zero,
        .{ .x = maximum_step + 0.0001, .y = 0 },
        maximum_speed,
        fixed_dt,
    ));
    try std.testing.expect(!foundation_coherence.controlledRootStepPasses(
        math.Vec2.zero,
        .{ .x = 10, .y = 0 },
        maximum_speed,
        fixed_dt,
    ));
}

const P27bRouteSummary = struct {
    fingerprint: u64,
    simulation_tick: u64,
    female_root: math.Vec2,
    male_root: math.Vec2,
    camera_center: math.Vec2,
    interaction_count: usize,
};

fn runP27bRoute(split_render_schedule: bool) !P27bRouteSummary {
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
    const fixed_delta: f64 = 1.0 / 240.0;

    for (0..900) |_| {
        const raw = script.nextRaw(&scene);
        if (split_render_schedule) {
            const first = try snapshots.update(raw);
            try scene.updateFrame(fixed_delta * 2, first);
            const second = try snapshots.update(raw);
            try scene.updateFrame(fixed_delta * 2, second);
        } else {
            const snapshot = try snapshots.update(raw);
            try scene.updateFrame(fixed_delta * 4, snapshot);
        }
        try script.observe(&scene);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
        scene.recordRendering(queue.frame_metrics);
    }
    try std.testing.expect(scene.evidence.camera_follow);
    try std.testing.expect(scene.evidence.parallax);
    try std.testing.expect(scene.evidence.raised_platform_landing);
    try std.testing.expectEqual(
        @as(u64, 0),
        queue.lifetime_metrics.cpu_allocations_after_stabilization,
    );
    return .{
        .fingerprint = scene.authoritativeInteractionFingerprint(),
        .simulation_tick = scene.integrated.production.simulation_tick,
        .female_root = scene.integrated.production.female.world_position,
        .male_root = scene.integrated.production.male.world_position,
        .camera_center = scene.integrated.camera.center,
        .interaction_count = scene.evidence.interaction_count,
    };
}

test "Prompt 27B pre-reset fixed-tick outcome is invariant to split render schedule" {
    const ordinary = try runP27bRoute(false);
    const split = try runP27bRoute(true);
    try std.testing.expectEqual(ordinary.simulation_tick, split.simulation_tick);
    try std.testing.expectEqual(ordinary.female_root, split.female_root);
    try std.testing.expectEqual(ordinary.male_root, split.male_root);
    try std.testing.expectEqual(ordinary.camera_center, split.camera_center);
    try std.testing.expectEqual(ordinary.interaction_count, split.interaction_count);
    try std.testing.expectEqual(ordinary.fingerprint, split.fingerprint);
}
