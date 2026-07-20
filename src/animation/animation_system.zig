const std = @import("std");
const humanoid = @import("humanoid");
const authored = @import("authored_clips");
const animator_module = @import("animator");
const fault_injection = @import("fault_injection");

pub const default_event_capacity: usize = 64;

pub const Runtime = struct {
    definitions: authored.Definitions,
    animator: animator_module.Animator,

    pub fn init(allocator: std.mem.Allocator, definition: *const humanoid.HumanoidDefinition, injector: ?fault_injection.Injector) !Runtime {
        var definitions = try authored.Definitions.init(allocator, &definition.skeleton_definition, injector);
        errdefer definitions.deinit();
        var animator = try animator_module.Animator.init(
            allocator,
            &definition.skeleton_definition,
            &definitions.machine,
            definitions.library.token(),
            default_event_capacity,
            injector,
        );
        errdefer animator.deinit();
        return .{ .definitions = definitions, .animator = animator };
    }

    pub fn deinit(runtime: *Runtime) void {
        runtime.animator.deinit();
        runtime.definitions.deinit();
        runtime.* = undefined;
    }
};

pub fn runFaultInjectionChecks(allocator: std.mem.Allocator, definition: *const humanoid.HumanoidDefinition) !void {
    for (fault_injection.animation_initialization_stages) |stage| {
        var attempt = Runtime.init(allocator, definition, .{ .fail_after = stage }) catch |err| {
            if (err != error.InjectedInitializationFailure) return err;
            var clean = try Runtime.init(allocator, definition, null);
            clean.deinit();
            std.log.info("animation fault-injection cleanup check passed after {s}", .{@tagName(stage)});
            continue;
        };
        attempt.deinit();
        return error.FaultInjectionDidNotTrigger;
    }
}
