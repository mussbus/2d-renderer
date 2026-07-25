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

    for ([_][]const u8{
        sdl_library,
        sdl_runtime,
        dxc,
        dxcompiler,
        dxil,
        dxv,
        shader_source,
        mesh_shader_source,
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
    b.getInstallStep().dependOn(&install_sdl.step);
    b.getInstallStep().dependOn(&install_vertex_shader.step);
    b.getInstallStep().dependOn(&install_fragment_shader.step);
    b.getInstallStep().dependOn(&install_mesh_vertex_shader.step);

    const installed_executable = b.getInstallPath(.bin, app.out_filename);
    const run_command = b.addSystemCommand(&.{installed_executable});
    run_command.setName("run installed skeletal_gpu_demo");
    run_command.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_command.addArgs(args);
    const run_step = b.step("run", "Run the installed sprite-batch, character, interaction, playground, or side-scroller demonstration");
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
    const math_module = b.createModule(.{
        .root_source_file = b.path("src/math/transform2d.zig"),
        .target = target,
        .optimize = optimize,
    });
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
    const collider_module = b.createModule(.{
        .root_source_file = b.path("src/physics/collider.zig"),
        .target = target,
        .optimize = optimize,
    });
    collider_module.addImport("math", math_module);
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
    const render_queue_module = b.createModule(.{
        .root_source_file = b.path("src/graphics/render_queue.zig"),
        .target = target,
        .optimize = optimize,
    });
    render_queue_module.addImport("math", math_module);
    render_queue_module.addImport("deformable_mesh", deformable_mesh_module);
    render_queue_module.addImport("sprite_batch", sprite_batch_module);
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
    const equipment_module = b.createModule(.{
        .root_source_file = b.path("src/scene/equipment.zig"),
        .target = target,
        .optimize = optimize,
    });
    equipment_module.addImport("math", math_module);
    equipment_module.addImport("deformation", deformation_module);
    equipment_module.addImport("skeleton", skeleton_module);
    equipment_module.addImport("appearance", appearance_module);
    equipment_module.addImport("anatomy", anatomy_module);
    equipment_module.addImport("deformable_mesh", deformable_mesh_module);
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
    humanoid_module.addImport("sprite_batch", sprite_batch_module);
    humanoid_module.addImport("fault_injection", fault_injection_module);
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
    character_module.addImport("humanoid", humanoid_module);
    character_module.addImport("appearance", appearance_module);
    character_module.addImport("anatomy", anatomy_module);
    character_module.addImport("equipment", equipment_module);
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
    const multi_character_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/multi_character_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    multi_character_demo_module.addImport("math", math_module);
    multi_character_demo_module.addImport("humanoid", humanoid_module);
    multi_character_demo_module.addImport("authored_clips", authored_clips_module);
    multi_character_demo_module.addImport("character", character_module);
    multi_character_demo_module.addImport("state_machine", state_machine_module);
    multi_character_demo_module.addImport("sprite_batch", sprite_batch_module);
    multi_character_demo_module.addImport("fault_injection", fault_injection_module);
    const handshake_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/handshake_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    handshake_demo_module.addImport("math", math_module);
    handshake_demo_module.addImport("input", input_module);
    handshake_demo_module.addImport("humanoid", humanoid_module);
    handshake_demo_module.addImport("authored_clips", authored_clips_module);
    handshake_demo_module.addImport("character", character_module);
    handshake_demo_module.addImport("interaction", interaction_module);
    handshake_demo_module.addImport("interaction_system", interaction_system_module);
    handshake_demo_module.addImport("handshake", handshake_module);
    handshake_demo_module.addImport("sprite_batch", sprite_batch_module);
    handshake_demo_module.addImport("state_machine", state_machine_module);
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
    const foot_planting_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/foot_planting_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    foot_planting_demo_module.addImport("math", math_module);
    foot_planting_demo_module.addImport("input", input_module);
    foot_planting_demo_module.addImport("fixed_step", fixed_step_module);
    foot_planting_demo_module.addImport("collider", collider_module);
    foot_planting_demo_module.addImport("collision_world", collision_world_module);
    foot_planting_demo_module.addImport("character_controller", character_controller_module);
    foot_planting_demo_module.addImport("events", events_module);
    foot_planting_demo_module.addImport("humanoid", humanoid_module);
    foot_planting_demo_module.addImport("authored_clips", authored_clips_module);
    foot_planting_demo_module.addImport("character", character_module);
    foot_planting_demo_module.addImport("foot_planting", foot_planting_module);
    foot_planting_demo_module.addImport("leg_ik", leg_ik_module);
    foot_planting_demo_module.addImport("sprite_batch", sprite_batch_module);
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
    modular_body_demo_module.addImport("math", math_module);
    modular_body_demo_module.addImport("deformation", deformation_module);
    modular_body_demo_module.addImport("appearance", appearance_module);
    modular_body_demo_module.addImport("anatomy", anatomy_module);
    modular_body_demo_module.addImport("humanoid", humanoid_module);
    modular_body_demo_module.addImport("authored_clips", authored_clips_module);
    modular_body_demo_module.addImport("character", character_module);
    modular_body_demo_module.addImport("sprite_batch", sprite_batch_module);
    modular_body_demo_module.addImport("fault_injection", fault_injection_module);
    const equipment_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/equipment_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    equipment_demo_module.addImport("math", math_module);
    equipment_demo_module.addImport("deformation", deformation_module);
    equipment_demo_module.addImport("humanoid", humanoid_module);
    equipment_demo_module.addImport("authored_clips", authored_clips_module);
    equipment_demo_module.addImport("character", character_module);
    equipment_demo_module.addImport("equipment", equipment_module);
    equipment_demo_module.addImport("modular_body_demo", modular_body_demo_module);
    equipment_demo_module.addImport("sprite_batch", sprite_batch_module);
    const breathing_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/breathing_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    breathing_demo_module.addImport("math", math_module);
    breathing_demo_module.addImport("deformation", deformation_module);
    breathing_demo_module.addImport("anatomy", anatomy_module);
    breathing_demo_module.addImport("equipment", equipment_module);
    breathing_demo_module.addImport("character", character_module);
    breathing_demo_module.addImport("equipment_demo", equipment_demo_module);
    breathing_demo_module.addImport("sprite_batch", sprite_batch_module);
    const mesh_attachment_demo_module = b.createModule(.{
        .root_source_file = b.path("src/scene/mesh_attachment_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    mesh_attachment_demo_module.addImport("math", math_module);
    mesh_attachment_demo_module.addImport("deformation", deformation_module);
    mesh_attachment_demo_module.addImport("deformable_mesh", deformable_mesh_module);
    mesh_attachment_demo_module.addImport("render_queue", render_queue_module);
    mesh_attachment_demo_module.addImport("humanoid", humanoid_module);
    mesh_attachment_demo_module.addImport("authored_clips", authored_clips_module);
    mesh_attachment_demo_module.addImport("character", character_module);
    mesh_attachment_demo_module.addImport("equipment", equipment_module);
    mesh_attachment_demo_module.addImport("modular_body_demo", modular_body_demo_module);
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
    app_module.addImport("multi_character_demo", multi_character_demo_module);
    app_module.addImport("interaction", interaction_module);
    app_module.addImport("handshake", handshake_module);
    app_module.addImport("interaction_system", interaction_system_module);
    app_module.addImport("handshake_demo", handshake_demo_module);
    app_module.addImport("handshake_ik_demo", handshake_ik_demo_module);
    app_module.addImport("foot_planting_demo", foot_planting_demo_module);
    app_module.addImport("diagnostics", diagnostics_module);
    app_module.addImport("debug_draw", debug_draw_module);
    app_module.addImport("integrated_demo", integrated_demo_module);
    app_module.addImport("playground_demo", playground_demo_module);
    app_module.addImport("modular_body_demo", modular_body_demo_module);
    app_module.addImport("equipment_demo", equipment_demo_module);
    app_module.addImport("breathing_demo", breathing_demo_module);
    app_module.addImport("mesh_attachment_demo", mesh_attachment_demo_module);
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
    test_module.addImport("equipment", equipment_module);
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
    test_module.addImport("collider", collider_module);
    test_module.addImport("collision_world", collision_world_module);
    test_module.addImport("character_controller", character_controller_module);
    test_module.addImport("controller_demo", controller_demo_module);
    test_module.addImport("procedural_motion", procedural_motion_module);
    test_module.addImport("character", character_module);
    test_module.addImport("multi_character_demo", multi_character_demo_module);
    test_module.addImport("interaction", interaction_module);
    test_module.addImport("handshake", handshake_module);
    test_module.addImport("interaction_system", interaction_system_module);
    test_module.addImport("handshake_demo", handshake_demo_module);
    test_module.addImport("foot_planting_demo", foot_planting_demo_module);
    test_module.addImport("diagnostics", diagnostics_module);
    test_module.addImport("debug_draw", debug_draw_module);
    test_module.addImport("integrated_demo", integrated_demo_module);
    test_module.addImport("playground_demo", playground_demo_module);
    test_module.addImport("modular_body_demo", modular_body_demo_module);
    test_module.addImport("equipment_demo", equipment_demo_module);
    test_module.addImport("breathing_demo", breathing_demo_module);
    test_module.addImport("mesh_attachment_demo", mesh_attachment_demo_module);
    const tests = b.addTest(.{ .name = "deterministic-tests", .root_module = test_module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run pure math, hierarchy, animation, controller, procedural-motion, collision, sprite-batch, and ownership tests without SDL or a GPU");
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
