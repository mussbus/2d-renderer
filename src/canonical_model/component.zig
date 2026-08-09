const identity = @import("identity.zig");

pub const Requirement = enum {
    required,
    optional,
};

pub const DefaultState = enum {
    enabled,
    disabled,
};

pub const MultiplicityPolicy = struct {
    minimum: u32,
    maximum: ?u32,
};

pub const CompatibilityRequirements = struct {
    profiles: []const identity.CompatibilityProfileId,
    required_tags: []const identity.SemanticTagId,

    pub const none = CompatibilityRequirements{
        .profiles = &.{},
        .required_tags = &.{},
    };
};

pub const Component = struct {
    component_id: identity.ComponentId,
    display_name: ?identity.DisplayName,
    component_type: identity.ComponentTypeId,
    parent_component_id: ?identity.ComponentId,
    semantic_tags: []const identity.SemanticTagId,
    requirement: Requirement,
    default_state: DefaultState,
    multiplicity: MultiplicityPolicy,
    compatibility: CompatibilityRequirements,
};
