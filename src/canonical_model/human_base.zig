const std = @import("std");
const component = @import("component.zig");
const coordinate = @import("coordinate.zig");
const definition = @import("definition.zig");
const human_attachments = @import("human_attachments.zig");
const human_controls = @import("human_controls.zig");
const human_joints = @import("human_joints.zig");
const human_structural_semantics = @import("human_structural_semantics.zig");
const identity = @import("identity.zig");
const human_rig = @import("human_rig.zig");
const material = @import("material.zig");
const semantics = @import("semantics.zig");
const visibility = @import("visibility.zig");

pub const schema_version = identity.SchemaVersion{ .major = 1, .minor = 1, .patch = 0 };
pub const asset_version = identity.AssetVersion{ .major = 1, .minor = 0, .patch = 0 };
pub const compiler_version = identity.CompilerVersion{ .major = 1, .minor = 0, .patch = 0 };
pub const authoritative_authoring_path = "assets/canonical_model/human_base/human_base.authoring.json";

pub const component_count: usize = 48;
pub const region_surface_count: usize = 206;
pub const neutral_material_count: usize = 11;

pub const open_tuning = struct {
    pub const skin_linear_srgb_rgba = [4]f32{ 0.52, 0.32, 0.22, 1.0 };
    pub const lips_linear_srgb_rgba = [4]f32{ 0.45, 0.16, 0.16, 1.0 };
    pub const nails_linear_srgb_rgba = [4]f32{ 0.75, 0.58, 0.50, 1.0 };
    pub const tooth_enamel_linear_srgb_rgba = [4]f32{ 0.90, 0.90, 0.82, 1.0 };
    pub const gums_linear_srgb_rgba = [4]f32{ 0.55, 0.20, 0.25, 1.0 };
    pub const oral_mucosa_linear_srgb_rgba = [4]f32{ 0.45, 0.12, 0.15, 1.0 };
    pub const tongue_linear_srgb_rgba = [4]f32{ 0.55, 0.18, 0.23, 1.0 };
    pub const sclera_linear_srgb_rgba = [4]f32{ 0.90, 0.90, 0.86, 1.0 };
    pub const iris_linear_srgb_rgba = [4]f32{ 0.18, 0.28, 0.22, 1.0 };
    pub const pupil_linear_srgb_rgba = [4]f32{ 0.01, 0.01, 0.01, 1.0 };
    pub const cornea_linear_srgb_rgba = [4]f32{ 1.0, 1.0, 1.0, 0.08 };
};

pub const ComponentSpec = struct {
    component_id: []const u8,
    component_type: []const u8,
    parent_component_id: ?[]const u8,
    requirement: component.Requirement,
    default_state: component.DefaultState,
    semantic_tags: []const identity.SemanticTagId,
};

pub const RegionSurfaceSpec = struct {
    region_id: []const u8,
    owner_component_id: []const u8,
    material_instance_id: []const u8,
};

pub const MaterialSpec = struct {
    definition_id: []const u8,
    definition_display_name: []const u8,
    instance_id: []const u8,
    instance_display_name: []const u8,
    color: [4]f32,
};

const structural_tags = makeIds(identity.SemanticTagId, &.{ "human", "structural" });
const structural_left_tags = makeIds(identity.SemanticTagId, &.{ "human", "left", "structural" });
const structural_right_tags = makeIds(identity.SemanticTagId, &.{ "human", "right", "structural" });
const nail_left_tags = makeIds(identity.SemanticTagId, &.{ "human", "left", "nail" });
const nail_right_tags = makeIds(identity.SemanticTagId, &.{ "human", "right", "nail" });
const optional_anatomy_tags = makeIds(identity.SemanticTagId, &.{ "human", "optional_anatomy" });
const region_tags = makeIds(identity.SemanticTagId, &.{ "human", "semantic_region" });
const material_capabilities = makeIds(identity.MaterialCapabilityId, &.{"base_color"});

pub const component_specs = buildComponentSpecs();
pub const region_surface_specs = buildRegionSurfaceSpecs();
pub const material_specs = [_]MaterialSpec{
    .{ .definition_id = "human_skin_material", .definition_display_name = "Human Skin Material", .instance_id = "human_base_skin", .instance_display_name = "Human Base Skin", .color = open_tuning.skin_linear_srgb_rgba },
    .{ .definition_id = "lip_material", .definition_display_name = "Lip Material", .instance_id = "human_base_lips", .instance_display_name = "Human Base Lips", .color = open_tuning.lips_linear_srgb_rgba },
    .{ .definition_id = "nail_material", .definition_display_name = "Nail Material", .instance_id = "human_base_nails", .instance_display_name = "Human Base Nails", .color = open_tuning.nails_linear_srgb_rgba },
    .{ .definition_id = "tooth_enamel_material", .definition_display_name = "Tooth Enamel Material", .instance_id = "human_base_tooth_enamel", .instance_display_name = "Human Base Tooth Enamel", .color = open_tuning.tooth_enamel_linear_srgb_rgba },
    .{ .definition_id = "gum_material", .definition_display_name = "Gum Material", .instance_id = "human_base_gums", .instance_display_name = "Human Base Gums", .color = open_tuning.gums_linear_srgb_rgba },
    .{ .definition_id = "oral_mucosa_material", .definition_display_name = "Oral Mucosa Material", .instance_id = "human_base_oral_mucosa", .instance_display_name = "Human Base Oral Mucosa", .color = open_tuning.oral_mucosa_linear_srgb_rgba },
    .{ .definition_id = "tongue_material", .definition_display_name = "Tongue Material", .instance_id = "human_base_tongue", .instance_display_name = "Human Base Tongue", .color = open_tuning.tongue_linear_srgb_rgba },
    .{ .definition_id = "sclera_material", .definition_display_name = "Sclera Material", .instance_id = "human_base_sclera", .instance_display_name = "Human Base Sclera", .color = open_tuning.sclera_linear_srgb_rgba },
    .{ .definition_id = "iris_material", .definition_display_name = "Iris Material", .instance_id = "human_base_iris", .instance_display_name = "Human Base Iris", .color = open_tuning.iris_linear_srgb_rgba },
    .{ .definition_id = "pupil_material", .definition_display_name = "Pupil Material", .instance_id = "human_base_pupil", .instance_display_name = "Human Base Pupil", .color = open_tuning.pupil_linear_srgb_rgba },
    .{ .definition_id = "cornea_material", .definition_display_name = "Cornea Material", .instance_id = "human_base_cornea", .instance_display_name = "Human Base Cornea", .color = open_tuning.cornea_linear_srgb_rgba },
};

pub const components = buildComponents();
pub const bones = human_rig.bones;
pub const joints = human_joints.joints;
pub const controls = human_controls.controls;
pub const anchors = human_attachments.anchors;
pub const sockets = human_attachments.sockets;
pub const mount_anchors = human_attachments.mount_anchors;
pub const attachments = human_attachments.attachments;
pub const landmarks = human_structural_semantics.landmarks;
pub const shared_seams = human_structural_semantics.shared_seams;
pub const interaction_sites = human_structural_semantics.interaction_sites;
pub const effectors = human_structural_semantics.effectors;
pub const regions = buildRegions();
pub const surfaces = buildSurfaces();
pub const material_definitions = buildMaterialDefinitions();
pub const material_instances = buildMaterialInstances();
pub const visibility_metadata = buildVisibilityMetadata();

/// Executable manifest mirror used by focused construction and mutation tests.
/// The file at `authoritative_authoring_path` is the M02 asset authority; the
/// Prompt 2E acceptance suite requires this mirror to serialize to that file's
/// reviewed canonical golden, and the update tool never writes the authority.
pub const source = definition.CanonicalCreatureDefinition{
    .schema_identity = .{
        .schema_id = makeId(identity.SchemaId, "canonical_creature_schema"),
        .version = schema_version,
    },
    .asset_identity = .{
        .asset_id = makeId(identity.AssetId, "human_base"),
        .display_name = makeDisplayName("Human Base"),
        .version = asset_version,
    },
    .compiler_identity = .{
        .compiler_id = makeId(identity.CompilerId, "m01_canonical_compiler"),
        .version = compiler_version,
    },
    .coordinate_contract = coordinate.canonical,
    .components = &components,
    .bones = &bones,
    .joints = &joints,
    .controls = &controls,
    .anchors = &anchors,
    .sockets = &sockets,
    .mount_anchors = &mount_anchors,
    .attachments = &attachments,
    .landmarks = &landmarks,
    .shared_seams = &shared_seams,
    .interaction_sites = &interaction_sites,
    .effectors = &effectors,
    .regions = &regions,
    .surfaces = &surfaces,
    .material_definitions = &material_definitions,
    .material_instances = &material_instances,
    .visibility_metadata = &visibility_metadata,
};

fn buildComponentSpecs() [component_count]ComponentSpec {
    @setEvalBranchQuota(100_000);
    var result: [component_count]ComponentSpec = undefined;
    var index: usize = 0;

    appendComponent(&result, &index, "body", "body", null, .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "torso", "torso", "body", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "pelvis", "pelvis", "body", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "neck", "neck", "body", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "head", "head", "body", .required, .enabled, &structural_tags);

    inline for (.{ "left", "right" }) |side| {
        const side_tags = if (std.mem.eql(u8, side, "left")) &structural_left_tags else &structural_right_tags;
        const arm_id = std.fmt.comptimePrint("arm_{s}_01", .{side});
        const hand_id = std.fmt.comptimePrint("hand_{s}_01", .{side});
        const leg_id = std.fmt.comptimePrint("leg_{s}_01", .{side});
        const foot_id = std.fmt.comptimePrint("foot_{s}_01", .{side});
        appendComponent(&result, &index, arm_id, "arm", "body", .required, .enabled, side_tags);
        appendComponent(&result, &index, hand_id, "hand", arm_id, .required, .enabled, side_tags);
        appendComponent(&result, &index, leg_id, "leg", "pelvis", .required, .enabled, side_tags);
        appendComponent(&result, &index, foot_id, "foot", leg_id, .required, .enabled, side_tags);
        appendComponent(&result, &index, std.fmt.comptimePrint("eye_{s}_01", .{side}), "eye", "head", .required, .enabled, side_tags);
        appendComponent(&result, &index, std.fmt.comptimePrint("ear_{s}_01", .{side}), "ear", "head", .required, .enabled, side_tags);
    }

    appendComponent(&result, &index, "mouth", "mouth", "head", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "mouth_cavity", "oral_cavity", "mouth", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "teeth_upper", "dentition", "mouth", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "gums_palate_upper", "oral_tissue", "mouth", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "teeth_lower", "dentition", "mouth", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "gums_lower", "oral_tissue", "mouth", .required, .enabled, &structural_tags);
    appendComponent(&result, &index, "tongue", "tongue", "mouth", .required, .enabled, &structural_tags);

    inline for (.{ "left", "right" }) |side| {
        const side_tags = if (std.mem.eql(u8, side, "left")) &nail_left_tags else &nail_right_tags;
        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
            appendComponent(
                &result,
                &index,
                std.fmt.comptimePrint("fingernail_{s}_{s}", .{ digit, side }),
                "nail",
                std.fmt.comptimePrint("hand_{s}_01", .{side}),
                .required,
                .enabled,
                side_tags,
            );
            appendComponent(
                &result,
                &index,
                std.fmt.comptimePrint("toenail_{s}_{s}", .{ digit, side }),
                "nail",
                std.fmt.comptimePrint("foot_{s}_01", .{side}),
                .required,
                .enabled,
                side_tags,
            );
        }
    }

    appendComponent(&result, &index, "anus_module_01", "optional_anatomy_module", "pelvis", .optional, .enabled, &optional_anatomy_tags);
    appendComponent(&result, &index, "vulva_vaginal_canal_module_01", "optional_anatomy_module", "pelvis", .optional, .disabled, &optional_anatomy_tags);
    appendComponent(&result, &index, "penis_module_01", "optional_anatomy_module", "pelvis", .optional, .disabled, &optional_anatomy_tags);
    appendComponent(&result, &index, "scrotum_testicles_module_01", "optional_anatomy_module", "pelvis", .optional, .disabled, &optional_anatomy_tags);

    if (index != component_count) @compileError("human_base component manifest count mismatch");
    return result;
}

fn appendComponent(
    result: *[component_count]ComponentSpec,
    index: *usize,
    component_id: []const u8,
    component_type: []const u8,
    parent_component_id: ?[]const u8,
    requirement: component.Requirement,
    default_state: component.DefaultState,
    semantic_tags: []const identity.SemanticTagId,
) void {
    result[index.*] = .{
        .component_id = component_id,
        .component_type = component_type,
        .parent_component_id = parent_component_id,
        .requirement = requirement,
        .default_state = default_state,
        .semantic_tags = semantic_tags,
    };
    index.* += 1;
}

fn buildComponents() [component_count]component.Component {
    @setEvalBranchQuota(100_000);
    var result: [component_count]component.Component = undefined;
    inline for (component_specs, 0..) |spec, index| {
        result[index] = .{
            .component_id = makeId(identity.ComponentId, spec.component_id),
            .display_name = null,
            .component_type = makeId(identity.ComponentTypeId, spec.component_type),
            .parent_component_id = if (spec.parent_component_id) |parent_id| makeId(identity.ComponentId, parent_id) else null,
            .semantic_tags = spec.semantic_tags,
            .requirement = spec.requirement,
            .default_state = spec.default_state,
            .multiplicity = .{
                .minimum = if (spec.requirement == .required) 1 else 0,
                .maximum = 1,
            },
            .compatibility = .none,
        };
    }
    return result;
}

fn buildRegionSurfaceSpecs() [region_surface_count]RegionSurfaceSpec {
    @setEvalBranchQuota(500_000);
    var result: [region_surface_count]RegionSurfaceSpec = undefined;
    var index: usize = 0;

    inline for (.{ "head", "face", "scalp", "forehead" }) |region_id| appendRegion(&result, &index, region_id, "head", "human_base_skin");
    inline for (.{ "left", "right" }) |side| appendRegion(&result, &index, std.fmt.comptimePrint("brow_{s}", .{side}), "head", "human_base_skin");
    appendRegion(&result, &index, "nose", "head", "human_base_skin");
    inline for (.{ "left", "right" }) |side| appendRegion(&result, &index, std.fmt.comptimePrint("cheek_{s}", .{side}), "head", "human_base_skin");
    appendRegion(&result, &index, "lip_upper", "head", "human_base_lips");
    appendRegion(&result, &index, "lip_lower", "head", "human_base_lips");
    appendRegion(&result, &index, "chin", "head", "human_base_skin");
    appendRegion(&result, &index, "jawline", "head", "human_base_skin");

    inline for (.{ "neck", "throat" }) |region_id| appendRegion(&result, &index, region_id, "neck", "human_base_skin");
    inline for (.{ "torso", "chest", "abdomen", "back", "sternum", "waist" }) |region_id| appendRegion(&result, &index, region_id, "torso", "human_base_skin");
    inline for (.{ "shoulder", "pectoral", "breast", "nipple", "areola" }) |region_prefix| {
        inline for (.{ "left", "right" }) |side| appendRegion(&result, &index, std.fmt.comptimePrint("{s}_{s}", .{ region_prefix, side }), "torso", "human_base_skin");
    }
    appendRegion(&result, &index, "navel", "torso", "human_base_skin");

    appendRegion(&result, &index, "pelvis", "pelvis", "human_base_skin");
    inline for (.{ "hip", "groin" }) |region_prefix| {
        inline for (.{ "left", "right" }) |side| appendRegion(&result, &index, std.fmt.comptimePrint("{s}_{s}", .{ region_prefix, side }), "pelvis", "human_base_skin");
    }
    appendRegion(&result, &index, "pubic", "pelvis", "human_base_skin");
    inline for (.{ "left", "right" }) |side| appendRegion(&result, &index, std.fmt.comptimePrint("glute_{s}", .{side}), "pelvis", "human_base_skin");
    appendRegion(&result, &index, "gluteal_cleft", "pelvis", "human_base_skin");
    appendRegion(&result, &index, "perineal", "pelvis", "human_base_skin");

    inline for (.{ "left", "right" }) |side| {
        const arm_owner = std.fmt.comptimePrint("arm_{s}_01", .{side});
        inline for (.{ "upper_arm", "elbow", "forearm", "wrist" }) |region_prefix| appendRegion(&result, &index, std.fmt.comptimePrint("{s}_{s}", .{ region_prefix, side }), arm_owner, "human_base_skin");
        const hand_owner = std.fmt.comptimePrint("hand_{s}_01", .{side});
        appendRegion(&result, &index, std.fmt.comptimePrint("palm_{s}", .{side}), hand_owner, "human_base_skin");
        appendRegion(&result, &index, std.fmt.comptimePrint("hand_dorsum_{s}", .{side}), hand_owner, "human_base_skin");
        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| appendRegion(&result, &index, std.fmt.comptimePrint("{s}_{s}", .{ digit, side }), hand_owner, "human_base_skin");

        const leg_owner = std.fmt.comptimePrint("leg_{s}_01", .{side});
        inline for (.{ "thigh", "knee", "lower_leg", "calf", "shin", "ankle" }) |region_prefix| appendRegion(&result, &index, std.fmt.comptimePrint("{s}_{s}", .{ region_prefix, side }), leg_owner, "human_base_skin");
        const foot_owner = std.fmt.comptimePrint("foot_{s}_01", .{side});
        inline for (.{ "heel", "midfoot", "forefoot", "sole" }) |region_prefix| appendRegion(&result, &index, std.fmt.comptimePrint("{s}_{s}", .{ region_prefix, side }), foot_owner, "human_base_skin");
        appendRegion(&result, &index, std.fmt.comptimePrint("toe_big_{s}", .{side}), foot_owner, "human_base_skin");
        inline for (.{ "index", "middle", "ring", "little" }) |toe| appendRegion(&result, &index, std.fmt.comptimePrint("toe_{s}_{s}", .{ toe, side }), foot_owner, "human_base_skin");
        appendRegion(&result, &index, std.fmt.comptimePrint("toe_pad_big_{s}", .{side}), foot_owner, "human_base_skin");
        inline for (.{ "index", "middle", "ring", "little" }) |toe| appendRegion(&result, &index, std.fmt.comptimePrint("toe_pad_{s}_{s}", .{ toe, side }), foot_owner, "human_base_skin");

        const eye_owner = std.fmt.comptimePrint("eye_{s}_01", .{side});
        appendRegion(&result, &index, std.fmt.comptimePrint("eye_{s}", .{side}), eye_owner, "human_base_skin");
        appendRegion(&result, &index, std.fmt.comptimePrint("sclera_{s}", .{side}), eye_owner, "human_base_sclera");
        appendRegion(&result, &index, std.fmt.comptimePrint("iris_{s}", .{side}), eye_owner, "human_base_iris");
        appendRegion(&result, &index, std.fmt.comptimePrint("pupil_{s}", .{side}), eye_owner, "human_base_pupil");
        appendRegion(&result, &index, std.fmt.comptimePrint("cornea_{s}", .{side}), eye_owner, "human_base_cornea");
        inline for (.{ "upper", "lower" }) |lid| {
            inline for (.{ "inner", "center", "outer" }) |section| appendRegion(&result, &index, std.fmt.comptimePrint("eyelid_{s}_{s}_{s}", .{ lid, side, section }), eye_owner, "human_base_skin");
        }
        appendRegion(&result, &index, std.fmt.comptimePrint("ear_{s}", .{side}), std.fmt.comptimePrint("ear_{s}_01", .{side}), "human_base_skin");
    }

    appendRegion(&result, &index, "mouth_external", "mouth", "human_base_lips");
    appendRegion(&result, &index, "mouth_internal", "mouth_cavity", "human_base_oral_mucosa");
    appendRegion(&result, &index, "oral_mucosa", "mouth_cavity", "human_base_oral_mucosa");
    appendRegion(&result, &index, "palate", "gums_palate_upper", "human_base_oral_mucosa");
    appendRegion(&result, &index, "gums_upper", "gums_palate_upper", "human_base_gums");
    appendRegion(&result, &index, "gums_lower", "gums_lower", "human_base_gums");
    appendRegion(&result, &index, "tongue", "tongue", "human_base_tongue");

    inline for (.{ "upper", "lower" }) |arch| {
        const owner = if (std.mem.eql(u8, arch, "upper")) "teeth_upper" else "teeth_lower";
        inline for (.{ "left", "right" }) |side| {
            inline for (.{ "central_incisor", "lateral_incisor", "canine", "premolar_01", "premolar_02", "molar_01", "molar_02", "molar_03" }) |tooth| {
                appendRegion(&result, &index, std.fmt.comptimePrint("tooth_{s}_{s}_{s}", .{ arch, side, tooth }), owner, "human_base_tooth_enamel");
            }
        }
    }

    inline for (.{ "left", "right" }) |side| {
        inline for (.{ "thumb", "index", "middle", "ring", "little" }) |digit| {
            const fingernail = std.fmt.comptimePrint("fingernail_{s}_{s}", .{ digit, side });
            const toenail = std.fmt.comptimePrint("toenail_{s}_{s}", .{ digit, side });
            appendRegion(&result, &index, fingernail, fingernail, "human_base_nails");
            appendRegion(&result, &index, toenail, toenail, "human_base_nails");
        }
    }

    inline for (.{ "anus_external", "perianal", "anal_canal" }) |region_id| appendRegion(&result, &index, region_id, "anus_module_01", "human_base_skin");
    appendRegion(&result, &index, "mons", "vulva_vaginal_canal_module_01", "human_base_skin");
    inline for (.{ "labia_majora", "labia_minora" }) |region_prefix| {
        inline for (.{ "left", "right" }) |side| appendRegion(&result, &index, std.fmt.comptimePrint("{s}_{s}", .{ region_prefix, side }), "vulva_vaginal_canal_module_01", "human_base_skin");
    }
    inline for (.{ "clitoral_region", "urethral_opening", "vaginal_opening", "vestibule", "vaginal_canal" }) |region_id| appendRegion(&result, &index, region_id, "vulva_vaginal_canal_module_01", "human_base_skin");
    inline for (.{ "penis_base", "penis_shaft", "penis_glans" }) |region_id| appendRegion(&result, &index, region_id, "penis_module_01", "human_base_skin");
    inline for (.{ "scrotum", "testicle_left", "testicle_right" }) |region_id| appendRegion(&result, &index, region_id, "scrotum_testicles_module_01", "human_base_skin");

    if (index != region_surface_count) @compileError(std.fmt.comptimePrint("human_base region/surface manifest count is {d}, expected {d}", .{ index, region_surface_count }));
    return result;
}

fn appendRegion(
    result: *[region_surface_count]RegionSurfaceSpec,
    index: *usize,
    region_id: []const u8,
    owner_component_id: []const u8,
    material_instance_id: []const u8,
) void {
    result[index.*] = .{
        .region_id = region_id,
        .owner_component_id = owner_component_id,
        .material_instance_id = material_instance_id,
    };
    index.* += 1;
}

fn buildRegions() [region_surface_count]semantics.Region {
    @setEvalBranchQuota(500_000);
    var result: [region_surface_count]semantics.Region = undefined;
    inline for (region_surface_specs, 0..) |spec, index| {
        result[index] = .{
            .region_id = makeId(identity.RegionId, spec.region_id),
            .display_name = null,
            .owner_component_id = makeId(identity.ComponentId, spec.owner_component_id),
            .semantic_tags = &region_tags,
        };
    }
    return result;
}

fn buildSurfaces() [region_surface_count]semantics.Surface {
    @setEvalBranchQuota(500_000);
    var result: [region_surface_count]semantics.Surface = undefined;
    inline for (region_surface_specs, 0..) |spec, index| {
        result[index] = .{
            .surface_id = makeId(identity.SurfaceId, std.fmt.comptimePrint("{s}_surface", .{spec.region_id})),
            .display_name = null,
            .owner_component_id = makeId(identity.ComponentId, spec.owner_component_id),
            .region_id = makeId(identity.RegionId, spec.region_id),
            .material_instance_id = makeId(identity.MaterialInstanceId, spec.material_instance_id),
            .coordinate_metadata_id = null,
            .visibility_metadata_id = null,
        };
    }
    return result;
}

fn buildMaterialDefinitions() [neutral_material_count]material.MaterialDefinition {
    @setEvalBranchQuota(100_000);
    const property_specs = [_]material.MaterialPropertySpec{.{
        .property_id = makeId(identity.MaterialPropertyId, "base_color"),
        .value_kind = .linear_srgb_rgba,
        .required = true,
    }};
    var result: [neutral_material_count]material.MaterialDefinition = undefined;
    inline for (material_specs, 0..) |spec, index| {
        result[index] = .{
            .material_definition_id = makeId(identity.MaterialDefinitionId, spec.definition_id),
            .display_name = makeDisplayName(spec.definition_display_name),
            .capabilities = &material_capabilities,
            .property_specs = &property_specs,
        };
    }
    return result;
}

fn buildMaterialInstances() [neutral_material_count]material.MaterialInstance {
    @setEvalBranchQuota(100_000);
    var result: [neutral_material_count]material.MaterialInstance = undefined;
    inline for (material_specs, 0..) |spec, index| {
        const properties = [_]material.MaterialProperty{.{
            .property_id = makeId(identity.MaterialPropertyId, "base_color"),
            .value = .{ .linear_srgb_rgba = .{ .channels = spec.color } },
        }};
        result[index] = .{
            .material_instance_id = makeId(identity.MaterialInstanceId, spec.instance_id),
            .display_name = makeDisplayName(spec.instance_display_name),
            .definition_id = makeId(identity.MaterialDefinitionId, spec.definition_id),
            .properties = &properties,
        };
    }
    return result;
}

fn buildVisibilityMetadata() [component_count]visibility.VisibilityCoverageMetadata {
    @setEvalBranchQuota(100_000);
    var result: [component_count]visibility.VisibilityCoverageMetadata = undefined;
    inline for (component_specs, 0..) |spec, index| {
        const enabled = spec.default_state == .enabled;
        result[index] = .{
            .visibility_metadata_id = makeId(identity.VisibilityMetadataId, std.fmt.comptimePrint("{s}_visibility", .{spec.component_id})),
            .subject = .{ .component = makeId(identity.ComponentId, spec.component_id) },
            .component_existence = .present,
            .component_enabled_state = if (enabled) .enabled else .disabled,
            .visibility_state = if (enabled) .visible else .hidden_by_policy,
            .coverage = .{ .value = 0 },
            .coverage_region_id = null,
            .coverage_sources = &.{},
            .representation = .canonical,
        };
    }
    return result;
}

fn makeId(comptime T: type, comptime bytes: []const u8) T {
    return T.init(bytes) catch |id_error| @compileError(@errorName(id_error) ++ ": " ++ bytes);
}

fn makeIds(comptime T: type, comptime values: []const []const u8) [values.len]T {
    var result: [values.len]T = undefined;
    inline for (values, 0..) |value, index| result[index] = makeId(T, value);
    return result;
}

fn makeDisplayName(comptime bytes: []const u8) identity.DisplayName {
    return identity.DisplayName.init(bytes) catch |name_error| @compileError(@errorName(name_error) ++ ": " ++ bytes);
}
