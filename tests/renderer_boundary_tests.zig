const std = @import("std");
const frame_capture = @import("frame_capture");

test "capture result is copied data with explicit caller lifetime" {
    const pixels = try std.testing.allocator.alloc(u8, 8);
    pixels[0..4].* = .{ 1, 2, 3, 4 };
    pixels[4..8].* = .{ 5, 6, 7, 8 };
    var capture = try frame_capture.CapturedFrame.initOwned(
        std.testing.allocator,
        2,
        1,
        pixels,
    );
    defer capture.deinit();

    try std.testing.expectEqualSlices(u8, pixels, capture.bytes());
    try std.testing.expectEqualSlices(u8, pixels, try capture.row(0));
}

test "capture result rejects mismatched dimensions" {
    const pixels = try std.testing.allocator.alloc(u8, 3);
    defer std.testing.allocator.free(pixels);
    try std.testing.expectError(
        error.InvalidCapturePayloadLength,
        frame_capture.CapturedFrame.initOwned(
            std.testing.allocator,
            1,
            1,
            pixels,
        ),
    );
}

test "capture result rejects a row beyond the copied frame" {
    const pixels = try std.testing.allocator.alloc(u8, 4);
    @memset(pixels, 0);
    var capture = try frame_capture.CapturedFrame.initOwned(
        std.testing.allocator,
        1,
        1,
        pixels,
    );
    defer capture.deinit();
    try std.testing.expectError(error.CaptureRowOutOfBounds, capture.row(1));
}
