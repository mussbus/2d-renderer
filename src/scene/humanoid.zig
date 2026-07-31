const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const appearance = @import("appearance");
const anatomy = @import("anatomy");
const component_graph = @import("component_graph");
const sprite = @import("sprite_batch");
const fault_injection = @import("fault_injection");

pub const canonical_attachment_semantic_count: usize = 15;
pub const default_visual_count: usize = 15;

pub const Facing = enum(u8) { left, right };

pub const AttachmentSemantic = enum(u8) {
    pelvis,
    torso,
    head,
    left_upper_arm,
    left_forearm,
    left_hand,
    right_upper_arm,
    right_forearm,
    right_hand,
    left_thigh,
    left_shin,
    left_foot,
    right_thigh,
    right_shin,
    right_foot,
};

pub const BodyPartLayers = struct {
    pub const back_thigh: u16 = 10;
    pub const back_shin: u16 = 11;
    pub const back_foot: u16 = 12;
    pub const back_upper_arm: u16 = 20;
    pub const back_forearm: u16 = 21;
    pub const back_hand: u16 = 22;
    pub const pelvis: u16 = 30;
    pub const torso: u16 = 31;
    pub const head: u16 = 40;
    pub const front_thigh: u16 = 50;
    pub const front_shin: u16 = 51;
    pub const front_foot: u16 = 52;
    pub const front_upper_arm: u16 = 60;
    pub const front_forearm: u16 = 61;
    pub const front_hand: u16 = 62;
};

pub fn defaultBodyPartLayer(semantic: AttachmentSemantic, facing: Facing) u16 {
    const left_is_front = facing == .left;
    return switch (semantic) {
        .pelvis => BodyPartLayers.pelvis,
        .torso => BodyPartLayers.torso,
        .head => BodyPartLayers.head,
        .left_upper_arm => if (left_is_front) BodyPartLayers.front_upper_arm else BodyPartLayers.back_upper_arm,
        .left_forearm => if (left_is_front) BodyPartLayers.front_forearm else BodyPartLayers.back_forearm,
        .left_hand => if (left_is_front) BodyPartLayers.front_hand else BodyPartLayers.back_hand,
        .right_upper_arm => if (left_is_front) BodyPartLayers.back_upper_arm else BodyPartLayers.front_upper_arm,
        .right_forearm => if (left_is_front) BodyPartLayers.back_forearm else BodyPartLayers.front_forearm,
        .right_hand => if (left_is_front) BodyPartLayers.back_hand else BodyPartLayers.front_hand,
        .left_thigh => if (left_is_front) BodyPartLayers.front_thigh else BodyPartLayers.back_thigh,
        .left_shin => if (left_is_front) BodyPartLayers.front_shin else BodyPartLayers.back_shin,
        .left_foot => if (left_is_front) BodyPartLayers.front_foot else BodyPartLayers.back_foot,
        .right_thigh => if (left_is_front) BodyPartLayers.back_thigh else BodyPartLayers.front_thigh,
        .right_shin => if (left_is_front) BodyPartLayers.back_shin else BodyPartLayers.front_shin,
        .right_foot => if (left_is_front) BodyPartLayers.back_foot else BodyPartLayers.front_foot,
    };
}

comptime {
    if (std.enums.values(AttachmentSemantic).len != canonical_attachment_semantic_count) @compileError("humanoid attachment semantic count mismatch");
}

pub const RenderAttachmentInput = appearance.VisualAttachmentInput;
pub const RenderAttachment = appearance.VisualAttachment;
pub const VisualDefinitionInputs = appearance.DefinitionInputs;
pub const AttachmentPointId = appearance.AttachmentPointId;
pub const VisualAttachmentId = appearance.VisualAttachmentId;
pub const BodyRegionId = appearance.BodyRegionId;
pub const VisualGroupId = appearance.VisualGroupId;
pub const RigModuleId = appearance.RigModuleId;
pub const ModuleJointId = appearance.ModuleJointId;
pub const ModuleSocketId = appearance.ModuleSocketId;

pub const SpriteTransform = struct {
    world_position: math.Vec2,
    rotation_radians: f32,
    signed_scale: math.Vec2,
};

pub fn spriteTransform(world: math.Mat3) !SpriteTransform {
    if (!world.isFinite()) return error.InvalidNonFiniteTransform;
    const x_length = @sqrt(world.values[0] * world.values[0] + world.values[1] * world.values[1]);
    const y_length = @sqrt(world.values[3] * world.values[3] + world.values[4] * world.values[4]);
    const determinant = world.values[0] * world.values[4] - world.values[1] * world.values[3];
    if (!std.math.isFinite(x_length) or !std.math.isFinite(y_length) or x_length == 0 or y_length == 0) {
        return error.InvalidSpriteBasis;
    }
    if (determinant < 0) {
        return .{
            .world_position = world.translationPart(),
            .rotation_radians = std.math.atan2(-world.values[1], -world.values[0]),
            .signed_scale = .{ .x = -x_length, .y = y_length },
        };
    }
    return .{
        .world_position = world.translationPart(),
        .rotation_radians = std.math.atan2(world.values[1], world.values[0]),
        .signed_scale = .{ .x = x_length, .y = y_length },
    };
}

pub const HumanoidDefinition = struct {
    allocator: std.mem.Allocator,
    skeleton_definition: skeleton.SkeletonDefinition,
    visual_definition: appearance.Definition,
    anatomy_definition: ?anatomy.Definition,
    component_graph_definition: ?component_graph.Definition,
    attachments: []const RenderAttachment,
    attachment_semantic_indices: [canonical_attachment_semantic_count]?VisualAttachmentId,

    pub fn init(allocator: std.mem.Allocator, injector: ?fault_injection.Injector) !HumanoidDefinition {
        const bones = boneInputs();
        const sockets = socketInputs();
        const attachment_points = attachmentPointInputs();
        const body_regions = bodyRegionInputs();
        const visual_groups = visualGroupInputs();
        const rig_modules = [_]appearance.RigModuleInput{};
        const visual_inputs = attachmentInputs();
        return initFromVisualDefinition(allocator, &bones, &sockets, .{
            .attachment_points = &attachment_points,
            .body_regions = &body_regions,
            .visual_groups = &visual_groups,
            .rig_modules = &rig_modules,
            .visuals = &visual_inputs,
        }, injector);
    }

    pub fn initFromInputs(
        allocator: std.mem.Allocator,
        bones: []const skeleton.BoneDefinitionInput,
        sockets: []const skeleton.SocketDefinitionInput,
        attachment_inputs: []const RenderAttachmentInput,
        injector: ?fault_injection.Injector,
    ) !HumanoidDefinition {
        const attachment_points = attachmentPointInputs();
        const body_regions = bodyRegionInputs();
        const visual_groups = visualGroupInputs();
        const rig_modules = [_]appearance.RigModuleInput{};
        return initFromVisualDefinition(allocator, bones, sockets, .{
            .attachment_points = &attachment_points,
            .body_regions = &body_regions,
            .visual_groups = &visual_groups,
            .rig_modules = &rig_modules,
            .visuals = attachment_inputs,
        }, injector);
    }

    pub fn initFromVisualDefinition(
        allocator: std.mem.Allocator,
        bones: []const skeleton.BoneDefinitionInput,
        sockets: []const skeleton.SocketDefinitionInput,
        visual_inputs: VisualDefinitionInputs,
        injector: ?fault_injection.Injector,
    ) !HumanoidDefinition {
        return initFromVisualDefinitionOptionalAnatomy(
            allocator,
            bones,
            sockets,
            visual_inputs,
            null,
            injector,
        );
    }

    pub fn initFromVisualDefinitionAndAnatomy(
        allocator: std.mem.Allocator,
        bones: []const skeleton.BoneDefinitionInput,
        sockets: []const skeleton.SocketDefinitionInput,
        visual_inputs: VisualDefinitionInputs,
        anatomy_inputs: anatomy.DefinitionInputs,
        injector: ?fault_injection.Injector,
    ) !HumanoidDefinition {
        return initFromVisualDefinitionOptionalAnatomy(
            allocator,
            bones,
            sockets,
            visual_inputs,
            anatomy_inputs,
            injector,
        );
    }

    fn initFromVisualDefinitionOptionalAnatomy(
        allocator: std.mem.Allocator,
        bones: []const skeleton.BoneDefinitionInput,
        sockets: []const skeleton.SocketDefinitionInput,
        visual_inputs: VisualDefinitionInputs,
        anatomy_inputs: ?anatomy.DefinitionInputs,
        injector: ?fault_injection.Injector,
    ) !HumanoidDefinition {
        var skeleton_definition = try skeleton.SkeletonDefinition.initHumanoid(allocator, bones, sockets, injector);
        errdefer skeleton_definition.deinit();
        var visual_definition = try appearance.Definition.init(
            allocator,
            &skeleton_definition,
            canonical_attachment_semantic_count,
            visual_inputs,
            injector,
        );
        errdefer visual_definition.deinit();
        var anatomy_definition: ?anatomy.Definition = null;
        errdefer if (anatomy_definition) |*value| value.deinit();
        if (anatomy_inputs) |inputs| {
            anatomy_definition = try anatomy.Definition.init(
                allocator,
                visual_definition.view(),
                inputs,
                injector,
            );
        }
        const component_graph_definition = if (anatomy_definition) |*value|
            try component_graph.Definition.init(
                visual_definition.view(),
                value.view(),
            )
        else
            null;

        var lookup = [_]?VisualAttachmentId{null} ** canonical_attachment_semantic_count;
        for (visual_definition.visuals) |visual| {
            if (visual.canonical_semantic) |raw_semantic| {
                lookup[raw_semantic] = visual.id;
            }
            try sprite.validateRequest(.{
                .world_position = .{ 0, 0 },
                .rotation = 0,
                .scale = visual.sprite_size.toArray(),
                .pivot = visual.pivot,
                .uv_rect = visual.uv_rect,
                .tint = visual.tint,
                .texture_page = visual.texture_page,
                .order = .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = visual.body_part_layer },
            }, 1);
        }

        return .{
            .allocator = allocator,
            .skeleton_definition = skeleton_definition,
            .visual_definition = visual_definition,
            .anatomy_definition = anatomy_definition,
            .component_graph_definition = component_graph_definition,
            .attachments = visual_definition.visuals,
            .attachment_semantic_indices = lookup,
        };
    }

    pub fn deinit(definition: *HumanoidDefinition) void {
        if (definition.anatomy_definition) |*value| value.deinit();
        definition.visual_definition.deinit();
        definition.skeleton_definition.deinit();
        definition.* = undefined;
    }

    pub fn attachment(definition: HumanoidDefinition, semantic: AttachmentSemantic) !*const RenderAttachment {
        const id = definition.attachment_semantic_indices[@intFromEnum(semantic)] orelse return error.MissingCanonicalVisual;
        return &definition.attachments[id.index()];
    }
};

pub const HumanoidCharacter = struct {
    local_and_world_pose: pose.Pose,
    appearance_runtime: appearance.Runtime,
    anatomy_runtime: ?anatomy.Runtime,
    character_to_world: math.Transform2D = math.Transform2D.identity(),

    pub fn init(allocator: std.mem.Allocator, definition: *const HumanoidDefinition, injector: ?fault_injection.Injector) !HumanoidCharacter {
        var pose_state = try pose.Pose.init(allocator, &definition.skeleton_definition, injector);
        errdefer pose_state.deinit();
        var appearance_runtime = try appearance.Runtime.init(allocator, definition.visual_definition.view(), injector);
        errdefer appearance_runtime.deinit();
        var anatomy_runtime: ?anatomy.Runtime = null;
        errdefer if (anatomy_runtime) |*value| value.deinit();
        if (definition.anatomy_definition) |*anatomy_definition| {
            anatomy_runtime = try anatomy.Runtime.init(allocator, anatomy_definition.view(), injector);
        }
        try after(injector, .humanoid_character_initialization);
        return .{
            .local_and_world_pose = pose_state,
            .appearance_runtime = appearance_runtime,
            .anatomy_runtime = anatomy_runtime,
        };
    }

    pub fn deinit(character: *HumanoidCharacter) void {
        if (character.anatomy_runtime) |*value| value.deinit();
        character.appearance_runtime.deinit();
        character.local_and_world_pose.deinit();
        character.* = undefined;
    }

    pub fn applyProgrammaticPose(character: *HumanoidCharacter, definition: *const HumanoidDefinition, frame: u32) !void {
        const skeleton_definition = &definition.skeleton_definition;
        try character.local_and_world_pose.restoreAllToRest(skeleton_definition);
        character.character_to_world = math.Transform2D.identity();

        if (frame >= 75) {
            var upper_arm = try character.local_and_world_pose.localForSemantic(skeleton_definition, .right_upper_arm);
            upper_arm.rotation_radians += 35.0 * std.math.pi / 180.0;
            try character.local_and_world_pose.setLocalSemantic(skeleton_definition, .right_upper_arm, upper_arm);
            var forearm = try character.local_and_world_pose.localForSemantic(skeleton_definition, .right_forearm);
            forearm.rotation_radians -= 55.0 * std.math.pi / 180.0;
            try character.local_and_world_pose.setLocalSemantic(skeleton_definition, .right_forearm, forearm);
        }
        if (frame >= 150) {
            var thigh = try character.local_and_world_pose.localForSemantic(skeleton_definition, .left_thigh);
            thigh.rotation_radians += 24.0 * std.math.pi / 180.0;
            try character.local_and_world_pose.setLocalSemantic(skeleton_definition, .left_thigh, thigh);
            var shin = try character.local_and_world_pose.localForSemantic(skeleton_definition, .left_shin);
            shin.rotation_radians -= 38.0 * std.math.pi / 180.0;
            try character.local_and_world_pose.setLocalSemantic(skeleton_definition, .left_shin, shin);
        }
        if (frame >= 225) {
            character.character_to_world = math.Transform2D.init(.{ .x = 0.55, .y = 0.18 }, 10.0 * std.math.pi / 180.0, math.Vec2.one);
        }
        try character.local_and_world_pose.evaluateWorld(skeleton_definition, character.character_to_world);
        try character.evaluateAppearance(definition);
    }

    pub fn submitAttachments(
        character: *const HumanoidCharacter,
        definition: *const HumanoidDefinition,
        batch: *sprite.SpriteBatch,
        actor_layer: u16,
    ) !u32 {
        var submitted: u32 = 0;
        for (definition.attachments) |attachment_definition| {
            if (!try character.appearance_runtime.isVisible(definition.visual_definition.view(), attachment_definition.id)) continue;
            const world = try attachmentWorld(character, definition, &attachment_definition);
            const sprite_transform = try spriteTransform(world);
            const world_size = sprite_transform.signed_scale.componentMul(attachment_definition.sprite_size);
            try batch.submit(.{
                .world_position = sprite_transform.world_position.toArray(),
                .rotation = sprite_transform.rotation_radians,
                .scale = world_size.toArray(),
                .pivot = attachment_definition.pivot,
                .uv_rect = attachment_definition.uv_rect,
                .tint = attachment_definition.tint,
                .texture_page = attachment_definition.texture_page,
                .order = .{
                    .scene_layer = 0,
                    .interaction_layer = 0,
                    .actor_layer = actor_layer,
                    .body_part_layer = attachment_definition.body_part_layer,
                },
            });
            submitted += 1;
        }
        return submitted;
    }

    pub fn attachmentWorld(character: *const HumanoidCharacter, definition: *const HumanoidDefinition, attachment_definition: *const RenderAttachment) !math.Mat3 {
        return character.appearance_runtime.visualWorld(definition.visual_definition.view(), attachment_definition.id);
    }

    pub fn evaluateAppearance(character: *HumanoidCharacter, definition: *const HumanoidDefinition) !void {
        if (character.anatomy_runtime) |*runtime| {
            const anatomy_definition = if (definition.anatomy_definition) |*value| value else return error.AnatomyDefinitionMismatch;
            try runtime.applyAppearanceState(
                anatomy_definition.view(),
                definition.visual_definition.view(),
                &character.appearance_runtime,
            );
        }
        try character.appearance_runtime.evaluate(
            definition.visual_definition.view(),
            &definition.skeleton_definition,
            &character.local_and_world_pose,
        );
        if (character.anatomy_runtime) |*runtime| {
            const anatomy_definition = if (definition.anatomy_definition) |*value| value else return error.AnatomyDefinitionMismatch;
            try runtime.evaluateHierarchy(
                anatomy_definition.view(),
                definition.visual_definition.view(),
                &character.appearance_runtime,
            );
        }
    }

    pub fn resetAppearance(character: *HumanoidCharacter, definition: *const HumanoidDefinition) !void {
        try character.appearance_runtime.reset(definition.visual_definition.view());
        if (character.anatomy_runtime) |*runtime| {
            const anatomy_definition = if (definition.anatomy_definition) |*value| value else return error.AnatomyDefinitionMismatch;
            try runtime.reset(anatomy_definition.view());
        }
        try character.evaluateAppearance(definition);
    }
};

pub const DemoCharacter = struct {
    definition: HumanoidDefinition,
    character: HumanoidCharacter,

    pub fn init(allocator: std.mem.Allocator, injector: ?fault_injection.Injector) !DemoCharacter {
        var definition = try HumanoidDefinition.init(allocator, injector);
        errdefer definition.deinit();
        var character = try HumanoidCharacter.init(allocator, &definition, injector);
        errdefer character.deinit();
        return .{ .definition = definition, .character = character };
    }

    pub fn deinit(demo: *DemoCharacter) void {
        demo.character.deinit();
        demo.definition.deinit();
        demo.* = undefined;
    }
};

pub fn runFaultInjectionChecks(allocator: std.mem.Allocator) !void {
    for (fault_injection.humanoid_initialization_stages) |stage| {
        var attempt = DemoCharacter.init(allocator, .{ .fail_after = stage }) catch |err| {
            if (err != error.InjectedInitializationFailure) return err;
            var clean = try DemoCharacter.init(allocator, null);
            clean.deinit();
            std.log.info("humanoid fault-injection cleanup check passed after {s}", .{@tagName(stage)});
            continue;
        };
        attempt.deinit();
        return error.FaultInjectionDidNotTrigger;
    }
}

pub fn boneInputs() [skeleton.bone_semantic_count]skeleton.BoneDefinitionInput {
    const identity = math.Transform2D.identity();
    return .{
        .{ .debug_name = "root", .parent_index = null, .rest_local = identity, .semantic = @intFromEnum(skeleton.BoneSemantic.root) },
        .{ .debug_name = "pelvis", .parent_index = 0, .rest_local = math.Transform2D.init(.{ .x = 0, .y = 0.9 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.pelvis) },
        .{ .debug_name = "torso", .parent_index = 1, .rest_local = math.Transform2D.init(.{ .x = 0, .y = 0.35 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.torso) },
        .{ .debug_name = "head", .parent_index = 2, .rest_local = math.Transform2D.init(.{ .x = 0, .y = 1.5 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.head) },
        .{ .debug_name = "left_upper_arm", .parent_index = 2, .rest_local = math.Transform2D.init(.{ .x = -0.45, .y = 1.0 }, std.math.pi, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.left_upper_arm) },
        .{ .debug_name = "left_forearm", .parent_index = 4, .rest_local = math.Transform2D.init(.{ .x = 0.65, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.left_forearm) },
        .{ .debug_name = "left_hand", .parent_index = 5, .rest_local = math.Transform2D.init(.{ .x = 0.55, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.left_hand) },
        .{ .debug_name = "right_upper_arm", .parent_index = 2, .rest_local = math.Transform2D.init(.{ .x = 0.45, .y = 1.0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.right_upper_arm) },
        .{ .debug_name = "right_forearm", .parent_index = 7, .rest_local = math.Transform2D.init(.{ .x = 0.65, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.right_forearm) },
        .{ .debug_name = "right_hand", .parent_index = 8, .rest_local = math.Transform2D.init(.{ .x = 0.55, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.right_hand) },
        .{ .debug_name = "left_thigh", .parent_index = 1, .rest_local = math.Transform2D.init(.{ .x = -0.2, .y = -0.2 }, -std.math.pi / 2.0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.left_thigh) },
        .{ .debug_name = "left_shin", .parent_index = 10, .rest_local = math.Transform2D.init(.{ .x = 0.9, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.left_shin) },
        .{ .debug_name = "left_foot", .parent_index = 11, .rest_local = math.Transform2D.init(.{ .x = 0.85, .y = 0 }, std.math.pi / 2.0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.left_foot) },
        .{ .debug_name = "right_thigh", .parent_index = 1, .rest_local = math.Transform2D.init(.{ .x = 0.2, .y = -0.2 }, -std.math.pi / 2.0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.right_thigh) },
        .{ .debug_name = "right_shin", .parent_index = 13, .rest_local = math.Transform2D.init(.{ .x = 0.9, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.right_shin) },
        .{ .debug_name = "right_foot", .parent_index = 14, .rest_local = math.Transform2D.init(.{ .x = 0.85, .y = 0 }, std.math.pi / 2.0, math.Vec2.one), .semantic = @intFromEnum(skeleton.BoneSemantic.right_foot) },
    };
}

pub fn socketInputs() [skeleton.socket_semantic_count]skeleton.SocketDefinitionInput {
    return .{
        .{ .debug_name = "left_hand", .parent_bone = 6, .local_to_bone = math.Transform2D.init(.{ .x = 0.25, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.SocketSemantic.left_hand) },
        .{ .debug_name = "right_hand", .parent_bone = 9, .local_to_bone = math.Transform2D.init(.{ .x = 0.25, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.SocketSemantic.right_hand) },
        .{ .debug_name = "left_foot", .parent_bone = 12, .local_to_bone = math.Transform2D.init(.{ .x = 0.35, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.SocketSemantic.left_foot) },
        .{ .debug_name = "right_foot", .parent_bone = 15, .local_to_bone = math.Transform2D.init(.{ .x = 0.35, .y = 0 }, 0, math.Vec2.one), .semantic = @intFromEnum(skeleton.SocketSemantic.right_foot) },
    };
}

pub const conventional_attachment_point_count: usize = 16;
pub const default_body_region_count: usize = 11;
pub const default_visual_group_count: usize = 1;

pub fn attachmentPointInputs() [conventional_attachment_point_count]appearance.AttachmentPointInput {
    const identity = math.Transform2D.identity();
    return .{
        .{ .debug_name = "head_scalp", .parent = .{ .canonical_bone = 3 }, .local_to_parent = math.Transform2D.init(.{ .x = 0, .y = 0.32 }, 0, math.Vec2.one) },
        .{ .debug_name = "face", .parent = .{ .attachment_point = "head_scalp" }, .local_to_parent = math.Transform2D.init(.{ .x = 0.28, .y = -0.25 }, 0, math.Vec2.one) },
        .{ .debug_name = "neck", .parent = .{ .canonical_bone = 2 }, .local_to_parent = math.Transform2D.init(.{ .x = 0, .y = 1.30 }, 0, math.Vec2.one) },
        .{ .debug_name = "upper_back", .parent = .{ .canonical_bone = 2 }, .local_to_parent = math.Transform2D.init(.{ .x = 0, .y = 1.0 }, 0, math.Vec2.one) },
        .{ .debug_name = "chest", .parent = .{ .canonical_bone = 2 }, .local_to_parent = math.Transform2D.init(.{ .x = 0, .y = 0.65 }, 0, math.Vec2.one) },
        .{ .debug_name = "waist_pelvis", .parent = .{ .canonical_bone = 1 }, .local_to_parent = identity },
        .{ .debug_name = "left_shoulder", .parent = .{ .canonical_bone = 4 }, .local_to_parent = identity },
        .{ .debug_name = "right_shoulder", .parent = .{ .canonical_bone = 7 }, .local_to_parent = identity },
        .{ .debug_name = "left_wrist", .parent = .{ .canonical_bone = 5 }, .local_to_parent = math.Transform2D.init(.{ .x = 0.55, .y = 0 }, 0, math.Vec2.one) },
        .{ .debug_name = "right_wrist", .parent = .{ .canonical_bone = 8 }, .local_to_parent = math.Transform2D.init(.{ .x = 0.55, .y = 0 }, 0, math.Vec2.one) },
        .{ .debug_name = "left_hand", .parent = .{ .canonical_bone = 6 }, .local_to_parent = math.Transform2D.init(.{ .x = 0.25, .y = 0 }, 0, math.Vec2.one) },
        .{ .debug_name = "right_hand", .parent = .{ .canonical_bone = 9 }, .local_to_parent = math.Transform2D.init(.{ .x = 0.25, .y = 0 }, 0, math.Vec2.one) },
        .{ .debug_name = "left_ankle", .parent = .{ .canonical_bone = 11 }, .local_to_parent = math.Transform2D.init(.{ .x = 0.85, .y = 0 }, 0, math.Vec2.one) },
        .{ .debug_name = "right_ankle", .parent = .{ .canonical_bone = 14 }, .local_to_parent = math.Transform2D.init(.{ .x = 0.85, .y = 0 }, 0, math.Vec2.one) },
        .{ .debug_name = "left_foot", .parent = .{ .canonical_bone = 12 }, .local_to_parent = math.Transform2D.init(.{ .x = 0.35, .y = 0 }, 0, math.Vec2.one) },
        .{ .debug_name = "right_foot", .parent = .{ .canonical_bone = 15 }, .local_to_parent = math.Transform2D.init(.{ .x = 0.35, .y = 0 }, 0, math.Vec2.one) },
    };
}

pub fn bodyRegionInputs() [default_body_region_count]appearance.BodyRegionInput {
    return .{
        .{ .debug_name = "pelvis" },
        .{ .debug_name = "torso" },
        .{ .debug_name = "head" },
        .{ .debug_name = "left_arm" },
        .{ .debug_name = "left_hand" },
        .{ .debug_name = "right_arm" },
        .{ .debug_name = "right_hand" },
        .{ .debug_name = "left_leg" },
        .{ .debug_name = "left_foot" },
        .{ .debug_name = "right_leg" },
        .{ .debug_name = "right_foot" },
    };
}

pub fn visualGroupInputs() [default_visual_group_count]appearance.VisualGroupInput {
    return .{.{ .debug_name = "body" }};
}

pub fn attachmentInputs() [default_visual_count]RenderAttachmentInput {
    const center = [2]f32{ 0.5, 0.5 };
    const joint = [2]f32{ 0.0, 0.5 };
    const red = [4]f32{ 0, 0, 0.5, 0.5 };
    const green = [4]f32{ 0.5, 0, 1, 0.5 };
    const blue = [4]f32{ 0, 0.5, 0.5, 1 };
    const yellow = [4]f32{ 0.5, 0.5, 1, 1 };
    const white = [4]f32{ 1, 1, 1, 1 };
    return .{
        attachmentInput("pelvis", .pelvis, 1, math.Transform2D.identity(), .{ .x = 0.72, .y = 0.42 }, center, blue, white),
        attachmentInput("torso", .torso, 2, math.Transform2D.init(.{ .x = 0, .y = 0.56 }, 0, math.Vec2.one), .{ .x = 0.86, .y = 1.16 }, center, yellow, white),
        attachmentInput("head", .head, 3, math.Transform2D.identity(), .{ .x = 0.66, .y = 0.66 }, center, blue, white),
        attachmentInput("left_upper_arm", .left_upper_arm, 4, math.Transform2D.identity(), .{ .x = 0.65, .y = 0.18 }, joint, red, white),
        attachmentInput("left_forearm", .left_forearm, 5, math.Transform2D.identity(), .{ .x = 0.55, .y = 0.15 }, joint, red, white),
        attachmentInput("left_hand", .left_hand, 6, math.Transform2D.identity(), .{ .x = 0.25, .y = 0.20 }, joint, red, white),
        attachmentInput("right_upper_arm", .right_upper_arm, 7, math.Transform2D.identity(), .{ .x = 0.65, .y = 0.18 }, joint, green, white),
        attachmentInput("right_forearm", .right_forearm, 8, math.Transform2D.identity(), .{ .x = 0.55, .y = 0.15 }, joint, green, white),
        attachmentInput("right_hand", .right_hand, 9, math.Transform2D.identity(), .{ .x = 0.25, .y = 0.20 }, joint, green, white),
        attachmentInput("left_thigh", .left_thigh, 10, math.Transform2D.identity(), .{ .x = 0.90, .y = 0.22 }, joint, red, white),
        attachmentInput("left_shin", .left_shin, 11, math.Transform2D.identity(), .{ .x = 0.85, .y = 0.18 }, joint, red, white),
        attachmentInput("left_foot", .left_foot, 12, math.Transform2D.identity(), .{ .x = 0.35, .y = 0.18 }, joint, red, white),
        attachmentInput("right_thigh", .right_thigh, 13, math.Transform2D.identity(), .{ .x = 0.90, .y = 0.22 }, joint, green, white),
        attachmentInput("right_shin", .right_shin, 14, math.Transform2D.identity(), .{ .x = 0.85, .y = 0.18 }, joint, green, white),
        attachmentInput("right_foot", .right_foot, 15, math.Transform2D.identity(), .{ .x = 0.35, .y = 0.18 }, joint, green, white),
    };
}

fn attachmentInput(
    name: []const u8,
    semantic: AttachmentSemantic,
    parent: u16,
    local: math.Transform2D,
    size: math.Vec2,
    pivot: [2]f32,
    uv: [4]f32,
    tint: [4]f32,
) RenderAttachmentInput {
    return .{
        .debug_name = name,
        .canonical_semantic = @intFromEnum(semantic),
        .transform_source = .{ .canonical_bone = parent },
        .local_to_source = local,
        .body_region = bodyRegionForSemantic(semantic),
        .visual_group = "body",
        .sprite_size = size,
        .pivot = pivot,
        .uv_rect = uv,
        .tint = tint,
        .texture_page = 0,
        .body_part_layer = defaultBodyPartLayer(semantic, .right),
    };
}

fn bodyRegionForSemantic(semantic: AttachmentSemantic) []const u8 {
    return switch (semantic) {
        .pelvis => "pelvis",
        .torso => "torso",
        .head => "head",
        .left_upper_arm, .left_forearm => "left_arm",
        .left_hand => "left_hand",
        .right_upper_arm, .right_forearm => "right_arm",
        .right_hand => "right_hand",
        .left_thigh, .left_shin => "left_leg",
        .left_foot => "left_foot",
        .right_thigh, .right_shin => "right_leg",
        .right_foot => "right_foot",
    };
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
