const std = @import("std");
const input = @import("input");
const collider = @import("collider");
const collision_world = @import("collision_world");
const character_controller = @import("character_controller");
const character = @import("character");
const equipment_demo = @import("equipment_demo");
const sprite = @import("sprite_batch");

pub const required_frames: u32 = 240;
pub const character_count: usize = 2;

pub const Evidence = struct {
    default_movement_speed: f32 = 0,
    modified_movement_speed: f32 = 0,
    default_jump_strength: f32 = 0,
    modified_jump_strength: f32 = 0,
    carrying_capacity: f32 = 0,
    armor: f32 = 0,
    damage_reduction: f32 = 0,
    default_movement_observed: bool = false,
    modified_movement_observed: bool = false,
    stronger_jump_observed: bool = false,
    double_jump_denied: bool = false,
    double_jump_allowed: bool = false,
    dash_denied: bool = false,
    dash_allowed: bool = false,
    dash_collision_observed: bool = false,
    duplicate_grants_preserved: bool = false,
    restoration_observed: bool = false,
    character_isolation_observed: bool = false,
};

pub const Scene = struct {
    visual_scene: equipment_demo.Scene,
    world: collision_world.CollisionWorld,
    evidence: Evidence = .{},
    visual_ticks: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var visual_scene = try equipment_demo.Scene.init(allocator);
        errdefer visual_scene.deinit();
        const colliders = [_]collider.StaticColliderInput{
            .{
                .id = 1,
                .bounds = .{ .minimum = .{ .x = -100, .y = -1 }, .maximum = .{ .x = 100, .y = 0 } },
            },
            .{
                .id = 2,
                .bounds = .{ .minimum = .{ .x = 1, .y = 0 }, .maximum = .{ .x = 1.2, .y = 4 } },
                .ground_query_eligible = false,
            },
        };
        var world = try collision_world.CollisionWorld.init(allocator, &colliders, null);
        errdefer world.deinit();

        var scene = Scene{
            .visual_scene = visual_scene,
            .world = world,
        };
        try scene.collectEvidence();
        return scene;
    }

    pub fn deinit(scene: *Scene) void {
        scene.world.deinit();
        scene.visual_scene.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene) !void {
        try scene.visual_scene.two_arm.advanceVisualTick(.{});
        try scene.visual_scene.four_arm.advanceVisualTick(.{});
        scene.visual_ticks += character_count;
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        return character.submitGlobally(&.{
            &scene.visual_scene.two_arm,
            &scene.visual_scene.four_arm,
        }, batch);
    }

    pub fn validateComplete(scene: Scene) !void {
        const evidence = scene.evidence;
        if (!evidence.default_movement_observed or
            !evidence.modified_movement_observed or
            !evidence.stronger_jump_observed or
            !evidence.double_jump_denied or
            !evidence.double_jump_allowed or
            !evidence.dash_denied or
            !evidence.dash_allowed or
            !evidence.dash_collision_observed or
            !evidence.duplicate_grants_preserved or
            !evidence.restoration_observed or
            !evidence.character_isolation_observed or
            scene.visual_ticks != @as(u64, required_frames) * character_count)
        {
            return error.CharacterPropertyDemonstrationIncomplete;
        }
    }

    fn collectEvidence(scene: *Scene) !void {
        const definition = scene.visual_scene.equipment_definition.view();
        const movement_speed = try definition.attributeId("movement_speed");
        const jump_strength = try definition.attributeId("jump_strength");
        const carrying_capacity = try definition.attributeId("carrying_capacity");
        const armor = try definition.attributeId("armor");
        const damage_reduction = try definition.attributeId("physical_damage_reduction");
        const double_jump = try definition.capabilityId("double_jump");
        const dash = try definition.capabilityId("dash");

        scene.evidence.default_movement_speed = try scene.visual_scene.four_arm.attributeValue(movement_speed);
        scene.evidence.modified_movement_speed = try scene.visual_scene.two_arm.attributeValue(movement_speed);
        scene.evidence.default_jump_strength = try scene.visual_scene.four_arm.attributeValue(jump_strength);
        scene.evidence.carrying_capacity = try scene.visual_scene.two_arm.attributeValue(carrying_capacity);
        scene.evidence.armor = try scene.visual_scene.four_arm.attributeValue(armor);

        const default_properties = character_controller.GameplayProperties{
            .maximum_run_speed = scene.evidence.default_movement_speed,
            .jump_speed = scene.evidence.default_jump_strength,
        };
        var modified_properties = default_properties;
        modified_properties.maximum_run_speed = scene.evidence.modified_movement_speed;

        var default_controller = try character_controller.CharacterController.init(
            .{},
            &scene.world,
            .{ .x = -5, .y = 1.05 },
            .right,
        );
        var modified_controller = default_controller;
        for (0..120) |_| {
            _ = try default_controller.stepWithProperties(&scene.world, moveIntent(1), default_properties);
            _ = try modified_controller.stepWithProperties(&scene.world, moveIntent(1), modified_properties);
        }
        scene.evidence.default_movement_observed =
            approximate(default_controller.state.velocity.x, scene.evidence.default_movement_speed);
        scene.evidence.modified_movement_observed =
            approximate(modified_controller.state.velocity.x, scene.evidence.modified_movement_speed) and
            modified_controller.state.position.x > default_controller.state.position.x;

        const speed_boots = try definition.itemId("speed_boots");
        try scene.visual_scene.two_arm.replaceItem(try definition.itemId("spring_boots"));
        scene.evidence.modified_jump_strength = try scene.visual_scene.two_arm.attributeValue(jump_strength);
        var strong_properties = default_properties;
        strong_properties.jump_speed = scene.evidence.modified_jump_strength;
        var default_jumper = try character_controller.CharacterController.init(
            .{},
            &scene.world,
            .{ .x = -8, .y = 1.05 },
            .right,
        );
        var strong_jumper = default_jumper;
        _ = try default_jumper.stepWithProperties(&scene.world, jumpIntent(), default_properties);
        _ = try strong_jumper.stepWithProperties(&scene.world, jumpIntent(), strong_properties);
        scene.evidence.stronger_jump_observed = strong_jumper.state.velocity.y > default_jumper.state.velocity.y;
        try scene.visual_scene.two_arm.replaceItem(speed_boots);
        scene.evidence.restoration_observed =
            approximate(try scene.visual_scene.two_arm.attributeValue(movement_speed), scene.evidence.modified_movement_speed);

        var without_double = try character_controller.CharacterController.init(
            .{},
            &scene.world,
            .{ .x = -12, .y = 1.05 },
            .right,
        );
        _ = try without_double.stepWithProperties(&scene.world, jumpIntent(), default_properties);
        scene.evidence.double_jump_denied =
            !(try without_double.stepWithProperties(&scene.world, jumpIntent(), default_properties)).jump_accepted;

        var with_double = try character_controller.CharacterController.init(
            .{},
            &scene.world,
            .{ .x = -15, .y = 1.05 },
            .right,
        );
        var double_properties = default_properties;
        double_properties.double_jump = try scene.visual_scene.four_arm.hasCapability(double_jump);
        _ = try with_double.stepWithProperties(&scene.world, jumpIntent(), double_properties);
        const air_jump = try with_double.stepWithProperties(&scene.world, jumpIntent(), double_properties);
        scene.evidence.double_jump_allowed = air_jump.jump_accepted and air_jump.jump_source == .air;

        var without_dash = try character_controller.CharacterController.init(
            .{},
            &scene.world,
            .{ .x = -20, .y = 1.05 },
            .right,
        );
        const denied_dash = try without_dash.stepWithProperties(&scene.world, dashIntent(1), default_properties);
        scene.evidence.dash_denied = denied_dash.dash_denied and !denied_dash.dash_started;

        var dash_properties = default_properties;
        dash_properties.dash = try scene.visual_scene.two_arm.hasCapability(dash);
        var with_dash = try character_controller.CharacterController.init(
            .{},
            &scene.world,
            .{ .x = -25, .y = 1.05 },
            .right,
        );
        const allowed_dash = try with_dash.stepWithProperties(&scene.world, dashIntent(-1), dash_properties);
        scene.evidence.dash_allowed = allowed_dash.dash_started and with_dash.state.facing == .left;

        var collision_dash = try character_controller.CharacterController.init(
            .{},
            &scene.world,
            .{ .x = 0, .y = 1.05 },
            .right,
        );
        _ = try collision_dash.stepWithProperties(&scene.world, dashIntent(1), dash_properties);
        for (0..40) |_| {
            const result = try collision_dash.stepWithProperties(&scene.world, emptyIntent(), dash_properties);
            if (result.wall_collision) {
                scene.evidence.dash_collision_observed =
                    result.dash_ended and collision_dash.state.dash_ticks_remaining == 0;
                break;
            }
        }

        const winged_boots = try definition.itemId("winged_boots");
        try scene.visual_scene.two_arm.replaceItem(winged_boots);
        try scene.visual_scene.two_arm.replaceItem(try definition.itemId("feather_amulet"));
        const duplicate_count = try scene.visual_scene.two_arm.capabilityGrantCount(double_jump);
        try scene.visual_scene.two_arm.unequipItem(winged_boots);
        const remaining_count = try scene.visual_scene.two_arm.capabilityGrantCount(double_jump);
        scene.evidence.duplicate_grants_preserved = duplicate_count == 2 and remaining_count == 1;
        try scene.visual_scene.two_arm.replaceItem(speed_boots);
        try scene.visual_scene.two_arm.replaceItem(try definition.itemId("amulet"));

        const backpack = try definition.itemId("backpack");
        try scene.visual_scene.two_arm.unequipItem(backpack);
        const capacity_without_backpack = try scene.visual_scene.two_arm.attributeValue(carrying_capacity);
        try scene.visual_scene.two_arm.equipItem(backpack);
        scene.evidence.restoration_observed = scene.evidence.restoration_observed and
            capacity_without_backpack < scene.evidence.carrying_capacity and
            approximate(try scene.visual_scene.two_arm.attributeValue(carrying_capacity), scene.evidence.carrying_capacity);

        const full_plate = try definition.itemId("full_plate_armor");
        try scene.visual_scene.four_arm.replaceItem(full_plate);
        scene.evidence.armor = try scene.visual_scene.four_arm.attributeValue(armor);
        scene.evidence.damage_reduction = try scene.visual_scene.four_arm.attributeValue(damage_reduction);
        try scene.visual_scene.four_arm.unequipItem(full_plate);
        try scene.visual_scene.four_arm.equipItem(try definition.itemId("right_shoulder_armor"));

        scene.evidence.character_isolation_observed =
            !approximate(
                try scene.visual_scene.two_arm.attributeValue(movement_speed),
                try scene.visual_scene.four_arm.attributeValue(movement_speed),
            ) and
            try scene.visual_scene.two_arm.hasCapability(dash) and
            try scene.visual_scene.four_arm.hasCapability(double_jump);
    }
};

fn emptyIntent() input.CharacterIntent {
    return .{
        .move_axis = 0,
        .jump_pressed = false,
        .jump_held = false,
        .jump_released = false,
        .dash_pressed = false,
        .interact_pressed = false,
    };
}

fn moveIntent(axis: f32) input.CharacterIntent {
    var value = emptyIntent();
    value.move_axis = axis;
    return value;
}

fn jumpIntent() input.CharacterIntent {
    var value = emptyIntent();
    value.jump_pressed = true;
    value.jump_held = true;
    return value;
}

fn dashIntent(axis: f32) input.CharacterIntent {
    var value = moveIntent(axis);
    value.dash_pressed = true;
    return value;
}

fn approximate(left: f32, right: f32) bool {
    return @abs(left - right) <= 0.0001;
}
