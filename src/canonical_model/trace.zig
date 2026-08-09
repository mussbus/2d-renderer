const std = @import("std");
const definition = @import("definition.zig");
const identity = @import("identity.zig");
const morphology = @import("morphology.zig");

pub const TraceError = error{
    OutputTooSmall,
    DependencyCycle,
    MultipleDerivedWriters,
    MultipleAuthoritativeWriters,
};

pub fn deterministicDependencyOrder(
    source: *const definition.CanonicalCreatureDefinition,
    output: []identity.MorphologyDependencyId,
) TraceError![]const identity.MorphologyDependencyId {
    const dependencies = source.morphology_graph.dependencies;
    if (output.len < dependencies.len) return error.OutputTooSmall;

    var emitted: usize = 0;
    while (emitted < dependencies.len) {
        var selected: ?usize = null;
        for (dependencies, 0..) |dependency, index| {
            if (containsDependencyId(output[0..emitted], dependency.dependency_id)) continue;
            if (!predecessorsEmitted(dependencies, dependency, output[0..emitted])) continue;
            if (selected == null or idLess(
                dependency.dependency_id.value.bytes,
                dependencies[selected.?].dependency_id.value.bytes,
            )) {
                selected = index;
            }
        }

        if (selected == null) return error.DependencyCycle;
        output[emitted] = dependencies[selected.?].dependency_id;
        emitted += 1;
    }
    return output[0..emitted];
}

pub fn authoritativeWriter(
    source: *const definition.CanonicalCreatureDefinition,
    target: morphology.BindingTarget,
) TraceError!?identity.MorphologyBindingId {
    var found: ?identity.MorphologyBindingId = null;
    for (source.morphology_bindings) |binding| {
        if (binding.writer_role != .authoritative or
            !morphology.bindingTargetsEqual(binding.target, target)) continue;
        if (found != null) return error.MultipleAuthoritativeWriters;
        found = binding.binding_id;
    }
    return found;
}

pub fn collectTargetDrivers(
    source: *const definition.CanonicalCreatureDefinition,
    target: morphology.BindingTarget,
    output: []identity.MorphologyBindingId,
) TraceError![]const identity.MorphologyBindingId {
    var count: usize = 0;
    for (source.morphology_bindings) |binding| {
        if (!morphology.bindingTargetsEqual(binding.target, target)) continue;
        if (count == output.len) return error.OutputTooSmall;
        output[count] = binding.binding_id;
        count += 1;
    }
    insertionSortIds(output[0..count]);
    return output[0..count];
}

pub fn collectDerivedInputs(
    source: *const definition.CanonicalCreatureDefinition,
    output_parameter_id: identity.MorphologyParameterId,
    output: []identity.MorphologyParameterId,
) TraceError!?[]const identity.MorphologyParameterId {
    var found: ?[]const identity.MorphologyParameterId = null;
    for (source.morphology_graph.dependencies) |dependency| {
        if (!dependency.output_parameter_id.eql(output_parameter_id)) continue;
        if (found != null) return error.MultipleDerivedWriters;
        found = dependency.input_parameter_ids;
    }
    const inputs = found orelse return null;
    if (output.len < inputs.len) return error.OutputTooSmall;
    @memcpy(output[0..inputs.len], inputs);
    insertionSortIds(output[0..inputs.len]);
    return output[0..inputs.len];
}

fn predecessorsEmitted(
    dependencies: []const morphology.ParameterDependency,
    dependency: morphology.ParameterDependency,
    emitted: []const identity.MorphologyDependencyId,
) bool {
    for (dependency.input_parameter_ids) |input_id| {
        for (dependencies) |candidate| {
            if (!candidate.output_parameter_id.eql(input_id)) continue;
            if (!containsDependencyId(emitted, candidate.dependency_id)) return false;
        }
    }
    return true;
}

fn containsDependencyId(
    values: []const identity.MorphologyDependencyId,
    value: identity.MorphologyDependencyId,
) bool {
    for (values) |candidate| if (candidate.eql(value)) return true;
    return false;
}

fn insertionSortIds(items: anytype) void {
    var index: usize = 1;
    while (index < items.len) : (index += 1) {
        const item = items[index];
        var destination = index;
        while (destination > 0 and idLess(
            item.value.bytes,
            items[destination - 1].value.bytes,
        )) : (destination -= 1) {
            items[destination] = items[destination - 1];
        }
        items[destination] = item;
    }
}

fn idLess(a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}
