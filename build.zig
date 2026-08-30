const std = @import("std");
const builtin = @import("builtin");

const required_zig = std.SemanticVersion{ .major = 0, .minor = 16, .patch = 0 };

const ShaderOutput = struct {
    step: *std.Build.Step.Run,
    output: std.Build.LazyPath,
};

pub fn build(b: *std.Build) void {
    comptime {
        if (builtin.zig_version.order(required_zig) != .eq) {
            @compileError("this project requires Zig 0.16.0 exactly");
        }
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    if (target.result.os.tag != .windows or target.result.cpu.arch != .x86_64) {
        std.debug.panic("this repository supports only Windows x86_64; selected target is {s}-{s}", .{
            @tagName(target.result.cpu.arch),
            @tagName(target.result.os.tag),
        });
    }

    const sdl_include = ".deps/SDL3-3.4.10/include";
    const sdl_library_dir = ".deps/SDL3-3.4.10/lib/x64";
    const sdl_library = ".deps/SDL3-3.4.10/lib/x64/SDL3.lib";
    const sdl_runtime = ".deps/SDL3-3.4.10/lib/x64/SDL3.dll";
    const dxc = ".deps/dxc-1.9.2602.24/bin/x64/dxc.exe";
    const dxcompiler = ".deps/dxc-1.9.2602.24/bin/x64/dxcompiler.dll";
    const dxil = ".deps/dxc-1.9.2602.24/bin/x64/dxil.dll";
    const dxv = ".deps/dxc-1.9.2602.24/bin/x64/dxv.exe";
    const shader_source = "assets/shaders/sprite.hlsl";
    const mesh_shader_source = "assets/shaders/deformable_mesh.hlsl";
    const mechanical_art_atlas = "assets/art/p23_mechanical_atlas.png";
    const energy_art_atlas = "assets/art/p23_energy_atlas.png";
    const male_character_atlas = "assets/art/p27c_male_base_anatomy_atlas.png";
    const female_character_atlas = "assets/art/p27c_female_base_anatomy_atlas.png";
    const character_component_atlas = "assets/art/p27c_anatomy_components_atlas.png";
    const wardrobe_upper_atlas = "assets/art/p25_wardrobe_upper_atlas.png";
    const wardrobe_layers_atlas = "assets/art/p25_wardrobe_layers_atlas.png";
    const wardrobe_lower_atlas = "assets/art/p25_wardrobe_lower_atlas.png";
    const violet_environment_atlas = "assets/art/p26_violet_crystal_ruin_atlas.png";
    const debug_environment_atlas = "assets/art/p26_neutral_debug_atlas.png";

    for ([_][]const u8{
        sdl_library,
        sdl_runtime,
        dxc,
        dxcompiler,
        dxil,
        dxv,
        shader_source,
        mesh_shader_source,
        mechanical_art_atlas,
        energy_art_atlas,
        male_character_atlas,
        female_character_atlas,
        character_component_atlas,
        wardrobe_upper_atlas,
        wardrobe_layers_atlas,
        wardrobe_lower_atlas,
        violet_environment_atlas,
        debug_environment_atlas,
        "tools/dependencies.lock.json",
    }) |path| {
        requireFile(b, path);
    }

    const vertex_shader = addShaderCompile(b, .{
        .dxc = dxc,
        .dxcompiler = dxcompiler,
        .dxil = dxil,
        .dxv = dxv,
        .source = shader_source,
        .stage = "vertex",
        .entry_point = "VSMain",
        .target_profile = "vs_6_0",
        .configuration = @tagName(optimize),
        .output_name = "sprite_vs.dxil",
    });
    const fragment_shader = addShaderCompile(b, .{
        .dxc = dxc,
        .dxcompiler = dxcompiler,
        .dxil = dxil,
        .dxv = dxv,
        .source = shader_source,
        .stage = "fragment",
        .entry_point = "PSMain",
        .target_profile = "ps_6_0",
        .configuration = @tagName(optimize),
        .output_name = "sprite_ps.dxil",
    });
    const mesh_vertex_shader = addShaderCompile(b, .{
        .dxc = dxc,
        .dxcompiler = dxcompiler,
        .dxil = dxil,
        .dxv = dxv,
        .source = mesh_shader_source,
        .stage = "vertex",
        .entry_point = "VSMain",
        .target_profile = "vs_6_0",
        .configuration = @tagName(optimize),
        .output_name = "deformable_mesh_vs.dxil",
    });

    const shaders_step = b.step("shaders", "Compile and validate HLSL as pinned DXIL artifacts");
    shaders_step.dependOn(&vertex_shader.step.step);
    shaders_step.dependOn(&fragment_shader.step.step);
    shaders_step.dependOn(&mesh_vertex_shader.step.step);

    const app_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    app_module.addIncludePath(b.path(sdl_include));
    app_module.addLibraryPath(b.path(sdl_library_dir));
    app_module.linkSystemLibrary("SDL3", .{ .preferred_link_mode = .dynamic, .search_strategy = .paths_first });

    const app = b.addExecutable(.{
        .name = "skeletal_gpu_demo",
        .root_module = app_module,
    });
    b.installArtifact(app);

    const install_sdl = b.addInstallFileWithDir(b.path(sdl_runtime), .bin, "SDL3.dll");
    const install_vertex_shader = b.addInstallFileWithDir(vertex_shader.output, .bin, "shaders/sprite_vs.dxil");
    const install_fragment_shader = b.addInstallFileWithDir(fragment_shader.output, .bin, "shaders/sprite_ps.dxil");
    const install_mesh_vertex_shader = b.addInstallFileWithDir(mesh_vertex_shader.output, .bin, "shaders/deformable_mesh_vs.dxil");
    const install_mechanical_art_atlas = b.addInstallFileWithDir(b.path(mechanical_art_atlas), .bin, "art/p23_mechanical_atlas.png");
    const install_energy_art_atlas = b.addInstallFileWithDir(b.path(energy_art_atlas), .bin, "art/p23_energy_atlas.png");
    const install_male_character_atlas = b.addInstallFileWithDir(b.path(male_character_atlas), .bin, "art/p27c_male_base_anatomy_atlas.png");
    const install_female_character_atlas = b.addInstallFileWithDir(b.path(female_character_atlas), .bin, "art/p27c_female_base_anatomy_atlas.png");
    const install_character_component_atlas = b.addInstallFileWithDir(b.path(character_component_atlas), .bin, "art/p27c_anatomy_components_atlas.png");
    const install_wardrobe_upper_atlas = b.addInstallFileWithDir(b.path(wardrobe_upper_atlas), .bin, "art/p25_wardrobe_upper_atlas.png");
    const install_wardrobe_layers_atlas = b.addInstallFileWithDir(b.path(wardrobe_layers_atlas), .bin, "art/p25_wardrobe_layers_atlas.png");
    const install_wardrobe_lower_atlas = b.addInstallFileWithDir(b.path(wardrobe_lower_atlas), .bin, "art/p25_wardrobe_lower_atlas.png");
    const install_violet_environment_atlas = b.addInstallFileWithDir(b.path(violet_environment_atlas), .bin, "art/p26_violet_crystal_ruin_atlas.png");
    const install_debug_environment_atlas = b.addInstallFileWithDir(b.path(debug_environment_atlas), .bin, "art/p26_neutral_debug_atlas.png");
    b.getInstallStep().dependOn(&install_sdl.step);
    b.getInstallStep().dependOn(&install_vertex_shader.step);
    b.getInstallStep().dependOn(&install_fragment_shader.step);
    b.getInstallStep().dependOn(&install_mesh_vertex_shader.step);
    b.getInstallStep().dependOn(&install_mechanical_art_atlas.step);
    b.getInstallStep().dependOn(&install_energy_art_atlas.step);
    b.getInstallStep().dependOn(&install_male_character_atlas.step);
    b.getInstallStep().dependOn(&install_female_character_atlas.step);
    b.getInstallStep().dependOn(&install_character_component_atlas.step);
    b.getInstallStep().dependOn(&install_wardrobe_upper_atlas.step);
    b.getInstallStep().dependOn(&install_wardrobe_layers_atlas.step);
    b.getInstallStep().dependOn(&install_wardrobe_lower_atlas.step);
    b.getInstallStep().dependOn(&install_violet_environment_atlas.step);
    b.getInstallStep().dependOn(&install_debug_environment_atlas.step);

    const installed_executable = b.getInstallPath(.bin, app.out_filename);
    const run_command = b.addSystemCommand(&.{installed_executable});
    run_command.setName("run installed skeletal_gpu_demo");
    run_command.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_command.addArgs(args);
    const run_step = b.step("run", "Run the installed sprite-batch, character, interaction, playground, foundation, or side-scroller demonstration");
    run_step.dependOn(&run_command.step);

    const gpu_smoke_command = b.addSystemCommand(&.{ installed_executable, "--gpu-smoke" });
    gpu_smoke_command.setName("run D3D12/DXIL draw and readback smoke test");
    gpu_smoke_command.step.dependOn(b.getInstallStep());
    const gpu_smoke_step = b.step("gpu-smoke", "Require and verify D3D12/DXIL rendering with GPU readback");
    gpu_smoke_step.dependOn(&gpu_smoke_command.step);

    const foundation_module = b.createModule(.{
        .root_source_file = b.path("src/foundation/root.zig"),
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
    const human_geometry_refinement_export_module = b.createModule(.{
        .root_source_file = b.path("tools/export_human_geometry_refinement_evidence.zig"),
        .target = target,
        .optimize = optimize,
    });
    human_geometry_refinement_export_module.addImport("canonical_model", canonical_model_module);
    human_geometry_refinement_export_module.addImport("canonical_geometry", canonical_geometry_module);
    human_geometry_refinement_export_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const human_geometry_refinement_export = b.addExecutable(.{
        .name = "export-human-geometry-refinement-evidence",
        .root_module = human_geometry_refinement_export_module,
    });
    const run_human_geometry_refinement_export = b.addRunArtifact(human_geometry_refinement_export);
    const convert_human_geometry_refinement_images = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    convert_human_geometry_refinement_images.addFileArg(b.path("tools/convert_human_geometry_ppm_to_png.ps1"));
    convert_human_geometry_refinement_images.addArgs(&.{
        "-EvidenceDirectory",
        "assets/canonical_model/human_base/geometry/evidence/prompt_2c",
        "-ContactSheetName",
        "human_base_main_body_owner_review_contact_sheet.png",
    });
    convert_human_geometry_refinement_images.setName("convert Prompt 2C PPM evidence and compose the owner contact sheet");
    convert_human_geometry_refinement_images.step.dependOn(&run_human_geometry_refinement_export.step);
    const human_geometry_refinement_export_step = b.step(
        "update-human-geometry-refinement-evidence",
        "Explicitly regenerate Prompt 2C derived OBJ, report, PPM, PNG, and contact-sheet evidence",
    );
    human_geometry_refinement_export_step.dependOn(&convert_human_geometry_refinement_images.step);
    const human_geometry_r1_export_module = b.createModule(.{
        .root_source_file = b.path("tools/export_human_geometry_r1_evidence.zig"),
        .target = target,
        .optimize = optimize,
    });
    human_geometry_r1_export_module.addImport("canonical_model", canonical_model_module);
    human_geometry_r1_export_module.addImport("canonical_geometry", canonical_geometry_module);
    human_geometry_r1_export_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const human_geometry_r1_export = b.addExecutable(.{
        .name = "export-human-geometry-r1-evidence",
        .root_module = human_geometry_r1_export_module,
    });
    const run_human_geometry_r1_export = b.addRunArtifact(human_geometry_r1_export);
    const convert_human_geometry_r1_images = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    convert_human_geometry_r1_images.addFileArg(b.path("tools/convert_human_geometry_ppm_to_png.ps1"));
    convert_human_geometry_r1_images.addArgs(&.{
        "-EvidenceDirectory",
        "assets/canonical_model/human_base/geometry/evidence/prompt_2c_r1",
        "-ContactSheetName",
        "human_base_main_body_r1_owner_review_contact_sheet.png",
        "-Columns",
        "4",
        "-OutputWidth",
        "960",
        "-OutputHeight",
        "1200",
    });
    convert_human_geometry_r1_images.setName("convert Prompt 2C-R1 PPM evidence and compose the owner contact sheet");
    convert_human_geometry_r1_images.step.dependOn(&run_human_geometry_r1_export.step);
    const human_geometry_r1_export_step = b.step(
        "update-human-geometry-r1-evidence",
        "Explicitly regenerate Prompt 2C-R1 derived OBJ, report, PPM, PNG, and contact-sheet evidence",
    );
    human_geometry_r1_export_step.dependOn(&convert_human_geometry_r1_images.step);
    const human_geometry_candidate_validator_module = b.createModule(.{
        .root_source_file = b.path("tools/validate_human_geometry_candidate.zig"),
        .target = target,
        .optimize = optimize,
    });
    human_geometry_candidate_validator_module.addImport("canonical_geometry", canonical_geometry_module);
    human_geometry_candidate_validator_module.addImport("canonical_human_geometry", canonical_human_geometry_module);
    const human_geometry_candidate_validator = b.addExecutable(.{
        .name = "validate-human-geometry-candidate",
        .root_module = human_geometry_candidate_validator_module,
    });
    const install_human_geometry_candidate_validator = b.addInstallArtifact(
        human_geometry_candidate_validator,
        .{},
    );
    const run_human_geometry_candidate_validator = b.addRunArtifact(human_geometry_candidate_validator);
    if (b.args) |args| run_human_geometry_candidate_validator.addArgs(args);
    const human_geometry_candidate_validator_step = b.step(
        "validate-human-geometry-candidate",
        "Validate and hash an explicitly selected human geometry candidate without promotion",
    );
    human_geometry_candidate_validator_step.dependOn(&run_human_geometry_candidate_validator.step);
    const blender_bridge_tests = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    blender_bridge_tests.addFileArg(b.path("tools/blender_bridge.ps1"));
    blender_bridge_tests.addArgs(&.{
        "-Command",
        "Test",
        "-Working",
        ".authoring-work/blender-bridge-test/human_base_geometry_t3_working.blend",
        "-Sidecar",
        ".authoring-work/blender-bridge-test/human_base_geometry_t3_working.sidecar.json",
        "-Candidate",
        ".authoring-work/blender-bridge-test/human_base_geometry.candidate.json",
        "-Evidence",
        ".authoring-work/blender-bridge-test/human_base_geometry.candidate.validation.txt",
    });
    blender_bridge_tests.setName("run pinned Blender bridge fail-closed and no-op round-trip tests");
    blender_bridge_tests.step.dependOn(&install_human_geometry_candidate_validator.step);
    const blender_bridge_test_step = b.step(
        "test-blender-bridge",
        "Run specialized pinned Blender 4.5.9 bridge and canonical round-trip tests",
    );
    blender_bridge_test_step.dependOn(&blender_bridge_tests.step);
    const human_base_export_module = b.createModule(.{
        .root_source_file = b.path("tools/export_human_base_evidence.zig"),
        .target = target,
        .optimize = optimize,
    });
    human_base_export_module.addImport("canonical_model", canonical_model_module);
    const human_base_export = b.addExecutable(.{
        .name = "export-human-base-evidence",
        .root_module = human_base_export_module,
    });
    const run_human_base_export = b.addRunArtifact(human_base_export);
    const human_base_export_step = b.step(
        "update-human-base-evidence",
        "Explicitly regenerate reviewed human_base derived evidence from the authoritative authoring source",
    );
    human_base_export_step.dependOn(&run_human_base_export.step);
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
    const input_module = b.createModule(.{
        .root_source_file = b.path("src/platform/input.zig"),
        .target = target,
        .optimize = optimize,
    });
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
    sdl_input_module.addImport("input", input_module);
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
    character_controller_module.addImport("input", input_module);
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
    const art_asset_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/art_asset_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    art_asset_demo_module.addImport("art_pack", art_pack_module);
    art_asset_demo_module.addImport("art_asset_catalog", art_asset_catalog_module);
    art_asset_demo_module.addImport("deformable_mesh", deformable_mesh_module);
    art_asset_demo_module.addImport("math", math_module);
    art_asset_demo_module.addImport("render_queue", render_queue_module);
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
    character_module.addImport("animator", animator_module);
    character_module.addImport("animation_system", animation_system_module);
    character_module.addImport("state_machine", state_machine_module);
    character_module.addImport("procedural_motion", procedural_motion_module);
    character_module.addImport("arm_ik", arm_ik_module);
    character_module.addImport("leg_ik", leg_ik_module);
    character_module.addImport("foot_planting", foot_planting_module);
    character_module.addImport("fixed_step", fixed_step_module);
    character_module.addImport("input", input_module);
    character_module.addImport("presentation_view", presentation_view_module);
    character_module.addImport("collision_world", collision_world_module);
    character_module.addImport("character_controller", character_controller_module);
    character_module.addImport("sprite_batch", sprite_batch_module);
    character_module.addImport("deformable_mesh", deformable_mesh_module);
    character_module.addImport("render_queue", render_queue_module);
    character_module.addImport("fault_injection", fault_injection_module);
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
    interaction_system_module.addImport("input", input_module);
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
    app_module.addImport("humanoid", humanoid_module);
    app_module.addImport("appearance", appearance_module);
    app_module.addImport("anatomy", anatomy_module);
    app_module.addImport("equipment", equipment_module);
    app_module.addImport("character_properties", character_properties_module);
    app_module.addImport("deformation", deformation_module);
    app_module.addImport("math", math_module);
    app_module.addImport("camera2d", camera2d_module);
    app_module.addImport("animation_system", animation_system_module);
    app_module.addImport("sprite_batch", sprite_batch_module);
    app_module.addImport("deformable_mesh", deformable_mesh_module);
    app_module.addImport("render_queue", render_queue_module);
    app_module.addImport("mesh_gpu_catalog", mesh_gpu_catalog_module);
    app_module.addImport("fault_injection", fault_injection_module);
    app_module.addImport("input", input_module);
    app_module.addImport("sdl", sdl_module);
    app_module.addImport("sdl_input", sdl_input_module);
    app_module.addImport("fixed_step", fixed_step_module);
    app_module.addImport("spring", spring_module);
    app_module.addImport("collider", collider_module);
    app_module.addImport("collision_world", collision_world_module);
    app_module.addImport("character_controller", character_controller_module);
    app_module.addImport("controller_demo", controller_demo_module);
    app_module.addImport("procedural_motion", procedural_motion_module);
    app_module.addImport("character", character_module);
    app_module.addImport("interaction", interaction_module);
    app_module.addImport("handshake", handshake_module);
    app_module.addImport("interaction_system", interaction_system_module);
    app_module.addImport("handshake_ik_demo", handshake_ik_demo_module);
    app_module.addImport("diagnostics", diagnostics_module);
    app_module.addImport("debug_draw", debug_draw_module);
    app_module.addImport("integrated_demo", integrated_demo_module);
    app_module.addImport("playground_demo", playground_demo_module);
    app_module.addImport("modular_body_demo", modular_body_demo_module);
    app_module.addImport("equipment_demo", equipment_demo_module);
    app_module.addImport("mesh_attachment_demo", mesh_attachment_demo_module);
    app_module.addImport("foundation_playground", foundation_playground_module);
    app_module.addImport("art_pack", art_pack_module);
    app_module.addImport("image_decode", image_decode_module);
    app_module.addImport("art_asset_demo", art_asset_demo_module);
    app_module.addImport("presentation_view", presentation_view_module);
    app_module.addImport("presentation_pose", presentation_pose_module);
    app_module.addImport("character_art", character_art_module);
    app_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    app_module.addImport("wardrobe_art", wardrobe_art_module);
    app_module.addImport("wardrobe_presentation", wardrobe_presentation_module);
    app_module.addImport("wardrobe_demo", wardrobe_demo_module);
    app_module.addImport("environment_art", environment_art_module);
    app_module.addImport("environment_theme", environment_theme_module);
    app_module.addImport("environment_demo", environment_demo_module);
    app_module.addImport("foundation_evidence", foundation_evidence_module);
    app_module.addImport("foundation_coherence", foundation_coherence_module);
    app_module.addImport("acceptance_hud", acceptance_hud_module);
    app_module.addImport("visual_foundation", visual_foundation_module);
    app_module.addImport("visual_geometry", visual_geometry_module);
    app_module.addImport("visual_registration", visual_registration_module);
    app_module.addImport("visual_geometry_audit", visual_geometry_audit_module);
    app_module.addImport("visual_geometry_overlay", visual_geometry_overlay_module);
    app_module.addImport("visual_truth", visual_truth_module);
    app_module.addImport("anatomy_evidence", anatomy_evidence_module);
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
    test_module.addImport("art_asset_demo", art_asset_demo_module);
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
    const camera_tests = b.addTest(.{
        .name = "camera-tests",
        .root_module = camera_test_module,
    });
    const run_camera_tests = b.addRunArtifact(camera_tests);
    const camera_test_step = b.step(
        "test-camera",
        "Run focused height-relative viewport, camera transform, and simulation-invariance tests",
    );
    camera_test_step.dependOn(&run_camera_tests.step);
    const art_test_module = b.createModule(.{
        .root_source_file = b.path("tests/art_pipeline_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    art_test_module.addImport("art_pack", art_pack_module);
    art_test_module.addImport("art_asset_catalog", art_asset_catalog_module);
    art_test_module.addImport("art_asset_demo", art_asset_demo_module);
    art_test_module.addImport("render_queue", render_queue_module);
    const art_tests = b.addTest(.{ .name = "art-pipeline-tests", .root_module = art_test_module });
    const run_art_tests = b.addRunArtifact(art_tests);
    const image_decode_test_module = b.createModule(.{
        .root_source_file = b.path("tests/image_decode_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    image_decode_test_module.addImport("image_decode", image_decode_module);
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
    presentation_test_module.addImport("input", input_module);
    presentation_test_module.addImport("humanoid", humanoid_module);
    presentation_test_module.addImport("character", character_module);
    presentation_test_module.addImport("presentation_view", presentation_view_module);
    presentation_test_module.addImport("presentation_pose", presentation_pose_module);
    presentation_test_module.addImport("character_art", character_art_module);
    presentation_test_module.addImport("modular_body_demo", modular_body_demo_module);
    presentation_test_module.addImport("modular_humanoid", modular_humanoid_module);
    presentation_test_module.addImport("handshake_ik_demo", handshake_ik_demo_module);
    presentation_test_module.addImport("render_queue", render_queue_module);
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
    component_graph_test_module.addImport("math", math_module);
    component_graph_test_module.addImport("anatomy", anatomy_module);
    component_graph_test_module.addImport("appearance", appearance_module);
    component_graph_test_module.addImport("component_graph", component_graph_module);
    component_graph_test_module.addImport("humanoid", humanoid_module);
    component_graph_test_module.addImport("modular_body_demo", modular_body_demo_module);
    component_graph_test_module.addImport("presentation_pose", presentation_pose_module);
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
    wardrobe_test_module.addImport("math", math_module);
    wardrobe_test_module.addImport("input", input_module);
    wardrobe_test_module.addImport("character_controller", character_controller_module);
    wardrobe_test_module.addImport("equipment", equipment_module);
    wardrobe_test_module.addImport("humanoid", humanoid_module);
    wardrobe_test_module.addImport("character", character_module);
    wardrobe_test_module.addImport("presentation_view", presentation_view_module);
    wardrobe_test_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    wardrobe_test_module.addImport("wardrobe_art", wardrobe_art_module);
    wardrobe_test_module.addImport("wardrobe_presentation", wardrobe_presentation_module);
    wardrobe_test_module.addImport("wardrobe_demo", wardrobe_demo_module);
    wardrobe_test_module.addImport("modular_humanoid", modular_humanoid_module);
    wardrobe_test_module.addImport("authored_clips", authored_clips_module);
    wardrobe_test_module.addImport("render_queue", render_queue_module);
    wardrobe_test_module.addImport("character_art", character_art_module);
    wardrobe_test_module.addImport("visual_geometry", visual_geometry_module);
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
    visual_registration_test_module.addImport("math", math_module);
    visual_registration_test_module.addImport("sprite_batch", sprite_batch_module);
    visual_registration_test_module.addImport("visual_geometry", visual_geometry_module);
    visual_registration_test_module.addImport("visual_registration", visual_registration_module);
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
    visual_geometry_test_module.addImport("math", math_module);
    visual_geometry_test_module.addImport("sprite_batch", sprite_batch_module);
    visual_geometry_test_module.addImport("camera2d", camera2d_module);
    visual_geometry_test_module.addImport("image_decode", image_decode_module);
    visual_geometry_test_module.addImport("render_queue", render_queue_module);
    visual_geometry_test_module.addImport("presentation_view", presentation_view_module);
    visual_geometry_test_module.addImport("humanoid", humanoid_module);
    visual_geometry_test_module.addImport("wardrobe_catalog", wardrobe_catalog_module);
    visual_geometry_test_module.addImport("wardrobe_demo", wardrobe_demo_module);
    visual_geometry_test_module.addImport("visual_geometry", visual_geometry_module);
    visual_geometry_test_module.addImport("visual_geometry_audit", visual_geometry_audit_module);
    visual_geometry_test_module.addImport("anatomy_quality", anatomy_quality_module);
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
    const visual_geometry_report_module = b.createModule(.{
        .root_source_file = b.path("src/scene/visual_geometry_report.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    visual_geometry_report_module.addImport("camera2d", camera2d_module);
    visual_geometry_report_module.addImport("image_decode", image_decode_module);
    visual_geometry_report_module.addImport("render_queue", render_queue_module);
    visual_geometry_report_module.addImport("presentation_view", presentation_view_module);
    visual_geometry_report_module.addImport("humanoid", humanoid_module);
    visual_geometry_report_module.addImport("wardrobe_demo", wardrobe_demo_module);
    visual_geometry_report_module.addImport("visual_geometry", visual_geometry_module);
    visual_geometry_report_module.addImport("visual_geometry_audit", visual_geometry_audit_module);
    const visual_geometry_report_exe = b.addExecutable(.{
        .name = "visual_geometry_report",
        .root_module = visual_geometry_report_module,
    });
    const run_visual_geometry_report = b.addRunArtifact(visual_geometry_report_exe);
    const visual_geometry_report_step = b.step(
        "visual-geometry-report",
        "Write Prompt 25D human and machine production-acceptance reports",
    );
    visual_geometry_report_step.dependOn(&run_visual_geometry_report.step);
    const anatomy_quality_report_module = b.createModule(.{
        .root_source_file = b.path("src/scene/anatomy_quality_report.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    anatomy_quality_report_module.addImport("camera2d", camera2d_module);
    anatomy_quality_report_module.addImport("image_decode", image_decode_module);
    anatomy_quality_report_module.addImport("render_queue", render_queue_module);
    anatomy_quality_report_module.addImport("presentation_view", presentation_view_module);
    anatomy_quality_report_module.addImport("humanoid", humanoid_module);
    anatomy_quality_report_module.addImport("wardrobe_demo", wardrobe_demo_module);
    anatomy_quality_report_module.addImport("visual_geometry", visual_geometry_module);
    anatomy_quality_report_module.addImport("visual_geometry_audit", visual_geometry_audit_module);
    anatomy_quality_report_module.addImport("anatomy_quality", anatomy_quality_module);
    const anatomy_quality_report_exe = b.addExecutable(.{
        .name = "anatomy_quality_report",
        .root_module = anatomy_quality_report_module,
    });
    const run_anatomy_quality_report = b.addRunArtifact(anatomy_quality_report_exe);
    if (b.args) |args| run_anatomy_quality_report.addArgs(args);
    const anatomy_quality_report_step = b.step(
        "p27c-anatomy-report",
        "Write Prompt 27C anatomy-silhouette, proportion, and continuity evidence",
    );
    anatomy_quality_report_step.dependOn(&run_anatomy_quality_report.step);
    const p27c_art_audit = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    p27c_art_audit.addFileArg(b.path("tools/audit_p27c_art.ps1"));
    p27c_art_audit.setName("audit Prompt 27C production anatomy pages");
    const p27c_r1_torso_audit = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    p27c_r1_torso_audit.addFileArg(
        b.path("tools/audit_p27c_r1_torso.ps1"),
    );
    p27c_r1_torso_audit.setName(
        "audit Prompt 27C-R1 torso correction bounds and fixtures",
    );
    const p27c_r1_torso_audit_step = b.step(
        "audit-p27c-r1-torso",
        "Audit Prompt 27C-R1 torso pixels, alpha, continuity, and fixtures",
    );
    p27c_r1_torso_audit_step.dependOn(&p27c_art_audit.step);
    p27c_r1_torso_audit_step.dependOn(&p27c_r1_torso_audit.step);
    const p27c_r1_review_package = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    p27c_r1_review_package.addFileArg(
        b.path("tools/build_p27c_r1_review_package.ps1"),
    );
    p27c_r1_review_package.setName(
        "build Prompt 27C-R1 provenance and owner-review package",
    );
    const p27c_r1_review_step = b.step(
        "p27c-r1-review",
        "Build the Prompt 27C-R1 provenance and owner-review package",
    );
    p27c_r1_review_step.dependOn(&p27c_r1_review_package.step);
    visual_geometry_test_step.dependOn(&p27c_art_audit.step);
    visual_geometry_test_step.dependOn(&p27c_r1_torso_audit.step);
    const verify_p25d_goldens = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    verify_p25d_goldens.addFileArg(b.path("tools/check_p25d_goldens.ps1"));
    verify_p25d_goldens.setName("verify approved Prompt 25D D3D12 goldens");
    const p25d_golden_step = b.step(
        "check-p25d-goldens",
        "Verify approved Prompt 25D D3D12/DXIL capture hashes",
    );
    p25d_golden_step.dependOn(&verify_p25d_goldens.step);
    const foundation_test_module = b.createModule(.{
        .root_source_file = b.path("tests/foundation_playground_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    foundation_test_module.addImport("math", math_module);
    foundation_test_module.addImport("input", input_module);
    foundation_test_module.addImport("equipment", equipment_module);
    foundation_test_module.addImport("render_queue", render_queue_module);
    foundation_test_module.addImport("camera2d", camera2d_module);
    foundation_test_module.addImport("foundation_playground", foundation_playground_module);
    foundation_test_module.addImport("foundation_world", foundation_world_module);
    const foundation_tests = b.addTest(.{ .name = "foundation-playground-tests", .root_module = foundation_test_module });
    const run_foundation_tests = b.addRunArtifact(foundation_tests);
    const foundation_test_step = b.step("test-foundation", "Run the Prompt 22 deterministic foundation-playground tests");
    foundation_test_step.dependOn(&run_foundation_tests.step);
    const environment_test_module = b.createModule(.{
        .root_source_file = b.path("tests/environment_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    environment_test_module.addImport("math", math_module);
    environment_test_module.addImport("input", input_module);
    environment_test_module.addImport("art_pack", art_pack_module);
    environment_test_module.addImport("collider", collider_module);
    environment_test_module.addImport("collision_world", collision_world_module);
    environment_test_module.addImport("character", character_module);
    environment_test_module.addImport("render_queue", render_queue_module);
    environment_test_module.addImport("foundation_world", foundation_world_module);
    environment_test_module.addImport("environment_art", environment_art_module);
    environment_test_module.addImport("environment_theme", environment_theme_module);
    environment_test_module.addImport("environment_demo", environment_demo_module);
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
    visual_foundation_test_module.addImport("math", math_module);
    visual_foundation_test_module.addImport("input", input_module);
    visual_foundation_test_module.addImport("interaction", interaction_module);
    visual_foundation_test_module.addImport("handshake", handshake_module);
    visual_foundation_test_module.addImport("presentation_view", presentation_view_module);
    visual_foundation_test_module.addImport("render_queue", render_queue_module);
    visual_foundation_test_module.addImport("camera2d", camera2d_module);
    visual_foundation_test_module.addImport("acceptance_hud", acceptance_hud_module);
    visual_foundation_test_module.addImport("foundation_evidence", foundation_evidence_module);
    visual_foundation_test_module.addImport("foundation_coherence", foundation_coherence_module);
    visual_foundation_test_module.addImport("visual_foundation", visual_foundation_module);
    visual_foundation_test_module.addImport("visual_truth", visual_truth_module);
    visual_foundation_test_module.addImport("visual_geometry", visual_geometry_module);
    visual_foundation_test_module.addImport("debug_draw", debug_draw_module);
    visual_foundation_test_module.addImport("anatomy", anatomy_module);
    visual_foundation_test_module.addImport("character_art", character_art_module);
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
    const p27a_review_package = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    p27a_review_package.addFileArg(b.path("tools/build_p27a_review_package.ps1"));
    p27a_review_package.setName("validate and package Prompt 27A D3D12 evidence");
    const p27a_review_step = b.step(
        "p27a-review",
        "Validate Prompt 27A captures and create PNG contact sheets and raw metrics",
    );
    p27a_review_step.dependOn(&p27a_review_package.step);
    const foundation_coherence_report_module = b.createModule(.{
        .root_source_file = b.path("src/scene/foundation_coherence_report.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    foundation_coherence_report_module.addImport("math", math_module);
    foundation_coherence_report_module.addImport("input", input_module);
    foundation_coherence_report_module.addImport("camera2d", camera2d_module);
    foundation_coherence_report_module.addImport("image_decode", image_decode_module);
    foundation_coherence_report_module.addImport("render_queue", render_queue_module);
    foundation_coherence_report_module.addImport("sprite_batch", sprite_batch_module);
    foundation_coherence_report_module.addImport("foundation_evidence", foundation_evidence_module);
    foundation_coherence_report_module.addImport("foundation_coherence", foundation_coherence_module);
    foundation_coherence_report_module.addImport("visual_foundation", visual_foundation_module);
    foundation_coherence_report_module.addImport("visual_geometry", visual_geometry_module);
    foundation_coherence_report_module.addImport("visual_geometry_audit", visual_geometry_audit_module);
    foundation_coherence_report_module.addImport("environment_theme", environment_theme_module);
    const foundation_coherence_report_exe = b.addExecutable(.{
        .name = "foundation_coherence_report",
        .root_module = foundation_coherence_report_module,
    });
    const run_foundation_coherence_report = b.addRunArtifact(
        foundation_coherence_report_exe,
    );
    if (b.args) |args| run_foundation_coherence_report.addArgs(args);
    const foundation_coherence_report_step = b.step(
        "p27b-coherence-report",
        "Write the Prompt 27B semantic production-acceptance report",
    );
    foundation_coherence_report_step.dependOn(
        &run_foundation_coherence_report.step,
    );
    const p27b_review_package = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    p27b_review_package.addFileArg(b.path("tools/build_p27b_review_package.ps1"));
    p27b_review_package.setName("validate and package Prompt 27B D3D12 evidence");
    const p27b_review_step = b.step(
        "p27b-review",
        "Validate Prompt 27B captures, pixel rulers, and review package",
    );
    p27b_review_step.dependOn(&p27b_review_package.step);
    const canonical_model_core_tests = b.addTest(.{
        .name = "canonical-model-core-tests",
        .root_module = canonical_model_core_test_module,
    });
    const run_canonical_model_core_tests = b.addRunArtifact(canonical_model_core_tests);
    const canonical_model_core_test_step = b.step(
        "test-canonical-model-core",
        "Run renderer-independent canonical model core-record tests",
    );
    canonical_model_core_test_step.dependOn(&run_canonical_model_core_tests.step);

    const canonical_model_phase_c_tests = b.addTest(.{
        .name = "canonical-model-phase-c-tests",
        .root_module = canonical_model_phase_c_test_module,
    });
    const run_canonical_model_phase_c_tests = b.addRunArtifact(canonical_model_phase_c_tests);
    const canonical_model_phase_c_test_step = b.step(
        "test-canonical-model-phase-c",
        "Run renderer-independent morphology, material, visibility, and coverage record tests",
    );
    canonical_model_phase_c_test_step.dependOn(&run_canonical_model_phase_c_tests.step);

    const canonical_model_phase_de_tests = b.addTest(.{
        .name = "canonical-model-phase-de-tests",
        .root_module = canonical_model_phase_de_test_module,
    });
    const run_canonical_model_phase_de_tests = b.addRunArtifact(canonical_model_phase_de_tests);
    const canonical_model_phase_de_test_step = b.step(
        "test-canonical-model-phase-de",
        "Run renderer-independent canonical normalization, hashing, validation, and trace tests",
    );
    canonical_model_phase_de_test_step.dependOn(&run_canonical_model_phase_de_tests.step);

    const canonical_model_phase_f_tests = b.addTest(.{
        .name = "canonical-model-phase-f-tests",
        .root_module = canonical_model_phase_f_test_module,
    });
    const run_canonical_model_phase_f_tests = b.addRunArtifact(canonical_model_phase_f_tests);
    const canonical_model_phase_f_test_step = b.step(
        "test-canonical-model-phase-f",
        "Run renderer-independent M01 proof-fixture and determinism acceptance tests",
    );
    canonical_model_phase_f_test_step.dependOn(&run_canonical_model_phase_f_tests.step);

    const canonical_human_identity_tests = b.addTest(.{
        .name = "canonical-human-identity-tests",
        .root_module = canonical_human_identity_test_module,
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
        .root_module = canonical_human_rig_test_module,
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
        .root_module = canonical_human_joint_control_test_module,
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
        .root_module = canonical_human_structural_test_module,
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
        .root_module = canonical_human_base_test_module,
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
        .root_module = canonical_geometry_test_module,
    });
    const run_canonical_geometry_tests = b.addRunArtifact(canonical_geometry_tests);
    const canonical_geometry_test_step = b.step(
        "test-canonical-geometry",
        "Run renderer-independent M03 canonical geometry schema and topology tests",
    );
    canonical_geometry_test_step.dependOn(&run_canonical_geometry_tests.step);

    const foundation_primitive_tests = b.addTest(.{
        .name = "foundation-primitive-tests",
        .root_module = foundation_primitive_test_module,
    });
    const run_foundation_primitive_tests = b.addRunArtifact(foundation_primitive_tests);
    const foundation_primitive_test_step = b.step(
        "test-foundation-primitives",
        "Run F2A identity, reference, spatial, canonical-data, and determinism tests",
    );
    foundation_primitive_test_step.dependOn(&run_foundation_primitive_tests.step);

    const scene_core_authored_tests = b.addTest(.{
        .name = "scene-core-authored-tests",
        .root_module = scene_core_authored_test_module,
    });
    const run_scene_core_authored_tests = b.addRunArtifact(scene_core_authored_tests);
    const scene_core_authored_test_step = b.step(
        "test-scene-core-authored",
        "Run F2B authored prefab, level, world, serialization, migration, and validation tests",
    );
    scene_core_authored_test_step.dependOn(&run_scene_core_authored_tests.step);
    const scene_core_runtime_tests = b.addTest(.{
        .name = "scene-core-runtime-tests",
        .root_module = scene_core_runtime_test_module,
    });
    const run_scene_core_runtime_tests = b.addRunArtifact(scene_core_runtime_tests);
    const scene_core_registry_tests = b.addTest(.{
        .name = "scene-core-registry-internal-tests",
        .root_module = scene_core_registry_test_module,
    });
    const run_scene_core_registry_tests = b.addRunArtifact(scene_core_registry_tests);
    const scene_core_runtime_test_step = b.step(
        "test-scene-core-runtime",
        "Run F2C runtime scene assembly, registry, lifecycle, snapshot, and consumer tests",
    );
    scene_core_runtime_test_step.dependOn(&run_scene_core_runtime_tests.step);
    scene_core_runtime_test_step.dependOn(&run_scene_core_registry_tests.step);

    const canonical_human_geometry_scaffold_tests = b.addTest(.{
        .name = "canonical-human-geometry-scaffold-tests",
        .root_module = canonical_human_geometry_scaffold_test_module,
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
        .root_module = canonical_human_geometry_refinement_test_module,
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
        .root_module = canonical_human_geometry_adoption_test_module,
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
        .root_module = canonical_human_geometry_r3_test_module,
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
        .root_module = canonical_human_geometry_r4_test_module,
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
        .root_module = canonical_human_geometry_full_test_module,
    });
    const run_canonical_human_geometry_full_tests = b.addRunArtifact(canonical_human_geometry_full_tests);
    const canonical_human_geometry_full_test_step = b.step(
        "test-canonical-human-geometry-full",
        "Run expensive M03 human-geometry self-intersection validation",
    );
    canonical_human_geometry_full_test_step.dependOn(&run_canonical_human_geometry_full_tests.step);
    canonical_human_geometry_full_test_step.dependOn(canonical_human_geometry_r4_test_step);

    const deterministic_test_filter = b.option(
        []const u8,
        "test-filter",
        "Run only deterministic tests whose names contain this text",
    );
    const tests = b.addTest(.{
        .name = "deterministic-tests",
        .root_module = test_module,
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
        .root_module = stress_test_module,
    });
    const run_stress_tests = b.addRunArtifact(stress_tests);
    const stress_test_step = b.step(
        "test-stress",
        "Run long-duration 1,000-interaction and 100,000-tick deterministic stress tests",
    );
    stress_test_step.dependOn(&run_stress_tests.step);

    const integration_tests = b.addTest(.{
        .name = "integration-tests",
        .root_module = integration_test_module,
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);
    const integration_test_step = b.step(
        "test-integration",
        "Run full deterministic production-route integration regressions",
    );
    integration_test_step.dependOn(&run_integration_tests.step);

    const test_step = b.step(
        "test",
        "Run the fast CPU development suite without SDL or a GPU",
    );
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_image_decode_tests.step);
    test_step.dependOn(&run_visual_registration_tests.step);
    test_step.dependOn(&run_canonical_model_core_tests.step);
    test_step.dependOn(&run_canonical_model_phase_c_tests.step);
    test_step.dependOn(&run_canonical_model_phase_de_tests.step);
    test_step.dependOn(&run_canonical_model_phase_f_tests.step);
    test_step.dependOn(&run_canonical_human_identity_tests.step);
    test_step.dependOn(&run_canonical_human_rig_tests.step);
    test_step.dependOn(&run_canonical_human_joint_control_tests.step);
    test_step.dependOn(&run_canonical_human_structural_tests.step);
    test_step.dependOn(&run_canonical_human_base_tests.step);
    test_step.dependOn(&run_canonical_geometry_tests.step);
    test_step.dependOn(&run_foundation_primitive_tests.step);
    test_step.dependOn(&run_scene_core_authored_tests.step);
    test_step.dependOn(&run_scene_core_runtime_tests.step);
    test_step.dependOn(&run_scene_core_registry_tests.step);
    test_step.dependOn(&run_canonical_human_geometry_scaffold_tests.step);
    test_step.dependOn(&run_canonical_human_geometry_refinement_tests.step);
    test_step.dependOn(&run_canonical_human_geometry_adoption_tests.step);
    test_step.dependOn(&run_canonical_human_geometry_r3_tests.step);
    test_step.dependOn(&run_canonical_human_geometry_r4_tests.step);

    const full_test_step = b.step(
        "test-full",
        "Run every non-stress CPU regression suite without SDL or a GPU",
    );
    full_test_step.dependOn(test_step);
    full_test_step.dependOn(&run_integration_tests.step);
    full_test_step.dependOn(&run_foundation_tests.step);
    full_test_step.dependOn(&run_wardrobe_tests.step);
    full_test_step.dependOn(&run_visual_geometry_tests.step);
    full_test_step.dependOn(&run_environment_tests.step);
    full_test_step.dependOn(&run_visual_foundation_tests.step);
    full_test_step.dependOn(&run_canonical_human_geometry_full_tests.step);

    const format = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "--check", "build.zig", "build.zig.zon", "src", "tests" });
    format.setName("verify Zig formatting");
    const repository_audit = b.addSystemCommand(&.{ "pwsh", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File" });
    repository_audit.addFileArg(b.path("tools/check_repository.ps1"));
    repository_audit.setName("audit repository source policy");

    const check_step = b.step(
        "check",
        "Run the fast CPU suite plus formatting and every static repository audit",
    );
    check_step.dependOn(&format.step);
    check_step.dependOn(test_step);
    check_step.dependOn(&environment_art_audit.step);
    check_step.dependOn(&p27c_art_audit.step);
    check_step.dependOn(&p27c_r1_torso_audit.step);
    check_step.dependOn(&verify_p25d_goldens.step);
    check_step.dependOn(&repository_audit.step);
    check_step.dependOn(&human_base_export.step);

    const verify_step = b.step(
        "verify",
        "Run fast checks, every non-stress regression, and deterministic stress tests",
    );
    verify_step.dependOn(check_step);
    verify_step.dependOn(full_test_step);
    verify_step.dependOn(stress_test_step);
}

const ShaderCompileOptions = struct {
    dxc: []const u8,
    dxcompiler: []const u8,
    dxil: []const u8,
    dxv: []const u8,
    source: []const u8,
    stage: []const u8,
    entry_point: []const u8,
    target_profile: []const u8,
    configuration: []const u8,
    output_name: []const u8,
};

fn addShaderCompile(b: *std.Build, options: ShaderCompileOptions) ShaderOutput {
    const command = b.addSystemCommand(&.{ "pwsh", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File" });
    command.addFileArg(b.path("tools/compile_shaders.ps1"));

    command.addArg("-DxcPath");
    command.addFileArg(b.path(options.dxc));
    command.addArg("-DxcompilerPath");
    command.addFileArg(b.path(options.dxcompiler));
    command.addArg("-DxilPath");
    command.addFileArg(b.path(options.dxil));
    command.addArg("-DxvPath");
    command.addFileArg(b.path(options.dxv));
    command.addArg("-LockFile");
    command.addFileArg(b.path("tools/dependencies.lock.json"));
    command.addArg("-SourcePath");
    command.addFileArg(b.path(options.source));
    command.addArgs(&.{
        "-Stage",
        options.stage,
        "-EntryPoint",
        options.entry_point,
        "-TargetProfile",
        options.target_profile,
        "-BuildConfiguration",
        options.configuration,
        "-OutputPath",
    });
    const output = command.addOutputFileArg(options.output_name);
    command.setName(b.fmt("compile {s} shader {s} ({s})", .{ options.stage, options.entry_point, options.target_profile }));
    return .{ .step = command, .output = output };
}

fn requireFile(b: *std.Build, path: []const u8) void {
    std.Io.Dir.cwd().access(b.graph.io, path, .{}) catch {
        std.debug.panic("required pinned dependency file '{s}' is missing; run & '.\\tools\\bootstrap_dependencies.ps1' from the repository root", .{path});
    };
}
