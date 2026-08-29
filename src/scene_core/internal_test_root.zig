//! White-box F2C test surface. This module is wired only into the focused
//! scene_core runtime test target and is not a supported downstream API.

pub const registry = @import("registry.zig");
pub const runtime_asset = @import("runtime_asset.zig");
pub const runtime_entity = @import("runtime_entity.zig");
