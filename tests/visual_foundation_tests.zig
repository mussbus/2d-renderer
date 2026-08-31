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
const visual_truth = @import("visual_truth");
const visual_geometry = @import("visual_geometry");
const debug_draw = @import("debug_draw");
const anatomy = @import("anatomy");
const character_art = @import("character_art");

test "Prompt 27 bounded real-art foundation route proves presentation interaction and reset" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .enforce_acceptance,
    );
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
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .enforce_acceptance,
    );
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

test "registration proof cases configure both production styles before simulation" {
    const cases = [_]visual_foundation.RegistrationProofCase{
        .body_front,
        .body_side_left,
        .body_side_right,
        .equipped_front,
        .equipped_side_left,
        .equipped_side_right,
    };
    for (cases) |proof_case| {
        var scene = try visual_foundation.Scene.init(
            std.testing.allocator,
            .measure_only,
        );
        defer scene.deinit();
        try scene.applyRegistrationProofCase(proof_case);
        const expected_view = proof_case.view();
        const expected_facing = proof_case.facing();
        try std.testing.expectEqual(
            expected_view,
            scene.integrated.production.male.presentationView(),
        );
        try std.testing.expectEqual(
            expected_view,
            scene.integrated.production.female.presentationView(),
        );
        try std.testing.expectEqual(expected_facing, scene.integrated.production.male.facingDirection());
        try std.testing.expectEqual(expected_facing, scene.integrated.production.female.facingDirection());
        var snapshot_builder = input.SnapshotBuilder{};
        try scene.updateFrame(0, try snapshot_builder.update(.{}));
        try std.testing.expectEqual(expected_facing, scene.integrated.production.male.facingDirection());
        try std.testing.expectEqual(expected_facing, scene.integrated.production.female.facingDirection());
        const expected_male_items: usize = if (proof_case.bodyOnly()) 0 else 3;
        const expected_female_items: usize = if (proof_case.bodyOnly()) 0 else 5;
        try std.testing.expectEqual(
            expected_male_items,
            scene.integrated.production.male.equipmentView().?.equippedItems().len,
        );
        try std.testing.expectEqual(
            expected_female_items,
            scene.integrated.production.female.equipmentView().?.equippedItems().len,
        );
        try std.testing.expectError(
            error.RegistrationProofCaseMustPrecedeSimulation,
            blk: {
                scene.integrated.production.simulation_tick = 1;
                break :blk scene.applyRegistrationProofCase(proof_case);
            },
        );
    }
}

test "component proof cases select bounded graph content and view before simulation" {
    const cases = [_]visual_foundation.ComponentProofCase{
        .eye_eyebrow,
        .scalp_hair,
        .extra_arm,
        .continuous,
        .intentional_gap,
        .front,
        .side_left,
        .side_right,
    };
    for (cases) |proof_case| {
        var scene = try visual_foundation.Scene.init(
            std.testing.allocator,
            .measure_only,
        );
        defer scene.deinit();
        try scene.applyComponentProofCase(proof_case);
        try std.testing.expectEqual(
            proof_case.view(),
            scene.integrated.production.male.presentationView(),
        );
        try std.testing.expectEqual(
            proof_case.view(),
            scene.integrated.production.female.presentationView(),
        );
        try std.testing.expectEqual(
            proof_case.facing(),
            scene.integrated.production.male.facingDirection(),
        );
        try std.testing.expectEqual(
            proof_case.facing(),
            scene.integrated.production.female.facingDirection(),
        );
        const definition = scene.integrated.production.definition
            .anatomy_definition.?.view();
        const male_runtime = scene.integrated.production.male.anatomyRuntimeSnapshot().?;
        const expected_body = if (proof_case.usesNonstandardMale())
            "nonstandard_humanoid"
        else
            "conventional_male";
        try std.testing.expectEqual(
            try definition.bodyPresetId(expected_body),
            male_runtime.selected_body_preset,
        );
        try std.testing.expectEqual(@as(usize, 0), scene.integrated.production
            .male.equipmentView().?.equippedItems().len);
        try std.testing.expectEqual(@as(usize, 0), scene.integrated.production
            .female.equipmentView().?.equippedItems().len);
        try std.testing.expectError(
            error.ComponentProofCaseMustPrecedeSimulation,
            blk: {
                scene.integrated.production.simulation_tick = 1;
                break :blk scene.applyComponentProofCase(proof_case);
            },
        );
    }
}

test "VF-01 truth snapshot exports typed graph ownership and connection modes" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
    try scene.applyComponentProofCase(.intentional_gap);
    scene.setDebugMode(.rig);
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    queue.beginFrame();
    _ = try scene.submit(&queue);
    try std.testing.expect(scene.truth_snapshot_valid);

    const male_id = scene.integrated.production.male.id().raw();
    var male_truth: ?*const visual_truth.Character = null;
    for (scene.truth_snapshot.characters[0..scene.truth_snapshot.character_count]) |*truth| {
        if (truth.id == male_id) male_truth = truth;
    }
    const truth = male_truth orelse return error.MaleTruthMissing;
    const detached = truth.partByName("extra_arm_second") orelse
        return error.IntentionalGapTruthMissing;
    try std.testing.expect(detached.active);
    try std.testing.expectEqual(
        @import("anatomy").ConnectionMode.intentional_gap,
        detached.connection_mode,
    );
    try std.testing.expectEqual(
        @import("anatomy").TopologyStatus.direct,
        detached.topology_status,
    );
    try std.testing.expect(detached.parent_socket != null);
    try std.testing.expect(detached.articulation_module != null);
    try std.testing.expectApproxEqAbs(
        @as(f32, 0.08),
        detached.measured_gap_m,
        0.00001,
    );
}

test "VF-03-R1 active optional arms produce graph-bound production submissions in every proof view" {
    const cases = [_]visual_foundation.ComponentProofCase{
        .continuous_front,
        .intentional_gap_front,
        .continuous_side_left,
        .continuous_side_right,
        .intentional_gap_side_left,
        .intentional_gap_side_right,
    };
    var projected_roots: [cases.len]math.Vec2 = undefined;
    for (cases, 0..) |proof_case, case_index| {
        var scene = try visual_foundation.Scene
            .initWithDiagnosticAllocatorAndComponentProof(
            std.testing.allocator,
            std.testing.allocator,
            .measure_only,
            proof_case,
        );
        defer scene.deinit();
        try scene.applyComponentProofCase(proof_case);
        scene.setDebugMode(.rig_registration);
        var queue = try render_queue.UnifiedRenderQueue.init(
            std.testing.allocator,
            render_queue.default_entry_capacity,
            render_queue.default_sprite_capacity,
            render_queue.default_mesh_capacity,
            visual_foundation.configured_texture_page_count,
        );
        defer queue.deinit();
        queue.beginFrame();
        _ = try scene.submit(&queue);

        try std.testing.expectEqual(@as(u8, 1), scene.truth_snapshot.active_optional_modules);
        try std.testing.expectEqual(
            @as(u8, 3),
            scene.truth_snapshot.expected_optional_visual_submissions,
        );
        try std.testing.expectEqual(
            @as(u8, 3),
            scene.truth_snapshot.actual_optional_visual_submissions,
        );
        try std.testing.expectEqual(
            @as(u8, 0),
            scene.truth_snapshot.missing_optional_visual_submissions,
        );
        try std.testing.expectEqual(
            @as(u8, 0),
            scene.truth_snapshot.orphan_optional_visual_submissions,
        );

        const truth = maleTruth(&scene) orelse return error.MaleTruthMissing;
        const component = truth.partByName("extra_arm") orelse
            return error.OptionalArmTruthMissing;
        try std.testing.expect(component.active);
        projected_roots[case_index] = component.connection_child_endpoint;
        const intentional = switch (proof_case) {
            .intentional_gap_front,
            .intentional_gap_side_left,
            .intentional_gap_side_right,
            => true,
            else => false,
        };
        try std.testing.expectEqual(
            if (intentional)
                anatomy.ConnectionMode.intentional_gap
            else
                anatomy.ConnectionMode.continuous,
            component.connection_mode,
        );
        try std.testing.expectEqual(
            visual_truth.MismatchResult.pass,
            component.connection_result,
        );
        try std.testing.expectApproxEqAbs(
            if (intentional) @as(f32, 0.08) else 0,
            component.measured_gap_m,
            0.00001,
        );
        try std.testing.expectApproxEqAbs(
            component.measured_gap_m * scene.integrated.camera.pixels_per_meter,
            component.acceptance_gap_px,
            0.0001,
        );

        const expected_names = [_][]const u8{
            "extra_upper_arm",
            "extra_forearm",
            "extra_hand",
        };
        const expected_starts = [_][]const u8{ "shoulder", "elbow", "wrist" };
        const expected_ends = [_][]const u8{ "elbow", "wrist", "hand_tip" };
        var found: [expected_names.len]bool = .{ false, false, false };
        for (scene.truth_snapshot.visuals[0..scene.truth_snapshot.visual_count]) |visual| {
            if (visual.character_id != truth.id) continue;
            const binding = visual.graph_binding orelse continue;
            if (binding.component_id != component.index) continue;
            var expected_index: ?usize = null;
            for (expected_names, 0..) |name, index| {
                if (std.mem.eql(u8, visual.stable_id.slice(), name)) {
                    expected_index = index;
                    break;
                }
            }
            const index = expected_index orelse
                return error.UnexpectedOptionalArmVisual;
            try std.testing.expect(!found[index]);
            found[index] = true;
            try std.testing.expectEqualStrings(
                "extra_arm",
                binding.component_identity.slice(),
            );
            try std.testing.expectEqualStrings(
                "extra_arm_module",
                binding.module_identity.slice(),
            );
            try std.testing.expectEqualStrings(
                expected_starts[index],
                binding.start_identity.slice(),
            );
            try std.testing.expectEqualStrings(
                expected_ends[index],
                binding.end_identity.slice(),
            );
            try std.testing.expectEqual(
                visual_geometry.RegistrationAuthority.authoritative_registration,
                visual.placement_authority,
            );
            try std.testing.expect(
                visual.final_submission_index != std.math.maxInt(u32),
            );
            try std.testing.expect(
                visual.alpha_bounds_maximum.x >
                    visual.alpha_bounds_minimum.x and
                    visual.alpha_bounds_maximum.y >
                        visual.alpha_bounds_minimum.y,
            );
            var passed_targets: usize = 0;
            for (scene.truth_snapshot.mismatches[0..scene.truth_snapshot.mismatch_count]) |mismatch| {
                if (mismatch.character_id == truth.id and
                    std.mem.eql(
                        u8,
                        mismatch.component.slice(),
                        visual.stable_id.slice(),
                    ) and mismatch.result == .pass)
                {
                    passed_targets += 1;
                }
            }
            try std.testing.expect(passed_targets >= 2);
        }
        for (found) |value| try std.testing.expect(value);
    }
    try std.testing.expect(
        !projected_roots[0].approxEqAbs(projected_roots[2], 0.00001),
    );
    try std.testing.expect(
        !projected_roots[2].approxEqAbs(projected_roots[3], 0.00001),
    );
}

test "VF-03-R1 disabled and two-module proofs enforce zero-or-exact production counts" {
    const cases = [_]struct {
        proof: visual_foundation.ComponentProofCase,
        modules: u8,
        submissions: u8,
    }{
        .{ .proof = .disabled, .modules = 0, .submissions = 0 },
        .{ .proof = .two_modules, .modules = 2, .submissions = 6 },
    };
    for (cases) |case| {
        var scene = try visual_foundation.Scene
            .initWithDiagnosticAllocatorAndComponentProof(
            std.testing.allocator,
            std.testing.allocator,
            .measure_only,
            case.proof,
        );
        defer scene.deinit();
        try scene.applyComponentProofCase(case.proof);
        scene.setDebugMode(.rig_registration);
        var queue = try render_queue.UnifiedRenderQueue.init(
            std.testing.allocator,
            render_queue.default_entry_capacity,
            render_queue.default_sprite_capacity,
            render_queue.default_mesh_capacity,
            visual_foundation.configured_texture_page_count,
        );
        defer queue.deinit();
        queue.beginFrame();
        _ = try scene.submit(&queue);
        try std.testing.expectEqual(
            case.modules,
            scene.truth_snapshot.active_optional_modules,
        );
        try std.testing.expectEqual(
            case.submissions,
            scene.truth_snapshot.expected_optional_visual_submissions,
        );
        try std.testing.expectEqual(
            case.submissions,
            scene.truth_snapshot.actual_optional_visual_submissions,
        );
        try std.testing.expectEqual(
            @as(u8, 0),
            scene.truth_snapshot.missing_optional_visual_submissions,
        );
        try std.testing.expectEqual(
            @as(u8, 0),
            scene.truth_snapshot.orphan_optional_visual_submissions,
        );
    }
}

test "VF-03-R1 cross-layer validator rejects duplicate module and joint ownership defects" {
    var scene = try visual_foundation.Scene
        .initWithDiagnosticAllocatorAndComponentProof(
        std.testing.allocator,
        std.testing.allocator,
        .measure_only,
        .continuous_front,
    );
    defer scene.deinit();
    try scene.applyComponentProofCase(.continuous_front);
    scene.setDebugMode(.rig_registration);
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    queue.beginFrame();
    _ = try scene.submit(&queue);

    var records: [6]character_art.OptionalArmSubmission = undefined;
    const count = try collectMaleOptionalSubmissions(&scene, &records);
    try std.testing.expectEqual(@as(usize, 3), count);
    const male = &scene.integrated.production.male;
    _ = try character_art.validateOptionalArmSubmissions(
        male,
        .front,
        records[0..count],
    );

    records[count] = records[0];
    try std.testing.expectError(
        error.DuplicateOptionalArmVisualSubmission,
        character_art.validateOptionalArmSubmissions(
            male,
            .front,
            records[0 .. count + 1],
        ),
    );

    const original_module = records[0].module_id;
    records[0].module_id =
        try scene.integrated.production.definition.visual_definition
            .rigModuleId("extra_arm_module_second");
    try std.testing.expectError(
        error.OptionalArmModuleOwnershipMismatch,
        character_art.validateOptionalArmSubmissions(
            male,
            .front,
            records[0..count],
        ),
    );
    records[0].module_id = original_module;

    records[0].end_global_index += 1;
    try std.testing.expectError(
        error.OptionalArmJointBindingMismatch,
        character_art.validateOptionalArmSubmissions(
            male,
            .front,
            records[0..count],
        ),
    );
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

fn maleTruth(
    scene: *const visual_foundation.Scene,
) ?*const visual_truth.Character {
    const male_id = scene.integrated.production.male.id().raw();
    for (scene.truth_snapshot.characters[0..scene.truth_snapshot.character_count]) |*truth| {
        if (truth.id == male_id) return truth;
    }
    return null;
}

fn collectMaleOptionalSubmissions(
    scene: *const visual_foundation.Scene,
    output: *[6]character_art.OptionalArmSubmission,
) !usize {
    const male = &scene.integrated.production.male;
    var count: usize = 0;
    for (scene.truth_snapshot.visuals[0..scene.truth_snapshot.visual_count]) |visual| {
        if (visual.character_id != male.id().raw()) continue;
        const binding = visual.graph_binding orelse continue;
        if (count == output.len) return error.OptionalArmSubmissionCapacityExceeded;
        output[count] = .{
            .visual_id = try scene.integrated.production.definition
                .visual_definition.visualId(visual.stable_id.slice()),
            .component_id = @enumFromInt(binding.component_id),
            .module_id = @enumFromInt(binding.module_id),
            .start_kind = binding.start_kind,
            .start_global_index = binding.start_global_index,
            .end_kind = binding.end_kind,
            .end_global_index = binding.end_global_index,
            .view = male.presentationView(),
            .submission_index = visual.final_submission_index,
        };
        count += 1;
    }
    return count;
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
    var first = camera2d.Camera2D.initDefault();
    try first.setCenter(.{ .x = 3, .y = 0 });
    try first.setViewport(960, 540);
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

test "height-relative viewport keeps Prompt 27B safe-region center invariant" {
    var camera = camera2d.Camera2D.initDefault();
    const bounds = foundation_coherence.Bounds{
        .minimum = .{ .x = -1, .y = -2 },
        .maximum = .{ .x = 1, .y = 3 },
    };
    _ = try foundation_coherence.applyVerticalSafeRegion(&camera, bounds);
    const reference_center = camera.center;

    for ([_][2]u32{
        .{ 960, 540 },
        .{ 800, 510 },
        .{ 640, 480 },
    }) |viewport| {
        try camera.setViewport(viewport[0], viewport[1]);
        _ = try foundation_coherence.applyVerticalSafeRegion(&camera, bounds);
        try std.testing.expect(camera.center.approxEqAbs(reference_center, 0.000001));
    }
}

test "Prompt 27B centered resize placement leaves bounded follow-up slack" {
    var camera = camera2d.Camera2D.initDefault();
    try camera.setViewport(960, 540);
    const first_bounds = foundation_coherence.Bounds{
        .minimum = .{ .x = -1, .y = -2 },
        .maximum = .{ .x = 1, .y = 3 },
    };
    const resize_correction = try foundation_coherence.centerVerticalSafeRegion(
        &camera,
        first_bounds,
    );
    try std.testing.expect(resize_correction.measurement.passes());
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), camera.center.y, 0.000001);

    const previous = camera;
    const next_bounds = foundation_coherence.Bounds{
        .minimum = first_bounds.minimum.add(.{ .x = 0, .y = 0.25 }),
        .maximum = first_bounds.maximum.add(.{ .x = 0, .y = 0.25 }),
    };
    const follow_up = try foundation_coherence.applyVerticalSafeRegion(
        &camera,
        next_bounds,
    );
    try std.testing.expect(follow_up.measurement.passes());
    const camera_step_px = try foundation_coherence.worldCameraVerticalStepPx(
        previous,
        camera,
    );
    try std.testing.expect(
        camera_step_px <= foundation_coherence.maximum_camera_step_px,
    );
}

test "Prompt 27B abrupt resize separates first-frame reprojection from subsequent camera motion" {
    var previous = camera2d.Camera2D.initDefault();
    try previous.setCenter(.{ .x = 3, .y = 0 });
    try previous.setViewport(
        foundation_coherence.abrupt_resize_from_width,
        foundation_coherence.abrupt_resize_from_height,
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

test "production scene camera retains drawable-derived scale across later frames" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    var snapshots = input.SnapshotBuilder{};

    const first_snapshot = try snapshots.update(.{});
    try scene.updateFrame(1.0 / 60.0, first_snapshot);
    queue.beginFrame();
    _ = try scene.submit(&queue);
    _ = queue.prepare();
    const settled_center = scene.integrated.camera.center;

    const before_zero = scene.integrated.camera;
    try std.testing.expectError(error.ZeroViewport, scene.applyViewport(1920, 0));
    try std.testing.expectEqualDeep(before_zero, scene.integrated.camera);
    try scene.applyViewport(1920, 1080);
    try std.testing.expectApproxEqAbs(
        @as(f32, 184.5),
        scene.integrated.camera.pixels_per_meter,
        0.00001,
    );
    queue.beginFrame();
    _ = try scene.submit(&queue);
    _ = queue.prepare();
    try std.testing.expectEqual(settled_center, scene.integrated.camera.center);

    for (0..8) |_| {
        const snapshot = try snapshots.update(.{});
        try scene.updateFrame(1.0 / 60.0, snapshot);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
        try std.testing.expectApproxEqAbs(
            @as(f32, 184.5),
            scene.integrated.camera.pixels_per_meter,
            0.00001,
        );
    }
    try std.testing.expect(scene.integrated.camera.center.isFinite());
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
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .enforce_acceptance,
    );
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
    try std.testing.expect(!scene.presenceInteractionContext());
    try std.testing.expectEqual(
        @as(u64, 0),
        queue.lifetime_metrics.cpu_allocations_after_stabilization,
    );
    return .{
        .fingerprint = scene.authoritativeInteractionFingerprint(),
        .simulation_tick = scene.integrated.production.simulation_tick,
        .female_root = scene.integrated.production.female.worldPosition(),
        .male_root = scene.integrated.production.male.worldPosition(),
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

test "Prompt 27C-R1 interactive-equivalent overlap remains measured without termination" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
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

    var crossed_reported_condition = false;
    var crossed_partner = false;
    var moved_away = false;
    for (0..2_400) |render_frame| {
        const move_right = render_frame < 1_200;
        const snapshot = try snapshots.update(.{
            .keyboard = if (move_right) .{ .d = true } else .{ .a = true },
        });
        try scene.updateFrame(1.0 / 240.0, snapshot);
        queue.beginFrame();
        _ = try scene.submit(&queue);
        _ = queue.prepare();
        const measurement = scene.latest_presence orelse
            return error.MissingCharacterPresenceMeasurement;
        crossed_reported_condition = crossed_reported_condition or
            measurement.overlap_ratio >= 0.021407;
        crossed_partner = crossed_partner or
            scene.integrated.production.female.worldPosition().x >
                scene.integrated.production.male.worldPosition().x + 1;
        if (!move_right and crossed_partner and
            scene.integrated.production.female.worldPosition().x <
                scene.integrated.production.male.worldPosition().x - 1)
        {
            moved_away = true;
            break;
        }
    }
    try std.testing.expect(crossed_reported_condition);
    try std.testing.expect(crossed_partner);
    try std.testing.expect(moved_away);
    try std.testing.expect(scene.evidence.presence_violation_count > 0);
    try std.testing.expect(
        scene.evidence.maximum_ordinary_overlap_ratio > 0.02,
    );
}

test "Prompt 27C-R1 exact reported overlap is diagnostic interactively and fatal in acceptance" {
    const observed = visual_foundation.PresenceMeasurement{
        .render_frame = 0,
        .simulation_tick = 0,
        .female_position = .{ .x = -2.4, .y = 1.05 },
        .male_position = .{ .x = -1.4, .y = 1.05 },
        .overlap_ratio = 0.021407,
        .interaction_context = false,
        .passes_acceptance = foundation_coherence.overlapPasses(
            0.021407,
            false,
        ),
    };
    try std.testing.expect(!observed.passes_acceptance);
    try visual_foundation.enforcePresenceMeasurement(
        observed,
        .measure_only,
    );
    try std.testing.expectError(
        error.CharacterPresenceOverlapExceeded,
        visual_foundation.enforcePresenceMeasurement(
            observed,
            .enforce_acceptance,
        ),
    );
}

test "Prompt 27C-R1 presence interaction context follows active ownership and reset cancellation" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
    const male_position = scene.integrated.production.male.worldPosition();
    const female_position = math.Vec2{
        .x = male_position.x - 3.72,
        .y = male_position.y,
    };
    try scene.integrated.production.female.stageControlledTransform(
        female_position,
        scene.integrated.production.female.facingDirection(),
    );

    var snapshots = input.SnapshotBuilder{};
    const request = try snapshots.update(.{
        .keyboard = .{ .e = true },
    });
    try scene.updateFrame(1.0 / 240.0, request);
    try std.testing.expect(scene.presenceInteractionContext());
    try std.testing.expectEqual(@as(usize, 1), scene.manager.activeCount());

    try scene.resetWorld();
    try std.testing.expect(!scene.presenceInteractionContext());
    try std.testing.expectEqual(@as(usize, 0), scene.manager.activeCount());
    try std.testing.expect(scene.manager.lastTerminal() != null);
    try std.testing.expectEqual(
        interaction.Lifecycle.cancelled,
        scene.manager.lastTerminal().?.lifecycle,
    );
}

test "VF-01 F1 mode order wraps deterministically" {
    try std.testing.expectEqual(visual_truth.Mode.rig, visual_truth.Mode.off.next());
    try std.testing.expectEqual(
        visual_truth.Mode.rig_registration,
        visual_truth.Mode.rig.next(),
    );
    try std.testing.expectEqual(
        visual_truth.Mode.all_diagnostics,
        visual_truth.Mode.rig_registration.next(),
    );
    try std.testing.expectEqual(
        visual_truth.Mode.off,
        visual_truth.Mode.all_diagnostics.next(),
    );
}

test "VF-01 F1 modes preserve authoritative gameplay and survive reset" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
    var snapshots = input.SnapshotBuilder{};
    const authoritative_before = scene.authoritativeInteractionFingerprint();

    inline for (0..3) |_| {
        const press = try snapshots.update(.{ .keyboard = .{ .f1 = true } });
        try scene.updateFrame(0, press);
        const release = try snapshots.update(.{});
        try scene.updateFrame(0, release);
    }
    try std.testing.expectEqual(
        visual_truth.Mode.all_diagnostics,
        scene.debug_mode,
    );
    try std.testing.expectEqual(
        authoritative_before,
        scene.authoritativeInteractionFingerprint(),
    );
    try scene.resetWorld();
    try std.testing.expectEqual(
        visual_truth.Mode.all_diagnostics,
        scene.debug_mode,
    );
}

test "VF-01 F4 edge is frame-level consumed once and held input does not repeat" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
    var snapshots = input.SnapshotBuilder{};

    const first = try snapshots.update(.{ .keyboard = .{ .f4 = true } });
    try std.testing.expect(first.manual_debug_capture.pressed);
    try scene.updateFrame(0, first);
    try std.testing.expect(scene.takeManualCaptureRequest());
    try std.testing.expect(!scene.takeManualCaptureRequest());

    const held = try snapshots.update(.{ .keyboard = .{ .f4 = true } });
    try std.testing.expect(!held.manual_debug_capture.pressed);
    try scene.updateFrame(0, held);
    try std.testing.expect(!scene.takeManualCaptureRequest());

    _ = try snapshots.update(.{});
    const second = try snapshots.update(.{ .keyboard = .{ .f4 = true } });
    try scene.updateFrame(0, second);
    try std.testing.expect(scene.takeManualCaptureRequest());
    try std.testing.expectEqual(@as(u64, 2), scene.manual_capture_request_count);
}

test "VF-01 production snapshot emits every applicable stable truth category" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
    scene.setDebugMode(.all_diagnostics);
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    queue.markStabilized();
    queue.beginFrame();
    _ = try scene.submit(&queue);
    _ = queue.prepare();

    const counts = scene.truth_category_counts;
    try std.testing.expect(counts.physics_root_collider > 0);
    try std.testing.expect(counts.canonical_skeleton > 0);
    try std.testing.expect(counts.projected_skeleton > 0);
    try std.testing.expect(counts.sockets_attachments > 0);
    try std.testing.expect(counts.module_joints_sockets > 0);
    try std.testing.expect(counts.component_pivots > 0);
    try std.testing.expect(counts.atlas_landmarks > 0);
    try std.testing.expect(counts.alpha_visible_bounds > 0);
    try std.testing.expect(
        counts.clothing_hair_anchors + counts.mismatch_errors > 0,
    );
    for (scene.truth_snapshot.mismatches[0..scene.truth_snapshot.mismatch_count]) |mismatch| {
        const identity = mismatch.expected_target.slice();
        try std.testing.expect(identity.len > 0);
        try std.testing.expect(std.mem.indexOfScalar(u8, identity, 0) == null);
        if (std.mem.eql(u8, mismatch.component.slice(), "hair") and
            mismatch.has_expected_target)
        {
            try std.testing.expect(std.mem.endsWith(u8, identity, "hair"));
        }
    }
    try std.testing.expectEqual(
        @as(u64, 0),
        queue.lifetime_metrics.cpu_allocations_after_stabilization,
    );
}

test "VF-02 production front and reflected side routes use authoritative registration" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    queue.markStabilized();

    try scene.integrated.production.female.setPresentationOverride(.force_front);
    try scene.integrated.production.male.setPresentationOverride(.force_front);
    try submitAndExpectRegisteredView(&scene, &queue, .front);

    try scene.integrated.production.female.setPresentationOverride(.force_side);
    try scene.integrated.production.male.setPresentationOverride(.force_side);
    try scene.integrated.production.female.setFacing(.right);
    try scene.integrated.production.male.setFacing(.right);
    try submitAndExpectRegisteredView(&scene, &queue, .side_right);

    try scene.integrated.production.female.setFacing(.left);
    try scene.integrated.production.male.setFacing(.left);
    try submitAndExpectRegisteredView(&scene, &queue, .side_left);

    try std.testing.expectEqual(
        @as(u64, 0),
        queue.lifetime_metrics.cpu_allocations_after_stabilization,
    );
}

const registered_component_ids = [_][]const u8{
    "torso",
    "pelvis",
    "left_upper_arm",
    "left_forearm",
    "right_upper_arm",
    "right_forearm",
    "left_thigh",
    "left_shin",
    "left_foot",
    "right_thigh",
    "right_shin",
    "right_foot",
    "nose",
};

fn submitAndExpectRegisteredView(
    scene: *visual_foundation.Scene,
    queue: *render_queue.UnifiedRenderQueue,
    expected_view: visual_geometry.View,
) !void {
    queue.beginFrame();
    _ = try scene.submit(queue);
    _ = queue.prepare();

    var female_counts = [_]u8{0} ** registered_component_ids.len;
    var male_counts = [_]u8{0} ** registered_component_ids.len;
    var registered_shoe_count: u8 = 0;
    var registered_graph_point_count: u8 = 0;
    for (scene.visual_trace.slice()) |record| {
        const registered_index = registeredComponentIndex(record.stable_id);
        if (registered_index) |index| {
            try std.testing.expectEqual(
                visual_geometry.RegistrationAuthority.authoritative_registration,
                record.placement_authority,
            );
            const registration = record.registration orelse
                return error.MissingProductionRegistrationEvidence;
            try std.testing.expectEqual(expected_view, record.view);
            try std.testing.expect(registration.maximum_residual_m <= registration.threshold_m);
            try std.testing.expect(std.math.isFinite(registration.maximum_residual_m));
            const expected_mode: visual_geometry.RegistrationBindingMode =
                if (std.mem.eql(u8, record.stable_id, "torso") or
                std.mem.eql(u8, record.stable_id, "pelvis"))
                    .frame
                else if (std.mem.endsWith(u8, record.stable_id, "_foot") and
                expected_view == .front)
                    .point_axis
                else if (std.mem.eql(u8, record.stable_id, "nose") or
                std.mem.endsWith(u8, record.stable_id, "_foot"))
                    .point
                else
                    .segment;
            try std.testing.expectEqual(expected_mode, registration.binding_mode);
            try std.testing.expectEqual(
                @as(u8, switch (expected_mode) {
                    .point => 1,
                    .point_axis => 1,
                    .segment => 2,
                    .frame => 3,
                    .mesh_bridge => return error.UnexpectedProductionMeshBridge,
                }),
                registration.point_count,
            );
            if (record.character_id == scene.integrated.production.female.id().raw()) {
                female_counts[index] += 1;
            } else if (record.character_id == scene.integrated.production.male.id().raw()) {
                male_counts[index] += 1;
            } else {
                return error.UnknownProductionRegistrationCharacter;
            }
        } else if (isGraphPointComponent(record.stable_id)) {
            try std.testing.expectEqual(
                visual_geometry.RegistrationAuthority.authoritative_registration,
                record.placement_authority,
            );
            const registration = record.registration orelse
                return error.MissingComponentGraphPointRegistrationEvidence;
            try std.testing.expectEqual(expected_view, record.view);
            try std.testing.expectEqual(
                visual_geometry.RegistrationBindingMode.point,
                registration.binding_mode,
            );
            try std.testing.expectEqual(@as(u8, 1), registration.point_count);
            try std.testing.expect(
                registration.maximum_residual_m <= registration.threshold_m,
            );
            registered_graph_point_count += 1;
        } else if (std.mem.eql(u8, record.stable_id, "crimson_strap_shoe")) {
            try std.testing.expectEqual(
                visual_geometry.RegistrationAuthority.authoritative_registration,
                record.placement_authority,
            );
            const registration = record.registration orelse
                return error.MissingProductionShoeRegistrationEvidence;
            try std.testing.expectEqual(expected_view, record.view);
            try std.testing.expectEqual(
                visual_geometry.RegistrationBindingMode.point_axis,
                registration.binding_mode,
            );
            try std.testing.expectEqual(
                visual_geometry.RegistrationScalePolicy.point_axis_authored,
                registration.scale_policy,
            );
            try std.testing.expectEqual(@as(u8, 1), registration.point_count);
            try std.testing.expectEqual(
                visual_geometry.LandmarkKind.ankle,
                registration.points[0].source_landmark,
            );
            try std.testing.expect(registration.axis != null);
            try std.testing.expect(
                registration.maximum_residual_m <= registration.threshold_m,
            );
            registered_shoe_count += 1;
        } else {
            try std.testing.expect(record.registration == null);
            try std.testing.expect(record.placement_authority != .authoritative_registration);
        }
    }
    try std.testing.expectEqual(
        @as(u8, if (expected_view == .front) 10 else 6),
        registered_graph_point_count,
    );
    for (female_counts, male_counts) |female_count, male_count| {
        try std.testing.expectEqual(@as(u8, 1), female_count);
        try std.testing.expectEqual(@as(u8, 1), male_count);
    }
    try std.testing.expectEqual(@as(u8, 4), registered_shoe_count);
}

fn isGraphPointComponent(stable_id: []const u8) bool {
    return std.mem.eql(u8, stable_id, "left_eye") or
        std.mem.eql(u8, stable_id, "right_eye") or
        std.mem.eql(u8, stable_id, "left_eyebrow") or
        std.mem.eql(u8, stable_id, "right_eyebrow") or
        std.mem.eql(u8, stable_id, "hair");
}

fn registeredComponentIndex(stable_id: []const u8) ?usize {
    for (registered_component_ids, 0..) |expected, index| {
        if (std.mem.eql(u8, stable_id, expected)) return index;
    }
    return null;
}

test "VF-01 command buffer overflow fails rather than truncating" {
    var commands = debug_draw.CommandBuffer{};
    commands.beginFrame();
    for (0..debug_draw.command_capacity) |index| {
        try commands.addMarker(
            .{ .x = @floatFromInt(index), .y = 0 },
            visual_truth.colors.canonical,
        );
    }
    try std.testing.expectError(
        error.DebugCommandCapacityExceeded,
        commands.addMarker(.{ .x = 0, .y = 1 }, visual_truth.colors.mismatch),
    );
    try std.testing.expectEqual(debug_draw.command_capacity, commands.count);
    try std.testing.expectEqual(@as(u64, 1), commands.overflow_count);
}

test "VF-01 clean and debug queue generation share one frozen production state" {
    var scene = try visual_foundation.Scene.init(
        std.testing.allocator,
        .measure_only,
    );
    defer scene.deinit();
    var queue = try render_queue.UnifiedRenderQueue.init(
        std.testing.allocator,
        render_queue.default_entry_capacity,
        render_queue.default_sprite_capacity,
        render_queue.default_mesh_capacity,
        visual_foundation.configured_texture_page_count,
    );
    defer queue.deinit();
    scene.manual_capture_pending = true;
    queue.beginFrame();
    _ = try scene.submit(&queue);
    try scene.bindTruthRenderFrame(71);
    const tick_before = scene.integrated.production.simulation_tick;
    const live_before = scene.authoritativeInteractionFingerprint();
    const authoritative = scene.truth_snapshot.authoritative_fingerprint;
    const presentation = scene.truth_snapshot.presentation_fingerprint;
    const capture = scene.truth_snapshot.capture_fingerprint;

    _ = try scene.submitManualTruthOverlay(&queue);
    try scene.refreshTruthSnapshot(71);
    try std.testing.expectEqual(
        tick_before,
        scene.integrated.production.simulation_tick,
    );
    try std.testing.expectEqual(
        live_before,
        scene.authoritativeInteractionFingerprint(),
    );
    try std.testing.expectEqual(
        authoritative,
        scene.truth_snapshot.authoritative_fingerprint,
    );
    try std.testing.expectEqual(
        presentation,
        scene.truth_snapshot.presentation_fingerprint,
    );
    try std.testing.expectEqual(
        capture,
        scene.truth_snapshot.capture_fingerprint,
    );
}

test "VF-01 incomplete bundles stay hidden and timestamp collisions advance counter" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var base_buffer: [160]u8 = undefined;
    const base = try vf01TemporaryBase(&tmp, &base_buffer);
    const timestamp = "20260729T184533.482Z";
    const first = try visual_truth.Bundle.begin(
        std.testing.io,
        base,
        timestamp,
        3,
    );
    const second = try visual_truth.Bundle.begin(
        std.testing.io,
        base,
        timestamp,
        3,
    );
    try std.testing.expectEqual(@as(u64, 3), first.capture_index);
    try std.testing.expectEqual(@as(u64, 4), second.capture_index);
    try std.testing.expect(!first.finalized);
    try std.testing.expectError(
        error.FileNotFound,
        std.Io.Dir.cwd().access(std.testing.io, first.finalDirectory(), .{}),
    );
    try std.testing.expect(
        visual_truth.isManualCaptureId(first.captureId()),
    );
}

test "VF-01 bundle schema summary fingerprints and manifest hashes agree" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var base_buffer: [160]u8 = undefined;
    const base = try vf01TemporaryBase(&tmp, &base_buffer);
    const timestamp = "20260729T184534.007Z";
    var bundle = try visual_truth.Bundle.begin(
        std.testing.io,
        base,
        timestamp,
        9,
    );
    const snapshot = try std.testing.allocator.create(visual_truth.Snapshot);
    defer std.testing.allocator.destroy(snapshot);
    snapshot.* = .{
        .mode = .all_diagnostics,
        .render_frame = 77,
        .simulation_tick = 91,
        .viewport = .{ 1280, 720 },
        .camera_center = .{ .x = 1.5, .y = -0.25 },
        .pixels_per_meter = 82,
        .authoritative_fingerprint = 0x1111222233334444,
        .presentation_fingerprint = 0x5555666677778888,
        .capture_fingerprint = 0x9999aaaabbbbcccc,
        .visual_count = 1,
        .mismatch_count = 2,
    };
    snapshot.visuals[0] = .{
        .character_id = 1,
        .stable_id = try visual_truth.Text.init("left_foot"),
        .owner = .anatomy,
        .role = .foot,
        .side = .left,
        .component_id = 3,
        .bound_identity = 4,
        .region_id = 5,
        .texture_page = 6,
        .source = .{ .x = 1, .y = 2, .width = 3, .height = 4 },
        .uv_rect = .{ 0.1, 0.2, 0.3, 0.4 },
        .world_position = .{ .x = 7, .y = 8 },
        .rotation = 0.25,
        .scale = .{ .x = 1.5, .y = 2.5 },
        .pivot = .{ 0.5, 0.1 },
        .draw_order_key = .{
            .scene_layer = 1,
            .interaction_layer = 2,
            .actor_layer = 3,
            .body_part_layer = 4,
            .submission_index = 5,
        },
        .view = .front,
        .facing = try visual_truth.Text.init("front_identity_preserved"),
        .alpha_bounds_minimum = .{ .x = 6.5, .y = 7.5 },
        .alpha_bounds_maximum = .{ .x = 7.5, .y = 8.5 },
        .landmark_count = 0,
        .landmarks = undefined,
        .final_submission_index = 5,
        .is_mesh = false,
        .submission_visibility = .suppressed_by_closed_footwear,
        .placement_authority = .authoritative_registration,
        .has_registration = true,
        .registration_identity = try visual_truth.Text.init("left_foot"),
        .registration_binding_mode = .point_axis,
        .registration_scale_policy = .point_axis_authored,
        .registration_mirroring_policy = .view_reflection,
        .registration_threshold_m = 0.00001,
        .registration_maximum_residual_m = 0.000001,
        .registration_axis = .{
            .source_start_landmark = .sole_back,
            .source_end_landmark = .sole_front,
            .reference_identity = "left_foot.support_tangent",
            .source_start_local = .{ 0.1, 0.2 },
            .source_end_local = .{ 0.9, 0.2 },
            .reference_vector_world = .{ .x = -0.275637, .y = 0 },
            .transformed_start_world = .{ .x = 7.2, .y = 7.5 },
            .transformed_end_world = .{ .x = 6.8, .y = 7.5 },
            .expected_end_world = .{ .x = 6.8, .y = 7.5 },
            .endpoint_residual_m = 0,
            .angular_residual_radians = 0,
            .threshold_radians = 0.00001,
        },
    };
    snapshot.mismatches[0] = try vf01Mismatch(
        "female.left_thigh",
        "projected_hip",
        "hip",
        1.18,
        .pass,
    );
    snapshot.mismatches[1] = try vf01Mismatch(
        "female.left_upper_arm",
        "projected_shoulder",
        "shoulder",
        13.42,
        .fail,
    );
    const provenance = vf01Provenance(snapshot, timestamp, bundle.capture_index);
    try writeVf01TestPng(&bundle, "clean.png");
    try writeVf01TestPng(&bundle, "debug.png");
    try bundle.writeStateJson(std.testing.io, snapshot, provenance);
    try bundle.writeSummary(
        std.testing.io,
        snapshot,
        provenance,
        .{
            .canonical_skeleton = 2,
            .projected_skeleton = 2,
            .mismatch_errors = 1,
        },
    );
    try bundle.finalize(
        std.testing.allocator,
        std.testing.io,
        snapshot,
        provenance,
        &.{},
    );
    try std.testing.expect(bundle.finalized);

    var state_path_buffer: [384]u8 = undefined;
    const state_path = try std.fmt.bufPrint(
        &state_path_buffer,
        "{s}/state.json",
        .{bundle.finalDirectory()},
    );
    const state = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        state_path,
        std.testing.allocator,
        .limited(2 * 1024 * 1024),
    );
    defer std.testing.allocator.free(state);
    var parsed_state = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        state,
        .{},
    );
    defer parsed_state.deinit();
    const root = parsed_state.value.object;
    try std.testing.expect(root.get("schema_version") != null);
    try std.testing.expect(root.get("capture_provenance") != null);
    try std.testing.expect(root.get("state_identity") != null);
    try std.testing.expect(root.get("characters") != null);
    try std.testing.expect(root.get("final_visual_submissions") != null);
    try std.testing.expect(root.get("mismatches") != null);
    try std.testing.expectEqual(
        @as(i64, visual_truth.schema_version),
        root.get("schema_version").?.integer,
    );
    const visual_submission =
        root.get("final_visual_submissions").?.array.items[0].object;
    try std.testing.expectEqualStrings(
        "authoritative_registration",
        visual_submission.get("placement_authority").?.string,
    );
    const registration = visual_submission.get("registration").?.object;
    try std.testing.expectEqualStrings(
        "point_axis",
        registration.get("binding_mode").?.string,
    );
    try std.testing.expectEqualStrings(
        "suppressed_by_closed_footwear",
        visual_submission.get("submission_visibility").?.string,
    );
    try std.testing.expectEqualStrings(
        "closed_footwear",
        visual_submission.get("covered_base_visual_owner").?.string,
    );
    try std.testing.expectEqualStrings(
        "ankle",
        visual_submission.get("exposed_anatomy_anchor").?.string,
    );
    const orientation_axis = registration.get("orientation_axis").?.object;
    try std.testing.expectEqualStrings(
        "left_foot.support_tangent",
        orientation_axis.get("reference_identity").?.string,
    );
    try std.testing.expect(
        registration.get("maximum_residual_m").?.float <=
            registration.get("threshold_m").?.float,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, state, "9999aaaabbbbcccc") != null,
    );

    var summary_path_buffer: [384]u8 = undefined;
    const summary_path = try std.fmt.bufPrint(
        &summary_path_buffer,
        "{s}/summary.txt",
        .{bundle.finalDirectory()},
    );
    const summary = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        summary_path,
        std.testing.allocator,
        .limited(1024 * 1024),
    );
    defer std.testing.allocator.free(summary);
    const failed_position =
        std.mem.indexOf(u8, summary, "female.left_upper_arm") orelse
        return error.MissingFailedSummaryEntry;
    const passed_position =
        std.mem.indexOf(u8, summary, "female.left_thigh") orelse
        return error.MissingPassedSummaryEntry;
    try std.testing.expect(failed_position < passed_position);

    var manifest_path_buffer: [384]u8 = undefined;
    const manifest_path = try std.fmt.bufPrint(
        &manifest_path_buffer,
        "{s}/manifest.json",
        .{bundle.finalDirectory()},
    );
    const manifest = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        manifest_path,
        std.testing.allocator,
        .limited(1024 * 1024),
    );
    defer std.testing.allocator.free(manifest);
    var parsed_manifest = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        manifest,
        .{},
    );
    defer parsed_manifest.deinit();
    const manifest_root = parsed_manifest.value.object;
    try std.testing.expect(manifest_root.get("bundle_complete").?.bool);
    try std.testing.expectEqual(
        @as(usize, 4),
        manifest_root.get("files").?.array.items.len,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, manifest, "9999aaaabbbbcccc") != null,
    );
    const next = try visual_truth.Bundle.begin(
        std.testing.io,
        base,
        "20260729T184535.008Z",
        0,
    );
    try std.testing.expectEqual(@as(u64, 10), next.capture_index);
}

test "VF-01 automated evidence names remain deterministic and untimestamped" {
    const names = [_][]const u8{
        "initial_idle",
        "walk_right",
        "airborne_rise",
        "landing_grounded",
        "all_diagnostics",
    };
    for (names) |name| {
        try std.testing.expect(!visual_truth.isManualCaptureId(name));
    }
    try std.testing.expect(
        visual_truth.isManualCaptureId("20260729T184533.482Z_0003"),
    );
}

fn vf01TemporaryBase(
    tmp: *const std.testing.TmpDir,
    buffer: []u8,
) ![]const u8 {
    return std.fmt.bufPrint(
        buffer,
        ".zig-cache/tmp/{s}/vf01_bundles",
        .{tmp.sub_path[0..]},
    );
}

fn vf01Provenance(
    snapshot: *const visual_truth.Snapshot,
    timestamp: []const u8,
    capture_index: u64,
) visual_truth.CaptureProvenance {
    return .{
        .utc_timestamp = timestamp,
        .capture_index = capture_index,
        .git_head = "0e9bfcb733ad24ae167acf8deb43540917cbb641",
        .staged_dirty = false,
        .unstaged_dirty = true,
        .untracked_dirty = false,
        .build_configuration = "Debug",
        .executable_arguments = "--demo foundation --scripted-input",
        .gpu_driver = "direct3d12",
        .shader_format = "DXIL",
        .clean_render_frame = snapshot.render_frame,
        .debug_render_frame = snapshot.render_frame,
        .clean_simulation_tick = snapshot.simulation_tick,
        .debug_simulation_tick = snapshot.simulation_tick,
        .authoritative_before = snapshot.authoritative_fingerprint,
        .authoritative_after = snapshot.authoritative_fingerprint,
        .presentation_before = snapshot.presentation_fingerprint,
        .presentation_after = snapshot.presentation_fingerprint,
        .capture_before = snapshot.capture_fingerprint,
        .capture_after = snapshot.capture_fingerprint,
    };
}

fn vf01Mismatch(
    component: []const u8,
    expected: []const u8,
    atlas: []const u8,
    pixel_error: f32,
    result: visual_truth.MismatchResult,
) !visual_truth.Mismatch {
    return .{
        .character_id = 2,
        .component = try visual_truth.Text.init(component),
        .expected_target = try visual_truth.Text.init(expected),
        .atlas_landmark = try visual_truth.Text.init(atlas),
        .expected_world = .{ .x = 1, .y = 2 },
        .transformed_atlas_world = .{ .x = 1.1, .y = 2.1 },
        .has_expected_target = true,
        .world_error_m = 0.1,
        .pixel_error = pixel_error,
        .threshold_px = 2,
        .result = result,
    };
}

fn writeVf01TestPng(
    bundle: *const visual_truth.Bundle,
    filename: []const u8,
) !void {
    var path_buffer: [384]u8 = undefined;
    const path = try bundle.filePath(&path_buffer, filename);
    var file = try std.Io.Dir.cwd().createFile(std.testing.io, path, .{});
    defer file.close(std.testing.io);
    const rgba = [_]u8{ 0x22, 0x44, 0x66, 0xff };
    try visual_truth.writeRgbaPng(
        &file,
        std.testing.io,
        &rgba,
        1,
        1,
        4,
    );
}
