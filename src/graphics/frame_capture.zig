const std = @import("std");

/// Owned, tightly packed RGBA8 output copied from a completed renderer readback.
/// The GPU transfer buffer and every backend handle remain renderer-owned.
pub const CapturedFrame = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    rgba: []u8,

    pub fn initOwned(
        allocator: std.mem.Allocator,
        width: u32,
        height: u32,
        rgba: []u8,
    ) !CapturedFrame {
        const pixel_count = std.math.mul(usize, width, height) catch
            return error.CaptureDimensionsOverflow;
        const expected_bytes = std.math.mul(usize, pixel_count, 4) catch
            return error.CaptureDimensionsOverflow;
        if (rgba.len != expected_bytes) return error.InvalidCapturePayloadLength;
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .rgba = rgba,
        };
    }

    pub fn deinit(self: *CapturedFrame) void {
        self.allocator.free(self.rgba);
        self.* = undefined;
    }

    pub fn bytes(self: *const CapturedFrame) []const u8 {
        return self.rgba;
    }

    pub fn row(self: *const CapturedFrame, y: u32) ![]const u8 {
        if (y >= self.height) return error.CaptureRowOutOfBounds;
        const row_bytes = std.math.mul(usize, self.width, 4) catch
            return error.CaptureDimensionsOverflow;
        const start = std.math.mul(usize, y, row_bytes) catch
            return error.CaptureDimensionsOverflow;
        return self.rgba[start .. start + row_bytes];
    }
};

test "captured frame validates ownership shape and exposes immutable rows" {
    const pixels = try std.testing.allocator.alloc(u8, 2 * 2 * 4);
    @memset(pixels, 7);
    var capture = try CapturedFrame.initOwned(std.testing.allocator, 2, 2, pixels);
    defer capture.deinit();

    try std.testing.expectEqual(@as(usize, 16), capture.bytes().len);
    try std.testing.expectEqualSlices(u8, &([_]u8{7} ** 8), try capture.row(1));
    try std.testing.expectError(error.CaptureRowOutOfBounds, capture.row(2));
}

test "captured frame rejects payloads that do not match dimensions" {
    const pixels = try std.testing.allocator.alloc(u8, 3);
    defer std.testing.allocator.free(pixels);
    try std.testing.expectError(
        error.InvalidCapturePayloadLength,
        CapturedFrame.initOwned(std.testing.allocator, 1, 1, pixels),
    );
}
