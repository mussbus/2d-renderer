const std = @import("std");

const HResult = i32;
const Guid = extern struct {
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,
};

const ImagingFactory = extern struct { vtable: *const ImagingFactoryVTable };
const ImagingFactoryVTable = extern struct {
    query_interface: *const anyopaque,
    add_ref: *const anyopaque,
    release: *const fn (*ImagingFactory) callconv(.winapi) u32,
    create_decoder_from_filename: *const fn (*ImagingFactory, [*:0]const u16, ?*const Guid, u32, u32, *?*BitmapDecoder) callconv(.winapi) HResult,
    create_decoder_from_stream: *const anyopaque,
    create_decoder_from_file_handle: *const anyopaque,
    create_component_info: *const anyopaque,
    create_decoder: *const anyopaque,
    create_encoder: *const anyopaque,
    create_palette: *const anyopaque,
    create_format_converter: *const fn (*ImagingFactory, *?*FormatConverter) callconv(.winapi) HResult,
};

const BitmapDecoder = extern struct { vtable: *const BitmapDecoderVTable };
const BitmapDecoderVTable = extern struct {
    query_interface: *const anyopaque,
    add_ref: *const anyopaque,
    release: *const fn (*BitmapDecoder) callconv(.winapi) u32,
    query_capability: *const anyopaque,
    initialize: *const anyopaque,
    get_container_format: *const fn (*BitmapDecoder, *Guid) callconv(.winapi) HResult,
    get_decoder_info: *const anyopaque,
    copy_palette: *const anyopaque,
    get_metadata_query_reader: *const anyopaque,
    get_preview: *const anyopaque,
    get_color_contexts: *const anyopaque,
    get_thumbnail: *const anyopaque,
    get_frame_count: *const fn (*BitmapDecoder, *u32) callconv(.winapi) HResult,
    get_frame: *const fn (*BitmapDecoder, u32, *?*BitmapFrameDecode) callconv(.winapi) HResult,
};

const BitmapSource = extern struct { vtable: *const anyopaque };
const BitmapFrameDecode = extern struct { vtable: *const BitmapFrameDecodeVTable };
const BitmapFrameDecodeVTable = extern struct {
    query_interface: *const anyopaque,
    add_ref: *const anyopaque,
    release: *const fn (*BitmapFrameDecode) callconv(.winapi) u32,
    get_size: *const fn (*BitmapFrameDecode, *u32, *u32) callconv(.winapi) HResult,
    get_pixel_format: *const fn (*BitmapFrameDecode, *Guid) callconv(.winapi) HResult,
    get_resolution: *const anyopaque,
    copy_palette: *const anyopaque,
    copy_pixels: *const anyopaque,
};

const FormatConverter = extern struct { vtable: *const FormatConverterVTable };
const FormatConverterVTable = extern struct {
    query_interface: *const anyopaque,
    add_ref: *const anyopaque,
    release: *const fn (*FormatConverter) callconv(.winapi) u32,
    get_size: *const anyopaque,
    get_pixel_format: *const anyopaque,
    get_resolution: *const anyopaque,
    copy_palette: *const anyopaque,
    copy_pixels: *const fn (*FormatConverter, ?*const anyopaque, u32, u32, [*]u8) callconv(.winapi) HResult,
    initialize: *const fn (*FormatConverter, *BitmapSource, *const Guid, u32, ?*anyopaque, f64, u32) callconv(.winapi) HResult,
    can_convert: *const fn (*FormatConverter, *const Guid, *const Guid, *i32) callconv(.winapi) HResult,
};

const CoInitializeExFn = *const fn (?*anyopaque, u32) callconv(.winapi) HResult;
const CoUninitializeFn = *const fn () callconv(.winapi) void;
const CoCreateInstanceFn = *const fn (*const Guid, ?*anyopaque, u32, *const Guid, *?*anyopaque) callconv(.winapi) HResult;

extern "kernel32" fn LoadLibraryW([*:0]const u16) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn GetProcAddress(*anyopaque, [*:0]const u8) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn FreeLibrary(*anyopaque) callconv(.winapi) i32;

const Ole32 = struct {
    module: *anyopaque,
    initialize: CoInitializeExFn,
    uninitialize: CoUninitializeFn,
    create_instance: CoCreateInstanceFn,

    fn init() !Ole32 {
        const module_name = [_:0]u16{ 'o', 'l', 'e', '3', '2', '.', 'd', 'l', 'l' };
        const module = LoadLibraryW(&module_name) orelse return error.ImageDecoderUnavailable;
        errdefer _ = FreeLibrary(module);
        return .{
            .module = module,
            .initialize = try loadFunction(CoInitializeExFn, module, "CoInitializeEx"),
            .uninitialize = try loadFunction(CoUninitializeFn, module, "CoUninitialize"),
            .create_instance = try loadFunction(CoCreateInstanceFn, module, "CoCreateInstance"),
        };
    }

    fn deinit(ole32: *Ole32) void {
        _ = FreeLibrary(ole32.module);
        ole32.* = undefined;
    }
};

pub const maximum_image_dimension: u32 = 16_384;
pub const maximum_decoded_bytes: u32 = 256 * 1024 * 1024;
pub const rgba_channel_count: u32 = 4;
pub const maximum_windows_path_units: usize = 4095;

pub const PixelLayout = enum { rgba8_unorm, unsupported };
pub const ImageLayout = struct {
    width: u32,
    height: u32,
    row_bytes: u32,
    byte_count: u32,
    pixel_layout: PixelLayout,
};
pub const Metrics = struct {
    decode_attempts: u32 = 0,
    successful_decodes: u32 = 0,
    decoded_bytes: u64 = 0,
};
pub const DecodedImage = struct {
    allocator: std.mem.Allocator,
    layout: ImageLayout,
    pixels: []u8,

    pub fn deinit(image: *DecodedImage) void {
        image.allocator.free(image.pixels);
        image.* = undefined;
    }
};

const clsid_wic_imaging_factory = makeGuid(0xcacaf262, 0x9370, 0x4615, .{ 0xa1, 0x3b, 0x9f, 0x55, 0x39, 0xda, 0x4c, 0x0a });
const iid_wic_imaging_factory = makeGuid(0xec5ec8a9, 0xc395, 0x4314, .{ 0x9c, 0x77, 0x54, 0xd7, 0xa9, 0x35, 0xff, 0x70 });
const png_container_format = makeGuid(0x1b7cfaf4, 0x713f, 0x473c, .{ 0xbb, 0xcd, 0x61, 0x37, 0x42, 0x5f, 0xae, 0xaf });
const rgba8_pixel_format = makeGuid(0xf5c7ad2d, 0x6a8d, 0x43dd, .{ 0xa7, 0xa8, 0xa2, 0x99, 0x35, 0x26, 0x1a, 0xe9 });

const rpc_e_changed_mode: HResult = @bitCast(@as(u32, 0x80010106));
const hresult_file_not_found: HResult = @bitCast(@as(u32, 0x80070002));
const hresult_path_not_found: HResult = @bitCast(@as(u32, 0x80070003));
const wincodec_err_unknown_image_format: HResult = @bitCast(@as(u32, 0x88982f07));
const wincodec_err_component_not_found: HResult = @bitCast(@as(u32, 0x88982f50));
const wincodec_err_bad_image: HResult = @bitCast(@as(u32, 0x88982f60));
const wincodec_err_frame_missing: HResult = @bitCast(@as(u32, 0x88982f62));
const wincodec_err_unsupported_pixel_format: HResult = @bitCast(@as(u32, 0x88982f80));

pub fn validateMetadata(width: u32, height: u32, pixel_layout: PixelLayout) !ImageLayout {
    if (pixel_layout != .rgba8_unorm) return error.UnsupportedPixelLayout;
    if (width == 0 or height == 0) return error.ZeroImageDimensions;
    if (width > maximum_image_dimension or height > maximum_image_dimension) return error.ImageDimensionsExceeded;
    const row_bytes = std.math.mul(u32, width, rgba_channel_count) catch return error.ImageByteSizeOverflow;
    const byte_count = std.math.mul(u32, row_bytes, height) catch return error.ImageByteSizeOverflow;
    if (byte_count > maximum_decoded_bytes) return error.ImageUploadSizeExceeded;
    return .{ .width = width, .height = height, .row_bytes = row_bytes, .byte_count = byte_count, .pixel_layout = pixel_layout };
}

pub fn decodePngFile(allocator: std.mem.Allocator, path: []const u8, metrics: ?*Metrics) !DecodedImage {
    if (metrics) |value| value.decode_attempts += 1;
    if (!std.ascii.endsWithIgnoreCase(path, ".png")) return error.UnsupportedImageFormat;
    if (path.len == 0 or path.len >= maximum_windows_path_units) return error.ImagePathTooLong;

    var wide_path_buffer: [maximum_windows_path_units + 1]u16 = undefined;
    const wide_length = std.unicode.utf8ToUtf16Le(&wide_path_buffer, path) catch return error.InvalidImagePathEncoding;
    wide_path_buffer[wide_length] = 0;
    const wide_path: [*:0]const u16 = @ptrCast(&wide_path_buffer);

    var ole32 = try Ole32.init();
    defer ole32.deinit();
    const initialize_result = ole32.initialize(null, 0);
    const uninitialize = initialize_result >= 0;
    if (initialize_result < 0 and initialize_result != rpc_e_changed_mode) return error.ComInitializationFailure;
    defer if (uninitialize) ole32.uninitialize();

    var raw_factory: ?*anyopaque = null;
    const factory_result = ole32.create_instance(&clsid_wic_imaging_factory, null, 1, &iid_wic_imaging_factory, &raw_factory);
    if (factory_result < 0 or raw_factory == null) return error.ImageDecoderUnavailable;
    const factory: *ImagingFactory = @ptrCast(@alignCast(raw_factory.?));
    defer _ = factory.vtable.release(factory);

    var decoder: ?*BitmapDecoder = null;
    const decoder_result = factory.vtable.create_decoder_from_filename(factory, wide_path, null, 0x80000000, 0, &decoder);
    if (decoder_result < 0 or decoder == null) return classifyDecodeFailure(decoder_result);
    defer _ = decoder.?.vtable.release(decoder.?);

    var container_format: Guid = undefined;
    if (decoder.?.vtable.get_container_format(decoder.?, &container_format) < 0) return error.MalformedImage;
    if (!guidEqual(container_format, png_container_format)) return error.UnsupportedImageFormat;
    var frame_count: u32 = 0;
    if (decoder.?.vtable.get_frame_count(decoder.?, &frame_count) < 0 or frame_count != 1) return error.UnsupportedFrameCount;

    var frame: ?*BitmapFrameDecode = null;
    const frame_result = decoder.?.vtable.get_frame(decoder.?, 0, &frame);
    if (frame_result < 0 or frame == null) return classifyDecodeFailure(frame_result);
    defer _ = frame.?.vtable.release(frame.?);
    var width: u32 = 0;
    var height: u32 = 0;
    if (frame.?.vtable.get_size(frame.?, &width, &height) < 0) return error.MalformedImage;
    const layout = try validateMetadata(width, height, .rgba8_unorm);

    var source_pixel_format: Guid = undefined;
    if (frame.?.vtable.get_pixel_format(frame.?, &source_pixel_format) < 0) return error.UnsupportedPixelLayout;
    var converter: ?*FormatConverter = null;
    if (factory.vtable.create_format_converter(factory, &converter) < 0 or converter == null) return error.ImageFormatConversionFailure;
    defer _ = converter.?.vtable.release(converter.?);
    var can_convert: i32 = 0;
    if (converter.?.vtable.can_convert(converter.?, &source_pixel_format, &rgba8_pixel_format, &can_convert) < 0 or can_convert == 0) {
        return error.UnsupportedPixelLayout;
    }
    const source: *BitmapSource = @ptrCast(frame.?);
    if (converter.?.vtable.initialize(converter.?, source, &rgba8_pixel_format, 0, null, 0, 0) < 0) {
        return error.ImageFormatConversionFailure;
    }

    const pixels = allocator.alloc(u8, layout.byte_count) catch return error.AllocationFailure;
    errdefer allocator.free(pixels);
    const copy_result = converter.?.vtable.copy_pixels(converter.?, null, layout.row_bytes, layout.byte_count, pixels.ptr);
    if (copy_result < 0) return classifyDecodeFailure(copy_result);
    if (metrics) |value| {
        value.successful_decodes += 1;
        value.decoded_bytes += layout.byte_count;
    }
    return .{ .allocator = allocator, .layout = layout, .pixels = pixels };
}

fn classifyDecodeFailure(result: HResult) anyerror {
    if (result == hresult_file_not_found or result == hresult_path_not_found) return error.MissingImageFile;
    if (result == wincodec_err_unknown_image_format or result == wincodec_err_component_not_found) return error.MalformedImage;
    if (result == wincodec_err_unsupported_pixel_format) return error.UnsupportedPixelLayout;
    if (result == wincodec_err_bad_image or result == wincodec_err_frame_missing) return error.MalformedImage;
    return error.ImageDecodeFailure;
}

fn loadFunction(comptime Function: type, module: *anyopaque, name: [*:0]const u8) !Function {
    const address = GetProcAddress(module, name) orelse return error.ImageDecoderUnavailable;
    return @ptrCast(address);
}

fn guidEqual(left: Guid, right: Guid) bool {
    return std.mem.eql(u8, std.mem.asBytes(&left), std.mem.asBytes(&right));
}

fn makeGuid(data1: u32, data2: u16, data3: u16, data4: [8]u8) Guid {
    return .{ .data1 = data1, .data2 = data2, .data3 = data3, .data4 = data4 };
}
