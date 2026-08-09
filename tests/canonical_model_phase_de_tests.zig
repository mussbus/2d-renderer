const std = @import("std");
const canonical = @import("canonical_model");

const attachment = canonical.attachment;
const component = canonical.component;
const definition = canonical.definition;
const diagnostics = canonical.diagnostics;
const hashing = canonical.hashing;
const identity = canonical.identity;
const material = canonical.material;
const math3d = canonical.math3d;
const morphology = canonical.morphology;
const normalization = canonical.normalization;
const rig = canonical.rig;
const semantics = canonical.semantics;
const serialization = canonical.serialization;
const trace = canonical.trace;
const validation = canonical.validation;
const visibility = canonical.visibility;

fn makeDefinition(
    components: []const component.Component,
    bones: []const rig.Bone,
) !definition.CanonicalCreatureDefinition {
    return .{
        .schema_identity = .{
            .schema_id = try identity.SchemaId.init("canonical_creature"),
            .version = .{ .major = 1, .minor = 0, .patch = 0 },
        },
        .asset_identity = .{
            .asset_id = try identity.AssetId.init("synthetic_creature"),
            .display_name = try identity.DisplayName.init("Synthetic Creature"),
            .version = .{ .major = 1, .minor = 2, .patch = 3 },
        },
        .compiler_identity = .{
            .compiler_id = try identity.CompilerId.init("canonical_compiler"),
            .version = .{ .major = 0, .minor = 1, .patch = 0 },
        },
        .components = components,
        .bones = bones,
    };
}

fn baseComponents(order_reversed: bool) ![2]component.Component {
    const body = component.Component{
        .component_id = try identity.ComponentId.init("body"),
        .display_name = try identity.DisplayName.init("Body"),
        .component_type = try identity.ComponentTypeId.init("body"),
        .parent_component_id = null,
        .semantic_tags = &.{},
        .requirement = .required,
        .default_state = .enabled,
        .multiplicity = .{ .minimum = 1, .maximum = 1 },
        .compatibility = .none,
    };
    const head = component.Component{
        .component_id = try identity.ComponentId.init("head"),
        .display_name = try identity.DisplayName.init("Head"),
        .component_type = try identity.ComponentTypeId.init("head"),
        .parent_component_id = body.component_id,
        .semantic_tags = &.{},
        .requirement = .required,
        .default_state = .enabled,
        .multiplicity = .{ .minimum = 1, .maximum = 1 },
        .compatibility = .none,
    };
    return if (order_reversed) .{ head, body } else .{ body, head };
}

fn baseBones(order_reversed: bool) ![2]rig.Bone {
    const root = rig.Bone{
        .bone_id = try identity.BoneId.init("skeleton_root"),
        .display_name = try identity.DisplayName.init("Skeleton Root"),
        .parent_bone_id = null,
        .deforms_mesh = false,
        .local_rest_transform = .identity,
        .semantic_tags = &.{},
        .mirror_bone_id = null,
        .display_length_m = null,
    };
    const head = rig.Bone{
        .bone_id = try identity.BoneId.init("head"),
        .display_name = try identity.DisplayName.init("Head"),
        .parent_bone_id = root.bone_id,
        .deforms_mesh = true,
        .local_rest_transform = .identity,
        .semantic_tags = &.{},
        .mirror_bone_id = null,
        .display_length_m = 0.25,
    };
    return if (order_reversed) .{ head, root } else .{ root, head };
}

fn containsCode(report: diagnostics.ValidationReport, code: diagnostics.Code) bool {
    for (report.diagnostics) |diagnostic| if (diagnostic.code == code) return true;
    return false;
}

test "normalization resolves defaults and stable-ID orders unordered collections" {
    var components_a = try baseComponents(false);
    const tags_a = [_]identity.SemanticTagId{
        try identity.SemanticTagId.init("z_tag"),
        try identity.SemanticTagId.init("a_tag"),
    };
    components_a[0].semantic_tags = &tags_a;
    const bones_a = try baseBones(false);
    var source_a = try makeDefinition(&components_a, &bones_a);
    source_a.coordinate_contract = null;

    var components_b = try baseComponents(true);
    const tags_b = [_]identity.SemanticTagId{
        try identity.SemanticTagId.init("a_tag"),
        try identity.SemanticTagId.init("z_tag"),
    };
    components_b[1].semantic_tags = &tags_b;
    const bones_b = try baseBones(true);
    var source_b = try makeDefinition(&components_b, &bones_b);
    source_b.coordinate_contract = canonical.coordinate.canonical;

    var diagnostic_storage_a: [64]diagnostics.Diagnostic = undefined;
    var diagnostic_storage_b: [64]diagnostics.Diagnostic = undefined;
    const result_a = try normalization.normalize(&source_a, .{}, &diagnostic_storage_a);
    const result_b = try normalization.normalize(&source_b, .{}, &diagnostic_storage_b);
    try std.testing.expect(result_a.isValid());
    try std.testing.expect(result_b.isValid());

    var bytes_a: [32768]u8 = undefined;
    var bytes_b: [32768]u8 = undefined;
    const canonical_a = try serialization.serialize(result_a.normalized.?, &bytes_a);
    const canonical_b = try serialization.serialize(result_b.normalized.?, &bytes_b);
    try std.testing.expectEqualStrings(canonical_a, canonical_b);
    try std.testing.expect(std.mem.indexOf(u8, canonical_a, "\"coordinate_contract\":{\"unit\":\"meter\"") != null);
    const body_index = std.mem.indexOf(u8, canonical_a, "\"component_id\":\"body\"").?;
    const head_index = std.mem.indexOf(u8, canonical_a, "\"component_id\":\"head\"").?;
    try std.testing.expect(body_index < head_index);
    try std.testing.expect(canonical_a[canonical_a.len - 1] == '}');
    try std.testing.expect(canonical_a[canonical_a.len - 1] != '\n');
}

test "authored response-curve point order remains semantic" {
    const components = try baseComponents(false);
    const bones = try baseBones(false);
    const points_a = [_]morphology.ResponseCurvePoint{
        .{ .input = 0, .output = 0 },
        .{ .input = 1, .output = 1 },
    };
    const points_b = [_]morphology.ResponseCurvePoint{
        .{ .input = 1, .output = 1 },
        .{ .input = 0, .output = 0 },
    };
    var parameters: [2]morphology.MorphologyParameter = undefined;
    for (&parameters, 0..) |*parameter, index| {
        parameter.* = .{
            .parameter_id = try identity.MorphologyParameterId.init("curve_parameter"),
            .display_name = try identity.DisplayName.init("Curve Parameter"),
            .category = .morphological,
            .unit = .normalized,
            .ranges = .{
                .default_value = .{ .float = 0.5 },
                .recommended = null,
                .hard = .{ .float = .{ .minimum = 0, .maximum = 1 } },
            },
            .response_curve = .{ .custom = .{ .authored_data = if (index == 0) &points_a else &points_b } },
            .symmetry = .centered,
            .topology_policy = .preserve_existing_topology,
            .binding_ids = &.{},
        };
    }
    var source_a = try makeDefinition(&components, &bones);
    source_a.morphology_parameters = parameters[0..1];
    var source_b = try makeDefinition(&components, &bones);
    source_b.morphology_parameters = parameters[1..2];
    var diagnostics_a: [64]diagnostics.Diagnostic = undefined;
    var diagnostics_b: [64]diagnostics.Diagnostic = undefined;
    const normalized_a = (try normalization.normalize(&source_a, .{}, &diagnostics_a)).normalized.?;
    const normalized_b = (try normalization.normalize(&source_b, .{}, &diagnostics_b)).normalized.?;
    var bytes_a: [32768]u8 = undefined;
    var bytes_b: [32768]u8 = undefined;
    const canonical_a = try serialization.serialize(normalized_a, &bytes_a);
    const canonical_b = try serialization.serialize(normalized_b, &bytes_b);
    try std.testing.expect(!std.mem.eql(u8, canonical_a, canonical_b));
}

test "f32 serialization is shortest round-tripping and normalizes negative zero" {
    const values = [_]f32{ 0.0, -0.0, 0.1, 1.2345678, 16777216.0, 1.0e-20 };
    for (values) |value| {
        var output: [64]u8 = undefined;
        const bytes = try serialization.serializeF32(value, &output);
        const parsed = try std.fmt.parseFloat(f32, bytes);
        const expected = math3d.normalizeZero(value);
        try std.testing.expectEqual(@as(u32, @bitCast(expected)), @as(u32, @bitCast(parsed)));
    }
    var tenth_buffer: [64]u8 = undefined;
    try std.testing.expectEqualStrings("0.1", try serialization.serializeF32(0.1, &tenth_buffer));
    var zero_buffer: [64]u8 = undefined;
    try std.testing.expectEqualStrings("0", try serialization.serializeF32(-0.0, &zero_buffer));
    var invalid_buffer: [64]u8 = undefined;
    try std.testing.expectError(error.NonFiniteFloat, serialization.serializeF32(std.math.inf(f32), &invalid_buffer));
}

test "quaternion signs and collection order share canonical bytes and source hash" {
    const components_a = try baseComponents(false);
    var bones_a = try baseBones(false);
    const half_sqrt_two: f32 = @sqrt(0.5);
    bones_a[1].local_rest_transform.rotation = .{
        .x = -0.0,
        .y = 0.0,
        .z = half_sqrt_two,
        .w = half_sqrt_two,
    };
    var source_a = try makeDefinition(&components_a, &bones_a);

    const components_b = try baseComponents(true);
    var bones_b = try baseBones(true);
    bones_b[0].local_rest_transform.rotation = .{
        .x = 0.0,
        .y = -0.0,
        .z = -half_sqrt_two,
        .w = -half_sqrt_two,
    };
    var source_b = try makeDefinition(&components_b, &bones_b);

    var diagnostics_a: [64]diagnostics.Diagnostic = undefined;
    var diagnostics_b: [64]diagnostics.Diagnostic = undefined;
    const normalized_a = (try normalization.normalize(&source_a, .{}, &diagnostics_a)).normalized.?;
    const normalized_b = (try normalization.normalize(&source_b, .{}, &diagnostics_b)).normalized.?;
    var bytes_a: [32768]u8 = undefined;
    var bytes_b: [32768]u8 = undefined;
    const hash_a = try hashing.hashNormalized(normalized_a, &bytes_a);
    const hash_b = try hashing.hashNormalized(normalized_b, &bytes_b);
    try std.testing.expectEqualStrings(hash_a.canonical_bytes, hash_b.canonical_bytes);
    try std.testing.expect(hash_a.source_definition_hash.eql(hash_b.source_definition_hash));
    const hash_hex = hash_a.source_definition_hash.toHex();
    try std.testing.expectEqualStrings("2855fc11c0f8a1e5698af253c1a89eeb07483e5879556094ea4b6f29149b784b", &hash_hex);
    std.debug.print("m01_p2c_source_definition_sha256={s}\n", .{hash_hex});

    source_b.asset_identity.display_name = try identity.DisplayName.init("Changed Display Name");
    var changed_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const changed = (try normalization.normalize(&source_b, .{}, &changed_diagnostics)).normalized.?;
    var changed_bytes: [32768]u8 = undefined;
    const changed_hash = try hashing.hashNormalized(changed, &changed_bytes);
    try std.testing.expect(!hash_a.source_definition_hash.eql(changed_hash.source_definition_hash));
}

test "nontrivial canonical quaternion remains byte-identical after JSON round trip" {
    const components = try baseComponents(false);
    var bones = try baseBones(false);
    bones[1].local_rest_transform.rotation = .{
        .x = 0.18257418,
        .y = -0.36514837,
        .z = 0.5477226,
        .w = 0.73029673,
    };
    var source = try makeDefinition(&components, &bones);

    var first_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const first_normalized = (try normalization.normalize(
        &source,
        .{},
        &first_diagnostics,
    )).normalized.?;
    var first_buffer: [32768]u8 = undefined;
    const first_bytes = try serialization.serialize(first_normalized, &first_buffer);

    var parsed = try canonical.parsing.parse(std.testing.allocator, first_bytes);
    defer parsed.deinit();
    var second_diagnostics: [64]diagnostics.Diagnostic = undefined;
    const second_normalized = (try normalization.normalize(
        &parsed.value,
        .{},
        &second_diagnostics,
    )).normalized.?;
    var second_buffer: [32768]u8 = undefined;
    const second_bytes = try serialization.serialize(second_normalized, &second_buffer);

    try std.testing.expectEqualStrings(first_bytes, second_bytes);
}

test "invalid quaternion is diagnosed and never normalized or hashed" {
    const components = try baseComponents(false);
    var bones = try baseBones(false);
    bones[1].local_rest_transform.rotation = .{ .x = 0, .y = 0, .z = 0, .w = 1.01 };
    var source = try makeDefinition(&components, &bones);
    const original_w = source.bones[1].local_rest_transform.rotation.w;
    var diagnostic_storage: [64]diagnostics.Diagnostic = undefined;
    const result = try normalization.normalize(&source, .{}, &diagnostic_storage);
    try std.testing.expect(!result.isValid());
    try std.testing.expect(result.normalized == null);
    try std.testing.expect(containsCode(result.report, .malformed_quaternion));
    try std.testing.expectEqual(original_w, source.bones[1].local_rest_transform.rotation.w);
}

test "identity reference root parent and tree-cycle diagnostics are structured" {
    const body_id = try identity.ComponentId.init("body");
    const head_id = try identity.ComponentId.init("head");
    const components = [_]component.Component{
        .{
            .component_id = body_id,
            .display_name = null,
            .component_type = try identity.ComponentTypeId.init("body"),
            .parent_component_id = head_id,
            .semantic_tags = &.{},
            .requirement = .required,
            .default_state = .enabled,
            .multiplicity = .{ .minimum = 2, .maximum = 1 },
            .compatibility = .none,
        },
        .{
            .component_id = head_id,
            .display_name = null,
            .component_type = try identity.ComponentTypeId.init("head"),
            .parent_component_id = body_id,
            .semantic_tags = &.{},
            .requirement = .required,
            .default_state = .enabled,
            .multiplicity = .{ .minimum = 1, .maximum = 1 },
            .compatibility = .none,
        },
        .{
            .component_id = head_id,
            .display_name = null,
            .component_type = try identity.ComponentTypeId.init("head"),
            .parent_component_id = try identity.ComponentId.init("skeleton_root"),
            .semantic_tags = &.{},
            .requirement = .required,
            .default_state = .enabled,
            .multiplicity = .{ .minimum = 1, .maximum = 1 },
            .compatibility = .none,
        },
    };
    const bones = try baseBones(false);
    var source = try makeDefinition(&components, &bones);
    var diagnostic_storage: [128]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{}, &diagnostic_storage);
    try std.testing.expect(!report.isValid());
    try std.testing.expect(containsCode(report, .duplicate_id));
    try std.testing.expect(containsCode(report, .wrong_reference_type));
    try std.testing.expect(containsCode(report, .invalid_component_root_count));
    try std.testing.expect(containsCode(report, .component_tree_cycle));
    try std.testing.expect(containsCode(report, .multiplicity_contradiction));
    for (report.diagnostics) |diagnostic| {
        try std.testing.expect(diagnostic.message.len != 0);
        try std.testing.expect(diagnostic.object_type.len != 0);
    }
}

test "skeleton root and cycle validation is explicit" {
    const components = try baseComponents(false);
    const bone_a_id = try identity.BoneId.init("bone_a");
    const bone_b_id = try identity.BoneId.init("bone_b");
    const bones = [_]rig.Bone{
        .{
            .bone_id = bone_a_id,
            .display_name = null,
            .parent_bone_id = bone_b_id,
            .deforms_mesh = true,
            .local_rest_transform = .identity,
            .semantic_tags = &.{},
            .mirror_bone_id = null,
            .display_length_m = null,
        },
        .{
            .bone_id = bone_b_id,
            .display_name = null,
            .parent_bone_id = bone_a_id,
            .deforms_mesh = true,
            .local_rest_transform = .identity,
            .semantic_tags = &.{},
            .mirror_bone_id = null,
            .display_length_m = null,
        },
    };
    const source = try makeDefinition(&components, &bones);
    var diagnostic_storage: [64]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{}, &diagnostic_storage);
    try std.testing.expect(containsCode(report, .invalid_skeleton_root_count));
    try std.testing.expect(containsCode(report, .skeleton_cycle));
}

test "non-finite ranges defaults and joint ordering fail without repair" {
    const components = try baseComponents(false);
    var bones = try baseBones(false);
    bones[1].local_rest_transform.translation_m.x = std.math.nan(f32);
    const joint = rig.Joint{
        .joint_id = try identity.JointId.init("head_joint"),
        .display_name = null,
        .parent_bone_id = bones[1].parent_bone_id.?,
        .child_bone_id = bones[1].bone_id,
        .joint_type = .ball_and_socket,
        .preferred_range = .{ .x = null, .y = null, .z = null },
        .hard_range = .{
            .x = .{ .minimum_radians = 1.0, .maximum_radians = -1.0 },
            .y = null,
            .z = null,
        },
        .preferred_bend_direction = null,
        .swing_twist = null,
        .limit_behavior = .{ .stiffness = null },
        .mobility_profile_override = null,
    };
    const parameter = morphology.MorphologyParameter{
        .parameter_id = try identity.MorphologyParameterId.init("normalized_size"),
        .display_name = try identity.DisplayName.init("Normalized Size"),
        .category = .morphological,
        .unit = .normalized,
        .ranges = .{
            .default_value = .{ .float = 1.2 },
            .recommended = .{ .float = .{ .minimum = 0.2, .maximum = 1.1 } },
            .hard = .{ .float = .{ .minimum = 0.0, .maximum = 1.0 } },
        },
        .response_curve = .linear,
        .symmetry = .centered,
        .topology_policy = .preserve_existing_topology,
        .binding_ids = &.{},
    };
    var source = try makeDefinition(&components, &bones);
    source.joints = &.{joint};
    source.morphology_parameters = &.{parameter};
    var diagnostic_storage: [128]diagnostics.Diagnostic = undefined;
    const result = try normalization.normalize(&source, .{}, &diagnostic_storage);
    try std.testing.expect(result.normalized == null);
    try std.testing.expect(containsCode(result.report, .non_finite_value));
    try std.testing.expect(containsCode(result.report, .invalid_joint_range));
    try std.testing.expect(containsCode(result.report, .default_outside_hard_range));
    try std.testing.expect(containsCode(result.report, .invalid_normalized_range));
    try std.testing.expect(std.math.isNan(source.bones[1].local_rest_transform.translation_m.x));
    try std.testing.expectEqual(@as(f32, 1.2), source.morphology_parameters[0].ranges.default_value.float);
}

test "binding schema ownership conflicts and group low-level writes are diagnosed" {
    const components = try baseComponents(false);
    const bones = try baseBones(false);
    const group_id = try identity.MorphologyParameterId.init("overall_height");
    const low_id = try identity.MorphologyParameterId.init("target_height");
    const binding_a_id = try identity.MorphologyBindingId.init("height_binding_a");
    const binding_b_id = try identity.MorphologyBindingId.init("height_binding_b");
    const binding_ids = [_]identity.MorphologyBindingId{ binding_a_id, binding_b_id };
    const parameters = [_]morphology.MorphologyParameter{
        .{
            .parameter_id = group_id,
            .display_name = try identity.DisplayName.init("Overall Height"),
            .category = .group,
            .unit = .normalized,
            .ranges = .{
                .default_value = .{ .float = 0.5 },
                .recommended = null,
                .hard = .{ .float = .{ .minimum = 0, .maximum = 1 } },
            },
            .response_curve = .linear,
            .symmetry = .centered,
            .topology_policy = .preserve_existing_topology,
            .binding_ids = &binding_ids,
        },
        .{
            .parameter_id = low_id,
            .display_name = try identity.DisplayName.init("Target Height"),
            .category = .structural,
            .unit = .meter,
            .ranges = .{
                .default_value = .{ .float = 1.0 },
                .recommended = null,
                .hard = .{ .float = .{ .minimum = 0.5, .maximum = 1.5 } },
            },
            .response_curve = .linear,
            .symmetry = .centered,
            .topology_policy = .preserve_existing_topology,
            .binding_ids = &.{},
        },
    };
    const property_id = try identity.PropertyId.init("translation_y");
    const bindings = [_]morphology.MorphologyBinding{
        .{
            .binding_id = binding_a_id,
            .source_parameter_id = group_id,
            .target = .{ .rest_bone_transform = .{ .target_id = bones[1].bone_id, .property_id = property_id } },
            .operation = .set,
            .writer_role = .authoritative,
            .resolution_stage = .rest_skeleton_and_anchors,
            .response_curve_override = null,
        },
        .{
            .binding_id = binding_b_id,
            .source_parameter_id = low_id,
            .target = .{ .rest_bone_transform = .{ .target_id = bones[1].bone_id, .property_id = property_id } },
            .operation = .scale,
            .writer_role = .authoritative,
            .resolution_stage = .rest_skeleton_and_anchors,
            .response_curve_override = null,
        },
    };
    const allowed_operations = [_]morphology.BindingOperation{.set};
    const rules = [_]morphology.BindingPropertyRule{.{
        .target_type = .rest_bone_transform,
        .property_id = property_id,
        .allowed_operations = &allowed_operations,
    }};
    var source = try makeDefinition(&components, &bones);
    source.morphology_parameters = &parameters;
    source.morphology_bindings = &bindings;
    var diagnostic_storage: [128]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{ .binding_schema = .{ .property_rules = &rules } }, &diagnostic_storage);
    try std.testing.expect(containsCode(report, .group_writes_low_level_target));
    try std.testing.expect(containsCode(report, .unsupported_target_operation));
    try std.testing.expect(containsCode(report, .multiple_authoritative_writers));
    try std.testing.expect(containsCode(report, .conflicting_binding_ownership));

    const unsupported_rules = [_]morphology.BindingPropertyRule{};
    var unsupported_storage: [128]diagnostics.Diagnostic = undefined;
    const unsupported_report = try validation.validate(&source, .{ .binding_schema = .{ .property_rules = &unsupported_rules } }, &unsupported_storage);
    try std.testing.expect(containsCode(unsupported_report, .unsupported_binding_target_property));
}

test "dependency order inputs writer and provenance traces are deterministic" {
    const components = try baseComponents(false);
    const bones = try baseBones(false);
    const input_a = try identity.MorphologyParameterId.init("input_a");
    const input_b = try identity.MorphologyParameterId.init("input_b");
    const middle = try identity.MorphologyParameterId.init("middle_value");
    const output = try identity.MorphologyParameterId.init("output_value");
    const parameter_ids = [_]identity.MorphologyParameterId{ input_a, input_b, middle, output };
    var parameters: [4]morphology.MorphologyParameter = undefined;
    for (&parameters, parameter_ids) |*parameter, parameter_id| {
        parameter.* = .{
            .parameter_id = parameter_id,
            .display_name = try identity.DisplayName.init(parameter_id.value.bytes),
            .category = .morphological,
            .unit = .normalized,
            .ranges = .{
                .default_value = .{ .float = 0.5 },
                .recommended = null,
                .hard = .{ .float = .{ .minimum = 0, .maximum = 1 } },
            },
            .response_curve = .linear,
            .symmetry = .centered,
            .topology_policy = .preserve_existing_topology,
            .binding_ids = &.{},
        };
    }
    const first_inputs = [_]identity.MorphologyParameterId{input_a};
    const second_inputs = [_]identity.MorphologyParameterId{ middle, input_b };
    const first_dependency_id = try identity.MorphologyDependencyId.init("z_first_dependency");
    const second_dependency_id = try identity.MorphologyDependencyId.init("a_second_dependency");
    const dependencies = [_]morphology.ParameterDependency{
        .{
            .dependency_id = second_dependency_id,
            .kind = .derived_value,
            .input_parameter_ids = &second_inputs,
            .output_parameter_id = output,
            .source_binding_ids = &.{},
            .resolution_stage = .structural_parameters,
        },
        .{
            .dependency_id = first_dependency_id,
            .kind = .derived_value,
            .input_parameter_ids = &first_inputs,
            .output_parameter_id = middle,
            .source_binding_ids = &.{},
            .resolution_stage = .structural_parameters,
        },
    };
    const provenance_sources = [_]morphology.ProvenanceSource{
        .{ .parameter = input_a },
        .{ .dependency = second_dependency_id },
    };
    const provenance_records = [_]morphology.ProvenanceTrace{.{
        .provenance_id = try identity.MorphologyProvenanceId.init("output_trace"),
        .output_parameter_id = output,
        .sources = &provenance_sources,
    }};
    var source = try makeDefinition(&components, &bones);
    source.morphology_parameters = &parameters;
    source.morphology_graph = .{ .dependencies = &dependencies, .provenance = &provenance_records };
    var diagnostic_storage: [128]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{}, &diagnostic_storage);
    try std.testing.expect(report.isValid());

    var order_storage: [2]identity.MorphologyDependencyId = undefined;
    const order = try trace.deterministicDependencyOrder(&source, &order_storage);
    try std.testing.expect(order[0].eql(first_dependency_id));
    try std.testing.expect(order[1].eql(second_dependency_id));
    var input_storage: [2]identity.MorphologyParameterId = undefined;
    const inputs = (try trace.collectDerivedInputs(&source, output, &input_storage)).?;
    try std.testing.expectEqual(@as(usize, 2), inputs.len);
    try std.testing.expect(inputs[0].eql(input_b));
    try std.testing.expect(inputs[1].eql(middle));

    const reordered_second_inputs = [_]identity.MorphologyParameterId{ input_b, middle };
    var reordered_dependencies = dependencies;
    reordered_dependencies[0].input_parameter_ids = &reordered_second_inputs;
    var reordered_source = source;
    reordered_source.morphology_graph.dependencies = &reordered_dependencies;
    var reordered_input_storage: [2]identity.MorphologyParameterId = undefined;
    const reordered_inputs = (try trace.collectDerivedInputs(
        &reordered_source,
        output,
        &reordered_input_storage,
    )).?;
    for (inputs, reordered_inputs) |input, reordered_input| {
        try std.testing.expect(input.eql(reordered_input));
    }

    const property_id = try identity.PropertyId.init("translation_y");
    const binding_id = try identity.MorphologyBindingId.init("authoritative_height_writer");
    const target = morphology.BindingTarget{ .rest_bone_transform = .{
        .target_id = bones[1].bone_id,
        .property_id = property_id,
    } };
    const binding_ids = [_]identity.MorphologyBindingId{binding_id};
    parameters[0].binding_ids = &binding_ids;
    const bindings = [_]morphology.MorphologyBinding{.{
        .binding_id = binding_id,
        .source_parameter_id = input_a,
        .target = target,
        .operation = .set,
        .writer_role = .authoritative,
        .resolution_stage = .rest_skeleton_and_anchors,
        .response_curve_override = null,
    }};
    source.morphology_bindings = &bindings;
    const writer = (try trace.authoritativeWriter(&source, target)).?;
    try std.testing.expect(writer.eql(binding_id));
    var driver_storage: [2]identity.MorphologyBindingId = undefined;
    const drivers = try trace.collectTargetDrivers(&source, target, &driver_storage);
    try std.testing.expectEqual(@as(usize, 1), drivers.len);
}

test "dependency cycles and unresolved derived inputs are rejected" {
    const components = try baseComponents(false);
    const bones = try baseBones(false);
    const parameter_a_id = try identity.MorphologyParameterId.init("parameter_a");
    const parameter_b_id = try identity.MorphologyParameterId.init("parameter_b");
    const parameters = [_]morphology.MorphologyParameter{
        .{
            .parameter_id = parameter_a_id,
            .display_name = try identity.DisplayName.init("Parameter A"),
            .category = .morphological,
            .unit = .normalized,
            .ranges = .{ .default_value = .{ .float = 0.5 }, .recommended = null, .hard = .{ .float = .{ .minimum = 0, .maximum = 1 } } },
            .response_curve = .linear,
            .symmetry = .centered,
            .topology_policy = .preserve_existing_topology,
            .binding_ids = &.{},
        },
        .{
            .parameter_id = parameter_b_id,
            .display_name = try identity.DisplayName.init("Parameter B"),
            .category = .morphological,
            .unit = .normalized,
            .ranges = .{ .default_value = .{ .float = 0.5 }, .recommended = null, .hard = .{ .float = .{ .minimum = 0, .maximum = 1 } } },
            .response_curve = .linear,
            .symmetry = .centered,
            .topology_policy = .preserve_existing_topology,
            .binding_ids = &.{},
        },
    };
    const missing_id = try identity.MorphologyParameterId.init("missing_input");
    const missing_binding_ids = [_]identity.MorphologyBindingId{try identity.MorphologyBindingId.init("missing_binding")};
    const inputs_a = [_]identity.MorphologyParameterId{ parameter_b_id, missing_id };
    const inputs_b = [_]identity.MorphologyParameterId{parameter_a_id};
    const dependencies = [_]morphology.ParameterDependency{
        .{
            .dependency_id = try identity.MorphologyDependencyId.init("dependency_a"),
            .kind = .derived_value,
            .input_parameter_ids = &inputs_a,
            .output_parameter_id = parameter_a_id,
            .source_binding_ids = &missing_binding_ids,
            .resolution_stage = .structural_parameters,
        },
        .{
            .dependency_id = try identity.MorphologyDependencyId.init("dependency_b"),
            .kind = .derived_value,
            .input_parameter_ids = &inputs_b,
            .output_parameter_id = parameter_b_id,
            .source_binding_ids = &.{},
            .resolution_stage = .structural_parameters,
        },
    };
    var source = try makeDefinition(&components, &bones);
    source.morphology_parameters = &parameters;
    source.morphology_graph.dependencies = &dependencies;
    var diagnostic_storage: [128]diagnostics.Diagnostic = undefined;
    const report = try validation.validate(&source, .{}, &diagnostic_storage);
    try std.testing.expect(containsCode(report, .morphology_dependency_cycle));
    try std.testing.expect(containsCode(report, .invalid_derived_input_reference));
    try std.testing.expect(containsCode(report, .unresolved_dependency));
    var order_storage: [2]identity.MorphologyDependencyId = undefined;
    try std.testing.expectError(error.DependencyCycle, trace.deterministicDependencyOrder(&source, &order_storage));
}

test "attachment semantic material and visibility validators reject invalid source" {
    const components = try baseComponents(false);
    const bones = try baseBones(false);
    const missing_anchor_id = try identity.AnchorId.init("missing_anchor");
    const socket_id = try identity.SocketId.init("head_socket");
    const socket = attachment.Socket{
        .socket_id = socket_id,
        .anchor_id = missing_anchor_id,
        .accepted_component_types = &.{},
        .accepted_tags = &.{},
        .capacity = 0,
        .attachment_requirement = .required,
        .compatibility = .none,
    };
    const attachment_record = attachment.Attachment{
        .attachment_id = try identity.AttachmentId.init("head_attachment"),
        .parent_socket_id = socket_id,
        .child_component_id = components[1].component_id,
        .child_mount_anchor_id = try identity.MountAnchorId.init("missing_mount"),
        .compatibility_profiles = &.{},
    };
    const missing_region_id = try identity.RegionId.init("missing_region");
    const missing_material_id = try identity.MaterialInstanceId.init("missing_material");
    const surface_id = try identity.SurfaceId.init("head_surface");
    const surface = semantics.Surface{
        .surface_id = surface_id,
        .display_name = null,
        .owner_component_id = components[1].component_id,
        .region_id = missing_region_id,
        .material_instance_id = missing_material_id,
        .coordinate_metadata_id = null,
        .visibility_metadata_id = null,
    };
    const missing_component_id = try identity.ComponentId.init("missing_component");
    const landmark = semantics.Landmark{
        .landmark_id = try identity.LandmarkId.init("missing_owner_landmark"),
        .display_name = null,
        .owner = .{ .component = missing_component_id },
        .coordinate_metadata_id = null,
        .semantic_tags = &.{},
    };
    const seam_members = [_]semantics.SharedSeamMember{.{
        .component_id = components[0].component_id,
        .surface_id = surface_id,
    }};
    const seam = semantics.SharedSeam{
        .seam_id = try identity.SeamId.init("invalid_shared_seam"),
        .display_name = null,
        .members = &seam_members,
        .coordinate_metadata_id = null,
    };
    const site = semantics.InteractionSite{
        .site_id = try identity.InteractionSiteId.init("missing_owner_site"),
        .display_name = null,
        .owner_component_id = missing_component_id,
        .region_id = missing_region_id,
        .preferred_anchor_id = missing_anchor_id,
        .semantic_tags = &.{},
        .approach_metadata_id = null,
        .orientation_metadata_id = null,
        .capacity = 1,
        .occupancy_policy_id = null,
    };
    const base_color_id = try identity.MaterialPropertyId.init("base_color");
    const property_specs = [_]material.MaterialPropertySpec{.{
        .property_id = base_color_id,
        .value_kind = .linear_srgb_rgba,
        .required = true,
    }};
    const material_definition_id = try identity.MaterialDefinitionId.init("skin_definition");
    const material_definition = material.MaterialDefinition{
        .material_definition_id = material_definition_id,
        .display_name = try identity.DisplayName.init("Skin Definition"),
        .capabilities = &.{},
        .property_specs = &property_specs,
    };
    const material_properties = [_]material.MaterialProperty{.{
        .property_id = base_color_id,
        .value = .{ .linear_srgb_rgba = material.LinearSrgbRgba.init(1.1, 0.2, 0.3, 1.0) },
    }};
    const material_instance = material.MaterialInstance{
        .material_instance_id = try identity.MaterialInstanceId.init("skin_instance"),
        .display_name = try identity.DisplayName.init("Skin Instance"),
        .definition_id = material_definition_id,
        .properties = &material_properties,
    };
    const visibility_record = visibility.VisibilityCoverageMetadata{
        .visibility_metadata_id = try identity.VisibilityMetadataId.init("invalid_visibility"),
        .subject = .{ .component = missing_component_id },
        .component_existence = .present,
        .component_enabled_state = .enabled,
        .visibility_state = .replaced_by_variant,
        .coverage = .{ .value = 1.25 },
        .coverage_region_id = missing_region_id,
        .coverage_sources = &.{},
        .representation = .canonical,
    };
    var source = try makeDefinition(&components, &bones);
    source.sockets = &.{socket};
    source.attachments = &.{attachment_record};
    source.surfaces = &.{surface};
    source.landmarks = &.{landmark};
    source.shared_seams = &.{seam};
    source.interaction_sites = &.{site};
    source.material_definitions = &.{material_definition};
    source.material_instances = &.{material_instance};
    source.visibility_metadata = &.{visibility_record};
    var diagnostic_storage: [256]diagnostics.Diagnostic = undefined;
    const result = try normalization.normalize(&source, .{}, &diagnostic_storage);
    try std.testing.expect(result.normalized == null);
    try std.testing.expect(containsCode(result.report, .socket_missing_anchor));
    try std.testing.expect(containsCode(result.report, .attachment_missing_mount_anchor));
    try std.testing.expect(containsCode(result.report, .attachment_capacity_exceeded));
    try std.testing.expect(containsCode(result.report, .incompatible_attachment_type));
    try std.testing.expect(containsCode(result.report, .surface_missing_region));
    try std.testing.expect(containsCode(result.report, .surface_missing_material));
    try std.testing.expect(containsCode(result.report, .seam_missing_member));
    try std.testing.expect(containsCode(result.report, .seam_member_mismatch));
    try std.testing.expect(containsCode(result.report, .semantic_owner_missing));
    try std.testing.expect(containsCode(result.report, .visibility_reference_missing));
    try std.testing.expect(containsCode(result.report, .coverage_out_of_range));
    try std.testing.expect(containsCode(result.report, .invalid_material_color));
    try std.testing.expectEqual(@as(f32, 1.25), source.visibility_metadata[0].coverage.value);
    try std.testing.expectEqual(@as(f32, 1.1), source.material_instances[0].properties[0].value.linear_srgb_rgba.r());
}

test "diagnostic ordering is stable across reordered invalid input" {
    const bones = try baseBones(false);
    const body_id = try identity.ComponentId.init("body");
    const missing_a = try identity.ComponentId.init("missing_a");
    const missing_z = try identity.ComponentId.init("missing_z");
    const body_type = try identity.ComponentTypeId.init("body");
    const component_a = component.Component{
        .component_id = try identity.ComponentId.init("a_child"),
        .display_name = null,
        .component_type = body_type,
        .parent_component_id = missing_z,
        .semantic_tags = &.{},
        .requirement = .required,
        .default_state = .enabled,
        .multiplicity = .{ .minimum = 1, .maximum = 1 },
        .compatibility = .none,
    };
    const component_z = component.Component{
        .component_id = try identity.ComponentId.init("z_child"),
        .display_name = null,
        .component_type = body_type,
        .parent_component_id = missing_a,
        .semantic_tags = &.{},
        .requirement = .required,
        .default_state = .enabled,
        .multiplicity = .{ .minimum = 1, .maximum = 1 },
        .compatibility = .none,
    };
    const root = component.Component{
        .component_id = body_id,
        .display_name = null,
        .component_type = body_type,
        .parent_component_id = null,
        .semantic_tags = &.{},
        .requirement = .required,
        .default_state = .enabled,
        .multiplicity = .{ .minimum = 1, .maximum = 1 },
        .compatibility = .none,
    };
    const components_a = [_]component.Component{ component_z, root, component_a };
    const components_b = [_]component.Component{ component_a, component_z, root };
    var source_a = try makeDefinition(&components_a, &bones);
    var source_b = try makeDefinition(&components_b, &bones);
    var storage_a: [128]diagnostics.Diagnostic = undefined;
    var storage_b: [128]diagnostics.Diagnostic = undefined;
    const report_a = try validation.validate(&source_a, .{}, &storage_a);
    const report_b = try validation.validate(&source_b, .{}, &storage_b);
    try std.testing.expectEqual(report_a.diagnostics.len, report_b.diagnostics.len);
    for (report_a.diagnostics, report_b.diagnostics) |a, b| {
        try std.testing.expectEqual(a.code, b.code);
        try std.testing.expectEqualStrings(a.object_type, b.object_type);
        try std.testing.expectEqualStrings(a.object_id orelse "", b.object_id orelse "");
        try std.testing.expectEqualStrings(a.property orelse "", b.property orelse "");
        try std.testing.expectEqualStrings(a.reference_id orelse "", b.reference_id orelse "");
        try std.testing.expectEqualStrings(a.message, b.message);
    }
}
