const std = @import("std");

pub const Options = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    sdl_include: []const u8,
    sdl_library_dir: []const u8,
};

pub const Catalog = struct {
    sdl_gpu_renderer_module: *std.Build.Module,
    secondary_motion_module: *std.Build.Module,
    secondary_motion_rate_module: *std.Build.Module,
    secondary_motion_test_module: *std.Build.Module,
    record_replay_module: *std.Build.Module,
    record_replay_proof_module: *std.Build.Module,
    record_replay_test_module: *std.Build.Module,
    effects_projectiles_entry_module: *std.Build.Module,
    projectile_effects_module: *std.Build.Module,
    projectiles_module: *std.Build.Module,
    effects_module: *std.Build.Module,
    effects_projectiles_test_module: *std.Build.Module,
    demo_entry_module: *std.Build.Module,
    engine_smoke_entry_module: *std.Build.Module,
    engine_lab_entry_module: *std.Build.Module,
    engine_lab_test_module: *std.Build.Module,
    engine_smoke_client_module: *std.Build.Module,
    engine_composition_test_module: *std.Build.Module,
    foundation_module: *std.Build.Module,
    world_module: *std.Build.Module,
    scene_core_module: *std.Build.Module,
    canonical_model_core_test_module: *std.Build.Module,
    canonical_model_phase_c_test_module: *std.Build.Module,
    canonical_model_phase_de_test_module: *std.Build.Module,
    canonical_model_phase_f_test_module: *std.Build.Module,
    canonical_human_identity_test_module: *std.Build.Module,
    canonical_human_rig_test_module: *std.Build.Module,
    canonical_human_joint_control_test_module: *std.Build.Module,
    canonical_human_structural_test_module: *std.Build.Module,
    canonical_human_base_test_module: *std.Build.Module,
    canonical_geometry_test_module: *std.Build.Module,
    foundation_primitive_test_module: *std.Build.Module,
    scene_core_authored_test_module: *std.Build.Module,
    scene_core_runtime_test_module: *std.Build.Module,
    scene_core_registry_test_module: *std.Build.Module,
    canonical_human_geometry_scaffold_test_module: *std.Build.Module,
    canonical_human_geometry_refinement_test_module: *std.Build.Module,
    canonical_human_geometry_adoption_test_module: *std.Build.Module,
    canonical_human_geometry_r3_test_module: *std.Build.Module,
    canonical_human_geometry_r4_test_module: *std.Build.Module,
    canonical_human_geometry_full_test_module: *std.Build.Module,
    test_module: *std.Build.Module,
    stress_test_module: *std.Build.Module,
    integration_test_module: *std.Build.Module,
    physical_input_module: *std.Build.Module,
    input_module: *std.Build.Module,
    sprite_batch_module: *std.Build.Module,
    art_pack_module: *std.Build.Module,
    presentation_view_module: *std.Build.Module,
    image_decode_module: *std.Build.Module,
    math_module: *std.Build.Module,
    camera2d_module: *std.Build.Module,
    visual_geometry_module: *std.Build.Module,
    visual_registration_module: *std.Build.Module,
    visual_geometry_audit_module: *std.Build.Module,
    anatomy_quality_module: *std.Build.Module,
    collider_module: *std.Build.Module,
    foundation_world_module: *std.Build.Module,
    collision_world_module: *std.Build.Module,
    character_controller_module: *std.Build.Module,
    render_queue_module: *std.Build.Module,
    art_asset_catalog_module: *std.Build.Module,
    art_pipeline_fixture_module: *std.Build.Module,
    appearance_module: *std.Build.Module,
    anatomy_module: *std.Build.Module,
    component_graph_module: *std.Build.Module,
    equipment_module: *std.Build.Module,
    humanoid_module: *std.Build.Module,
    modular_humanoid_module: *std.Build.Module,
    authored_clips_module: *std.Build.Module,
    character_module: *std.Build.Module,
    character_entity_binding_module: *std.Build.Module,
    interaction_module: *std.Build.Module,
    handshake_module: *std.Build.Module,
    presentation_pose_module: *std.Build.Module,
    character_art_module: *std.Build.Module,
    wardrobe_catalog_module: *std.Build.Module,
    wardrobe_art_module: *std.Build.Module,
    wardrobe_presentation_module: *std.Build.Module,
    handshake_ik_demo_module: *std.Build.Module,
    debug_draw_module: *std.Build.Module,
    visual_truth_module: *std.Build.Module,
    frame_capture_module: *std.Build.Module,
    integrated_demo_module: *std.Build.Module,
    modular_body_demo_module: *std.Build.Module,
    wardrobe_demo_module: *std.Build.Module,
    foundation_playground_module: *std.Build.Module,
    environment_art_module: *std.Build.Module,
    environment_theme_module: *std.Build.Module,
    environment_demo_module: *std.Build.Module,
    foundation_evidence_module: *std.Build.Module,
    foundation_coherence_module: *std.Build.Module,
    acceptance_hud_module: *std.Build.Module,
    visual_foundation_module: *std.Build.Module,
    camera_test_module: *std.Build.Module,
    canonical_model_module: *std.Build.Module,
    canonical_geometry_module: *std.Build.Module,
    canonical_human_geometry_module: *std.Build.Module,
};

pub fn register(options: Options) Catalog {
    const b = options.b;
    const target = options.target;
    const optimize = options.optimize;
    const sdl_include = options.sdl_include;
    const sdl_library_dir = options.sdl_library_dir;

    const foundation_module = b.createModule(.{
        .root_source_file = b.path("src/foundation/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const world_module = b.createModule(.{
        .root_source_file = b.path("src/world/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const scene_core_module = b.createModule(.{
        .root_source_file = b.path("src/scene_core/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_core_module.addImport("foundation", foundation_module);
    const current_transform2d_conformance_module = b.createModule(.{
        .root_source_file = b.path("src/math/transform2d.zig"),
        .target = target,
        .optimize = optimize,
    });
    const canonical_model_module = b.createModule(.{
        .root_source_file = b.path("src/canonical_model/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const canonical_geometry_module = b.createModule(.{
        .root_source_file = b.path("src/canonical_geometry/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_geometry_module.addImport("canonical_model", canonical_model_module);
    const canonical_human_geometry_module = b.createModule(.{
        .root_source_file = b.path("src/canonical_geometry/human_base/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_geometry_module.addImport("canonical_model", canonical_model_module);
    canonical_human_geometry_module.addImport("canonical_geometry", canonical_geometry_module);
    const canonical_model_core_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_model_core_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_model_core_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_model_phase_c_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_model_phase_c_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_model_phase_c_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_model_phase_de_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_model_phase_de_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_model_phase_de_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_model_phase_f_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_model_phase_f_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_model_phase_f_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_human_identity_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_identity_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_identity_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_human_rig_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_rig_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_rig_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_human_joint_control_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_joint_control_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_joint_control_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_human_structural_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_structural_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_structural_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_human_base_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_base_acceptance_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_base_test_module.addImport("canonical_model", canonical_model_module);
    const canonical_geometry_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_geometry_foundation_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_geometry_test_module.addImport("canonical_model", canonical_model_module);
    canonical_geometry_test_module.addImport("canonical_geometry", canonical_geometry_module);
    const foundation_primitive_test_module = b.createModule(.{
        .root_source_file = b.path("tests/foundation/test_foundation_primitives.zig"),
        .target = target,
        .optimize = optimize,
    });
    foundation_primitive_test_module.addImport("foundation", foundation_module);
    foundation_primitive_test_module.addImport("canonical_model", canonical_model_module);
    foundation_primitive_test_module.addImport("canonical_geometry", canonical_geometry_module);
    foundation_primitive_test_module.addImport("current_transform2d", current_transform2d_conformance_module);
    const scene_core_authored_test_module = b.createModule(.{
        .root_source_file = b.path("tests/scene_core/test_scene_core_authored.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_core_authored_test_module.addImport("foundation", foundation_module);
    scene_core_authored_test_module.addImport("scene_core", scene_core_module);
    const scene_core_runtime_test_module = b.createModule(.{
        .root_source_file = b.path("tests/scene_core/test_scene_core_runtime.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_core_runtime_test_module.addImport("foundation", foundation_module);
    scene_core_runtime_test_module.addImport("scene_core", scene_core_module);
    const scene_core_registry_test_module = b.createModule(.{
        .root_source_file = b.path("tests/scene_core/test_scene_core_registry_internal.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_core_registry_test_module.addImport("foundation", foundation_module);
    const scene_core_internal_test_module = b.createModule(.{
        .root_source_file = b.path("src/scene_core/internal_test_root.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_core_internal_test_module.addImport("foundation", foundation_module);
    scene_core_registry_test_module.addImport("scene_core_internal", scene_core_internal_test_module);
    const canonical_human_geometry_scaffold_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_geometry_scaffold_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_geometry_scaffold_test_module.addImport("canonical_geometry", canonical_geometry_module);
    canonical_human_geometry_scaffold_test_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const canonical_human_geometry_refinement_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_geometry_refinement_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_geometry_refinement_test_module.addImport("canonical_geometry", canonical_geometry_module);
    canonical_human_geometry_refinement_test_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const canonical_human_geometry_adoption_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_geometry_adoption_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_geometry_adoption_test_module.addImport("canonical_geometry", canonical_geometry_module);
    canonical_human_geometry_adoption_test_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const canonical_human_geometry_r3_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_geometry_r3_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_geometry_r3_test_module.addImport("canonical_geometry", canonical_geometry_module);
    canonical_human_geometry_r3_test_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const canonical_human_geometry_r4_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_geometry_r4_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_geometry_r4_test_module.addImport("canonical_geometry", canonical_geometry_module);
    canonical_human_geometry_r4_test_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const canonical_human_geometry_full_test_module = b.createModule(.{
        .root_source_file = b.path("tests/canonical_human_geometry_full_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    canonical_human_geometry_full_test_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const test_module = b.createModule(.{
        .root_source_file = b.path("tests/test_all.zig"),
        .target = target,
        .optimize = optimize,
    });
    const stress_test_module = b.createModule(.{
        .root_source_file = b.path("tests/stress_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const integration_test_module = b.createModule(.{
        .root_source_file = b.path("tests/integration_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const fault_injection_module = b.createModule(.{
        .root_source_file = b.path("src/platform/fault_injection.zig"),
        .target = target,
        .optimize = optimize,
    });
    const physical_input_module = b.createModule(.{
        .root_source_file = b.path("src/platform/input.zig"),
        .target = target,
        .optimize = optimize,
    });
    const character_intent_module = b.createModule(.{
        .root_source_file = b.path("src/physics/character_intent.zig"),
        .target = target,
        .optimize = optimize,
    });
    const input_module = b.createModule(.{
        .root_source_file = b.path("src/app/demo_actions.zig"),
        .target = target,
        .optimize = optimize,
    });
    input_module.addImport("physical_input", physical_input_module);
    input_module.addImport("character_intent", character_intent_module);
    const sdl_module = b.createModule(.{
        .root_source_file = b.path("src/platform/sdl.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    sdl_module.addIncludePath(b.path(sdl_include));
    const sdl_input_module = b.createModule(.{
        .root_source_file = b.path("src/platform/sdl_input.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    sdl_input_module.addIncludePath(b.path(sdl_include));
    sdl_input_module.addImport("physical_input", physical_input_module);
    sdl_input_module.addImport("sdl", sdl_module);
    const fixed_step_module = b.createModule(.{
        .root_source_file = b.path("src/physics/fixed_step.zig"),
        .target = target,
        .optimize = optimize,
    });
    const spring_module = b.createModule(.{
        .root_source_file = b.path("src/physics/spring.zig"),
        .target = target,
        .optimize = optimize,
    });
    const secondary_motion_module = b.createModule(.{
        .root_source_file = b.path("src/physics/secondary_motion.zig"),
        .target = target,
        .optimize = optimize,
    });
    secondary_motion_module.addImport("fixed_step", fixed_step_module);
    secondary_motion_module.addImport("spring", spring_module);
    const secondary_motion_rate_module = b.createModule(.{
        .root_source_file = b.path("src/physics/secondary_motion_rate.zig"),
        .target = target,
        .optimize = optimize,
    });
    secondary_motion_rate_module.addImport("secondary_motion", secondary_motion_module);
    secondary_motion_rate_module.addImport("fixed_step", fixed_step_module);
    const secondary_motion_test_module = b.createModule(.{
        .root_source_file = b.path("tests/psm01_secondary_motion_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    secondary_motion_test_module.addImport("secondary_motion", secondary_motion_module);
    secondary_motion_test_module.addImport("secondary_motion_rate", secondary_motion_rate_module);
    secondary_motion_test_module.addImport("fixed_step", fixed_step_module);
    secondary_motion_test_module.addImport("spring", spring_module);
    const sprite_batch_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/sprite_batch.zig"),
        .target = target,
        .optimize = optimize,
    });
    const art_pack_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/art_pack.zig"),
        .target = target,
        .optimize = optimize,
    });
    const presentation_view_module = b.createModule(.{
        .root_source_file = b.path("src/scene/presentation_view.zig"),
        .target = target,
        .optimize = optimize,
    });
    const image_decode_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/image_decode.zig"),
        .target = target,
        .optimize = optimize,
    });
    const math_module = b.createModule(.{
        .root_source_file = b.path("src/math/transform2d.zig"),
        .target = target,
        .optimize = optimize,
    });
    const attachment_secondary_motion_module = b.createModule(.{
        .root_source_file = b.path("src/animation/attachment_secondary_motion.zig"),
        .target = target,
        .optimize = optimize,
    });
    attachment_secondary_motion_module.addImport("math", math_module);
    attachment_secondary_motion_module.addImport("fixed_step", fixed_step_module);
    attachment_secondary_motion_module.addImport("spring", spring_module);
    const deformation_module = b.createModule(.{
        .root_source_file = b.path("src/scene/deformation.zig"),
        .target = target,
        .optimize = optimize,
    });
    deformation_module.addImport("math", math_module);
    deformation_module.addImport("fixed_step", fixed_step_module);
    const camera2d_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/camera2d.zig"),
        .target = target,
        .optimize = optimize,
    });
    camera2d_module.addImport("math", math_module);
    const visual_geometry_module = b.createModule(.{
        .root_source_file = b.path("src/scene/visual_geometry.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_geometry_module.addImport("math", math_module);
    visual_geometry_module.addImport("camera2d", camera2d_module);
    visual_geometry_module.addImport("sprite_batch", sprite_batch_module);
    const visual_registration_module = b.createModule(.{
        .root_source_file = b.path("src/scene/visual_registration.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_registration_module.addImport("math", math_module);
    visual_registration_module.addImport("sprite_batch", sprite_batch_module);
    visual_registration_module.addImport("visual_geometry", visual_geometry_module);
    const anatomy_evidence_module = b.createModule(.{
        .root_source_file = b.path("src/scene/anatomy_evidence.zig"),
        .target = target,
        .optimize = optimize,
    });
    anatomy_evidence_module.addImport("visual_geometry", visual_geometry_module);
    const visual_geometry_audit_module = b.createModule(.{
        .root_source_file = b.path("src/scene/visual_geometry_audit.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_geometry_audit_module.addImport("math", math_module);
    visual_geometry_audit_module.addImport("camera2d", camera2d_module);
    visual_geometry_audit_module.addImport("sprite_batch", sprite_batch_module);
    visual_geometry_audit_module.addImport("visual_geometry", visual_geometry_module);
    visual_geometry_audit_module.addImport("visual_registration", visual_registration_module);
    const anatomy_quality_module = b.createModule(.{
        .root_source_file = b.path("src/scene/anatomy_quality.zig"),
        .target = target,
        .optimize = optimize,
    });
    anatomy_quality_module.addImport("math", math_module);
    anatomy_quality_module.addImport("camera2d", camera2d_module);
    anatomy_quality_module.addImport("sprite_batch", sprite_batch_module);
    anatomy_quality_module.addImport("visual_geometry", visual_geometry_module);
    anatomy_quality_module.addImport("visual_geometry_audit", visual_geometry_audit_module);
    const collider_module = b.createModule(.{
        .root_source_file = b.path("src/physics/collider.zig"),
        .target = target,
        .optimize = optimize,
    });
    collider_module.addImport("math", math_module);
    const foundation_world_module = b.createModule(.{
        .root_source_file = b.path("src/scene/foundation_world.zig"),
        .target = target,
        .optimize = optimize,
    });
    foundation_world_module.addImport("math", math_module);
    foundation_world_module.addImport("collider", collider_module);
    const collision_world_module = b.createModule(.{
        .root_source_file = b.path("src/physics/collision_world.zig"),
        .target = target,
        .optimize = optimize,
    });
    collision_world_module.addImport("math", math_module);
    collision_world_module.addImport("collider", collider_module);
    collision_world_module.addImport("fault_injection", fault_injection_module);
    const character_controller_module = b.createModule(.{
        .root_source_file = b.path("src/physics/character_controller.zig"),
        .target = target,
        .optimize = optimize,
    });
    character_controller_module.addImport("math", math_module);
    character_controller_module.addImport("character_intent", character_intent_module);
    character_controller_module.addImport("collider", collider_module);
    character_controller_module.addImport("collision_world", collision_world_module);
    character_controller_module.addImport("fixed_step", fixed_step_module);
    const skeleton_module = b.createModule(.{
        .root_source_file = b.path("src/animation/skeleton.zig"),
        .target = target,
        .optimize = optimize,
    });
    skeleton_module.addImport("math", math_module);
    skeleton_module.addImport("fault_injection", fault_injection_module);
    const deformable_mesh_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/deformable_mesh.zig"),
        .target = target,
        .optimize = optimize,
    });
    deformable_mesh_module.addImport("math", math_module);
    deformable_mesh_module.addImport("deformation", deformation_module);
    deformable_mesh_module.addImport("skeleton", skeleton_module);
    const attachment_meshes_module = b.createModule(.{
        .root_source_file = b.path("src/scene/attachment_meshes.zig"),
        .target = target,
        .optimize = optimize,
    });
    attachment_meshes_module.addImport("math", math_module);
    attachment_meshes_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    attachment_meshes_module.addImport("deformable_mesh", deformable_mesh_module);
    const render_queue_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/render_queue.zig"),
        .target = target,
        .optimize = optimize,
    });
    render_queue_module.addImport("math", math_module);
    render_queue_module.addImport("deformable_mesh", deformable_mesh_module);
    render_queue_module.addImport("sprite_batch", sprite_batch_module);
    const art_asset_catalog_module = b.createModule(.{
        .root_source_file = b.path("src/scene/art_asset_catalog.zig"),
        .target = target,
        .optimize = optimize,
    });
    art_asset_catalog_module.addImport("art_pack", art_pack_module);
    const art_pipeline_fixture_module = b.createModule(.{
        .root_source_file = b.path("tests/support/art_pipeline_fixture.zig"),
        .target = target,
        .optimize = optimize,
    });
    art_pipeline_fixture_module.addImport("art_pack", art_pack_module);
    art_pipeline_fixture_module.addImport("art_asset_catalog", art_asset_catalog_module);
    art_pipeline_fixture_module.addImport("deformable_mesh", deformable_mesh_module);
    art_pipeline_fixture_module.addImport("math", math_module);
    art_pipeline_fixture_module.addImport("render_queue", render_queue_module);
    const mesh_gpu_catalog_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/mesh_gpu_catalog.zig"),
        .target = target,
        .optimize = optimize,
    });
    mesh_gpu_catalog_module.addImport("deformable_mesh", deformable_mesh_module);
    const pose_module = b.createModule(.{
        .root_source_file = b.path("src/animation/pose.zig"),
        .target = target,
        .optimize = optimize,
    });
    pose_module.addImport("math", math_module);
    pose_module.addImport("skeleton", skeleton_module);
    pose_module.addImport("fault_injection", fault_injection_module);
    const appearance_module = b.createModule(.{
        .root_source_file = b.path("src/scene/appearance.zig"),
        .target = target,
        .optimize = optimize,
    });
    appearance_module.addImport("math", math_module);
    appearance_module.addImport("deformation", deformation_module);
    appearance_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    appearance_module.addImport("skeleton", skeleton_module);
    appearance_module.addImport("pose", pose_module);
    appearance_module.addImport("fault_injection", fault_injection_module);
    const anatomy_module = b.createModule(.{
        .root_source_file = b.path("src/scene/anatomy.zig"),
        .target = target,
        .optimize = optimize,
    });
    anatomy_module.addImport("math", math_module);
    anatomy_module.addImport("deformation", deformation_module);
    anatomy_module.addImport("skeleton", skeleton_module);
    anatomy_module.addImport("appearance", appearance_module);
    anatomy_module.addImport("fault_injection", fault_injection_module);
    const component_graph_module = b.createModule(.{
        .root_source_file = b.path("src/scene/component_graph.zig"),
        .target = target,
        .optimize = optimize,
    });
    component_graph_module.addImport("math", math_module);
    component_graph_module.addImport("skeleton", skeleton_module);
    component_graph_module.addImport("appearance", appearance_module);
    component_graph_module.addImport("anatomy", anatomy_module);
    const character_properties_module = b.createModule(.{
        .root_source_file = b.path("src/scene/character_properties.zig"),
        .target = target,
        .optimize = optimize,
    });
    character_properties_module.addImport("skeleton", skeleton_module);
    const equipment_module = b.createModule(.{
        .root_source_file = b.path("src/scene/equipment.zig"),
        .target = target,
        .optimize = optimize,
    });
    equipment_module.addImport("math", math_module);
    equipment_module.addImport("deformation", deformation_module);
    equipment_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    equipment_module.addImport("skeleton", skeleton_module);
    equipment_module.addImport("appearance", appearance_module);
    equipment_module.addImport("anatomy", anatomy_module);
    equipment_module.addImport("deformable_mesh", deformable_mesh_module);
    equipment_module.addImport("character_properties", character_properties_module);
    const two_bone_ik_module = b.createModule(.{
        .root_source_file = b.path("src/animation/two_bone_ik.zig"),
        .target = target,
        .optimize = optimize,
    });
    two_bone_ik_module.addImport("math", math_module);
    const arm_ik_module = b.createModule(.{
        .root_source_file = b.path("src/animation/arm_ik.zig"),
        .target = target,
        .optimize = optimize,
    });
    arm_ik_module.addImport("math", math_module);
    arm_ik_module.addImport("skeleton", skeleton_module);
    arm_ik_module.addImport("pose", pose_module);
    arm_ik_module.addImport("two_bone_ik", two_bone_ik_module);
    const leg_ik_module = b.createModule(.{
        .root_source_file = b.path("src/animation/leg_ik.zig"),
        .target = target,
        .optimize = optimize,
    });
    leg_ik_module.addImport("math", math_module);
    leg_ik_module.addImport("skeleton", skeleton_module);
    leg_ik_module.addImport("pose", pose_module);
    leg_ik_module.addImport("two_bone_ik", two_bone_ik_module);
    const procedural_motion_module = b.createModule(.{
        .root_source_file = b.path("src/animation/procedural_motion.zig"),
        .target = target,
        .optimize = optimize,
    });
    procedural_motion_module.addImport("fixed_step", fixed_step_module);
    procedural_motion_module.addImport("spring", spring_module);
    procedural_motion_module.addImport("skeleton", skeleton_module);
    procedural_motion_module.addImport("pose", pose_module);
    const humanoid_module = b.createModule(.{
        .root_source_file = b.path("src/scene/humanoid.zig"),
        .target = target,
        .optimize = optimize,
    });
    humanoid_module.addImport("math", math_module);
    humanoid_module.addImport("skeleton", skeleton_module);
    humanoid_module.addImport("pose", pose_module);
    humanoid_module.addImport("appearance", appearance_module);
    humanoid_module.addImport("anatomy", anatomy_module);
    humanoid_module.addImport("component_graph", component_graph_module);
    humanoid_module.addImport("sprite_batch", sprite_batch_module);
    humanoid_module.addImport("fault_injection", fault_injection_module);
    const modular_humanoid_module = b.createModule(.{
        .root_source_file = b.path("src/scene/modular_humanoid.zig"),
        .target = target,
        .optimize = optimize,
    });
    modular_humanoid_module.addImport("math", math_module);
    modular_humanoid_module.addImport("deformation", deformation_module);
    modular_humanoid_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    modular_humanoid_module.addImport("appearance", appearance_module);
    modular_humanoid_module.addImport("anatomy", anatomy_module);
    modular_humanoid_module.addImport("humanoid", humanoid_module);
    modular_humanoid_module.addImport("fault_injection", fault_injection_module);
    const equipment_catalog_module = b.createModule(.{
        .root_source_file = b.path("src/scene/equipment_catalog.zig"),
        .target = target,
        .optimize = optimize,
    });
    equipment_catalog_module.addImport("math", math_module);
    equipment_catalog_module.addImport("deformation", deformation_module);
    equipment_catalog_module.addImport("humanoid", humanoid_module);
    equipment_catalog_module.addImport("equipment", equipment_module);
    const events_module = b.createModule(.{
        .root_source_file = b.path("src/animation/events.zig"),
        .target = target,
        .optimize = optimize,
    });
    const foot_planting_module = b.createModule(.{
        .root_source_file = b.path("src/animation/foot_planting.zig"),
        .target = target,
        .optimize = optimize,
    });
    foot_planting_module.addImport("math", math_module);
    foot_planting_module.addImport("collider", collider_module);
    foot_planting_module.addImport("collision_world", collision_world_module);
    foot_planting_module.addImport("events", events_module);
    foot_planting_module.addImport("fixed_step", fixed_step_module);
    foot_planting_module.addImport("skeleton", skeleton_module);
    foot_planting_module.addImport("pose", pose_module);
    foot_planting_module.addImport("leg_ik", leg_ik_module);
    foot_planting_module.addImport("two_bone_ik", two_bone_ik_module);
    const clip_module = b.createModule(.{
        .root_source_file = b.path("src/animation/clip.zig"),
        .target = target,
        .optimize = optimize,
    });
    clip_module.addImport("math", math_module);
    clip_module.addImport("skeleton", skeleton_module);
    clip_module.addImport("events", events_module);
    clip_module.addImport("fault_injection", fault_injection_module);
    const state_machine_module = b.createModule(.{
        .root_source_file = b.path("src/animation/state_machine.zig"),
        .target = target,
        .optimize = optimize,
    });
    state_machine_module.addImport("clip", clip_module);
    state_machine_module.addImport("fault_injection", fault_injection_module);
    const animator_module = b.createModule(.{
        .root_source_file = b.path("src/animation/animator.zig"),
        .target = target,
        .optimize = optimize,
    });
    animator_module.addImport("math", math_module);
    animator_module.addImport("skeleton", skeleton_module);
    animator_module.addImport("pose", pose_module);
    animator_module.addImport("clip", clip_module);
    animator_module.addImport("events", events_module);
    animator_module.addImport("state_machine", state_machine_module);
    animator_module.addImport("fault_injection", fault_injection_module);
    const authored_clips_module = b.createModule(.{
        .root_source_file = b.path("src/animation/authored_clips.zig"),
        .target = target,
        .optimize = optimize,
    });
    authored_clips_module.addImport("math", math_module);
    authored_clips_module.addImport("skeleton", skeleton_module);
    authored_clips_module.addImport("humanoid", humanoid_module);
    authored_clips_module.addImport("clip", clip_module);
    authored_clips_module.addImport("events", events_module);
    authored_clips_module.addImport("state_machine", state_machine_module);
    authored_clips_module.addImport("fault_injection", fault_injection_module);
    const animation_system_module = b.createModule(.{
        .root_source_file = b.path("src/animation/animation_system.zig"),
        .target = target,
        .optimize = optimize,
    });
    animation_system_module.addImport("humanoid", humanoid_module);
    animation_system_module.addImport("authored_clips", authored_clips_module);
    animation_system_module.addImport("animator", animator_module);
    animation_system_module.addImport("fault_injection", fault_injection_module);
    const character_module = b.createModule(.{
        .root_source_file = b.path("src/scene/character.zig"),
        .target = target,
        .optimize = optimize,
    });
    character_module.addImport("math", math_module);
    character_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    character_module.addImport("humanoid", humanoid_module);
    character_module.addImport("appearance", appearance_module);
    character_module.addImport("anatomy", anatomy_module);
    character_module.addImport("component_graph", component_graph_module);
    character_module.addImport("equipment", equipment_module);
    character_module.addImport("character_properties", character_properties_module);
    character_module.addImport("deformation", deformation_module);
    character_module.addImport("skeleton", skeleton_module);
    character_module.addImport("authored_clips", authored_clips_module);
    character_module.addImport("clip", clip_module);
    character_module.addImport("events", events_module);
    character_module.addImport("animator", animator_module);
    character_module.addImport("animation_system", animation_system_module);
    character_module.addImport("state_machine", state_machine_module);
    character_module.addImport("procedural_motion", procedural_motion_module);
    character_module.addImport("arm_ik", arm_ik_module);
    character_module.addImport("leg_ik", leg_ik_module);
    character_module.addImport("foot_planting", foot_planting_module);
    character_module.addImport("fixed_step", fixed_step_module);
    character_module.addImport("character_intent", character_intent_module);
    character_module.addImport("presentation_view", presentation_view_module);
    character_module.addImport("collision_world", collision_world_module);
    character_module.addImport("character_controller", character_controller_module);
    character_module.addImport("sprite_batch", sprite_batch_module);
    character_module.addImport("deformable_mesh", deformable_mesh_module);
    character_module.addImport("render_queue", render_queue_module);
    character_module.addImport("fault_injection", fault_injection_module);
    const character_entity_binding_module = b.createModule(.{
        .root_source_file = b.path("src/scene/character_entity_binding.zig"),
        .target = target,
        .optimize = optimize,
    });
    character_entity_binding_module.addImport("foundation", foundation_module);
    character_entity_binding_module.addImport("scene_core", scene_core_module);
    character_entity_binding_module.addImport("math", math_module);
    character_entity_binding_module.addImport("character", character_module);
    const interaction_module = b.createModule(.{
        .root_source_file = b.path("src/interaction/interaction.zig"),
        .target = target,
        .optimize = optimize,
    });
    interaction_module.addImport("skeleton", skeleton_module);
    interaction_module.addImport("clip", clip_module);
    interaction_module.addImport("events", events_module);
    interaction_module.addImport("state_machine", state_machine_module);
    interaction_module.addImport("fixed_step", fixed_step_module);
    interaction_module.addImport("presentation_view", presentation_view_module);
    const handshake_module = b.createModule(.{
        .root_source_file = b.path("src/interaction/handshake.zig"),
        .target = target,
        .optimize = optimize,
    });
    handshake_module.addImport("interaction", interaction_module);
    handshake_module.addImport("authored_clips", authored_clips_module);
    handshake_module.addImport("state_machine", state_machine_module);
    handshake_module.addImport("clip", clip_module);
    handshake_module.addImport("skeleton", skeleton_module);
    const interaction_system_module = b.createModule(.{
        .root_source_file = b.path("src/interaction/interaction_system.zig"),
        .target = target,
        .optimize = optimize,
    });
    interaction_system_module.addImport("math", math_module);
    interaction_system_module.addImport("character_intent", character_intent_module);
    interaction_system_module.addImport("fixed_step", fixed_step_module);
    interaction_system_module.addImport("humanoid", humanoid_module);
    interaction_system_module.addImport("skeleton", skeleton_module);
    interaction_system_module.addImport("state_machine", state_machine_module);
    interaction_system_module.addImport("arm_ik", arm_ik_module);
    interaction_system_module.addImport("character", character_module);
    interaction_system_module.addImport("interaction", interaction_module);
    const presentation_pose_module = b.createModule(.{
        .root_source_file = b.path("src/scene/presentation_pose.zig"),
        .target = target,
        .optimize = optimize,
    });
    presentation_pose_module.addImport("math", math_module);
    presentation_pose_module.addImport("skeleton", skeleton_module);
    presentation_pose_module.addImport("pose", pose_module);
    presentation_pose_module.addImport("appearance", appearance_module);
    presentation_pose_module.addImport("anatomy", anatomy_module);
    const character_art_module = b.createModule(.{
        .root_source_file = b.path("src/scene/character_art.zig"),
        .target = target,
        .optimize = optimize,
    });
    character_art_module.addImport("math", math_module);
    character_art_module.addImport("art_pack", art_pack_module);
    character_art_module.addImport("humanoid", humanoid_module);
    character_art_module.addImport("character", character_module);
    character_art_module.addImport("appearance", appearance_module);
    character_art_module.addImport("skeleton", skeleton_module);
    character_art_module.addImport("presentation_pose", presentation_pose_module);
    character_art_module.addImport("presentation_view", presentation_view_module);
    character_art_module.addImport("render_queue", render_queue_module);
    character_art_module.addImport("sprite_batch", sprite_batch_module);
    character_art_module.addImport("visual_geometry", visual_geometry_module);
    character_art_module.addImport("visual_registration", visual_registration_module);
    character_art_module.addImport("image_decode", image_decode_module);
    character_art_module.addImport("anatomy", anatomy_module);
    const wardrobe_catalog_module = b.createModule(.{
        .root_source_file = b.path("src/scene/wardrobe_catalog.zig"),
        .target = target,
        .optimize = optimize,
    });
    wardrobe_catalog_module.addImport("math", math_module);
    wardrobe_catalog_module.addImport("deformation", deformation_module);
    wardrobe_catalog_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    wardrobe_catalog_module.addImport("deformable_mesh", deformable_mesh_module);
    wardrobe_catalog_module.addImport("equipment", equipment_module);
    wardrobe_catalog_module.addImport("humanoid", humanoid_module);
    wardrobe_catalog_module.addImport("visual_geometry", visual_geometry_module);
    const wardrobe_art_module = b.createModule(.{
        .root_source_file = b.path("src/scene/wardrobe_art.zig"),
        .target = target,
        .optimize = optimize,
    });
    wardrobe_art_module.addImport("art_pack", art_pack_module);
    wardrobe_art_module.addImport("equipment", equipment_module);
    wardrobe_art_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    wardrobe_art_module.addImport("visual_geometry", visual_geometry_module);
    wardrobe_art_module.addImport("image_decode", image_decode_module);
    const wardrobe_presentation_module = b.createModule(.{
        .root_source_file = b.path("src/scene/wardrobe_presentation.zig"),
        .target = target,
        .optimize = optimize,
    });
    wardrobe_presentation_module.addImport("art_pack", art_pack_module);
    wardrobe_presentation_module.addImport("math", math_module);
    wardrobe_presentation_module.addImport("deformable_mesh", deformable_mesh_module);
    wardrobe_presentation_module.addImport("equipment", equipment_module);
    wardrobe_presentation_module.addImport("humanoid", humanoid_module);
    wardrobe_presentation_module.addImport("character", character_module);
    wardrobe_presentation_module.addImport("presentation_pose", presentation_pose_module);
    wardrobe_presentation_module.addImport("presentation_view", presentation_view_module);
    wardrobe_presentation_module.addImport("render_queue", render_queue_module);
    wardrobe_presentation_module.addImport("sprite_batch", sprite_batch_module);
    wardrobe_presentation_module.addImport("wardrobe_art", wardrobe_art_module);
    wardrobe_presentation_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    wardrobe_presentation_module.addImport("anatomy", anatomy_module);
    wardrobe_presentation_module.addImport("visual_geometry", visual_geometry_module);
    wardrobe_presentation_module.addImport("visual_registration", visual_registration_module);
    wardrobe_presentation_module.addImport("character_art", character_art_module);
    const handshake_ik_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/handshake_ik_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    handshake_ik_demo_module.addImport("math", math_module);
    handshake_ik_demo_module.addImport("input", input_module);
    handshake_ik_demo_module.addImport("arm_ik", arm_ik_module);
    handshake_ik_demo_module.addImport("humanoid", humanoid_module);
    handshake_ik_demo_module.addImport("authored_clips", authored_clips_module);
    handshake_ik_demo_module.addImport("character", character_module);
    handshake_ik_demo_module.addImport("interaction", interaction_module);
    handshake_ik_demo_module.addImport("interaction_system", interaction_system_module);
    handshake_ik_demo_module.addImport("handshake", handshake_module);
    handshake_ik_demo_module.addImport("sprite_batch", sprite_batch_module);
    const diagnostics_module = b.createModule(.{
        .root_source_file = b.path("src/debug/diagnostics.zig"),
        .target = target,
        .optimize = optimize,
    });
    diagnostics_module.addImport("math", math_module);
    diagnostics_module.addImport("collider", collider_module);
    diagnostics_module.addImport("fixed_step", fixed_step_module);
    diagnostics_module.addImport("humanoid", humanoid_module);
    diagnostics_module.addImport("state_machine", state_machine_module);
    diagnostics_module.addImport("foot_planting", foot_planting_module);
    diagnostics_module.addImport("interaction", interaction_module);
    diagnostics_module.addImport("character", character_module);
    diagnostics_module.addImport("interaction_system", interaction_system_module);
    const debug_draw_module = b.createModule(.{
        .root_source_file = b.path("src/debug/debug_draw.zig"),
        .target = target,
        .optimize = optimize,
    });
    debug_draw_module.addImport("math", math_module);
    debug_draw_module.addImport("collider", collider_module);
    debug_draw_module.addImport("character", character_module);
    debug_draw_module.addImport("sprite_batch", sprite_batch_module);
    const visual_geometry_overlay_module = b.createModule(.{
        .root_source_file = b.path("src/debug/visual_geometry_overlay.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_geometry_overlay_module.addImport("math", math_module);
    visual_geometry_overlay_module.addImport("camera2d", camera2d_module);
    visual_geometry_overlay_module.addImport("image_decode", image_decode_module);
    visual_geometry_overlay_module.addImport("character_art", character_art_module);
    visual_geometry_overlay_module.addImport("wardrobe_art", wardrobe_art_module);
    visual_geometry_overlay_module.addImport("debug_draw", debug_draw_module);
    visual_geometry_overlay_module.addImport("sprite_batch", sprite_batch_module);
    visual_geometry_overlay_module.addImport("visual_geometry", visual_geometry_module);
    const visual_truth_module = b.createModule(.{
        .root_source_file = b.path("src/debug/visual_truth.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_truth_module.addImport("math", math_module);
    visual_truth_module.addImport("collider", collider_module);
    visual_truth_module.addImport("skeleton", skeleton_module);
    visual_truth_module.addImport("appearance", appearance_module);
    visual_truth_module.addImport("anatomy", anatomy_module);
    visual_truth_module.addImport("component_graph", component_graph_module);
    visual_truth_module.addImport("character", character_module);
    visual_truth_module.addImport("humanoid", humanoid_module);
    visual_truth_module.addImport("character_art", character_art_module);
    visual_truth_module.addImport("presentation_pose", presentation_pose_module);
    visual_truth_module.addImport("camera2d", camera2d_module);
    visual_truth_module.addImport("sprite_batch", sprite_batch_module);
    visual_truth_module.addImport("debug_draw", debug_draw_module);
    visual_truth_module.addImport("visual_geometry", visual_geometry_module);
    visual_truth_module.addImport("visual_geometry_overlay", visual_geometry_overlay_module);
    const frame_capture_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/frame_capture.zig"),
        .target = target,
        .optimize = optimize,
    });
    const capture_writer_module = b.createModule(.{
        .root_source_file = b.path("src/evidence/capture_writer.zig"),
        .target = target,
        .optimize = optimize,
    });
    capture_writer_module.addImport("frame_capture", frame_capture_module);
    capture_writer_module.addImport("visual_truth", visual_truth_module);
    const sdl_gpu_renderer_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/sdl_gpu_renderer.zig"),
        .target = target,
        .optimize = optimize,
    });
    sdl_gpu_renderer_module.addImport("sdl", sdl_module);
    sdl_gpu_renderer_module.addImport("fault_injection", fault_injection_module);
    sdl_gpu_renderer_module.addImport("sprite_batch", sprite_batch_module);
    sdl_gpu_renderer_module.addImport("deformable_mesh", deformable_mesh_module);
    sdl_gpu_renderer_module.addImport("render_queue", render_queue_module);
    sdl_gpu_renderer_module.addImport("mesh_gpu_catalog", mesh_gpu_catalog_module);
    sdl_gpu_renderer_module.addImport("camera2d", camera2d_module);
    sdl_gpu_renderer_module.addImport("art_pack", art_pack_module);
    sdl_gpu_renderer_module.addImport("image_decode", image_decode_module);
    sdl_gpu_renderer_module.addImport("diagnostics", diagnostics_module);
    sdl_gpu_renderer_module.addImport("frame_capture", frame_capture_module);
    const engine_lab_module = b.createModule(.{
        .root_source_file = b.path("src/app/engine_lab/hub.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_lab_module.addImport("foundation", foundation_module);
    engine_lab_module.addImport("scene_core", scene_core_module);
    engine_lab_module.addImport("fixed_step", fixed_step_module);
    engine_lab_module.addImport("world", world_module);
    engine_lab_module.addImport("spring", spring_module);
    engine_lab_module.addImport("secondary_motion", secondary_motion_module);
    engine_lab_module.addImport("math", math_module);
    engine_lab_module.addImport("collider", collider_module);
    engine_lab_module.addImport("collision_world", collision_world_module);
    engine_lab_module.addImport("character", character_module);
    engine_lab_module.addImport("humanoid", humanoid_module);
    engine_lab_module.addImport("authored_clips", authored_clips_module);
    engine_lab_module.addImport("character_intent", character_intent_module);
    engine_lab_module.addImport("camera2d", camera2d_module);
    const engine_lab_verification_module = b.createModule(.{
        .root_source_file = b.path("src/app/engine_lab/verification.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_lab_verification_module.addImport("engine_lab", engine_lab_module);
    const engine_lab_actions_module = b.createModule(.{
        .root_source_file = b.path("src/app/engine_lab/actions.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_lab_actions_module.addImport("physical_input", physical_input_module);
    engine_lab_actions_module.addImport("engine_lab", engine_lab_module);
    const engine_lab_view_module = b.createModule(.{
        .root_source_file = b.path("src/app/engine_lab/view.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_lab_view_module.addImport("engine_lab", engine_lab_module);
    engine_lab_view_module.addImport("fixed_step", fixed_step_module);
    engine_lab_view_module.addImport("collider", collider_module);
    engine_lab_view_module.addImport("debug_draw", debug_draw_module);
    engine_lab_view_module.addImport("math", math_module);
    engine_lab_view_module.addImport("sprite_batch", sprite_batch_module);
    engine_lab_view_module.addImport("render_queue", render_queue_module);
    const engine_lab_entry_module = b.createModule(.{
        .root_source_file = b.path("src/app/engine_lab/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    engine_lab_entry_module.addIncludePath(b.path(sdl_include));
    engine_lab_entry_module.addLibraryPath(b.path(sdl_library_dir));
    engine_lab_entry_module.linkSystemLibrary("SDL3", .{
        .preferred_link_mode = .dynamic,
        .search_strategy = .paths_first,
    });
    engine_lab_entry_module.addImport("engine_lab", engine_lab_module);
    engine_lab_entry_module.addImport("engine_lab_verification", engine_lab_verification_module);
    engine_lab_entry_module.addImport("engine_lab_actions", engine_lab_actions_module);
    engine_lab_entry_module.addImport("engine_lab_view", engine_lab_view_module);
    engine_lab_entry_module.addImport("sdl_gpu_renderer", sdl_gpu_renderer_module);
    engine_lab_entry_module.addImport("sdl_input", sdl_input_module);
    engine_lab_entry_module.addImport("art_pack", art_pack_module);
    engine_lab_entry_module.addImport("physical_input", physical_input_module);
    engine_lab_entry_module.addImport("sdl", sdl_module);
    const engine_lab_test_module = b.createModule(.{
        .root_source_file = b.path("tests/engine_lab_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_lab_test_module.addImport("engine_lab", engine_lab_module);
    engine_lab_test_module.addImport("engine_lab_verification", engine_lab_verification_module);
    engine_lab_test_module.addImport("collider", collider_module);
    engine_lab_test_module.addImport("physical_input", physical_input_module);
    engine_lab_test_module.addImport("engine_lab_actions", engine_lab_actions_module);
    engine_lab_test_module.addImport("engine_lab_view", engine_lab_view_module);
    engine_lab_test_module.addImport("render_queue", render_queue_module);
    engine_lab_test_module.addImport("debug_draw", debug_draw_module);
    const projectiles_module = b.createModule(.{ .root_source_file = b.path("src/projectiles/root.zig"), .target = target, .optimize = optimize });
    projectiles_module.addImport("foundation", foundation_module);
    projectiles_module.addImport("math", math_module);
    projectiles_module.addImport("fixed_step", fixed_step_module);
    projectiles_module.addImport("collider", collider_module);
    const effects_module = b.createModule(.{ .root_source_file = b.path("src/effects/root.zig"), .target = target, .optimize = optimize });
    effects_module.addImport("foundation", foundation_module);
    effects_module.addImport("math", math_module);
    effects_module.addImport("fixed_step", fixed_step_module);
    effects_module.addImport("art_pack", art_pack_module);
    const projectile_effects_module = b.createModule(.{ .root_source_file = b.path("src/effect_composition/projectile_effects.zig"), .target = target, .optimize = optimize });
    projectile_effects_module.addImport("projectiles", projectiles_module);
    projectile_effects_module.addImport("effects", effects_module);
    projectile_effects_module.addImport("math", math_module);
    projectile_effects_module.addImport("foundation", foundation_module);
    engine_lab_module.addImport("projectiles", projectiles_module);
    engine_lab_module.addImport("effects", effects_module);
    engine_lab_module.addImport("projectile_effects", projectile_effects_module);
    engine_lab_test_module.addImport("collision_world", collision_world_module);
    engine_lab_test_module.addImport("math", math_module);
    const effects_projectiles_scene_module = b.createModule(.{ .root_source_file = b.path("src/app/effects_projectiles_scene.zig"), .target = target, .optimize = optimize });
    effects_projectiles_scene_module.addImport("projectiles", projectiles_module);
    effects_projectiles_scene_module.addImport("effects", effects_module);
    effects_projectiles_scene_module.addImport("projectile_effects", projectile_effects_module);
    effects_projectiles_scene_module.addImport("foundation", foundation_module);
    effects_projectiles_scene_module.addImport("math", math_module);
    effects_projectiles_scene_module.addImport("collider", collider_module);
    effects_projectiles_scene_module.addImport("collision_world", collision_world_module);
    const effects_projectiles_view_module = b.createModule(.{ .root_source_file = b.path("src/app/effects_projectiles_view.zig"), .target = target, .optimize = optimize });
    effects_projectiles_view_module.addImport("effects_projectiles_scene", effects_projectiles_scene_module);
    effects_projectiles_view_module.addImport("projectiles", projectiles_module);
    effects_projectiles_view_module.addImport("effects", effects_module);
    effects_projectiles_view_module.addImport("math", math_module);
    effects_projectiles_view_module.addImport("sprite_batch", sprite_batch_module);
    effects_projectiles_view_module.addImport("render_queue", render_queue_module);
    const effects_projectiles_entry_module = b.createModule(.{ .root_source_file = b.path("src/app/effects_projectiles.zig"), .target = target, .optimize = optimize, .link_libc = true });
    effects_projectiles_entry_module.addIncludePath(b.path(sdl_include));
    effects_projectiles_entry_module.addLibraryPath(b.path(sdl_library_dir));
    effects_projectiles_entry_module.linkSystemLibrary("SDL3", .{ .preferred_link_mode = .dynamic, .search_strategy = .paths_first });
    effects_projectiles_entry_module.addImport("sdl", sdl_module);
    effects_projectiles_entry_module.addImport("effects_projectiles_scene", effects_projectiles_scene_module);
    effects_projectiles_entry_module.addImport("effects_projectiles_view", effects_projectiles_view_module);
    effects_projectiles_entry_module.addImport("fixed_step", fixed_step_module);
    effects_projectiles_entry_module.addImport("sdl_gpu_renderer", sdl_gpu_renderer_module);
    const effects_projectiles_test_module = b.createModule(.{ .root_source_file = b.path("tests/effects/root.zig"), .target = target, .optimize = optimize });
    effects_projectiles_test_module.addImport("effects_projectiles_scene", effects_projectiles_scene_module);
    effects_projectiles_test_module.addImport("effects_projectiles_view", effects_projectiles_view_module);
    effects_projectiles_test_module.addImport("render_queue", render_queue_module);
    effects_projectiles_test_module.addImport("projectile_effects", projectile_effects_module);
    effects_projectiles_test_module.addImport("foundation", foundation_module);
    effects_projectiles_test_module.addImport("math", math_module);
    effects_projectiles_test_module.addImport("projectiles", projectiles_module);
    effects_projectiles_test_module.addImport("effects", effects_module);
    const engine_smoke_client_module = b.createModule(.{
        .root_source_file = b.path("src/app/engine_smoke_client.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_smoke_client_module.addImport("foundation", foundation_module);
    engine_smoke_client_module.addImport("scene_core", scene_core_module);
    engine_smoke_client_module.addImport("sprite_batch", sprite_batch_module);
    const engine_smoke_entry_module = b.createModule(.{
        .root_source_file = b.path("src/app/engine_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    engine_smoke_entry_module.addIncludePath(b.path(sdl_include));
    engine_smoke_entry_module.addLibraryPath(b.path(sdl_library_dir));
    engine_smoke_entry_module.linkSystemLibrary("SDL3", .{
        .preferred_link_mode = .dynamic,
        .search_strategy = .paths_first,
    });
    engine_smoke_entry_module.addImport("engine_smoke_client", engine_smoke_client_module);
    engine_smoke_entry_module.addImport("sdl_gpu_renderer", sdl_gpu_renderer_module);
    engine_smoke_entry_module.addImport("fault_injection", fault_injection_module);
    const integrated_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/integrated_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    integrated_demo_module.addImport("math", math_module);
    integrated_demo_module.addImport("input", input_module);
    integrated_demo_module.addImport("fixed_step", fixed_step_module);
    integrated_demo_module.addImport("collider", collider_module);
    integrated_demo_module.addImport("collision_world", collision_world_module);
    integrated_demo_module.addImport("character_controller", character_controller_module);
    integrated_demo_module.addImport("humanoid", humanoid_module);
    integrated_demo_module.addImport("authored_clips", authored_clips_module);
    integrated_demo_module.addImport("state_machine", state_machine_module);
    integrated_demo_module.addImport("character", character_module);
    integrated_demo_module.addImport("foundation", foundation_module);
    integrated_demo_module.addImport("scene_core", scene_core_module);
    integrated_demo_module.addImport("character_entity_binding", character_entity_binding_module);
    integrated_demo_module.addImport("interaction", interaction_module);
    integrated_demo_module.addImport("interaction_system", interaction_system_module);
    integrated_demo_module.addImport("handshake", handshake_module);
    integrated_demo_module.addImport("foot_planting", foot_planting_module);
    integrated_demo_module.addImport("sprite_batch", sprite_batch_module);
    integrated_demo_module.addImport("diagnostics", diagnostics_module);
    integrated_demo_module.addImport("debug_draw", debug_draw_module);
    const playground_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/playground_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    playground_demo_module.addImport("math", math_module);
    playground_demo_module.addImport("input", input_module);
    playground_demo_module.addImport("fixed_step", fixed_step_module);
    playground_demo_module.addImport("collider", collider_module);
    playground_demo_module.addImport("collision_world", collision_world_module);
    playground_demo_module.addImport("character_controller", character_controller_module);
    playground_demo_module.addImport("humanoid", humanoid_module);
    playground_demo_module.addImport("authored_clips", authored_clips_module);
    playground_demo_module.addImport("state_machine", state_machine_module);
    playground_demo_module.addImport("character", character_module);
    playground_demo_module.addImport("interaction", interaction_module);
    playground_demo_module.addImport("interaction_system", interaction_system_module);
    playground_demo_module.addImport("handshake", handshake_module);
    playground_demo_module.addImport("foot_planting", foot_planting_module);
    playground_demo_module.addImport("sprite_batch", sprite_batch_module);
    playground_demo_module.addImport("debug_draw", debug_draw_module);
    const modular_body_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/modular_body_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    modular_body_demo_module.addImport("humanoid", humanoid_module);
    modular_body_demo_module.addImport("modular_humanoid", modular_humanoid_module);
    modular_body_demo_module.addImport("authored_clips", authored_clips_module);
    modular_body_demo_module.addImport("character", character_module);
    modular_body_demo_module.addImport("sprite_batch", sprite_batch_module);
    modular_body_demo_module.addImport("fault_injection", fault_injection_module);
    const wardrobe_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/wardrobe_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    wardrobe_demo_module.addImport("math", math_module);
    wardrobe_demo_module.addImport("fixed_step", fixed_step_module);
    wardrobe_demo_module.addImport("input", input_module);
    wardrobe_demo_module.addImport("collider", collider_module);
    wardrobe_demo_module.addImport("collision_world", collision_world_module);
    wardrobe_demo_module.addImport("character_controller", character_controller_module);
    wardrobe_demo_module.addImport("authored_clips", authored_clips_module);
    wardrobe_demo_module.addImport("humanoid", humanoid_module);
    wardrobe_demo_module.addImport("character", character_module);
    wardrobe_demo_module.addImport("character_art", character_art_module);
    wardrobe_demo_module.addImport("modular_humanoid", modular_humanoid_module);
    wardrobe_demo_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    wardrobe_demo_module.addImport("wardrobe_art", wardrobe_art_module);
    wardrobe_demo_module.addImport("wardrobe_presentation", wardrobe_presentation_module);
    wardrobe_demo_module.addImport("render_queue", render_queue_module);
    wardrobe_demo_module.addImport("deformable_mesh", deformable_mesh_module);
    wardrobe_demo_module.addImport("visual_geometry", visual_geometry_module);
    wardrobe_demo_module.addImport("anatomy_evidence", anatomy_evidence_module);
    const equipment_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/equipment_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    equipment_demo_module.addImport("humanoid", humanoid_module);
    equipment_demo_module.addImport("authored_clips", authored_clips_module);
    equipment_demo_module.addImport("character", character_module);
    equipment_demo_module.addImport("equipment", equipment_module);
    equipment_demo_module.addImport("modular_humanoid", modular_humanoid_module);
    equipment_demo_module.addImport("equipment_catalog", equipment_catalog_module);
    equipment_demo_module.addImport("sprite_batch", sprite_batch_module);
    const mesh_attachment_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/mesh_attachment_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    mesh_attachment_demo_module.addImport("math", math_module);
    mesh_attachment_demo_module.addImport("deformation", deformation_module);
    mesh_attachment_demo_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    mesh_attachment_demo_module.addImport("deformable_mesh", deformable_mesh_module);
    mesh_attachment_demo_module.addImport("render_queue", render_queue_module);
    mesh_attachment_demo_module.addImport("humanoid", humanoid_module);
    mesh_attachment_demo_module.addImport("authored_clips", authored_clips_module);
    mesh_attachment_demo_module.addImport("character", character_module);
    mesh_attachment_demo_module.addImport("equipment", equipment_module);
    mesh_attachment_demo_module.addImport("modular_humanoid", modular_humanoid_module);
    mesh_attachment_demo_module.addImport("attachment_meshes", attachment_meshes_module);
    const foundation_playground_module = b.createModule(.{
        .root_source_file = b.path("src/scene/foundation_playground.zig"),
        .target = target,
        .optimize = optimize,
    });
    foundation_playground_module.addImport("math", math_module);
    foundation_playground_module.addImport("input", input_module);
    foundation_playground_module.addImport("fixed_step", fixed_step_module);
    foundation_playground_module.addImport("collider", collider_module);
    foundation_playground_module.addImport("collision_world", collision_world_module);
    foundation_playground_module.addImport("character_controller", character_controller_module);
    foundation_playground_module.addImport("deformation", deformation_module);
    foundation_playground_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    foundation_playground_module.addImport("anatomy", anatomy_module);
    foundation_playground_module.addImport("equipment", equipment_module);
    foundation_playground_module.addImport("deformable_mesh", deformable_mesh_module);
    foundation_playground_module.addImport("humanoid", humanoid_module);
    foundation_playground_module.addImport("authored_clips", authored_clips_module);
    foundation_playground_module.addImport("character", character_module);
    foundation_playground_module.addImport("interaction", interaction_module);
    foundation_playground_module.addImport("interaction_system", interaction_system_module);
    foundation_playground_module.addImport("handshake", handshake_module);
    foundation_playground_module.addImport("foot_planting", foot_planting_module);
    foundation_playground_module.addImport("render_queue", render_queue_module);
    foundation_playground_module.addImport("camera2d", camera2d_module);
    foundation_playground_module.addImport("debug_draw", debug_draw_module);
    foundation_playground_module.addImport("modular_humanoid", modular_humanoid_module);
    foundation_playground_module.addImport("attachment_meshes", attachment_meshes_module);
    foundation_playground_module.addImport("foundation_world", foundation_world_module);
    const environment_art_module = b.createModule(.{
        .root_source_file = b.path("src/scene/environment_art.zig"),
        .target = target,
        .optimize = optimize,
    });
    environment_art_module.addImport("art_pack", art_pack_module);
    const environment_theme_module = b.createModule(.{
        .root_source_file = b.path("src/scene/environment_theme.zig"),
        .target = target,
        .optimize = optimize,
    });
    environment_theme_module.addImport("math", math_module);
    environment_theme_module.addImport("art_pack", art_pack_module);
    environment_theme_module.addImport("collider", collider_module);
    environment_theme_module.addImport("collision_world", collision_world_module);
    environment_theme_module.addImport("character", character_module);
    environment_theme_module.addImport("environment_art", environment_art_module);
    environment_theme_module.addImport("render_queue", render_queue_module);
    environment_theme_module.addImport("camera2d", camera2d_module);
    const environment_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/environment_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    environment_demo_module.addImport("math", math_module);
    environment_demo_module.addImport("input", input_module);
    environment_demo_module.addImport("character_controller", character_controller_module);
    environment_demo_module.addImport("foundation_world", foundation_world_module);
    environment_demo_module.addImport("camera2d", camera2d_module);
    environment_demo_module.addImport("character", character_module);
    environment_demo_module.addImport("humanoid", humanoid_module);
    environment_demo_module.addImport("presentation_view", presentation_view_module);
    environment_demo_module.addImport("environment_art", environment_art_module);
    environment_demo_module.addImport("environment_theme", environment_theme_module);
    environment_demo_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    environment_demo_module.addImport("wardrobe_demo", wardrobe_demo_module);
    environment_demo_module.addImport("render_queue", render_queue_module);
    environment_demo_module.addImport("deformable_mesh", deformable_mesh_module);
    environment_demo_module.addImport("collision_world", collision_world_module);
    environment_demo_module.addImport("visual_geometry", visual_geometry_module);
    environment_demo_module.addImport("modular_humanoid", modular_humanoid_module);
    const foundation_evidence_module = b.createModule(.{
        .root_source_file = b.path("src/scene/foundation_evidence.zig"),
        .target = target,
        .optimize = optimize,
    });
    const foundation_coherence_module = b.createModule(.{
        .root_source_file = b.path("src/scene/foundation_coherence.zig"),
        .target = target,
        .optimize = optimize,
    });
    foundation_coherence_module.addImport("math", math_module);
    foundation_coherence_module.addImport("camera2d", camera2d_module);
    foundation_coherence_module.addImport("sprite_batch", sprite_batch_module);
    foundation_coherence_module.addImport("render_queue", render_queue_module);
    foundation_coherence_module.addImport("visual_geometry", visual_geometry_module);
    const acceptance_hud_module = b.createModule(.{
        .root_source_file = b.path("src/debug/acceptance_hud.zig"),
        .target = target,
        .optimize = optimize,
    });
    acceptance_hud_module.addImport("math", math_module);
    acceptance_hud_module.addImport("camera2d", camera2d_module);
    acceptance_hud_module.addImport("character", character_module);
    acceptance_hud_module.addImport("sprite_batch", sprite_batch_module);
    acceptance_hud_module.addImport("render_queue", render_queue_module);
    acceptance_hud_module.addImport("foundation_evidence", foundation_evidence_module);
    const visual_foundation_module = b.createModule(.{
        .root_source_file = b.path("src/scene/visual_foundation.zig"),
        .target = target,
        .optimize = optimize,
    });
    visual_foundation_module.addImport("foundation_evidence", foundation_evidence_module);
    visual_foundation_module.addImport("foundation_coherence", foundation_coherence_module);
    visual_foundation_module.addImport("math", math_module);
    visual_foundation_module.addImport("input", input_module);
    visual_foundation_module.addImport("fixed_step", fixed_step_module);
    visual_foundation_module.addImport("character_controller", character_controller_module);
    visual_foundation_module.addImport("character", character_module);
    visual_foundation_module.addImport("humanoid", humanoid_module);
    visual_foundation_module.addImport("interaction", interaction_module);
    visual_foundation_module.addImport("interaction_system", interaction_system_module);
    visual_foundation_module.addImport("handshake", handshake_module);
    visual_foundation_module.addImport("presentation_view", presentation_view_module);
    visual_foundation_module.addImport("presentation_pose", presentation_pose_module);
    visual_foundation_module.addImport("skeleton", skeleton_module);
    visual_foundation_module.addImport("environment_demo", environment_demo_module);
    visual_foundation_module.addImport("environment_art", environment_art_module);
    visual_foundation_module.addImport("environment_theme", environment_theme_module);
    visual_foundation_module.addImport("foundation_world", foundation_world_module);
    visual_foundation_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    visual_foundation_module.addImport("wardrobe_demo", wardrobe_demo_module);
    visual_foundation_module.addImport("render_queue", render_queue_module);
    visual_foundation_module.addImport("deformable_mesh", deformable_mesh_module);
    visual_foundation_module.addImport("debug_draw", debug_draw_module);
    visual_foundation_module.addImport("camera2d", camera2d_module);
    visual_foundation_module.addImport("visual_geometry", visual_geometry_module);
    visual_foundation_module.addImport("visual_geometry_overlay", visual_geometry_overlay_module);
    visual_foundation_module.addImport("visual_truth", visual_truth_module);
    visual_foundation_module.addImport("modular_humanoid", modular_humanoid_module);
    const controller_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/controller_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    controller_demo_module.addImport("math", math_module);
    controller_demo_module.addImport("input", input_module);
    controller_demo_module.addImport("fixed_step", fixed_step_module);
    controller_demo_module.addImport("collision_world", collision_world_module);
    controller_demo_module.addImport("character_controller", character_controller_module);
    controller_demo_module.addImport("humanoid", humanoid_module);
    controller_demo_module.addImport("animation_system", animation_system_module);
    controller_demo_module.addImport("state_machine", state_machine_module);
    controller_demo_module.addImport("procedural_motion", procedural_motion_module);
    controller_demo_module.addImport("sprite_batch", sprite_batch_module);
    controller_demo_module.addImport("fault_injection", fault_injection_module);
    const demo_application_module = b.createModule(.{
        .root_source_file = b.path("src/app/demo_application.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo_application_module.addImport("humanoid", humanoid_module);
    demo_application_module.addImport("appearance", appearance_module);
    demo_application_module.addImport("anatomy", anatomy_module);
    demo_application_module.addImport("equipment", equipment_module);
    demo_application_module.addImport("character_properties", character_properties_module);
    demo_application_module.addImport("deformation", deformation_module);
    demo_application_module.addImport("math", math_module);
    demo_application_module.addImport("camera2d", camera2d_module);
    demo_application_module.addImport("animation_system", animation_system_module);
    demo_application_module.addImport("sprite_batch", sprite_batch_module);
    demo_application_module.addImport("deformable_mesh", deformable_mesh_module);
    demo_application_module.addImport("render_queue", render_queue_module);
    demo_application_module.addImport("mesh_gpu_catalog", mesh_gpu_catalog_module);
    demo_application_module.addImport("fault_injection", fault_injection_module);
    demo_application_module.addImport("input", input_module);
    demo_application_module.addImport("sdl", sdl_module);
    demo_application_module.addImport("sdl_input", sdl_input_module);
    demo_application_module.addImport("fixed_step", fixed_step_module);
    demo_application_module.addImport("spring", spring_module);
    demo_application_module.addImport("collider", collider_module);
    demo_application_module.addImport("collision_world", collision_world_module);
    demo_application_module.addImport("character_controller", character_controller_module);
    demo_application_module.addImport("controller_demo", controller_demo_module);
    demo_application_module.addImport("procedural_motion", procedural_motion_module);
    demo_application_module.addImport("character", character_module);
    demo_application_module.addImport("interaction", interaction_module);
    demo_application_module.addImport("handshake", handshake_module);
    demo_application_module.addImport("interaction_system", interaction_system_module);
    demo_application_module.addImport("handshake_ik_demo", handshake_ik_demo_module);
    demo_application_module.addImport("diagnostics", diagnostics_module);
    demo_application_module.addImport("debug_draw", debug_draw_module);
    demo_application_module.addImport("integrated_demo", integrated_demo_module);
    demo_application_module.addImport("playground_demo", playground_demo_module);
    demo_application_module.addImport("modular_body_demo", modular_body_demo_module);
    demo_application_module.addImport("equipment_demo", equipment_demo_module);
    demo_application_module.addImport("mesh_attachment_demo", mesh_attachment_demo_module);
    demo_application_module.addImport("foundation_playground", foundation_playground_module);
    demo_application_module.addImport("art_pack", art_pack_module);
    demo_application_module.addImport("image_decode", image_decode_module);
    demo_application_module.addImport("presentation_view", presentation_view_module);
    demo_application_module.addImport("presentation_pose", presentation_pose_module);
    demo_application_module.addImport("character_art", character_art_module);
    demo_application_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    demo_application_module.addImport("wardrobe_art", wardrobe_art_module);
    demo_application_module.addImport("wardrobe_presentation", wardrobe_presentation_module);
    demo_application_module.addImport("wardrobe_demo", wardrobe_demo_module);
    demo_application_module.addImport("environment_art", environment_art_module);
    demo_application_module.addImport("environment_theme", environment_theme_module);
    demo_application_module.addImport("environment_demo", environment_demo_module);
    demo_application_module.addImport("foundation_evidence", foundation_evidence_module);
    demo_application_module.addImport("foundation_coherence", foundation_coherence_module);
    demo_application_module.addImport("acceptance_hud", acceptance_hud_module);
    demo_application_module.addImport("visual_foundation", visual_foundation_module);
    demo_application_module.addImport("visual_geometry", visual_geometry_module);
    demo_application_module.addImport("visual_registration", visual_registration_module);
    demo_application_module.addImport("visual_geometry_audit", visual_geometry_audit_module);
    demo_application_module.addImport("visual_geometry_overlay", visual_geometry_overlay_module);
    demo_application_module.addImport("visual_truth", visual_truth_module);
    demo_application_module.addImport("anatomy_evidence", anatomy_evidence_module);
    demo_application_module.addImport("sdl_gpu_renderer", sdl_gpu_renderer_module);
    demo_application_module.addImport("capture_writer", capture_writer_module);
    const demo_entry_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    demo_entry_module.addIncludePath(b.path(sdl_include));
    demo_entry_module.addLibraryPath(b.path(sdl_library_dir));
    demo_entry_module.linkSystemLibrary("SDL3", .{
        .preferred_link_mode = .dynamic,
        .search_strategy = .paths_first,
    });
    demo_entry_module.addImport("demo_application", demo_application_module);
    demo_entry_module.addImport("fault_injection", fault_injection_module);
    demo_entry_module.addImport("visual_foundation", visual_foundation_module);
    const engine_composition_test_module = b.createModule(.{
        .root_source_file = b.path("tests/engine_composition_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_composition_test_module.addImport("foundation", foundation_module);
    engine_composition_test_module.addImport("scene_core", scene_core_module);
    engine_composition_test_module.addImport("engine_smoke_client", engine_smoke_client_module);
    engine_composition_test_module.addImport("math", math_module);
    engine_composition_test_module.addImport("humanoid", humanoid_module);
    engine_composition_test_module.addImport("authored_clips", authored_clips_module);
    engine_composition_test_module.addImport("character", character_module);
    engine_composition_test_module.addImport("character_entity_binding", character_entity_binding_module);
    engine_composition_test_module.addImport("handshake", handshake_module);
    engine_composition_test_module.addImport("interaction", interaction_module);
    engine_composition_test_module.addImport("interaction_system", interaction_system_module);
    test_module.addImport("fault_injection", fault_injection_module);
    test_module.addImport("sprite_batch", sprite_batch_module);
    test_module.addImport("deformable_mesh", deformable_mesh_module);
    test_module.addImport("render_queue", render_queue_module);
    test_module.addImport("mesh_gpu_catalog", mesh_gpu_catalog_module);
    test_module.addImport("math", math_module);
    test_module.addImport("camera2d", camera2d_module);
    test_module.addImport("skeleton", skeleton_module);
    test_module.addImport("pose", pose_module);
    test_module.addImport("appearance", appearance_module);
    test_module.addImport("anatomy", anatomy_module);
    test_module.addImport("component_graph", component_graph_module);
    test_module.addImport("equipment", equipment_module);
    test_module.addImport("equipment_catalog", equipment_catalog_module);
    test_module.addImport("character_properties", character_properties_module);
    test_module.addImport("deformation", deformation_module);
    test_module.addImport("two_bone_ik", two_bone_ik_module);
    test_module.addImport("arm_ik", arm_ik_module);
    test_module.addImport("leg_ik", leg_ik_module);
    test_module.addImport("foot_planting", foot_planting_module);
    test_module.addImport("humanoid", humanoid_module);
    test_module.addImport("events", events_module);
    test_module.addImport("clip", clip_module);
    test_module.addImport("state_machine", state_machine_module);
    test_module.addImport("animator", animator_module);
    test_module.addImport("authored_clips", authored_clips_module);
    test_module.addImport("animation_system", animation_system_module);
    test_module.addImport("input", input_module);
    test_module.addImport("fixed_step", fixed_step_module);
    test_module.addImport("spring", spring_module);
    test_module.addImport("attachment_secondary_motion", attachment_secondary_motion_module);
    test_module.addImport("attachment_meshes", attachment_meshes_module);
    test_module.addImport("collider", collider_module);
    test_module.addImport("collision_world", collision_world_module);
    test_module.addImport("character_controller", character_controller_module);
    test_module.addImport("controller_demo", controller_demo_module);
    test_module.addImport("procedural_motion", procedural_motion_module);
    test_module.addImport("character", character_module);
    test_module.addImport("foundation", foundation_module);
    test_module.addImport("scene_core", scene_core_module);
    test_module.addImport("character_entity_binding", character_entity_binding_module);
    test_module.addImport("interaction", interaction_module);
    test_module.addImport("handshake", handshake_module);
    test_module.addImport("interaction_system", interaction_system_module);
    test_module.addImport("handshake_ik_demo", handshake_ik_demo_module);
    test_module.addImport("diagnostics", diagnostics_module);
    test_module.addImport("debug_draw", debug_draw_module);
    test_module.addImport("integrated_demo", integrated_demo_module);
    test_module.addImport("playground_demo", playground_demo_module);
    test_module.addImport("modular_body_demo", modular_body_demo_module);
    test_module.addImport("modular_humanoid", modular_humanoid_module);
    test_module.addImport("equipment_demo", equipment_demo_module);
    test_module.addImport("mesh_attachment_demo", mesh_attachment_demo_module);
    test_module.addImport("foundation_playground", foundation_playground_module);
    test_module.addImport("foundation_world", foundation_world_module);
    test_module.addImport("art_pack", art_pack_module);
    test_module.addImport("art_asset_catalog", art_asset_catalog_module);
    test_module.addImport("art_pipeline_fixture", art_pipeline_fixture_module);
    test_module.addImport("presentation_view", presentation_view_module);
    test_module.addImport("presentation_pose", presentation_pose_module);
    test_module.addImport("character_art", character_art_module);
    test_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    test_module.addImport("wardrobe_art", wardrobe_art_module);
    test_module.addImport("wardrobe_presentation", wardrobe_presentation_module);
    test_module.addImport("wardrobe_demo", wardrobe_demo_module);
    test_module.addImport("environment_art", environment_art_module);
    test_module.addImport("environment_theme", environment_theme_module);
    test_module.addImport("environment_demo", environment_demo_module);
    test_module.addImport("visual_geometry", visual_geometry_module);
    test_module.addImport("visual_registration", visual_registration_module);
    test_module.addImport("visual_geometry_audit", visual_geometry_audit_module);
    test_module.addImport("anatomy_evidence", anatomy_evidence_module);
    stress_test_module.addImport("math", math_module);
    stress_test_module.addImport("input", input_module);
    stress_test_module.addImport("humanoid", humanoid_module);
    stress_test_module.addImport("authored_clips", authored_clips_module);
    stress_test_module.addImport("character", character_module);
    stress_test_module.addImport("interaction_system", interaction_system_module);
    stress_test_module.addImport("handshake", handshake_module);
    stress_test_module.addImport("integrated_demo", integrated_demo_module);
    integration_test_module.addImport("math", math_module);
    integration_test_module.addImport("sprite_batch", sprite_batch_module);
    integration_test_module.addImport("diagnostics", diagnostics_module);
    integration_test_module.addImport("debug_draw", debug_draw_module);
    integration_test_module.addImport("integrated_demo", integrated_demo_module);
    const camera_test_module = b.createModule(.{
        .root_source_file = b.path("tests/camera_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    camera_test_module.addImport("math", math_module);
    camera_test_module.addImport("camera2d", camera2d_module);
    camera_test_module.addImport("input", input_module);
    camera_test_module.addImport("collision_world", collision_world_module);
    camera_test_module.addImport("character_controller", character_controller_module);

    const record_replay_module = b.createModule(.{
        .root_source_file = b.path("src/record_replay/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    record_replay_module.addImport("foundation", foundation_module);
    const record_replay_proof_module = b.createModule(.{
        .root_source_file = b.path("src/app/record_replay_proof.zig"),
        .target = target,
        .optimize = optimize,
    });
    record_replay_proof_module.addImport("record_replay", record_replay_module);
    record_replay_proof_module.addImport("foundation", foundation_module);
    record_replay_proof_module.addImport("scene_core", scene_core_module);
    record_replay_proof_module.addImport("math", math_module);
    record_replay_proof_module.addImport("character_controller", character_controller_module);
    record_replay_proof_module.addImport("character_intent", character_intent_module);
    record_replay_proof_module.addImport("collision_world", collision_world_module);
    record_replay_proof_module.addImport("fixed_step", fixed_step_module);
    const record_replay_test_module = b.createModule(.{
        .root_source_file = b.path("tests/record_replay_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    record_replay_test_module.addImport("record_replay", record_replay_module);
    record_replay_test_module.addImport("record_replay_proof", record_replay_proof_module);
    record_replay_test_module.addImport("foundation", foundation_module);
    record_replay_test_module.addImport("fixed_step", fixed_step_module);
    record_replay_test_module.addImport("input", input_module);
    return .{
        .sdl_gpu_renderer_module = sdl_gpu_renderer_module,
        .secondary_motion_module = secondary_motion_module,
        .secondary_motion_rate_module = secondary_motion_rate_module,
        .secondary_motion_test_module = secondary_motion_test_module,
        .record_replay_module = record_replay_module,
        .record_replay_proof_module = record_replay_proof_module,
        .record_replay_test_module = record_replay_test_module,
        .effects_projectiles_entry_module = effects_projectiles_entry_module,
        .projectile_effects_module = projectile_effects_module,
        .projectiles_module = projectiles_module,
        .effects_module = effects_module,
        .effects_projectiles_test_module = effects_projectiles_test_module,
        .demo_entry_module = demo_entry_module,
        .engine_smoke_entry_module = engine_smoke_entry_module,
        .engine_lab_entry_module = engine_lab_entry_module,
        .engine_lab_test_module = engine_lab_test_module,
        .engine_smoke_client_module = engine_smoke_client_module,
        .engine_composition_test_module = engine_composition_test_module,
        .foundation_module = foundation_module,
        .world_module = world_module,
        .scene_core_module = scene_core_module,
        .canonical_model_core_test_module = canonical_model_core_test_module,
        .canonical_model_phase_c_test_module = canonical_model_phase_c_test_module,
        .canonical_model_phase_de_test_module = canonical_model_phase_de_test_module,
        .canonical_model_phase_f_test_module = canonical_model_phase_f_test_module,
        .canonical_human_identity_test_module = canonical_human_identity_test_module,
        .canonical_human_rig_test_module = canonical_human_rig_test_module,
        .canonical_human_joint_control_test_module = canonical_human_joint_control_test_module,
        .canonical_human_structural_test_module = canonical_human_structural_test_module,
        .canonical_human_base_test_module = canonical_human_base_test_module,
        .canonical_geometry_test_module = canonical_geometry_test_module,
        .foundation_primitive_test_module = foundation_primitive_test_module,
        .scene_core_authored_test_module = scene_core_authored_test_module,
        .scene_core_runtime_test_module = scene_core_runtime_test_module,
        .scene_core_registry_test_module = scene_core_registry_test_module,
        .canonical_human_geometry_scaffold_test_module = canonical_human_geometry_scaffold_test_module,
        .canonical_human_geometry_refinement_test_module = canonical_human_geometry_refinement_test_module,
        .canonical_human_geometry_adoption_test_module = canonical_human_geometry_adoption_test_module,
        .canonical_human_geometry_r3_test_module = canonical_human_geometry_r3_test_module,
        .canonical_human_geometry_r4_test_module = canonical_human_geometry_r4_test_module,
        .canonical_human_geometry_full_test_module = canonical_human_geometry_full_test_module,
        .test_module = test_module,
        .stress_test_module = stress_test_module,
        .integration_test_module = integration_test_module,
        .physical_input_module = physical_input_module,
        .input_module = input_module,
        .sprite_batch_module = sprite_batch_module,
        .art_pack_module = art_pack_module,
        .presentation_view_module = presentation_view_module,
        .image_decode_module = image_decode_module,
        .math_module = math_module,
        .camera2d_module = camera2d_module,
        .visual_geometry_module = visual_geometry_module,
        .visual_registration_module = visual_registration_module,
        .visual_geometry_audit_module = visual_geometry_audit_module,
        .anatomy_quality_module = anatomy_quality_module,
        .collider_module = collider_module,
        .foundation_world_module = foundation_world_module,
        .collision_world_module = collision_world_module,
        .character_controller_module = character_controller_module,
        .render_queue_module = render_queue_module,
        .art_asset_catalog_module = art_asset_catalog_module,
        .art_pipeline_fixture_module = art_pipeline_fixture_module,
        .appearance_module = appearance_module,
        .anatomy_module = anatomy_module,
        .component_graph_module = component_graph_module,
        .equipment_module = equipment_module,
        .humanoid_module = humanoid_module,
        .modular_humanoid_module = modular_humanoid_module,
        .authored_clips_module = authored_clips_module,
        .character_module = character_module,
        .character_entity_binding_module = character_entity_binding_module,
        .interaction_module = interaction_module,
        .handshake_module = handshake_module,
        .presentation_pose_module = presentation_pose_module,
        .character_art_module = character_art_module,
        .wardrobe_catalog_module = wardrobe_catalog_module,
        .wardrobe_art_module = wardrobe_art_module,
        .wardrobe_presentation_module = wardrobe_presentation_module,
        .handshake_ik_demo_module = handshake_ik_demo_module,
        .debug_draw_module = debug_draw_module,
        .visual_truth_module = visual_truth_module,
        .frame_capture_module = frame_capture_module,
        .integrated_demo_module = integrated_demo_module,
        .modular_body_demo_module = modular_body_demo_module,
        .wardrobe_demo_module = wardrobe_demo_module,
        .foundation_playground_module = foundation_playground_module,
        .environment_art_module = environment_art_module,
        .environment_theme_module = environment_theme_module,
        .environment_demo_module = environment_demo_module,
        .foundation_evidence_module = foundation_evidence_module,
        .foundation_coherence_module = foundation_coherence_module,
        .acceptance_hud_module = acceptance_hud_module,
        .visual_foundation_module = visual_foundation_module,
        .camera_test_module = camera_test_module,
        .canonical_model_module = canonical_model_module,
        .canonical_geometry_module = canonical_geometry_module,
        .canonical_human_geometry_module = canonical_human_geometry_module,
    };
}
