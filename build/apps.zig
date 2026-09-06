const std = @import("std");
const modules_build = @import("modules.zig");

pub const Options = struct {
    b: *std.Build,
    modules: *const modules_build.Catalog,
    runtime_steps: []const *std.Build.Step,
};

pub const Registration = struct {
    effects_projectiles: *std.Build.Step.Compile,
    demo: *std.Build.Step.Compile,
    engine_smoke: *std.Build.Step.Compile,
    engine_lab: *std.Build.Step.Compile,
};

pub fn register(options: Options) Registration {
    const b = options.b;
    const modules = options.modules;

    const demo = b.addExecutable(.{
        .name = "engine_sandbox",
        .root_module = modules.demo_entry_module,
    });
    b.installArtifact(demo);

    const engine_smoke = b.addExecutable(.{
        .name = "engine_smoke",
        .root_module = modules.engine_smoke_entry_module,
    });
    b.installArtifact(engine_smoke);

    const engine_lab = b.addExecutable(.{
        .name = "engine_lab",
        .root_module = modules.engine_lab_entry_module,
    });
    // Opt-in install keeps the established default application build unchanged.
    const install_engine_lab = b.addInstallArtifact(engine_lab, .{});
    const engine_lab_step = b.step("engine-lab", "Build and install the independent Engine Lab with its production runtime");
    engine_lab_step.dependOn(&install_engine_lab.step);
    const install_lab_white = b.addInstallFileWithDir(b.path("assets/engine_lab/white.png"), .bin, "engine_lab/white.png");
    engine_lab_step.dependOn(&install_lab_white.step);
    for (options.runtime_steps) |step| engine_lab_step.dependOn(step);
    const run_engine_lab = b.addSystemCommand(&.{b.getInstallPath(.bin, engine_lab.out_filename)});
    run_engine_lab.setName("run independent Engine Lab");
    run_engine_lab.step.dependOn(engine_lab_step);
    if (b.args) |args| run_engine_lab.addArgs(args);
    const run_engine_lab_step = b.step("run-engine-lab", "Run the persistent Engine Lab hub; --help, --seed HEX, --verify or --smoke");
    run_engine_lab_step.dependOn(&run_engine_lab.step);
    const effects_projectiles = b.addExecutable(.{ .name = "effects_projectiles", .root_module = modules.effects_projectiles_entry_module });
    b.installArtifact(effects_projectiles);
    b.step("effects-projectiles", "Build the independent effects and projectiles proof").dependOn(&effects_projectiles.step);
    const run_effects_projectiles = b.addSystemCommand(&.{b.getInstallPath(.bin, effects_projectiles.out_filename)});
    run_effects_projectiles.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_effects_projectiles.addArgs(args);
    b.step("run-effects-projectiles", "Run the Effects/projectiles proof: Space pause, period step, R reset, N seed, P spawn, D deflect, F1 debug").dependOn(&run_effects_projectiles.step);
    const smoke_effects_projectiles = b.addSystemCommand(&.{ b.getInstallPath(.bin, effects_projectiles.out_filename), "--smoke", "--capture" });
    smoke_effects_projectiles.step.dependOn(b.getInstallStep());
    b.step("effects-projectiles-smoke", "Run real D3D12 Effects/projectiles proof, allocation checks and four readbacks").dependOn(&smoke_effects_projectiles.step);

    const installed_demo = b.getInstallPath(.bin, demo.out_filename);
    const run_demo = b.addSystemCommand(&.{installed_demo});
    run_demo.setName("run installed engine sandbox");
    run_demo.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_demo.addArgs(args);
    const run_step = b.step(
        "run",
        "Run the installed sprite-batch, character, interaction, playground, foundation, or side-scroller demonstration",
    );
    run_step.dependOn(&run_demo.step);

    const installed_engine_smoke = b.getInstallPath(.bin, engine_smoke.out_filename);
    const gpu_smoke_command = b.addSystemCommand(&.{ installed_engine_smoke, "--gpu-smoke" });
    gpu_smoke_command.setName("run D3D12/DXIL draw and readback smoke test");
    gpu_smoke_command.step.dependOn(b.getInstallStep());
    const gpu_smoke_step = b.step(
        "gpu-smoke",
        "Require and verify D3D12/DXIL rendering with GPU readback",
    );
    gpu_smoke_step.dependOn(&gpu_smoke_command.step);

    const engine_smoke_step = b.step(
        "engine-smoke",
        "Build the independent production-engine composition executable",
    );
    engine_smoke_step.dependOn(&engine_smoke.step);

    const run_engine_smoke = b.addSystemCommand(&.{installed_engine_smoke});
    run_engine_smoke.setName("run independent D3D12/DXIL engine composition proof");
    run_engine_smoke.step.dependOn(b.getInstallStep());
    const run_engine_smoke_step = b.step(
        "run-engine-smoke",
        "Run the independent RuntimeScene and production-renderer physical proof",
    );
    run_engine_smoke_step.dependOn(&run_engine_smoke.step);

    return .{ .demo = demo, .engine_smoke = engine_smoke, .engine_lab = engine_lab, .effects_projectiles = effects_projectiles };
}
