const std = @import("std");
const humanoid = @import("humanoid");
const modular_humanoid = @import("modular_humanoid");
const authored = @import("authored_clips");
const character = @import("character");
const sprite = @import("sprite_batch");
const fault_injection = @import("fault_injection");

pub const required_frames: u32 = 240;
pub const character_count: usize = 3;

pub const Scene = struct {
    definition: humanoid.HumanoidDefinition,
    shared_animations: authored.Definitions,
    id_allocator: character.EntityIdAllocator,
    conventional_male: character.CharacterInstance,
    conventional_female: character.CharacterInstance,
    nonstandard: character.CharacterInstance,
    initial_topology: [character_count]u64,
    presentation_switches: u8 = 0,
    hair_switches: u8 = 0,
    total_visual_ticks: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        return initWithInjector(allocator, null);
    }

    fn initWithInjector(allocator: std.mem.Allocator, injector: ?fault_injection.Injector) !Scene {
        var definition = try modular_humanoid.initDefinitionWithInjector(
            allocator,
            injector,
            .standard,
        );
        errdefer definition.deinit();
        var shared_animations = try authored.Definitions.init(allocator, &definition.skeleton_definition, null);
        errdefer shared_animations.deinit();

        var id_allocator = character.EntityIdAllocator{};
        var male = try character.CharacterInstance.init(
            allocator,
            try id_allocator.allocate(),
            &definition,
            &shared_animations,
            .{ .x = -2.4, .y = 1.05 },
            .right,
            0,
            injector,
        );
        errdefer male.deinit();
        var female = try character.CharacterInstance.init(
            allocator,
            try id_allocator.allocate(),
            &definition,
            &shared_animations,
            .{ .x = 0, .y = 1.05 },
            .right,
            1,
            null,
        );
        errdefer female.deinit();
        var unusual = try character.CharacterInstance.init(
            allocator,
            try id_allocator.allocate(),
            &definition,
            &shared_animations,
            .{ .x = 2.4, .y = 1.05 },
            .left,
            2,
            null,
        );
        errdefer unusual.deinit();

        const anatomy_definition = if (definition.anatomy_definition) |*value| value.view() else return error.ModularBodyDefinitionMissing;
        try male.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_male"));
        try female.selectBodyPreset(try anatomy_definition.bodyPresetId("conventional_female"));
        try unusual.selectBodyPreset(try anatomy_definition.bodyPresetId("nonstandard_humanoid"));
        try male.setGlobalBuild(15);
        try female.setGlobalBuild(50);
        try unusual.setGlobalBuild(85);
        try female.setMorphologyChannelOverride(try anatomy_definition.morphologyChannelId("hip_width"), 80);
        try unusual.setPartMorphologyOverride(
            try anatomy_definition.partInstanceId("tail"),
            try anatomy_definition.morphologyChannelId("tail_thickness"),
            100,
        );

        const initial_topology = .{
            try topologyFingerprint(&male),
            try topologyFingerprint(&female),
            try topologyFingerprint(&unusual),
        };
        return .{
            .definition = definition,
            .shared_animations = shared_animations,
            .id_allocator = id_allocator,
            .conventional_male = male,
            .conventional_female = female,
            .nonstandard = unusual,
            .initial_topology = initial_topology,
        };
    }

    pub fn deinit(scene: *Scene) void {
        scene.nonstandard.deinit();
        scene.conventional_female.deinit();
        scene.conventional_male.deinit();
        scene.shared_animations.deinit();
        scene.definition.deinit();
        scene.* = undefined;
    }

    pub fn updateFrame(scene: *Scene, frame: u32) !void {
        const anatomy_definition = if (scene.definition.anatomy_definition) |*value| value.view() else return error.ModularBodyDefinitionMissing;
        if (frame == 80) {
            const profile = try anatomy_definition.presentationProfileId("modest");
            try scene.conventional_male.selectPresentationProfile(profile);
            try scene.conventional_female.selectPresentationProfile(profile);
            try scene.nonstandard.selectPresentationProfile(profile);
            scene.presentation_switches += 1;
        }
        if (frame == 120) {
            try scene.nonstandard.selectHair(try anatomy_definition.hairDefinitionId("short_rigid"));
            scene.hair_switches += 1;
        }
        if (frame == 160) {
            const profile = try anatomy_definition.presentationProfileId("adult_detailed");
            try scene.conventional_male.selectPresentationProfile(profile);
            try scene.conventional_female.selectPresentationProfile(profile);
            try scene.nonstandard.selectPresentationProfile(profile);
            try scene.nonstandard.selectHair(try anatomy_definition.hairDefinitionId("ponytail"));
            scene.presentation_switches += 1;
            scene.hair_switches += 1;
        }

        const instances = [_]*character.CharacterInstance{
            &scene.conventional_male,
            &scene.conventional_female,
            &scene.nonstandard,
        };
        for (0..4) |_| {
            for (instances) |instance| {
                try instance.advanceVisualTick(.{});
                scene.total_visual_ticks += 1;
            }
        }
    }

    pub fn submit(scene: *Scene, batch: *sprite.SpriteBatch) !u32 {
        const instances = [_]*character.CharacterInstance{
            &scene.conventional_male,
            &scene.conventional_female,
            &scene.nonstandard,
        };
        return character.submitGlobally(&instances, batch);
    }

    pub fn validateComplete(scene: *const Scene) !void {
        if (scene.presentation_switches != 2 or scene.hair_switches != 2) return error.ModularBodyEvidenceIncomplete;
        if (scene.total_visual_ticks != @as(u64, required_frames) * character_count * 4) return error.ModularBodyTickCountMismatch;
        const instances = [_]*const character.CharacterInstance{
            &scene.conventional_male,
            &scene.conventional_female,
            &scene.nonstandard,
        };
        for (instances, scene.initial_topology) |instance, initial| {
            if (try topologyFingerprint(instance) != initial) return error.PresentationChangedAnatomyTopology;
        }
        const anatomy_definition = scene.definition.anatomy_definition.?.view();
        if (anatomy_definition.faces.len < 2) return error.DistinctFaceDefinitionsMissing;
        const male_runtime = scene.conventional_male.character.anatomy_runtime.?;
        const female_runtime = scene.conventional_female.character.anatomy_runtime.?;
        for ([_][]const u8{ "left_eye", "right_eye", "left_eyebrow", "right_eyebrow", "nose", "mouth", "left_ear", "right_ear" }) |name| {
            const part_id = try anatomy_definition.partInstanceId(name);
            if (!try male_runtime.isPartActive(anatomy_definition, part_id) or
                try female_runtime.isPartActive(anatomy_definition, part_id))
            {
                return error.DistinctFaceSelectionIncorrect;
            }
        }
        for ([_][]const u8{ "angular_left_eye", "angular_right_eye", "angular_left_eyebrow", "angular_right_eyebrow", "angular_nose", "angular_mouth", "angular_left_ear", "angular_right_ear" }) |name| {
            const part_id = try anatomy_definition.partInstanceId(name);
            if (try male_runtime.isPartActive(anatomy_definition, part_id) or
                !try female_runtime.isPartActive(anatomy_definition, part_id))
            {
                return error.DistinctFaceSelectionIncorrect;
            }
        }
        for ([_][]const u8{ "eyebrows", "angular_eyebrows" }) |name| {
            const part_id = try anatomy_definition.partInstanceId(name);
            if (try male_runtime.isPartActive(anatomy_definition, part_id) or
                try female_runtime.isPartActive(anatomy_definition, part_id))
            {
                return error.LegacyCombinedEyebrowSelected;
            }
        }
        const appearance_definition = scene.definition.visual_definition.view();
        const conventional_eye_id = try scene.definition.visual_definition.visualId("left_eye");
        const angular_eye_id = try scene.definition.visual_definition.visualId("angular_left_eye");
        if (!try scene.conventional_male.character.appearance_runtime.isVisible(appearance_definition, conventional_eye_id) or
            try scene.conventional_male.character.appearance_runtime.isVisible(appearance_definition, angular_eye_id) or
            try scene.conventional_female.character.appearance_runtime.isVisible(appearance_definition, conventional_eye_id) or
            !try scene.conventional_female.character.appearance_runtime.isVisible(appearance_definition, angular_eye_id))
        {
            return error.DistinctFaceVisualSelectionIncorrect;
        }
        const conventional_eye = appearance_definition.visuals[conventional_eye_id.index()];
        const angular_eye = appearance_definition.visuals[angular_eye_id.index()];
        if (conventional_eye.local_to_source.approxEqAbs(angular_eye.local_to_source, 0) and
            conventional_eye.sprite_size.approxEqAbs(angular_eye.sprite_size, 0))
        {
            return error.DistinctFaceVisualDataMissing;
        }
        const unusual_runtime = scene.nonstandard.character.anatomy_runtime.?;
        for ([_][]const u8{ "extra_arm", "extra_arm_second", "tail", "left_horn", "right_horn" }) |name| {
            if (!try unusual_runtime.isPartActive(anatomy_definition, try anatomy_definition.partInstanceId(name))) {
                return error.NonstandardAnatomyMissing;
            }
        }
    }
};

pub fn runFaultInjectionChecks(allocator: std.mem.Allocator) !void {
    for (fault_injection.anatomy_initialization_stages) |stage| {
        var attempt = Scene.initWithInjector(allocator, .{ .fail_after = stage }) catch |err| {
            if (err != error.InjectedInitializationFailure) return err;
            var clean = try Scene.init(allocator);
            clean.deinit();
            std.log.info("modular-body fault-injection cleanup check passed after {s}", .{@tagName(stage)});
            continue;
        };
        attempt.deinit();
        return error.FaultInjectionDidNotTrigger;
    }
}

fn topologyFingerprint(instance: *const character.CharacterInstance) !u64 {
    const definition = instance.definition.anatomy_definition orelse return error.CharacterHasNoAnatomy;
    const runtime = instance.character.anatomy_runtime orelse return error.CharacterHasNoAnatomy;
    return runtime.topologyFingerprint(definition);
}
