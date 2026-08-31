const std = @import("std");
const frame_capture = @import("frame_capture");
const visual_truth = @import("visual_truth");

pub const PixelEvidence = struct {
    width: u32 = 0,
    height: u32 = 0,
    rgb_payload_bytes: u64 = 0,
    sha256: [32]u8 = [_]u8{0} ** 32,
    minimum_channel: u8 = 255,
    maximum_channel: u8 = 0,
    mean_channel: f64 = 0,
};

/// Writes historical PPM evidence from a copied capture. It receives no
/// renderer, GPU resource, scene, or other mutable production authority.
pub fn writePpm(
    io: std.Io,
    path: []const u8,
    capture: *const frame_capture.CapturedFrame,
) !PixelEvidence {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var header_buffer: [64]u8 = undefined;
    const header = try std.fmt.bufPrint(
        &header_buffer,
        "P6\n{d} {d}\n255\n",
        .{ capture.width, capture.height },
    );
    try file.writeStreamingAll(io, header);

    var sha256 = std.crypto.hash.sha2.Sha256.init(.{});
    var minimum_channel: u8 = 255;
    var maximum_channel: u8 = 0;
    var channel_sum: u64 = 0;
    const row_bytes = std.math.mul(usize, capture.width, 3) catch
        return error.CaptureDimensionsOverflow;
    const rgb_row = try std.heap.smp_allocator.alloc(u8, row_bytes);
    defer std.heap.smp_allocator.free(rgb_row);

    for (0..capture.height) |y| {
        const rgba = try capture.row(@intCast(y));
        for (0..capture.width) |x| {
            const source_offset = x * 4;
            const destination_offset = x * 3;
            @memcpy(
                rgb_row[destination_offset .. destination_offset + 3],
                rgba[source_offset .. source_offset + 3],
            );
            inline for (0..3) |channel_index| {
                const channel = rgb_row[destination_offset + channel_index];
                minimum_channel = @min(minimum_channel, channel);
                maximum_channel = @max(maximum_channel, channel);
                channel_sum += channel;
            }
        }
        try file.writeStreamingAll(io, rgb_row);
        sha256.update(rgb_row);
    }

    var digest: [32]u8 = undefined;
    sha256.final(&digest);
    const payload_bytes = std.math.mul(u64, capture.width, capture.height) catch
        return error.CaptureDimensionsOverflow;
    const rgb_payload_bytes = std.math.mul(u64, payload_bytes, 3) catch
        return error.CaptureDimensionsOverflow;
    return .{
        .width = capture.width,
        .height = capture.height,
        .rgb_payload_bytes = rgb_payload_bytes,
        .sha256 = digest,
        .minimum_channel = minimum_channel,
        .maximum_channel = maximum_channel,
        .mean_channel = @as(f64, @floatFromInt(channel_sum)) /
            @as(f64, @floatFromInt(rgb_payload_bytes)),
    };
}

pub fn writePng(
    io: std.Io,
    path: []const u8,
    capture: *const frame_capture.CapturedFrame,
) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try visual_truth.writeRgbaPng(
        &file,
        io,
        capture.bytes().ptr,
        capture.width,
        capture.height,
        capture.width * 4,
    );
}
