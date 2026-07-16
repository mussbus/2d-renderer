const std = @import("std");
const gpu = @import("graphics/gpu_demo.zig");
const fault_injection = @import("platform/fault_injection.zig");

const Options = struct {
    gpu_smoke: bool = false,
    maximum_frames: ?u32 = null,
};

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    const options = try parseOptions(arguments);
    if (options.gpu_smoke) {
        try runFaultInjectionChecks();
        var demo = try gpu.GpuDemo.init(true, null);
        defer demo.deinit();
        try demo.runSmoke();
        return;
    }

    var demo = try gpu.GpuDemo.init(false, null);
    defer demo.deinit();
    try demo.runVisible(options.maximum_frames);
}

fn runFaultInjectionChecks() !void {
    for (fault_injection.all_stages) |stage| {
        var attempt = gpu.GpuDemo.init(true, .{ .fail_after = stage }) catch |err| {
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
        } else {
            std.log.err("unknown argument: {s}; supported: --gpu-smoke, --frames <count>", .{argument});
            return error.UnknownArgument;
        }
    }
    return options;
}
