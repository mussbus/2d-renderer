const debug = @import("debug_draw");
comptime {
    _ = @sizeOf(debug.CommandBufferWithCapacity(0));
}
