const std = @import("std");
const f = @import("foundation");
pub const allocator = std.testing.allocator;
pub const namespace = f.identity.NamespaceId.parseCanonical("71aadcd3-3b42-52c8-b3a9-e41804af4329") catch @compileError("valid Effects/projectiles test namespace");
pub const seed = f.determinism.Seed128{ .bytes = .{1} ** 16 };
pub fn id(key: []const u8) f.identity.EntityId {
    return f.identity.uuidV5(f.identity.EntityId, namespace, key);
}
// 2e-5 m permits accumulated 240 Hz f32 integration rounding, well below a pixel.
pub const tolerance: f32 = 2e-5;
