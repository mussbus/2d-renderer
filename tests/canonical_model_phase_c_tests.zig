const std = @import("std");
const canonical = @import("canonical_model");

const identity = canonical.identity;
const material = canonical.material;
const morphology = canonical.morphology;
const visibility = canonical.visibility;

test "morphology parameters represent categories value domains ranges and curves" {
    const categories = [_]morphology.ParameterCategory{
        .structural,
        .morphological,
        .appearance,
        .group,
    };
    try std.testing.expectEqual(@as(usize, 4), categories.len);

    const enum_values = [_]identity.EnumValueId{
        try identity.EnumValueId.init("profile_a"),
        try identity.EnumValueId.init("profile_b"),
    };
    const examples = [_]morphology.ParameterRanges{
        .{
            .default_value = .{ .float = 0.5 },
            .recommended = .{ .float = .{ .minimum = 0.25, .maximum = 0.75 } },
            .hard = .{ .float = .{ .minimum = 0.0, .maximum = 1.0 } },
        },
        .{
            .default_value = .{ .integer = 2 },
            .recommended = .{ .integer = .{ .minimum = 1, .maximum = 3 } },
            .hard = .{ .integer = .{ .minimum = 0, .maximum = 4 } },
        },
        .{
            .default_value = .{ .enumeration = enum_values[0] },
            .recommended = .{ .enumeration = &enum_values },
            .hard = .{ .enumeration = &enum_values },
        },
        .{
            .default_value = .{ .boolean = false },
            .recommended = .{ .boolean = .{ .allows_false = true, .allows_true = true } },
            .hard = .{ .boolean = .{ .allows_false = true, .allows_true = true } },
        },
    };

    try std.testing.expectEqual(@as(usize, 4), examples.len);
    try std.testing.expectEqual(.float, std.meta.activeTag(examples[0].default_value));
    try std.testing.expectEqual(.integer, std.meta.activeTag(examples[1].default_value));
    try std.testing.expectEqual(.enumeration, std.meta.activeTag(examples[2].default_value));
    try std.testing.expectEqual(.boolean, std.meta.activeTag(examples[3].default_value));

    const custom_curve = morphology.ResponseCurve{
        .custom = .{ .reference = try identity.ResponseCurveId.init("shoulder_width_curve") },
    };
    const authored_points = [_]morphology.ResponseCurvePoint{
        .{ .input = 0.0, .output = 0.0 },
        .{ .input = 0.5, .output = 0.65 },
        .{ .input = 1.0, .output = 1.0 },
    };
    const authored_curve = morphology.ResponseCurve{
        .custom = .{ .authored_data = &authored_points },
    };
    try std.testing.expectEqual(.custom, std.meta.activeTag(custom_curve));
    try std.testing.expectEqual(.reference, std.meta.activeTag(custom_curve.custom));
    try std.testing.expectEqual(.authored_data, std.meta.activeTag(authored_curve.custom));
    try std.testing.expectEqual(@as(usize, 3), authored_curve.custom.authored_data.len);

    const parameter = morphology.MorphologyParameter{
        .parameter_id = try identity.MorphologyParameterId.init("target_height"),
        .display_name = try identity.DisplayName.init("Target Height"),
        .category = .structural,
        .unit = .meter,
        .ranges = examples[0],
        .response_curve = .linear,
        .symmetry = .centered,
        .topology_policy = .preserve_existing_topology,
        .binding_ids = &.{},
    };
    try std.testing.expectEqual(morphology.ParameterCategory.structural, parameter.category);
    try std.testing.expectEqual(morphology.ValueUnit.meter, parameter.unit);
    try std.testing.expectEqual(morphology.TopologyPolicy.preserve_existing_topology, parameter.topology_policy);
}

test "symmetry preserves linked mirrored and independent underlying parameter IDs" {
    const left_id = try identity.MorphologyParameterId.init("arm_length_left_01");
    const right_id = try identity.MorphologyParameterId.init("arm_length_right_01");
    const linked = morphology.Symmetry{
        .mirrored = .{
            .left_parameter_id = left_id,
            .right_parameter_id = right_id,
            .linked_by_default = true,
        },
    };
    const independent = morphology.Symmetry{
        .independent_pair = .{
            .left_parameter_id = left_id,
            .right_parameter_id = right_id,
            .linked_by_default = false,
        },
    };

    try std.testing.expectEqual(.mirrored, std.meta.activeTag(linked));
    try std.testing.expect(linked.mirrored.left_parameter_id.eql(left_id));
    try std.testing.expect(linked.mirrored.right_parameter_id.eql(right_id));
    try std.testing.expect(linked.mirrored.linked_by_default);
    try std.testing.expectEqual(.independent_pair, std.meta.activeTag(independent));
    try std.testing.expect(!independent.independent_pair.linked_by_default);
}

test "one structural parameter declares multiple explicit typed bindings" {
    const parameter_id = try identity.MorphologyParameterId.init("target_height");
    const binding_ids = [_]identity.MorphologyBindingId{
        try identity.MorphologyBindingId.init("target_height_root_binding"),
        try identity.MorphologyBindingId.init("target_height_anchor_binding"),
        try identity.MorphologyBindingId.init("target_height_collision_binding"),
        try identity.MorphologyBindingId.init("target_height_garment_binding"),
    };
    const property_id = try identity.PropertyId.init("height_m");
    const bindings = [_]morphology.MorphologyBinding{
        .{
            .binding_id = binding_ids[0],
            .source_parameter_id = parameter_id,
            .target = .{ .rest_bone_transform = .{
                .target_id = try identity.BoneId.init("skeleton_root"),
                .property_id = try identity.PropertyId.init("translation_y"),
            } },
            .operation = .set,
            .writer_role = .authoritative,
            .resolution_stage = .rest_skeleton_and_anchors,
            .response_curve_override = null,
        },
        .{
            .binding_id = binding_ids[1],
            .source_parameter_id = parameter_id,
            .target = .{ .anchor_transform = .{
                .target_id = try identity.AnchorId.init("head_top_anchor"),
                .property_id = try identity.PropertyId.init("position_y"),
            } },
            .operation = .offset,
            .writer_role = .authoritative,
            .resolution_stage = .rest_skeleton_and_anchors,
            .response_curve_override = .smooth,
        },
        .{
            .binding_id = binding_ids[2],
            .source_parameter_id = parameter_id,
            .target = .{ .collision_geometry = .{
                .target_id = try identity.CollisionGeometryId.init("body_collision"),
                .property_id = property_id,
            } },
            .operation = .scale,
            .writer_role = .authoritative,
            .resolution_stage = .collisions_and_interaction_sites,
            .response_curve_override = null,
        },
        .{
            .binding_id = binding_ids[3],
            .source_parameter_id = parameter_id,
            .target = .{ .garment_fitting_envelope = .{
                .target_id = try identity.GarmentFittingEnvelopeId.init("body_fitting_envelope"),
                .property_id = property_id,
            } },
            .operation = .derive,
            .writer_role = .authoritative,
            .resolution_stage = .garment_fitting,
            .response_curve_override = null,
        },
    };
    const parameter = morphology.MorphologyParameter{
        .parameter_id = parameter_id,
        .display_name = try identity.DisplayName.init("Target Height"),
        .category = .structural,
        .unit = .meter,
        .ranges = .{
            .default_value = .{ .float = 1.0 },
            .recommended = .{ .float = .{ .minimum = 0.75, .maximum = 1.25 } },
            .hard = .{ .float = .{ .minimum = 0.5, .maximum = 1.5 } },
        },
        .response_curve = .linear,
        .symmetry = .centered,
        .topology_policy = .preserve_existing_topology,
        .binding_ids = &binding_ids,
    };

    try std.testing.expectEqual(@as(usize, 4), parameter.binding_ids.len);
    try std.testing.expectEqual(morphology.BindingTargetType.rest_bone_transform, std.meta.activeTag(bindings[0].target));
    try std.testing.expectEqual(morphology.BindingTargetType.anchor_transform, std.meta.activeTag(bindings[1].target));
    try std.testing.expectEqual(morphology.BindingTargetType.collision_geometry, std.meta.activeTag(bindings[2].target));
    try std.testing.expectEqual(morphology.BindingTargetType.garment_fitting_envelope, std.meta.activeTag(bindings[3].target));
    try std.testing.expectEqualStrings("height_m", bindings[3].target.garment_fitting_envelope.property_id.value.bytes);
}

test "all binding target categories and operations remain representable" {
    const property_id = try identity.PropertyId.init("value");
    const targets = [_]morphology.BindingTarget{
        .{ .rest_bone_transform = .{ .target_id = try identity.BoneId.init("bone_a"), .property_id = property_id } },
        .{ .anchor_transform = .{ .target_id = try identity.AnchorId.init("anchor_a"), .property_id = property_id } },
        .{ .socket = .{ .target_id = try identity.SocketId.init("socket_a"), .property_id = property_id } },
        .{ .mesh_morph_target = .{ .target_id = try identity.MorphTargetId.init("morph_a"), .property_id = property_id } },
        .{ .corrective_shape_input = .{ .target_id = try identity.CorrectiveShapeId.init("corrective_a"), .property_id = property_id } },
        .{ .material_parameter = .{ .target_id = try identity.MaterialInstanceId.init("material_a"), .property_id = property_id } },
        .{ .collision_geometry = .{ .target_id = try identity.CollisionGeometryId.init("collision_a"), .property_id = property_id } },
        .{ .interaction_site = .{ .target_id = try identity.InteractionSiteId.init("site_a"), .property_id = property_id } },
        .{ .garment_fitting_envelope = .{ .target_id = try identity.GarmentFittingEnvelopeId.init("envelope_a"), .property_id = property_id } },
        .{ .garment_fitting_surface = .{ .target_id = try identity.SurfaceId.init("surface_a"), .property_id = property_id } },
        .{ .semantic_landmark = .{ .target_id = try identity.LandmarkId.init("landmark_a"), .property_id = property_id } },
        .{ .soft_tissue_property = .{ .target_id = try identity.SoftTissueProfileId.init("soft_tissue_a"), .property_id = property_id } },
        .{ .morphology_parameter = .{ .target_id = try identity.MorphologyParameterId.init("parameter_a"), .property_id = property_id } },
    };
    const operations = [_]morphology.BindingOperation{
        .set,
        .offset,
        .scale,
        .weight,
        .remap,
        .derive,
    };

    try std.testing.expectEqual(@typeInfo(morphology.BindingTargetType).@"enum".fields.len, targets.len);
    try std.testing.expectEqual(@as(usize, 6), operations.len);
    try std.testing.expectError(error.InvalidCanonicalId, identity.PropertyId.init("PositionX"));
}

test "group parameters drive parameters and derived dependencies expose provenance" {
    const group_id = try identity.MorphologyParameterId.init("overall_shoulder_width");
    const clavicle_id = try identity.MorphologyParameterId.init("clavicle_length");
    const deltoid_id = try identity.MorphologyParameterId.init("deltoid_width");
    const binding_ids = [_]identity.MorphologyBindingId{
        try identity.MorphologyBindingId.init("shoulder_group_clavicle_binding"),
        try identity.MorphologyBindingId.init("shoulder_group_deltoid_binding"),
    };
    const parameter_property = try identity.PropertyId.init("value");
    const bindings = [_]morphology.MorphologyBinding{
        .{
            .binding_id = binding_ids[0],
            .source_parameter_id = group_id,
            .target = .{ .morphology_parameter = .{ .target_id = clavicle_id, .property_id = parameter_property } },
            .operation = .scale,
            .writer_role = .contributing,
            .resolution_stage = .structural_parameters,
            .response_curve_override = null,
        },
        .{
            .binding_id = binding_ids[1],
            .source_parameter_id = group_id,
            .target = .{ .morphology_parameter = .{ .target_id = deltoid_id, .property_id = parameter_property } },
            .operation = .scale,
            .writer_role = .contributing,
            .resolution_stage = .structural_parameters,
            .response_curve_override = .smooth,
        },
    };
    const group_parameter = morphology.MorphologyParameter{
        .parameter_id = group_id,
        .display_name = try identity.DisplayName.init("Overall Shoulder Width"),
        .category = .group,
        .unit = .normalized,
        .ranges = .{
            .default_value = .{ .float = 0.5 },
            .recommended = .{ .float = .{ .minimum = 0.25, .maximum = 0.75 } },
            .hard = .{ .float = .{ .minimum = 0, .maximum = 1 } },
        },
        .response_curve = .smooth,
        .symmetry = .centered,
        .topology_policy = .preserve_existing_topology,
        .binding_ids = &binding_ids,
    };
    for (bindings) |binding| {
        try std.testing.expectEqual(morphology.BindingTargetType.morphology_parameter, std.meta.activeTag(binding.target));
    }
    try std.testing.expectEqual(morphology.ParameterCategory.group, group_parameter.category);

    const derived_id = try identity.MorphologyParameterId.init("shoulder_span_derived");
    const dependency_id = try identity.MorphologyDependencyId.init("shoulder_span_dependency");
    const inputs = [_]identity.MorphologyParameterId{ clavicle_id, deltoid_id };
    const dependency = morphology.ParameterDependency{
        .dependency_id = dependency_id,
        .kind = .derived_value,
        .input_parameter_ids = &inputs,
        .output_parameter_id = derived_id,
        .source_binding_ids = &binding_ids,
        .resolution_stage = .rest_skeleton_and_anchors,
    };
    const provenance_sources = [_]morphology.ProvenanceSource{
        .{ .parameter = clavicle_id },
        .{ .parameter = deltoid_id },
        .{ .dependency = dependency_id },
    };
    const trace = morphology.ProvenanceTrace{
        .provenance_id = try identity.MorphologyProvenanceId.init("shoulder_span_trace"),
        .output_parameter_id = derived_id,
        .sources = &provenance_sources,
    };
    const dependencies = [_]morphology.ParameterDependency{dependency};
    const traces = [_]morphology.ProvenanceTrace{trace};
    const graph = morphology.DependencyGraph{
        .dependencies = &dependencies,
        .provenance = &traces,
    };

    try std.testing.expectEqual(@as(usize, 2), graph.dependencies[0].input_parameter_ids.len);
    try std.testing.expect(graph.dependencies[0].output_parameter_id.eql(derived_id));
    try std.testing.expectEqual(@as(usize, 3), graph.provenance[0].sources.len);
    try std.testing.expect(@intFromEnum(morphology.ResolutionStage.structural_parameters) < @intFromEnum(morphology.ResolutionStage.rest_skeleton_and_anchors));
    try std.testing.expect(@intFromEnum(morphology.ResolutionStage.rest_skeleton_and_anchors) < @intFromEnum(morphology.ResolutionStage.mesh_morphology));
    try std.testing.expect(@intFromEnum(morphology.ResolutionStage.mesh_morphology) < @intFromEnum(morphology.ResolutionStage.soft_tissue));
    try std.testing.expect(@intFromEnum(morphology.ResolutionStage.soft_tissue) < @intFromEnum(morphology.ResolutionStage.collisions_and_interaction_sites));
    try std.testing.expect(@intFromEnum(morphology.ResolutionStage.collisions_and_interaction_sites) < @intFromEnum(morphology.ResolutionStage.garment_fitting));
    try std.testing.expect(@intFromEnum(morphology.ResolutionStage.garment_fitting) < @intFromEnum(morphology.ResolutionStage.corrective_validation));
}

test "material definitions and instances remain separate with locked base color encoding" {
    const base_color_id = try identity.MaterialPropertyId.init("base_color");
    const roughness_id = try identity.MaterialPropertyId.init("roughness");
    const gloss_specular_id = try identity.MaterialPropertyId.init("gloss_specular");
    const opacity_id = try identity.MaterialPropertyId.init("opacity");
    const translucency_id = try identity.MaterialPropertyId.init("translucency");
    const subsurface_id = try identity.MaterialPropertyId.init("subsurface_response");
    const normal_detail_id = try identity.MaterialPropertyId.init("normal_detail_strength");
    const wetness_response_id = try identity.MaterialPropertyId.init("wetness_response");
    const temperature_response_id = try identity.MaterialPropertyId.init("temperature_color_response");
    const emission_id = try identity.MaterialPropertyId.init("emission");
    const displacement_id = try identity.MaterialPropertyId.init("displacement_detail");
    const specs = [_]material.MaterialPropertySpec{
        .{ .property_id = base_color_id, .value_kind = .linear_srgb_rgba, .required = true },
        .{ .property_id = roughness_id, .value_kind = .scalar, .required = true },
        .{ .property_id = gloss_specular_id, .value_kind = .scalar, .required = false },
        .{ .property_id = opacity_id, .value_kind = .scalar, .required = false },
        .{ .property_id = translucency_id, .value_kind = .scalar, .required = false },
        .{ .property_id = subsurface_id, .value_kind = .response_reference, .required = false },
        .{ .property_id = normal_detail_id, .value_kind = .scalar, .required = false },
        .{ .property_id = wetness_response_id, .value_kind = .response_reference, .required = false },
        .{ .property_id = temperature_response_id, .value_kind = .response_reference, .required = false },
        .{ .property_id = emission_id, .value_kind = .scalar, .required = false },
        .{ .property_id = displacement_id, .value_kind = .detail_reference, .required = false },
    };
    const capabilities = [_]identity.MaterialCapabilityId{
        try identity.MaterialCapabilityId.init("subsurface_response"),
        try identity.MaterialCapabilityId.init("temperature_color_response"),
        try identity.MaterialCapabilityId.init("normal_detail"),
    };
    const definition_id = try identity.MaterialDefinitionId.init("skin_material");
    const definition = material.MaterialDefinition{
        .material_definition_id = definition_id,
        .display_name = try identity.DisplayName.init("Skin Material"),
        .capabilities = &capabilities,
        .property_specs = &specs,
    };
    const base_color = material.LinearSrgbRgba.init(0.25, 0.5, 0.75, 1.0);
    const values = [_]material.MaterialProperty{
        .{ .property_id = base_color_id, .value = .{ .linear_srgb_rgba = base_color } },
        .{ .property_id = roughness_id, .value = .{ .scalar = 0.6 } },
        .{ .property_id = wetness_response_id, .value = .{ .response_reference = try identity.MaterialResponseId.init("skin_wetness") } },
        .{ .property_id = emission_id, .value = .{ .scalar = 0.0 } },
        .{ .property_id = displacement_id, .value = .{ .detail_reference = try identity.MaterialDetailId.init("skin_micro_detail") } },
    };
    const instance = material.MaterialInstance{
        .material_instance_id = try identity.MaterialInstanceId.init("neutral_skin"),
        .display_name = try identity.DisplayName.init("Neutral Skin"),
        .definition_id = definition_id,
        .properties = &values,
    };

    try std.testing.expect(material.MaterialDefinition != material.MaterialInstance);
    try std.testing.expect(instance.definition_id.eql(definition.material_definition_id));
    try std.testing.expectEqual(@as(usize, 11), definition.property_specs.len);
    try std.testing.expectEqual(material.ColorSpace.linear_srgb, material.LinearSrgbRgba.color_space);
    try std.testing.expectEqual(material.ChannelOrder.rgba, material.LinearSrgbRgba.channel_order);
    try std.testing.expectEqual(material.AlphaConvention.straight_unassociated, material.LinearSrgbRgba.alpha_convention);
    try std.testing.expect(@TypeOf(base_color.channels[0]) == f32);
    try std.testing.expectEqual(@as(f32, 0.25), base_color.r());
    try std.testing.expectEqual(@as(f32, 0.5), base_color.g());
    try std.testing.expectEqual(@as(f32, 0.75), base_color.b());
    try std.testing.expectEqual(@as(f32, 1.0), base_color.a());
    try std.testing.expect(!@hasField(material.MaterialInstance, "temporary_surface_state"));
}

test "visibility metadata keeps existence enabled visibility coverage and representation separate" {
    const coverage_sources = [_]visibility.CoverageContribution{
        .{
            .source_type = .clothing,
            .source_id = try identity.CoverageSourceId.init("shirt_front"),
            .amount = .{ .value = 0.25 },
        },
        .{
            .source_type = .body_overlap,
            .source_id = try identity.CoverageSourceId.init("arm_overlap"),
            .amount = .{ .value = 0.10 },
        },
    };
    const region_id = try identity.RegionId.init("chest_region");
    const variant_id = try identity.RepresentationVariantId.init("chest_partial_cover");
    const metadata = visibility.VisibilityCoverageMetadata{
        .visibility_metadata_id = try identity.VisibilityMetadataId.init("chest_visibility"),
        .subject = .{ .surface = try identity.SurfaceId.init("chest_surface") },
        .component_existence = .present,
        .component_enabled_state = .enabled,
        .visibility_state = .partially_visible,
        .coverage = .{ .value = 0.35 },
        .coverage_region_id = region_id,
        .coverage_sources = &coverage_sources,
        .representation = .{ .variant = variant_id },
    };
    const states = [_]visibility.VisibilityState{
        .visible,
        .partially_visible,
        .fully_occluded,
        .hidden_by_policy,
        .hidden_for_representation,
        .replaced_by_variant,
    };
    const source_types = [_]visibility.CoverageSourceType{
        .clothing,
        .armor,
        .hair,
        .accessory,
        .body_overlap,
        .prop,
    };

    try std.testing.expectEqual(visibility.ComponentExistence.present, metadata.component_existence);
    try std.testing.expectEqual(visibility.ComponentEnabledState.enabled, metadata.component_enabled_state);
    try std.testing.expectEqual(visibility.VisibilityState.partially_visible, metadata.visibility_state);
    try std.testing.expect(@TypeOf(metadata.coverage) == visibility.NormalizedCoverage);
    try std.testing.expect(@TypeOf(metadata.coverage.value) == f32);
    try std.testing.expectEqual(@as(f32, 0.35), metadata.coverage.value);
    try std.testing.expectEqual(@as(f32, 0.0), visibility.NormalizedCoverage.minimum);
    try std.testing.expectEqual(@as(f32, 1.0), visibility.NormalizedCoverage.maximum);
    try std.testing.expectEqual(.variant, std.meta.activeTag(metadata.representation));
    try std.testing.expect(metadata.representation.variant.eql(variant_id));
    try std.testing.expectEqual(@as(usize, 6), states.len);
    try std.testing.expectEqual(@as(usize, 6), source_types.len);
}
