const std = @import("std");
const builtin = @import("builtin");
const modules_build = @import("build/modules.zig");
const tests_engine_build = @import("build/tests_engine.zig");
const tests_content_build = @import("build/tests_content.zig");
const evidence_build = @import("build/evidence.zig");
const gates_build = @import("build/gates.zig");

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

    const modules = modules_build.register(.{
        .b = b,
        .target = target,
        .optimize = optimize,
        .sdl_include = sdl_include,
        .app_module = app_module,
    });
    const engine_tests = tests_engine_build.register(.{
        .b = b,
        .target = target,
        .optimize = optimize,
        .modules = &modules,
    });
    const content_tests = tests_content_build.register(.{
        .b = b,
        .target = target,
        .optimize = optimize,
        .modules = &modules,
    });
    const evidence = evidence_build.register(.{
        .b = b,
        .target = target,
        .optimize = optimize,
        .modules = &modules,
        .install_step = b.getInstallStep(),
        .visual_geometry_test_step = content_tests.visual_geometry_test_step,
    });
    gates_build.register(.{
        .b = b,
        .app = app,
        .engine = engine_tests,
        .content = content_tests,
        .evidence = evidence,
    });
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
