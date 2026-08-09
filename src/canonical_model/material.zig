const identity = @import("identity.zig");

pub const ColorSpace = enum {
    linear_srgb,
};

pub const ChannelOrder = enum {
    rgba,
};

pub const AlphaConvention = enum {
    straight_unassociated,
};

pub const LinearSrgbRgba = struct {
    channels: [4]f32,

    pub const color_space = ColorSpace.linear_srgb;
    pub const channel_order = ChannelOrder.rgba;
    pub const alpha_convention = AlphaConvention.straight_unassociated;
    pub const minimum_channel: f32 = 0.0;
    pub const maximum_channel: f32 = 1.0;

    pub fn init(red: f32, green: f32, blue: f32, alpha: f32) LinearSrgbRgba {
        return .{ .channels = .{ red, green, blue, alpha } };
    }

    pub fn r(self: LinearSrgbRgba) f32 {
        return self.channels[0];
    }

    pub fn g(self: LinearSrgbRgba) f32 {
        return self.channels[1];
    }

    pub fn b(self: LinearSrgbRgba) f32 {
        return self.channels[2];
    }

    pub fn a(self: LinearSrgbRgba) f32 {
        return self.channels[3];
    }
};

pub const MaterialValueKind = enum {
    linear_srgb_rgba,
    scalar,
    boolean,
    vector4,
    response_reference,
    detail_reference,
};

pub const MaterialPropertySpec = struct {
    property_id: identity.MaterialPropertyId,
    value_kind: MaterialValueKind,
    required: bool,
};

pub const MaterialDefinition = struct {
    material_definition_id: identity.MaterialDefinitionId,
    display_name: identity.DisplayName,
    capabilities: []const identity.MaterialCapabilityId,
    property_specs: []const MaterialPropertySpec,
};

pub const MaterialPropertyValue = union(enum) {
    linear_srgb_rgba: LinearSrgbRgba,
    scalar: f32,
    boolean: bool,
    vector4: [4]f32,
    response_reference: identity.MaterialResponseId,
    detail_reference: identity.MaterialDetailId,
};

pub const MaterialProperty = struct {
    property_id: identity.MaterialPropertyId,
    value: MaterialPropertyValue,
};

pub const MaterialInstance = struct {
    material_instance_id: identity.MaterialInstanceId,
    display_name: identity.DisplayName,
    definition_id: identity.MaterialDefinitionId,
    properties: []const MaterialProperty,
};
