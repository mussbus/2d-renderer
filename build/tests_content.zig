const std = @import("std");
const modules_build = @import("modules.zig");

pub const Options = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    modules: *const modules_build.Catalog,
};

pub const Registration = struct {
    content_tests: *std.Build.Step,
    visual_geometry_test_step: *std.Build.Step,
    environment_art_audit: *std.Build.Step.Run,
    run_image_decode: *std.Build.Step.Run,
    run_foundation: *std.Build.Step.Run,
    run_wardrobe: *std.Build.Step.Run,
    run_environment: *std.Build.Step.Run,
    run_visual_foundation: *std.Build.Step.Run,
};

pub fn register(options: Options) Registration {
    const b = options.b;
    const target = options.target;
    const optimize = options.optimize;
    const modules = options.modules;

    const art_test_module = b.createModule(.{
        .root_source_file = b.path("tests/art_pipeline_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    art_test_module.addImport("art_pack", modules.art_pack_module);
    art_test_module.addImport("art_asset_catalog", modules.art_asset_catalog_module);
    art_test_module.addImport("art_asset_demo", modules.art_asset_demo_module);
    art_test_module.addImport("render_queue", modules.render_queue_module);
    const art_tests = b.addTest(.{ .name = "art-pipeline-tests", .root_module = art_test_module });
    const run_art_tests = b.addRunArtifact(art_tests);
    const image_decode_test_module = b.createModule(.{
        .root_source_file = b.path("tests/image_decode_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    image_decode_test_module.addImport("image_decode", modules.image_decode_module);
    const image_decode_tests = b.addTest(.{ .name = "image-decode-tests", .root_module = image_decode_test_module });
    const run_image_decode_tests = b.addRunArtifact(image_decode_tests);
    const art_test_step = b.step("test-art", "Run the Prompt 23 art-definition, PNG-decoder, and renderer-routing tests");
    art_test_step.dependOn(&run_art_tests.step);
    art_test_step.dependOn(&run_image_decode_tests.step);
    const presentation_test_module = b.createModule(.{
        .root_source_file = b.path("tests/character_presentation_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    presentation_test_module.addImport("input", modules.input_module);
    presentation_test_module.addImport("humanoid", modules.humanoid_module);
    presentation_test_module.addImport("character", modules.character_module);
    presentation_test_module.addImport("presentation_view", modules.presentation_view_module);
    presentation_test_module.addImport("presentation_pose", modules.presentation_pose_module);
    presentation_test_module.addImport("character_art", modules.character_art_module);
    presentation_test_module.addImport("modular_body_demo", modules.modular_body_demo_module);
    presentation_test_module.addImport("modular_humanoid", modules.modular_humanoid_module);
    presentation_test_module.addImport("handshake_ik_demo", modules.handshake_ik_demo_module);
    presentation_test_module.addImport("render_queue", modules.render_queue_module);
    const presentation_tests = b.addTest(.{
        .name = "character-presentation-tests",
        .root_module = presentation_test_module,
    });
    const run_presentation_tests = b.addRunArtifact(presentation_tests);
    const presentation_test_step = b.step(
        "test-presentation",
        "Run the Prompt 24 view-policy, character-art, interaction, and steady-state tests",
    );
    presentation_test_step.dependOn(&run_presentation_tests.step);
    const component_graph_test_module = b.createModule(.{
        .root_source_file = b.path("tests/component_graph_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    component_graph_test_module.addImport("math", modules.math_module);
    component_graph_test_module.addImport("anatomy", modules.anatomy_module);
    component_graph_test_module.addImport("appearance", modules.appearance_module);
    component_graph_test_module.addImport("component_graph", modules.component_graph_module);
    component_graph_test_module.addImport("humanoid", modules.humanoid_module);
    component_graph_test_module.addImport("character", modules.character_module);
    component_graph_test_module.addImport("modular_body_demo", modules.modular_body_demo_module);
    component_graph_test_module.addImport("presentation_pose", modules.presentation_pose_module);
    const component_graph_tests = b.addTest(.{
        .name = "component-graph-tests",
        .root_module = component_graph_test_module,
    });
    const run_component_graph_tests = b.addRunArtifact(component_graph_tests);
    const component_graph_test_step = b.step(
        "test-component-graph",
        "Run VF-03 typed topology, optional module, projection, and fail-closed tests",
    );
    component_graph_test_step.dependOn(&run_component_graph_tests.step);
    const wardrobe_test_module = b.createModule(.{
        .root_source_file = b.path("tests/wardrobe_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    wardrobe_test_module.addImport("math", modules.math_module);
    wardrobe_test_module.addImport("input", modules.input_module);
    wardrobe_test_module.addImport("character_controller", modules.character_controller_module);
    wardrobe_test_module.addImport("equipment", modules.equipment_module);
    wardrobe_test_module.addImport("humanoid", modules.humanoid_module);
    wardrobe_test_module.addImport("character", modules.character_module);
    wardrobe_test_module.addImport("presentation_view", modules.presentation_view_module);
    wardrobe_test_module.addImport("wardrobe_catalog", modules.wardrobe_catalog_module);
    wardrobe_test_module.addImport("wardrobe_art", modules.wardrobe_art_module);
    wardrobe_test_module.addImport("wardrobe_presentation", modules.wardrobe_presentation_module);
    wardrobe_test_module.addImport("wardrobe_demo", modules.wardrobe_demo_module);
    wardrobe_test_module.addImport("modular_humanoid", modules.modular_humanoid_module);
    wardrobe_test_module.addImport("authored_clips", modules.authored_clips_module);
    wardrobe_test_module.addImport("render_queue", modules.render_queue_module);
    wardrobe_test_module.addImport("character_art", modules.character_art_module);
    wardrobe_test_module.addImport("visual_geometry", modules.visual_geometry_module);
    const wardrobe_tests = b.addTest(.{
        .name = "wardrobe-tests",
        .root_module = wardrobe_test_module,
    });
    const run_wardrobe_tests = b.addRunArtifact(wardrobe_tests);
    const wardrobe_test_step = b.step(
        "test-wardrobe",
        "Run Prompt 25 wardrobe catalog, preset, view-binding, and steady-state tests",
    );
    wardrobe_test_step.dependOn(&run_wardrobe_tests.step);
    const visual_registration_test_module = b.createModule(.{
        .root_source_file = b.path("tests/visual_registration_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_registration_test_module.addImport("math", modules.math_module);
    visual_registration_test_module.addImport("sprite_batch", modules.sprite_batch_module);
    visual_registration_test_module.addImport("visual_geometry", modules.visual_geometry_module);
    visual_registration_test_module.addImport("visual_registration", modules.visual_registration_module);
    const visual_registration_tests = b.addTest(.{
        .name = "visual-registration-tests",
        .root_module = visual_registration_test_module,
    });
    const run_visual_registration_tests = b.addRunArtifact(visual_registration_tests);
    const visual_registration_test_step = b.step(
        "test-visual-registration",
        "Run VF-02 point, segment, frame, mesh-bridge, and fail-closed registration tests",
    );
    visual_registration_test_step.dependOn(&run_visual_registration_tests.step);
    const visual_geometry_test_module = b.createModule(.{
        .root_source_file = b.path("tests/visual_geometry_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_geometry_test_module.addImport("math", modules.math_module);
    visual_geometry_test_module.addImport("sprite_batch", modules.sprite_batch_module);
    visual_geometry_test_module.addImport("camera2d", modules.camera2d_module);
    visual_geometry_test_module.addImport("image_decode", modules.image_decode_module);
    visual_geometry_test_module.addImport("render_queue", modules.render_queue_module);
    visual_geometry_test_module.addImport("presentation_view", modules.presentation_view_module);
    visual_geometry_test_module.addImport("humanoid", modules.humanoid_module);
    visual_geometry_test_module.addImport("wardrobe_catalog", modules.wardrobe_catalog_module);
    visual_geometry_test_module.addImport("wardrobe_demo", modules.wardrobe_demo_module);
    visual_geometry_test_module.addImport("visual_geometry", modules.visual_geometry_module);
    visual_geometry_test_module.addImport("visual_geometry_audit", modules.visual_geometry_audit_module);
    visual_geometry_test_module.addImport("anatomy_quality", modules.anatomy_quality_module);
    const visual_geometry_tests = b.addTest(.{
        .name = "visual-geometry-tests",
        .root_module = visual_geometry_test_module,
    });
    const run_visual_geometry_tests = b.addRunArtifact(visual_geometry_tests);
    const visual_geometry_test_step = b.step(
        "test-visual-geometry",
        "Run Prompt 25D semantic landmark, alpha, fit, coverage, pose, and production acceptance",
    );
    visual_geometry_test_step.dependOn(&run_visual_geometry_tests.step);
    const foundation_test_module = b.createModule(.{
        .root_source_file = b.path("tests/foundation_playground_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    foundation_test_module.addImport("math", modules.math_module);
    foundation_test_module.addImport("input", modules.input_module);
    foundation_test_module.addImport("equipment", modules.equipment_module);
    foundation_test_module.addImport("render_queue", modules.render_queue_module);
    foundation_test_module.addImport("camera2d", modules.camera2d_module);
    foundation_test_module.addImport("foundation_playground", modules.foundation_playground_module);
    foundation_test_module.addImport("foundation_world", modules.foundation_world_module);
    const foundation_tests = b.addTest(.{ .name = "foundation-playground-tests", .root_module = foundation_test_module });
    const run_foundation_tests = b.addRunArtifact(foundation_tests);
    const foundation_test_step = b.step("test-foundation", "Run the Prompt 22 deterministic foundation-playground tests");
    foundation_test_step.dependOn(&run_foundation_tests.step);
    const environment_test_module = b.createModule(.{
        .root_source_file = b.path("tests/environment_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    environment_test_module.addImport("math", modules.math_module);
    environment_test_module.addImport("input", modules.input_module);
    environment_test_module.addImport("art_pack", modules.art_pack_module);
    environment_test_module.addImport("collider", modules.collider_module);
    environment_test_module.addImport("collision_world", modules.collision_world_module);
    environment_test_module.addImport("character", modules.character_module);
    environment_test_module.addImport("render_queue", modules.render_queue_module);
    environment_test_module.addImport("foundation_world", modules.foundation_world_module);
    environment_test_module.addImport("environment_art", modules.environment_art_module);
    environment_test_module.addImport("environment_theme", modules.environment_theme_module);
    environment_test_module.addImport("environment_demo", modules.environment_demo_module);
    const environment_tests = b.addTest(.{ .name = "environment-tests", .root_module = environment_test_module });
    const run_environment_tests = b.addRunArtifact(environment_tests);
    const environment_art_audit = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    environment_art_audit.addFileArg(b.path("tools/audit_p26_environment_art.ps1"));
    environment_art_audit.setName("audit Prompt 26 environment atlas geometry");
    const environment_test_step = b.step(
        "test-environment",
        "Run Prompt 26 theme, hot-swap, collision-surface, ordering, and invariance tests",
    );
    environment_test_step.dependOn(&run_environment_tests.step);
    environment_test_step.dependOn(&environment_art_audit.step);
    const visual_foundation_test_module = b.createModule(.{
        .root_source_file = b.path("tests/visual_foundation_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_foundation_test_module.addImport("math", modules.math_module);
    visual_foundation_test_module.addImport("input", modules.input_module);
    visual_foundation_test_module.addImport("interaction", modules.interaction_module);
    visual_foundation_test_module.addImport("handshake", modules.handshake_module);
    visual_foundation_test_module.addImport("presentation_view", modules.presentation_view_module);
    visual_foundation_test_module.addImport("render_queue", modules.render_queue_module);
    visual_foundation_test_module.addImport("camera2d", modules.camera2d_module);
    visual_foundation_test_module.addImport("acceptance_hud", modules.acceptance_hud_module);
    visual_foundation_test_module.addImport("foundation_evidence", modules.foundation_evidence_module);
    visual_foundation_test_module.addImport("foundation_coherence", modules.foundation_coherence_module);
    visual_foundation_test_module.addImport("visual_foundation", modules.visual_foundation_module);
    visual_foundation_test_module.addImport("visual_truth", modules.visual_truth_module);
    visual_foundation_test_module.addImport("visual_geometry", modules.visual_geometry_module);
    visual_foundation_test_module.addImport("debug_draw", modules.debug_draw_module);
    visual_foundation_test_module.addImport("anatomy", modules.anatomy_module);
    visual_foundation_test_module.addImport("character_art", modules.character_art_module);
    const visual_foundation_tests = b.addTest(.{
        .name = "visual-foundation-tests",
        .root_module = visual_foundation_test_module,
        .filters = if (b.option(
            []const u8,
            "visual-foundation-test-filter",
            "Run only visual-foundation tests whose names contain this text",
        )) |filter| &.{filter} else &.{},
    });
    const run_visual_foundation_tests = b.addRunArtifact(visual_foundation_tests);
    const visual_foundation_test_step = b.step(
        "test-visual-foundation",
        "Run Prompt 27 real-art integrated foundation and interaction-presentation tests",
    );
    visual_foundation_test_step.dependOn(&run_visual_foundation_tests.step);
    const canonical_model_core_tests = b.addTest(.{
        .name = "canonical-model-core-tests",
        .root_module = modules.canonical_model_core_test_module,
    });
    const run_canonical_model_core_tests = b.addRunArtifact(canonical_model_core_tests);
    const canonical_model_core_test_step = b.step(
        "test-canonical-model-core",
        "Run renderer-independent canonical model core-record tests",
    );
    canonical_model_core_test_step.dependOn(&run_canonical_model_core_tests.step);

    const canonical_model_phase_c_tests = b.addTest(.{
        .name = "canonical-model-phase-c-tests",
        .root_module = modules.canonical_model_phase_c_test_module,
    });
    const run_canonical_model_phase_c_tests = b.addRunArtifact(canonical_model_phase_c_tests);
    const canonical_model_phase_c_test_step = b.step(
        "test-canonical-model-phase-c",
        "Run renderer-independent morphology, material, visibility, and coverage record tests",
    );
    canonical_model_phase_c_test_step.dependOn(&run_canonical_model_phase_c_tests.step);

    const canonical_model_phase_de_tests = b.addTest(.{
        .name = "canonical-model-phase-de-tests",
        .root_module = modules.canonical_model_phase_de_test_module,
    });
    const run_canonical_model_phase_de_tests = b.addRunArtifact(canonical_model_phase_de_tests);
    const canonical_model_phase_de_test_step = b.step(
        "test-canonical-model-phase-de",
        "Run renderer-independent canonical normalization, hashing, validation, and trace tests",
    );
    canonical_model_phase_de_test_step.dependOn(&run_canonical_model_phase_de_tests.step);

    const canonical_model_phase_f_tests = b.addTest(.{
        .name = "canonical-model-phase-f-tests",
        .root_module = modules.canonical_model_phase_f_test_module,
    });
    const run_canonical_model_phase_f_tests = b.addRunArtifact(canonical_model_phase_f_tests);
    const canonical_model_phase_f_test_step = b.step(
        "test-canonical-model-phase-f",
        "Run renderer-independent M01 proof-fixture and determinism acceptance tests",
    );
    canonical_model_phase_f_test_step.dependOn(&run_canonical_model_phase_f_tests.step);

    const canonical_human_identity_tests = b.addTest(.{
        .name = "canonical-human-identity-tests",
        .root_module = modules.canonical_human_identity_test_module,
    });
    const run_canonical_human_identity_tests = b.addRunArtifact(canonical_human_identity_tests);
    const canonical_human_identity_test_step = b.step(
        "test-canonical-human-identity",
        "Run Prompt 2A human identity, component, semantic, material, and M01-golden tests",
    );
    canonical_human_identity_test_step.dependOn(&run_canonical_human_identity_tests.step);
    canonical_human_identity_test_step.dependOn(&run_canonical_model_phase_de_tests.step);
    canonical_human_identity_test_step.dependOn(&run_canonical_model_phase_f_tests.step);

    const canonical_human_rig_tests = b.addTest(.{
        .name = "canonical-human-rig-tests",
        .root_module = modules.canonical_human_rig_test_module,
    });
    const run_canonical_human_rig_tests = b.addRunArtifact(canonical_human_rig_tests);
    const canonical_human_rig_test_step = b.step(
        "test-canonical-human-rig",
        "Run Prompt 2B skeleton, rest-pose, measurement, symmetry, and activation tests",
    );
    canonical_human_rig_test_step.dependOn(&run_canonical_human_rig_tests.step);
    canonical_human_rig_test_step.dependOn(canonical_human_identity_test_step);

    const canonical_human_joint_control_tests = b.addTest(.{
        .name = "canonical-human-joint-control-tests",
        .root_module = modules.canonical_human_joint_control_test_module,
    });
    const run_canonical_human_joint_control_tests = b.addRunArtifact(canonical_human_joint_control_tests);
    const canonical_human_joint_control_test_step = b.step(
        "test-canonical-human-joint-controls",
        "Run Prompt 2C human joint, ROM, control, trace, and invalid-data tests",
    );
    canonical_human_joint_control_test_step.dependOn(&run_canonical_human_joint_control_tests.step);
    canonical_human_joint_control_test_step.dependOn(canonical_human_rig_test_step);

    const canonical_human_structural_tests = b.addTest(.{
        .name = "canonical-human-structural-tests",
        .root_module = modules.canonical_human_structural_test_module,
    });
    const run_canonical_human_structural_tests = b.addRunArtifact(canonical_human_structural_tests);
    const canonical_human_structural_test_step = b.step(
        "test-canonical-human-structural",
        "Run Prompt 2D anchor, socket, landmark, seam, site, effector, and proxy-decision tests",
    );
    canonical_human_structural_test_step.dependOn(&run_canonical_human_structural_tests.step);
    canonical_human_structural_test_step.dependOn(canonical_human_joint_control_test_step);

    const canonical_human_base_tests = b.addTest(.{
        .name = "canonical-human-base-acceptance-tests",
        .root_module = modules.canonical_human_base_test_module,
    });
    const run_canonical_human_base_tests = b.addRunArtifact(canonical_human_base_tests);
    const canonical_human_base_test_step = b.step(
        "test-canonical-human-base",
        "Run Prompt 2E file-backed human_base golden, determinism, evidence, and invalid-fixture tests",
    );
    canonical_human_base_test_step.dependOn(&run_canonical_human_base_tests.step);
    canonical_human_base_test_step.dependOn(canonical_human_structural_test_step);

    const canonical_geometry_tests = b.addTest(.{
        .name = "canonical-geometry-foundation-tests",
        .root_module = modules.canonical_geometry_test_module,
    });
    const run_canonical_geometry_tests = b.addRunArtifact(canonical_geometry_tests);
    const canonical_geometry_test_step = b.step(
        "test-canonical-geometry",
        "Run renderer-independent M03 canonical geometry schema and topology tests",
    );
    canonical_geometry_test_step.dependOn(&run_canonical_geometry_tests.step);

    const canonical_human_geometry_scaffold_tests = b.addTest(.{
        .name = "canonical-human-geometry-scaffold-tests",
        .root_module = modules.canonical_human_geometry_scaffold_test_module,
    });
    const run_canonical_human_geometry_scaffold_tests = b.addRunArtifact(canonical_human_geometry_scaffold_tests);
    const canonical_human_geometry_scaffold_test_step = b.step(
        "test-canonical-human-geometry-scaffold",
        "Run M03 Prompt 2B file-backed continuous human main-body scaffold tests",
    );
    canonical_human_geometry_scaffold_test_step.dependOn(&run_canonical_human_geometry_scaffold_tests.step);
    canonical_human_geometry_scaffold_test_step.dependOn(canonical_geometry_test_step);

    const canonical_human_geometry_refinement_tests = b.addTest(.{
        .name = "canonical-human-geometry-refinement-tests",
        .root_module = modules.canonical_human_geometry_refinement_test_module,
    });
    const run_canonical_human_geometry_refinement_tests = b.addRunArtifact(canonical_human_geometry_refinement_tests);
    const canonical_human_geometry_refinement_test_step = b.step(
        "test-canonical-human-geometry-refinement",
        "Run frozen M03 Prompt 2C and Prompt 2C-R1 historical-evidence tests",
    );
    canonical_human_geometry_refinement_test_step.dependOn(&run_canonical_human_geometry_refinement_tests.step);
    canonical_human_geometry_refinement_test_step.dependOn(canonical_human_geometry_scaffold_test_step);

    const canonical_human_geometry_adoption_tests = b.addTest(.{
        .name = "canonical-human-geometry-adoption-tests",
        .root_module = modules.canonical_human_geometry_adoption_test_module,
    });
    const run_canonical_human_geometry_adoption_tests = b.addRunArtifact(canonical_human_geometry_adoption_tests);
    const canonical_human_geometry_adoption_test_step = b.step(
        "test-canonical-human-geometry-adoption",
        "Run M03 Prompt 2C-T3 HM08 topology-reset, mapping, provenance, and determinism tests",
    );
    canonical_human_geometry_adoption_test_step.dependOn(&run_canonical_human_geometry_adoption_tests.step);
    canonical_human_geometry_adoption_test_step.dependOn(canonical_human_geometry_refinement_test_step);

    const canonical_human_geometry_r3_tests = b.addTest(.{
        .name = "canonical-human-geometry-r3-tests",
        .root_module = modules.canonical_human_geometry_r3_test_module,
    });
    const run_canonical_human_geometry_r3_tests = b.addRunArtifact(canonical_human_geometry_r3_tests);
    const canonical_human_geometry_r3_test_step = b.step(
        "test-canonical-human-geometry-r3",
        "Run M03 Prompt 2C-R3 neutral-human adaptation and evidence tests",
    );
    canonical_human_geometry_r3_test_step.dependOn(&run_canonical_human_geometry_r3_tests.step);
    canonical_human_geometry_r3_test_step.dependOn(canonical_human_geometry_adoption_test_step);

    const canonical_human_geometry_r4_tests = b.addTest(.{
        .name = "canonical-human-geometry-r4-tests",
        .root_module = modules.canonical_human_geometry_r4_test_module,
    });
    const run_canonical_human_geometry_r4_tests = b.addRunArtifact(canonical_human_geometry_r4_tests);
    const canonical_human_geometry_r4_test_step = b.step(
        "test-canonical-human-geometry-r4",
        "Run M03 Prompt 2C-R4 final neutral shared-human shape and evidence tests",
    );
    canonical_human_geometry_r4_test_step.dependOn(&run_canonical_human_geometry_r4_tests.step);
    canonical_human_geometry_r4_test_step.dependOn(canonical_human_geometry_r3_test_step);

    const canonical_human_geometry_full_tests = b.addTest(.{
        .name = "canonical-human-geometry-full-tests",
        .root_module = modules.canonical_human_geometry_full_test_module,
    });
    const run_canonical_human_geometry_full_tests = b.addRunArtifact(canonical_human_geometry_full_tests);
    const canonical_human_geometry_full_test_step = b.step(
        "test-canonical-human-geometry-full",
        "Run expensive M03 human-geometry self-intersection validation",
    );
    canonical_human_geometry_full_test_step.dependOn(&run_canonical_human_geometry_full_tests.step);
    canonical_human_geometry_full_test_step.dependOn(canonical_human_geometry_r4_test_step);

    const content_tests = b.step(
        "test-content-tests",
        "Run current canonical, authored-content, art, and visual qualification tests",
    );
    content_tests.dependOn(&run_art_tests.step);
    content_tests.dependOn(&run_image_decode_tests.step);
    content_tests.dependOn(&run_presentation_tests.step);
    content_tests.dependOn(&run_component_graph_tests.step);
    content_tests.dependOn(&run_wardrobe_tests.step);
    content_tests.dependOn(&run_visual_registration_tests.step);
    content_tests.dependOn(&run_visual_geometry_tests.step);
    content_tests.dependOn(&run_foundation_tests.step);
    content_tests.dependOn(&run_environment_tests.step);
    content_tests.dependOn(&run_visual_foundation_tests.step);
    content_tests.dependOn(&run_canonical_model_core_tests.step);
    content_tests.dependOn(&run_canonical_model_phase_c_tests.step);
    content_tests.dependOn(&run_canonical_model_phase_de_tests.step);
    content_tests.dependOn(&run_canonical_model_phase_f_tests.step);
    content_tests.dependOn(&run_canonical_human_identity_tests.step);
    content_tests.dependOn(&run_canonical_human_rig_tests.step);
    content_tests.dependOn(&run_canonical_human_joint_control_tests.step);
    content_tests.dependOn(&run_canonical_human_structural_tests.step);
    content_tests.dependOn(&run_canonical_human_base_tests.step);
    content_tests.dependOn(&run_canonical_geometry_tests.step);
    content_tests.dependOn(&run_canonical_human_geometry_scaffold_tests.step);
    content_tests.dependOn(&run_canonical_human_geometry_refinement_tests.step);
    content_tests.dependOn(&run_canonical_human_geometry_adoption_tests.step);
    content_tests.dependOn(&run_canonical_human_geometry_r3_tests.step);
    content_tests.dependOn(&run_canonical_human_geometry_r4_tests.step);
    content_tests.dependOn(&run_canonical_human_geometry_full_tests.step);

    return .{
        .content_tests = content_tests,
        .visual_geometry_test_step = visual_geometry_test_step,
        .environment_art_audit = environment_art_audit,
        .run_image_decode = run_image_decode_tests,
        .run_foundation = run_foundation_tests,
        .run_wardrobe = run_wardrobe_tests,
        .run_environment = run_environment_tests,
        .run_visual_foundation = run_visual_foundation_tests,
    };
}
