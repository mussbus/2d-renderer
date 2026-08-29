const std = @import("std");
const foundation = @import("foundation");
const canonical_json = @import("canonical_json.zig");

pub const max_records_per_entity: usize = 32;
pub const max_payload_bytes: usize = 64 * 1024;
pub const max_payload_bytes_per_asset: usize = 1024 * 1024;

pub const ComponentTypeId = struct {
    value: []const u8,

    pub fn init(value: []const u8) error{InvalidComponentTypeId}!ComponentTypeId {
        if (!validTypeId(value)) return error.InvalidComponentTypeId;
        return .{ .value = value };
    }

    pub fn eql(a: ComponentTypeId, b: ComponentTypeId) bool {
        return std.mem.eql(u8, a.value, b.value);
    }

    pub fn order(a: ComponentTypeId, b: ComponentTypeId) std.math.Order {
        return std.mem.order(u8, a.value, b.value);
    }
};

pub const Criticality = enum {
    required,
    optional_preserve,
};

pub const ExtensionRecord = struct {
    type_id: ComponentTypeId,
    schema_version: foundation.version.SchemaVersion,
    criticality: Criticality,
    canonical_payload: []const u8,
    dependencies: []const foundation.reference.DirectDependency = &.{},
};

pub const DescriptorError = error{
    InvalidPayload,
    DependencyReportMismatch,
};

pub const ValidateFn = *const fn (
    payload: []const u8,
    declared_dependencies: []const foundation.reference.DirectDependency,
) DescriptorError!void;

pub const Descriptor = struct {
    type_id: ComponentTypeId,
    schema_version: foundation.version.SchemaVersion,
    validate: ValidateFn,
};

pub const RegistryError = error{
    AmbiguousVersionRoute,
    DuplicateDescriptor,
    FrozenRegistry,
    RegistryFull,
};

pub const DescriptorRegistry = struct {
    storage: []Descriptor,
    length: usize = 0,
    frozen: bool = false,

    pub fn init(storage: []Descriptor) DescriptorRegistry {
        return .{ .storage = storage };
    }

    pub fn register(self: *DescriptorRegistry, descriptor: Descriptor) RegistryError!void {
        if (self.frozen) return error.FrozenRegistry;
        if (self.length == self.storage.len) return error.RegistryFull;
        for (self.storage[0..self.length]) |existing| {
            if (!existing.type_id.eql(descriptor.type_id)) continue;
            if (existing.schema_version.eql(descriptor.schema_version)) return error.DuplicateDescriptor;
            if (existing.schema_version.major == descriptor.schema_version.major and
                existing.schema_version.minor == descriptor.schema_version.minor)
            {
                return error.AmbiguousVersionRoute;
            }
        }
        self.storage[self.length] = descriptor;
        self.length += 1;
    }

    pub fn freeze(self: *DescriptorRegistry) void {
        insertionSort(self.storage[0..self.length]);
        self.frozen = true;
    }

    pub fn find(self: *const DescriptorRegistry, type_id: ComponentTypeId, schema_version: foundation.version.SchemaVersion) ?Descriptor {
        if (!self.frozen) return null;
        for (self.storage[0..self.length]) |descriptor| {
            if (descriptor.type_id.eql(type_id) and descriptor.schema_version.eql(schema_version)) return descriptor;
        }
        return null;
    }

    pub fn descriptors(self: *const DescriptorRegistry) []const Descriptor {
        return self.storage[0..self.length];
    }
};

pub const ValidationError = error{
    DuplicateDependency,
    DuplicateExtension,
    InvalidCanonicalPayload,
    PayloadTooLarge,
    RegistryNotFrozen,
    TooManyExtensions,
    UnknownRequiredExtension,
} || DescriptorError;

pub fn validateRecords(records: []const ExtensionRecord, registry: *const DescriptorRegistry) ValidationError!usize {
    if (!registry.frozen) return error.RegistryNotFrozen;
    if (records.len > max_records_per_entity) return error.TooManyExtensions;
    var total_bytes: usize = 0;
    for (records, 0..) |record, index| {
        if (record.canonical_payload.len > max_payload_bytes) return error.PayloadTooLarge;
        var canonical_scratch: [max_payload_bytes]u8 = undefined;
        if (!canonical_json.isCanonical(record.canonical_payload, &canonical_scratch)) return error.InvalidCanonicalPayload;
        total_bytes += record.canonical_payload.len;
        for (records[0..index]) |previous| if (previous.type_id.eql(record.type_id)) return error.DuplicateExtension;
        for (record.dependencies, 0..) |dependency, dependency_index| {
            for (record.dependencies[0..dependency_index]) |previous| {
                if (dependency.asset.revision.asset_id.eql(previous.asset.revision.asset_id)) return error.DuplicateDependency;
            }
        }
        if (registry.find(record.type_id, record.schema_version)) |descriptor| {
            try descriptor.validate(record.canonical_payload, record.dependencies);
        } else if (record.criticality == .required) {
            return error.UnknownRequiredExtension;
        }
    }
    return total_bytes;
}

pub fn validTypeId(value: []const u8) bool {
    if (value.len == 0 or value.len > 127 or value[0] == '.' or value[value.len - 1] == '.') return false;
    var segment_start = true;
    var first_segment = true;
    for (value) |byte| {
        if (byte == '.') {
            if (segment_start) return false;
            segment_start = true;
            first_segment = false;
            continue;
        }
        if (segment_start) {
            if (byte < 'a' or byte > 'z') return false;
            if (first_segment and !isOwner(byte)) return false;
            segment_start = false;
        } else if (!((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_')) {
            return false;
        }
    }
    return !segment_start and !first_segment;
}

fn isOwner(value: u8) bool {
    return switch (value) {
        'f', 'w', 'r', 'p', 'e', 'u', 'c', 'a', 'h' => true,
        else => false,
    };
}

fn insertionSort(values: []Descriptor) void {
    var index: usize = 1;
    while (index < values.len) : (index += 1) {
        const value = values[index];
        var position = index;
        while (position > 0 and descriptorOrder(value, values[position - 1]) == .lt) : (position -= 1) {
            values[position] = values[position - 1];
        }
        values[position] = value;
    }
}

fn descriptorOrder(a: Descriptor, b: Descriptor) std.math.Order {
    const type_order = a.type_id.order(b.type_id);
    if (type_order != .eq) return type_order;
    return a.schema_version.order(b.schema_version);
}
