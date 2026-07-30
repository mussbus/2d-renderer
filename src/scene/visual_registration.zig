const std = @import("std");
const math = @import("math");
const sprite = @import("sprite_batch");
const visual = @import("visual_geometry");

pub const structural_epsilon_m: f32 = 0.00001;
pub const axis_epsilon: f32 = 0.00001;
pub const orthogonality_epsilon: f32 = 0.002;
pub const angular_epsilon_radians: f32 = 0.00001;

pub const EndpointRole = enum(u8) {
    point,
    axis_start,
    axis_end,
    proximal,
    distal,
    origin,
    axis_x,
    axis_y,
};

pub const SourcePoint = struct {
    role: EndpointRole,
    landmark: visual.LandmarkKind,
    local: math.Vec2,
};

pub const TargetPoint = struct {
    role: EndpointRole,
    identity: []const u8,
    world: math.Vec2,
};

pub const Definition = struct {
    identity: []const u8,
    binding_mode: visual.RegistrationBindingMode,
    scale_policy: visual.RegistrationScalePolicy,
    mirroring_policy: visual.RegistrationMirroringPolicy,
    failure_policy: FailurePolicy = .fail_closed,
    allows_reflection: bool = false,
    authored_adjustment_radians: f32 = 0,

    pub fn validate(definition: Definition) !void {
        if (definition.identity.len == 0) return error.EmptyRegistrationIdentity;
        if (!std.math.isFinite(definition.authored_adjustment_radians)) {
            return error.InvalidRegistrationAdjustment;
        }
        switch (definition.binding_mode) {
            .point => if (definition.scale_policy != .point_authored)
                return error.RegistrationScalePolicyMismatch,
            .point_axis => if (definition.scale_policy != .point_axis_authored)
                return error.RegistrationScalePolicyMismatch,
            .segment => if (definition.scale_policy != .segment_longitudinal_transverse)
                return error.RegistrationScalePolicyMismatch,
            .frame => if (definition.scale_policy != .frame_axes)
                return error.RegistrationScalePolicyMismatch,
            .mesh_bridge => if (definition.scale_policy != .mesh_bridge)
                return error.RegistrationScalePolicyMismatch,
        }
    }
};

pub const FailurePolicy = enum(u8) {
    fail_closed,
};

pub const Placement = struct {
    request: sprite.SpriteRequest,
    evidence: visual.RegistrationEvidence,
};

pub const PointAxisTarget = struct {
    anchor: TargetPoint,
    axis_identity: []const u8,
    /// Unnormalized production target vector in world XY.
    direction_world: math.Vec2,

    pub fn validate(target: PointAxisTarget) !void {
        try validateTarget(target.anchor);
        if (target.anchor.role != .point) return error.InvalidPointEndpointRole;
        if (target.axis_identity.len == 0) return error.EmptyTargetIdentity;
        if (!target.direction_world.isFinite()) return error.NonFiniteTargetAxis;
        if (target.direction_world.length() <= axis_epsilon) {
            return error.CoincidentTargetAxis;
        }
    }
};

pub fn sourcePoint(
    alpha: visual.AlphaGeometry,
    geometry: visual.Geometry,
    landmark: visual.LandmarkKind,
    role: EndpointRole,
) !SourcePoint {
    const definition = geometry.find(landmark) orelse
        return error.MissingSourceLandmark;
    const local = alpha.visibleUvToLocal(definition.visible_uv);
    const point = SourcePoint{
        .role = role,
        .landmark = landmark,
        .local = .{ .x = local[0], .y = local[1] },
    };
    try validateSource(point);
    return point;
}

pub fn targetPoint(
    identity: []const u8,
    world: ?math.Vec2,
    role: EndpointRole,
) !TargetPoint {
    const target = TargetPoint{
        .role = role,
        .identity = identity,
        .world = world orelse return error.MissingRegistrationTarget,
    };
    try validateTarget(target);
    return target;
}

pub fn requireAuthoritative(evidence: ?visual.RegistrationEvidence) !void {
    const value = evidence orelse return error.RegistrationAuthorityBypassed;
    if (value.authority != .authoritative_registration) {
        return error.RegistrationAuthorityBypassed;
    }
}

pub fn validateSemanticIdentity(
    expected: visual.Side,
    actual: visual.Side,
) !void {
    if (expected == .none or actual == .none or expected != actual) {
        return error.RegistrationSemanticIdentitySwap;
    }
}

pub fn validateResidual(expected: math.Vec2, actual: math.Vec2) !void {
    if (!expected.isFinite() or !actual.isFinite()) {
        return error.NonFiniteRegistrationResidual;
    }
    if (expected.sub(actual).length() > structural_epsilon_m) {
        return error.ExcessiveRegistrationResidual;
    }
}

pub fn solvePoint(
    definition: Definition,
    base: sprite.SpriteRequest,
    source: SourcePoint,
    target: TargetPoint,
    rotation_radians: f32,
    scale: math.Vec2,
) !Placement {
    try definition.validate();
    if (definition.binding_mode != .point) return error.RegistrationBindingModeMismatch;
    if (source.role != .point or target.role != .point) {
        return error.InvalidPointEndpointRole;
    }
    try validateSource(source);
    try validateTarget(target);
    if (!std.math.isFinite(rotation_radians) or !scale.isFinite() or
        @abs(scale.x) <= axis_epsilon or @abs(scale.y) <= axis_epsilon)
    {
        return error.InvalidPointTransform;
    }
    var request = base;
    request.world_position = target.world.toArray();
    request.rotation = rotation_radians + definition.authored_adjustment_radians;
    request.scale = scale.toArray();
    request.pivot = source.local.toArray();
    const points = [_]SourcePoint{source};
    const targets = [_]TargetPoint{target};
    const evidence = try buildEvidence(definition, request, &points, &targets);
    return .{ .request = request, .evidence = evidence };
}

pub fn solvePointAxis(
    definition: Definition,
    base: sprite.SpriteRequest,
    source_anchor: SourcePoint,
    source_axis_start: SourcePoint,
    source_axis_end: SourcePoint,
    target: PointAxisTarget,
    scale: math.Vec2,
) !Placement {
    try definition.validate();
    if (definition.binding_mode != .point_axis) {
        return error.RegistrationBindingModeMismatch;
    }
    if (source_anchor.role != .point or
        source_axis_start.role != .axis_start or
        source_axis_end.role != .axis_end)
    {
        return error.InvalidPointAxisEndpointRole;
    }
    try validateSource(source_anchor);
    try validateSource(source_axis_start);
    try validateSource(source_axis_end);
    try target.validate();
    if (!scale.isFinite() or
        @abs(scale.x) <= axis_epsilon or
        @abs(scale.y) <= axis_epsilon)
    {
        return error.InvalidPointTransform;
    }

    const scaled_source_axis = source_axis_end.local
        .sub(source_axis_start.local)
        .componentMul(scale);
    const source_axis_length = scaled_source_axis.length();
    if (source_axis_length <= axis_epsilon) return error.CoincidentSourceAxis;
    const target_angle = std.math.atan2(
        target.direction_world.y,
        target.direction_world.x,
    );
    const source_angle = std.math.atan2(
        scaled_source_axis.y,
        scaled_source_axis.x,
    );

    var request = base;
    request.world_position = target.anchor.world.toArray();
    request.rotation =
        target_angle - source_angle + definition.authored_adjustment_radians;
    request.scale = scale.toArray();
    request.pivot = source_anchor.local.toArray();

    const points = [_]SourcePoint{source_anchor};
    const targets = [_]TargetPoint{target.anchor};
    var evidence = try buildEvidence(definition, request, &points, &targets);
    const transformed_start = transformPoint(request, source_axis_start.local);
    const transformed_end = transformPoint(request, source_axis_end.local);
    const transformed_axis = transformed_end.sub(transformed_start);
    const transformed_length = transformed_axis.length();
    if (transformed_length <= axis_epsilon) return error.CoincidentTransformedAxis;
    const target_unit = target.direction_world.scale(
        1.0 / target.direction_world.length(),
    );
    const expected_end = transformed_start.add(target_unit.scale(transformed_length));
    const endpoint_residual = transformed_end.sub(expected_end).length();
    const angular_residual = @abs(shortestAngularDelta(
        std.math.atan2(target.direction_world.y, target.direction_world.x),
        std.math.atan2(transformed_axis.y, transformed_axis.x),
    ));
    if (!std.math.isFinite(endpoint_residual) or
        endpoint_residual > structural_epsilon_m or
        !std.math.isFinite(angular_residual) or
        angular_residual > angular_epsilon_radians)
    {
        return error.ExcessiveRegistrationResidual;
    }
    evidence.axis = .{
        .source_start_landmark = source_axis_start.landmark,
        .source_end_landmark = source_axis_end.landmark,
        .reference_identity = target.axis_identity,
        .source_start_local = source_axis_start.local.toArray(),
        .source_end_local = source_axis_end.local.toArray(),
        .reference_vector_world = target.direction_world,
        .transformed_start_world = transformed_start,
        .transformed_end_world = transformed_end,
        .expected_end_world = expected_end,
        .endpoint_residual_m = endpoint_residual,
        .angular_residual_radians = angular_residual,
        .threshold_radians = angular_epsilon_radians,
    };
    return .{ .request = request, .evidence = evidence };
}

pub fn solveSegment(
    definition: Definition,
    base: sprite.SpriteRequest,
    source_proximal: SourcePoint,
    source_distal: SourcePoint,
    target_proximal: TargetPoint,
    target_distal: TargetPoint,
    transverse_scale: f32,
    reflect_transverse: bool,
) !Placement {
    try definition.validate();
    if (definition.binding_mode != .segment) return error.RegistrationBindingModeMismatch;
    if (source_proximal.role != .proximal or source_distal.role != .distal) {
        return error.InvalidSourceEndpointOrder;
    }
    if (target_proximal.role != .proximal or target_distal.role != .distal) {
        return error.InvalidTargetEndpointOrder;
    }
    try validateSource(source_proximal);
    try validateSource(source_distal);
    try validateTarget(target_proximal);
    try validateTarget(target_distal);
    if (!std.math.isFinite(transverse_scale) or @abs(transverse_scale) <= axis_epsilon) {
        return error.InvalidTransverseScale;
    }
    if (reflect_transverse and !definition.allows_reflection) {
        return error.InvalidRegistrationReflection;
    }

    const source_axis = source_distal.local.sub(source_proximal.local);
    const target_axis = target_distal.world.sub(target_proximal.world);
    const source_length = source_axis.length();
    const target_length = target_axis.length();
    if (source_length <= axis_epsilon) return error.CoincidentSourceSegment;
    if (target_length <= axis_epsilon) return error.CoincidentTargetSegment;
    const source_is_x = @abs(source_axis.x) >= @abs(source_axis.y);
    if (source_is_x) {
        if (@abs(source_axis.y) > axis_epsilon) return error.ObliqueSourceSegment;
    } else if (@abs(source_axis.x) > axis_epsilon) {
        return error.ObliqueSourceSegment;
    }

    const longitudinal_scale = target_length / source_length;
    const transverse_sign: f32 = if (reflect_transverse) -1 else 1;
    const scale = if (source_is_x)
        math.Vec2{
            .x = longitudinal_scale,
            .y = transverse_scale * transverse_sign,
        }
    else
        math.Vec2{
            .x = transverse_scale * transverse_sign,
            .y = longitudinal_scale,
        };
    const source_angle = std.math.atan2(
        source_axis.y * scale.y,
        source_axis.x * scale.x,
    );
    const target_angle = std.math.atan2(target_axis.y, target_axis.x);
    var request = base;
    request.world_position = target_proximal.world.toArray();
    request.rotation =
        target_angle - source_angle + definition.authored_adjustment_radians;
    request.scale = scale.toArray();
    request.pivot = source_proximal.local.toArray();
    const points = [_]SourcePoint{ source_proximal, source_distal };
    const targets = [_]TargetPoint{ target_proximal, target_distal };
    const evidence = try buildEvidence(definition, request, &points, &targets);
    return .{ .request = request, .evidence = evidence };
}

pub fn solveFrame(
    definition: Definition,
    base: sprite.SpriteRequest,
    source_origin: SourcePoint,
    source_axis_x: SourcePoint,
    source_axis_y: SourcePoint,
    target_origin: TargetPoint,
    target_axis_x: TargetPoint,
    target_axis_y: TargetPoint,
) !Placement {
    try definition.validate();
    if (definition.binding_mode != .frame) return error.RegistrationBindingModeMismatch;
    if (source_origin.role != .origin or source_axis_x.role != .axis_x or
        source_axis_y.role != .axis_y)
    {
        return error.InvalidSourceFrameRoles;
    }
    if (target_origin.role != .origin or target_axis_x.role != .axis_x or
        target_axis_y.role != .axis_y)
    {
        return error.InvalidTargetFrameRoles;
    }
    try validateSource(source_origin);
    try validateSource(source_axis_x);
    try validateSource(source_axis_y);
    try validateTarget(target_origin);
    try validateTarget(target_axis_x);
    try validateTarget(target_axis_y);

    const source_x = source_axis_x.local.sub(source_origin.local);
    const source_y = source_axis_y.local.sub(source_origin.local);
    const target_x = target_axis_x.world.sub(target_origin.world);
    const target_y = target_axis_y.world.sub(target_origin.world);
    const source_x_length = source_x.length();
    const source_y_length = source_y.length();
    const target_x_length = target_x.length();
    const target_y_length = target_y.length();
    if (source_x_length <= axis_epsilon or source_y_length <= axis_epsilon) {
        return error.DegenerateSourceFrame;
    }
    if (target_x_length <= axis_epsilon or target_y_length <= axis_epsilon) {
        return error.DegenerateTargetFrame;
    }
    const source_cross = cross(source_x, source_y);
    const target_cross = cross(target_x, target_y);
    if (@abs(source_cross) <= axis_epsilon) return error.DegenerateSourceFrame;
    if (@abs(target_cross) <= axis_epsilon) return error.DegenerateTargetFrame;
    const reflected = std.math.signbit(source_cross) != std.math.signbit(target_cross);
    if (reflected and !definition.allows_reflection) {
        return error.InvalidRegistrationReflection;
    }
    const source_orthogonality =
        @abs(source_x.dot(source_y) / (source_x_length * source_y_length));
    const target_orthogonality =
        @abs(target_x.dot(target_y) / (target_x_length * target_y_length));
    if (source_orthogonality > orthogonality_epsilon) {
        return error.NonOrthogonalSourceFrame;
    }
    if (target_orthogonality > orthogonality_epsilon) {
        return error.NonOrthogonalTargetFrame;
    }

    var scale = math.Vec2{
        .x = target_x_length / source_x_length,
        .y = target_y_length / source_y_length,
    };
    if (reflected) scale.y = -scale.y;
    const source_x_scaled = math.Vec2{
        .x = source_x.x * scale.x,
        .y = source_x.y * scale.y,
    };
    var request = base;
    request.world_position = target_origin.world.toArray();
    request.rotation = std.math.atan2(target_x.y, target_x.x) -
        std.math.atan2(source_x_scaled.y, source_x_scaled.x) +
        definition.authored_adjustment_radians;
    request.scale = scale.toArray();
    request.pivot = source_origin.local.toArray();
    const points = [_]SourcePoint{ source_origin, source_axis_x, source_axis_y };
    const targets = [_]TargetPoint{ target_origin, target_axis_x, target_axis_y };
    const evidence = try buildEvidence(definition, request, &points, &targets);
    return .{ .request = request, .evidence = evidence };
}

pub fn validateMeshBridgeDefinition(definition: Definition) !void {
    try definition.validate();
    if (definition.binding_mode != .mesh_bridge) {
        return error.RegistrationBindingModeMismatch;
    }
}

fn buildEvidence(
    definition: Definition,
    request: sprite.SpriteRequest,
    sources: []const SourcePoint,
    targets: []const TargetPoint,
) !visual.RegistrationEvidence {
    if (sources.len != targets.len or
        sources.len == 0 or
        sources.len > visual.registration_point_capacity)
    {
        return error.InvalidRegistrationPointCount;
    }
    var points: [visual.registration_point_capacity]visual.RegistrationPoint =
        undefined;
    var maximum_residual: f32 = 0;
    for (sources, targets, 0..) |source, target, index| {
        const transformed_array = sprite.localPointToWorld(
            request,
            source.local.toArray(),
        );
        const transformed = math.Vec2{
            .x = transformed_array[0],
            .y = transformed_array[1],
        };
        const residual = transformed.sub(target.world).length();
        if (!std.math.isFinite(residual) or residual > structural_epsilon_m) {
            return error.ExcessiveRegistrationResidual;
        }
        maximum_residual = @max(maximum_residual, residual);
        points[index] = .{
            .source_landmark = source.landmark,
            .target_identity = target.identity,
            .source_local = source.local.toArray(),
            .target_world = target.world,
            .transformed_world = transformed,
            .residual_m = residual,
        };
    }
    return .{
        .identity = definition.identity,
        .binding_mode = definition.binding_mode,
        .authority = .authoritative_registration,
        .scale_policy = definition.scale_policy,
        .mirroring_policy = definition.mirroring_policy,
        .threshold_m = structural_epsilon_m,
        .point_count = @intCast(sources.len),
        .points = points,
        .maximum_residual_m = maximum_residual,
    };
}

fn validateSource(source: SourcePoint) !void {
    if (!source.local.isFinite()) return error.NonFiniteSourcePoint;
}

fn validateTarget(target: TargetPoint) !void {
    if (target.identity.len == 0) return error.EmptyTargetIdentity;
    if (!target.world.isFinite()) return error.NonFiniteTargetPoint;
}

fn transformPoint(request: sprite.SpriteRequest, local: math.Vec2) math.Vec2 {
    const transformed = sprite.localPointToWorld(request, local.toArray());
    return .{ .x = transformed[0], .y = transformed[1] };
}

fn shortestAngularDelta(from: f32, to: f32) f32 {
    var delta = @mod(to - from + std.math.pi, std.math.tau);
    if (delta < 0) delta += std.math.tau;
    return delta - std.math.pi;
}

fn cross(a: math.Vec2, b: math.Vec2) f32 {
    return a.x * b.y - a.y * b.x;
}
