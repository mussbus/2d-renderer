pub const c = @cImport({
    // Zig 0.16.0 ReleaseSafe/ReleaseFast translate MinGW's fortified wcscat and
    // wcscpy wrappers into invalid unused local declarations. No C code is
    // compiled here, so disabling fortify for header translation avoids that
    // pinned compiler/header conflict without changing SDL's linked runtime.
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("SDL3/SDL.h");
});
