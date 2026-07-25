const std = @import("std");
const gpu = @import("graphics/gpu_demo.zig");
const fault_injection = @import("fault_injection");

const Options = struct {
    gpu_smoke: bool = false,
    maximum_frames: ?u32 = null,
    demo: gpu.DemoMode = .sprites,
    scripted_input: bool = false,
    debug_visualization: bool = false,
    interactive: bool = false,
};

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    const options = try parseOptions(arguments);
    if (options.gpu_smoke) {
        try runInitializationFaultChecks();
        var demo = try gpu.GpuDemo.init(std.heap.page_allocator, true, null);
        defer demo.deinit();
        try demo.runRuntimeFaultChecks();
        try demo.runSmoke();
        return;
    }

    var demo = try gpu.GpuDemo.init(std.heap.page_allocator, false, null);
    defer demo.deinit();
    try demo.runVisible(options.maximum_frames, options.demo, options.scripted_input, options.debug_visualization, options.interactive);
}

test "application entry point remains type checked" {
    _ = &main;
}

fn runInitializationFaultChecks() !void {
    for (fault_injection.initialization_stages) |stage| {
        var attempt = gpu.GpuDemo.init(std.heap.page_allocator, true, .{ .fail_after = stage }) catch |err| {
            if (err != error.InjectedInitializationFailure) {
                std.log.err("fault-injection cleanup check for {s} failed before reaching its injection point: {s}", .{ @tagName(stage), @errorName(err) });
                return err;
            }
            std.log.info("fault-injection cleanup check passed after {s}", .{@tagName(stage)});
            continue;
        };
        attempt.deinit();
        std.log.err("fault-injection stage {s} did not trigger", .{@tagName(stage)});
        return error.FaultInjectionDidNotTrigger;
    }
}

fn parseOptions(arguments: []const []const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < arguments.len) : (index += 1) {
        const argument = arguments[index];
        if (std.mem.eql(u8, argument, "--gpu-smoke")) {
            options.gpu_smoke = true;
        } else if (std.mem.eql(u8, argument, "--frames")) {
            index += 1;
            if (index >= arguments.len) return error.MissingFrameCount;
            options.maximum_frames = try std.fmt.parseInt(u32, arguments[index], 10);
        } else if (std.mem.eql(u8, argument, "--demo")) {
            index += 1;
            if (index >= arguments.len) return error.MissingDemoName;
            if (std.mem.eql(u8, arguments[index], "humanoid")) {
                options.demo = .humanoid;
            } else if (std.mem.eql(u8, arguments[index], "animation")) {
                options.demo = .animation;
            } else if (std.mem.eql(u8, arguments[index], "controller")) {
                options.demo = .controller;
            } else if (std.mem.eql(u8, arguments[index], "secondary-motion")) {
                options.demo = .secondary_motion;
            } else if (std.mem.eql(u8, arguments[index], "multi-character")) {
                options.demo = .multi_character;
            } else if (std.mem.eql(u8, arguments[index], "handshake")) {
                options.demo = .handshake;
            } else if (std.mem.eql(u8, arguments[index], "handshake-ik")) {
                options.demo = .handshake_ik;
            } else if (std.mem.eql(u8, arguments[index], "foot-planting")) {
                options.demo = .foot_planting;
            } else if (std.mem.eql(u8, arguments[index], "integrated")) {
                options.demo = .integrated;
            } else if (std.mem.eql(u8, arguments[index], "playground")) {
                options.demo = .playground;
            } else if (std.mem.eql(u8, arguments[index], "modular-body")) {
                options.demo = .modular_body;
            } else if (std.mem.eql(u8, arguments[index], "equipment")) {
                options.demo = .equipment;
            } else if (std.mem.eql(u8, arguments[index], "breathing")) {
                options.demo = .breathing;
            } else if (std.mem.eql(u8, arguments[index], "mesh-attachments")) {
                options.demo = .mesh_attachments;
            } else if (std.mem.eql(u8, arguments[index], "side-scroller")) {
                options.demo = .side_scroller;
            } else if (std.mem.eql(u8, arguments[index], "sprites")) {
                options.demo = .sprites;
            } else {
                std.log.err("unknown demo: {s}; supported: sprites, humanoid, animation, controller, secondary-motion, multi-character, handshake, handshake-ik, foot-planting, integrated, playground, modular-body, equipment, breathing, mesh-attachments, side-scroller", .{arguments[index]});
                return error.UnknownDemo;
            }
        } else if (std.mem.eql(u8, argument, "--scripted-input")) {
            options.scripted_input = true;
        } else if (std.mem.eql(u8, argument, "--debug-visualization")) {
            options.debug_visualization = true;
        } else if (std.mem.eql(u8, argument, "--interactive")) {
            options.interactive = true;
        } else {
            std.log.err("unknown argument: {s}; supported: --gpu-smoke, --frames <count>, --demo <sprites|humanoid|animation|controller|secondary-motion|multi-character|handshake|handshake-ik|foot-planting|integrated|playground|modular-body|equipment|breathing|mesh-attachments|side-scroller>, --scripted-input, --debug-visualization, --interactive", .{argument});
            return error.UnknownArgument;
        }
    }
    if (options.scripted_input and options.demo != .controller and options.demo != .secondary_motion and options.demo != .handshake and options.demo != .handshake_ik and options.demo != .foot_planting and options.demo != .integrated and options.demo != .playground and options.demo != .side_scroller) {
        return error.ScriptedInputRequiresControllerDemo;
    }
    if (options.debug_visualization and options.demo != .integrated and options.demo != .playground) return error.DebugVisualizationRequiresIntegratedDemo;
    if (options.interactive and options.demo != .playground) return error.InteractiveRequiresPlaygroundDemo;
    if (options.demo == .playground and options.interactive == options.scripted_input) return error.PlaygroundRequiresExactlyOneInputMode;
    if (options.demo == .playground and options.scripted_input and options.maximum_frames != 1800) return error.PlaygroundScriptRequiresExactFrameCount;
    if (options.demo == .side_scroller and (!options.scripted_input or options.interactive)) return error.SideScrollerRequiresScriptedInput;
    if (options.demo == .side_scroller and options.maximum_frames != 1100) return error.SideScrollerScriptRequiresExactFrameCount;
    return options;
}
