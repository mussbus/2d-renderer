const foundation = @import("foundation");

/// Opaque process-local token returned by the neutral runtime asset boundary.
/// It is neither persistent identity nor permission to create a downstream
/// renderer, physics, or other track-owned object.
pub const ResolvedAssetToken = extern struct {
    value: u32,

    pub const invalid = ResolvedAssetToken{ .value = 0 };

    pub fn init(value: u32) error{InvalidResolvedAssetToken}!ResolvedAssetToken {
        if (value == 0) return error.InvalidResolvedAssetToken;
        return .{ .value = value };
    }

    pub fn eql(a: ResolvedAssetToken, b: ResolvedAssetToken) bool {
        return a.value == b.value;
    }
};

pub const ResolveError = error{
    AssetResolutionFailed,
    InvalidResolvedAssetToken,
};

pub const Resolver = struct {
    context: ?*anyopaque,
    resolve_fn: *const fn (?*anyopaque, foundation.reference.AssetRef) anyerror!ResolvedAssetToken,

    pub fn resolve(self: Resolver, reference: foundation.reference.AssetRef) ResolveError!ResolvedAssetToken {
        const token = self.resolve_fn(self.context, reference) catch return error.AssetResolutionFailed;
        if (token.value == 0) return error.InvalidResolvedAssetToken;
        return token;
    }
};
