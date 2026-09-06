const std = @import("std");
const apps_build = @import("apps.zig");
const tests_engine = @import("tests_engine.zig");
const tests_content = @import("tests_content.zig");
const evidence_build = @import("evidence.zig");

pub const Options = struct {
    b: *std.Build,
    apps: apps_build.Registration,
    engine: tests_engine.Registration,
    content: tests_content.Registration,
    evidence: evidence_build.Registration,
};

pub fn register(options: Options) void {
    const b = options.b;

    const test_step = b.step(
        "test",
        "Run the fast engine-contract CPU suite without SDL or a GPU",
    );
    test_step.dependOn(&options.engine.run_secondary_motion.step);
    test_step.dependOn(&options.engine.run_deterministic.step);
    test_step.dependOn(&options.engine.run_engine_composition.step);
    test_step.dependOn(&options.engine.run_engine_lab.step);
    test_step.dependOn(&options.engine.run_renderer_boundary.step);
    test_step.dependOn(&options.content.run_image_decode.step);
    test_step.dependOn(&options.engine.run_foundation_primitives.step);
    test_step.dependOn(&options.engine.run_world.step);
    test_step.dependOn(&options.engine.run_scene_binding_boundary.step);
    test_step.dependOn(&options.engine.run_scene_core_authored.step);
    test_step.dependOn(&options.engine.run_scene_core_runtime.step);
    test_step.dependOn(&options.engine.run_scene_core_registry.step);

    const format = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "fmt",
        "--check",
        "build.zig",
        "build.zig.zon",
        "build",
        "src",
        "tests",
    });
    format.setName("verify Zig formatting");

    const repository_audit = addPowerShellFile(b, "tools/check_repository.ps1");
    repository_audit.setName("audit current repository architecture and hygiene");

    const documentation_audit = addPowerShellFile(b, "tools/check_documentation.ps1");
    documentation_audit.setName("audit required documentation structure and local links");

    const content_policy_audit = addPowerShellFile(b, "tools/check_content.ps1");
    content_policy_audit.setName("audit current canonical/content qualification and retained historical policy");

    const check_step = b.step(
        "check",
        "Run the routine app compile, fast engine contracts, formatting, architecture policy, and documentation audit",
    );
    check_step.dependOn(&options.apps.demo.step);
    check_step.dependOn(&options.apps.engine_smoke.step);
    check_step.dependOn(&options.apps.engine_lab.step);
    check_step.dependOn(&format.step);
    check_step.dependOn(test_step);
    check_step.dependOn(&repository_audit.step);
    check_step.dependOn(&documentation_audit.step);

    const full_test_step = b.step(
        "test-full",
        "Run check plus all deterministic CPU integration and stress coverage; no content qualification or GPU",
    );
    full_test_step.dependOn(check_step);
    full_test_step.dependOn(&options.engine.run_integration.step);
    full_test_step.dependOn(&options.engine.run_stress.step);
    full_test_step.dependOn(&options.content.run_foundation.step);
    full_test_step.dependOn(&options.content.run_wardrobe.step);
    full_test_step.dependOn(&options.content.run_environment.step);
    full_test_step.dependOn(&options.content.run_visual_foundation.step);

    const content_step = b.step(
        "test-content",
        "Run current canonical, geometry, art, authored-content, golden, and content-policy qualification",
    );
    content_step.dependOn(options.content.content_tests);
    content_step.dependOn(&options.content.environment_art_audit.step);
    content_step.dependOn(&options.evidence.anatomy_art_audit.step);
    content_step.dependOn(&options.evidence.anatomy_torso_audit.step);
    content_step.dependOn(&options.evidence.visual_geometry_goldens.step);
    content_step.dependOn(&options.evidence.human_base_export_compile.step);
    content_step.dependOn(&content_policy_audit.step);

    const verify_step = b.step(
        "verify",
        "Run check, full deterministic CPU integration, and current content qualification; no physical GPU or manual review",
    );
    verify_step.dependOn(check_step);
    verify_step.dependOn(full_test_step);
    verify_step.dependOn(content_step);
}

fn addPowerShellFile(b: *std.Build, path: []const u8) *std.Build.Step.Run {
    const command = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    command.addFileArg(b.path(path));
    return command;
}
