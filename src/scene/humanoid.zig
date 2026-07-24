const std = @import("std");
const math = @import("math");
const skeleton = @import("skeleton");
const pose = @import("pose");
const sprite = @import("sprite_batch");
const fault_injection = @import("fault_injection");

pub const attachment_count: usize = 15;

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
    if (std.enums.values(AttachmentSemantic).len != attachment_count) @compileError("humanoid attachment semantic count mismatch");
}

pub const RenderAttachmentInput = struct {
    debug_name: []const u8,
    semantic: u8,
    parent_bone: u16,
    local_to_bone: math.Transform2D,
    sprite_size: math.Vec2,
    pivot: [2]f32,
    uv_rect: [4]f32,
    tint: [4]f32,
    texture_page: u32,
    body_part_layer: u16,
};

pub const RenderAttachment = struct {
    id: u16,
    debug_name: skeleton.DebugName,
    semantic: AttachmentSemantic,
    parent_bone: u16,
    local_to_bone: math.Transform2D,
    sprite_size: math.Vec2,
    pivot: [2]f32,
    uv_rect: [4]f32,
    tint: [4]f32,
    texture_page: u32,
    body_part_layer: u16,
};

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
    attachments: []const RenderAttachment,
    attachment_semantic_indices: [attachment_count]?u16,

    pub fn init(allocator: std.mem.Allocator, injector: ?fault_injection.Injector) !HumanoidDefinition {
        const bones = boneInputs();
        const sockets = socketInputs();
        const attachment_inputs = attachmentInputs();
        return initFromInputs(allocator, &bones, &sockets, &attachment_inputs, injector);
    }

    pub fn initFromInputs(
        allocator: std.mem.Allocator,
        bones: []const skeleton.BoneDefinitionInput,
        sockets: []const skeleton.SocketDefinitionInput,
        attachment_inputs: []const RenderAttachmentInput,
        injector: ?fault_injection.Injector,
    ) !HumanoidDefinition {
        var skeleton_definition = try skeleton.SkeletonDefinition.initHumanoid(allocator, bones, sockets, injector);
        errdefer skeleton_definition.deinit();
        if (attachment_inputs.len != attachment_count) return error.AttachmentLengthMismatch;

        const attachments = allocator.alloc(RenderAttachment, attachment_inputs.len) catch return error.AllocationFailure;
        errdefer allocator.free(attachments);
        try after(injector, .attachment_allocation);
        var lookup = [_]?u16{null} ** attachment_count;
        for (attachment_inputs, 0..) |input, index| {
            if (input.semantic >= attachment_count) return error.InvalidAttachmentSemantic;
            const semantic: AttachmentSemantic = @enumFromInt(input.semantic);
            if (lookup[input.semantic] != null) return error.DuplicateAttachmentSemantic;
            if (input.parent_bone >= skeleton_definition.boneCount()) {
                std.log.warn("attachment validation: attachment={d} name={s} parent={d} bone_count={d}", .{ index, input.debug_name, input.parent_bone, skeleton_definition.boneCount() });
                return error.InvalidAttachmentParent;
            }
            if (!input.local_to_bone.isFinite() or !input.sprite_size.isFinite() or input.sprite_size.x <= 0 or input.sprite_size.y <= 0) {
                return error.NonFiniteTransform;
            }
            const name = try skeleton.DebugName.init(input.debug_name);
            for (attachments[0..index]) |*existing| {
                if (name.eql(&existing.debug_name)) return error.DuplicateAttachmentName;
            }
            try sprite.validateRequest(.{
                .world_position = .{ 0, 0 },
                .rotation = 0,
                .scale = input.sprite_size.toArray(),
                .pivot = input.pivot,
                .uv_rect = input.uv_rect,
                .tint = input.tint,
                .texture_page = input.texture_page,
                .order = .{ .scene_layer = 0, .interaction_layer = 0, .actor_layer = 0, .body_part_layer = input.body_part_layer },
            }, 1);
            attachments[index] = .{
                .id = @intCast(index),
                .debug_name = name,
                .semantic = semantic,
                .parent_bone = input.parent_bone,
                .local_to_bone = input.local_to_bone,
                .sprite_size = input.sprite_size,
                .pivot = input.pivot,
                .uv_rect = input.uv_rect,
                .tint = input.tint,
                .texture_page = input.texture_page,
                .body_part_layer = input.body_part_layer,
            };
            lookup[input.semantic] = @intCast(index);
        }
        for (lookup) |index| if (index == null) return error.MissingAttachmentSemantic;

        return .{
            .allocator = allocator,
            .skeleton_definition = skeleton_definition,
            .attachments = attachments,
            .attachment_semantic_indices = lookup,
        };
    }

    pub fn deinit(definition: *HumanoidDefinition) void {
        definition.allocator.free(definition.attachments);
        definition.skeleton_definition.deinit();
        definition.* = undefined;
    }

    pub fn attachment(definition: HumanoidDefinition, semantic: AttachmentSemantic) *const RenderAttachment {
        return &definition.attachments[definition.attachment_semantic_indices[@intFromEnum(semantic)].?];
    }
};

pub const HumanoidCharacter = struct {
    local_and_world_pose: pose.Pose,
    character_to_world: math.Transform2D = math.Transform2D.identity(),

    pub fn init(allocator: std.mem.Allocator, definition: *const HumanoidDefinition, injector: ?fault_injection.Injector) !HumanoidCharacter {
        var pose_state = try pose.Pose.init(allocator, &definition.skeleton_definition, injector);
        errdefer pose_state.deinit();
        try after(injector, .humanoid_character_initialization);
        return .{ .local_and_world_pose = pose_state };
    }

    pub fn deinit(character: *HumanoidCharacter) void {
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
    }

    pub fn submitAttachments(
        character: *const HumanoidCharacter,
        definition: *const HumanoidDefinition,
        batch: *sprite.SpriteBatch,
        actor_layer: u16,
    ) !u32 {
        var submitted: u32 = 0;
        for (definition.attachments) |attachment_definition| {
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
        const bone_world = try character.local_and_world_pose.worldForBone(&definition.skeleton_definition, attachment_definition.parent_bone);
        return bone_world.mul(try attachment_definition.local_to_bone.localToParent());
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

pub fn attachmentInputs() [attachment_count]RenderAttachmentInput {
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
        .semantic = @intFromEnum(semantic),
        .parent_bone = parent,
        .local_to_bone = local,
        .sprite_size = size,
        .pivot = pivot,
        .uv_rect = uv,
        .tint = tint,
        .texture_page = 0,
        .body_part_layer = defaultBodyPartLayer(semantic, .right),
    };
}

fn after(injector: ?fault_injection.Injector, stage: fault_injection.InitStage) !void {
    if (injector) |value| try value.after(stage);
}
