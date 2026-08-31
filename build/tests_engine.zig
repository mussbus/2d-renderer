const std = @import("std");
const modules_build = @import("modules.zig");

pub const Options = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    modules: *const modules_build.Catalog,
};

pub const Registration = struct {
    run_engine_composition: *std.Build.Step.Run,
    run_deterministic: *std.Build.Step.Run,
    run_renderer_boundary: *std.Build.Step.Run,
    run_foundation_primitives: *std.Build.Step.Run,
    run_f4c4_adoption: *std.Build.Step.Run,
    run_scene_core_authored: *std.Build.Step.Run,
    run_scene_core_runtime: *std.Build.Step.Run,
    run_scene_core_registry: *std.Build.Step.Run,
    run_stress: *std.Build.Step.Run,
    run_integration: *std.Build.Step.Run,
};

pub fn register(options: Options) Registration {
    const b = options.b;
    const target = options.target;
    const optimize = options.optimize;
    const modules = options.modules;

    const engine_composition_tests = b.addTest(.{
        .name = "engine-composition-tests",
        .root_module = modules.engine_composition_test_module,
    });
    const run_engine_composition_tests = b.addRunArtifact(engine_composition_tests);
    const engine_composition_test_step = b.step(
        "test-engine-composition",
        "Run independent RuntimeScene, character-binding, interaction, and render-data composition proofs",
    );
    engine_composition_test_step.dependOn(&run_engine_composition_tests.step);

    const camera_tests = b.addTest(.{
        .name = "camera-tests",
        .root_module = modules.camera_test_module,
    });
    const run_camera_tests = b.addRunArtifact(camera_tests);
    const camera_test_step = b.step(
        "test-camera",
        "Run focused height-relative viewport, camera transform, and simulation-invariance tests",
    );
    camera_test_step.dependOn(&run_camera_tests.step);
    const renderer_boundary_test_module = b.createModule(.{
        .root_source_file = b.path("tests/renderer_boundary_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    renderer_boundary_test_module.addImport("frame_capture", modules.frame_capture_module);
    const renderer_boundary_tests = b.addTest(.{
        .name = "renderer-boundary-tests",
        .root_module = renderer_boundary_test_module,
    });
    const run_renderer_boundary_tests = b.addRunArtifact(renderer_boundary_tests);
    const renderer_boundary_test_step = b.step(
        "test-renderer-boundary",
        "Run focused copied-frame ownership and capture-contract tests",
    );
    renderer_boundary_test_step.dependOn(&run_renderer_boundary_tests.step);
    const art_test_module = b.createModule(.{
        .root_source_file = b.path("tests/art_pipeline_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    art_test_module.addImport("art_pack", modules.art_pack_module);
    art_test_module.addImport("art_asset_catalog", modules.art_asset_catalog_module);
    art_test_module.addImport("art_asset_demo", modules.art_asset_demo_module);
    art_test_module.addImport("render_queue", modules.render_queue_module);
    const foundation_primitive_tests = b.addTest(.{
        .name = "foundation-primitive-tests",
        .root_module = modules.foundation_primitive_test_module,
    });
    const run_foundation_primitive_tests = b.addRunArtifact(foundation_primitive_tests);
    const foundation_primitive_test_step = b.step(
        "test-foundation-primitives",
        "Run F2A identity, reference, spatial, canonical-data, and determinism tests",
    );
    foundation_primitive_test_step.dependOn(&run_foundation_primitive_tests.step);

    const f4c4_adoption_test_module = b.createModule(.{
        .root_source_file = b.path("tests/f4c4_adoption_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    f4c4_adoption_test_module.addImport("foundation", modules.foundation_module);
    f4c4_adoption_test_module.addImport("scene_core", modules.scene_core_module);
    f4c4_adoption_test_module.addImport("physical_input", modules.physical_input_module);
    f4c4_adoption_test_module.addImport("input", modules.input_module);
    f4c4_adoption_test_module.addImport("character", modules.character_module);
    f4c4_adoption_test_module.addImport("character_entity_binding", modules.character_entity_binding_module);
    f4c4_adoption_test_module.addImport("integrated_demo", modules.integrated_demo_module);
    const f4c4_adoption_tests = b.addTest(.{
        .name = "f4c4-adoption-tests",
        .root_module = f4c4_adoption_test_module,
    });
    const run_f4c4_adoption_tests = b.addRunArtifact(f4c4_adoption_tests);
    const f4c4_adoption_test_step = b.step(
        "test-f4c4-adoption",
        "Run F4C4 scene-core binding and application-action boundary tests",
    );
    f4c4_adoption_test_step.dependOn(&run_f4c4_adoption_tests.step);

    const scene_core_authored_tests = b.addTest(.{
        .name = "scene-core-authored-tests",
        .root_module = modules.scene_core_authored_test_module,
    });
    const run_scene_core_authored_tests = b.addRunArtifact(scene_core_authored_tests);
    const scene_core_authored_test_step = b.step(
        "test-scene-core-authored",
        "Run F2B authored prefab, level, world, serialization, migration, and validation tests",
    );
    scene_core_authored_test_step.dependOn(&run_scene_core_authored_tests.step);
    const scene_core_runtime_tests = b.addTest(.{
        .name = "scene-core-runtime-tests",
        .root_module = modules.scene_core_runtime_test_module,
    });
    const run_scene_core_runtime_tests = b.addRunArtifact(scene_core_runtime_tests);
    const scene_core_registry_tests = b.addTest(.{
        .name = "scene-core-registry-internal-tests",
        .root_module = modules.scene_core_registry_test_module,
    });
    const run_scene_core_registry_tests = b.addRunArtifact(scene_core_registry_tests);
    const scene_core_runtime_test_step = b.step(
        "test-scene-core-runtime",
        "Run F2C runtime scene assembly, registry, lifecycle, snapshot, and consumer tests",
    );
    scene_core_runtime_test_step.dependOn(&run_scene_core_runtime_tests.step);
    scene_core_runtime_test_step.dependOn(&run_scene_core_registry_tests.step);

    const deterministic_test_filter = b.option(
        []const u8,
        "test-filter",
        "Run only deterministic tests whose names contain this text",
    );
    const tests = b.addTest(.{
        .name = "deterministic-tests",
        .root_module = modules.test_module,
        .filters = if (deterministic_test_filter) |filter| &.{filter} else &.{},
    });
    const run_tests = b.addRunArtifact(tests);
    const deterministic_test_step = b.step(
        "test-deterministic",
        "Run the deterministic CPU test aggregate; optionally narrow with -Dtest-filter=<text>",
    );
    deterministic_test_step.dependOn(&run_tests.step);
    const stress_tests = b.addTest(.{
        .name = "stress-tests",
        .root_module = modules.stress_test_module,
    });
    const run_stress_tests = b.addRunArtifact(stress_tests);
    const stress_test_step = b.step(
        "test-stress",
        "Run long-duration 1,000-interaction and 100,000-tick deterministic stress tests",
    );
    stress_test_step.dependOn(&run_stress_tests.step);

    const integration_tests = b.addTest(.{
        .name = "integration-tests",
        .root_module = modules.integration_test_module,
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);
    const integration_test_step = b.step(
        "test-integration",
        "Run full deterministic production-route integration regressions",
    );
    integration_test_step.dependOn(&run_integration_tests.step);

    return .{
        .run_engine_composition = run_engine_composition_tests,
        .run_deterministic = run_tests,
        .run_renderer_boundary = run_renderer_boundary_tests,
        .run_foundation_primitives = run_foundation_primitive_tests,
        .run_f4c4_adoption = run_f4c4_adoption_tests,
        .run_scene_core_authored = run_scene_core_authored_tests,
        .run_scene_core_runtime = run_scene_core_runtime_tests,
        .run_scene_core_registry = run_scene_core_registry_tests,
        .run_stress = run_stress_tests,
        .run_integration = run_integration_tests,
    };
}
