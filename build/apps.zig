const std = @import("std");
const modules_build = @import("modules.zig");

pub const Options = struct {
    b: *std.Build,
    modules: *const modules_build.Catalog,
};

pub const Registration = struct {
    effects_projectiles: *std.Build.Step.Compile,
    demo: *std.Build.Step.Compile,
    engine_smoke: *std.Build.Step.Compile,
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

    const effects_projectiles = b.addExecutable(.{ .name = "effects_projectiles", .root_module = modules.effects_projectiles_entry_module });
    b.installArtifact(effects_projectiles);
    b.step("effects-projectiles", "Build the independent E1 effects and projectiles proof").dependOn(&effects_projectiles.step);
    const run_e1 = b.addSystemCommand(&.{b.getInstallPath(.bin, effects_projectiles.out_filename)});
    run_e1.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_e1.addArgs(args);
    b.step("run-effects-projectiles", "Run the E1 proof: Space pause, period step, R reset, N seed, P spawn, D deflect, F1 debug").dependOn(&run_e1.step);
    const smoke_e1 = b.addSystemCommand(&.{ b.getInstallPath(.bin, effects_projectiles.out_filename), "--smoke", "--capture" });
    smoke_e1.step.dependOn(b.getInstallStep());
    b.step("effects-projectiles-smoke", "Run real D3D12 E1 proof, allocation checks and four readbacks").dependOn(&smoke_e1.step);

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

    return .{ .demo = demo, .engine_smoke = engine_smoke, .effects_projectiles = effects_projectiles };
}
