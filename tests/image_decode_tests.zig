const std = @import("std");
const image_decode = @import("image_decode");

test "PNG metadata catches unsupported layouts zero dimensions overflow and upload limits" {
    try std.testing.expectError(error.UnsupportedPixelLayout, image_decode.validateMetadata(1, 1, .unsupported));
    try std.testing.expectError(error.ZeroImageDimensions, image_decode.validateMetadata(0, 1, .rgba8_unorm));
    try std.testing.expectError(error.ImageDimensionsExceeded, image_decode.validateMetadata(image_decode.maximum_image_dimension + 1, 1, .rgba8_unorm));
    try std.testing.expectError(error.ImageUploadSizeExceeded, image_decode.validateMetadata(16_384, 16_384, .rgba8_unorm));
    const valid = try image_decode.validateMetadata(256, 256, .rgba8_unorm);
    try std.testing.expectEqual(@as(u32, 1024), valid.row_bytes);
    try std.testing.expectEqual(@as(u32, 262_144), valid.byte_count);
}

test "WIC decodes production PNG alpha and classifies missing corrupt and unsupported files" {
    var metrics = image_decode.Metrics{};
    var decoded = try image_decode.decodePngFile(
        std.testing.allocator,
        "assets/art/mechanical_atlas.png",
        &metrics,
    );
    defer decoded.deinit();
    try std.testing.expectEqual(@as(u32, 256), decoded.layout.width);
    try std.testing.expectEqual(@as(u32, 256), decoded.layout.height);
    try std.testing.expectEqual(image_decode.PixelLayout.rgba8_unorm, decoded.layout.pixel_layout);
    try std.testing.expectEqual(@as(u32, 1), metrics.successful_decodes);
    var transparent_pixels: usize = 0;
    var opaque_pixels: usize = 0;
    var offset: usize = 3;
    while (offset < decoded.pixels.len) : (offset += 4) {
        if (decoded.pixels[offset] == 0) transparent_pixels += 1;
        if (decoded.pixels[offset] == 255) opaque_pixels += 1;
    }
    try std.testing.expect(transparent_pixels > 1000);
    try std.testing.expect(opaque_pixels > 1000);

    try std.testing.expectError(
        error.MissingImageFile,
        image_decode.decodePngFile(std.testing.allocator, "tests/fixtures/does_not_exist.png", null),
    );
    try std.testing.expectError(
        error.MalformedImage,
        image_decode.decodePngFile(std.testing.allocator, "tests/fixtures/p23_corrupt.png", null),
    );
    try std.testing.expectError(
        error.UnsupportedImageFormat,
        image_decode.decodePngFile(std.testing.allocator, "tests/fixtures/p23_corrupt.jpg", null),
    );
}

test "PNG decode allocation failure leaves the fixed allocator unchanged" {
    var bytes: [1]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&bytes);
    try std.testing.expectError(
        error.AllocationFailure,
        image_decode.decodePngFile(fixed.allocator(), "assets/art/energy_atlas.png", null),
    );
    try std.testing.expectEqual(@as(usize, 0), fixed.end_index);
}
