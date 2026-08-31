const std = @import("std");
const modules_build = @import("modules.zig");

pub const Options = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    modules: *const modules_build.Catalog,
    install_step: *std.Build.Step,
    visual_geometry_test_step: *std.Build.Step,
};

pub const Registration = struct {
    p27c_art_audit: *std.Build.Step.Run,
    p27c_r1_torso_audit: *std.Build.Step.Run,
    p25d_goldens: *std.Build.Step.Run,
    human_base_export_compile: *std.Build.Step.Compile,
    history: *std.Build.Step,
    history_check: *std.Build.Step,
    visual_acceptance: *std.Build.Step,
};

pub fn register(options: Options) Registration {
    const b = options.b;
    const target = options.target;
    const optimize = options.optimize;
    const modules = options.modules;

    const human_geometry_refinement_export_module = b.createModule(.{
        .root_source_file = b.path("tools/export_human_geometry_refinement_evidence.zig"),
        .target = target,
        .optimize = optimize,
    });
    human_geometry_refinement_export_module.addImport("canonical_model", modules.canonical_model_module);
    human_geometry_refinement_export_module.addImport("canonical_geometry", modules.canonical_geometry_module);
    human_geometry_refinement_export_module.addImport("canonical_human_geometry", modules.canonical_human_geometry_module);
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
    human_geometry_r1_export_module.addImport("canonical_model", modules.canonical_model_module);
    human_geometry_r1_export_module.addImport("canonical_geometry", modules.canonical_geometry_module);
    human_geometry_r1_export_module.addImport("canonical_human_geometry", modules.canonical_human_geometry_module);
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
    human_geometry_candidate_validator_module.addImport("canonical_geometry", modules.canonical_geometry_module);
    human_geometry_candidate_validator_module.addImport("canonical_human_geometry", modules.canonical_human_geometry_module);
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
    human_base_export_module.addImport("canonical_model", modules.canonical_model_module);
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
    const visual_geometry_report_module = b.createModule(.{
        .root_source_file = b.path("src/scene/visual_geometry_report.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    visual_geometry_report_module.addImport("camera2d", modules.camera2d_module);
    visual_geometry_report_module.addImport("image_decode", modules.image_decode_module);
    visual_geometry_report_module.addImport("render_queue", modules.render_queue_module);
    visual_geometry_report_module.addImport("presentation_view", modules.presentation_view_module);
    visual_geometry_report_module.addImport("humanoid", modules.humanoid_module);
    visual_geometry_report_module.addImport("wardrobe_demo", modules.wardrobe_demo_module);
    visual_geometry_report_module.addImport("visual_geometry", modules.visual_geometry_module);
    visual_geometry_report_module.addImport("visual_geometry_audit", modules.visual_geometry_audit_module);
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
    anatomy_quality_report_module.addImport("camera2d", modules.camera2d_module);
    anatomy_quality_report_module.addImport("image_decode", modules.image_decode_module);
    anatomy_quality_report_module.addImport("render_queue", modules.render_queue_module);
    anatomy_quality_report_module.addImport("presentation_view", modules.presentation_view_module);
    anatomy_quality_report_module.addImport("humanoid", modules.humanoid_module);
    anatomy_quality_report_module.addImport("wardrobe_demo", modules.wardrobe_demo_module);
    anatomy_quality_report_module.addImport("visual_geometry", modules.visual_geometry_module);
    anatomy_quality_report_module.addImport("visual_geometry_audit", modules.visual_geometry_audit_module);
    anatomy_quality_report_module.addImport("anatomy_quality", modules.anatomy_quality_module);
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
    options.visual_geometry_test_step.dependOn(&p27c_art_audit.step);
    options.visual_geometry_test_step.dependOn(&p27c_r1_torso_audit.step);
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
    foundation_coherence_report_module.addImport("math", modules.math_module);
    foundation_coherence_report_module.addImport("input", modules.input_module);
    foundation_coherence_report_module.addImport("camera2d", modules.camera2d_module);
    foundation_coherence_report_module.addImport("image_decode", modules.image_decode_module);
    foundation_coherence_report_module.addImport("render_queue", modules.render_queue_module);
    foundation_coherence_report_module.addImport("sprite_batch", modules.sprite_batch_module);
    foundation_coherence_report_module.addImport("foundation_evidence", modules.foundation_evidence_module);
    foundation_coherence_report_module.addImport("foundation_coherence", modules.foundation_coherence_module);
    foundation_coherence_report_module.addImport("visual_foundation", modules.visual_foundation_module);
    foundation_coherence_report_module.addImport("visual_geometry", modules.visual_geometry_module);
    foundation_coherence_report_module.addImport("visual_geometry_audit", modules.visual_geometry_audit_module);
    foundation_coherence_report_module.addImport("environment_theme", modules.environment_theme_module);
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

    const history_registration_check = b.addSystemCommand(&.{
        "pwsh",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
    });
    history_registration_check.addFileArg(b.path("tools/check_history_registration.ps1"));
    history_registration_check.setName("verify retained historical evidence registration");
    const history_check = b.step(
        "evidence-history-check",
        "Validate historical evidence registration without regenerating derived evidence",
    );
    history_check.dependOn(&history_registration_check.step);

    const history = b.step(
        "evidence-history",
        "Explicitly regenerate historical canonical and prompt-era evidence; mutates derived evidence outputs",
    );
    history.dependOn(human_geometry_refinement_export_step);
    history.dependOn(human_geometry_r1_export_step);
    history.dependOn(blender_bridge_test_step);
    history.dependOn(p27a_review_step);
    history.dependOn(p27b_review_step);

    const visual_acceptance = b.step(
        "visual-acceptance",
        "Build current manual visual-review application and report tools; follow docs/TESTING.md to capture and review",
    );
    visual_acceptance.dependOn(options.install_step);
    visual_acceptance.dependOn(&visual_geometry_report_exe.step);
    visual_acceptance.dependOn(&anatomy_quality_report_exe.step);
    visual_acceptance.dependOn(&foundation_coherence_report_exe.step);

    return .{
        .p27c_art_audit = p27c_art_audit,
        .p27c_r1_torso_audit = p27c_r1_torso_audit,
        .p25d_goldens = verify_p25d_goldens,
        .human_base_export_compile = human_base_export,
        .history = history,
        .history_check = history_check,
        .visual_acceptance = visual_acceptance,
    };
}
