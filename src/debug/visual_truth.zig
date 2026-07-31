const std = @import("std");
const math = @import("math");
const collider = @import("collider");
const skeleton = @import("skeleton");
const appearance = @import("appearance");
const anatomy = @import("anatomy");
const component_graph = @import("component_graph");
const character = @import("character");
const humanoid = @import("humanoid");
const character_art = @import("character_art");
const presentation_pose = @import("presentation_pose");
const camera2d = @import("camera2d");
const sprite = @import("sprite_batch");
const debug_draw = @import("debug_draw");
const visual_geometry = @import("visual_geometry");
const visual_geometry_overlay = @import("visual_geometry_overlay");

pub const schema_version: u32 = 4;
pub const character_capacity: usize = 2;
pub const mismatch_capacity: usize = visual_geometry.trace_capacity *
    visual_geometry.landmark_capacity;
pub const text_capacity: usize = 63;
pub const registration_tolerance_px: f32 = 2.0;

pub const Mode = enum(u8) {
    off,
    rig,
    rig_registration,
    all_diagnostics,

    pub fn next(mode: Mode) Mode {
        return switch (mode) {
            .off => .rig,
            .rig => .rig_registration,
            .rig_registration => .all_diagnostics,
            .all_diagnostics => .off,
        };
    }

    pub fn includesRegistration(mode: Mode) bool {
        return mode == .rig_registration or mode == .all_diagnostics;
    }
};

pub const CharacterRole = enum(u8) {
    controlled,
    passive,
};

pub const MismatchResult = enum(u8) {
    pass,
    fail,
    not_applicable,
};

pub const Text = extern struct {
    length: u8 = 0,
    bytes: [text_capacity]u8 = [_]u8{0} ** text_capacity,

    pub fn init(value: []const u8) !Text {
        if (value.len > text_capacity) return error.VisualTruthTextTooLong;
        var result = Text{ .length = @intCast(value.len) };
        @memcpy(result.bytes[0..value.len], value);
        return result;
    }

    pub fn slice(value: *const Text) []const u8 {
        return value.bytes[0..value.length];
    }
};

pub const Transform = extern struct {
    position: math.Vec2,
    rotation_radians: f32,
    scale: math.Vec2,

    pub fn fromLocal(value: math.Transform2D) Transform {
        return .{
            .position = value.translation,
            .rotation_radians = value.rotation_radians,
            .scale = value.scale,
        };
    }

    pub fn fromWorld(value: math.Mat3) !Transform {
        const x_axis = math.Vec2{ .x = value.values[0], .y = value.values[1] };
        const y_axis = math.Vec2{ .x = value.values[3], .y = value.values[4] };
        const determinant = x_axis.x * y_axis.y - x_axis.y * y_axis.x;
        var x_scale = x_axis.length();
        const y_scale = y_axis.length();
        if (!std.math.isFinite(x_scale) or !std.math.isFinite(y_scale) or
            !std.math.isFinite(determinant))
        {
            return error.NonFiniteVisualTruthTransform;
        }
        if (determinant < 0) x_scale = -x_scale;
        return .{
            .position = value.translationPart(),
            .rotation_radians = value.rotationRadians(),
            .scale = .{ .x = x_scale, .y = y_scale },
        };
    }
};

pub const Bone = struct {
    index: u16,
    name: Text,
    semantic: skeleton.BoneSemantic,
    parent: ?u16,
    local: Transform,
    canonical_world: Transform,
    projected_world: Transform,
    position_delta_m: f32,
    angular_delta_radians: f32,
};

pub const Socket = struct {
    index: u16,
    name: Text,
    semantic: skeleton.SocketSemantic,
    parent_bone: u16,
    canonical_world: Transform,
    projected_world: Transform,
};

pub const AttachmentPoint = struct {
    index: u16,
    name: Text,
    parent_index: ?u16,
    hierarchy_depth: u8,
    canonical_world: Transform,
    projected_world: Transform,
};

pub const Part = struct {
    index: u16,
    name: Text,
    definition_name: Text,
    semantic_role: Text,
    parent_part: ?u16,
    parent_socket: ?u16,
    hierarchy_depth: u8,
    active: bool,
    articulation_module: ?u16,
    binding_mode: anatomy.BindingMode,
    connection_mode: anatomy.ConnectionMode,
    measured_gap_m: f32,
    minimum_gap_m: f32,
    maximum_gap_m: f32,
    topology_status: anatomy.TopologyStatus,
    material_slot: Text,
    morphology_response: Text,
    required_views: anatomy.ViewSupport,
    selected_variant: Text,
    bound_visual_count: u8,
    bound_visuals: [8]Text,
    canonical_world: Transform,
    projected_world: Transform,
    connection_parent_endpoint: math.Vec2,
    connection_child_endpoint: math.Vec2,
    connection_gap_vector: math.Vec2,
    target_gap_m: f32,
    acceptance_gap_px: f32,
    connection_result: MismatchResult,
    parent_socket_name: Text,
    child_root_name: Text,
};

pub const PartSocket = struct {
    index: u16,
    name: Text,
    owner_part: u16,
    accepted_child_tag: Text,
    role: Text,
    capacity: u16,
    occupancy: u16,
    supported_connections: anatomy.ConnectionModeSupport,
    canonical_world: Transform,
    projected_world: Transform,
};

pub const ModuleJoint = struct {
    index: u16,
    name: Text,
    module_index: u16,
    owner_component: ?u16,
    active: bool,
    parent_joint: ?u16,
    canonical_world: Transform,
    projected_world: Transform,
};

pub const ModuleSocket = struct {
    index: u16,
    name: Text,
    module_index: u16,
    owner_component: ?u16,
    active: bool,
    parent_joint: ?u16,
    canonical_world: Transform,
    projected_world: Transform,
};

pub const Character = struct {
    id: u32 = 0,
    role: CharacterRole = .passive,
    root: math.Vec2 = math.Vec2.zero,
    has_controller: bool = false,
    controller_position: math.Vec2 = math.Vec2.zero,
    velocity: math.Vec2 = math.Vec2.zero,
    facing: humanoid.Facing = .right,
    grounded: bool = false,
    support_collider: ?u16 = null,
    has_movement_collider: bool = false,
    movement_collider: collider.Aabb = .{
        .minimum = math.Vec2.zero,
        .maximum = math.Vec2.zero,
    },
    animation_state: Text = .{},
    animation_time: f32 = 0,
    animation_phase: f32 = 0,
    presentation_mode: Text = .{},
    resolved_view: Text = .{},
    interaction_owner: u32 = 0,
    body_preset: Text = .{},
    morphology_preset: Text = .{},
    selected_hair: Text = .{},
    outfit: Text = .{},
    loadout_count: u16 = 0,
    resolved_visual_count: u16 = 0,
    bone_count: usize = 0,
    bones: [skeleton.maximum_bones]Bone = undefined,
    socket_count: usize = 0,
    sockets: [skeleton.maximum_sockets]Socket = undefined,
    attachment_count: usize = 0,
    attachments: [appearance.maximum_attachment_points]AttachmentPoint = undefined,
    part_count: usize = 0,
    parts: [anatomy.maximum_part_instances]Part = undefined,
    part_socket_count: usize = 0,
    part_sockets: [anatomy.maximum_part_sockets]PartSocket = undefined,
    module_joint_count: usize = 0,
    module_joints: [appearance.maximum_total_module_joints]ModuleJoint = undefined,
    module_socket_count: usize = 0,
    module_sockets: [appearance.maximum_total_module_sockets]ModuleSocket = undefined,

    pub fn boneBySemantic(
        truth: *const Character,
        semantic: skeleton.BoneSemantic,
    ) ?*const Bone {
        for (truth.bones[0..truth.bone_count]) |*bone| {
            if (bone.semantic == semantic) return bone;
        }
        return null;
    }

    pub fn partByName(
        truth: *const Character,
        stable_id: []const u8,
    ) ?*const Part {
        for (truth.parts[0..truth.part_count]) |*part| {
            if (std.mem.eql(u8, part.name.slice(), stable_id)) return part;
        }
        return null;
    }
};

pub const Visual = struct {
    character_id: u32,
    stable_id: Text,
    owner: visual_geometry.Owner,
    role: visual_geometry.Role,
    side: visual_geometry.Side,
    component_id: u32,
    bound_identity: u32,
    region_id: u32,
    texture_page: u32,
    source: visual_geometry.PixelRect,
    uv_rect: [4]f32,
    world_position: math.Vec2,
    rotation: f32,
    scale: math.Vec2,
    pivot: [2]f32,
    draw_order_key: sprite.DrawOrderKey,
    view: visual_geometry.View,
    facing: Text,
    alpha_bounds_minimum: math.Vec2,
    alpha_bounds_maximum: math.Vec2,
    landmark_count: u8,
    landmarks: [visual_geometry.landmark_capacity]visual_geometry.WorldLandmark,
    final_submission_index: u32,
    is_mesh: bool,
    submission_visibility: visual_geometry.SubmissionVisibility = .rendered,
    base_visual_policy: visual_geometry.BaseVisualPolicy = .retain,
    placement_authority: visual_geometry.RegistrationAuthority,
    has_registration: bool,
    registration_identity: Text,
    registration_binding_mode: visual_geometry.RegistrationBindingMode = .point,
    registration_scale_policy: visual_geometry.RegistrationScalePolicy = .point_authored,
    registration_mirroring_policy: visual_geometry.RegistrationMirroringPolicy = .none,
    registration_threshold_m: f32 = 0,
    registration_maximum_residual_m: f32 = 0,
    registration_axis: ?visual_geometry.RegistrationAxis = null,
    graph_binding: ?VisualGraphBinding = null,
};

pub const VisualGraphBinding = struct {
    component_id: u16,
    component_identity: Text,
    parent_component_id: u16,
    parent_component_identity: Text,
    module_id: u16,
    module_identity: Text,
    graph_visual_index: u8,
    source_identity: Text,
    start_kind: visual_geometry.GraphEndpointKind,
    start_global_index: u16,
    start_identity: Text,
    end_kind: visual_geometry.GraphEndpointKind,
    end_global_index: u16,
    end_identity: Text,
};

pub const Mismatch = struct {
    character_id: u32,
    component: Text,
    expected_target: Text,
    atlas_landmark: Text,
    expected_world: math.Vec2,
    transformed_atlas_world: math.Vec2,
    has_expected_target: bool,
    world_error_m: f32,
    pixel_error: f32,
    threshold_px: f32,
    result: MismatchResult,
};

pub const CategoryCounts = extern struct {
    physics_root_collider: u32 = 0,
    canonical_skeleton: u32 = 0,
    projected_skeleton: u32 = 0,
    sockets_attachments: u32 = 0,
    module_joints_sockets: u32 = 0,
    component_pivots: u32 = 0,
    atlas_landmarks: u32 = 0,
    alpha_visible_bounds: u32 = 0,
    clothing_hair_anchors: u32 = 0,
    mismatch_errors: u32 = 0,

    pub fn total(counts: CategoryCounts) u32 {
        return counts.physics_root_collider +
            counts.canonical_skeleton +
            counts.projected_skeleton +
            counts.sockets_attachments +
            counts.module_joints_sockets +
            counts.component_pivots +
            counts.atlas_landmarks +
            counts.alpha_visible_bounds +
            counts.clothing_hair_anchors +
            counts.mismatch_errors;
    }
};

pub const Snapshot = struct {
    mode: Mode = .off,
    render_frame: u64 = 0,
    simulation_tick: u64 = 0,
    viewport: [2]u32 = .{ 0, 0 },
    camera_center: math.Vec2 = math.Vec2.zero,
    pixels_per_meter: f32 = 0,
    character_count: usize = 0,
    characters: [character_capacity]Character = undefined,
    visual_count: usize = 0,
    visuals: [visual_geometry.trace_capacity]Visual = undefined,
    mismatch_count: usize = 0,
    mismatches: [mismatch_capacity]Mismatch = undefined,
    authoritative_fingerprint: u64 = 0,
    presentation_fingerprint: u64 = 0,
    capture_fingerprint: u64 = 0,
    active_optional_modules: u8 = 0,
    expected_optional_visual_submissions: u8 = 0,
    actual_optional_visual_submissions: u8 = 0,
    missing_optional_visual_submissions: u8 = 0,
    orphan_optional_visual_submissions: u8 = 0,

    pub fn build(
        snapshot: *Snapshot,
        mode: Mode,
        render_frame: u64,
        simulation_tick: u64,
        camera: camera2d.Camera2D,
        characters: [character_capacity]*const character.CharacterInstance,
        presentations: [character_capacity]character_art.Presentation,
        trace: *const visual_geometry.Trace,
        alpha_catalog: *const visual_geometry_overlay.AlphaCatalog,
    ) !void {
        if (trace.count > visual_geometry.trace_capacity) {
            return error.VisualTruthTraceCapacityExceeded;
        }
        snapshot.mode = mode;
        snapshot.render_frame = render_frame;
        snapshot.simulation_tick = simulation_tick;
        snapshot.viewport = .{ camera.viewport_width, camera.viewport_height };
        snapshot.camera_center = camera.center;
        snapshot.pixels_per_meter = camera.pixels_per_meter;
        snapshot.character_count = character_capacity;
        snapshot.visual_count = 0;
        snapshot.mismatch_count = 0;
        snapshot.active_optional_modules = 0;
        snapshot.expected_optional_visual_submissions = 0;
        snapshot.actual_optional_visual_submissions = 0;
        snapshot.missing_optional_visual_submissions = 0;
        snapshot.orphan_optional_visual_submissions = 0;
        snapshot.authoritative_fingerprint = 0;
        snapshot.presentation_fingerprint = 0;
        snapshot.capture_fingerprint = 0;
        for (characters, presentations, 0..) |instance, presentation, index| {
            try captureCharacter(
                &snapshot.characters[index],
                instance,
                presentation,
                if (instance.controller != null) .controlled else .passive,
                camera.pixels_per_meter,
            );
        }
        for (trace.slice()) |record| {
            try snapshot.appendVisual(record, alpha_catalog);
            try snapshot.appendMismatches(record, alpha_catalog, camera);
        }
        try snapshot.validateOptionalArmGraphToSubmission();
        snapshot.authoritative_fingerprint = snapshot.hashAuthoritative();
        snapshot.presentation_fingerprint = snapshot.hashPresentation();
        snapshot.capture_fingerprint = snapshot.hashCapture();
    }

    pub fn buildOverlay(
        snapshot: *const Snapshot,
        mode: Mode,
        commands: *debug_draw.CommandBuffer,
    ) !CategoryCounts {
        commands.beginFrame();
        if (mode == .off) return .{};
        var counts = CategoryCounts{};
        try snapshot.appendRig(commands, &counts);
        if (mode.includesRegistration()) {
            try snapshot.appendRegistration(commands, &counts);
        }
        if (counts.total() != commands.count) return error.VisualTruthCategoryCountMismatch;
        return counts;
    }

    pub fn bindRenderFrame(snapshot: *Snapshot, render_frame: u64) void {
        snapshot.render_frame = render_frame;
        snapshot.capture_fingerprint = snapshot.hashCapture();
    }

    pub fn setOutfit(
        snapshot: *Snapshot,
        character_id: u32,
        outfit: []const u8,
        loadout_count: usize,
    ) !void {
        const truth = snapshot.characterByIdMutable(character_id) orelse
            return error.VisualTruthCharacterMissing;
        truth.outfit = try Text.init(outfit);
        truth.loadout_count = @intCast(loadout_count);
        snapshot.presentation_fingerprint = snapshot.hashPresentation();
        snapshot.capture_fingerprint = snapshot.hashCapture();
    }

    fn appendVisual(
        snapshot: *Snapshot,
        record: visual_geometry.TraceRecord,
        alpha_catalog: *const visual_geometry_overlay.AlphaCatalog,
    ) !void {
        if (snapshot.visual_count == snapshot.visuals.len) {
            return error.VisualTruthVisualCapacityExceeded;
        }
        const alpha = try alpha_catalog.find(record.region_id);
        var landmarks: [visual_geometry.landmark_capacity]visual_geometry.WorldLandmark = undefined;
        for (record.geometry.landmarks[0..record.geometry.landmark_count], 0..) |landmark, index| {
            landmarks[index] = .{
                .kind = landmark.kind,
                .world = try directAtlasLandmark(record, alpha, landmark.kind),
            };
        }
        const bounds = try visualBounds(record, alpha);
        snapshot.visuals[snapshot.visual_count] = .{
            .character_id = record.character_id,
            .stable_id = try Text.init(record.stable_id),
            .owner = record.owner,
            .role = record.role,
            .side = record.side,
            .component_id = record.component_id,
            .bound_identity = record.bound_identity,
            .region_id = record.region_id,
            .texture_page = record.request.texture_page,
            .source = record.source,
            .uv_rect = record.request.uv_rect,
            .world_position = .{
                .x = record.request.world_position[0],
                .y = record.request.world_position[1],
            },
            .rotation = record.request.rotation,
            .scale = .{
                .x = record.request.scale[0],
                .y = record.request.scale[1],
            },
            .pivot = record.request.pivot,
            .draw_order_key = try sprite.validateOrder(
                record.request.order,
                record.submission_index,
            ),
            .view = record.view,
            .facing = try Text.init(switch (record.view) {
                .front => "front_identity_preserved",
                .side_left => "left",
                .side_right => "right",
            }),
            .alpha_bounds_minimum = bounds.minimum,
            .alpha_bounds_maximum = bounds.maximum,
            .landmark_count = record.geometry.landmark_count,
            .landmarks = landmarks,
            .final_submission_index = record.submission_index,
            .is_mesh = record.mesh != null,
            .submission_visibility = record.submission_visibility,
            .base_visual_policy = record.base_visual_policy,
            .placement_authority = record.placement_authority,
            .has_registration = record.registration != null,
            .registration_identity = try Text.init(if (record.registration) |registration|
                registration.identity
            else
                "not_registered"),
            .registration_binding_mode = if (record.registration) |registration|
                registration.binding_mode
            else
                .point,
            .registration_scale_policy = if (record.registration) |registration|
                registration.scale_policy
            else
                .point_authored,
            .registration_mirroring_policy = if (record.registration) |registration|
                registration.mirroring_policy
            else
                .none,
            .registration_threshold_m = if (record.registration) |registration|
                registration.threshold_m
            else
                0,
            .registration_maximum_residual_m = if (record.registration) |registration|
                registration.maximum_residual_m
            else
                0,
            .registration_axis = if (record.registration) |registration|
                registration.axis
            else
                null,
            .graph_binding = if (record.graph_binding) |binding|
                VisualGraphBinding{
                    .component_id = binding.component_id,
                    .component_identity = try Text.init(
                        binding.component_identity,
                    ),
                    .parent_component_id = binding.parent_component_id,
                    .parent_component_identity = try Text.init(
                        binding.parent_component_identity,
                    ),
                    .module_id = binding.module_id,
                    .module_identity = try Text.init(binding.module_identity),
                    .graph_visual_index = binding.graph_visual_index,
                    .source_identity = try Text.init(binding.source_identity),
                    .start_kind = binding.start_kind,
                    .start_global_index = binding.start_global_index,
                    .start_identity = try Text.init(binding.start_identity),
                    .end_kind = binding.end_kind,
                    .end_global_index = binding.end_global_index,
                    .end_identity = try Text.init(binding.end_identity),
                }
            else
                null,
        };
        snapshot.visual_count += 1;
        const truth = snapshot.characterByIdMutable(record.character_id) orelse
            return error.VisualTruthCharacterMissing;
        truth.resolved_visual_count = std.math.add(
            u16,
            truth.resolved_visual_count,
            1,
        ) catch return error.VisualTruthResolvedVisualCountOverflow;
    }

    fn appendMismatches(
        snapshot: *Snapshot,
        record: visual_geometry.TraceRecord,
        alpha_catalog: *const visual_geometry_overlay.AlphaCatalog,
        camera: camera2d.Camera2D,
    ) !void {
        if (record.registration) |registration| {
            for (registration.points[0..registration.point_count]) |point| {
                if (snapshot.mismatch_count == snapshot.mismatches.len) {
                    return error.VisualTruthMismatchCapacityExceeded;
                }
                const expected_pixel = try camera.worldToPresentation(
                    point.target_world,
                    record.request.camera_x_factor,
                );
                const actual_pixel = try camera.worldToPresentation(
                    point.transformed_world,
                    record.request.camera_x_factor,
                );
                const pixel_error = expected_pixel.sub(actual_pixel).length();
                const threshold_px = registration.threshold_m * camera.pixels_per_meter;
                snapshot.mismatches[snapshot.mismatch_count] = .{
                    .character_id = record.character_id,
                    .component = try Text.init(record.stable_id),
                    .expected_target = try Text.init(point.target_identity),
                    .atlas_landmark = try Text.init(@tagName(point.source_landmark)),
                    .expected_world = point.target_world,
                    .transformed_atlas_world = point.transformed_world,
                    .has_expected_target = true,
                    .world_error_m = point.residual_m,
                    .pixel_error = pixel_error,
                    .threshold_px = threshold_px,
                    .result = if (std.math.isFinite(point.residual_m) and
                        std.math.isFinite(pixel_error) and
                        point.residual_m <= registration.threshold_m)
                        .pass
                    else
                        .fail,
                };
                snapshot.mismatch_count += 1;
            }
            if (registration.axis) |axis| {
                if (snapshot.mismatch_count == snapshot.mismatches.len) {
                    return error.VisualTruthMismatchCapacityExceeded;
                }
                const expected_pixel = try camera.worldToPresentation(
                    axis.expected_end_world,
                    record.request.camera_x_factor,
                );
                const actual_pixel = try camera.worldToPresentation(
                    axis.transformed_end_world,
                    record.request.camera_x_factor,
                );
                const pixel_error = expected_pixel.sub(actual_pixel).length();
                snapshot.mismatches[snapshot.mismatch_count] = .{
                    .character_id = record.character_id,
                    .component = try Text.init(record.stable_id),
                    .expected_target = try Text.init(axis.reference_identity),
                    .atlas_landmark = try Text.init(@tagName(axis.source_end_landmark)),
                    .expected_world = axis.expected_end_world,
                    .transformed_atlas_world = axis.transformed_end_world,
                    .has_expected_target = true,
                    .world_error_m = axis.endpoint_residual_m,
                    .pixel_error = pixel_error,
                    .threshold_px = registration.threshold_m * camera.pixels_per_meter,
                    .result = if (std.math.isFinite(axis.endpoint_residual_m) and
                        std.math.isFinite(axis.angular_residual_radians) and
                        std.math.isFinite(pixel_error) and
                        axis.endpoint_residual_m <= registration.threshold_m and
                        axis.angular_residual_radians <= axis.threshold_radians)
                        .pass
                    else
                        .fail,
                };
                snapshot.mismatch_count += 1;
            }
            return;
        }
        const alpha = try alpha_catalog.find(record.region_id);
        for (record.geometry.landmarks[0..record.geometry.landmark_count]) |landmark| {
            if (snapshot.mismatch_count == snapshot.mismatches.len) {
                return error.VisualTruthMismatchCapacityExceeded;
            }
            const actual = try directAtlasLandmark(record, alpha, landmark.kind);
            const expected = snapshot.expectedTarget(record, landmark.kind);
            const threshold = if (record.fit) |fit|
                fit.registration_tolerance_px
            else
                registration_tolerance_px;
            var mismatch = Mismatch{
                .character_id = record.character_id,
                .component = try Text.init(record.stable_id),
                .expected_target = try Text.init(expected.name),
                .atlas_landmark = try Text.init(@tagName(landmark.kind)),
                .expected_world = expected.world,
                .transformed_atlas_world = actual,
                .has_expected_target = expected.applicable,
                .world_error_m = 0,
                .pixel_error = 0,
                .threshold_px = threshold,
                .result = .not_applicable,
            };
            if (expected.applicable) {
                const world_error = expected.world.sub(actual).length();
                const expected_pixel = try camera.worldToPresentation(
                    expected.world,
                    record.request.camera_x_factor,
                );
                const actual_pixel = try camera.worldToPresentation(
                    actual,
                    record.request.camera_x_factor,
                );
                const pixel_error = expected_pixel.sub(actual_pixel).length();
                mismatch.world_error_m = world_error;
                mismatch.pixel_error = pixel_error;
                mismatch.result = if (std.math.isFinite(world_error) and
                    std.math.isFinite(pixel_error) and pixel_error <= threshold)
                    .pass
                else
                    .fail;
            }
            snapshot.mismatches[snapshot.mismatch_count] = mismatch;
            snapshot.mismatch_count += 1;
        }
    }

    fn validateOptionalArmGraphToSubmission(snapshot: *Snapshot) !void {
        for (snapshot.characters[0..snapshot.character_count]) |truth| {
            for ([_][]const u8{ "extra_arm", "extra_arm_second" }) |name| {
                const part = truth.partByName(name) orelse
                    return error.OptionalArmComponentMissingFromTruth;
                var actual: usize = 0;
                for (snapshot.visuals[0..snapshot.visual_count]) |visual| {
                    const binding = visual.graph_binding orelse continue;
                    if (visual.character_id != truth.id or
                        binding.component_id != part.index)
                    {
                        continue;
                    }
                    actual += 1;
                    if (!part.active) {
                        snapshot.orphan_optional_visual_submissions += 1;
                        return error.InactiveOptionalArmProducedSubmission;
                    }
                    if (visual.final_submission_index == std.math.maxInt(u32)) {
                        snapshot.missing_optional_visual_submissions += 1;
                        return error.OptionalArmFinalSubmissionMissing;
                    }
                    if (part.articulation_module == null or
                        binding.module_id != part.articulation_module.?)
                    {
                        return error.OptionalArmModuleOwnershipMismatch;
                    }
                }
                if (!part.active) {
                    if (actual != 0) return error.InactiveOptionalArmProducedSubmission;
                    continue;
                }
                snapshot.active_optional_modules += 1;
                snapshot.expected_optional_visual_submissions +=
                    part.bound_visual_count;
                snapshot.actual_optional_visual_submissions +=
                    @intCast(actual);
                if (actual != part.bound_visual_count) {
                    snapshot.missing_optional_visual_submissions +=
                        @intCast(part.bound_visual_count -| actual);
                    return error.OptionalArmFinalSubmissionMissing;
                }
            }
        }
        if (snapshot.missing_optional_visual_submissions != 0 or
            snapshot.orphan_optional_visual_submissions != 0)
        {
            return error.OptionalArmGraphSubmissionIntegrityFailed;
        }
    }

    const Expected = struct {
        name: []const u8,
        world: math.Vec2,
        applicable: bool,
    };

    fn expectedTarget(
        snapshot: *const Snapshot,
        record: visual_geometry.TraceRecord,
        kind: visual_geometry.LandmarkKind,
    ) Expected {
        const truth = snapshot.characterById(record.character_id) orelse
            return .{ .name = "missing_character", .world = math.Vec2.zero, .applicable = false };
        if (expectedBoneSemantic(record.role, record.side, kind)) |semantic| {
            if (truth.boneBySemantic(semantic)) |bone| {
                return .{
                    .name = @tagName(semantic),
                    .world = bone.projected_world.position,
                    .applicable = true,
                };
            }
        }
        if (record.role == .face_feature) {
            const part = truth.partByName(record.stable_id) orelse
                return .{
                    .name = "missing_face_component_anchor",
                    .world = math.Vec2.zero,
                    .applicable = false,
                };
            return .{
                .name = part.name.slice(),
                .world = part.projected_world.position,
                .applicable = part.active,
            };
        }
        if (record.role == .hair and
            (kind == .proximal or kind == .center or kind == .scalp))
        {
            const head = truth.boneBySemantic(.head) orelse
                return .{
                    .name = "missing_head_hair_anchor",
                    .world = math.Vec2.zero,
                    .applicable = false,
                };
            return .{
                .name = "head_hair_anchor",
                .world = head.projected_world.position,
                .applicable = true,
            };
        }
        if (record.role == .headwear and
            (kind == .proximal or kind == .center or kind == .headwear_fit))
        {
            const head = truth.boneBySemantic(.head) orelse
                return .{
                    .name = "missing_headwear_anchor",
                    .world = math.Vec2.zero,
                    .applicable = false,
                };
            return .{
                .name = "headwear_anchor",
                .world = head.projected_world.position,
                .applicable = true,
            };
        }
        if (record.bound_identity < truth.part_count) {
            const part = &truth.parts[record.bound_identity];
            if (part.active and (record.owner == .clothing or
                record.owner == .equipment or
                record.owner == .accessory))
            {
                return .{
                    .name = part.name.slice(),
                    .world = part.projected_world.position,
                    .applicable = kind == .center or
                        kind == .proximal or
                        kind == .scalp or
                        record.role == .face_feature or
                        record.role == .hair,
                };
            }
        }
        return .{
            .name = "not_applicable",
            .world = math.Vec2.zero,
            .applicable = false,
        };
    }

    fn characterById(snapshot: *const Snapshot, id: u32) ?*const Character {
        for (snapshot.characters[0..snapshot.character_count]) |*value| {
            if (value.id == id) return value;
        }
        return null;
    }

    fn characterByIdMutable(snapshot: *Snapshot, id: u32) ?*Character {
        for (snapshot.characters[0..snapshot.character_count]) |*value| {
            if (value.id == id) return value;
        }
        return null;
    }

    fn appendRig(
        snapshot: *const Snapshot,
        commands: *debug_draw.CommandBuffer,
        counts: *CategoryCounts,
    ) !void {
        for (snapshot.characters[0..snapshot.character_count]) |truth| {
            try commands.addMarker(truth.root, colors.physics);
            counts.physics_root_collider += 1;
            if (truth.has_movement_collider) {
                try commands.addAabb(truth.movement_collider, colors.physics);
                counts.physics_root_collider += 4;
            } else {
                try addMismatchCross(commands, truth.root, colors.mismatch);
                counts.mismatch_errors += 2;
            }
            for (truth.bones[0..truth.bone_count]) |bone| {
                if (bone.parent) |parent| {
                    try commands.addLine(
                        truth.bones[parent].canonical_world.position,
                        bone.canonical_world.position,
                        colors.canonical,
                    );
                    counts.canonical_skeleton += 1;
                }
                try commands.addMarker(bone.canonical_world.position, colors.canonical);
                counts.canonical_skeleton += 1;
            }
            for (truth.sockets[0..truth.socket_count]) |socket_value| {
                try commands.addMarker(socket_value.canonical_world.position, colors.socket);
                counts.sockets_attachments += 1;
            }
            for (truth.attachments[0..truth.attachment_count]) |point| {
                try commands.addMarker(point.canonical_world.position, colors.socket);
                counts.sockets_attachments += 1;
                if (point.parent_index) |parent| {
                    try commands.addLine(
                        truth.attachments[parent].canonical_world.position,
                        point.canonical_world.position,
                        colors.socket,
                    );
                    counts.sockets_attachments += 1;
                }
            }
            for (truth.parts[0..truth.part_count]) |part| {
                if (!part.active) continue;
                try commands.addMarker(part.canonical_world.position, colors.socket);
                counts.sockets_attachments += 1;
                if (part.parent_part) |parent| {
                    try commands.addLine(
                        truth.parts[parent].canonical_world.position,
                        part.canonical_world.position,
                        if (part.connection_mode == .intentional_gap)
                            colors.module
                        else
                            colors.socket,
                    );
                    counts.sockets_attachments += 1;
                }
            }
            for (truth.part_sockets[0..truth.part_socket_count]) |socket_value| {
                try commands.addMarker(socket_value.canonical_world.position, colors.socket);
                counts.sockets_attachments += 1;
            }
            for (truth.module_joints[0..truth.module_joint_count]) |joint| {
                const color = if (joint.active) colors.module else colors.inactive;
                try commands.addMarker(joint.canonical_world.position, color);
                counts.module_joints_sockets += 1;
                if (joint.parent_joint) |parent| {
                    try commands.addLine(
                        truth.module_joints[parent].canonical_world.position,
                        joint.canonical_world.position,
                        color,
                    );
                    counts.module_joints_sockets += 1;
                }
            }
            for (truth.module_sockets[0..truth.module_socket_count]) |socket_value| {
                try commands.addMarker(
                    socket_value.canonical_world.position,
                    if (socket_value.active) colors.module else colors.inactive,
                );
                counts.module_joints_sockets += 1;
            }
        }
    }

    fn appendRegistration(
        snapshot: *const Snapshot,
        commands: *debug_draw.CommandBuffer,
        counts: *CategoryCounts,
    ) !void {
        for (snapshot.characters[0..snapshot.character_count]) |truth| {
            for (truth.bones[0..truth.bone_count]) |bone| {
                if (bone.parent) |parent| {
                    try commands.addLine(
                        truth.bones[parent].projected_world.position,
                        bone.projected_world.position,
                        colors.projected,
                    );
                    counts.projected_skeleton += 1;
                }
                try commands.addMarker(bone.projected_world.position, colors.projected);
                counts.projected_skeleton += 1;
            }
            for (truth.parts[0..truth.part_count]) |part| {
                if (!isOptionalArmPart(part) or
                    part.articulation_module == null or
                    part.parent_socket == null)
                {
                    continue;
                }
                if (!part.active) {
                    counts.sockets_attachments += try commands.addLabel(
                        part.connection_parent_endpoint.add(.{ .x = 0.03, .y = 0.08 }),
                        "INACTIVE",
                        colors.inactive,
                    );
                    continue;
                }
                const color = connectionColor(part);
                try commands.addLine(
                    part.connection_parent_endpoint,
                    part.connection_child_endpoint,
                    color,
                );
                try commands.addMarker(part.connection_parent_endpoint, color);
                try commands.addMarker(part.connection_child_endpoint, color);
                counts.sockets_attachments += 3;
                const label = switch (part.connection_result) {
                    .fail => "INVALID",
                    .not_applicable => "INACTIVE",
                    .pass => switch (part.connection_mode) {
                        .continuous => "CONT",
                        .intentional_gap => "INT_GAP",
                        .hidden => "HIDDEN",
                        .soft_bridge => "SOFT_BRIDGE",
                    },
                };
                counts.sockets_attachments += try commands.addLabel(
                    part.connection_parent_endpoint
                        .add(part.connection_gap_vector.scale(0.5))
                        .add(.{ .x = 0.03, .y = 0.08 }),
                    label,
                    color,
                );
            }
            for (truth.module_joints[0..truth.module_joint_count]) |joint| {
                if (!joint.active) continue;
                try commands.addMarker(joint.projected_world.position, colors.module);
                counts.module_joints_sockets += 1;
                if (joint.parent_joint) |parent| {
                    try commands.addLine(
                        truth.module_joints[parent].projected_world.position,
                        joint.projected_world.position,
                        colors.module,
                    );
                    counts.module_joints_sockets += 1;
                }
            }
            for (truth.module_sockets[0..truth.module_socket_count]) |socket_value| {
                if (!socket_value.active) continue;
                try commands.addMarker(
                    socket_value.projected_world.position,
                    colors.module,
                );
                counts.module_joints_sockets += 1;
            }
        }
        for (snapshot.visuals[0..snapshot.visual_count]) |visual| {
            try commands.addMarker(visual.world_position, colors.pivot);
            counts.component_pivots += 1;
            const minimum = visual.alpha_bounds_minimum;
            const maximum = visual.alpha_bounds_maximum;
            try commands.addLine(minimum, .{ .x = maximum.x, .y = minimum.y }, colors.alpha);
            try commands.addLine(.{ .x = maximum.x, .y = minimum.y }, maximum, colors.alpha);
            try commands.addLine(maximum, .{ .x = minimum.x, .y = maximum.y }, colors.alpha);
            try commands.addLine(.{ .x = minimum.x, .y = maximum.y }, minimum, colors.alpha);
            counts.alpha_visible_bounds += 4;
            for (visual.landmarks[0..visual.landmark_count]) |landmark| {
                try commands.addMarker(landmark.world, colors.landmark);
                counts.atlas_landmarks += 1;
            }
            if (visual.graph_binding != null) {
                var identity_buffer: [24]u8 = undefined;
                const identity = try std.fmt.bufPrint(
                    &identity_buffer,
                    "{s}{d}",
                    .{
                        switch (visual.role) {
                            .upper_arm => "U",
                            .forearm => "F",
                            .hand => "H",
                            else => "V",
                        },
                        visual.final_submission_index,
                    },
                );
                counts.component_pivots += try commands.addLabel(
                    visual.world_position.add(.{ .x = 0.03, .y = 0.06 }),
                    identity,
                    colors.pivot,
                );
            }
        }
        for (snapshot.mismatches[0..snapshot.mismatch_count]) |mismatch| {
            if (!mismatch.has_expected_target) continue;
            const color = if (mismatch.result == .pass) colors.anchor else colors.mismatch;
            try commands.addLine(
                mismatch.expected_world,
                mismatch.transformed_atlas_world,
                color,
            );
            if (mismatch.result == .fail) {
                counts.mismatch_errors += 1;
            } else {
                counts.clothing_hair_anchors += 1;
            }
        }
    }

    fn connectionColor(part: Part) debug_draw.Color {
        if (!part.active) return colors.inactive;
        if (part.connection_result == .fail) return colors.invalid;
        return switch (part.connection_mode) {
            .continuous => colors.continuous,
            .intentional_gap => colors.intentional_gap,
            .hidden, .soft_bridge => colors.module,
        };
    }

    fn isOptionalArmPart(part: Part) bool {
        return std.mem.eql(u8, part.name.slice(), "extra_arm") or
            std.mem.eql(u8, part.name.slice(), "extra_arm_second");
    }

    fn hashAuthoritative(snapshot: *const Snapshot) u64 {
        var hash = fnv_offset;
        hashValue(&hash, snapshot.simulation_tick);
        for (snapshot.characters[0..snapshot.character_count]) |truth| {
            hashValue(&hash, truth.id);
            hashValue(&hash, truth.root);
            hashValue(&hash, truth.controller_position);
            hashValue(&hash, truth.velocity);
            hashValue(&hash, truth.grounded);
            if (truth.support_collider) |support| {
                hashValue(&hash, @as(u8, 1));
                hashValue(&hash, support);
            } else {
                hashValue(&hash, @as(u8, 0));
            }
            for (truth.bones[0..truth.bone_count]) |bone| {
                hashValue(&hash, bone.local);
                hashValue(&hash, bone.canonical_world);
            }
        }
        return hash;
    }

    fn hashPresentation(snapshot: *const Snapshot) u64 {
        var hash = fnv_offset;
        for (snapshot.characters[0..snapshot.character_count]) |truth| {
            hashBytes(&hash, truth.resolved_view.slice());
            hashBytes(&hash, truth.body_preset.slice());
            hashBytes(&hash, truth.morphology_preset.slice());
            hashBytes(&hash, truth.selected_hair.slice());
            hashBytes(&hash, truth.outfit.slice());
            for (truth.bones[0..truth.bone_count]) |bone| {
                hashValue(&hash, bone.projected_world);
            }
            for (truth.parts[0..truth.part_count]) |part| {
                hashBytes(&hash, part.name.slice());
                hashBytes(&hash, part.definition_name.slice());
                hashBytes(&hash, part.semantic_role.slice());
                hashOptionalValue(&hash, part.parent_part);
                hashOptionalValue(&hash, part.parent_socket);
                hashValue(&hash, part.active);
                hashValue(&hash, part.binding_mode);
                hashValue(&hash, part.connection_mode);
                hashValue(&hash, part.measured_gap_m);
                hashValue(&hash, part.minimum_gap_m);
                hashValue(&hash, part.maximum_gap_m);
                hashValue(&hash, part.connection_parent_endpoint);
                hashValue(&hash, part.connection_child_endpoint);
                hashValue(&hash, part.connection_gap_vector);
                hashValue(&hash, part.target_gap_m);
                hashValue(&hash, part.acceptance_gap_px);
                hashValue(&hash, part.connection_result);
                hashValue(&hash, part.topology_status);
                hashBytes(&hash, part.selected_variant.slice());
                for (part.bound_visuals[0..part.bound_visual_count]) |visual| {
                    hashBytes(&hash, visual.slice());
                }
                hashValue(&hash, part.projected_world);
            }
            for (truth.module_joints[0..truth.module_joint_count]) |joint| {
                hashValue(&hash, joint.module_index);
                hashOptionalValue(&hash, joint.owner_component);
                hashValue(&hash, joint.active);
                hashValue(&hash, joint.projected_world);
            }
            for (truth.module_sockets[0..truth.module_socket_count]) |socket_value| {
                hashValue(&hash, socket_value.module_index);
                hashOptionalValue(&hash, socket_value.owner_component);
                hashValue(&hash, socket_value.active);
                hashValue(&hash, socket_value.projected_world);
            }
        }
        for (snapshot.visuals[0..snapshot.visual_count]) |visual| {
            hashValue(&hash, visual.character_id);
            hashValue(&hash, visual.component_id);
            hashValue(&hash, visual.region_id);
            hashValue(&hash, visual.world_position);
            hashValue(&hash, visual.rotation);
            hashValue(&hash, visual.scale);
            hashValue(&hash, visual.pivot);
            hashValue(&hash, visual.final_submission_index);
            hashValue(&hash, visual.submission_visibility);
            hashValue(&hash, visual.base_visual_policy);
            hashValue(&hash, visual.placement_authority);
            hashValue(&hash, visual.registration_maximum_residual_m);
            if (visual.graph_binding) |binding| {
                hashValue(&hash, @as(u8, 1));
                hashValue(&hash, binding.component_id);
                hashValue(&hash, binding.module_id);
                hashValue(&hash, binding.graph_visual_index);
                hashValue(&hash, binding.start_kind);
                hashValue(&hash, binding.start_global_index);
                hashValue(&hash, binding.end_kind);
                hashValue(&hash, binding.end_global_index);
            } else {
                hashValue(&hash, @as(u8, 0));
            }
        }
        hashValue(&hash, snapshot.active_optional_modules);
        hashValue(&hash, snapshot.expected_optional_visual_submissions);
        hashValue(&hash, snapshot.actual_optional_visual_submissions);
        hashValue(&hash, snapshot.missing_optional_visual_submissions);
        hashValue(&hash, snapshot.orphan_optional_visual_submissions);
        return hash;
    }

    fn hashCapture(snapshot: *const Snapshot) u64 {
        var hash = fnv_offset;
        hashValue(&hash, snapshot.authoritative_fingerprint);
        hashValue(&hash, snapshot.presentation_fingerprint);
        hashValue(&hash, snapshot.render_frame);
        hashValue(&hash, snapshot.viewport);
        hashValue(&hash, snapshot.camera_center);
        hashValue(&hash, snapshot.pixels_per_meter);
        return hash;
    }
};

pub const CaptureProvenance = struct {
    utc_timestamp: []const u8,
    capture_index: u64,
    git_head: []const u8,
    staged_dirty: bool,
    unstaged_dirty: bool,
    untracked_dirty: bool,
    build_configuration: []const u8,
    executable_arguments: []const u8,
    gpu_driver: []const u8,
    shader_format: []const u8,
    clean_render_frame: u64,
    debug_render_frame: u64,
    clean_simulation_tick: u64,
    debug_simulation_tick: u64,
    authoritative_before: u64,
    authoritative_after: u64,
    presentation_before: u64,
    presentation_after: u64,
    capture_before: u64,
    capture_after: u64,

    pub fn statesMatch(provenance: CaptureProvenance) bool {
        return provenance.clean_render_frame == provenance.debug_render_frame and
            provenance.clean_simulation_tick == provenance.debug_simulation_tick and
            provenance.authoritative_before == provenance.authoritative_after and
            provenance.presentation_before == provenance.presentation_after and
            provenance.capture_before == provenance.capture_after;
    }
};

pub const SourceAssetEvidence = struct {
    path: []const u8,
    size: u64,
    sha256: [32]u8,
};

pub const FileEvidence = struct {
    name: []const u8,
    size: u64,
    sha256: [32]u8,
};

pub const Bundle = struct {
    capture_id: [64]u8 = undefined,
    capture_id_length: usize = 0,
    final_path: [320]u8 = undefined,
    final_path_length: usize = 0,
    incomplete_path: [340]u8 = undefined,
    incomplete_path_length: usize = 0,
    capture_index: u64 = 0,
    finalized: bool = false,

    pub fn begin(
        io: std.Io,
        base_directory: []const u8,
        utc_timestamp: []const u8,
        first_index: u64,
    ) !Bundle {
        try validateTimestamp(utc_timestamp);
        const cwd = std.Io.Dir.cwd();
        try cwd.createDirPath(io, base_directory);
        var directory = try cwd.openDir(
            io,
            base_directory,
            .{ .iterate = true },
        );
        defer directory.close(io);
        var index = first_index;
        var iterator = directory.iterate();
        while (try iterator.next(io)) |entry| {
            if (entry.kind != .directory or
                !isManualCaptureId(entry.name))
            {
                continue;
            }
            const separator = std.mem.lastIndexOfScalar(u8, entry.name, '_') orelse
                return error.InvalidManualCaptureDirectoryName;
            const existing_index = try std.fmt.parseInt(
                u64,
                entry.name[separator + 1 ..],
                10,
            );
            if (existing_index >= index) {
                index = std.math.add(u64, existing_index, 1) catch
                    return error.ManualCaptureIndexOverflow;
            }
        }
        var attempt: usize = 0;
        while (attempt < 10_000) : (attempt += 1) {
            var result = Bundle{ .capture_index = index };
            const id = try std.fmt.bufPrint(
                &result.capture_id,
                "{s}_{d:0>4}",
                .{ utc_timestamp, index },
            );
            result.capture_id_length = id.len;
            const final_path = try std.fmt.bufPrint(
                &result.final_path,
                "{s}/{s}",
                .{ base_directory, id },
            );
            result.final_path_length = final_path.len;
            const incomplete_path = try std.fmt.bufPrint(
                &result.incomplete_path,
                "{s}/.{s}.incomplete",
                .{ base_directory, id },
            );
            result.incomplete_path_length = incomplete_path.len;
            if (cwd.access(io, final_path, .{})) |_| {
                index = std.math.add(u64, index, 1) catch
                    return error.ManualCaptureIndexOverflow;
                continue;
            } else |err| switch (err) {
                error.FileNotFound => {},
                else => return err,
            }
            cwd.createDir(io, incomplete_path, .default_dir) catch |err| switch (err) {
                error.PathAlreadyExists => {
                    index = std.math.add(u64, index, 1) catch
                        return error.ManualCaptureIndexOverflow;
                    continue;
                },
                else => return err,
            };
            return result;
        }
        return error.ManualCaptureCollisionLimitExceeded;
    }

    pub fn captureId(bundle: *const Bundle) []const u8 {
        return bundle.capture_id[0..bundle.capture_id_length];
    }

    pub fn finalDirectory(bundle: *const Bundle) []const u8 {
        return bundle.final_path[0..bundle.final_path_length];
    }

    pub fn incompleteDirectory(bundle: *const Bundle) []const u8 {
        return bundle.incomplete_path[0..bundle.incomplete_path_length];
    }

    pub fn filePath(
        bundle: *const Bundle,
        buffer: []u8,
        filename: []const u8,
    ) ![]const u8 {
        if (bundle.finalized) return error.ManualCaptureAlreadyFinalized;
        return std.fmt.bufPrint(
            buffer,
            "{s}/{s}",
            .{ bundle.incompleteDirectory(), filename },
        );
    }

    pub fn writeStateJson(
        bundle: *const Bundle,
        io: std.Io,
        snapshot: *const Snapshot,
        provenance: CaptureProvenance,
    ) !void {
        if (!provenance.statesMatch()) return error.ManualCaptureStatesDiffer;
        var path_buffer: [384]u8 = undefined;
        const path = try bundle.filePath(&path_buffer, "state.json");
        var file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);
        try writeStateDocument(&file, io, bundle, snapshot, provenance);
    }

    pub fn writeSummary(
        bundle: *const Bundle,
        io: std.Io,
        snapshot: *const Snapshot,
        provenance: CaptureProvenance,
        counts: CategoryCounts,
    ) !void {
        var path_buffer: [384]u8 = undefined;
        const path = try bundle.filePath(&path_buffer, "summary.txt");
        var file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);
        try writeFileFmt(
            &file,
            io,
            "capture: {s}\nmode: {s}\ncharacters: {d}\nvisuals: {d}\nmismatches: {d}\ndebug_commands: {d}\nclean_debug_state_match: {}\nactive_optional_modules: {d}\nexpected_optional_visual_submissions: {d}\nactual_optional_visual_submissions: {d}\nmissing_optional_visual_submissions: {d}\norphan_optional_visual_submissions: {d}\nmanual_visual_acceptance: [PENDING OWNER REVIEW]\n\n",
            .{
                bundle.captureId(),
                @tagName(snapshot.mode),
                snapshot.character_count,
                snapshot.visual_count,
                snapshot.mismatch_count,
                counts.total(),
                provenance.statesMatch(),
                snapshot.active_optional_modules,
                snapshot.expected_optional_visual_submissions,
                snapshot.actual_optional_visual_submissions,
                snapshot.missing_optional_visual_submissions,
                snapshot.orphan_optional_visual_submissions,
            },
        );
        for (snapshot.characters[0..snapshot.character_count]) |truth| {
            try writeFileFmt(
                &file,
                io,
                "character {d}: role={s} view={s} outfit={s} body={s} morphology={s} hair={s}\n",
                .{
                    truth.id,
                    @tagName(truth.role),
                    truth.resolved_view.slice(),
                    truth.outfit.slice(),
                    truth.body_preset.slice(),
                    truth.morphology_preset.slice(),
                    truth.selected_hair.slice(),
                },
            );
            for ([_][]const u8{ "extra_arm", "extra_arm_second" }) |name| {
                const part = truth.partByName(name) orelse continue;
                try writeFileFmt(
                    &file,
                    io,
                    "  {s}: active={} connection_mode={s} parent_socket={s} child_root={s} target_gap_m={d:.3} measured_gap_m={d:.3} gap_px={d:.3} accepted_range_m={d:.3}-{d:.3} result={s}\n",
                    .{
                        part.name.slice(),
                        part.active,
                        @tagName(part.connection_mode),
                        part.parent_socket_name.slice(),
                        part.child_root_name.slice(),
                        part.target_gap_m,
                        part.measured_gap_m,
                        part.acceptance_gap_px,
                        part.minimum_gap_m,
                        part.maximum_gap_m,
                        upperResult(part.connection_result),
                    },
                );
            }
        }
        try file.writeStreamingAll(io, "\nregistration disagreements, sorted by severity:\n");
        var ranked: [64]u16 = undefined;
        var ranked_count: usize = 0;
        for (snapshot.mismatches[0..snapshot.mismatch_count], 0..) |mismatch, index| {
            if (!mismatch.has_expected_target) continue;
            const insertion = summaryInsertion(snapshot, ranked[0..ranked_count], mismatch);
            if (insertion >= ranked.len) continue;
            if (ranked_count < ranked.len) ranked_count += 1;
            var cursor = ranked_count - 1;
            while (cursor > insertion) : (cursor -= 1) {
                ranked[cursor] = ranked[cursor - 1];
            }
            ranked[insertion] = @intCast(index);
        }
        for (ranked[0..ranked_count]) |raw_index| {
            const mismatch = snapshot.mismatches[raw_index];
            try writeFileFmt(
                &file,
                io,
                "{s}.{s}\n  {s} -> atlas {s}: {d:.3} px [{s}]\n",
                .{
                    mismatch.component.slice(),
                    mismatch.atlas_landmark.slice(),
                    mismatch.expected_target.slice(),
                    mismatch.atlas_landmark.slice(),
                    mismatch.pixel_error,
                    upperResult(mismatch.result),
                },
            );
        }
    }

    pub fn finalize(
        bundle: *Bundle,
        allocator: std.mem.Allocator,
        io: std.Io,
        snapshot: *const Snapshot,
        provenance: CaptureProvenance,
        source_assets: []const SourceAssetEvidence,
    ) !void {
        if (bundle.finalized) return error.ManualCaptureAlreadyFinalized;
        if (!provenance.statesMatch()) return error.ManualCaptureStatesDiffer;
        const names = [_][]const u8{ "clean.png", "debug.png", "state.json", "summary.txt" };
        var evidence: [names.len]FileEvidence = undefined;
        for (names, 0..) |name, index| {
            var path_buffer: [384]u8 = undefined;
            const path = try bundle.filePath(&path_buffer, name);
            evidence[index] = try hashFile(allocator, io, path, name);
        }
        try validatePngFile(allocator, io, bundle, "clean.png");
        try validatePngFile(allocator, io, bundle, "debug.png");
        try validateJsonFile(allocator, io, bundle, "state.json");
        try bundle.writeManifest(
            io,
            snapshot,
            provenance,
            &evidence,
            source_assets,
        );
        try validateJsonFile(allocator, io, bundle, "manifest.json");
        for (evidence) |expected| {
            var path_buffer: [384]u8 = undefined;
            const path = try bundle.filePath(&path_buffer, expected.name);
            const actual = try hashFile(allocator, io, path, expected.name);
            if (actual.size != expected.size or
                !std.mem.eql(u8, &actual.sha256, &expected.sha256))
            {
                return error.ManualCaptureHashValidationFailed;
            }
        }
        try std.Io.Dir.renamePreserve(
            std.Io.Dir.cwd(),
            bundle.incompleteDirectory(),
            std.Io.Dir.cwd(),
            bundle.finalDirectory(),
            io,
        );
        bundle.finalized = true;
    }

    fn writeManifest(
        bundle: *const Bundle,
        io: std.Io,
        snapshot: *const Snapshot,
        provenance: CaptureProvenance,
        evidence: []const FileEvidence,
        source_assets: []const SourceAssetEvidence,
    ) !void {
        var path_buffer: [384]u8 = undefined;
        const path = try bundle.filePath(&path_buffer, "manifest.json");
        var file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);
        try writeFileFmt(
            &file,
            io,
            "{{\n  \"schema_version\": {d},\n  \"capture_id\": ",
            .{schema_version},
        );
        try writeJsonString(&file, io, bundle.captureId());
        try writeFileFmt(
            &file,
            io,
            ",\n  \"bundle_complete\": true,\n  \"manual_visual_acceptance\": \"pending_owner_review\",\n  \"common_state_fingerprint\": \"{x:0>16}\",\n  \"clean_debug_frame_equal\": {},\n  \"clean_debug_tick_equal\": {},\n  \"clean_debug_state_equal\": {},\n  \"manifest_self_hash\": \"not_applicable_self_referential\",\n  \"files\": [\n",
            .{
                snapshot.capture_fingerprint,
                provenance.clean_render_frame == provenance.debug_render_frame,
                provenance.clean_simulation_tick == provenance.debug_simulation_tick,
                provenance.statesMatch(),
            },
        );
        for (evidence, 0..) |item, index| {
            try file.writeStreamingAll(io, "    {\"name\": ");
            try writeJsonString(&file, io, item.name);
            try writeFileFmt(
                &file,
                io,
                ", \"byte_size\": {d}, \"sha256\": \"{x}\"}}{s}\n",
                .{ item.size, item.sha256, if (index + 1 == evidence.len) "" else "," },
            );
        }
        try file.writeStreamingAll(io, "  ],\n  \"source_assets\": [\n");
        for (source_assets, 0..) |asset, index| {
            try file.writeStreamingAll(io, "    {\"path\": ");
            try writeJsonString(&file, io, asset.path);
            try writeFileFmt(
                &file,
                io,
                ", \"byte_size\": {d}, \"sha256\": \"{x}\"}}{s}\n",
                .{ asset.size, asset.sha256, if (index + 1 == source_assets.len) "" else "," },
            );
        }
        try file.writeStreamingAll(io, "  ]\n}\n");
    }
};

pub fn utcTimestamp(io: std.Io, buffer: *[32]u8) ![]const u8 {
    const now = std.Io.Clock.real.now(io);
    if (now.nanoseconds < 0) return error.InvalidUtcTimestamp;
    const nanoseconds: u96 = @intCast(now.nanoseconds);
    const seconds: u64 = @intCast(nanoseconds / std.time.ns_per_s);
    const milliseconds: u16 = @intCast(
        (nanoseconds % std.time.ns_per_s) / std.time.ns_per_ms,
    );
    const epoch = std.time.epoch.EpochSeconds{ .secs = seconds };
    const year_day = epoch.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_seconds = epoch.getDaySeconds();
    return std.fmt.bufPrint(
        buffer,
        "{d:0>4}{d:0>2}{d:0>2}T{d:0>2}{d:0>2}{d:0>2}.{d:0>3}Z",
        .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            day_seconds.getHoursIntoDay(),
            day_seconds.getMinutesIntoHour(),
            day_seconds.getSecondsIntoMinute(),
            milliseconds,
        },
    );
}

pub fn hashSourceAsset(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) !SourceAssetEvidence {
    const evidence = try hashFile(allocator, io, path, path);
    return .{ .path = path, .size = evidence.size, .sha256 = evidence.sha256 };
}

pub fn writeRgbaPng(
    file: *std.Io.File,
    io: std.Io,
    rgba: [*]const u8,
    width: u32,
    height: u32,
    row_pitch: u32,
) !void {
    if (width == 0 or height == 0 or row_pitch < width * 4) {
        return error.InvalidPngInput;
    }
    try file.writeStreamingAll(io, &png_signature);
    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8] = 8;
    ihdr[9] = 6;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;
    try writePngChunk(file, io, "IHDR", &ihdr);

    const row_data_bytes = @as(u64, width) * 4 + 1;
    const raw_bytes = row_data_bytes * height;
    const block_count = (raw_bytes + png_deflate_block_max - 1) /
        png_deflate_block_max;
    const idat_length_u64 = 2 + raw_bytes + block_count * 5 + 4;
    if (idat_length_u64 > std.math.maxInt(u32)) return error.PngTooLarge;
    var length_buffer: [4]u8 = undefined;
    std.mem.writeInt(u32, &length_buffer, @intCast(idat_length_u64), .big);
    try file.writeStreamingAll(io, &length_buffer);
    try file.writeStreamingAll(io, "IDAT");
    var crc = std.hash.crc.Crc32.init();
    crc.update("IDAT");
    const zlib_header = [_]u8{ 0x78, 0x01 };
    try file.writeStreamingAll(io, &zlib_header);
    crc.update(&zlib_header);
    var adler_a: u32 = 1;
    var adler_b: u32 = 0;
    var raw_cursor: u64 = 0;
    var block: [png_deflate_block_max]u8 = undefined;
    while (raw_cursor < raw_bytes) {
        const remaining = raw_bytes - raw_cursor;
        const block_length: usize = @intCast(@min(remaining, block.len));
        const final_block = block_length == remaining;
        for (block[0..block_length], 0..) |*byte, offset| {
            const logical = raw_cursor + offset;
            const row = logical / row_data_bytes;
            const column = logical % row_data_bytes;
            byte.* = if (column == 0)
                0
            else
                rgba[@as(usize, @intCast(row * row_pitch + column - 1))];
            adler_a = (adler_a + byte.*) % 65521;
            adler_b = (adler_b + adler_a) % 65521;
        }
        const length: u16 = @intCast(block_length);
        var block_header = [5]u8{
            @intFromBool(final_block),
            0,
            0,
            0,
            0,
        };
        std.mem.writeInt(u16, block_header[1..3], length, .little);
        std.mem.writeInt(u16, block_header[3..5], ~length, .little);
        try file.writeStreamingAll(io, &block_header);
        try file.writeStreamingAll(io, block[0..block_length]);
        crc.update(&block_header);
        crc.update(block[0..block_length]);
        raw_cursor += block_length;
    }
    var adler: [4]u8 = undefined;
    std.mem.writeInt(u32, &adler, (adler_b << 16) | adler_a, .big);
    try file.writeStreamingAll(io, &adler);
    crc.update(&adler);
    var crc_buffer: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc_buffer, crc.final(), .big);
    try file.writeStreamingAll(io, &crc_buffer);
    try writePngChunk(file, io, "IEND", &.{});
}

const Colors = struct {
    physics: debug_draw.Color = .{ 1.0, 0.18, 0.18, 1 },
    canonical: debug_draw.Color = .{ 1.0, 0.88, 0.12, 1 },
    projected: debug_draw.Color = .{ 0.15, 0.95, 1.0, 1 },
    socket: debug_draw.Color = .{ 0.25, 1.0, 0.35, 1 },
    module: debug_draw.Color = .{ 0.72, 0.35, 1.0, 1 },
    continuous: debug_draw.Color = .{ 0.18, 1.0, 0.42, 1 },
    intentional_gap: debug_draw.Color = .{ 1.0, 0.62, 0.08, 1 },
    invalid: debug_draw.Color = .{ 1.0, 0.08, 0.08, 1 },
    inactive: debug_draw.Color = .{ 0.42, 0.46, 0.52, 0.82 },
    pivot: debug_draw.Color = .{ 1.0, 0.52, 0.08, 1 },
    landmark: debug_draw.Color = .{ 0.95, 0.95, 0.95, 1 },
    alpha: debug_draw.Color = .{ 0.20, 0.62, 1.0, 0.90 },
    anchor: debug_draw.Color = .{ 0.20, 1.0, 0.72, 1 },
    mismatch: debug_draw.Color = .{ 1.0, 0.0, 0.65, 1 },
};

pub const colors = Colors{};

fn captureCharacter(
    result: *Character,
    instance: *const character.CharacterInstance,
    presentation: character_art.Presentation,
    role: CharacterRole,
    pixels_per_meter: f32,
) !void {
    const definition = &instance.definition.skeleton_definition;
    const projection = try presentation.projectionFor(instance);
    const anatomy_definition = instance.definition.anatomy_definition orelse
        return error.CharacterHasNoAnatomy;
    const anatomy_runtime = instance.character.anatomy_runtime orelse
        return error.CharacterHasNoAnatomy;
    const anatomy_projection = try presentation_pose.FrontAnatomyProjection.init(
        projection,
        anatomy_definition,
        anatomy_runtime,
    );
    result.* = .{
        .id = instance.id.raw(),
        .role = role,
        .root = instance.world_position,
        .facing = instance.facing,
        .grounded = instance.interactionGrounded(),
        .animation_state = try Text.init(@tagName(instance.animationState())),
        .animation_time = instance.animationTime(),
        .animation_phase = instance.animationNormalizedTime(),
        .presentation_mode = try Text.init(@tagName(instance.presentationOverride())),
        .resolved_view = try Text.init(@tagName(instance.presentationView())),
        .interaction_owner = instance.interactionOwnerId(),
        .resolved_visual_count = 0,
    };
    if (instance.controller) |controller_value| {
        result.has_controller = true;
        result.controller_position = controller_value.state.position;
        result.velocity = controller_value.state.velocity;
        result.support_collider = controller_value.state.supporting_collider;
        result.has_movement_collider = true;
        result.movement_collider = try collider.characterBounds(
            controller_value.state.position,
            controller_value.configuration.collider_half_extents,
        );
    }
    const preset = anatomy_definition.body_presets[
        anatomy_runtime.selected_body_preset.index()
    ];
    result.body_preset = try Text.init(preset.stable_id.slice());
    const morphology = anatomy_definition.morphology_presets[
        anatomy_runtime.selected_morphology_preset.index()
    ];
    result.morphology_preset = try Text.init(morphology.stable_id.slice());
    if (anatomy_runtime.selected_hair) |hair_id| {
        result.selected_hair = try Text.init(
            anatomy_definition.hair_definitions[hair_id.index()].stable_id.slice(),
        );
    } else {
        result.selected_hair = try Text.init("none");
    }

    result.bone_count = definition.bones.len;
    for (definition.bones, 0..) |bone_definition, index| {
        const canonical_world = try instance.character.local_and_world_pose.worldForBone(
            definition,
            @intCast(index),
        );
        const projected_world = projection.bone_world[index];
        const canonical_transform = try Transform.fromWorld(canonical_world);
        const projected_transform = try Transform.fromWorld(projected_world);
        result.bones[index] = .{
            .index = @intCast(index),
            .name = try Text.init(bone_definition.debug_name.slice()),
            .semantic = bone_definition.semantic,
            .parent = if (bone_definition.parent_index == skeleton.no_parent)
                null
            else
                bone_definition.parent_index,
            .local = Transform.fromLocal(
                instance.character.local_and_world_pose.local_transforms[index],
            ),
            .canonical_world = canonical_transform,
            .projected_world = projected_transform,
            .position_delta_m = projected_transform.position
                .sub(canonical_transform.position).length(),
            .angular_delta_radians = angularDelta(
                canonical_transform.rotation_radians,
                projected_transform.rotation_radians,
            ),
        };
    }

    result.socket_count = definition.sockets.len;
    for (definition.sockets, 0..) |socket_definition, index| {
        const canonical_world = try instance.character.local_and_world_pose.socketWorld(
            definition,
            socket_definition.semantic,
        );
        const projected_world = projection.bone_world[socket_definition.parent_bone]
            .mul(try socket_definition.local_to_bone.localToParent());
        result.sockets[index] = .{
            .index = @intCast(index),
            .name = try Text.init(socket_definition.debug_name.slice()),
            .semantic = socket_definition.semantic,
            .parent_bone = socket_definition.parent_bone,
            .canonical_world = try Transform.fromWorld(canonical_world),
            .projected_world = try Transform.fromWorld(projected_world),
        };
    }

    const appearance_definition = instance.definition.visual_definition;
    const appearance_runtime = instance.character.appearance_runtime;
    result.attachment_count = appearance_definition.attachment_points.len;
    for (appearance_definition.attachment_points, 0..) |point, index| {
        result.attachments[index] = .{
            .index = @intCast(index),
            .name = try Text.init(point.debug_name.slice()),
            .parent_index = switch (point.parent) {
                .canonical_bone => null,
                .attachment_point => |parent| @intCast(parent.index()),
            },
            .hierarchy_depth = point.hierarchy_depth,
            .canonical_world = try Transform.fromWorld(
                appearance_runtime.attachment_point_world[index],
            ),
            .projected_world = try Transform.fromWorld(
                projection.attachment_point_world[index],
            ),
        };
    }

    const graph_definition = instance.definition.component_graph_definition orelse
        return error.CharacterHasNoComponentGraph;
    const graph = try graph_definition.view(
        appearance_definition,
        anatomy_definition,
    );
    const selected_profile = anatomy_runtime.selected_presentation_profile;
    const selected_profile_name = anatomy_definition.presentation_profiles[
        selected_profile.index()
    ].stable_id.slice();

    result.part_count = graph.componentCount();
    for (anatomy_definition.part_instances, 0..) |part, index| {
        const active = try anatomy_runtime.isPartActive(anatomy_definition, part.id);
        const graph_component = try graph.component(part.id);
        const part_definition = graph_component.definition;
        const bound_visuals = try graph.boundVisuals(part.id, selected_profile);
        if (bound_visuals.len > result.parts[index].bound_visuals.len) {
            return error.ComponentBoundVisualCapacityExceeded;
        }
        var connection_minimum: f32 = 0;
        var connection_maximum: f32 = 0;
        switch (part.connection) {
            .continuous => |value| connection_maximum = value.maximum_gap,
            .intentional_gap => |value| {
                connection_minimum = value.minimum_gap;
                connection_maximum = value.maximum_gap;
            },
            .hidden, .soft_bridge => {},
        }
        var parent_endpoint = anatomy_projection.part_binding_world[index]
            .translationPart();
        var child_endpoint = parent_endpoint;
        var parent_socket_name = try Text.init("root_attachment");
        var child_root_name = try Text.init(part.stable_id.slice());
        if (graph_component.parent_socket) |parent_socket_id| {
            const parent_socket = anatomy_definition.instance_sockets[
                parent_socket_id.index()
            ];
            parent_endpoint = anatomy_projection.socket_world[
                parent_socket_id.index()
            ].translationPart();
            parent_socket_name = try Text.init(parent_socket.stable_id.slice());
            child_endpoint = anatomy_projection.part_binding_world[index]
                .translationPart();
            if (part.articulation_module) |module_id| {
                const module = appearance_definition.rig_modules[
                    module_id.index()
                ];
                if (module.joint_count == 0) return error.RigModuleJointMissing;
                const root_joint = appearance_definition.module_joints[
                    module.joint_start
                ];
                if (root_joint.parent_joint_global != appearance.no_index) {
                    return error.InvalidRigModuleJointChain;
                }
                child_endpoint = projection.module_joint_world[
                    module.joint_start
                ].translationPart();
                child_root_name = try Text.init(root_joint.debug_name.slice());
            }
        }
        const gap_vector = child_endpoint.sub(parent_endpoint);
        const measured_gap = gap_vector.length();
        const target_gap: f32 = switch (part.connection) {
            .intentional_gap => component_graph.measuredGap(part),
            .continuous, .hidden, .soft_bridge => 0,
        };
        const connection_result: MismatchResult = if (!active)
            .not_applicable
        else switch (part.connection) {
            .continuous => |value| if (measured_gap <= value.maximum_gap)
                .pass
            else
                .fail,
            .intentional_gap => |value| if (measured_gap >= value.minimum_gap and
                measured_gap <= value.maximum_gap)
                .pass
            else
                .fail,
            .hidden, .soft_bridge => .not_applicable,
        };
        result.parts[index] = .{
            .index = @intCast(index),
            .name = try Text.init(part.stable_id.slice()),
            .definition_name = try Text.init(part_definition.stable_id.slice()),
            .semantic_role = try Text.init(part_definition.type_tag.slice()),
            .parent_part = if (graph_component.parent_component) |parent|
                @intCast(parent.index())
            else
                null,
            .parent_socket = if (graph_component.parent_socket) |socket_id|
                @intCast(socket_id.index())
            else
                null,
            .hierarchy_depth = part.hierarchy_depth,
            .active = active,
            .articulation_module = if (part.articulation_module) |module_id|
                @intCast(module_id.index())
            else
                null,
            .binding_mode = part_definition.binding_mode,
            .connection_mode = std.meta.activeTag(part.connection),
            .measured_gap_m = measured_gap,
            .minimum_gap_m = connection_minimum,
            .maximum_gap_m = connection_maximum,
            .topology_status = part.topology_status,
            .material_slot = if (part_definition.material_slot) |name|
                try Text.init(name.slice())
            else
                try Text.init("none"),
            .morphology_response = if (part_definition.morphology_response) |name|
                try Text.init(name.slice())
            else
                try Text.init("none"),
            .required_views = part_definition.required_views,
            .selected_variant = try Text.init(selected_profile_name),
            .bound_visual_count = @intCast(bound_visuals.len),
            .bound_visuals = undefined,
            .canonical_world = try Transform.fromWorld(anatomy_runtime.part_world[index]),
            .projected_world = try Transform.fromWorld(anatomy_projection.part_world[index]),
            .connection_parent_endpoint = parent_endpoint,
            .connection_child_endpoint = child_endpoint,
            .connection_gap_vector = gap_vector,
            .target_gap_m = target_gap,
            .acceptance_gap_px = measured_gap * pixels_per_meter,
            .connection_result = connection_result,
            .parent_socket_name = parent_socket_name,
            .child_root_name = child_root_name,
        };
        for (bound_visuals, 0..) |visual_id, visual_index| {
            result.parts[index].bound_visuals[visual_index] = try Text.init(
                appearance_definition.visuals[visual_id.index()].debug_name.slice(),
            );
        }
    }

    result.part_socket_count = anatomy_definition.instance_sockets.len;
    for (anatomy_definition.instance_sockets, 0..) |socket_value, index| {
        var occupancy: u16 = 0;
        for (anatomy_definition.part_instances) |part| {
            switch (part.parent) {
                .body_part_socket => |parent_socket| {
                    if (parent_socket == socket_value.id) occupancy += 1;
                },
                .attachment_point, .module_socket => {},
            }
        }
        result.part_sockets[index] = .{
            .index = @intCast(index),
            .name = try Text.init(socket_value.stable_id.slice()),
            .owner_part = @intCast(socket_value.owner.index()),
            .accepted_child_tag = if (socket_value.accepted_child_tag) |tag|
                try Text.init(tag.slice())
            else
                try Text.init("any"),
            .role = if (socket_value.role) |socket_role|
                try Text.init(socket_role.slice())
            else
                try Text.init("untyped"),
            .capacity = socket_value.capacity,
            .occupancy = occupancy,
            .supported_connections = socket_value.supported_connections,
            .canonical_world = try Transform.fromWorld(anatomy_runtime.socket_world[index]),
            .projected_world = try Transform.fromWorld(anatomy_projection.socket_world[index]),
        };
    }

    result.module_joint_count = appearance_definition.module_joints.len;
    for (appearance_definition.module_joints, 0..) |joint, index| {
        const owner_component = componentForModule(
            anatomy_definition,
            joint.module_id,
        );
        result.module_joints[index] = .{
            .index = @intCast(index),
            .name = try Text.init(joint.debug_name.slice()),
            .module_index = @intCast(joint.module_id.index()),
            .owner_component = if (owner_component) |owner|
                @intCast(owner.index())
            else
                null,
            .active = if (owner_component) |owner|
                try anatomy_runtime.isPartActive(anatomy_definition, owner)
            else
                false,
            .parent_joint = if (joint.parent_joint_global == appearance.no_index)
                null
            else
                joint.parent_joint_global,
            .canonical_world = try Transform.fromWorld(
                appearance_runtime.module_joint_world[index],
            ),
            .projected_world = try Transform.fromWorld(
                projection.module_joint_world[index],
            ),
        };
    }

    result.module_socket_count = appearance_definition.module_sockets.len;
    for (appearance_definition.module_sockets, 0..) |socket_value, index| {
        const owner_component = componentForModule(
            anatomy_definition,
            socket_value.module_id,
        );
        result.module_sockets[index] = .{
            .index = @intCast(index),
            .name = try Text.init(socket_value.debug_name.slice()),
            .module_index = @intCast(socket_value.module_id.index()),
            .owner_component = if (owner_component) |owner|
                @intCast(owner.index())
            else
                null,
            .active = if (owner_component) |owner|
                try anatomy_runtime.isPartActive(anatomy_definition, owner)
            else
                false,
            .parent_joint = if (socket_value.parent_joint_global == appearance.no_index)
                null
            else
                socket_value.parent_joint_global,
            .canonical_world = try Transform.fromWorld(
                appearance_runtime.module_socket_world[index],
            ),
            .projected_world = try Transform.fromWorld(
                projection.module_socket_world[index],
            ),
        };
    }
}

fn expectedBoneSemantic(
    role: visual_geometry.Role,
    side: visual_geometry.Side,
    kind: visual_geometry.LandmarkKind,
) ?skeleton.BoneSemantic {
    const left = side == .left;
    return switch (role) {
        .upper_arm => switch (kind) {
            .shoulder, .proximal => if (left) .left_upper_arm else .right_upper_arm,
            .elbow, .distal => if (left) .left_forearm else .right_forearm,
            else => null,
        },
        .forearm => switch (kind) {
            .elbow, .proximal => if (left) .left_forearm else .right_forearm,
            .wrist, .distal => if (left) .left_hand else .right_hand,
            else => null,
        },
        .thigh => switch (kind) {
            .hip, .proximal => if (left) .left_thigh else .right_thigh,
            .knee, .distal => if (left) .left_shin else .right_shin,
            else => null,
        },
        .shin => switch (kind) {
            .knee, .proximal => if (left) .left_shin else .right_shin,
            .ankle, .distal => if (left) .left_foot else .right_foot,
            else => null,
        },
        .foot, .shoe => switch (kind) {
            .ankle, .proximal => if (left) .left_foot else .right_foot,
            else => null,
        },
        .torso, .torso_garment => switch (kind) {
            .shoulder_left => .left_upper_arm,
            .shoulder_right => .right_upper_arm,
            .neck => .head,
            else => null,
        },
        .pelvis, .lower_garment, .waist_accessory => switch (kind) {
            .hip_left => .left_thigh,
            .hip_right => .right_thigh,
            else => null,
        },
        .sleeve => switch (kind) {
            .proximal => if (left) .left_upper_arm else .right_upper_arm,
            .distal => if (left) .left_forearm else .right_forearm,
            else => null,
        },
        .glove => switch (kind) {
            .wrist, .proximal => if (left) .left_hand else .right_hand,
            else => null,
        },
        .legwear => switch (kind) {
            .proximal => if (left) .left_shin else .right_shin,
            .ankle => if (left) .left_foot else .right_foot,
            else => null,
        },
        else => null,
    };
}

fn componentForModule(
    definition: anatomy.DefinitionView,
    module_id: appearance.RigModuleId,
) ?anatomy.BodyPartInstanceId {
    for (definition.part_instances) |part| {
        if (part.articulation_module == module_id) return part.id;
    }
    return null;
}

fn directAtlasLandmark(
    record: visual_geometry.TraceRecord,
    alpha: visual_geometry.AlphaGeometry,
    kind: visual_geometry.LandmarkKind,
) !math.Vec2 {
    const landmark = record.geometry.find(kind) orelse
        return error.MissingSemanticLandmark;
    if (record.mesh) |mesh_value| {
        if (mesh_value.vertex_count == 0) return error.EmptyVisualTruthMesh;
        const local = alpha.visibleUvToLocal(landmark.visible_uv);
        var nearest = mesh_value.vertices[0];
        var nearest_distance = std.math.inf(f32);
        for (mesh_value.vertices[0..mesh_value.vertex_count]) |vertex| {
            const dx = vertex.uv[0] - local[0];
            const dy = vertex.uv[1] - local[1];
            const distance = dx * dx + dy * dy;
            if (distance < nearest_distance) {
                nearest = vertex;
                nearest_distance = distance;
            }
        }
        return nearest.world;
    }
    const local = alpha.visibleUvToLocal(landmark.visible_uv);
    const world = sprite.localPointToWorld(record.request, local);
    return .{ .x = world[0], .y = world[1] };
}

fn visualBounds(
    record: visual_geometry.TraceRecord,
    alpha: visual_geometry.AlphaGeometry,
) !collider.Aabb {
    if (record.mesh) |mesh_value| {
        if (mesh_value.vertex_count == 0) return error.EmptyVisualTruthMesh;
        var minimum = mesh_value.vertices[0].world;
        var maximum = minimum;
        for (mesh_value.vertices[1..mesh_value.vertex_count]) |vertex| {
            minimum.x = @min(minimum.x, vertex.world.x);
            minimum.y = @min(minimum.y, vertex.world.y);
            maximum.x = @max(maximum.x, vertex.world.x);
            maximum.y = @max(maximum.y, vertex.world.y);
        }
        const bounds = collider.Aabb{ .minimum = minimum, .maximum = maximum };
        try bounds.validate();
        return bounds;
    }
    const corners = [_][2]f32{
        alpha.visibleUvToLocal(.{ 0, 0 }),
        alpha.visibleUvToLocal(.{ 1, 0 }),
        alpha.visibleUvToLocal(.{ 1, 1 }),
        alpha.visibleUvToLocal(.{ 0, 1 }),
    };
    const first = sprite.localPointToWorld(record.request, corners[0]);
    var minimum = math.Vec2{ .x = first[0], .y = first[1] };
    var maximum = minimum;
    for (corners[1..]) |corner| {
        const point = sprite.localPointToWorld(record.request, corner);
        minimum.x = @min(minimum.x, point[0]);
        minimum.y = @min(minimum.y, point[1]);
        maximum.x = @max(maximum.x, point[0]);
        maximum.y = @max(maximum.y, point[1]);
    }
    const bounds = collider.Aabb{ .minimum = minimum, .maximum = maximum };
    try bounds.validate();
    return bounds;
}

fn addMismatchCross(
    commands: *debug_draw.CommandBuffer,
    center: math.Vec2,
    color: debug_draw.Color,
) !void {
    const radius = debug_draw.marker_size_meters;
    try commands.addLine(
        center.add(.{ .x = -radius, .y = -radius }),
        center.add(.{ .x = radius, .y = radius }),
        color,
    );
    try commands.addLine(
        center.add(.{ .x = -radius, .y = radius }),
        center.add(.{ .x = radius, .y = -radius }),
        color,
    );
}

fn writeStateDocument(
    file: *std.Io.File,
    io: std.Io,
    bundle: *const Bundle,
    snapshot: *const Snapshot,
    provenance: CaptureProvenance,
) !void {
    try writeFileFmt(
        file,
        io,
        "{{\n  \"schema_version\": {d},\n  \"capture_provenance\": {{\n    \"utc_timestamp\": ",
        .{schema_version},
    );
    try writeJsonString(file, io, provenance.utc_timestamp);
    try writeFileFmt(file, io, ",\n    \"monotonic_capture_index\": {d},\n    \"capture_directory\": ", .{provenance.capture_index});
    try writeJsonString(file, io, bundle.finalDirectory());
    try file.writeStreamingAll(io, ",\n    \"git_head\": ");
    try writeJsonString(file, io, provenance.git_head);
    try writeFileFmt(
        file,
        io,
        ",\n    \"working_tree\": {{\"staged\": {}, \"unstaged\": {}, \"untracked\": {}}},\n    \"build_configuration\": ",
        .{
            provenance.staged_dirty,
            provenance.unstaged_dirty,
            provenance.untracked_dirty,
        },
    );
    try writeJsonString(file, io, provenance.build_configuration);
    try file.writeStreamingAll(io, ",\n    \"executable_arguments\": ");
    try writeJsonString(file, io, provenance.executable_arguments);
    try file.writeStreamingAll(io, ",\n    \"sdl_gpu_driver\": ");
    try writeJsonString(file, io, provenance.gpu_driver);
    try file.writeStreamingAll(io, ",\n    \"shader_format\": ");
    try writeJsonString(file, io, provenance.shader_format);
    try writeFileFmt(
        file,
        io,
        ",\n    \"viewport\": [{d}, {d}],\n    \"camera\": {{\"center\": [{d:.9}, {d:.9}], \"pixels_per_meter\": {d:.6}}},\n    \"render_frame\": {d},\n    \"simulation_tick\": {d},\n    \"selected_f1_mode\": \"{s}\",\n    \"manual_visual_acceptance\": \"pending_owner_review\"\n  }},\n",
        .{
            snapshot.viewport[0],
            snapshot.viewport[1],
            snapshot.camera_center.x,
            snapshot.camera_center.y,
            snapshot.pixels_per_meter,
            snapshot.render_frame,
            snapshot.simulation_tick,
            @tagName(snapshot.mode),
        },
    );
    try writeFileFmt(
        file,
        io,
        "  \"state_identity\": {{\n    \"authoritative_fingerprint\": \"{x:0>16}\",\n    \"presentation_fingerprint\": \"{x:0>16}\",\n    \"capture_fingerprint\": \"{x:0>16}\",\n    \"clean_debug_states_match\": {}\n  }},\n  \"optional_arm_submission_integrity\": {{\"active_optional_modules\": {d}, \"expected_optional_visual_submissions\": {d}, \"actual_optional_visual_submissions\": {d}, \"missing_optional_visual_submissions\": {d}, \"orphan_optional_visual_submissions\": {d}}},\n  \"characters\": [\n",
        .{
            snapshot.authoritative_fingerprint,
            snapshot.presentation_fingerprint,
            snapshot.capture_fingerprint,
            provenance.statesMatch(),
            snapshot.active_optional_modules,
            snapshot.expected_optional_visual_submissions,
            snapshot.actual_optional_visual_submissions,
            snapshot.missing_optional_visual_submissions,
            snapshot.orphan_optional_visual_submissions,
        },
    );
    for (snapshot.characters[0..snapshot.character_count], 0..) |truth, character_index| {
        try writeFileFmt(
            file,
            io,
            "    {{\n      \"character_id\": {d},\n      \"role\": \"{s}\",\n      \"world_root\": [{d:.9}, {d:.9}],\n      \"controller\": {{\"present\": {}, \"position\": [{d:.9}, {d:.9}], \"velocity\": [{d:.9}, {d:.9}], \"facing\": \"{s}\", \"grounded\": {}, \"support_collider\": ",
            .{
                truth.id,
                @tagName(truth.role),
                truth.root.x,
                truth.root.y,
                truth.has_controller,
                truth.controller_position.x,
                truth.controller_position.y,
                truth.velocity.x,
                truth.velocity.y,
                @tagName(truth.facing),
                truth.grounded,
            },
        );
        if (truth.support_collider) |support| {
            try writeFileFmt(file, io, "{d}", .{support});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try file.writeStreamingAll(io, ", \"movement_collider\": ");
        if (truth.has_movement_collider) {
            try writeFileFmt(
                file,
                io,
                "{{\"minimum\": [{d:.9}, {d:.9}], \"maximum\": [{d:.9}, {d:.9}]}}",
                .{
                    truth.movement_collider.minimum.x,
                    truth.movement_collider.minimum.y,
                    truth.movement_collider.maximum.x,
                    truth.movement_collider.maximum.y,
                },
            );
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try file.writeStreamingAll(io, "},\n      \"animation\": {\"state\": ");
        try writeJsonString(file, io, truth.animation_state.slice());
        try writeFileFmt(
            file,
            io,
            ", \"time_seconds\": {d:.9}, \"normalized_phase\": {d:.9}}},\n      \"presentation\": {{\"mode\": ",
            .{ truth.animation_time, truth.animation_phase },
        );
        try writeJsonString(file, io, truth.presentation_mode.slice());
        try file.writeStreamingAll(io, ", \"resolved_view\": ");
        try writeJsonString(file, io, truth.resolved_view.slice());
        try writeFileFmt(file, io, ", \"interaction_owner\": {d}}},\n      \"appearance\": {{\"body_preset\": ", .{truth.interaction_owner});
        try writeJsonString(file, io, truth.body_preset.slice());
        try file.writeStreamingAll(io, ", \"morphology_preset\": ");
        try writeJsonString(file, io, truth.morphology_preset.slice());
        try file.writeStreamingAll(io, ", \"selected_hair\": ");
        try writeJsonString(file, io, truth.selected_hair.slice());
        try file.writeStreamingAll(io, ", \"outfit\": ");
        try writeJsonString(file, io, truth.outfit.slice());
        try writeFileFmt(
            file,
            io,
            ", \"loadout_item_count\": {d}, \"resolved_visual_count\": {d}}},\n",
            .{ truth.loadout_count, truth.resolved_visual_count },
        );

        try file.writeStreamingAll(io, "      \"canonical_skeleton\": {\"bones\": [\n");
        for (truth.bones[0..truth.bone_count], 0..) |bone, index| {
            try writeFileFmt(file, io, "        {{\"index\": {d}, \"name\": ", .{bone.index});
            try writeJsonString(file, io, bone.name.slice());
            try writeFileFmt(file, io, ", \"semantic\": \"{s}\", \"parent\": ", .{@tagName(bone.semantic)});
            if (bone.parent) |parent| {
                try writeFileFmt(file, io, "{d}", .{parent});
            } else {
                try file.writeStreamingAll(io, "null");
            }
            try file.writeStreamingAll(io, ", \"local_transform\": ");
            try writeTransformJson(file, io, bone.local);
            try file.writeStreamingAll(io, ", \"world_transform\": ");
            try writeTransformJson(file, io, bone.canonical_world);
            try writeFileFmt(
                file,
                io,
                "}}{s}\n",
                .{if (index + 1 == truth.bone_count) "" else ","},
            );
        }
        try file.writeStreamingAll(io, "      ], \"sockets\": [\n");
        for (truth.sockets[0..truth.socket_count], 0..) |socket_value, index| {
            try writeFileFmt(file, io, "        {{\"index\": {d}, \"name\": ", .{socket_value.index});
            try writeJsonString(file, io, socket_value.name.slice());
            try writeFileFmt(
                file,
                io,
                ", \"semantic\": \"{s}\", \"parent_bone\": {d}, \"world_transform\": ",
                .{ @tagName(socket_value.semantic), socket_value.parent_bone },
            );
            try writeTransformJson(file, io, socket_value.canonical_world);
            try writeFileFmt(file, io, "}}{s}\n", .{if (index + 1 == truth.socket_count) "" else ","});
        }
        try file.writeStreamingAll(io, "      ]},\n");

        try file.writeStreamingAll(io, "      \"presentation_projection\": {\"bones\": [\n");
        for (truth.bones[0..truth.bone_count], 0..) |bone, index| {
            try writeFileFmt(
                file,
                io,
                "        {{\"source_index\": {d}, \"source_semantic\": \"{s}\", \"projected_world_transform\": ",
                .{ bone.index, @tagName(bone.semantic) },
            );
            try writeTransformJson(file, io, bone.projected_world);
            try writeFileFmt(
                file,
                io,
                ", \"differs_from_canonical\": {}, \"position_delta_m\": {d:.9}, \"angular_delta_radians\": {d:.9}}}{s}\n",
                .{
                    bone.position_delta_m > 0.000001 or @abs(bone.angular_delta_radians) > 0.000001,
                    bone.position_delta_m,
                    bone.angular_delta_radians,
                    if (index + 1 == truth.bone_count) "" else ",",
                },
            );
        }
        try file.writeStreamingAll(io, "      ]},\n");
        try writeComponentData(file, io, truth, snapshot);
        try writeFileFmt(
            file,
            io,
            "    }}{s}\n",
            .{if (character_index + 1 == snapshot.character_count) "" else ","},
        );
    }

    try file.writeStreamingAll(io, "  ],\n  \"final_visual_submissions\": [\n");
    for (snapshot.visuals[0..snapshot.visual_count], 0..) |visual, index| {
        try writeFileFmt(
            file,
            io,
            "    {{\"character_id\": {d}, \"stable_identity\": ",
            .{visual.character_id},
        );
        try writeJsonString(file, io, visual.stable_id.slice());
        try writeFileFmt(
            file,
            io,
            ", \"owner_type\": \"{s}\", \"semantic_role\": \"{s}\", \"side\": \"{s}\", \"body_region\": \"{s}\", \"component_id\": {d}, \"bound_identity\": {d}, \"texture_page\": {d}, \"source_pixel_rectangle\": {{\"x\": {d}, \"y\": {d}, \"width\": {d}, \"height\": {d}}}, \"uv_rectangle\": [{d:.9}, {d:.9}, {d:.9}, {d:.9}], \"world_position\": [{d:.9}, {d:.9}], \"rotation\": {d:.9}, \"scale\": [{d:.9}, {d:.9}], \"pivot\": [{d:.9}, {d:.9}], \"draw_order_key\": [{d}, {d}, {d}, {d}, {d}], \"view\": \"{s}\", \"facing\": ",
            .{
                @tagName(visual.owner),
                @tagName(visual.role),
                @tagName(visual.side),
                @tagName(visual.role),
                visual.component_id,
                visual.bound_identity,
                visual.texture_page,
                visual.source.x,
                visual.source.y,
                visual.source.width,
                visual.source.height,
                visual.uv_rect[0],
                visual.uv_rect[1],
                visual.uv_rect[2],
                visual.uv_rect[3],
                visual.world_position.x,
                visual.world_position.y,
                visual.rotation,
                visual.scale.x,
                visual.scale.y,
                visual.pivot[0],
                visual.pivot[1],
                visual.draw_order_key.scene_layer,
                visual.draw_order_key.interaction_layer,
                visual.draw_order_key.actor_layer,
                visual.draw_order_key.body_part_layer,
                visual.draw_order_key.submission_index,
                @tagName(visual.view),
            },
        );
        try writeJsonString(file, io, visual.facing.slice());
        try writeFileFmt(
            file,
            io,
            ", \"submission_visibility\": \"{s}\", \"base_visual_policy\": \"{s}\", \"covered_base_visual_owner\": {s}, \"exposed_anatomy_anchor\": {s}, \"placement_authority\": \"{s}\", \"registration\": ",
            .{
                @tagName(visual.submission_visibility),
                @tagName(visual.base_visual_policy),
                if (visual.submission_visibility == .suppressed_by_closed_footwear)
                    "\"closed_footwear\""
                else
                    "null",
                if (visual.submission_visibility == .suppressed_by_closed_footwear)
                    "\"ankle\""
                else
                    "null",
                @tagName(visual.placement_authority),
            },
        );
        if (visual.has_registration) {
            try file.writeStreamingAll(io, "{\"identity\": ");
            try writeJsonString(file, io, visual.registration_identity.slice());
            try writeFileFmt(
                file,
                io,
                ", \"binding_mode\": \"{s}\", \"scale_policy\": \"{s}\", \"mirroring_policy\": \"{s}\", \"threshold_m\": {d:.9}, \"maximum_residual_m\": {d:.9}, \"orientation_axis\": ",
                .{
                    @tagName(visual.registration_binding_mode),
                    @tagName(visual.registration_scale_policy),
                    @tagName(visual.registration_mirroring_policy),
                    visual.registration_threshold_m,
                    visual.registration_maximum_residual_m,
                },
            );
            if (visual.registration_axis) |axis| {
                try writeFileFmt(
                    file,
                    io,
                    "{{\"source_start\": \"{s}\", \"source_end\": \"{s}\", \"reference_identity\": ",
                    .{
                        @tagName(axis.source_start_landmark),
                        @tagName(axis.source_end_landmark),
                    },
                );
                try writeJsonString(file, io, axis.reference_identity);
                try writeFileFmt(
                    file,
                    io,
                    ", \"reference_vector_world\": [{d:.9}, {d:.9}], \"transformed_start_world\": [{d:.9}, {d:.9}], \"transformed_end_world\": [{d:.9}, {d:.9}], \"expected_end_world\": [{d:.9}, {d:.9}], \"endpoint_residual_m\": {d:.9}, \"angular_residual_radians\": {d:.9}, \"threshold_radians\": {d:.9}}}",
                    .{
                        axis.reference_vector_world.x,
                        axis.reference_vector_world.y,
                        axis.transformed_start_world.x,
                        axis.transformed_start_world.y,
                        axis.transformed_end_world.x,
                        axis.transformed_end_world.y,
                        axis.expected_end_world.x,
                        axis.expected_end_world.y,
                        axis.endpoint_residual_m,
                        axis.angular_residual_radians,
                        axis.threshold_radians,
                    },
                );
            } else {
                try file.writeStreamingAll(io, "null");
            }
            try file.writeStreamingAll(io, "}");
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try file.writeStreamingAll(io, ", \"graph_binding\": ");
        if (visual.graph_binding) |binding| {
            try writeFileFmt(
                file,
                io,
                "{{\"component_id\": {d}, \"component_identity\": ",
                .{binding.component_id},
            );
            try writeJsonString(file, io, binding.component_identity.slice());
            try writeFileFmt(
                file,
                io,
                ", \"parent_component_id\": {d}, \"parent_component_identity\": ",
                .{binding.parent_component_id},
            );
            try writeJsonString(file, io, binding.parent_component_identity.slice());
            try writeFileFmt(
                file,
                io,
                ", \"module_id\": {d}, \"module_identity\": ",
                .{binding.module_id},
            );
            try writeJsonString(file, io, binding.module_identity.slice());
            try writeFileFmt(
                file,
                io,
                ", \"graph_bound_visual_index\": {d}, \"source_identity\": ",
                .{binding.graph_visual_index},
            );
            try writeJsonString(file, io, binding.source_identity.slice());
            try writeFileFmt(
                file,
                io,
                ", \"start\": {{\"kind\": \"{s}\", \"global_index\": {d}, \"identity\": ",
                .{ @tagName(binding.start_kind), binding.start_global_index },
            );
            try writeJsonString(file, io, binding.start_identity.slice());
            try writeFileFmt(
                file,
                io,
                "}}, \"end\": {{\"kind\": \"{s}\", \"global_index\": {d}, \"identity\": ",
                .{ @tagName(binding.end_kind), binding.end_global_index },
            );
            try writeJsonString(file, io, binding.end_identity.slice());
            try file.writeStreamingAll(io, "}, \"submission_present\": true}");
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try writeFileFmt(
            file,
            io,
            ", \"alpha_visible_bounds\": {{\"minimum\": [{d:.9}, {d:.9}], \"maximum\": [{d:.9}, {d:.9}]}}, \"is_mesh\": {}, \"transformed_landmarks\": [",
            .{
                visual.alpha_bounds_minimum.x,
                visual.alpha_bounds_minimum.y,
                visual.alpha_bounds_maximum.x,
                visual.alpha_bounds_maximum.y,
                visual.is_mesh,
            },
        );
        for (visual.landmarks[0..visual.landmark_count], 0..) |landmark, landmark_index| {
            try writeFileFmt(
                file,
                io,
                "{{\"kind\": \"{s}\", \"world\": [{d:.9}, {d:.9}]}}{s}",
                .{
                    @tagName(landmark.kind),
                    landmark.world.x,
                    landmark.world.y,
                    if (landmark_index + 1 == visual.landmark_count) "" else ", ",
                },
            );
        }
        try writeFileFmt(
            file,
            io,
            "], \"final_submission_index\": {d}}}{s}\n",
            .{
                visual.final_submission_index,
                if (index + 1 == snapshot.visual_count) "" else ",",
            },
        );
    }

    try file.writeStreamingAll(io, "  ],\n  \"mismatches\": [\n");
    for (snapshot.mismatches[0..snapshot.mismatch_count], 0..) |mismatch, index| {
        try file.writeStreamingAll(io, "    {\"component\": ");
        try writeJsonString(file, io, mismatch.component.slice());
        try file.writeStreamingAll(io, ", \"expected_target_identity\": ");
        try writeJsonString(file, io, mismatch.expected_target.slice());
        try file.writeStreamingAll(io, ", \"atlas_landmark_identity\": ");
        try writeJsonString(file, io, mismatch.atlas_landmark.slice());
        try writeFileFmt(
            file,
            io,
            ", \"character_id\": {d}, \"expected_world_point\": [{d:.9}, {d:.9}], \"transformed_atlas_world_point\": [{d:.9}, {d:.9}], \"world_space_error_m\": {d:.9}, \"acceptance_camera_pixel_error\": {d:.6}, \"threshold_px\": {d:.6}, \"result\": \"{s}\"}}{s}\n",
            .{
                mismatch.character_id,
                mismatch.expected_world.x,
                mismatch.expected_world.y,
                mismatch.transformed_atlas_world.x,
                mismatch.transformed_atlas_world.y,
                mismatch.world_error_m,
                mismatch.pixel_error,
                mismatch.threshold_px,
                @tagName(mismatch.result),
                if (index + 1 == snapshot.mismatch_count) "" else ",",
            },
        );
    }
    try file.writeStreamingAll(io, "  ]\n}\n");
}

fn writeComponentData(
    file: *std.Io.File,
    io: std.Io,
    truth: Character,
    snapshot: *const Snapshot,
) !void {
    try file.writeStreamingAll(io, "      \"component_topology\": {\n        \"attachment_points\": [\n");
    for (truth.attachments[0..truth.attachment_count], 0..) |point, index| {
        try writeFileFmt(file, io, "          {{\"index\": {d}, \"name\": ", .{point.index});
        try writeJsonString(file, io, point.name.slice());
        try file.writeStreamingAll(io, ", \"parent_attachment\": ");
        if (point.parent_index) |parent| {
            try writeFileFmt(file, io, "{d}", .{parent});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try writeFileFmt(file, io, ", \"hierarchy_depth\": {d}, \"canonical_world\": ", .{point.hierarchy_depth});
        try writeTransformJson(file, io, point.canonical_world);
        try file.writeStreamingAll(io, ", \"projected_world\": ");
        try writeTransformJson(file, io, point.projected_world);
        try writeFileFmt(file, io, "}}{s}\n", .{if (index + 1 == truth.attachment_count) "" else ","});
    }
    try file.writeStreamingAll(io, "        ],\n        \"anatomy_parts\": [\n");
    for (truth.parts[0..truth.part_count], 0..) |part, index| {
        try writeFileFmt(file, io, "          {{\"index\": {d}, \"name\": ", .{part.index});
        try writeJsonString(file, io, part.name.slice());
        try file.writeStreamingAll(io, ", \"definition\": ");
        try writeJsonString(file, io, part.definition_name.slice());
        try file.writeStreamingAll(io, ", \"semantic_role\": ");
        try writeJsonString(file, io, part.semantic_role.slice());
        try file.writeStreamingAll(io, ", \"parent_part\": ");
        if (part.parent_part) |parent| {
            try writeFileFmt(file, io, "{d}", .{parent});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try file.writeStreamingAll(io, ", \"parent_socket\": ");
        if (part.parent_socket) |parent_socket| {
            try writeFileFmt(file, io, "{d}", .{parent_socket});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try writeFileFmt(
            file,
            io,
            ", \"active\": {}, \"hierarchy_depth\": {d}, \"binding_mode\": \"{s}\", \"connection_mode\": \"{s}\", \"measured_gap_m\": {d:.9}, \"minimum_gap_m\": {d:.9}, \"maximum_gap_m\": {d:.9}, \"topology_status\": \"{s}\", \"material_slot\": ",
            .{
                part.active,
                part.hierarchy_depth,
                @tagName(part.binding_mode),
                @tagName(part.connection_mode),
                part.measured_gap_m,
                part.minimum_gap_m,
                part.maximum_gap_m,
                @tagName(part.topology_status),
            },
        );
        try writeJsonString(file, io, part.material_slot.slice());
        try file.writeStreamingAll(io, ", \"morphology_response\": ");
        try writeJsonString(file, io, part.morphology_response.slice());
        try writeFileFmt(
            file,
            io,
            ", \"required_views\": {{\"front\": {}, \"side_left\": {}, \"side_right\": {}}}, \"selected_variant\": ",
            .{
                part.required_views.front,
                part.required_views.side_left,
                part.required_views.side_right,
            },
        );
        try writeJsonString(file, io, part.selected_variant.slice());
        try file.writeStreamingAll(io, ", \"bound_visuals\": [");
        for (part.bound_visuals[0..part.bound_visual_count], 0..) |visual_name, visual_index| {
            try writeJsonString(file, io, visual_name.slice());
            if (visual_index + 1 != part.bound_visual_count) {
                try file.writeStreamingAll(io, ", ");
            }
        }
        try file.writeStreamingAll(io, "], \"bound_visual_submission_status\": [");
        for (part.bound_visuals[0..part.bound_visual_count], 0..) |visual_name, visual_index| {
            var final_submission: ?u32 = null;
            for (snapshot.visuals[0..snapshot.visual_count]) |visual| {
                const binding = visual.graph_binding orelse continue;
                if (visual.character_id == truth.id and
                    binding.component_id == part.index and
                    std.mem.eql(
                        u8,
                        visual.stable_id.slice(),
                        visual_name.slice(),
                    ))
                {
                    final_submission = visual.final_submission_index;
                    break;
                }
            }
            try file.writeStreamingAll(io, "{\"visual_identity\": ");
            try writeJsonString(file, io, visual_name.slice());
            try writeFileFmt(
                file,
                io,
                ", \"classification\": \"{s}\", \"submission_present\": {}, \"final_submission_index\": ",
                .{
                    if (!part.active)
                        "inactive"
                    else if (final_submission != null)
                        "submitted"
                    else
                        "missing",
                    final_submission != null,
                },
            );
            if (final_submission) |submission_index| {
                try writeFileFmt(file, io, "{d}", .{submission_index});
            } else {
                try file.writeStreamingAll(io, "null");
            }
            try writeFileFmt(
                file,
                io,
                "}}{s}",
                .{if (visual_index + 1 == part.bound_visual_count) "" else ", "},
            );
        }
        try file.writeStreamingAll(io, "], \"articulation_module\": ");
        if (part.articulation_module) |module| {
            try writeFileFmt(file, io, "{d}", .{module});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try file.writeStreamingAll(io, ", \"canonical_world\": ");
        try writeTransformJson(file, io, part.canonical_world);
        try file.writeStreamingAll(io, ", \"projected_world\": ");
        try writeTransformJson(file, io, part.projected_world);
        try file.writeStreamingAll(io, ", \"connection_proof\": {\"parent_socket\": ");
        try writeJsonString(file, io, part.parent_socket_name.slice());
        try file.writeStreamingAll(io, ", \"child_root\": ");
        try writeJsonString(file, io, part.child_root_name.slice());
        try writeFileFmt(
            file,
            io,
            ", \"parent_endpoint\": [{d:.9}, {d:.9}], \"child_endpoint\": [{d:.9}, {d:.9}], \"target_gap_m\": {d:.9}, \"measured_gap_m\": {d:.9}, \"gap_vector\": [{d:.9}, {d:.9}], \"acceptance_camera_gap_px\": {d:.6}, \"accepted_range_m\": [{d:.9}, {d:.9}], \"result\": \"{s}\"}}",
            .{
                part.connection_parent_endpoint.x,
                part.connection_parent_endpoint.y,
                part.connection_child_endpoint.x,
                part.connection_child_endpoint.y,
                part.target_gap_m,
                part.measured_gap_m,
                part.connection_gap_vector.x,
                part.connection_gap_vector.y,
                part.acceptance_gap_px,
                part.minimum_gap_m,
                part.maximum_gap_m,
                @tagName(part.connection_result),
            },
        );
        try writeFileFmt(file, io, "}}{s}\n", .{if (index + 1 == truth.part_count) "" else ","});
    }
    try file.writeStreamingAll(io, "        ],\n        \"part_sockets\": [\n");
    for (truth.part_sockets[0..truth.part_socket_count], 0..) |socket_value, index| {
        try writeFileFmt(file, io, "          {{\"index\": {d}, \"name\": ", .{socket_value.index});
        try writeJsonString(file, io, socket_value.name.slice());
        try writeFileFmt(file, io, ", \"owner_part\": {d}, \"accepted_child_tag\": ", .{socket_value.owner_part});
        try writeJsonString(file, io, socket_value.accepted_child_tag.slice());
        try file.writeStreamingAll(io, ", \"role\": ");
        try writeJsonString(file, io, socket_value.role.slice());
        try writeFileFmt(
            file,
            io,
            ", \"capacity\": {d}, \"occupancy\": {d}, \"supported_connections\": {{\"continuous\": {}, \"intentional_gap\": {}, \"hidden\": {}, \"soft_bridge\": {}}}",
            .{
                socket_value.capacity,
                socket_value.occupancy,
                socket_value.supported_connections.continuous,
                socket_value.supported_connections.intentional_gap,
                socket_value.supported_connections.hidden,
                socket_value.supported_connections.soft_bridge,
            },
        );
        try file.writeStreamingAll(io, ", \"canonical_world\": ");
        try writeTransformJson(file, io, socket_value.canonical_world);
        try file.writeStreamingAll(io, ", \"projected_world\": ");
        try writeTransformJson(file, io, socket_value.projected_world);
        try writeFileFmt(file, io, "}}{s}\n", .{if (index + 1 == truth.part_socket_count) "" else ","});
    }
    try file.writeStreamingAll(io, "        ],\n        \"rig_modules\": {\"joints\": [\n");
    for (truth.module_joints[0..truth.module_joint_count], 0..) |joint, index| {
        try writeFileFmt(file, io, "          {{\"index\": {d}, \"name\": ", .{joint.index});
        try writeJsonString(file, io, joint.name.slice());
        try writeFileFmt(file, io, ", \"module\": {d}, \"owner_component\": ", .{joint.module_index});
        if (joint.owner_component) |owner| {
            try writeFileFmt(file, io, "{d}", .{owner});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try writeFileFmt(file, io, ", \"active\": {}, \"parent_joint\": ", .{joint.active});
        if (joint.parent_joint) |parent| {
            try writeFileFmt(file, io, "{d}", .{parent});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try file.writeStreamingAll(io, ", \"canonical_world\": ");
        try writeTransformJson(file, io, joint.canonical_world);
        try file.writeStreamingAll(io, ", \"projected_world\": ");
        try writeTransformJson(file, io, joint.projected_world);
        try writeFileFmt(file, io, "}}{s}\n", .{if (index + 1 == truth.module_joint_count) "" else ","});
    }
    try file.writeStreamingAll(io, "        ], \"sockets\": [\n");
    for (truth.module_sockets[0..truth.module_socket_count], 0..) |socket_value, index| {
        try writeFileFmt(file, io, "          {{\"index\": {d}, \"name\": ", .{socket_value.index});
        try writeJsonString(file, io, socket_value.name.slice());
        try writeFileFmt(file, io, ", \"module\": {d}, \"owner_component\": ", .{socket_value.module_index});
        if (socket_value.owner_component) |owner| {
            try writeFileFmt(file, io, "{d}", .{owner});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try writeFileFmt(file, io, ", \"active\": {}, \"parent_joint\": ", .{socket_value.active});
        if (socket_value.parent_joint) |parent| {
            try writeFileFmt(file, io, "{d}", .{parent});
        } else {
            try file.writeStreamingAll(io, "null");
        }
        try file.writeStreamingAll(io, ", \"canonical_world\": ");
        try writeTransformJson(file, io, socket_value.canonical_world);
        try file.writeStreamingAll(io, ", \"projected_world\": ");
        try writeTransformJson(file, io, socket_value.projected_world);
        try writeFileFmt(file, io, "}}{s}\n", .{if (index + 1 == truth.module_socket_count) "" else ","});
    }
    try file.writeStreamingAll(io, "        ]}\n      }\n");
}

fn writeTransformJson(
    file: *std.Io.File,
    io: std.Io,
    value: Transform,
) !void {
    try writeFileFmt(
        file,
        io,
        "{{\"position\": [{d:.9}, {d:.9}], \"rotation_radians\": {d:.9}, \"scale\": [{d:.9}, {d:.9}]}}",
        .{
            value.position.x,
            value.position.y,
            value.rotation_radians,
            value.scale.x,
            value.scale.y,
        },
    );
}

fn writeJsonString(file: *std.Io.File, io: std.Io, value: []const u8) !void {
    try file.writeStreamingAll(io, "\"");
    var start: usize = 0;
    for (value, 0..) |byte, index| {
        const replacement: ?[]const u8 = switch (byte) {
            '"' => "\\\"",
            '\\' => "\\\\",
            '\n' => "\\n",
            '\r' => "\\r",
            '\t' => "\\t",
            else => null,
        };
        if (replacement) |escaped| {
            if (index > start) try file.writeStreamingAll(io, value[start..index]);
            try file.writeStreamingAll(io, escaped);
            start = index + 1;
        } else if (byte < 0x20) {
            if (index > start) try file.writeStreamingAll(io, value[start..index]);
            try writeFileFmt(file, io, "\\u00{x:0>2}", .{byte});
            start = index + 1;
        }
    }
    if (start < value.len) try file.writeStreamingAll(io, value[start..]);
    try file.writeStreamingAll(io, "\"");
}

fn writeFileFmt(
    file: *std.Io.File,
    io: std.Io,
    comptime format: []const u8,
    args: anytype,
) !void {
    var buffer: [4096]u8 = undefined;
    const rendered = try std.fmt.bufPrint(&buffer, format, args);
    try file.writeStreamingAll(io, rendered);
}

fn summaryInsertion(
    snapshot: *const Snapshot,
    ranked: []const u16,
    candidate: Mismatch,
) usize {
    const candidate_severity = resultSeverity(candidate.result);
    for (ranked, 0..) |raw_index, index| {
        const existing = snapshot.mismatches[raw_index];
        const existing_severity = resultSeverity(existing.result);
        if (candidate_severity > existing_severity or
            (candidate_severity == existing_severity and
                candidate.pixel_error > existing.pixel_error))
        {
            return index;
        }
    }
    return ranked.len;
}

fn resultSeverity(result: MismatchResult) u8 {
    return switch (result) {
        .fail => 2,
        .not_applicable => 1,
        .pass => 0,
    };
}

fn upperResult(result: MismatchResult) []const u8 {
    return switch (result) {
        .pass => "PASS",
        .fail => "FAIL",
        .not_applicable => "NOT APPLICABLE",
    };
}

fn validateTimestamp(value: []const u8) !void {
    if (value.len != 20 or value[8] != 'T' or value[15] != '.' or value[19] != 'Z') {
        return error.InvalidUtcTimestamp;
    }
    for (value, 0..) |byte, index| {
        if (index == 8 or index == 15 or index == 19) continue;
        if (!std.ascii.isDigit(byte)) return error.InvalidUtcTimestamp;
    }
}

pub fn isManualCaptureId(value: []const u8) bool {
    if (value.len < 25 or value[20] != '_') return false;
    validateTimestamp(value[0..20]) catch return false;
    for (value[21..]) |byte| {
        if (!std.ascii.isDigit(byte)) return false;
    }
    return true;
}

fn hashFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    name: []const u8,
) !FileEvidence {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(64 * 1024 * 1024),
    );
    defer allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .name = name, .size = bytes.len, .sha256 = digest };
}

fn validatePngFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    bundle: *const Bundle,
    filename: []const u8,
) !void {
    var path_buffer: [384]u8 = undefined;
    const path = try bundle.filePath(&path_buffer, filename);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(16 * 1024 * 1024),
    );
    defer allocator.free(bytes);
    if (bytes.len < png_signature.len or
        !std.mem.eql(u8, bytes[0..png_signature.len], &png_signature))
    {
        return error.InvalidManualCapturePng;
    }
}

fn validateJsonFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    bundle: *const Bundle,
    filename: []const u8,
) !void {
    var path_buffer: [384]u8 = undefined;
    const path = try bundle.filePath(&path_buffer, filename);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(16 * 1024 * 1024),
    );
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        bytes,
        .{},
    ) catch return error.InvalidManualCaptureJson;
    parsed.deinit();
}

const png_signature = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };
const png_deflate_block_max: usize = 65_535;

fn writePngChunk(
    file: *std.Io.File,
    io: std.Io,
    chunk_type: []const u8,
    data: []const u8,
) !void {
    if (chunk_type.len != 4 or data.len > std.math.maxInt(u32)) {
        return error.InvalidPngChunk;
    }
    var length_buffer: [4]u8 = undefined;
    std.mem.writeInt(u32, &length_buffer, @intCast(data.len), .big);
    try file.writeStreamingAll(io, &length_buffer);
    try file.writeStreamingAll(io, chunk_type);
    try file.writeStreamingAll(io, data);
    var crc = std.hash.crc.Crc32.init();
    crc.update(chunk_type);
    crc.update(data);
    var crc_buffer: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc_buffer, crc.final(), .big);
    try file.writeStreamingAll(io, &crc_buffer);
}

fn angularDelta(left: f32, right: f32) f32 {
    const raw = @mod(right - left + std.math.pi, 2.0 * std.math.pi);
    return raw - std.math.pi;
}

const fnv_offset: u64 = 14695981039346656037;
const fnv_prime: u64 = 1099511628211;

fn hashValue(hash: *u64, value: anytype) void {
    for (std.mem.asBytes(&value)) |byte| {
        hash.* = (hash.* ^ byte) *% fnv_prime;
    }
}

fn hashOptionalValue(hash: *u64, value: anytype) void {
    if (value) |payload| {
        hashValue(hash, @as(u8, 1));
        hashValue(hash, payload);
    } else {
        hashValue(hash, @as(u8, 0));
    }
}

fn hashBytes(hash: *u64, bytes: []const u8) void {
    for (bytes) |byte| {
        hash.* = (hash.* ^ byte) *% fnv_prime;
    }
}
