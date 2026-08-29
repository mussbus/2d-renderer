const std = @import("std");
const foundation = @import("foundation");

pub const max_tags_per_entity: usize = 64;
pub const max_tag_length: usize = 63;

pub const TagId = struct {
    value: []const u8,

    pub fn init(value: []const u8) error{InvalidTagId}!TagId {
        if (!validTag(value)) return error.InvalidTagId;
        return .{ .value = value };
    }

    pub fn eql(a: TagId, b: TagId) bool {
        return std.mem.eql(u8, a.value, b.value);
    }

    pub fn order(a: TagId, b: TagId) std.math.Order {
        return std.mem.order(u8, a.value, b.value);
    }
};

pub const EnabledIntent = enum {
    inherit,
    enabled,
    disabled,
};

pub const VisibilityIntent = enum {
    inherit,
    visible,
    hidden,
};

pub const PlacementClassification = enum {
    authored,
    editor_preview,
    cutscene_overlay,
};

pub const LayerSystem = enum {
    render,
    lighting,
    collision,
    navigation,
};

pub const LayerAssignment = struct {
    system: LayerSystem,
    layer: foundation.reference.AssetRef,

    pub fn validate(self: LayerAssignment) error{WrongLayerKind}!void {
        const expected_prefix = switch (self.system) {
            .render, .lighting => "r.",
            .collision => "p.",
            .navigation => "w.",
        };
        if (!std.mem.startsWith(u8, self.layer.expected_kind.name, expected_prefix)) {
            return error.WrongLayerKind;
        }
    }
};

pub fn effectiveEnabled(parent: bool, intent: EnabledIntent) bool {
    if (!parent) return false;
    return switch (intent) {
        .inherit, .enabled => true,
        .disabled => false,
    };
}

fn validTag(value: []const u8) bool {
    if (value.len == 0 or value.len > max_tag_length) return false;
    const colon = std.mem.indexOfScalar(u8, value, ':') orelse return false;
    if (std.mem.indexOfScalarPos(u8, value, colon + 1, ':') != null) return false;
    return validSegment(value[0..colon]) and validSegment(value[colon + 1 ..]);
}

fn validSegment(value: []const u8) bool {
    if (value.len == 0 or value[0] < 'a' or value[0] > 'z') return false;
    for (value[1..]) |byte| {
        if (!((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_')) return false;
    }
    return true;
}
