const std = @import("std");
const canonical = @import("canonical_model");

const asset_directory = "assets/canonical_model/human_base";
const invalid_directory = "tests/fixtures/canonical_model/human_base/invalid";
const canonical_path = asset_directory ++ "/human_base.canonical.json";
const report_path = asset_directory ++ "/human_base.structural_report.txt";

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    try std.Io.Dir.cwd().createDirPath(init.io, asset_directory);
    try std.Io.Dir.cwd().createDirPath(init.io, invalid_directory);

    var diagnostic_storage: [1024]canonical.diagnostics.Diagnostic = undefined;
    var loaded = try canonical.human_base.loadAuthoritative(allocator, init.io, &diagnostic_storage);
    defer loaded.deinit();
    const source = loaded.definition();

    const canonical_bytes = try canonical.serialization.serializeAlloc(allocator, loaded.normalized());
    defer allocator.free(canonical_bytes);
    try writeFile(init.io, canonical_path, canonical_bytes);

    for (canonical.human_acceptance.invalid_fixture_specs) |spec| {
        try writeInvalidFixture(init.io, allocator, source, spec);
    }

    const structural_report = try canonical.human_evidence.generateAlloc(allocator, source);
    defer allocator.free(structural_report);
    try writeFile(init.io, report_path, structural_report);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(canonical_bytes, &digest, .{});
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    std.debug.print(
        "human_base canonical_bytes={d} final_byte=0x{x:0>2} trailing_newline={s} sha256={s} invalid_fixtures={d}\n",
        .{
            canonical_bytes.len,
            canonical_bytes[canonical_bytes.len - 1],
            if (canonical_bytes[canonical_bytes.len - 1] == '\n') "yes" else "no",
            &digest_hex,
            canonical.human_acceptance.invalid_fixture_specs.len,
        },
    );
}

fn writeInvalidFixture(
    io: std.Io,
    allocator: std.mem.Allocator,
    base_source: *const canonical.definition.CanonicalCreatureDefinition,
    spec: canonical.human_acceptance.FixtureSpec,
) !void {
    var path_buffer: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ invalid_directory, spec.file_name });
    var source = base_source.*;
    switch (spec.kind) {
        .missing_skeleton_root => {
            const records = try removeBoneAlloc(allocator, source.bones, "skeleton_root");
            defer allocator.free(records);
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .second_skeleton_root => {
            const records = try allocator.dupe(canonical.rig.Bone, source.bones);
            defer allocator.free(records);
            records[findBoneIndex(records, "head") orelse return error.MissingFixtureTarget].parent_bone_id = null;
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .wrong_pelvis_parent => {
            const records = try allocator.dupe(canonical.rig.Bone, source.bones);
            defer allocator.free(records);
            records[findBoneIndex(records, "pelvis") orelse return error.MissingFixtureTarget].parent_bone_id = try canonical.identity.BoneId.init("missing_pelvis_parent");
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .wrong_spine_count => {
            const records = try removeBoneAlloc(allocator, source.bones, "spine_07");
            defer allocator.free(records);
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .wrong_neck_count => {
            const records = try removeBoneAlloc(allocator, source.bones, "neck_03");
            defer allocator.free(records);
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .wrong_arm_twist_count => {
            const records = try removeBoneAlloc(allocator, source.bones, "upper_arm_twist_left_02");
            defer allocator.free(records);
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .wrong_leg_twist_count => {
            const records = try removeBoneAlloc(allocator, source.bones, "thigh_twist_left_02");
            defer allocator.free(records);
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .malformed_finger_chain => {
            const records = try allocator.dupe(canonical.rig.Bone, source.bones);
            defer allocator.free(records);
            records[findBoneIndex(records, "index_middle_left") orelse return error.MissingFixtureTarget].parent_bone_id = try canonical.identity.BoneId.init("hand_left");
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .malformed_toe_chain => {
            const records = try allocator.dupe(canonical.rig.Bone, source.bones);
            defer allocator.free(records);
            records[findBoneIndex(records, "toe_index_left_02") orelse return error.MissingFixtureTarget].parent_bone_id = try canonical.identity.BoneId.init("forefoot_left");
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .bilateral_mirror_mismatch => {
            const records = try allocator.dupe(canonical.rig.Bone, source.bones);
            defer allocator.free(records);
            records[findBoneIndex(records, "upper_arm_left") orelse return error.MissingFixtureTarget].local_rest_transform.translation_m.x += 0.01;
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .foot_contact_off_ground => {
            const records = try allocator.dupe(canonical.attachment.Anchor, source.anchors);
            defer allocator.free(records);
            records[findAnchorIndex(records, "heel_contact_left_anchor") orelse return error.MissingFixtureTarget].local_transform.translation_m.y += 0.01;
            records[findAnchorIndex(records, "heel_contact_right_anchor") orelse return error.MissingFixtureTarget].local_transform.translation_m.y += 0.01;
            source.anchors = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .canonical_height_mismatch => {
            const records = try allocator.dupe(canonical.rig.Bone, source.bones);
            defer allocator.free(records);
            records[findBoneIndex(records, "head") orelse return error.MissingFixtureTarget].local_rest_transform.translation_m.y += 0.01;
            source.bones = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .missing_required_landmark => {
            const records = try removeLandmarkAlloc(allocator, source.landmarks, "head_top_landmark");
            defer allocator.free(records);
            source.landmarks = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .missing_required_seam => {
            const records = try removeSeamAlloc(allocator, source.shared_seams, "torso_pelvis_seam");
            defer allocator.free(records);
            source.shared_seams = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .socket_missing_anchor => {
            const records = try allocator.dupe(canonical.attachment.Socket, source.sockets);
            defer allocator.free(records);
            records[findSocketIndex(records, "hair_socket") orelse return error.MissingFixtureTarget].anchor_id = try canonical.identity.AnchorId.init("missing_hair_anchor");
            source.sockets = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .interaction_site_missing_owner => {
            const records = try allocator.dupe(canonical.semantics.InteractionSite, source.interaction_sites);
            defer allocator.free(records);
            records[findSiteIndex(records, "palm_left_site") orelse return error.MissingFixtureTarget].owner_component_id = try canonical.identity.ComponentId.init("missing_site_owner");
            source.interaction_sites = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
        .invalid_optional_module_multiplicity => {
            const records = try allocator.dupe(canonical.component.Component, source.components);
            defer allocator.free(records);
            records[findComponentIndex(records, "penis_module_01") orelse return error.MissingFixtureTarget].multiplicity.maximum = 2;
            source.components = records;
            try writeReadableDefinition(io, allocator, path, &source);
        },
    }
}

fn writeReadableDefinition(
    io: std.Io,
    allocator: std.mem.Allocator,
    path: []const u8,
    source: *const canonical.definition.CanonicalCreatureDefinition,
) !void {
    const serialized = try canonical.serialization.serializeAlloc(allocator, .{
        .source = source,
        .coordinate_contract = source.coordinate_contract.?,
    });
    defer allocator.free(serialized);
    const readable = try prettyJsonAlloc(allocator, serialized);
    defer allocator.free(readable);
    try writeFile(io, path, readable);
}

fn prettyJsonAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    var indent: usize = 0;
    var in_string = false;
    var escaped = false;
    var index: usize = 0;
    while (index < input.len) : (index += 1) {
        const byte = input[index];
        if (in_string) {
            try output.append(allocator, byte);
            if (escaped) {
                escaped = false;
            } else if (byte == '\\') {
                escaped = true;
            } else if (byte == '"') {
                in_string = false;
            }
            continue;
        }
        if (byte == '"') {
            in_string = true;
            try output.append(allocator, byte);
            continue;
        }
        switch (byte) {
            '{', '[' => {
                try output.append(allocator, byte);
                const closing: u8 = if (byte == '{') '}' else ']';
                if (index + 1 < input.len and input[index + 1] == closing) {
                    index += 1;
                    try output.append(allocator, closing);
                } else {
                    indent += 1;
                    try appendNewlineAndIndent(allocator, &output, indent);
                }
            },
            '}', ']' => {
                indent -= 1;
                try appendNewlineAndIndent(allocator, &output, indent);
                try output.append(allocator, byte);
            },
            ',' => {
                try output.append(allocator, byte);
                try appendNewlineAndIndent(allocator, &output, indent);
            },
            ':' => try output.appendSlice(allocator, ": "),
            else => try output.append(allocator, byte),
        }
    }
    return output.toOwnedSlice(allocator);
}

fn appendNewlineAndIndent(allocator: std.mem.Allocator, output: *std.ArrayList(u8), indent: usize) !void {
    try output.append(allocator, '\n');
    for (0..indent * 2) |_| try output.append(allocator, ' ');
}

fn removeBoneAlloc(allocator: std.mem.Allocator, records: []const canonical.rig.Bone, id: []const u8) ![]canonical.rig.Bone {
    const output = try allocator.alloc(canonical.rig.Bone, records.len - 1);
    errdefer allocator.free(output);
    var index: usize = 0;
    for (records) |record| {
        if (std.mem.eql(u8, record.bone_id.value.bytes, id)) continue;
        if (index == output.len) return error.DuplicateFixtureTarget;
        output[index] = record;
        index += 1;
    }
    if (index != output.len) return error.MissingFixtureTarget;
    return output;
}

fn removeLandmarkAlloc(allocator: std.mem.Allocator, records: []const canonical.semantics.Landmark, id: []const u8) ![]canonical.semantics.Landmark {
    const output = try allocator.alloc(canonical.semantics.Landmark, records.len - 1);
    errdefer allocator.free(output);
    var index: usize = 0;
    for (records) |record| {
        if (std.mem.eql(u8, record.landmark_id.value.bytes, id)) continue;
        if (index == output.len) return error.DuplicateFixtureTarget;
        output[index] = record;
        index += 1;
    }
    if (index != output.len) return error.MissingFixtureTarget;
    return output;
}

fn removeSeamAlloc(allocator: std.mem.Allocator, records: []const canonical.semantics.SharedSeam, id: []const u8) ![]canonical.semantics.SharedSeam {
    const output = try allocator.alloc(canonical.semantics.SharedSeam, records.len - 1);
    errdefer allocator.free(output);
    var index: usize = 0;
    for (records) |record| {
        if (std.mem.eql(u8, record.seam_id.value.bytes, id)) continue;
        if (index == output.len) return error.DuplicateFixtureTarget;
        output[index] = record;
        index += 1;
    }
    if (index != output.len) return error.MissingFixtureTarget;
    return output;
}

fn findBoneIndex(records: []const canonical.rig.Bone, id: []const u8) ?usize {
    for (records, 0..) |record, index| if (std.mem.eql(u8, record.bone_id.value.bytes, id)) return index;
    return null;
}

fn findAnchorIndex(records: []const canonical.attachment.Anchor, id: []const u8) ?usize {
    for (records, 0..) |record, index| if (std.mem.eql(u8, record.anchor_id.value.bytes, id)) return index;
    return null;
}

fn findSocketIndex(records: []const canonical.attachment.Socket, id: []const u8) ?usize {
    for (records, 0..) |record, index| if (std.mem.eql(u8, record.socket_id.value.bytes, id)) return index;
    return null;
}

fn findSiteIndex(records: []const canonical.semantics.InteractionSite, id: []const u8) ?usize {
    for (records, 0..) |record, index| if (std.mem.eql(u8, record.site_id.value.bytes, id)) return index;
    return null;
}

fn findComponentIndex(records: []const canonical.component.Component, id: []const u8) ?usize {
    for (records, 0..) |record, index| if (std.mem.eql(u8, record.component_id.value.bytes, id)) return index;
    return null;
}

fn writeFile(io: std.Io, path: []const u8, bytes: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}
