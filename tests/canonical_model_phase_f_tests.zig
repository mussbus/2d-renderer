const std = @import("std");
const canonical = @import("canonical_model");

const definition = canonical.definition;
const diagnostics = canonical.diagnostics;
const hashing = canonical.hashing;
const identity = canonical.identity;
const material = canonical.material;
const math3d = canonical.math3d;
const morphology = canonical.morphology;
const normalization = canonical.normalization;
const parsing = canonical.parsing;
const serialization = canonical.serialization;
const trace = canonical.trace;
const validation = canonical.validation;

const valid_authoring_json = @embedFile("fixtures/canonical_model/minimal_valid_authoring.json");
const equivalent_authoring_json = @embedFile("fixtures/canonical_model/valid/minimal_valid_equivalent_authoring.json");
const canonical_golden_json = @embedFile("fixtures/canonical_model/valid/minimal_valid_canonical.json");
const invalid_duplicate_id_json = @embedFile("fixtures/canonical_model/invalid/duplicate_id.json");
const invalid_missing_parent_json = @embedFile("fixtures/canonical_model/invalid/missing_parent_reference.json");
const invalid_component_cycle_json = @embedFile("fixtures/canonical_model/invalid/component_cycle.json");
const invalid_skeleton_cycle_json = @embedFile("fixtures/canonical_model/invalid/skeleton_cycle.json");
const invalid_joint_range_json = @embedFile("fixtures/canonical_model/invalid/invalid_joint_range.json");
const invalid_non_finite_json = @embedFile("fixtures/canonical_model/invalid/non_finite_numeric.json");
const invalid_coverage_json = @embedFile("fixtures/canonical_model/invalid/coverage_out_of_range.json");
const invalid_dependency_cycle_json = @embedFile("fixtures/canonical_model/invalid/morphology_dependency_cycle.json");
const invalid_writer_conflict_json = @embedFile("fixtures/canonical_model/invalid/authoritative_writer_conflict.json");
const invalid_socket_mount_json = @embedFile("fixtures/canonical_model/invalid/invalid_socket_anchor_mount.json");
const invalid_semantic_owner_json = @embedFile("fixtures/canonical_model/invalid/missing_semantic_owner.json");
const invalid_wrong_reference_type_json = @embedFile("fixtures/canonical_model/invalid/wrong_reference_type.json");
const valid_fixture_sha256 = "b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d";

const offset_operations = [_]morphology.BindingOperation{.offset};
const scale_operations = [_]morphology.BindingOperation{.scale};
const set_operations = [_]morphology.BindingOperation{.set};
const binding_property_rules = [_]morphology.BindingPropertyRule{
    .{
        .target_type = .anchor_transform,
        .property_id = literalId(identity.PropertyId, "position_y"),
        .allowed_operations = &offset_operations,
    },
    .{
        .target_type = .rest_bone_transform,
        .property_id = literalId(identity.PropertyId, "translation_y"),
        .allowed_operations = &offset_operations,
    },
    .{
        .target_type = .rest_bone_transform,
        .property_id = literalId(identity.PropertyId, "scale_x"),
        .allowed_operations = &scale_operations,
    },
    .{
        .target_type = .material_parameter,
        .property_id = literalId(identity.PropertyId, "roughness"),
        .allowed_operations = &set_operations,
    },
};

const validation_context = validation.ValidationContext{
    .binding_schema = .{ .property_rules = &binding_property_rules },
};

test "minimal proof fixture exercises every required M01 Phase F concept" {
    var first_parse = try parsing.parse(std.testing.allocator, valid_authoring_json);
    defer first_parse.deinit();

    const source = &first_parse.value;
    try std.testing.expect(source.coordinate_contract == null);
    try std.testing.expectEqual(@as(usize, 4), source.components.len);
    try std.testing.expectEqual(@as(usize, 4), source.bones.len);
    try std.testing.expectEqual(@as(usize, 1), source.joints.len);
    try std.testing.expectEqual(@as(usize, 1), source.controls.len);
    try std.testing.expectEqual(@as(usize, 2), source.anchors.len);
    try std.testing.expectEqual(@as(usize, 1), source.sockets.len);
    try std.testing.expectEqual(@as(usize, 1), source.mount_anchors.len);
    try std.testing.expectEqual(@as(usize, 1), source.attachments.len);
    try std.testing.expectEqual(@as(usize, 2), source.regions.len);
    try std.testing.expectEqual(@as(usize, 2), source.surfaces.len);
    try std.testing.expectEqual(@as(usize, 1), source.landmarks.len);
    try std.testing.expectEqual(@as(usize, 1), source.shared_seams.len);
    try std.testing.expectEqual(@as(usize, 1), source.interaction_sites.len);
    try std.testing.expectEqual(@as(usize, 1), source.effectors.len);
    try std.testing.expectEqual(@as(usize, 4), source.morphology_parameters.len);
    try std.testing.expectEqual(@as(usize, 4), source.morphology_bindings.len);
    try std.testing.expectEqual(@as(usize, 2), source.morphology_graph.dependencies.len);
    try std.testing.expectEqual(@as(usize, 1), source.morphology_graph.provenance.len);
    try std.testing.expectEqual(@as(usize, 1), source.material_definitions.len);
    try std.testing.expectEqual(@as(usize, 1), source.material_instances.len);
    try std.testing.expectEqual(@as(usize, 1), source.visibility_metadata.len);

    const body_height_index = try indexById(source.morphology_parameters, "parameter_id", "body_height");
    try std.testing.expectEqual(
        @as(usize, 2),
        source.morphology_parameters[body_height_index].binding_ids.len,
    );

    var first_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const first_normalization = try normalization.normalize(
        &first_parse.value,
        validation_context,
        &first_diagnostics,
    );
    try std.testing.expect(first_normalization.isValid());
    try std.testing.expectEqual(canonical.coordinate.canonical, first_normalization.normalized.?.coordinate_contract);

    var first_bytes_buffer: [64 * 1024]u8 = undefined;
    const first_hash = try hashing.hashNormalized(
        first_normalization.normalized.?,
        &first_bytes_buffer,
    );

    const hash_hex = first_hash.source_definition_hash.toHex();
    try std.testing.expectEqualStrings(valid_fixture_sha256, &hash_hex);
    try std.testing.expectEqual(@as(usize, 12_022), first_hash.canonical_bytes.len);
    try std.testing.expectEqualStrings(canonical_golden_json, first_hash.canonical_bytes);
    try std.testing.expectEqual(@as(usize, 12_022), canonical_golden_json.len);
    try std.testing.expect(std.mem.indexOf(u8, first_hash.canonical_bytes, "\"coordinate_contract\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, first_hash.canonical_bytes, "\"component_id\":\"body\"") != null);
    try std.testing.expect(first_hash.canonical_bytes[first_hash.canonical_bytes.len - 1] == '}');
    try std.testing.expect(std.mem.indexOfAny(u8, first_hash.canonical_bytes, "\t\r\n") == null);
    try std.testing.expect(std.mem.indexOf(u8, first_hash.canonical_bytes, "\": ") == null);
    try std.testing.expect(std.mem.indexOf(u8, first_hash.canonical_bytes, ", ") == null);
    try std.testing.expect(std.mem.indexOf(u8, first_hash.canonical_bytes, "{ ") == null);
    try std.testing.expect(std.mem.indexOf(u8, first_hash.canonical_bytes, "[ ") == null);
    std.debug.print(
        "m01_p2d_valid_fixture bytes={d} sha256={s}\n",
        .{ first_hash.canonical_bytes.len, hash_hex },
    );
}

test "committed canonical golden parses normalizes and round trips exactly" {
    var first_parse = try parsing.parse(std.testing.allocator, valid_authoring_json);
    defer first_parse.deinit();
    var first_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const first_normalization = try normalizeSource(&first_parse.value, &first_diagnostics);
    try std.testing.expect(first_normalization.isValid());

    var first_bytes_buffer: [64 * 1024]u8 = undefined;
    const first_hash = try hashing.hashNormalized(first_normalization.normalized.?, &first_bytes_buffer);

    var second_parse = try parsing.parse(std.testing.allocator, canonical_golden_json);
    defer second_parse.deinit();
    var second_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const second_normalization = try normalization.normalize(
        &second_parse.value,
        validation_context,
        &second_diagnostics,
    );
    try std.testing.expect(second_normalization.isValid());

    var second_bytes_buffer: [64 * 1024]u8 = undefined;
    const second_hash = try hashing.hashNormalized(second_normalization.normalized.?, &second_bytes_buffer);
    try std.testing.expectEqualStrings(canonical_golden_json, second_hash.canonical_bytes);
    try std.testing.expectEqualStrings(first_hash.canonical_bytes, second_hash.canonical_bytes);
    try std.testing.expect(first_hash.source_definition_hash.eql(second_hash.source_definition_hash));
}

test "file-backed explicit defaults and reordered collections share canonical identity" {
    var authored_parse = try parsing.parse(std.testing.allocator, valid_authoring_json);
    defer authored_parse.deinit();
    var authored_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const authored_normalization = try normalizeSource(&authored_parse.value, &authored_diagnostics);
    try std.testing.expect(authored_normalization.isValid());

    var authored_buffer: [64 * 1024]u8 = undefined;
    const authored_hash = try hashing.hashNormalized(authored_normalization.normalized.?, &authored_buffer);

    try std.testing.expect(std.mem.indexOfAny(u8, valid_authoring_json, " \t\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, valid_authoring_json, "\"coordinate_contract\"") == null);
    try std.testing.expect(
        std.mem.indexOf(u8, valid_authoring_json, "\"component_id\": \"pelvis\"").? <
            std.mem.indexOf(u8, valid_authoring_json, "\"component_id\": \"body\"").? and
            std.mem.indexOf(u8, authored_hash.canonical_bytes, "\"component_id\":\"body\"").? <
                std.mem.indexOf(u8, authored_hash.canonical_bytes, "\"component_id\":\"pelvis\"").?,
    );

    var canonical_parse = try parsing.parse(std.testing.allocator, equivalent_authoring_json);
    defer canonical_parse.deinit();
    try std.testing.expect(canonical_parse.value.coordinate_contract != null);
    try std.testing.expect(std.mem.indexOf(u8, equivalent_authoring_json, "\"coordinate_contract\"") != null);
    var canonical_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const canonical_normalization = try normalizeSource(&canonical_parse.value, &canonical_diagnostics);
    try std.testing.expect(canonical_normalization.isValid());

    var canonical_buffer: [64 * 1024]u8 = undefined;
    const canonical_hash = try hashing.hashNormalized(canonical_normalization.normalized.?, &canonical_buffer);
    try std.testing.expectEqualStrings(authored_hash.canonical_bytes, canonical_hash.canonical_bytes);
    try std.testing.expect(authored_hash.source_definition_hash.eql(canonical_hash.source_definition_hash));
}

test "repeat canonical generation is byte and hash identical" {
    var expected_bytes: [64 * 1024]u8 = undefined;
    var expected_length: usize = 0;
    var expected_hash: ?hashing.SourceDefinitionHash = null;

    for (0..5) |_| {
        var parsed = try parsing.parse(std.testing.allocator, valid_authoring_json);
        defer parsed.deinit();
        var diagnostic_storage: [64]diagnostics.Diagnostic = undefined;
        const normalized = try normalizeSource(&parsed.value, &diagnostic_storage);
        try std.testing.expect(normalized.isValid());
        var serialization_buffer: [64 * 1024]u8 = undefined;
        const generated = try hashing.hashNormalized(normalized.normalized.?, &serialization_buffer);
        if (expected_hash) |hash| {
            try std.testing.expectEqualStrings(expected_bytes[0..expected_length], generated.canonical_bytes);
            try std.testing.expect(hash.eql(generated.source_definition_hash));
        } else {
            @memcpy(expected_bytes[0..generated.canonical_bytes.len], generated.canonical_bytes);
            expected_length = generated.canonical_bytes.len;
            expected_hash = generated.source_definition_hash;
        }
    }

    try std.testing.expectEqualStrings(valid_fixture_sha256, &expected_hash.?.toHex());
}

test "material canonical-data mutation changes the source-definition hash" {
    var parsed = try parsing.parse(std.testing.allocator, valid_authoring_json);
    defer parsed.deinit();
    var original_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const original_normalization = try normalizeSource(&parsed.value, &original_diagnostics);
    try std.testing.expect(original_normalization.isValid());
    var original_buffer: [64 * 1024]u8 = undefined;
    const original_hash = try hashing.hashNormalized(original_normalization.normalized.?, &original_buffer);

    var mutated_source = parsed.value;
    const instances = try std.testing.allocator.dupe(material.MaterialInstance, parsed.value.material_instances);
    defer std.testing.allocator.free(instances);
    const properties = try std.testing.allocator.dupe(material.MaterialProperty, instances[0].properties);
    defer std.testing.allocator.free(properties);
    instances[0].properties = properties;
    mutated_source.material_instances = instances;

    const color_index = try indexById(properties, "property_id", "base_color");
    switch (properties[color_index].value) {
        .linear_srgb_rgba => |color| {
            var mutated_color = color;
            mutated_color.channels[0] = 0.26;
            properties[color_index].value = .{ .linear_srgb_rgba = mutated_color };
        },
        else => return error.UnexpectedProofFixtureMaterialValue,
    }

    var mutated_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const mutated_normalization = try normalizeSource(&mutated_source, &mutated_diagnostics);
    try std.testing.expect(mutated_normalization.isValid());
    var mutated_buffer: [64 * 1024]u8 = undefined;
    const mutated_hash = try hashing.hashNormalized(mutated_normalization.normalized.?, &mutated_buffer);
    try std.testing.expect(!original_hash.source_definition_hash.eql(mutated_hash.source_definition_hash));
    try std.testing.expect(!std.mem.eql(u8, original_hash.canonical_bytes, mutated_hash.canonical_bytes));
}

test "local-only skeleton source derives reproducible fixture global transforms" {
    var parsed = try parsing.parse(std.testing.allocator, valid_authoring_json);
    defer parsed.deinit();
    var diagnostic_storage: [64]diagnostics.Diagnostic = undefined;
    const normalized = try normalizeSource(&parsed.value, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());

    const expected = [_]struct { id: []const u8, global_y_m: f32 }{
        .{ .id = "skeleton_root", .global_y_m = 0.0 },
        .{ .id = "pelvis", .global_y_m = 0.8 },
        .{ .id = "spine_01", .global_y_m = 1.2 },
        .{ .id = "head", .global_y_m = 1.5 },
    };
    for (expected) |entry| {
        const first = (try deriveGlobalAffine(&parsed.value, entry.id, 0)).translation_m.y;
        const second = (try deriveGlobalAffine(&parsed.value, entry.id, 0)).translation_m.y;
        try std.testing.expectEqual(entry.global_y_m, first);
        try std.testing.expectEqual(first, second);
    }

    var canonical_buffer: [64 * 1024]u8 = undefined;
    const canonical_bytes = try serialization.serialize(normalized.normalized.?, &canonical_buffer);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "\"local_rest_transform\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "global_transform") == null);
    try std.testing.expect(std.mem.indexOf(u8, canonical_bytes, "world_transform") == null);
    std.debug.print("m01_p2d_global_y skeleton_root=0 pelvis=0.8 spine_01=1.2 head=1.5\n", .{});
}

test "nontrivial local TRS hierarchy composes as deterministic parent times local affine" {
    const sqrt_half: f32 = 0.70710677;
    const sin_pi_over_eight: f32 = 0.38268343;
    const cos_pi_over_eight: f32 = 0.9238795;
    const parent_rotation = try math3d.Quaternion.initCanonical(0, 0, sqrt_half, sqrt_half);
    const local_rotation = try math3d.Quaternion.initCanonical(0, 0, sin_pi_over_eight, cos_pi_over_eight);

    const parent = math3d.AffineTransform.fromLocal(.{
        .translation_m = .{ .x = 10, .y = 20, .z = 30 },
        .rotation = parent_rotation,
        .scale = .{ .x = 2, .y = 3, .z = 4 },
    });
    const local = math3d.AffineTransform.fromLocal(.{
        .translation_m = .{ .x = 1, .y = 2, .z = 3 },
        .rotation = local_rotation,
        .scale = .{ .x = 0.5, .y = 2, .z = 1.5 },
    });
    const point = math3d.Vec3{ .x = 0.25, .y = -0.5, .z = 2 };

    const global = math3d.AffineTransform.compose(parent, local);
    const repeated = math3d.AffineTransform.compose(parent, local);
    const composed_point = global.transformPoint(point);
    const sequential_point = parent.transformPoint(local.transformPoint(point));

    // This tolerance covers f32 rounding from canonical quaternion normalization and
    // the two affine multiplication layers while remaining below authoring precision.
    const tolerance: f32 = 2e-5;
    try expectVec3Approx(sequential_point, composed_point, tolerance);
    try expectVec3Approx(.{ .x = 5.8561554, .y = 23.59099, .z = 54 }, composed_point, tolerance);
    try std.testing.expect(std.meta.eql(global, repeated));

    const active_x = parent_rotation.rotateVector(.{ .x = 1, .y = 0, .z = 0 });
    try expectVec3Approx(.{ .x = 0, .y = 1, .z = 0 }, active_x, tolerance);

    const composed_rotation = try math3d.Quaternion.compose(parent_rotation, local_rotation);
    const composed_rotated_x = composed_rotation.rotateVector(.{ .x = 1, .y = 0, .z = 0 });
    try expectVec3Approx(.{ .x = -sqrt_half, .y = sqrt_half, .z = 0 }, composed_rotated_x, tolerance);

    const shear_dot = global.x_axis.x * global.y_axis.x +
        global.x_axis.y * global.y_axis.y +
        global.x_axis.z * global.y_axis.z;
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), shear_dot, tolerance);
    std.debug.print(
        "m01_p2d_affine point=({d:.7},{d:.7},{d:.7}) shear_dot={d:.7}\n",
        .{ composed_point.x, composed_point.y, composed_point.z, shear_dot },
    );
}

test "morphology binding dependency and provenance trace is deterministic" {
    var parsed = try parsing.parse(std.testing.allocator, valid_authoring_json);
    defer parsed.deinit();
    var diagnostic_storage: [64]diagnostics.Diagnostic = undefined;
    const normalized = try normalizeSource(&parsed.value, &diagnostic_storage);
    try std.testing.expect(normalized.isValid());

    var order_storage: [2]identity.MorphologyDependencyId = undefined;
    const order = try trace.deterministicDependencyOrder(&parsed.value, &order_storage);
    try std.testing.expectEqualStrings("group_drives_height", order[0].value.bytes);
    try std.testing.expectEqualStrings("derive_surface_roughness", order[1].value.bytes);

    const binding_index = try indexById(parsed.value.morphology_bindings, "binding_id", "body_height_bone_binding");
    const target = parsed.value.morphology_bindings[binding_index].target;
    const writer = (try trace.authoritativeWriter(&parsed.value, target)).?;
    try std.testing.expectEqualStrings("body_height_bone_binding", writer.value.bytes);
    var driver_storage: [4]identity.MorphologyBindingId = undefined;
    const drivers = try trace.collectTargetDrivers(&parsed.value, target, &driver_storage);
    try std.testing.expectEqual(@as(usize, 1), drivers.len);

    var derived_input_storage: [2]identity.MorphologyParameterId = undefined;
    const derived_inputs = (try trace.collectDerivedInputs(
        &parsed.value,
        literalId(identity.MorphologyParameterId, "surface_roughness"),
        &derived_input_storage,
    )).?;
    try std.testing.expectEqual(@as(usize, 2), derived_inputs.len);
    try std.testing.expectEqualStrings("body_height", derived_inputs[0].value.bytes);
    try std.testing.expectEqualStrings("head_width", derived_inputs[1].value.bytes);
    try std.testing.expectEqual(@as(usize, 5), parsed.value.morphology_graph.provenance[0].sources.len);
    std.debug.print(
        "m01_p2d_trace group_drives_height->derive_surface_roughness writer=body_height_bone_binding\n",
        .{},
    );
}

test "file-backed invalid fixture duplicate ID is rejected without unrelated diagnostics" {
    try expectInvalidFixture(invalid_duplicate_id_json, .duplicate_id);
}

test "file-backed invalid fixture missing component parent is rejected and not repaired" {
    try expectInvalidFixture(invalid_missing_parent_json, .missing_reference);
}

test "file-backed invalid fixture component ownership cycle is rejected" {
    try expectInvalidFixture(invalid_component_cycle_json, .component_tree_cycle);
}

test "file-backed invalid fixture skeleton cycle is rejected" {
    try expectInvalidFixture(invalid_skeleton_cycle_json, .skeleton_cycle);
}

test "file-backed invalid fixture joint range ordering is rejected" {
    try expectInvalidFixture(invalid_joint_range_json, .invalid_joint_range);
}

test "file-backed invalid fixture non-finite numeric token is rejected by the parser" {
    try std.testing.expectError(
        error.InvalidNumber,
        parsing.parse(std.testing.allocator, invalid_non_finite_json),
    );
}

test "file-backed invalid fixture normalized coverage is rejected rather than clamped" {
    try expectInvalidFixture(invalid_coverage_json, .coverage_out_of_range);
}

test "file-backed invalid fixture morphology dependency cycle is rejected" {
    try expectInvalidFixture(invalid_dependency_cycle_json, .morphology_dependency_cycle);
}

test "file-backed invalid fixture conflicting authoritative morphology writers are rejected" {
    try expectInvalidFixture(invalid_writer_conflict_json, .multiple_authoritative_writers);
}

test "file-backed invalid fixture socket mount relationship is rejected" {
    try expectInvalidFixture(invalid_socket_mount_json, .attachment_missing_mount_anchor);
}

test "file-backed invalid fixture missing semantic owner is rejected" {
    try expectInvalidFixture(invalid_semantic_owner_json, .semantic_owner_missing);
}

test "file-backed invalid fixture wrong-type reference is rejected explicitly" {
    try expectInvalidFixture(invalid_wrong_reference_type_json, .wrong_reference_type);
}

test "file-backed invalid fixture diagnostics are identical across repeated parsing and validation" {
    var first_parse = try parsing.parse(std.testing.allocator, invalid_joint_range_json);
    defer first_parse.deinit();
    var second_parse = try parsing.parse(std.testing.allocator, invalid_joint_range_json);
    defer second_parse.deinit();

    var first_storage: [64]diagnostics.Diagnostic = undefined;
    var second_storage: [64]diagnostics.Diagnostic = undefined;
    const first = try normalizeSource(&first_parse.value, &first_storage);
    const second = try normalizeSource(&second_parse.value, &second_storage);
    try std.testing.expect(first.normalized == null);
    try std.testing.expect(second.normalized == null);
    try expectReportsEqual(first.report, second.report);
}

test "representative file-backed diagnostics identify exact source locations" {
    try expectSingleDiagnostic(invalid_missing_parent_json, .{
        .code = .missing_reference,
        .object_type = "component",
        .object_id = "torso",
        .property = "parent_component_id",
        .reference_type = "component",
        .reference_id = "missing_parent",
        .message = "reference does not resolve to an existing canonical object",
    });
    try expectSingleDiagnostic(invalid_coverage_json, .{
        .code = .coverage_out_of_range,
        .object_type = "visibility_metadata",
        .object_id = "invalid_coverage",
        .property = "coverage",
        .message = "coverage must be finite and within 0.0 through 1.0",
    });
    try expectSingleDiagnostic(invalid_writer_conflict_json, .{
        .code = .multiple_authoritative_writers,
        .object_type = "morphology_binding",
        .object_id = "root_height_b",
        .property = "target",
        .reference_type = "rest_bone_transform",
        .reference_id = "skeleton_root",
        .message = "low-level target property has more than one authoritative writer",
    });
}

const ExpectedDiagnostic = struct {
    code: diagnostics.Code,
    object_type: []const u8,
    object_id: ?[]const u8 = null,
    property: ?[]const u8 = null,
    reference_type: ?[]const u8 = null,
    reference_id: ?[]const u8 = null,
    message: []const u8,
};

fn literalId(comptime T: type, comptime bytes: []const u8) T {
    return .{ .value = .{ .bytes = bytes } };
}

fn containsCode(report: diagnostics.ValidationReport, code: diagnostics.Code) bool {
    for (report.diagnostics) |entry| {
        if (entry.code == code) return true;
    }
    return false;
}

fn expectOnlyCode(result: normalization.Result, code: diagnostics.Code) !void {
    try std.testing.expect(result.normalized == null);
    try std.testing.expect(!result.report.isValid());
    try std.testing.expect(containsCode(result.report, code));
    for (result.report.diagnostics) |entry| {
        try std.testing.expectEqual(code, entry.code);
    }
}

fn expectInvalidFixture(source_bytes: []const u8, code: diagnostics.Code) !void {
    var parsed = try parsing.parse(std.testing.allocator, source_bytes);
    defer parsed.deinit();
    var storage: [64]diagnostics.Diagnostic = undefined;
    const result = try normalizeSource(&parsed.value, &storage);
    try expectOnlyCode(result, code);
}

fn expectSingleDiagnostic(source_bytes: []const u8, expected: ExpectedDiagnostic) !void {
    var parsed = try parsing.parse(std.testing.allocator, source_bytes);
    defer parsed.deinit();
    var storage: [64]diagnostics.Diagnostic = undefined;
    const result = try normalizeSource(&parsed.value, &storage);
    try std.testing.expect(result.normalized == null);
    try std.testing.expectEqual(@as(usize, 1), result.report.diagnostics.len);
    const actual = result.report.diagnostics[0];
    try std.testing.expectEqual(expected.code, actual.code);
    try std.testing.expectEqualStrings(expected.object_type, actual.object_type);
    try expectOptionalStringEqual(expected.object_id, actual.object_id);
    try expectOptionalStringEqual(expected.property, actual.property);
    try expectOptionalStringEqual(expected.reference_type, actual.reference_type);
    try expectOptionalStringEqual(expected.reference_id, actual.reference_id);
    try std.testing.expectEqualStrings(expected.message, actual.message);
    std.debug.print(
        "m01_p3_diagnostic code={s} object={s} id={s} property={s} reference_type={s} reference_id={s}\n",
        .{
            @tagName(actual.code),
            actual.object_type,
            actual.object_id orelse "null",
            actual.property orelse "null",
            actual.reference_type orelse "null",
            actual.reference_id orelse "null",
        },
    );
}

fn indexById(items: anytype, comptime field_name: []const u8, expected_id: []const u8) !usize {
    for (items, 0..) |item, index| {
        if (std.mem.eql(u8, @field(item, field_name).value.bytes, expected_id)) return index;
    }
    return error.ProofFixtureRecordMissing;
}

fn deriveGlobalAffine(
    source: *const definition.CanonicalCreatureDefinition,
    bone_id: []const u8,
    depth: usize,
) !math3d.AffineTransform {
    if (depth >= source.bones.len) return error.ProofFixtureSkeletonCycle;
    const index = try indexById(source.bones, "bone_id", bone_id);
    const bone = source.bones[index];
    const local = math3d.AffineTransform.fromLocal(bone.local_rest_transform);
    const parent_id = bone.parent_bone_id orelse return local;
    const parent = try deriveGlobalAffine(source, parent_id.value.bytes, depth + 1);
    return math3d.AffineTransform.compose(parent, local);
}

fn expectVec3Approx(expected: math3d.Vec3, actual: math3d.Vec3, tolerance: f32) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, tolerance);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, tolerance);
    try std.testing.expectApproxEqAbs(expected.z, actual.z, tolerance);
}

fn expectReportsEqual(
    first: diagnostics.ValidationReport,
    second: diagnostics.ValidationReport,
) !void {
    try std.testing.expectEqual(first.error_count, second.error_count);
    try std.testing.expectEqual(first.warning_count, second.warning_count);
    try std.testing.expectEqual(first.info_count, second.info_count);
    try std.testing.expectEqual(first.diagnostics.len, second.diagnostics.len);
    for (first.diagnostics, second.diagnostics) |first_entry, second_entry| {
        try std.testing.expectEqual(first_entry.severity, second_entry.severity);
        try std.testing.expectEqual(first_entry.code, second_entry.code);
        try std.testing.expectEqual(first_entry.category, second_entry.category);
        try std.testing.expectEqualStrings(first_entry.object_type, second_entry.object_type);
        try expectOptionalStringEqual(first_entry.object_id, second_entry.object_id);
        try expectOptionalStringEqual(first_entry.property, second_entry.property);
        try expectOptionalStringEqual(first_entry.reference_type, second_entry.reference_type);
        try expectOptionalStringEqual(first_entry.reference_id, second_entry.reference_id);
        try std.testing.expectEqualStrings(first_entry.message, second_entry.message);
    }
}

fn expectOptionalStringEqual(first: ?[]const u8, second: ?[]const u8) !void {
    if (first) |first_value| {
        try std.testing.expect(second != null);
        try std.testing.expectEqualStrings(first_value, second.?);
    } else {
        try std.testing.expect(second == null);
    }
}

fn normalizeSource(
    source: *const definition.CanonicalCreatureDefinition,
    storage: []diagnostics.Diagnostic,
) !normalization.Result {
    return normalization.normalize(source, validation_context, storage);
}
