const std = @import("std");
const canonical_data = @import("canonical_data.zig");
const identity = @import("identity.zig");
const version = @import("version.zig");

pub const ContentHash = canonical_data.Sha256Digest;

pub const AssetKind = struct {
    name: []const u8,

    pub fn init(name: []const u8) error{InvalidAssetKind}!AssetKind {
        if (!validAssetKind(name)) return error.InvalidAssetKind;
        return .{ .name = name };
    }

    pub fn eql(a: AssetKind, b: AssetKind) bool {
        return std.mem.eql(u8, a.name, b.name);
    }

    pub fn order(a: AssetKind, b: AssetKind) std.math.Order {
        return std.mem.order(u8, a.name, b.name);
    }
};

/// One exact revision of a logical asset. Within one resolved dependency
/// graph, an AssetId may resolve to exactly one AssetRevision.
pub const AssetRevision = struct {
    asset_id: identity.AssetId,
    version: version.AssetVersion,
    content_hash: ContentHash,

    pub fn eql(a: AssetRevision, b: AssetRevision) bool {
        return a.asset_id.eql(b.asset_id) and a.version.eql(b.version) and a.content_hash.eql(b.content_hash);
    }

    pub fn order(a: AssetRevision, b: AssetRevision) std.math.Order {
        const id_order = a.asset_id.byteOrder(b.asset_id);
        if (id_order != .eq) return id_order;
        const version_order = a.version.order(b.version);
        if (version_order != .eq) return version_order;
        return a.content_hash.order(b.content_hash);
    }
};

/// Deterministic authored/runtime references pin kind, identity, semantic
/// version, and content hash. They never imply a floating "latest" revision.
pub const AssetRef = struct {
    revision: AssetRevision,
    expected_kind: AssetKind,

    pub fn eql(a: AssetRef, b: AssetRef) bool {
        return a.revision.eql(b.revision) and a.expected_kind.eql(b.expected_kind);
    }

    pub fn order(a: AssetRef, b: AssetRef) std.math.Order {
        const revision_order = a.revision.order(b.revision);
        if (revision_order != .eq) return revision_order;
        return a.expected_kind.order(b.expected_kind);
    }
};

pub const DependencyClass = enum(u8) {
    semantic_runtime_required = 1,
    optional_presentation = 2,
    tooling_only = 3,
};

pub const DirectDependency = struct {
    asset: AssetRef,
    class: DependencyClass,
};

pub const DependencyNode = struct {
    asset: AssetRef,
    dependencies: []const DirectDependency,
};

pub const HashDomain = enum {
    direct_dependencies,
    transitive_dependency_set,

    pub fn name(self: HashDomain) []const u8 {
        // These v1 strings and their framing are persistent deterministic
        // protocols. Any incompatible algorithm requires a new reviewed
        // domain instead of changing an existing result.
        return switch (self) {
            .direct_dependencies => "foundation.asset_direct_dependencies.v1",
            .transitive_dependency_set => "foundation.asset_transitive_dependency_set.v1",
        };
    }
};

pub const GraphError = error{
    CatalogDuplicate,
    DependencyCycle,
    DependencyMismatch,
    DuplicateDependency,
    MissingDependency,
    ScratchTooSmall,
};

const VisitState = enum(u8) { unseen, visiting, complete };

pub const ClosureScratch = struct {
    states: []u8,
    selected_indices: []usize,
};

pub fn hashDirectDependencies(
    class: DependencyClass,
    dependencies: []const DirectDependency,
    index_scratch: []usize,
) GraphError!ContentHash {
    try rejectDuplicateDependencies(dependencies);
    var count: usize = 0;
    for (dependencies, 0..) |dependency, index| {
        if (dependency.class != class) continue;
        if (count == index_scratch.len) return error.ScratchTooSmall;
        index_scratch[count] = index;
        count += 1;
    }
    const selected = index_scratch[0..count];
    sortDependencyIndices(dependencies, selected);
    return hashSelectedDependencies(.direct_dependencies, class, dependencies, selected);
}

pub fn hashTransitiveDependencySet(
    class: DependencyClass,
    direct_dependencies: []const DirectDependency,
    catalog: []const DependencyNode,
    scratch: ClosureScratch,
) GraphError!ContentHash {
    if (scratch.states.len < catalog.len or scratch.selected_indices.len < catalog.len) {
        return error.ScratchTooSmall;
    }
    try rejectCatalogDuplicates(catalog);
    try rejectDuplicateDependencies(direct_dependencies);
    @memset(scratch.states[0..catalog.len], @intFromEnum(VisitState.unseen));
    var selected_count: usize = 0;
    for (direct_dependencies) |dependency| {
        if (dependency.class != class) continue;
        const node_index = findNode(catalog, dependency.asset.revision.asset_id) orelse return error.MissingDependency;
        if (!catalog[node_index].asset.eql(dependency.asset)) return error.DependencyMismatch;
        try visitNode(class, node_index, catalog, scratch.states, scratch.selected_indices, &selected_count);
    }
    const selected = scratch.selected_indices[0..selected_count];
    sortNodeIndices(catalog, selected);
    return hashSelectedNodes(class, catalog, selected);
}

fn visitNode(
    class: DependencyClass,
    node_index: usize,
    catalog: []const DependencyNode,
    states: []u8,
    selected: []usize,
    selected_count: *usize,
) GraphError!void {
    const state: VisitState = @enumFromInt(states[node_index]);
    switch (state) {
        .visiting => return error.DependencyCycle,
        .complete => return,
        .unseen => {},
    }
    states[node_index] = @intFromEnum(VisitState.visiting);
    const node = catalog[node_index];
    try rejectDuplicateDependencies(node.dependencies);
    for (node.dependencies) |dependency| {
        if (dependency.class != class) continue;
        const dependency_index = findNode(catalog, dependency.asset.revision.asset_id) orelse return error.MissingDependency;
        if (!catalog[dependency_index].asset.eql(dependency.asset)) return error.DependencyMismatch;
        try visitNode(class, dependency_index, catalog, states, selected, selected_count);
    }
    states[node_index] = @intFromEnum(VisitState.complete);
    selected[selected_count.*] = node_index;
    selected_count.* += 1;
}

fn rejectCatalogDuplicates(catalog: []const DependencyNode) GraphError!void {
    for (catalog, 0..) |node, index| {
        for (catalog[0..index]) |previous| {
            if (node.asset.revision.asset_id.eql(previous.asset.revision.asset_id)) return error.CatalogDuplicate;
        }
    }
}

fn rejectDuplicateDependencies(dependencies: []const DirectDependency) GraphError!void {
    for (dependencies, 0..) |dependency, index| {
        for (dependencies[0..index]) |previous| {
            if (dependency.asset.revision.asset_id.eql(previous.asset.revision.asset_id)) {
                return error.DuplicateDependency;
            }
        }
    }
}

fn findNode(catalog: []const DependencyNode, asset_id: identity.AssetId) ?usize {
    for (catalog, 0..) |node, index| {
        if (node.asset.revision.asset_id.eql(asset_id)) return index;
    }
    return null;
}

fn sortDependencyIndices(dependencies: []const DirectDependency, indices: []usize) void {
    var index: usize = 1;
    while (index < indices.len) : (index += 1) {
        const value = indices[index];
        var position = index;
        while (position > 0 and dependencyOrder(dependencies[value], dependencies[indices[position - 1]]) == .lt) : (position -= 1) {
            indices[position] = indices[position - 1];
        }
        indices[position] = value;
    }
}

fn sortNodeIndices(catalog: []const DependencyNode, indices: []usize) void {
    var index: usize = 1;
    while (index < indices.len) : (index += 1) {
        const value = indices[index];
        var position = index;
        while (position > 0 and catalog[value].asset.order(catalog[indices[position - 1]].asset) == .lt) : (position -= 1) {
            indices[position] = indices[position - 1];
        }
        indices[position] = value;
    }
}

fn dependencyOrder(a: DirectDependency, b: DirectDependency) std.math.Order {
    const class_order = std.math.order(@intFromEnum(a.class), @intFromEnum(b.class));
    if (class_order != .eq) return class_order;
    return a.asset.order(b.asset);
}

fn hashSelectedDependencies(
    domain: HashDomain,
    class: DependencyClass,
    dependencies: []const DirectDependency,
    selected: []const usize,
) ContentHash {
    var hasher = beginHash(domain, class, selected.len);
    for (selected) |index| updateAssetRef(&hasher, dependencies[index].asset);
    var result: ContentHash = undefined;
    hasher.final(&result.bytes);
    return result;
}

fn hashSelectedNodes(
    class: DependencyClass,
    catalog: []const DependencyNode,
    selected: []const usize,
) ContentHash {
    var hasher = beginHash(.transitive_dependency_set, class, selected.len);
    for (selected) |index| updateAssetRef(&hasher, catalog[index].asset);
    var result: ContentHash = undefined;
    hasher.final(&result.bytes);
    return result;
}

fn beginHash(domain: HashDomain, class: DependencyClass, count: usize) std.crypto.hash.sha2.Sha256 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateFramed(&hasher, domain.name());
    hasher.update(&.{@intFromEnum(class)});
    var count_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &count_bytes, count, .big);
    hasher.update(&count_bytes);
    return hasher;
}

fn updateAssetRef(hasher: *std.crypto.hash.sha2.Sha256, asset: AssetRef) void {
    updateFramed(hasher, asset.expected_kind.name);
    hasher.update(&asset.revision.asset_id.bytes);
    var version_bytes: [12]u8 = undefined;
    std.mem.writeInt(u32, version_bytes[0..4], asset.revision.version.major, .big);
    std.mem.writeInt(u32, version_bytes[4..8], asset.revision.version.minor, .big);
    std.mem.writeInt(u32, version_bytes[8..12], asset.revision.version.patch, .big);
    hasher.update(&version_bytes);
    hasher.update(&asset.revision.content_hash.bytes);
}

fn updateFramed(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    var length_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &length_bytes, value.len, .big);
    hasher.update(&length_bytes);
    hasher.update(value);
}

fn validAssetKind(name: []const u8) bool {
    if (name.len == 0 or name.len > 127 or name[0] == '.' or name[name.len - 1] == '.') return false;
    var segment_start = true;
    for (name) |byte| {
        if (byte == '.') {
            if (segment_start) return false;
            segment_start = true;
            continue;
        }
        if (segment_start) {
            if (byte < 'a' or byte > 'z') return false;
            segment_start = false;
            continue;
        }
        if (!((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_')) return false;
    }
    return !segment_start;
}
