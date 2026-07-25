const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const anatomy = @import("anatomy");
const equipment = @import("equipment");
const character = @import("character");
const equipment_demo = @import("equipment_demo");
const sprite = @import("sprite_batch");

pub const required_frames: u32 = 240;
pub const fixed_ticks_per_frame: u32 = 4;
pub const character_count: usize = equipment_demo.character_count;

pub const Evidence = struct {
    minimum_sample: f32 = 1,
    maximum_sample: f32 = -1,
    minimum_torso_scale_x: f32 = std.math.inf(f32),
    maximum_torso_scale_x: f32 = -std.math.inf(f32),
    body_clothing_agreement: bool = true,
    four_independent_sleeve_bindings: bool = false,
    isolated_sleeve_override: bool = false,
    rigid_opt_out: bool = false,
};

pub const Scene = struct {
    equipment_scene: equipment_demo.Scene,
    evidence: Evidence = .{},
    fixed_ticks: u64 = 0,
    initial_two_root: math.Vec2,
    initial_four_root: math.Vec2,
    initial_two_ik_lengths: [2]f32,
    initial_four_ik_lengths: [2]f32,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var base = try equipment_demo.Scene.init(allocator);
        errdefer base.deinit();
        try base.two_arm.configureBreathing(try deformation.BreathingConfiguration.init(960, 0.8));
        try base.four_arm.configureBreathing(try deformation.BreathingConfiguration.init(720, 0.65));
        try base.four_arm.setBreathingPhaseTick(180);

        var scene = Scene{
            .equipment_scene = base,
            .initial_two_root = base.two_arm.world_position,
            .initial_four_root = base.four_arm.world_position,
            .initial_two_ik_lengths = .{ base.two_arm.right_arm_binding.upper_length, base.two_arm.right_arm_binding.lower_length },
            .initial_four_ik_lengths = .{ base.four_arm.right_arm_binding.upper_length, base.four_arm.right_arm_binding.lower_length },
        };
        scene.evidence.four_independent_sleeve_bindings = try hasIndependentSleeveBindings(&scene.equipment_scene.four_arm);
        scene.evidence.rigid_opt_out = try rigidComponentsOptOut(&scene.equipment_scene.equipment_definition);
        try scene.observe();
        return scene;
    }

    pub fn deinit(scene: *Scene) void {
        scene.equipment_scene.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene, frame: u32) !void {
        try scene.equipment_scene.updateFrame(frame);
        scene.fixed_ticks += @intCast(character_count);
        for (1..fixed_ticks_per_frame) |_| {
            try scene.equipment_scene.two_arm.advanceVisualTick(.{});
            try scene.equipment_scene.four_arm.advanceVisualTick(.{});
            scene.fixed_ticks += @intCast(character_count);
        }
        if (frame == 40) scene.evidence.isolated_sleeve_override = try proveIsolatedSleeveOverride(&scene.equipment_scene.four_arm);
        try scene.observe();
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        return scene.equipment_scene.submit(batch);
    }

    pub fn validateComplete(scene: *const Scene) !void {
        if (scene.fixed_ticks != @as(u64, required_frames) *
            @as(u64, fixed_ticks_per_frame) *
            @as(u64, character_count))
        {
            return error.BreathingTickCountMismatch;
        }
        if (scene.evidence.maximum_sample - scene.evidence.minimum_sample < 1.25 or
            scene.evidence.maximum_torso_scale_x - scene.evidence.minimum_torso_scale_x < 0.025 or
            !scene.evidence.body_clothing_agreement or
            !scene.evidence.four_independent_sleeve_bindings or
            !scene.evidence.isolated_sleeve_override or
            !scene.evidence.rigid_opt_out)
        {
            return error.BreathingDeformationEvidenceIncomplete;
        }
        if (!scene.initial_two_root.approxEqAbs(scene.equipment_scene.two_arm.world_position, 0) or
            !scene.initial_four_root.approxEqAbs(scene.equipment_scene.four_arm.world_position, 0) or
            scene.initial_two_ik_lengths[0] != scene.equipment_scene.two_arm.right_arm_binding.upper_length or
            scene.initial_two_ik_lengths[1] != scene.equipment_scene.two_arm.right_arm_binding.lower_length or
            scene.initial_four_ik_lengths[0] != scene.equipment_scene.four_arm.right_arm_binding.upper_length or
            scene.initial_four_ik_lengths[1] != scene.equipment_scene.four_arm.right_arm_binding.lower_length)
        {
            return error.BreathingGameplayInvarianceFailed;
        }
    }

    fn observe(scene: *Scene) !void {
        const sample = try scene.equipment_scene.two_arm.breathingSample();
        scene.evidence.minimum_sample = @min(scene.evidence.minimum_sample, sample);
        scene.evidence.maximum_sample = @max(scene.evidence.maximum_sample, sample);

        const instance = &scene.equipment_scene.two_arm;
        const anatomy_definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
        const runtime = if (instance.character.anatomy_runtime) |*value| value else return error.CharacterHasNoAnatomy;
        const torso_id = try anatomy_definition.partInstanceId("torso");
        const part = anatomy_definition.part_instances[torso_id.index()];
        const part_definition = anatomy_definition.part_definitions[part.definition.index()];
        const skin = try runtime.resolvedDeformationForPart(anatomy_definition, torso_id, .{});
        scene.evidence.minimum_torso_scale_x = @min(scene.evidence.minimum_torso_scale_x, skin.scale.x);
        scene.evidence.maximum_torso_scale_x = @max(scene.evidence.maximum_torso_scale_x, skin.scale.x);

        const sweatshirt_component = try scene.equipment_scene.equipment_definition.visualComponentId("sweatshirt_torso");
        const response = scene.equipment_scene.equipment_definition.visual_components[sweatshirt_component.index()].deformation_response;
        const cloth = try runtime.resolvedDeformationForPart(anatomy_definition, torso_id, response);
        const skin_neutral = try deformation.resolve(.{
            .base_morphology = runtime.part_morph_local[torso_id.index()],
            .breathing_binding = part_definition.breathing_binding,
            .breathing_sample = 0,
            .response = .{},
        });
        const cloth_neutral = try deformation.resolve(.{
            .base_morphology = runtime.part_morph_local[torso_id.index()],
            .breathing_binding = part_definition.breathing_binding,
            .breathing_sample = 0,
            .response = response,
        });
        const skin_delta = skin.scale.x - skin_neutral.scale.x;
        const cloth_delta = cloth.scale.x - cloth_neutral.scale.x;
        if (skin_delta * cloth_delta < -1e-8 or @abs(cloth_delta) > @abs(skin_delta) + 1e-6) {
            scene.evidence.body_clothing_agreement = false;
        }
    }
};

fn hasIndependentSleeveBindings(instance: *character.CharacterInstance) !bool {
    const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
    const component_id = try loadout.definition.visualComponentId("long_sleeve");
    var parts: [4]anatomy.BodyPartInstanceId = undefined;
    var count: usize = 0;
    for (loadout.visuals()) |visual| {
        const recipe = try loadout.definition.recipe(visual.recipe);
        if (recipe.component != component_id) continue;
        const part_id = switch (visual.source) {
            .anatomy_part => |value| value,
            .attachment_point => return false,
        };
        for (parts[0..count]) |existing| if (existing == part_id) return false;
        if (count >= parts.len) return false;
        parts[count] = part_id;
        count += 1;
    }
    return count == parts.len;
}

fn proveIsolatedSleeveOverride(instance: *character.CharacterInstance) !bool {
    const loadout = if (instance.equipment_loadout) |*value| value else return error.CharacterEquipmentNotInitialized;
    const anatomy_definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
    const component_id = try loadout.definition.visualComponentId("long_sleeve");
    var indices: [4]usize = undefined;
    var sources: [4]anatomy.BodyPartInstanceId = undefined;
    var before: [4]math.Mat3 = undefined;
    var count: usize = 0;
    for (loadout.visuals(), 0..) |visual, index| {
        const recipe = try loadout.definition.recipe(visual.recipe);
        if (recipe.component != component_id) continue;
        if (count >= indices.len) return false;
        indices[count] = index;
        sources[count] = switch (visual.source) {
            .anatomy_part => |value| value,
            .attachment_point => return false,
        };
        before[count] = try instance.equipmentVisualWorld(index);
        count += 1;
    }
    if (count != indices.len) return false;
    const changed_part = try anatomy_definition.partInstanceId("extra_arm");
    try instance.setPartMorphologyOverride(
        changed_part,
        try anatomy_definition.morphologyChannelId("upper_arm_thickness"),
        100,
    );
    var changed_count: usize = 0;
    for (indices, sources, before) |index, source, previous| {
        const changed = !previous.approxEqAbs(try instance.equipmentVisualWorld(index), 1e-6);
        if (source == changed_part) {
            if (!changed) return false;
            changed_count += 1;
        } else if (changed) {
            return false;
        }
    }
    return changed_count == 1;
}

fn rigidComponentsOptOut(definition: *const equipment.Definition) !bool {
    const armor = definition.visual_components[(try definition.visualComponentId("armor_torso")).index()].deformation_response;
    const gauntlet = definition.visual_components[(try definition.visualComponentId("gauntlet")).index()].deformation_response;
    return armor.breathing == 0 and gauntlet.breathing == 0 and gauntlet.morphology == 0;
}
