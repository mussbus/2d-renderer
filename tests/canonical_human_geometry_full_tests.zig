const std = @import("std");
const human_geometry = @import("canonical_human_geometry");

test "neutral human main-body scaffold has zero non-adjacent triangle self-intersections" {
    var loaded = try human_geometry.authority.loadAuthoritative(std.testing.allocator, std.testing.io);
    defer loaded.deinit();
    const mesh = human_geometry.analysis.findMainBody(loaded.definition()) orelse return error.TestExpectedEqual;
    var report = try human_geometry.analysis.selfIntersectionReportAlloc(std.testing.allocator, mesh);
    defer report.deinit();
    if (report.pairs.len != 0) for (report.pairs) |pair| std.debug.print(
        "self intersection face_a={d} face_b={d}\n",
        .{ pair.face_a.value, pair.face_b.value },
    );
    try std.testing.expectEqual(@as(usize, 0), report.pairs.len);
}
