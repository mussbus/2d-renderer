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

    for ([_][]const u8{
        sdl_library,
        sdl_runtime,
        dxc,
        dxcompiler,
        dxil,
        dxv,
        shader_source,
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

    const shaders_step = b.step("shaders", "Compile and validate HLSL as pinned DXIL artifacts");
    shaders_step.dependOn(&vertex_shader.step.step);
    shaders_step.dependOn(&fragment_shader.step.step);

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
    b.getInstallStep().dependOn(&install_sdl.step);
    b.getInstallStep().dependOn(&install_vertex_shader.step);
    b.getInstallStep().dependOn(&install_fragment_shader.step);

    const installed_executable = b.getInstallPath(.bin, app.out_filename);
    const run_command = b.addSystemCommand(&.{installed_executable});
    run_command.setName("run installed skeletal_gpu_demo");
    run_command.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_command.addArgs(args);
    const run_step = b.step("run", "Run the installed 1,000-sprite SDL GPU batch demonstration");
    run_step.dependOn(&run_command.step);

    const gpu_smoke_command = b.addSystemCommand(&.{ installed_executable, "--gpu-smoke" });
    gpu_smoke_command.setName("run D3D12/DXIL draw and readback smoke test");
    gpu_smoke_command.step.dependOn(b.getInstallStep());
    const gpu_smoke_step = b.step("gpu-smoke", "Require and verify D3D12/DXIL rendering with GPU readback");
    gpu_smoke_step.dependOn(&gpu_smoke_command.step);

    const test_module = b.createModule(.{
        .root_source_file = b.path("tests/test_all.zig"),
        .target = target,
        .optimize = optimize,
    });
    const fault_injection_module = b.createModule(.{
        .root_source_file = b.path("src/platform/fault_injection.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sprite_batch_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/sprite_batch.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("fault_injection", fault_injection_module);
    test_module.addImport("sprite_batch", sprite_batch_module);
    const tests = b.addTest(.{ .name = "deterministic-tests", .root_module = test_module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run pure sprite-batch, ownership, and configuration tests without SDL or a GPU");
    test_step.dependOn(&run_tests.step);

    const format = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "--check", "build.zig", "build.zig.zon", "src", "tests" });
    format.setName("verify Zig formatting");
    const repository_audit = b.addSystemCommand(&.{ "pwsh", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File" });
    repository_audit.addFileArg(b.path("tools/check_repository.ps1"));
    repository_audit.setName("audit repository source policy");

    const check_step = b.step("check", "Verify formatting, deterministic tests, and source policy without a GPU");
    check_step.dependOn(&format.step);
    check_step.dependOn(&run_tests.step);
    check_step.dependOn(&repository_audit.step);
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
