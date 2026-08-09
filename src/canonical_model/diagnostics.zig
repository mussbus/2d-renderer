const std = @import("std");

pub const Severity = enum {
    @"error",
    warning,
    info,
};

pub const Category = enum {
    identity,
    reference,
    graph,
    transform,
    value,
    morphology_binding,
    attachment,
    semantic,
};

pub const Code = enum {
    duplicate_id,
    invalid_utf8,
    missing_reference,
    wrong_reference_type,
    invalid_component_root_count,
    invalid_skeleton_root_count,
    invalid_parent_relationship,
    component_tree_cycle,
    skeleton_cycle,
    morphology_dependency_cycle,
    non_finite_value,
    invalid_normalized_range,
    invalid_parameter_range,
    default_outside_hard_range,
    malformed_quaternion,
    invalid_joint_range,
    unsupported_binding_target_property,
    unsupported_target_operation,
    multiple_authoritative_writers,
    unresolved_dependency,
    conflicting_binding_ownership,
    invalid_derived_input_reference,
    group_writes_low_level_target,
    socket_missing_anchor,
    attachment_missing_socket,
    attachment_missing_mount_anchor,
    attachment_capacity_exceeded,
    multiplicity_contradiction,
    incompatible_attachment_type,
    attachment_parent_mismatch,
    surface_missing_region,
    surface_missing_material,
    seam_missing_member,
    seam_member_mismatch,
    semantic_owner_missing,
    visibility_reference_missing,
    coverage_out_of_range,
    material_definition_missing,
    material_property_unsupported,
    material_property_type_mismatch,
    invalid_material_color,
    invalid_coordinate_contract,
    schema_feature_version_mismatch,
};

pub const Diagnostic = struct {
    severity: Severity,
    code: Code,
    category: Category,
    object_type: []const u8,
    object_id: ?[]const u8,
    property: ?[]const u8,
    reference_type: ?[]const u8,
    reference_id: ?[]const u8,
    message: []const u8,
};

pub const ValidationReport = struct {
    diagnostics: []const Diagnostic,
    error_count: usize,
    warning_count: usize,
    info_count: usize,

    pub fn isValid(self: ValidationReport) bool {
        return self.error_count == 0;
    }
};

pub const CollectorError = error{DiagnosticCapacityExceeded};

pub const Collector = struct {
    storage: []Diagnostic,
    count: usize = 0,
    error_count: usize = 0,
    warning_count: usize = 0,
    info_count: usize = 0,

    pub fn init(storage: []Diagnostic) Collector {
        return .{ .storage = storage };
    }

    pub fn add(self: *Collector, diagnostic: Diagnostic) CollectorError!void {
        if (self.count == self.storage.len) return error.DiagnosticCapacityExceeded;
        self.storage[self.count] = diagnostic;
        self.count += 1;
        switch (diagnostic.severity) {
            .@"error" => self.error_count += 1,
            .warning => self.warning_count += 1,
            .info => self.info_count += 1,
        }
    }

    pub fn finish(self: *Collector) ValidationReport {
        insertionSort(self.storage[0..self.count]);
        return .{
            .diagnostics = self.storage[0..self.count],
            .error_count = self.error_count,
            .warning_count = self.warning_count,
            .info_count = self.info_count,
        };
    }
};

fn insertionSort(items: []Diagnostic) void {
    var index: usize = 1;
    while (index < items.len) : (index += 1) {
        const item = items[index];
        var destination = index;
        while (destination > 0 and lessThan(item, items[destination - 1])) : (destination -= 1) {
            items[destination] = items[destination - 1];
        }
        items[destination] = item;
    }
}

fn lessThan(a: Diagnostic, b: Diagnostic) bool {
    const code_order = std.math.order(@intFromEnum(a.code), @intFromEnum(b.code));
    if (code_order != .eq) return code_order == .lt;
    if (stringOrder(a.object_type, b.object_type)) |result| return result;
    if (optionalStringOrder(a.object_id, b.object_id)) |result| return result;
    if (optionalStringOrder(a.property, b.property)) |result| return result;
    if (optionalStringOrder(a.reference_type, b.reference_type)) |result| return result;
    if (optionalStringOrder(a.reference_id, b.reference_id)) |result| return result;
    return std.mem.order(u8, a.message, b.message) == .lt;
}

fn stringOrder(a: []const u8, b: []const u8) ?bool {
    return switch (std.mem.order(u8, a, b)) {
        .lt => true,
        .gt => false,
        .eq => null,
    };
}

fn optionalStringOrder(a: ?[]const u8, b: ?[]const u8) ?bool {
    if (a == null and b != null) return true;
    if (a != null and b == null) return false;
    if (a == null) return null;
    return stringOrder(a.?, b.?);
}
