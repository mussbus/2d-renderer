const std = @import("std");
const demo_application = @import("demo_application");
const fault_injection = @import("fault_injection");

const Options = struct {
    gpu_smoke: bool = false,
    maximum_frames: ?u32 = null,
    demo: demo_application.DemoMode = .sprites,
    scripted_input: bool = false,
    debug_visualization: bool = false,
    interactive: bool = false,
    registration_proof_case: ?@import("visual_foundation").RegistrationProofCase = null,
    component_proof_case: ?@import("visual_foundation").ComponentProofCase = null,
    capture_manual_bundle: bool = false,
};

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    const options = try parseOptions(arguments);
    if (options.gpu_smoke) {
        try runInitializationFaultChecks(init.io);
        var demo = try demo_application.DemoApplication.init(std.heap.page_allocator, init.io, true, null);
        defer demo.deinit();
        try demo.runRuntimeFaultChecks();
        try demo.runSmoke();
        return;
    }

    var demo = try demo_application.DemoApplication.init(std.heap.page_allocator, init.io, false, null);
    defer demo.deinit();
    try demo.runVisible(
        options.maximum_frames,
        options.demo,
        options.scripted_input,
        options.debug_visualization,
        options.interactive,
        options.registration_proof_case,
        options.component_proof_case,
        options.capture_manual_bundle,
    );
}

test "application entry point remains type checked" {
    _ = &main;
}

fn runInitializationFaultChecks(io: std.Io) !void {
    for (fault_injection.initialization_stages) |stage| {
        var attempt = demo_application.DemoApplication.init(std.heap.page_allocator, io, true, .{ .fail_after = stage }) catch |err| {
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
            if (std.mem.eql(u8, arguments[index], "controller")) {
                options.demo = .controller;
            } else if (std.mem.eql(u8, arguments[index], "handshake-ik")) {
                options.demo = .handshake_ik;
            } else if (std.mem.eql(u8, arguments[index], "integrated")) {
                options.demo = .integrated;
            } else if (std.mem.eql(u8, arguments[index], "playground")) {
                options.demo = .playground;
            } else if (std.mem.eql(u8, arguments[index], "modular-body")) {
                options.demo = .modular_body;
            } else if (std.mem.eql(u8, arguments[index], "equipment")) {
                options.demo = .equipment;
            } else if (std.mem.eql(u8, arguments[index], "mesh-attachments")) {
                options.demo = .mesh_attachments;
            } else if (std.mem.eql(u8, arguments[index], "side-scroller")) {
                options.demo = .side_scroller;
            } else if (std.mem.eql(u8, arguments[index], "foundation")) {
                options.demo = .foundation;
            } else if (std.mem.eql(u8, arguments[index], "wardrobe")) {
                options.demo = .wardrobe;
            } else if (std.mem.eql(u8, arguments[index], "visual-quality")) {
                options.demo = .visual_quality;
            } else if (std.mem.eql(u8, arguments[index], "anatomy-quality")) {
                options.demo = .anatomy_quality;
            } else if (std.mem.eql(u8, arguments[index], "environment")) {
                options.demo = .environment;
            } else if (std.mem.eql(u8, arguments[index], "sprites")) {
                options.demo = .sprites;
            } else {
                std.log.err("unknown demo: {s}; supported: sprites, controller, handshake-ik, integrated, playground, modular-body, equipment, mesh-attachments, side-scroller, foundation, wardrobe, visual-quality, anatomy-quality, environment", .{arguments[index]});
                return error.UnknownDemo;
            }
        } else if (std.mem.eql(u8, argument, "--scripted-input")) {
            options.scripted_input = true;
        } else if (std.mem.eql(u8, argument, "--debug-visualization")) {
            options.debug_visualization = true;
        } else if (std.mem.eql(u8, argument, "--interactive")) {
            options.interactive = true;
        } else if (std.mem.eql(u8, argument, "--registration-proof-case")) {
            index += 1;
            if (index >= arguments.len) return error.MissingRegistrationProofCase;
            options.registration_proof_case =
                try @import("visual_foundation").RegistrationProofCase.parse(
                    arguments[index],
                );
        } else if (std.mem.eql(u8, argument, "--component-proof-case")) {
            index += 1;
            if (index >= arguments.len) return error.MissingComponentProofCase;
            options.component_proof_case =
                try @import("visual_foundation").ComponentProofCase.parse(
                    arguments[index],
                );
        } else if (std.mem.eql(u8, argument, "--capture-manual-bundle")) {
            options.capture_manual_bundle = true;
        } else {
            std.log.err("unknown argument: {s}; supported: --gpu-smoke, --frames <count>, --demo <sprites|controller|handshake-ik|integrated|playground|modular-body|equipment|mesh-attachments|side-scroller|foundation|wardrobe|visual-quality|anatomy-quality|environment>, --scripted-input, --debug-visualization, --interactive, --registration-proof-case <body-front|body-side-left|body-side-right|equipped-front|equipped-side-left|equipped-side-right>, --component-proof-case <eye-eyebrow|scalp-hair|extra-arm|continuous|intentional-gap|front|side-left|side-right|disabled|continuous-front|intentional-gap-front|continuous-side-left|continuous-side-right|intentional-gap-side-left|intentional-gap-side-right|two-modules>, --capture-manual-bundle", .{argument});
            return error.UnknownArgument;
        }
    }
    if (options.scripted_input and options.demo != .controller and options.demo != .handshake_ik and options.demo != .integrated and options.demo != .playground and options.demo != .side_scroller and options.demo != .foundation and options.demo != .wardrobe and options.demo != .visual_quality and options.demo != .anatomy_quality and options.demo != .environment) {
        return error.ScriptedInputRequiresControllerDemo;
    }
    if (options.debug_visualization and
        options.demo != .integrated and
        options.demo != .playground and
        options.demo != .foundation and
        options.demo != .visual_quality and
        options.demo != .environment)
    {
        return error.DebugVisualizationRequiresIntegratedDemo;
    }
    if (options.interactive and options.demo != .playground and options.demo != .foundation and options.demo != .wardrobe and options.demo != .environment) return error.InteractiveRequiresPlaygroundDemo;
    if (options.demo == .playground and options.interactive == options.scripted_input) return error.PlaygroundRequiresExactlyOneInputMode;
    if (options.demo == .playground and options.scripted_input and options.maximum_frames != 1800) return error.PlaygroundScriptRequiresExactFrameCount;
    if (options.demo == .foundation and options.interactive == options.scripted_input) return error.FoundationRequiresExactlyOneInputMode;
    if (options.registration_proof_case != null and
        (options.demo != .foundation or !options.interactive))
    {
        return error.RegistrationProofCaseRequiresInteractiveFoundation;
    }
    if (options.component_proof_case != null and
        (options.demo != .foundation or !options.interactive))
    {
        return error.ComponentProofCaseRequiresInteractiveFoundation;
    }
    if (options.component_proof_case != null and
        options.registration_proof_case != null)
    {
        return error.ProofCasesAreMutuallyExclusive;
    }
    if (options.capture_manual_bundle and
        (options.demo != .foundation or !options.interactive))
    {
        return error.ManualBundleCaptureRequiresInteractiveFoundation;
    }
    if (options.demo == .foundation and options.scripted_input and
        options.maximum_frames != @import("visual_foundation").required_frames)
    {
        return error.FoundationScriptRequiresExactFrameCount;
    }
    if (options.demo == .side_scroller and (!options.scripted_input or options.interactive)) return error.SideScrollerRequiresScriptedInput;
    if (options.demo == .side_scroller and options.maximum_frames != 1100) return error.SideScrollerScriptRequiresExactFrameCount;
    if (options.demo == .wardrobe and options.interactive == options.scripted_input) return error.WardrobeRequiresExactlyOneInputMode;
    if (options.demo == .wardrobe and options.scripted_input and options.maximum_frames != 600) return error.WardrobeScriptRequiresExactFrameCount;
    if (options.demo == .visual_quality and
        (!options.scripted_input or options.interactive or options.maximum_frames != 600))
    {
        return error.VisualQualityRequiresExactScriptedRoute;
    }
    if (options.demo == .anatomy_quality and
        (!options.scripted_input or options.interactive or options.maximum_frames != 600))
    {
        return error.AnatomyQualityRequiresExactScriptedRoute;
    }
    if (options.demo == .environment and options.interactive == options.scripted_input) {
        return error.EnvironmentRequiresExactlyOneInputMode;
    }
    if (options.demo == .environment and
        options.scripted_input and options.maximum_frames != 720)
    {
        return error.EnvironmentScriptRequiresExactFrameCount;
    }
    return options;
}
