const debug = @import("debug_draw");
comptime {
    for (.{ 1, 3, 2048, 2304, 65535 }) |capacity| {
        const Buffer = debug.CommandBufferWithCapacity(capacity);
        _ = @sizeOf(Buffer);
        if (@typeInfo(@FieldType(Buffer, "commands")).array.len != capacity)
            @compileError("debug capacity fixture storage mismatch");
    }
}
