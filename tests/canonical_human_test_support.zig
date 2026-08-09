const std = @import("std");
const canonical = @import("canonical_model");

pub fn load() !canonical.human_base.LoadedHumanBase {
    var diagnostic_storage: [1024]canonical.diagnostics.Diagnostic = undefined;
    return canonical.human_base.loadAuthoritative(
        std.testing.allocator,
        std.testing.io,
        &diagnostic_storage,
    );
}

pub fn dupe(comptime T: type, source: []const T) ![]T {
    return std.testing.allocator.dupe(T, source);
}
