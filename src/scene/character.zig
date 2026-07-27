const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const attachment_secondary_motion = @import("attachment_secondary_motion");
const humanoid = @import("humanoid");
const appearance = @import("appearance");
const anatomy = @import("anatomy");
const equipment = @import("equipment");
const properties = @import("character_properties");
const skeleton = @import("skeleton");
const authored = @import("authored_clips");
const clip = @import("clip");
const animator_module = @import("animator");
const animation_system = @import("animation_system");
const state_machine = @import("state_machine");
const procedural_motion = @import("procedural_motion");
const arm_ik = @import("arm_ik");
const leg_ik = @import("leg_ik");
const foot_planting = @import("foot_planting");
const fixed_step = @import("fixed_step");
const input = @import("input");
const presentation_view = @import("presentation_view");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const sprite = @import("sprite_batch");
const mesh = @import("deformable_mesh");
const render_queue = @import("render_queue");
const fault_injection = @import("fault_injection");

pub const maximum_characters: usize = 8;
pub const maximum_layer_overrides: usize = 8;
pub const SceneLayers = struct {
    pub const background: i16 = -30_000;
    pub const midground: i16 = -20_000;
    pub const world: i16 = -10_000;
    pub const characters: i16 = 0;
    pub const foreground: i16 = 10_000;
    pub const debug_overlay: i16 = 30_000;
};
pub const characters_scene_layer: i16 = SceneLayers.characters;
pub const neutral_interaction_layer: i16 = 0;
pub const minimum_interaction_layer: i16 = -1024;
pub const maximum_interaction_layer: i16 = 1024;

pub const EntityId = enum(u32) {
    invalid = 0,
    _,

    pub fn raw(id: EntityId) u32 {
        return @intFromEnum(id);
    }

    pub fn isValid(id: EntityId) bool {
        return id != .invalid;
    }
};

pub fn entityIdFromRaw(raw: u32) !EntityId {
    if (raw == 0) return error.InvalidEntityId;
    return @enumFromInt(raw);
}

pub const EntityIdAllocator = struct {
    next_value: u32 = 1,
    exhausted: bool = false,

    pub fn initAt(next_value: u32) !EntityIdAllocator {
        if (next_value == 0) return error.InvalidEntityId;
        return .{ .next_value = next_value };
    }

    pub fn allocate(allocator: *EntityIdAllocator) !EntityId {
        if (allocator.exhausted) return error.EntityIdOverflow;
        const id = try entityIdFromRaw(allocator.next_value);
        if (allocator.next_value == std.math.maxInt(u32)) {
            allocator.exhausted = true;
        } else {
            allocator.next_value += 1;
        }
        return id;
    }
};

pub const EntityRegistry = struct {
    ids: [maximum_characters]EntityId = [_]EntityId{.invalid} ** maximum_characters,
    count: usize = 0,

    pub fn insert(registry: *EntityRegistry, id: EntityId) !void {
        if (!id.isValid()) return error.InvalidEntityId;
        for (registry.ids[0..registry.count]) |existing| {
            if (existing == id) return error.DuplicateEntityId;
        }
        if (registry.count == registry.ids.len) return error.CharacterCapacityExceeded;
        registry.ids[registry.count] = id;
        registry.count += 1;
    }

    pub fn contains(registry: EntityRegistry, id: EntityId) bool {
        for (registry.ids[0..registry.count]) |existing| {
            if (existing == id) return true;
        }
        return false;
    }
};

pub const OverrideHandle = enum(u32) {
    invalid = 0,
    _,

    pub fn raw(handle: OverrideHandle) u32 {
        return @intFromEnum(handle);
    }
};

pub const LayerOverrideRequest = struct {
    interaction_layer: ?i32 = null,
    body_part_layer: ?i32 = null,
};

pub const ResolvedLayers = struct {
    interaction_layer: i16,
    body_part_layer: u16,
};

const LayerOverride = struct {
    active: bool = false,
    handle: OverrideHandle = .invalid,
    attachment_id: u16 = 0,
    interaction_layer: ?i16 = null,
    body_part_layer: ?u16 = null,
};

pub const LayerOverrideTable = struct {
    entries: [maximum_layer_overrides]LayerOverride = [_]LayerOverride{.{}} ** maximum_layer_overrides,
    next_handle: u32 = 1,
    handles_exhausted: bool = false,

    pub fn applyAttachment(
        table: *LayerOverrideTable,
        definition: *const humanoid.HumanoidDefinition,
        attachment_id: u16,
        request: LayerOverrideRequest,
    ) !OverrideHandle {
        if (attachment_id >= definition.attachments.len) return error.InvalidAttachmentTarget;
        const validated = try validateOverrideRequest(request);
        return table.applyValidated(attachment_id, validated);
    }

    pub fn applyValidated(
        table: *LayerOverrideTable,
        attachment_id: u16,
        validated: ValidatedOverrideRequest,
    ) !OverrideHandle {
        if (table.handles_exhausted) return error.OverrideHandleOverflow;

        var available: ?usize = null;
        for (table.entries, 0..) |entry, index| {
            if (!entry.active) {
                available = index;
                break;
            }
        }
        const index = available orelse return error.LayerOverrideCapacityExceeded;
        const handle: OverrideHandle = @enumFromInt(table.next_handle);
        table.entries[index] = .{
            .active = true,
            .handle = handle,
            .attachment_id = attachment_id,
            .interaction_layer = validated.interaction_layer,
            .body_part_layer = validated.body_part_layer,
        };
        if (table.next_handle == std.math.maxInt(u32)) {
            table.handles_exhausted = true;
        } else {
            table.next_handle += 1;
        }
        return handle;
    }

    pub fn applySemantic(
        table: *LayerOverrideTable,
        definition: *const humanoid.HumanoidDefinition,
        semantic: humanoid.AttachmentSemantic,
        request: LayerOverrideRequest,
    ) !OverrideHandle {
        return table.applyAttachment(definition, @intFromEnum((try definition.attachment(semantic)).id), request);
    }

    pub fn applySemanticRaw(
        table: *LayerOverrideTable,
        definition: *const humanoid.HumanoidDefinition,
        raw_semantic: u8,
        request: LayerOverrideRequest,
    ) !OverrideHandle {
        if (raw_semantic >= humanoid.canonical_attachment_semantic_count) return error.InvalidBodyPartSemantic;
        return table.applySemantic(definition, @enumFromInt(raw_semantic), request);
    }

    pub fn clear(table: *LayerOverrideTable, handle: OverrideHandle) !void {
        if (handle == .invalid) return error.InvalidOverrideHandle;
        for (&table.entries) |*entry| {
            if (entry.active and entry.handle == handle) {
                entry.* = .{};
                return;
            }
        }
        return error.OverrideNotFound;
    }

    pub fn clearAll(table: *LayerOverrideTable) void {
        table.entries = [_]LayerOverride{.{}} ** maximum_layer_overrides;
    }

    pub fn activeCount(table: LayerOverrideTable) usize {
        var count: usize = 0;
        for (table.entries) |entry| {
            if (entry.active) count += 1;
        }
        return count;
    }

    pub fn resolve(table: LayerOverrideTable, attachment_id: u16, default_body_part_layer: u16) ResolvedLayers {
        var resolved = ResolvedLayers{
            .interaction_layer = neutral_interaction_layer,
            .body_part_layer = default_body_part_layer,
        };
        var interaction_precedence: u32 = 0;
        var body_precedence: u32 = 0;
        for (table.entries) |entry| {
            if (!entry.active or entry.attachment_id != attachment_id) continue;
            const precedence = entry.handle.raw();
            if (entry.interaction_layer) |value| {
                if (precedence > interaction_precedence) {
                    resolved.interaction_layer = value;
                    interaction_precedence = precedence;
                }
            }
            if (entry.body_part_layer) |value| {
                if (precedence > body_precedence) {
                    resolved.body_part_layer = value;
                    body_precedence = precedence;
                }
            }
        }
        return resolved;
    }
};

const ValidatedOverrideRequest = struct {
    interaction_layer: ?i16,
    body_part_layer: ?u16,
};

fn validateOverrideRequest(request: LayerOverrideRequest) !ValidatedOverrideRequest {
    if (request.interaction_layer == null and request.body_part_layer == null) return error.EmptyLayerOverride;
    var interaction_layer: ?i16 = null;
    var body_part_layer: ?u16 = null;
    if (request.interaction_layer) |value| {
        if (value < minimum_interaction_layer or value > maximum_interaction_layer) return error.InvalidInteractionLayer;
        interaction_layer = @intCast(value);
    }
    if (request.body_part_layer) |value| {
        if (value < 0 or value > std.math.maxInt(u16)) return error.InvalidBodyPartLayer;
        body_part_layer = @intCast(value);
    }
    return .{ .interaction_layer = interaction_layer, .body_part_layer = body_part_layer };
}

pub const HotPathMetrics = struct {
    pose_allocations: u64 = 0,
    animator_allocations: u64 = 0,
    procedural_allocations: u64 = 0,
    layer_resolution_allocations: u64 = 0,
    override_allocations: u64 = 0,
    submission_allocations: u64 = 0,
    ik_solver_allocations: u64 = 0,
    ik_binding_lookup_allocations: u64 = 0,
    ik_pose_application_allocations: u64 = 0,
    ik_hierarchy_evaluation_allocations: u64 = 0,
    ground_query_allocations: u64 = 0,
    foot_plant_update_allocations: u64 = 0,
    leg_binding_allocations: u64 = 0,
    leg_ik_allocations: u64 = 0,
    foot_target_allocations: u64 = 0,
};

pub const ArmIkRuntime = struct {
    applied: bool = false,
    pre_root_local: math.Transform2D = math.Transform2D.identity(),
    pre_middle_local: math.Transform2D = math.Transform2D.identity(),
    metrics: ?arm_ik.Metrics = null,
};

pub const VisualTickInput = struct {
    horizontal_velocity: f32 = 0,
    vertical_velocity: f32 = 0,
    physically_grounded: bool = true,
    landing_event: ?procedural_motion.LandingEvent = null,
};

pub const PropertyBindings = struct {
    movement_speed: ?properties.AttributeId,
    jump_strength: ?properties.AttributeId,
    double_jump: ?properties.CapabilityId,
    dash: ?properties.CapabilityId,

    pub fn init(definition: equipment.DefinitionView) PropertyBindings {
        return .{
            .movement_speed = definition.attributeId("movement_speed") catch null,
            .jump_strength = definition.attributeId("jump_strength") catch null,
            .double_jump = definition.capabilityId("double_jump") catch null,
            .dash = definition.capabilityId("dash") catch null,
        };
    }
};

pub const ResolvedEquipmentTransform = struct {
    binding_world: math.Mat3,
    resolved_deformation: math.Transform2D,
    secondary_deformation: math.Transform2D,
    bound_identity: mesh.BoundIdentity,

    pub fn composedDeformation(transform: ResolvedEquipmentTransform) !math.Transform2D {
        return attachment_secondary_motion.composeResolvedDeformation(
            transform.resolved_deformation,
            transform.secondary_deformation,
        );
    }

    pub fn world(transform: ResolvedEquipmentTransform) !math.Mat3 {
        return transform.binding_world.mul(try (try transform.composedDeformation()).localToParent());
    }
};

pub const HumanoidDefinitionView = struct {
    skeleton_definition: skeleton.SkeletonDefinition,
    visual_definition: appearance.DefinitionView,
    anatomy_definition: ?anatomy.DefinitionView,
    attachments: []const humanoid.RenderAttachment,
    attachment_semantic_indices: [humanoid.canonical_attachment_semantic_count]?humanoid.VisualAttachmentId,
    owner_token: usize,

    fn init(definition: *const humanoid.HumanoidDefinition) HumanoidDefinitionView {
        return .{
            .skeleton_definition = definition.skeleton_definition,
            .visual_definition = definition.visual_definition.view(),
            .anatomy_definition = if (definition.anatomy_definition) |*value| value.view() else null,
            .attachments = definition.attachments,
            .attachment_semantic_indices = definition.attachment_semantic_indices,
            .owner_token = definition.skeleton_definition.compatibilityToken(),
        };
    }

    pub fn attachment(view: HumanoidDefinitionView, semantic: humanoid.AttachmentSemantic) !*const humanoid.RenderAttachment {
        const id = view.attachment_semantic_indices[@intFromEnum(semantic)] orelse return error.MissingCanonicalVisual;
        return &view.attachments[id.index()];
    }
};

pub const AnimationDefinitionsView = struct {
    clips: []const clip.ClipDefinition,
    machine: state_machine.Definition,
    library_token: usize,

    fn init(definitions: *const authored.Definitions) AnimationDefinitionsView {
        return .{
            .clips = definitions.library.clips,
            .machine = definitions.machine,
            .library_token = definitions.library.token(),
        };
    }
};

pub const CharacterInstance = struct {
    id: EntityId,
    definition: HumanoidDefinitionView,
    shared_animations: AnimationDefinitionsView,
    character: humanoid.HumanoidCharacter,
    animator: animator_module.Animator,
    procedural: procedural_motion.State,
    right_arm_binding: arm_ik.Binding,
    right_arm_ik: ArmIkRuntime = .{},
    left_leg_binding: leg_ik.Binding,
    right_leg_binding: leg_ik.Binding,
    foot_plants: foot_planting.State = .{},
    controller: ?character_controller.CharacterController = null,
    facing: humanoid.Facing,
    default_facing: humanoid.Facing,
    world_position: math.Vec2,
    default_world_position: math.Vec2,
    actor_layer: u16,
    default_actor_layer: u16,
    overrides: LayerOverrideTable = .{},
    equipment_loadout: ?equipment.Loadout = null,
    property_bindings: ?PropertyBindings = null,
    resolved_properties: ?properties.ResolvedSet = null,
    interaction_owner_id: u32 = 0,
    presentation: presentation_view.Runtime = .{},
    passive_grounded: bool = true,
    simulation_tick: u64 = 0,
    last_submitted_keys: [humanoid.canonical_attachment_semantic_count]?sprite.DrawOrderKey = [_]?sprite.DrawOrderKey{null} ** humanoid.canonical_attachment_semantic_count,
    metrics: HotPathMetrics = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        id: EntityId,
        definition: *const humanoid.HumanoidDefinition,
        shared_animations: *const authored.Definitions,
        world_position: math.Vec2,
        facing: humanoid.Facing,
        actor_layer: u16,
        injector: ?fault_injection.Injector,
    ) !CharacterInstance {
        if (!id.isValid()) return error.InvalidEntityId;
        if (!world_position.isFinite()) return error.InvalidNonFiniteTransform;
        _ = try sprite.validateOrder(.{
            .scene_layer = characters_scene_layer,
            .interaction_layer = neutral_interaction_layer,
            .actor_layer = actor_layer,
            .body_part_layer = 0,
        }, 0);
        for (definition.attachments) |attachment| {
            if (attachment.canonical_semantic) |raw_semantic| {
                const semantic: humanoid.AttachmentSemantic = @enumFromInt(raw_semantic);
                if (attachment.body_part_layer != humanoid.defaultBodyPartLayer(semantic, .right)) {
                    return error.ImmutableDefaultLayerMismatch;
                }
            }
        }

        var character = try humanoid.HumanoidCharacter.init(allocator, definition, injector);
        errdefer character.deinit();
        var animator = try animator_module.Animator.init(
            allocator,
            &definition.skeleton_definition,
            &shared_animations.machine,
            shared_animations.library.token(),
            animation_system.default_event_capacity,
            injector,
        );
        errdefer animator.deinit();
        const procedural = try procedural_motion.State.init();
        const right_arm_binding = try arm_ik.Binding.initRightArm(&definition.skeleton_definition);
        const left_leg_binding = try leg_ik.Binding.initLeft(&definition.skeleton_definition);
        const right_leg_binding = try leg_ik.Binding.initRight(&definition.skeleton_definition);

        var instance = CharacterInstance{
            .id = id,
            .definition = HumanoidDefinitionView.init(definition),
            .shared_animations = AnimationDefinitionsView.init(shared_animations),
            .character = character,
            .animator = animator,
            .procedural = procedural,
            .right_arm_binding = right_arm_binding,
            .left_leg_binding = left_leg_binding,
            .right_leg_binding = right_leg_binding,
            .facing = facing,
            .default_facing = facing,
            .world_position = world_position,
            .default_world_position = world_position,
            .actor_layer = actor_layer,
            .default_actor_layer = actor_layer,
        };
        errdefer instance.deinit();
        try instance.animator.update(
            &instance.shared_animations.machine,
            instance.shared_animations.clips,
            instance.shared_animations.library_token,
            &definition.skeleton_definition,
            0,
            &instance.character.local_and_world_pose,
        );
        try instance.evaluateWorldPose();
        return instance;
    }

    pub fn initControlled(
        allocator: std.mem.Allocator,
        id: EntityId,
        definition: *const humanoid.HumanoidDefinition,
        shared_animations: *const authored.Definitions,
        world: *const collision_world.CollisionWorld,
        configuration: character_controller.Configuration,
        spawn_position: math.Vec2,
        facing: humanoid.Facing,
        actor_layer: u16,
        injector: ?fault_injection.Injector,
    ) !CharacterInstance {
        var instance = try CharacterInstance.init(
            allocator,
            id,
            definition,
            shared_animations,
            spawn_position,
            facing,
            actor_layer,
            injector,
        );
        errdefer instance.deinit();
        instance.controller = try character_controller.CharacterController.init(
            configuration,
            world,
            spawn_position,
            if (facing == .left) .left else .right,
        );
        try instance.syncPresentationView();
        return instance;
    }

    pub fn deinit(instance: *CharacterInstance) void {
        instance.animator.deinit();
        instance.character.deinit();
        instance.* = undefined;
    }

    pub fn enterAnimationState(instance: *CharacterInstance, state: state_machine.StateId) !void {
        try instance.animator.enterState(&instance.shared_animations.machine, state);
        try instance.syncPresentationView();
    }

    pub fn canEnterAnimationState(instance: CharacterInstance, state: state_machine.StateId) bool {
        _ = instance.shared_animations.machine.stateIndex(state) catch return false;
        return true;
    }

    pub fn sampleInteractionAnimation(instance: *CharacterInstance, state: state_machine.StateId, shared_time_seconds: f32) !void {
        const next_tick = std.math.add(u64, instance.simulation_tick, 1) catch return error.SimulationTickOverflow;
        try instance.restoreRightHandIkLocals();
        try instance.restoreFootIkLocals();
        try instance.animator.sampleEnteredStateAtTime(
            &instance.shared_animations.machine,
            instance.shared_animations.clips,
            instance.shared_animations.library_token,
            &instance.definition.skeleton_definition,
            state,
            shared_time_seconds,
            &instance.character.local_and_world_pose,
        );
        try instance.procedural.composePose(
            &instance.definition.skeleton_definition,
            &instance.character.local_and_world_pose,
            next_tick,
        );
        if (instance.character.anatomy_runtime) |*runtime| {
            const anatomy_definition = instance.definition.anatomy_definition orelse return error.AnatomyDefinitionMismatch;
            try runtime.advanceBreathing(anatomy_definition);
        }
        instance.simulation_tick = next_tick;
        try instance.evaluateWorldPose();
        try instance.syncPresentationView();
        try instance.advanceAttachmentSecondaryMotion(.{});
    }

    pub fn reserveInteraction(instance: *CharacterInstance, owner_id: u32) !void {
        if (owner_id == 0) return error.InvalidInteractionOwner;
        if (instance.interaction_owner_id != 0) return error.CharacterAlreadyInteracting;
        instance.interaction_owner_id = owner_id;
    }

    pub fn claimInteractionPresentation(
        instance: *CharacterInstance,
        owner_id: u32,
        view: presentation_view.View,
    ) !void {
        if (instance.interaction_owner_id != owner_id) return error.InteractionOwnershipMismatch;
        const previous = instance.presentation;
        errdefer instance.presentation = previous;
        try instance.presentation.claimInteraction(owner_id, view);
        try instance.syncPresentationView();
    }

    pub fn releaseInteraction(instance: *CharacterInstance, owner_id: u32) !void {
        if (owner_id == 0) return error.InvalidInteractionOwner;
        if (instance.interaction_owner_id != owner_id) return error.InteractionOwnershipMismatch;
        if (instance.presentation.interaction_owner != 0) {
            try instance.presentation.releaseInteraction(owner_id);
        }
        instance.interaction_owner_id = 0;
        try instance.syncPresentationView();
    }

    pub fn isInteractionLocked(instance: CharacterInstance) bool {
        return instance.interaction_owner_id != 0;
    }

    pub fn interactionOwnerId(instance: CharacterInstance) u32 {
        return instance.interaction_owner_id;
    }

    pub fn presentationView(instance: CharacterInstance) presentation_view.View {
        return instance.presentation.current;
    }

    pub fn presentationOverride(instance: CharacterInstance) presentation_view.DebugOverride {
        return instance.presentation.debug_override;
    }

    pub fn setPresentationOverride(
        instance: *CharacterInstance,
        value: presentation_view.DebugOverride,
    ) !void {
        instance.presentation.setDebugOverride(value);
        try instance.syncPresentationView();
    }

    pub fn cyclePresentationOverride(instance: *CharacterInstance) !void {
        instance.presentation.cycleDebugOverride();
        try instance.syncPresentationView();
    }

    pub fn applyPresentationInput(
        instance: *CharacterInstance,
        snapshot: input.FrameInputSnapshot,
    ) !void {
        if (snapshot.presentation_view_cycle.pressed) try instance.cyclePresentationOverride();
    }

    pub fn interactionGrounded(instance: CharacterInstance) bool {
        if (instance.controller) |controller| return controller.state.grounded;
        return instance.passive_grounded;
    }

    pub fn setPassiveGrounded(instance: *CharacterInstance, grounded: bool) !void {
        if (instance.controller != null) return error.ControlledCharacterGroundingIsAuthoritative;
        instance.passive_grounded = grounded;
        try instance.syncPresentationView();
    }

    pub fn fallbackAnimationState(instance: CharacterInstance) state_machine.StateId {
        if (instance.controller) |controller| {
            if (@abs(controller.state.velocity.x) > 0.0001) return .walk;
        }
        return .idle;
    }

    pub fn animationTime(instance: CharacterInstance) f32 {
        return instance.animator.currentClipTime();
    }

    pub fn animationNormalizedTime(instance: CharacterInstance) f32 {
        const state_index = instance.shared_animations.machine.stateIndex(instance.animationState()) catch return 0;
        const clip_index = instance.shared_animations.machine.states[state_index].clip_index;
        if (clip_index >= instance.shared_animations.clips.len) return 0;
        const duration = instance.shared_animations.clips[clip_index].duration;
        if (!std.math.isFinite(duration) or duration <= 0) return 0;
        return std.math.clamp(instance.animationTime() / duration, 0, 1);
    }

    pub fn animationState(instance: CharacterInstance) state_machine.StateId {
        return instance.animator.currentState(&instance.shared_animations.machine);
    }

    pub fn setFacing(instance: *CharacterInstance, facing: humanoid.Facing) !void {
        try instance.restoreFootIkLocals();
        if (instance.facing != facing) try instance.clearAttachmentSecondaryMotion();
        instance.facing = facing;
        try instance.evaluateWorldPose();
    }

    pub fn setActorLayer(instance: *CharacterInstance, actor_layer: u16) !void {
        _ = try sprite.validateOrder(.{
            .scene_layer = characters_scene_layer,
            .interaction_layer = neutral_interaction_layer,
            .actor_layer = actor_layer,
            .body_part_layer = 0,
        }, 0);
        instance.actor_layer = actor_layer;
    }

    pub fn setWorldPosition(instance: *CharacterInstance, world_position: math.Vec2) !void {
        if (!world_position.isFinite()) return error.InvalidNonFiniteTransform;
        try instance.restoreFootIkLocals();
        instance.world_position = world_position;
        try instance.evaluateWorldPose();
    }

    pub fn applyAttachmentOverride(instance: *CharacterInstance, attachment_id: u16, request: LayerOverrideRequest) !OverrideHandle {
        if (attachment_id >= instance.definition.attachments.len) return error.InvalidAttachmentTarget;
        const validated = try validateOverrideRequest(request);
        return instance.applyValidatedOverride(attachment_id, validated);
    }

    pub fn applySemanticOverride(instance: *CharacterInstance, semantic: humanoid.AttachmentSemantic, request: LayerOverrideRequest) !OverrideHandle {
        return instance.applyAttachmentOverride(@intFromEnum((try instance.definition.attachment(semantic)).id), request);
    }

    pub fn setVisualVisible(instance: *CharacterInstance, visual_id: humanoid.VisualAttachmentId, visible: bool) !void {
        try instance.character.appearance_runtime.setVisible(instance.definition.visual_definition, visual_id, visible);
    }

    pub fn setVisualDeformation(
        instance: *CharacterInstance,
        visual_id: humanoid.VisualAttachmentId,
        deformation_transform: math.Transform2D,
    ) !void {
        try instance.character.appearance_runtime.setVisualDeformation(instance.definition.visual_definition, visual_id, deformation_transform);
        try instance.evaluateAppearance();
    }

    pub fn setModuleJointLocal(
        instance: *CharacterInstance,
        module_id: humanoid.RigModuleId,
        joint_id: humanoid.ModuleJointId,
        local: math.Transform2D,
    ) !void {
        try instance.character.appearance_runtime.setModuleJointLocal(
            instance.definition.visual_definition,
            module_id,
            joint_id,
            local,
        );
        try instance.evaluateAppearance();
    }

    pub fn clearOverride(instance: *CharacterInstance, handle: OverrideHandle) !void {
        try instance.overrides.clear(handle);
    }

    pub fn clearOverrides(instance: *CharacterInstance) void {
        instance.overrides.clearAll();
        instance.interaction_owner_id = 0;
        instance.presentation.interaction_owner = 0;
        instance.passive_grounded = true;
    }

    pub fn advanceVisualTick(instance: *CharacterInstance, tick_input: VisualTickInput) !void {
        try instance.advanceVisualTickInternal(null, tick_input);
    }

    pub fn advanceVisualTickWithFootPlanting(
        instance: *CharacterInstance,
        world: *const collision_world.CollisionWorld,
        tick_input: VisualTickInput,
    ) !void {
        try instance.advanceVisualTickInternal(world, tick_input);
    }

    /// Reapplies already-acquired grounded foot constraints after an interaction
    /// has sampled its shared pose and applied arm IK. This never acquires a new
    /// lock because no semantic contact event is supplied.
    pub fn maintainFootPlantingDuringInteraction(
        instance: *CharacterInstance,
        world: *const collision_world.CollisionWorld,
    ) !void {
        if (!instance.isInteractionLocked()) return error.CharacterNotInteracting;
        const left_locked = instance.foot_plants.left.hasLock();
        const right_locked = instance.foot_plants.right.hasLock();
        const has_lock = left_locked or right_locked;
        const stance_phase: f32 = if (left_locked and right_locked)
            0.54
        else if (left_locked)
            0.25
        else
            0.75;
        try foot_planting.updateAndApply(&instance.foot_plants, .{
            .world = world,
            .definition = &instance.definition.skeleton_definition,
            .mutable_pose = &instance.character.local_and_world_pose,
            .character_to_world = instance.character.character_to_world,
            .left_binding = instance.left_leg_binding,
            .right_binding = instance.right_leg_binding,
            .facing_left = instance.facing == .left,
            .physically_grounded = instance.interactionGrounded(),
            .walking_state = has_lock,
            .walk_phase = stance_phase,
            .walk_weight = if (has_lock) 1 else 0,
            .emitted_events = &.{},
            .simulation_tick = instance.simulation_tick,
        });
        try instance.evaluateAppearance();
    }

    fn advanceVisualTickInternal(
        instance: *CharacterInstance,
        world: ?*const collision_world.CollisionWorld,
        tick_input: VisualTickInput,
    ) !void {
        const next_tick = std.math.add(u64, instance.simulation_tick, 1) catch return error.SimulationTickOverflow;
        try instance.restoreRightHandIkLocals();
        try instance.restoreFootIkLocals();
        try instance.animator.update(
            &instance.shared_animations.machine,
            instance.shared_animations.clips,
            instance.shared_animations.library_token,
            &instance.definition.skeleton_definition,
            @floatCast(fixed_step.fixed_dt_seconds),
            &instance.character.local_and_world_pose,
        );
        const walk_sample = currentWalkSample(instance);
        try instance.procedural.update(.{
            .horizontal_velocity = tick_input.horizontal_velocity,
            .physically_grounded = tick_input.physically_grounded,
            .walk_cycle_phase = walk_sample.phase,
            .walk_layer_weight = walk_sample.weight,
            .landing_event = tick_input.landing_event,
        });
        try instance.procedural.composePose(
            &instance.definition.skeleton_definition,
            &instance.character.local_and_world_pose,
            next_tick,
        );
        if (instance.character.anatomy_runtime) |*runtime| {
            const anatomy_definition = instance.definition.anatomy_definition orelse return error.AnatomyDefinitionMismatch;
            try runtime.advanceBreathing(anatomy_definition);
        }
        instance.simulation_tick = next_tick;
        try instance.evaluateWorldPose();
        if (world) |authoritative_world| {
            try foot_planting.updateAndApply(&instance.foot_plants, .{
                .world = authoritative_world,
                .definition = &instance.definition.skeleton_definition,
                .mutable_pose = &instance.character.local_and_world_pose,
                .character_to_world = instance.character.character_to_world,
                .left_binding = instance.left_leg_binding,
                .right_binding = instance.right_leg_binding,
                .facing_left = instance.facing == .left,
                .physically_grounded = if (instance.controller) |controller| controller.state.grounded else tick_input.physically_grounded,
                .walking_state = walk_sample.allows_planting,
                .walk_phase = walk_sample.phase,
                .walk_weight = walk_sample.weight,
                .emitted_events = instance.animator.emittedEvents(),
                .simulation_tick = next_tick,
            });
            try instance.evaluateAppearance();
        }
        try instance.syncPresentationView();
        try instance.advanceAttachmentSecondaryMotion(tick_input);
    }

    fn advanceAttachmentSecondaryMotion(
        instance: *CharacterInstance,
        tick_input: VisualTickInput,
    ) !void {
        if (!std.math.isFinite(tick_input.horizontal_velocity) or
            !std.math.isFinite(tick_input.vertical_velocity))
        {
            return error.NonFiniteSecondaryMotionInput;
        }
        const landing_impulse_y = if (tick_input.landing_event) |event| landing: {
            if (!std.math.isFinite(event.impact_speed) or event.impact_speed < 0) {
                return error.NonFiniteSecondaryMotionInput;
            }
            break :landing -event.impact_speed;
        } else 0;
        const shared_input = attachment_secondary_motion.TickInput{
            .anchor_world = math.Vec2.zero,
            .linear_velocity_world = .{
                .x = tick_input.horizontal_velocity,
                .y = tick_input.vertical_velocity,
            },
            .landing_velocity_impulse_world = .{ .x = 0, .y = landing_impulse_y },
            .facing = if (instance.presentationView() == .front)
                .right
            else if (instance.facing == .left)
                .left
            else
                .right,
        };
        const appearance_advanced = try instance.character.appearance_runtime.advanceSecondaryMotion(
            instance.definition.visual_definition,
            shared_input,
        );

        if (instance.equipment_loadout) |*loadout| {
            var visual_index: usize = 0;
            while (visual_index < loadout.resolved_visual_count) : (visual_index += 1) {
                const recipe = try loadout.definition.recipe(loadout.resolved_visuals[visual_index].recipe);
                if (recipe.component.index() >= loadout.definition.visual_components.len) {
                    return error.InvalidEquipmentVisualReference;
                }
                const component = loadout.definition.visual_components[recipe.component.index()];
                const motion_definition = component.secondary_motion orelse {
                    loadout.resolved_visuals[visual_index].secondary.clear();
                    continue;
                };
                const resolved = try instance.equipmentVisualTransform(visual_index);
                var input_value = shared_input;
                input_value.anchor_world = resolved.binding_world.translationPart();
                try loadout.resolved_visuals[visual_index].secondary.step(motion_definition, input_value);
            }
        }
        if (appearance_advanced) try instance.evaluateAppearance();
    }

    fn clearAttachmentSecondaryMotion(instance: *CharacterInstance) !void {
        try instance.character.appearance_runtime.clearSecondaryMotion(
            instance.definition.visual_definition,
        );
        if (instance.equipment_loadout) |*loadout| {
            for (loadout.resolved_visuals[0..loadout.resolved_visual_count]) |*visual| {
                visual.secondary.clear();
            }
        }
    }

    pub fn selectControllerAnimation(instance: *CharacterInstance, physics: character_controller.StepResult) !void {
        const controller = if (instance.controller) |*value| value else return error.CharacterHasNoController;
        const machine = &instance.shared_animations.machine;
        if (physics.jump_accepted) {
            try instance.animator.enterState(machine, .jump_start);
            return;
        }
        if (physics.landed) {
            try instance.animator.enterState(machine, .landing);
            return;
        }
        const current = instance.animator.currentState(machine);
        if (current == .jump_start or current == .landing) return;
        if (instance.animator.active_transition) |transition| {
            const source = machine.states[transition.source_state_index].id;
            if (source == .jump_start or source == .landing) return;
            return;
        }
        if (!controller.state.grounded) {
            const desired: state_machine.StateId = if (controller.state.velocity.y > 0.05) .rising else .falling;
            if (current != desired) try instance.animator.enterState(machine, desired);
            return;
        }
        const desired: state_machine.StateId = if (@abs(controller.state.velocity.x) < 0.10) .idle else .walk;
        if (current == desired) return;
        if ((current == .idle and desired == .walk) or (current == .walk and desired == .idle)) {
            try instance.animator.requestState(machine, desired);
        } else {
            try instance.animator.enterState(machine, desired);
        }
    }

    pub fn stepController(
        instance: *CharacterInstance,
        world: *const collision_world.CollisionWorld,
        intent: input.CharacterIntent,
    ) !character_controller.StepResult {
        const controller = if (instance.controller) |*value| value else return error.CharacterHasNoController;
        const result = try controller.stepWithProperties(world, intent, try instance.controllerGameplayProperties());
        instance.world_position = controller.state.position;
        const resolved_facing: humanoid.Facing = if (controller.state.facing == .left) .left else .right;
        if (instance.facing != resolved_facing) try instance.clearAttachmentSecondaryMotion();
        instance.facing = resolved_facing;
        try instance.evaluateWorldPose();
        try instance.syncPresentationView();
        return result;
    }

    pub fn reset(instance: *CharacterInstance) !void {
        if (instance.controller != null) return error.ControlledCharacterResetRequiresWorld;
        try instance.resetVisualState();
    }

    pub fn resetControlled(instance: *CharacterInstance, world: *const collision_world.CollisionWorld) !void {
        const controller = if (instance.controller) |*value| value else return error.CharacterHasNoController;
        try controller.reset(world);
        try instance.resetVisualState();
        instance.world_position = controller.state.position;
        instance.facing = if (controller.state.facing == .left) .left else .right;
        try instance.evaluateWorldPose();
    }

    fn resetVisualState(instance: *CharacterInstance) !void {
        try instance.restoreRightHandIkLocals();
        try instance.restoreFootIkLocals();
        try instance.animator.enterState(&instance.shared_animations.machine, .idle);
        try instance.animator.update(
            &instance.shared_animations.machine,
            instance.shared_animations.clips,
            instance.shared_animations.library_token,
            &instance.definition.skeleton_definition,
            0,
            &instance.character.local_and_world_pose,
        );
        try instance.procedural.reset(0);
        instance.overrides.clearAll();
        instance.presentation.reset();
        instance.facing = instance.default_facing;
        instance.actor_layer = instance.default_actor_layer;
        instance.world_position = instance.default_world_position;
        instance.simulation_tick = 0;
        instance.last_submitted_keys = [_]?sprite.DrawOrderKey{null} ** humanoid.canonical_attachment_semantic_count;
        instance.metrics = .{};
        instance.right_arm_ik = .{};
        instance.foot_plants.reset();
        try instance.character.appearance_runtime.reset(instance.definition.visual_definition);
        if (instance.character.anatomy_runtime) |*runtime| {
            const anatomy_definition = instance.definition.anatomy_definition orelse return error.AnatomyDefinitionMismatch;
            try runtime.reset(anatomy_definition);
        }
        if (instance.equipment_loadout) |*loadout| {
            var candidate = loadout.*;
            try candidate.resetToDefault(try instance.equipmentContext());
            const resolved = try resolveLoadoutProperties(&candidate);
            loadout.* = candidate;
            instance.resolved_properties = resolved;
        }
        try instance.evaluateWorldPose();
    }

    pub fn syncPresentationView(instance: *CharacterInstance) !void {
        const change = try instance.presentation.sync(instance.presentationAutomaticInput());
        if (change.changed()) try instance.clearAttachmentSecondaryMotion();
    }

    fn presentationAutomaticInput(instance: CharacterInstance) presentation_view.AutomaticInput {
        const state = instance.animationState();
        if (instance.controller) |controller| {
            if (controller.state.dash_ticks_remaining > 0) {
                return .{ .grounded = controller.state.grounded, .activity = .dashing };
            }
            if (!controller.state.grounded) {
                return .{
                    .grounded = false,
                    .activity = switch (state) {
                        .jump_start => .jumping,
                        .rising => .rising,
                        .falling => .falling,
                        else => if (controller.state.velocity.y > 0) .rising else .falling,
                    },
                };
            }
            return .{
                .grounded = true,
                .activity = switch (state) {
                    .landing => .landing,
                    .walk => .walking,
                    .jump_start => .jumping,
                    .rising => .rising,
                    .falling => .falling,
                    .idle, .handshake_role_a, .handshake_role_b => if (@abs(controller.state.velocity.x) >= 0.10)
                        .walking
                    else
                        .idle,
                },
            };
        }
        return .{
            .grounded = instance.passive_grounded,
            .activity = switch (state) {
                .idle => .idle,
                .walk => .walking,
                .jump_start => .jumping,
                .rising => .rising,
                .falling => .falling,
                .landing => .landing,
                .handshake_role_a, .handshake_role_b => .idle,
            },
        };
    }

    pub fn selectBodyPreset(instance: *CharacterInstance, preset_id: anatomy.BodyPresetId) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.selectBodyPreset(definition, preset_id);
        try instance.evaluateAppearance();
        if (instance.equipment_loadout) |*loadout| try loadout.rebind(try instance.equipmentContext());
    }

    pub fn selectMorphologyPreset(instance: *CharacterInstance, preset_id: anatomy.MorphologyPresetId) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.selectMorphologyPreset(definition, preset_id);
        try instance.evaluateAppearance();
    }

    pub fn setGlobalBuild(instance: *CharacterInstance, user_value: f32) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.setGlobalBuild(definition, user_value);
        try instance.evaluateAppearance();
    }

    pub fn setMorphologyChannelOverride(
        instance: *CharacterInstance,
        channel_id: anatomy.MorphologyChannelId,
        user_value: ?f32,
    ) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.setChannelOverride(definition, channel_id, user_value);
        try instance.evaluateAppearance();
    }

    pub fn setPartMorphologyOverride(
        instance: *CharacterInstance,
        part_id: anatomy.BodyPartInstanceId,
        channel_id: anatomy.MorphologyChannelId,
        user_value: ?f32,
    ) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.setInstanceOverride(definition, part_id, channel_id, user_value);
        try instance.evaluateAppearance();
    }

    pub fn configureBreathing(
        instance: *CharacterInstance,
        configuration: deformation.BreathingConfiguration,
    ) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.configureBreathing(definition, configuration);
        try instance.evaluateAppearance();
    }

    pub fn setBreathingPhaseTick(instance: *CharacterInstance, phase_tick: u32) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.setBreathingPhaseTick(definition, phase_tick);
        try instance.evaluateAppearance();
    }

    pub fn breathingSample(instance: *const CharacterInstance) !f32 {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = instance.character.anatomy_runtime orelse return error.CharacterHasNoAnatomy;
        return runtime.breathingSample(definition);
    }

    pub fn selectPresentationProfile(instance: *CharacterInstance, profile_id: anatomy.PresentationProfileId) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.selectPresentationProfile(definition, profile_id);
        try instance.evaluateAppearance();
    }

    pub fn selectHair(instance: *CharacterInstance, hair_id: ?anatomy.HairDefinitionId) !void {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try runtime.selectHair(definition, hair_id);
        try instance.evaluateAppearance();
    }

    pub fn applyRightHandIk(instance: *CharacterInstance, target_world: math.Vec2, weight: f32) !arm_ik.Metrics {
        if (instance.right_arm_ik.applied) return error.ArmIkAlreadyAppliedThisTick;
        const world_bend = if (instance.facing == .right)
            instance.right_arm_binding.character_local_bend
        else
            instance.right_arm_binding.character_local_bend.opposite();
        const application = try arm_ik.apply(
            instance.right_arm_binding,
            &instance.character.local_and_world_pose,
            &instance.definition.skeleton_definition,
            instance.character.character_to_world,
            target_world,
            world_bend,
            weight,
        );
        instance.right_arm_ik = .{
            .applied = true,
            .pre_root_local = application.pre_root_local,
            .pre_middle_local = application.pre_middle_local,
            .metrics = application.metrics,
        };
        try instance.evaluateAppearance();
        return application.metrics;
    }

    pub fn clearRightHandIk(instance: *CharacterInstance) !void {
        if (!instance.right_arm_ik.applied) {
            instance.right_arm_ik = .{};
            return;
        }
        const saved = instance.right_arm_ik;
        instance.right_arm_ik = .{};
        try arm_ik.restore(
            instance.right_arm_binding,
            &instance.character.local_and_world_pose,
            &instance.definition.skeleton_definition,
            instance.character.character_to_world,
            saved.pre_root_local,
            saved.pre_middle_local,
        );
        try instance.evaluateAppearance();
    }

    pub fn rightHandIkMetrics(instance: CharacterInstance) ?arm_ik.Metrics {
        return instance.right_arm_ik.metrics;
    }

    pub fn socketPosition(instance: CharacterInstance, semantic: skeleton.SocketSemantic) !math.Vec2 {
        return instance.character.local_and_world_pose.socketPosition(&instance.definition.skeleton_definition, semantic);
    }

    pub fn resolvedOrder(instance: CharacterInstance, semantic: humanoid.AttachmentSemantic) !sprite.OrderInput {
        const attachment = try instance.definition.attachment(semantic);
        return instance.resolvedOrderForAttachment(attachment);
    }

    pub fn resolvedOrderForAttachment(instance: CharacterInstance, attachment: *const humanoid.RenderAttachment) sprite.OrderInput {
        const default_body_layer = if (attachment.canonical_semantic) |raw_semantic|
            humanoid.defaultBodyPartLayer(@enumFromInt(raw_semantic), instance.facing)
        else
            attachment.body_part_layer;
        const resolved = instance.overrides.resolve(@intFromEnum(attachment.id), default_body_layer);
        return .{
            .scene_layer = characters_scene_layer,
            .interaction_layer = resolved.interaction_layer,
            .actor_layer = instance.actor_layer,
            .body_part_layer = resolved.body_part_layer,
        };
    }

    pub fn submittedKey(instance: CharacterInstance, semantic: humanoid.AttachmentSemantic) !sprite.DrawOrderKey {
        return instance.last_submitted_keys[@intFromEnum(semantic)] orelse error.AttachmentNotSubmitted;
    }

    pub fn submitAttachments(instance: *CharacterInstance, batch: *sprite.SpriteBatch) !u32 {
        instance.last_submitted_keys = [_]?sprite.DrawOrderKey{null} ** humanoid.canonical_attachment_semantic_count;
        var submitted: u32 = 0;
        for (instance.definition.attachments) |attachment| {
            if (!try instance.character.appearance_runtime.isVisible(instance.definition.visual_definition, attachment.id)) continue;
            const world = try instance.character.appearance_runtime.visualWorld(instance.definition.visual_definition, attachment.id);
            const sprite_transform = try humanoid.spriteTransform(world);
            const world_size = sprite_transform.signed_scale.componentMul(attachment.sprite_size);
            const order = instance.resolvedOrderForAttachment(&attachment);
            const key = try batch.submitWithKey(.{
                .world_position = sprite_transform.world_position.toArray(),
                .rotation = sprite_transform.rotation_radians,
                .scale = world_size.toArray(),
                .pivot = attachment.pivot,
                .uv_rect = attachment.uv_rect,
                .tint = attachment.tint,
                .texture_page = attachment.texture_page,
                .order = order,
            });
            if (attachment.canonical_semantic) |raw_semantic| {
                instance.last_submitted_keys[raw_semantic] = key;
            }
            submitted += 1;
        }
        submitted += try instance.submitEquipmentVisuals(batch);
        return submitted;
    }

    pub fn initializeEquipment(instance: *CharacterInstance, definition: equipment.DefinitionView) !void {
        if (instance.equipment_loadout != null) return error.CharacterEquipmentAlreadyInitialized;
        const loadout = try equipment.Loadout.init(definition, try instance.equipmentContext());
        const resolved = try resolveLoadoutProperties(&loadout);
        instance.equipment_loadout = loadout;
        instance.property_bindings = PropertyBindings.init(definition);
        instance.resolved_properties = resolved;
    }

    pub fn equipItem(instance: *CharacterInstance, item_id: equipment.EquipmentItemId) !void {
        const context = try instance.equipmentContext();
        const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
        var candidate = loadout.*;
        try candidate.equip(context, item_id);
        const resolved = try resolveLoadoutProperties(&candidate);
        loadout.* = candidate;
        instance.resolved_properties = resolved;
    }

    pub fn replaceItem(instance: *CharacterInstance, item_id: equipment.EquipmentItemId) !void {
        const context = try instance.equipmentContext();
        const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
        var candidate = loadout.*;
        try candidate.replace(context, item_id);
        const resolved = try resolveLoadoutProperties(&candidate);
        loadout.* = candidate;
        instance.resolved_properties = resolved;
    }

    pub fn unequipItem(instance: *CharacterInstance, item_id: equipment.EquipmentItemId) !void {
        const context = try instance.equipmentContext();
        const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
        var candidate = loadout.*;
        try candidate.unequip(context, item_id);
        const resolved = try resolveLoadoutProperties(&candidate);
        loadout.* = candidate;
        instance.resolved_properties = resolved;
    }

    pub fn selectEquipmentItems(
        instance: *CharacterInstance,
        item_ids: []const equipment.EquipmentItemId,
    ) !void {
        const context = try instance.equipmentContext();
        const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
        var candidate = loadout.*;
        try candidate.replaceAll(context, item_ids);
        const resolved = try resolveLoadoutProperties(&candidate);
        loadout.* = candidate;
        instance.resolved_properties = resolved;
    }

    pub fn attributeValue(instance: CharacterInstance, attribute_id: properties.AttributeId) !f32 {
        const resolved = instance.resolved_properties orelse return error.CharacterPropertiesNotInitialized;
        return resolved.value(attribute_id);
    }

    pub fn hasCapability(instance: CharacterInstance, capability_id: properties.CapabilityId) !bool {
        const resolved = instance.resolved_properties orelse return error.CharacterPropertiesNotInitialized;
        _ = try resolved.grantCount(capability_id);
        return resolved.hasCapability(capability_id);
    }

    pub fn capabilityGrantCount(instance: CharacterInstance, capability_id: properties.CapabilityId) !u16 {
        const resolved = instance.resolved_properties orelse return error.CharacterPropertiesNotInitialized;
        return resolved.grantCount(capability_id);
    }

    pub fn equipmentVisualWorld(instance: *CharacterInstance, visual_index: usize) !math.Mat3 {
        return (try instance.equipmentVisualTransform(visual_index)).world();
    }

    pub fn equipmentVisualTransform(instance: *CharacterInstance, visual_index: usize) !ResolvedEquipmentTransform {
        const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
        const anatomy_definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const anatomy_runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try loadout.validateCompatibility(.{
            .definition = anatomy_definition,
            .runtime = anatomy_runtime,
            .owning_character = instance.id.raw(),
        });
        if (loadout.definition.appearance_token != instance.definition.visual_definition.owner_token) {
            return error.EquipmentAppearanceDefinitionMismatch;
        }
        if (visual_index >= loadout.visuals().len) return error.InvalidResolvedEquipmentVisualIndex;
        const visual = loadout.visuals()[visual_index];
        const recipe = try loadout.definition.recipe(visual.recipe);
        if (recipe.component.index() >= loadout.definition.visual_components.len) {
            return error.InvalidEquipmentVisualReference;
        }
        const component = loadout.definition.visual_components[recipe.component.index()];
        const secondary_deformation = if (component.secondary_motion) |motion_definition|
            try visual.secondary.resolvedTransform(motion_definition)
        else
            math.Transform2D.identity();
        return switch (visual.source) {
            .anatomy_part => |part_id| .{
                .binding_world = (try anatomy_runtime.partBindingWorld(anatomy_definition, part_id))
                    .mul(try recipe.local_to_binding.localToParent()),
                .resolved_deformation = try anatomy_runtime.resolvedDeformationForPart(
                    anatomy_definition,
                    part_id,
                    component.deformation_response,
                ),
                .secondary_deformation = secondary_deformation,
                .bound_identity = .{ .anatomy_part = @intFromEnum(part_id) },
            },
            .attachment_point => |point_id| .{
                .binding_world = (try instance.character.appearance_runtime.attachmentPointWorld(
                    instance.definition.visual_definition,
                    point_id,
                )).mul(try recipe.local_to_binding.localToParent()),
                .resolved_deformation = math.Transform2D.identity(),
                .secondary_deformation = secondary_deformation,
                .bound_identity = .{ .attachment_point = @intFromEnum(point_id) },
            },
        };
    }

    fn submitEquipmentVisuals(instance: *CharacterInstance, batch: *sprite.SpriteBatch) !u32 {
        const loadout = if (instance.equipment_loadout) |*value| value else return 0;
        const anatomy_definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const anatomy_runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try loadout.validateCompatibility(.{
            .definition = anatomy_definition,
            .runtime = anatomy_runtime,
            .owning_character = instance.id.raw(),
        });
        if (loadout.definition.appearance_token != instance.definition.visual_definition.owner_token) {
            return error.EquipmentAppearanceDefinitionMismatch;
        }

        var submitted: u32 = 0;
        for (loadout.visuals(), 0..) |visual, visual_index| {
            const recipe = try loadout.definition.recipe(visual.recipe);
            if (recipe.component.index() >= loadout.definition.visual_components.len or
                recipe.visual_layer.index() >= loadout.definition.visual_layers.len)
            {
                return error.InvalidEquipmentVisualReference;
            }
            const component = loadout.definition.visual_components[recipe.component.index()];
            if (component.primitive == .deformable_mesh) return error.MeshRequiresUnifiedRenderQueue;
            const layer = loadout.definition.visual_layers[recipe.visual_layer.index()];
            const world = try instance.equipmentVisualWorld(visual_index);
            const sprite_transform = try humanoid.spriteTransform(world);
            const world_size = sprite_transform.signed_scale.componentMul(component.sprite_size);
            _ = try batch.submitWithKey(.{
                .world_position = sprite_transform.world_position.toArray(),
                .rotation = sprite_transform.rotation_radians,
                .scale = world_size.toArray(),
                .pivot = component.pivot,
                .uv_rect = component.uv_rect,
                .tint = component.tint,
                .texture_page = component.texture_page,
                .order = .{
                    .scene_layer = characters_scene_layer,
                    .interaction_layer = neutral_interaction_layer,
                    .actor_layer = instance.actor_layer,
                    .body_part_layer = layer.render_layer,
                },
            });
            submitted += 1;
        }
        return submitted;
    }

    pub fn submitUnified(instance: *CharacterInstance, queue: *render_queue.UnifiedRenderQueue) !u32 {
        instance.last_submitted_keys = [_]?sprite.DrawOrderKey{null} ** humanoid.canonical_attachment_semantic_count;
        var submitted: u32 = 0;
        for (instance.definition.attachments) |attachment| {
            if (!try instance.character.appearance_runtime.isVisible(instance.definition.visual_definition, attachment.id)) continue;
            const world = try instance.character.appearance_runtime.visualWorld(instance.definition.visual_definition, attachment.id);
            const sprite_transform = try humanoid.spriteTransform(world);
            const world_size = sprite_transform.signed_scale.componentMul(attachment.sprite_size);
            const key = try queue.submitSprite(.{
                .world_position = sprite_transform.world_position.toArray(),
                .rotation = sprite_transform.rotation_radians,
                .scale = world_size.toArray(),
                .pivot = attachment.pivot,
                .uv_rect = attachment.uv_rect,
                .tint = attachment.tint,
                .texture_page = attachment.texture_page,
                .order = instance.resolvedOrderForAttachment(&attachment),
            });
            if (attachment.canonical_semantic) |raw_semantic| instance.last_submitted_keys[raw_semantic] = key;
            submitted += 1;
        }
        submitted += try instance.submitUnifiedEquipment(queue);
        return submitted;
    }

    fn submitUnifiedEquipment(instance: *CharacterInstance, queue: *render_queue.UnifiedRenderQueue) !u32 {
        const loadout = if (instance.equipment_loadout) |*value| value else return 0;
        const anatomy_definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const anatomy_runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        try loadout.validateCompatibility(.{
            .definition = anatomy_definition,
            .runtime = anatomy_runtime,
            .owning_character = instance.id.raw(),
        });
        if (loadout.definition.appearance_token != instance.definition.visual_definition.owner_token) {
            return error.EquipmentAppearanceDefinitionMismatch;
        }

        var submitted: u32 = 0;
        var visual_index: usize = 0;
        while (visual_index < loadout.visuals().len) : (visual_index += 1) {
            const visual = loadout.visuals()[visual_index];
            const recipe = try loadout.definition.recipe(visual.recipe);
            if (recipe.component.index() >= loadout.definition.visual_components.len or
                recipe.visual_layer.index() >= loadout.definition.visual_layers.len)
            {
                return error.InvalidEquipmentVisualReference;
            }
            const component = loadout.definition.visual_components[recipe.component.index()];
            const layer = loadout.definition.visual_layers[recipe.visual_layer.index()];
            const resolved = try instance.equipmentVisualTransform(visual_index);
            const order = sprite.OrderInput{
                .scene_layer = characters_scene_layer,
                .interaction_layer = neutral_interaction_layer,
                .actor_layer = instance.actor_layer,
                .body_part_layer = layer.render_layer,
            };
            switch (component.primitive) {
                .rigid_sprite => {
                    const sprite_transform = try humanoid.spriteTransform(try resolved.world());
                    const world_size = sprite_transform.signed_scale.componentMul(component.sprite_size);
                    _ = try queue.submitSprite(.{
                        .world_position = sprite_transform.world_position.toArray(),
                        .rotation = sprite_transform.rotation_radians,
                        .scale = world_size.toArray(),
                        .pivot = component.pivot,
                        .uv_rect = component.uv_rect,
                        .tint = component.tint,
                        .texture_page = component.texture_page,
                        .order = order,
                    });
                },
                .deformable_mesh => |definition| {
                    const composed_deformation = try resolved.composedDeformation();
                    try loadout.resolved_visuals[visual_index].mesh_state.update(
                        instance.id.raw(),
                        resolved.bound_identity,
                        resolved.binding_world,
                        composed_deformation,
                    );
                    _ = try queue.submitMesh(.{
                        .definition = definition,
                        .binding_world = resolved.binding_world,
                        .resolved_deformation = composed_deformation,
                        .owning_character = instance.id.raw(),
                        .bound_identity = resolved.bound_identity,
                        .order = order,
                    });
                },
            }
            submitted += 1;
        }
        return submitted;
    }

    fn equipmentContext(instance: *CharacterInstance) !equipment.AnatomyContext {
        const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        return .{ .definition = definition, .runtime = runtime, .owning_character = instance.id.raw() };
    }

    fn controllerGameplayProperties(instance: CharacterInstance) !character_controller.GameplayProperties {
        const controller = instance.controller orelse return error.CharacterHasNoController;
        var movement = character_controller.GameplayProperties.fromConfiguration(controller.configuration);
        if (instance.resolved_properties) |resolved| {
            if (instance.property_bindings) |bindings| {
                if (bindings.movement_speed) |id| movement.maximum_run_speed = try resolved.value(id);
                if (bindings.jump_strength) |id| movement.jump_speed = try resolved.value(id);
                if (bindings.double_jump) |id| movement.double_jump = resolved.hasCapability(id);
                if (bindings.dash) |id| movement.dash = resolved.hasCapability(id);
            }
        }
        try movement.validate(controller.configuration);
        return movement;
    }

    fn applyValidatedOverride(instance: *CharacterInstance, attachment_id: u16, validated: ValidatedOverrideRequest) !OverrideHandle {
        return instance.overrides.applyValidated(attachment_id, validated);
    }

    fn evaluateWorldPose(instance: *CharacterInstance) !void {
        const visual_scale = math.Vec2{ .x = if (instance.facing == .left) -1 else 1, .y = 1 };
        instance.character.character_to_world = math.Transform2D.init(instance.world_position, 0, visual_scale);
        try instance.character.local_and_world_pose.evaluateWorld(
            &instance.definition.skeleton_definition,
            instance.character.character_to_world,
        );
        try instance.evaluateAppearance();
    }

    fn evaluateAppearance(instance: *CharacterInstance) !void {
        if (instance.character.anatomy_runtime) |*runtime| {
            const anatomy_definition = instance.definition.anatomy_definition orelse return error.AnatomyDefinitionMismatch;
            try runtime.applyAppearanceState(
                anatomy_definition,
                instance.definition.visual_definition,
                &instance.character.appearance_runtime,
            );
        }
        try instance.character.appearance_runtime.evaluate(
            instance.definition.visual_definition,
            &instance.definition.skeleton_definition,
            &instance.character.local_and_world_pose,
        );
        if (instance.character.anatomy_runtime) |*runtime| {
            const anatomy_definition = instance.definition.anatomy_definition orelse return error.AnatomyDefinitionMismatch;
            try runtime.evaluateHierarchy(
                anatomy_definition,
                instance.definition.visual_definition,
                &instance.character.appearance_runtime,
            );
        }
    }

    fn restoreRightHandIkLocals(instance: *CharacterInstance) !void {
        if (!instance.right_arm_ik.applied) {
            instance.right_arm_ik = .{};
            return;
        }
        const saved = instance.right_arm_ik;
        instance.right_arm_ik = .{};
        try instance.character.local_and_world_pose.setLocal(instance.right_arm_binding.root_bone, saved.pre_root_local);
        try instance.character.local_and_world_pose.setLocal(instance.right_arm_binding.middle_bone, saved.pre_middle_local);
    }

    fn restoreFootIkLocals(instance: *CharacterInstance) !void {
        try foot_planting.restoreApplied(
            &instance.foot_plants,
            &instance.character.local_and_world_pose,
            &instance.definition.skeleton_definition,
            instance.character.character_to_world,
            instance.left_leg_binding,
            instance.right_leg_binding,
        );
    }
};

const equipment_property_source_kind: u16 = 1;

fn resolveLoadoutProperties(loadout: *const equipment.Loadout) !properties.ResolvedSet {
    var builder = try properties.Builder.init(
        loadout.definition.attributes,
        loadout.definition.capabilities,
        &.{},
    );
    for (loadout.modifiers()) |modifier| {
        try builder.addModifier(.{
            .source = properties.SourceId.init(equipment_property_source_kind, @intFromEnum(modifier.item)),
            .source_ordinal = modifier.source_ordinal,
            .attribute = modifier.attribute,
            .operation = modifier.operation,
            .amount = modifier.amount,
        });
    }
    for (loadout.capabilities()) |grant| {
        try builder.addCapabilityGrant(.{
            .source = properties.SourceId.init(equipment_property_source_kind, @intFromEnum(grant.item)),
            .capability = grant.capability,
        });
    }
    return builder.finish();
}

pub fn submitGlobally(instances: []const *CharacterInstance, batch: *sprite.SpriteBatch) !u32 {
    if (instances.len > maximum_characters) return error.CharacterCapacityExceeded;
    var ordered: [maximum_characters]*CharacterInstance = undefined;
    for (instances, 0..) |instance, index| {
        if (!instance.id.isValid()) return error.InvalidEntityId;
        ordered[index] = instance;
    }
    var index: usize = 1;
    while (index < instances.len) : (index += 1) {
        const candidate = ordered[index];
        var destination = index;
        while (destination > 0 and candidate.id.raw() < ordered[destination - 1].id.raw()) : (destination -= 1) {
            ordered[destination] = ordered[destination - 1];
        }
        ordered[destination] = candidate;
    }
    for (ordered[0..instances.len], 0..) |instance, ordered_index| {
        if (ordered_index > 0 and ordered[ordered_index - 1].id == instance.id) return error.DuplicateEntityId;
    }

    var submitted: u32 = 0;
    for (ordered[0..instances.len]) |instance| submitted += try instance.submitAttachments(batch);
    return submitted;
}

pub fn submitUnifiedGlobally(instances: []const *CharacterInstance, queue: *render_queue.UnifiedRenderQueue) !u32 {
    if (instances.len > maximum_characters) return error.CharacterCapacityExceeded;
    var ordered: [maximum_characters]*CharacterInstance = undefined;
    for (instances, 0..) |instance, index| {
        if (!instance.id.isValid()) return error.InvalidEntityId;
        ordered[index] = instance;
    }
    var index: usize = 1;
    while (index < instances.len) : (index += 1) {
        const candidate = ordered[index];
        var destination = index;
        while (destination > 0 and candidate.id.raw() < ordered[destination - 1].id.raw()) : (destination -= 1) {
            ordered[destination] = ordered[destination - 1];
        }
        ordered[destination] = candidate;
    }
    for (ordered[0..instances.len], 0..) |instance, ordered_index| {
        if (ordered_index > 0 and ordered[ordered_index - 1].id == instance.id) return error.DuplicateEntityId;
    }

    var submitted: u32 = 0;
    for (ordered[0..instances.len]) |instance| submitted += try instance.submitUnified(queue);
    return submitted;
}

pub fn resetAll(instances: []const *CharacterInstance) !void {
    for (instances) |instance| try instance.reset();
}

const WalkSample = struct {
    phase: f32 = 0,
    weight: f32 = 0,
    allows_planting: bool = false,
};

fn currentWalkSample(instance: *const CharacterInstance) WalkSample {
    const animator = instance.animator;
    const machine = &instance.shared_animations.machine;
    const clips = instance.shared_animations.clips;
    if (animator.active_transition) |transition| {
        const weight = if (transition.duration == 0) 1 else @min(1, transition.elapsed / transition.duration);
        if (machine.states[transition.destination_state_index].id == .walk) {
            return .{
                .phase = playbackPhase(machine, clips, transition.destination_state_index, transition.destination_playback.current_time),
                .weight = weight,
                .allows_planting = true,
            };
        }
        if (machine.states[transition.source_state_index].id == .walk) {
            return .{
                .phase = playbackPhase(machine, clips, transition.source_state_index, transition.source_playback.current_time),
                .weight = 1 - weight,
            };
        }
        return .{};
    }
    if (machine.states[animator.current_state_index].id != .walk) return .{};
    return .{
        .phase = playbackPhase(machine, clips, animator.current_state_index, animator.playback.current_time),
        .weight = 1,
        .allows_planting = true,
    };
}

fn playbackPhase(machine: *const state_machine.Definition, clips: anytype, state_index: u16, current_time: f32) f32 {
    const animation_state = machine.states[state_index];
    const duration = clips[animation_state.clip_index].duration;
    return if (duration > 0) current_time / duration else 0;
}
