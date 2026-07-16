const std = @import("std");
const fault_injection = @import("fault_injection");

test "every initialization stage round-trips through its command-line name" {
    for (fault_injection.all_stages) |stage| {
        try std.testing.expectEqual(stage, fault_injection.parse(@tagName(stage)).?);
    }
    try std.testing.expect(fault_injection.parse("not_a_stage") == null);
}

test "fault injection fails exactly after the selected acquisition stage" {
    for (fault_injection.all_stages) |selected| {
        const injector = fault_injection.Injector{ .fail_after = selected };
        var observed = false;
        for (fault_injection.all_stages) |visited| {
            injector.after(visited) catch |err| {
                try std.testing.expectEqual(error.InjectedInitializationFailure, err);
                try std.testing.expectEqual(selected, visited);
                observed = true;
                break;
            };
        }
        try std.testing.expect(observed);
    }
}
