const std = @import("std");
const attachment = @import("attachment.zig");
const component = @import("component.zig");
const coordinate = @import("coordinate.zig");
const definition = @import("definition.zig");
const identity = @import("identity.zig");
const material = @import("material.zig");
const math3d = @import("math3d.zig");
const morphology = @import("morphology.zig");
const rig = @import("rig.zig");
const semantics = @import("semantics.zig");
const visibility = @import("visibility.zig");

pub const ParseError = error{
    OutOfMemory,
    InvalidJson,
    ExpectedObject,
    ExpectedArray,
    ExpectedString,
    ExpectedBoolean,
    ExpectedNumber,
    InvalidNumber,
    IntegerOutOfRange,
    InvalidEnumValue,
    InvalidCanonicalId,
    InvalidDisplayName,
    MissingField,
    UnknownField,
    InvalidArrayLength,
    InvalidTaggedValue,
};

pub const ParsedDefinition = struct {
    parsed_json: std.json.Parsed(std.json.Value),
    value: definition.CanonicalCreatureDefinition,

    pub fn deinit(self: *ParsedDefinition) void {
        self.parsed_json.deinit();
        self.* = undefined;
    }
};

const AuthoringDocument = struct {
    schema_identity: identity.SchemaIdentity,
    asset_identity: identity.AssetIdentity,
    compiler_identity: identity.CompilerIdentity,
    coordinate_contract: ?coordinate.CoordinateContract = null,
    components: []const component.Component = &.{},
    bones: []const rig.Bone = &.{},
    joints: []const rig.Joint = &.{},
    controls: []const rig.Control = &.{},
    anchors: []const attachment.Anchor = &.{},
    sockets: []const attachment.Socket = &.{},
    mount_anchors: []const attachment.MountAnchor = &.{},
    attachments: []const attachment.Attachment = &.{},
    regions: []const semantics.Region = &.{},
    surfaces: []const semantics.Surface = &.{},
    landmarks: []const semantics.Landmark = &.{},
    shared_seams: []const semantics.SharedSeam = &.{},
    interaction_sites: []const semantics.InteractionSite = &.{},
    effectors: []const semantics.Effector = &.{},
    morphology_parameters: []const morphology.MorphologyParameter = &.{},
    morphology_bindings: []const morphology.MorphologyBinding = &.{},
    morphology_dependencies: []const morphology.ParameterDependency = &.{},
    morphology_provenance: []const morphology.ProvenanceTrace = &.{},
    material_definitions: []const material.MaterialDefinition = &.{},
    material_instances: []const material.MaterialInstance = &.{},
    visibility_metadata: []const visibility.VisibilityCoverageMetadata = &.{},
};

pub fn parse(
    allocator: std.mem.Allocator,
    source_bytes: []const u8,
) ParseError!ParsedDefinition {
    var parsed_json = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        source_bytes,
        .{ .parse_numbers = false },
    ) catch |parse_error| switch (parse_error) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidJson,
    };
    errdefer parsed_json.deinit();

    const document = try parseValue(
        AuthoringDocument,
        parsed_json.arena.allocator(),
        parsed_json.value,
    );
    return .{
        .parsed_json = parsed_json,
        .value = .{
            .schema_identity = document.schema_identity,
            .asset_identity = document.asset_identity,
            .compiler_identity = document.compiler_identity,
            .coordinate_contract = document.coordinate_contract,
            .components = document.components,
            .bones = document.bones,
            .joints = document.joints,
            .controls = document.controls,
            .anchors = document.anchors,
            .sockets = document.sockets,
            .mount_anchors = document.mount_anchors,
            .attachments = document.attachments,
            .regions = document.regions,
            .surfaces = document.surfaces,
            .landmarks = document.landmarks,
            .shared_seams = document.shared_seams,
            .interaction_sites = document.interaction_sites,
            .effectors = document.effectors,
            .morphology_parameters = document.morphology_parameters,
            .morphology_bindings = document.morphology_bindings,
            .morphology_graph = .{
                .dependencies = document.morphology_dependencies,
                .provenance = document.morphology_provenance,
            },
            .material_definitions = document.material_definitions,
            .material_instances = document.material_instances,
            .visibility_metadata = document.visibility_metadata,
        },
    };
}

fn parseValue(
    comptime T: type,
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!T {
    if (comptime isTypedId(T)) return parseTypedId(T, json_value);
    if (comptime T == identity.DisplayName) return parseDisplayName(json_value);
    if (comptime T == math3d.Vec3) return parseVec3(json_value);
    if (comptime T == math3d.Quaternion) return parseQuaternion(json_value);
    if (comptime T == visibility.NormalizedCoverage) {
        return .{ .value = try parseFloat(f32, json_value) };
    }
    if (comptime T == attachment.TransformDriver or
        T == rig.DrivenTarget or
        T == semantics.SemanticOwner or
        T == visibility.VisibilitySubject)
    {
        return parseTaggedIdUnion(T, allocator, json_value);
    }
    if (comptime T == rig.ControlValue) return parseControlValue(allocator, json_value);
    if (comptime T == morphology.ParameterValue) return parseParameterValue(allocator, json_value);
    if (comptime T == morphology.ParameterDomain) return parseParameterDomain(allocator, json_value);
    if (comptime T == morphology.ResponseCurve) return parseResponseCurve(allocator, json_value);
    if (comptime T == morphology.Symmetry) return parseSymmetry(allocator, json_value);
    if (comptime T == morphology.BindingTarget) return parseBindingTarget(allocator, json_value);
    if (comptime T == morphology.ProvenanceSource) return parseProvenanceSource(allocator, json_value);
    if (comptime T == material.MaterialPropertyValue) return parseMaterialValue(allocator, json_value);
    if (comptime T == visibility.RepresentationSelection) return parseRepresentationSelection(allocator, json_value);

    return switch (@typeInfo(T)) {
        .bool => switch (json_value) {
            .bool => |value| value,
            else => error.ExpectedBoolean,
        },
        .float => parseFloat(T, json_value),
        .int => parseInteger(T, json_value),
        .@"enum" => parseEnum(T, json_value),
        .optional => |optional_info| switch (json_value) {
            .null => null,
            else => try parseValue(optional_info.child, allocator, json_value),
        },
        .pointer => |pointer_info| switch (pointer_info.size) {
            .slice => try parseSlice(T, pointer_info.child, allocator, json_value),
            else => @compileError("canonical JSON parser only supports slice pointers"),
        },
        .array => |array_info| try parseArray(T, array_info.child, allocator, json_value),
        .@"struct" => try parseStruct(T, allocator, json_value),
        else => @compileError("unsupported canonical JSON type: " ++ @typeName(T)),
    };
}

fn isTypedId(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "kind_name"),
        else => false,
    };
}

fn parseTypedId(comptime T: type, json_value: std.json.Value) ParseError!T {
    const bytes = try expectString(json_value);
    return T.init(bytes) catch error.InvalidCanonicalId;
}

fn parseDisplayName(json_value: std.json.Value) ParseError!identity.DisplayName {
    const bytes = try expectString(json_value);
    return identity.DisplayName.init(bytes) catch error.InvalidDisplayName;
}

fn parseVec3(json_value: std.json.Value) ParseError!math3d.Vec3 {
    const items = try expectArray(json_value);
    if (items.len != 3) return error.InvalidArrayLength;
    return .{
        .x = try parseFloat(f32, items[0]),
        .y = try parseFloat(f32, items[1]),
        .z = try parseFloat(f32, items[2]),
    };
}

fn parseQuaternion(json_value: std.json.Value) ParseError!math3d.Quaternion {
    const items = try expectArray(json_value);
    if (items.len != 4) return error.InvalidArrayLength;
    return .{
        .x = try parseFloat(f32, items[0]),
        .y = try parseFloat(f32, items[1]),
        .z = try parseFloat(f32, items[2]),
        .w = try parseFloat(f32, items[3]),
    };
}

fn parseTaggedIdUnion(
    comptime T: type,
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!T {
    const object = try expectObject(json_value);
    try requireOnlyFields(object, &.{ "type", "id" });
    const tag_name = try expectString(try requireField(object, "type"));
    const id_value = try requireField(object, "id");
    inline for (@typeInfo(T).@"union".fields) |field| {
        if (std.mem.eql(u8, field.name, tag_name)) {
            return @unionInit(T, field.name, try parseValue(field.type, allocator, id_value));
        }
    }
    return error.InvalidTaggedValue;
}

fn parseControlValue(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!rig.ControlValue {
    const object = try expectObject(json_value);
    try requireOnlyFields(object, &.{ "value_type", "value" });
    const tag = try expectString(try requireField(object, "value_type"));
    const value = try requireField(object, "value");
    if (std.mem.eql(u8, tag, "scalar")) return .{ .scalar = try parseFloat(f32, value) };
    if (std.mem.eql(u8, tag, "vector")) return .{ .vector = try parseValue(math3d.Vec3, allocator, value) };
    if (std.mem.eql(u8, tag, "quaternion")) return .{ .quaternion = try parseValue(math3d.Quaternion, allocator, value) };
    if (std.mem.eql(u8, tag, "transform")) return .{ .transform = try parseValue(math3d.LocalTransform, allocator, value) };
    return error.InvalidTaggedValue;
}

fn parseParameterValue(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!morphology.ParameterValue {
    const object = try expectObject(json_value);
    try requireOnlyFields(object, &.{ "value_type", "value" });
    const tag = try expectString(try requireField(object, "value_type"));
    const value = try requireField(object, "value");
    if (std.mem.eql(u8, tag, "float")) return .{ .float = try parseFloat(f32, value) };
    if (std.mem.eql(u8, tag, "integer")) return .{ .integer = try parseInteger(i64, value) };
    if (std.mem.eql(u8, tag, "enumeration")) return .{ .enumeration = try parseValue(identity.EnumValueId, allocator, value) };
    if (std.mem.eql(u8, tag, "boolean")) return .{ .boolean = try parseValue(bool, allocator, value) };
    return error.InvalidTaggedValue;
}

fn parseParameterDomain(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!morphology.ParameterDomain {
    const object = try expectObject(json_value);
    const tag = try expectString(try requireField(object, "value_type"));
    if (std.mem.eql(u8, tag, "float")) {
        try requireOnlyFields(object, &.{ "value_type", "minimum", "maximum" });
        return .{ .float = .{
            .minimum = try parseFloat(f32, try requireField(object, "minimum")),
            .maximum = try parseFloat(f32, try requireField(object, "maximum")),
        } };
    }
    if (std.mem.eql(u8, tag, "integer")) {
        try requireOnlyFields(object, &.{ "value_type", "minimum", "maximum" });
        return .{ .integer = .{
            .minimum = try parseInteger(i64, try requireField(object, "minimum")),
            .maximum = try parseInteger(i64, try requireField(object, "maximum")),
        } };
    }
    if (std.mem.eql(u8, tag, "enumeration")) {
        try requireOnlyFields(object, &.{ "value_type", "values" });
        return .{ .enumeration = try parseValue(
            []const identity.EnumValueId,
            allocator,
            try requireField(object, "values"),
        ) };
    }
    if (std.mem.eql(u8, tag, "boolean")) {
        try requireOnlyFields(object, &.{ "value_type", "allows_false", "allows_true" });
        return .{ .boolean = .{
            .allows_false = try parseValue(bool, allocator, try requireField(object, "allows_false")),
            .allows_true = try parseValue(bool, allocator, try requireField(object, "allows_true")),
        } };
    }
    return error.InvalidTaggedValue;
}

fn parseResponseCurve(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!morphology.ResponseCurve {
    const object = try expectObject(json_value);
    const tag = try expectString(try requireField(object, "curve_type"));
    if (std.mem.eql(u8, tag, "linear")) {
        try requireOnlyFields(object, &.{"curve_type"});
        return .linear;
    }
    if (std.mem.eql(u8, tag, "smooth")) {
        try requireOnlyFields(object, &.{"curve_type"});
        return .smooth;
    }
    if (std.mem.eql(u8, tag, "custom_reference")) {
        try requireOnlyFields(object, &.{ "curve_type", "curve_id" });
        return .{ .custom = .{ .reference = try parseValue(
            identity.ResponseCurveId,
            allocator,
            try requireField(object, "curve_id"),
        ) } };
    }
    if (std.mem.eql(u8, tag, "custom_data")) {
        try requireOnlyFields(object, &.{ "curve_type", "points" });
        return .{ .custom = .{ .authored_data = try parseValue(
            []const morphology.ResponseCurvePoint,
            allocator,
            try requireField(object, "points"),
        ) } };
    }
    return error.InvalidTaggedValue;
}

fn parseSymmetry(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!morphology.Symmetry {
    const object = try expectObject(json_value);
    const tag = try expectString(try requireField(object, "symmetry_type"));
    if (std.mem.eql(u8, tag, "centered")) {
        try requireOnlyFields(object, &.{"symmetry_type"});
        return .centered;
    }
    if (std.mem.eql(u8, tag, "mirrored") or std.mem.eql(u8, tag, "independent_pair")) {
        try requireOnlyFields(object, &.{
            "symmetry_type",
            "left_parameter_id",
            "right_parameter_id",
            "linked_by_default",
        });
        const pair = morphology.PairedParameterIds{
            .left_parameter_id = try parseValue(identity.MorphologyParameterId, allocator, try requireField(object, "left_parameter_id")),
            .right_parameter_id = try parseValue(identity.MorphologyParameterId, allocator, try requireField(object, "right_parameter_id")),
            .linked_by_default = try parseValue(bool, allocator, try requireField(object, "linked_by_default")),
        };
        return if (std.mem.eql(u8, tag, "mirrored")) .{ .mirrored = pair } else .{ .independent_pair = pair };
    }
    return error.InvalidTaggedValue;
}

fn parseBindingTarget(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!morphology.BindingTarget {
    const object = try expectObject(json_value);
    try requireOnlyFields(object, &.{ "target_type", "target_id", "property_id" });
    const tag_name = try expectString(try requireField(object, "target_type"));
    const target_id = try requireField(object, "target_id");
    const property_id = try parseValue(identity.PropertyId, allocator, try requireField(object, "property_id"));
    inline for (@typeInfo(morphology.BindingTarget).@"union".fields) |field| {
        if (std.mem.eql(u8, field.name, tag_name)) {
            const address_type = field.type;
            const id_type = @typeInfo(address_type).@"struct".fields[0].type;
            return @unionInit(morphology.BindingTarget, field.name, address_type{
                .target_id = try parseValue(id_type, allocator, target_id),
                .property_id = property_id,
            });
        }
    }
    return error.InvalidTaggedValue;
}

fn parseProvenanceSource(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!morphology.ProvenanceSource {
    const object = try expectObject(json_value);
    const tag_name = try expectString(try requireField(object, "source_type"));
    if (std.mem.eql(u8, tag_name, "manual_adjustment")) {
        try requireOnlyFields(object, &.{"source_type"});
        return .manual_adjustment;
    }
    try requireOnlyFields(object, &.{ "source_type", "source_id" });
    const source_id = try requireField(object, "source_id");
    inline for (@typeInfo(morphology.ProvenanceSource).@"union".fields) |field| {
        if (field.type != void and std.mem.eql(u8, field.name, tag_name)) {
            return @unionInit(
                morphology.ProvenanceSource,
                field.name,
                try parseValue(field.type, allocator, source_id),
            );
        }
    }
    return error.InvalidTaggedValue;
}

fn parseMaterialValue(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!material.MaterialPropertyValue {
    const object = try expectObject(json_value);
    const tag = try expectString(try requireField(object, "value_type"));
    if (std.mem.eql(u8, tag, "linear_srgb_rgba")) {
        try requireOnlyFields(object, &.{ "value_type", "channels" });
        return .{ .linear_srgb_rgba = .{
            .channels = try parseValue([4]f32, allocator, try requireField(object, "channels")),
        } };
    }
    try requireOnlyFields(object, &.{ "value_type", "value" });
    const value = try requireField(object, "value");
    if (std.mem.eql(u8, tag, "scalar")) return .{ .scalar = try parseFloat(f32, value) };
    if (std.mem.eql(u8, tag, "boolean")) return .{ .boolean = try parseValue(bool, allocator, value) };
    if (std.mem.eql(u8, tag, "vector4")) return .{ .vector4 = try parseValue([4]f32, allocator, value) };
    if (std.mem.eql(u8, tag, "response_reference")) return .{ .response_reference = try parseValue(identity.MaterialResponseId, allocator, value) };
    if (std.mem.eql(u8, tag, "detail_reference")) return .{ .detail_reference = try parseValue(identity.MaterialDetailId, allocator, value) };
    return error.InvalidTaggedValue;
}

fn parseRepresentationSelection(
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!visibility.RepresentationSelection {
    const object = try expectObject(json_value);
    const tag = try expectString(try requireField(object, "selection_type"));
    if (std.mem.eql(u8, tag, "canonical")) {
        try requireOnlyFields(object, &.{"selection_type"});
        return .canonical;
    }
    try requireOnlyFields(object, &.{ "selection_type", "variant_id" });
    const variant_id = try parseValue(
        identity.RepresentationVariantId,
        allocator,
        try requireField(object, "variant_id"),
    );
    if (std.mem.eql(u8, tag, "variant")) return .{ .variant = variant_id };
    if (std.mem.eql(u8, tag, "substitution")) return .{ .substitution = variant_id };
    return error.InvalidTaggedValue;
}

fn parseStruct(
    comptime T: type,
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!T {
    const object = try expectObject(json_value);
    const fields = @typeInfo(T).@"struct".fields;

    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        var known = false;
        inline for (fields) |field| {
            if (std.mem.eql(u8, entry.key_ptr.*, field.name)) known = true;
        }
        if (!known) return error.UnknownField;
    }

    var result: T = undefined;
    inline for (fields) |field| {
        if (object.get(field.name)) |field_value| {
            @field(result, field.name) = try parseValue(field.type, allocator, field_value);
        } else if (field.defaultValue()) |default_value| {
            @field(result, field.name) = default_value;
        } else {
            return error.MissingField;
        }
    }
    return result;
}

fn parseSlice(
    comptime T: type,
    comptime Child: type,
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!T {
    const items = try expectArray(json_value);
    const result = try allocator.alloc(Child, items.len);
    for (items, 0..) |item, index| {
        result[index] = try parseValue(Child, allocator, item);
    }
    return result;
}

fn parseArray(
    comptime T: type,
    comptime Child: type,
    allocator: std.mem.Allocator,
    json_value: std.json.Value,
) ParseError!T {
    const items = try expectArray(json_value);
    if (items.len != @typeInfo(T).array.len) return error.InvalidArrayLength;
    var result: T = undefined;
    for (items, 0..) |item, index| {
        result[index] = try parseValue(Child, allocator, item);
    }
    return result;
}

fn parseFloat(comptime T: type, json_value: std.json.Value) ParseError!T {
    const value = switch (json_value) {
        .number_string => |bytes| std.fmt.parseFloat(T, bytes) catch return error.InvalidNumber,
        .integer => |integer| @as(T, @floatFromInt(integer)),
        .float => |float| @as(T, @floatCast(float)),
        else => return error.ExpectedNumber,
    };
    if (!std.math.isFinite(value)) return error.InvalidNumber;
    return value;
}

fn parseInteger(comptime T: type, json_value: std.json.Value) ParseError!T {
    return switch (json_value) {
        .number_string => |bytes| std.fmt.parseInt(T, bytes, 10) catch |parse_error| switch (parse_error) {
            error.Overflow => error.IntegerOutOfRange,
            error.InvalidCharacter => error.InvalidNumber,
        },
        .integer => |integer| std.math.cast(T, integer) orelse error.IntegerOutOfRange,
        else => error.ExpectedNumber,
    };
}

fn parseEnum(comptime T: type, json_value: std.json.Value) ParseError!T {
    const name = try expectString(json_value);
    return std.meta.stringToEnum(T, name) orelse error.InvalidEnumValue;
}

fn expectString(json_value: std.json.Value) ParseError![]const u8 {
    return switch (json_value) {
        .string => |bytes| bytes,
        else => error.ExpectedString,
    };
}

fn expectArray(json_value: std.json.Value) ParseError![]const std.json.Value {
    return switch (json_value) {
        .array => |array| array.items,
        else => error.ExpectedArray,
    };
}

fn expectObject(json_value: std.json.Value) ParseError!std.json.ObjectMap {
    return switch (json_value) {
        .object => |object| object,
        else => error.ExpectedObject,
    };
}

fn requireField(object: std.json.ObjectMap, name: []const u8) ParseError!std.json.Value {
    return object.get(name) orelse error.MissingField;
}

fn requireOnlyFields(
    object: std.json.ObjectMap,
    allowed_fields: []const []const u8,
) ParseError!void {
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        var allowed = false;
        for (allowed_fields) |field| {
            if (std.mem.eql(u8, field, entry.key_ptr.*)) {
                allowed = true;
                break;
            }
        }
        if (!allowed) return error.UnknownField;
    }
}
