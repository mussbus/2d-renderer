const std = @import("std");
const skeleton = @import("skeleton");

pub const maximum_attribute_definitions: usize = 64;
pub const maximum_capability_definitions: usize = 64;
pub const maximum_resolution_modifiers: usize = 256;
pub const maximum_resolution_grants: usize = 256;

pub const AttributeId = enum(u16) {
    _,

    pub fn index(id: AttributeId) usize {
        return @intFromEnum(id);
    }
};

pub const CapabilityId = enum(u16) {
    _,

    pub fn index(id: CapabilityId) usize {
        return @intFromEnum(id);
    }
};

pub const AttributeOperation = enum(u8) {
    add,
    multiply,
};

pub const AttributeDefinitionInput = struct {
    stable_id: []const u8,
    base_value: f32,
    minimum: f32,
    maximum: f32,

    pub fn validate(input: AttributeDefinitionInput) !void {
        if (!std.math.isFinite(input.base_value) or
            !std.math.isFinite(input.minimum) or
            !std.math.isFinite(input.maximum))
        {
            return error.NonFiniteAttributeDefinition;
        }
        if (input.minimum > input.maximum or
            input.base_value < input.minimum or
            input.base_value > input.maximum)
        {
            return error.InvalidAttributeRange;
        }
    }
};

pub const CapabilityDefinitionInput = struct {
    stable_id: []const u8,
    granted_by_default: bool = false,
};

pub const AttributeDefinition = struct {
    id: AttributeId,
    stable_id: skeleton.DebugName,
    base_value: f32,
    minimum: f32,
    maximum: f32,

    pub fn validate(definition: AttributeDefinition) !void {
        try (AttributeDefinitionInput{
            .stable_id = definition.stable_id.slice(),
            .base_value = definition.base_value,
            .minimum = definition.minimum,
            .maximum = definition.maximum,
        }).validate();
    }
};

pub const CapabilityDefinition = struct {
    id: CapabilityId,
    stable_id: skeleton.DebugName,
    granted_by_default: bool,
};

pub const SourceKindId = enum(u16) {
    _,
};

pub const SourceId = struct {
    kind: SourceKindId,
    instance: u16,

    pub fn init(kind: u16, instance: u16) SourceId {
        return .{ .kind = @enumFromInt(kind), .instance = instance };
    }
};

pub const BaseAttributeOverride = struct {
    attribute: AttributeId,
    value: f32,
};

pub const Modifier = struct {
    source: SourceId,
    source_ordinal: u16,
    attribute: AttributeId,
    operation: AttributeOperation,
    amount: f32,
};

pub const CapabilityGrant = struct {
    source: SourceId,
    capability: CapabilityId,
};

pub const ResolvedSet = struct {
    attribute_values: [maximum_attribute_definitions]f32 = [_]f32{0} ** maximum_attribute_definitions,
    capability_source_counts: [maximum_capability_definitions]u16 = [_]u16{0} ** maximum_capability_definitions,
    attribute_count: u16 = 0,
    capability_count: u16 = 0,
    applied_modifier_count: u16 = 0,
    active_grant_count: u16 = 0,

    pub fn value(resolved: ResolvedSet, id: AttributeId) !f32 {
        if (id.index() >= resolved.attribute_count) return error.InvalidAttributeId;
        return resolved.attribute_values[id.index()];
    }

    pub fn hasCapability(resolved: ResolvedSet, id: CapabilityId) bool {
        return resolved.grantCount(id) catch 0 > 0;
    }

    pub fn grantCount(resolved: ResolvedSet, id: CapabilityId) !u16 {
        if (id.index() >= resolved.capability_count) return error.InvalidCapabilityId;
        return resolved.capability_source_counts[id.index()];
    }

    pub fn validate(resolved: ResolvedSet) !void {
        if (resolved.attribute_count > maximum_attribute_definitions or
            resolved.capability_count > maximum_capability_definitions or
            resolved.applied_modifier_count > maximum_resolution_modifiers or
            resolved.active_grant_count > maximum_resolution_grants)
        {
            return error.InvalidResolvedPropertyCount;
        }
        for (resolved.attribute_values[0..resolved.attribute_count]) |attribute_value| {
            if (!std.math.isFinite(attribute_value)) return error.NonFiniteResolvedAttribute;
        }
    }
};

pub const Builder = struct {
    attribute_definitions: []const AttributeDefinition,
    capability_definitions: []const CapabilityDefinition,
    resolved: ResolvedSet,
    modifiers: [maximum_resolution_modifiers]Modifier = undefined,
    modifier_count: u16 = 0,
    grants: [maximum_resolution_grants]CapabilityGrant = undefined,
    grant_count: u16 = 0,

    pub fn init(
        attribute_definitions: []const AttributeDefinition,
        capability_definitions: []const CapabilityDefinition,
        base_overrides: []const BaseAttributeOverride,
    ) !Builder {
        if (attribute_definitions.len > maximum_attribute_definitions or
            capability_definitions.len > maximum_capability_definitions)
        {
            return error.PropertyDefinitionCapacityExceeded;
        }

        var builder = Builder{
            .attribute_definitions = attribute_definitions,
            .capability_definitions = capability_definitions,
            .resolved = .{
                .attribute_count = @intCast(attribute_definitions.len),
                .capability_count = @intCast(capability_definitions.len),
            },
        };
        for (attribute_definitions, 0..) |definition, index| {
            if (definition.id.index() != index) return error.NonCanonicalAttributeDefinitionOrder;
            try definition.validate();
            builder.resolved.attribute_values[index] = definition.base_value;
        }
        for (capability_definitions, 0..) |definition, index| {
            if (definition.id.index() != index) return error.NonCanonicalCapabilityDefinitionOrder;
            builder.resolved.capability_source_counts[index] = @intFromBool(definition.granted_by_default);
        }
        for (base_overrides, 0..) |override, index| {
            if (override.attribute.index() >= attribute_definitions.len) return error.InvalidAttributeId;
            if (!std.math.isFinite(override.value)) return error.NonFiniteBaseAttributeOverride;
            const definition = attribute_definitions[override.attribute.index()];
            if (override.value < definition.minimum or override.value > definition.maximum) {
                return error.BaseAttributeOverrideOutOfRange;
            }
            for (base_overrides[0..index]) |existing| {
                if (existing.attribute == override.attribute) return error.DuplicateBaseAttributeOverride;
            }
            builder.resolved.attribute_values[override.attribute.index()] = override.value;
        }
        return builder;
    }

    pub fn addModifier(builder: *Builder, modifier: Modifier) !void {
        if (builder.modifier_count == maximum_resolution_modifiers) {
            return error.PropertyModifierCapacityExceeded;
        }
        if (modifier.attribute.index() >= builder.attribute_definitions.len) return error.InvalidAttributeId;
        try validateModifierAmount(modifier.operation, modifier.amount);
        for (builder.modifiers[0..builder.modifier_count]) |existing| {
            if (sameModifierKey(existing, modifier)) return error.DuplicatePropertyModifierKey;
        }
        builder.modifiers[builder.modifier_count] = modifier;
        builder.modifier_count += 1;
    }

    pub fn addCapabilityGrant(builder: *Builder, grant: CapabilityGrant) !void {
        if (builder.grant_count == maximum_resolution_grants) {
            return error.PropertyGrantCapacityExceeded;
        }
        if (grant.capability.index() >= builder.capability_definitions.len) return error.InvalidCapabilityId;
        for (builder.grants[0..builder.grant_count]) |existing| {
            if (sameSource(existing.source, grant.source) and existing.capability == grant.capability) {
                return error.DuplicateCapabilitySource;
            }
        }
        builder.grants[builder.grant_count] = grant;
        builder.grant_count += 1;
    }

    pub fn finish(builder: *Builder) !ResolvedSet {
        insertionSortModifiers(builder.modifiers[0..builder.modifier_count]);
        var additive_totals = [_]f64{0} ** maximum_attribute_definitions;
        var multiplier_products = [_]f64{1} ** maximum_attribute_definitions;
        for (builder.modifiers[0..builder.modifier_count]) |modifier| {
            const index = modifier.attribute.index();
            switch (modifier.operation) {
                .add => additive_totals[index] += modifier.amount,
                .multiply => multiplier_products[index] *= modifier.amount,
            }
        }
        for (builder.attribute_definitions, 0..) |definition, index| {
            const base: f64 = builder.resolved.attribute_values[index];
            const raw = (base + additive_totals[index]) * multiplier_products[index];
            const bounded = std.math.clamp(raw, @as(f64, definition.minimum), @as(f64, definition.maximum));
            builder.resolved.attribute_values[index] = @floatCast(bounded);
        }
        for (builder.grants[0..builder.grant_count]) |grant| {
            const count = &builder.resolved.capability_source_counts[grant.capability.index()];
            count.* = std.math.add(u16, count.*, 1) catch return error.CapabilitySourceCountOverflow;
        }
        builder.resolved.applied_modifier_count = builder.modifier_count;
        builder.resolved.active_grant_count = builder.grant_count;
        try builder.resolved.validate();
        return builder.resolved;
    }
};

pub fn validateModifierAmount(operation: AttributeOperation, amount: f32) !void {
    if (!std.math.isFinite(amount)) return error.NonFiniteAttributeModifier;
    if (operation == .multiply and (amount < 0 or amount > 16)) {
        return error.InvalidMultiplicativeModifier;
    }
}

fn insertionSortModifiers(modifiers: []Modifier) void {
    var index: usize = 1;
    while (index < modifiers.len) : (index += 1) {
        const value = modifiers[index];
        var destination = index;
        while (destination > 0 and modifierLessThan(value, modifiers[destination - 1])) {
            modifiers[destination] = modifiers[destination - 1];
            destination -= 1;
        }
        modifiers[destination] = value;
    }
}

fn modifierLessThan(left: Modifier, right: Modifier) bool {
    const left_attribute = @intFromEnum(left.attribute);
    const right_attribute = @intFromEnum(right.attribute);
    if (left_attribute != right_attribute) return left_attribute < right_attribute;
    const left_operation = @intFromEnum(left.operation);
    const right_operation = @intFromEnum(right.operation);
    if (left_operation != right_operation) return left_operation < right_operation;
    const left_kind = @intFromEnum(left.source.kind);
    const right_kind = @intFromEnum(right.source.kind);
    if (left_kind != right_kind) return left_kind < right_kind;
    if (left.source.instance != right.source.instance) return left.source.instance < right.source.instance;
    return left.source_ordinal < right.source_ordinal;
}

fn sameModifierKey(left: Modifier, right: Modifier) bool {
    return left.attribute == right.attribute and
        left.operation == right.operation and
        sameSource(left.source, right.source) and
        left.source_ordinal == right.source_ordinal;
}

fn sameSource(left: SourceId, right: SourceId) bool {
    return left.kind == right.kind and left.instance == right.instance;
}
