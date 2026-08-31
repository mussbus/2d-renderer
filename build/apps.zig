const std = @import("std");
const modules_build = @import("modules.zig");

pub const Options = struct {
    b: *std.Build,
    modules: *const modules_build.Catalog,
};

pub const Registration = struct {
    demo: *std.Build.Step.Compile,
    engine_smoke: *std.Build.Step.Compile,
};

pub fn register(options: Options) Registration {
    const b = options.b;
    const modules = options.modules;

    const demo = b.addExecutable(.{
        .name = "skeletal_gpu_demo",
        .root_module = modules.demo_entry_module,
    });
    b.installArtifact(demo);

    const engine_smoke = b.addExecutable(.{
        .name = "engine_smoke",
        .root_module = modules.engine_smoke_entry_module,
    });
    b.installArtifact(engine_smoke);

    const installed_demo = b.getInstallPath(.bin, demo.out_filename);
    const run_demo = b.addSystemCommand(&.{installed_demo});
    run_demo.setName("run installed skeletal_gpu_demo");
    run_demo.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_demo.addArgs(args);
    const run_step = b.step(
        "run",
        "Run the installed sprite-batch, character, interaction, playground, foundation, or side-scroller demonstration",
    );
    run_step.dependOn(&run_demo.step);

    const gpu_smoke_command = b.addSystemCommand(&.{ installed_demo, "--gpu-smoke" });
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

    const installed_engine_smoke = b.getInstallPath(.bin, engine_smoke.out_filename);
    const run_engine_smoke = b.addSystemCommand(&.{installed_engine_smoke});
    run_engine_smoke.setName("run independent D3D12/DXIL engine composition proof");
    run_engine_smoke.step.dependOn(b.getInstallStep());
    const run_engine_smoke_step = b.step(
        "run-engine-smoke",
        "Run the independent RuntimeScene and production-renderer physical proof",
    );
    run_engine_smoke_step.dependOn(&run_engine_smoke.step);

    return .{ .demo = demo, .engine_smoke = engine_smoke };
}
