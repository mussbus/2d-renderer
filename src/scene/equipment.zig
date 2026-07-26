const std = @import("std");
const math = @import("math");
const deformation = @import("deformation");
const secondary_motion = @import("attachment_secondary_motion");
const properties = @import("character_properties");
const skeleton = @import("skeleton");
const appearance = @import("appearance");
const anatomy = @import("anatomy");
const mesh = @import("deformable_mesh");

pub const maximum_equipment_slots: usize = 32;
pub const maximum_anatomy_roles: usize = 32;
pub const maximum_visual_layers: usize = 32;
pub const maximum_visual_components: usize = 96;
pub const maximum_item_definitions: usize = 96;
pub const maximum_attribute_definitions: usize = properties.maximum_attribute_definitions;
pub const maximum_capability_definitions: usize = properties.maximum_capability_definitions;
pub const maximum_item_references: usize = 512;
pub const maximum_visual_recipes: usize = 256;
pub const maximum_equipped_items: usize = 24;
pub const maximum_resolved_visuals: usize = 96;
pub const maximum_active_modifiers: usize = 96;
pub const maximum_active_capabilities: usize = 64;
pub const maximum_active_coverage: usize = 96;

pub const EquipmentSlotId = enum(u16) {
    _,

    pub fn index(id: EquipmentSlotId) usize {
        return @intFromEnum(id);
    }
};

pub const AnatomyRoleId = enum(u16) {
    _,

    pub fn index(id: AnatomyRoleId) usize {
        return @intFromEnum(id);
    }
};

pub const VisualLayerId = enum(u16) {
    _,

    pub fn index(id: VisualLayerId) usize {
        return @intFromEnum(id);
    }
};

pub const VisualComponentId = enum(u16) {
    _,

    pub fn index(id: VisualComponentId) usize {
        return @intFromEnum(id);
    }
};

pub const EquipmentItemId = enum(u16) {
    _,

    pub fn index(id: EquipmentItemId) usize {
        return @intFromEnum(id);
    }
};

pub const AttributeId = properties.AttributeId;
pub const CapabilityId = properties.CapabilityId;

pub const ItemVisualRecipeId = enum(u16) {
    _,

    pub fn index(id: ItemVisualRecipeId) usize {
        return @intFromEnum(id);
    }
};

pub const EquipmentSlotInput = struct {
    stable_id: []const u8,
};

pub const AnatomyRoleInput = struct {
    stable_id: []const u8,
    compatible_part_type: []const u8,
};

pub const VisualLayerInput = struct {
    stable_id: []const u8,
    render_layer: u16,
};

pub const AttributeDefinitionInput = properties.AttributeDefinitionInput;
pub const CapabilityDefinitionInput = properties.CapabilityDefinitionInput;

pub const VisualComponentInput = struct {
    stable_id: []const u8,
    sprite_size: math.Vec2,
    pivot: [2]f32 = .{ 0.5, 0.5 },
    uv_rect: [4]f32 = .{ 0, 0, 0.5, 0.5 },
    tint: [4]f32,
    texture_page: u32 = 0,
    deformation_response: deformation.Response = .{},
    secondary_motion: ?secondary_motion.Definition = null,
    primitive: VisualPrimitiveInput = .rigid_sprite,
};

pub const VisualPrimitiveInput = union(enum) {
    rigid_sprite,
    deformable_mesh: mesh.DefinitionView,
};

pub const MatchSelection = enum(u8) {
    first_compatible,
    every_compatible,
    specific_instance,
};

pub const AnatomyBindingInput = struct {
    role: []const u8,
    selection: MatchSelection,
    specific_instance: ?[]const u8 = null,
    required: bool = true,
    maximum_matches: u16,
};

pub const VisualBindingInput = union(enum) {
    anatomy: AnatomyBindingInput,
    attachment_point: []const u8,
};

pub const ItemVisualRecipeInput = struct {
    component: []const u8,
    binding: VisualBindingInput,
    local_to_binding: math.Transform2D = math.Transform2D.identity(),
    body_region: []const u8,
    visual_layer: []const u8,
};

pub const AttributeOperation = properties.AttributeOperation;

pub const AttributeModifierInput = struct {
    attribute: []const u8,
    operation: AttributeOperation,
    amount: f32,
};

pub const EquipmentItemInput = struct {
    stable_id: []const u8,
    occupied_slots: []const []const u8,
    visual_recipes: []const ItemVisualRecipeInput,
    covered_body_regions: []const []const u8,
    attribute_modifiers: []const AttributeModifierInput,
    capability_grants: []const []const u8,
};

pub const DefinitionInputs = struct {
    equipment_slots: []const EquipmentSlotInput,
    anatomy_roles: []const AnatomyRoleInput,
    visual_layers: []const VisualLayerInput,
    visual_components: []const VisualComponentInput,
    attributes: []const AttributeDefinitionInput,
    capabilities: []const CapabilityDefinitionInput,
    items: []const EquipmentItemInput,
    default_loadout: []const []const u8 = &.{},
};

pub const EquipmentSlot = struct {
    id: EquipmentSlotId,
    stable_id: skeleton.DebugName,
};

pub const AnatomyRole = struct {
    id: AnatomyRoleId,
    stable_id: skeleton.DebugName,
    compatible_part_type: skeleton.DebugName,
};

pub const VisualLayer = struct {
    id: VisualLayerId,
    stable_id: skeleton.DebugName,
    render_layer: u16,
};

pub const AttributeDefinition = properties.AttributeDefinition;
pub const CapabilityDefinition = properties.CapabilityDefinition;

pub const VisualComponent = struct {
    id: VisualComponentId,
    stable_id: skeleton.DebugName,
    sprite_size: math.Vec2,
    pivot: [2]f32,
    uv_rect: [4]f32,
    tint: [4]f32,
    texture_page: u32,
    deformation_response: deformation.Response,
    secondary_motion: ?secondary_motion.Definition,
    primitive: VisualPrimitive,
};

pub const VisualPrimitive = union(enum) {
    rigid_sprite,
    deformable_mesh: mesh.DefinitionView,
};

pub const AnatomyBinding = struct {
    role: AnatomyRoleId,
    selection: MatchSelection,
    specific_instance: ?anatomy.BodyPartInstanceId,
    required: bool,
    maximum_matches: u16,
};

pub const VisualBinding = union(enum) {
    anatomy: AnatomyBinding,
    attachment_point: appearance.AttachmentPointId,
};

pub const ItemVisualRecipe = struct {
    id: ItemVisualRecipeId,
    component: VisualComponentId,
    binding: VisualBinding,
    local_to_binding: math.Transform2D,
    body_region: appearance.BodyRegionId,
    visual_layer: VisualLayerId,
};

pub const AttributeModifier = struct {
    attribute: AttributeId,
    operation: AttributeOperation,
    amount: f32,
};

pub const EquipmentItem = struct {
    id: EquipmentItemId,
    stable_id: skeleton.DebugName,
    occupied_slot_start: u16,
    occupied_slot_count: u16,
    visual_recipe_start: u16,
    visual_recipe_count: u16,
    coverage_start: u16,
    coverage_count: u16,
    modifier_start: u16,
    modifier_count: u16,
    capability_start: u16,
    capability_count: u16,
};

pub const DefinitionView = struct {
    equipment_slots: []const EquipmentSlot,
    anatomy_roles: []const AnatomyRole,
    visual_layers: []const VisualLayer,
    visual_components: []const VisualComponent,
    attributes: []const AttributeDefinition,
    capabilities: []const CapabilityDefinition,
    items: []const EquipmentItem,
    occupied_slots: []const EquipmentSlotId,
    visual_recipes: []const ItemVisualRecipe,
    covered_body_regions: []const appearance.BodyRegionId,
    attribute_modifiers: []const AttributeModifier,
    capability_grants: []const CapabilityId,
    default_loadout: []const EquipmentItemId,
    anatomy_token: usize,
    appearance_token: usize,
    owner_token: usize,

    pub fn slotId(definition: DefinitionView, name: []const u8) !EquipmentSlotId {
        return findEquipmentSlot(definition.equipment_slots, name);
    }

    pub fn itemId(definition: DefinitionView, name: []const u8) !EquipmentItemId {
        return findEquipmentItem(definition.items, name);
    }

    pub fn attributeId(definition: DefinitionView, name: []const u8) !AttributeId {
        return findAttribute(definition.attributes, name);
    }

    pub fn visualComponentId(definition: DefinitionView, name: []const u8) !VisualComponentId {
        return findVisualComponent(definition.visual_components, name);
    }

    pub fn capabilityId(definition: DefinitionView, name: []const u8) !CapabilityId {
        return findCapability(definition.capabilities, name);
    }

    pub fn item(definition: DefinitionView, id: EquipmentItemId) !*const EquipmentItem {
        if (id.index() >= definition.items.len) return error.InvalidEquipmentItemId;
        return &definition.items[id.index()];
    }

    pub fn recipe(definition: DefinitionView, id: ItemVisualRecipeId) !*const ItemVisualRecipe {
        if (id.index() >= definition.visual_recipes.len) return error.InvalidVisualRecipeId;
        return &definition.visual_recipes[id.index()];
    }
};

pub const Definition = struct {
    allocator: std.mem.Allocator,
    equipment_slots: []const EquipmentSlot,
    anatomy_roles: []const AnatomyRole,
    visual_layers: []const VisualLayer,
    visual_components: []const VisualComponent,
    attributes: []const AttributeDefinition,
    capabilities: []const CapabilityDefinition,
    items: []const EquipmentItem,
    occupied_slots: []const EquipmentSlotId,
    visual_recipes: []const ItemVisualRecipe,
    covered_body_regions: []const appearance.BodyRegionId,
    attribute_modifiers: []const AttributeModifier,
    capability_grants: []const CapabilityId,
    default_loadout: []const EquipmentItemId,
    anatomy_token: usize,
    appearance_token: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        anatomy_definition: anatomy.DefinitionView,
        appearance_definition: appearance.DefinitionView,
        inputs: DefinitionInputs,
    ) !Definition {
        try validateInputCounts(inputs);

        const equipment_slots = allocator.alloc(EquipmentSlot, inputs.equipment_slots.len) catch return error.AllocationFailure;
        errdefer allocator.free(equipment_slots);
        for (inputs.equipment_slots, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(EquipmentSlot, equipment_slots[0..index], stable_id);
            equipment_slots[index] = .{ .id = @enumFromInt(index), .stable_id = stable_id };
        }

        const anatomy_roles = allocator.alloc(AnatomyRole, inputs.anatomy_roles.len) catch return error.AllocationFailure;
        errdefer allocator.free(anatomy_roles);
        for (inputs.anatomy_roles, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(AnatomyRole, anatomy_roles[0..index], stable_id);
            const compatible_part_type = try skeleton.DebugName.init(input.compatible_part_type);
            if (!anatomyHasPartType(anatomy_definition, compatible_part_type)) return error.MissingCompatibleAnatomyType;
            anatomy_roles[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .compatible_part_type = compatible_part_type,
            };
        }

        const visual_layers = allocator.alloc(VisualLayer, inputs.visual_layers.len) catch return error.AllocationFailure;
        errdefer allocator.free(visual_layers);
        for (inputs.visual_layers, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(VisualLayer, visual_layers[0..index], stable_id);
            visual_layers[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .render_layer = input.render_layer,
            };
        }

        const visual_components = allocator.alloc(VisualComponent, inputs.visual_components.len) catch return error.AllocationFailure;
        errdefer allocator.free(visual_components);
        for (inputs.visual_components, 0..) |input, index| {
            const primitive: VisualPrimitive = switch (input.primitive) {
                .rigid_sprite => rigid: {
                    if (!input.sprite_size.isFinite() or input.sprite_size.x <= 0 or input.sprite_size.y <= 0 or
                        !finiteArray(2, input.pivot) or !finiteArray(4, input.uv_rect) or
                        input.pivot[0] < 0 or input.pivot[0] > 1 or input.pivot[1] < 0 or input.pivot[1] > 1 or
                        input.uv_rect[0] < 0 or input.uv_rect[0] >= input.uv_rect[2] or input.uv_rect[2] > 1 or
                        input.uv_rect[1] < 0 or input.uv_rect[1] >= input.uv_rect[3] or input.uv_rect[3] > 1)
                    {
                        return error.InvalidVisualComponent;
                    }
                    break :rigid .rigid_sprite;
                },
                .deformable_mesh => |mesh_definition| deformable: {
                    try mesh_definition.validate();
                    if (mesh_definition.material.texture_page != input.texture_page or
                        !std.mem.eql(u8, std.mem.asBytes(&mesh_definition.material.tint), std.mem.asBytes(&input.tint)))
                    {
                        return error.MeshComponentMaterialMismatch;
                    }
                    break :deformable .{ .deformable_mesh = mesh_definition };
                },
            };
            if (!finiteArray(4, input.tint) or !normalizedArray(4, input.tint)) return error.InvalidVisualComponent;
            try input.deformation_response.validate();
            if (input.secondary_motion) |definition| try definition.validate();
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(VisualComponent, visual_components[0..index], stable_id);
            visual_components[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .sprite_size = input.sprite_size,
                .pivot = input.pivot,
                .uv_rect = input.uv_rect,
                .tint = input.tint,
                .texture_page = input.texture_page,
                .deformation_response = input.deformation_response,
                .secondary_motion = input.secondary_motion,
                .primitive = primitive,
            };
        }

        const attributes = allocator.alloc(AttributeDefinition, inputs.attributes.len) catch return error.AllocationFailure;
        errdefer allocator.free(attributes);
        for (inputs.attributes, 0..) |input, index| {
            try input.validate();
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(AttributeDefinition, attributes[0..index], stable_id);
            attributes[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .base_value = input.base_value,
                .minimum = input.minimum,
                .maximum = input.maximum,
            };
        }

        const capabilities = allocator.alloc(CapabilityDefinition, inputs.capabilities.len) catch return error.AllocationFailure;
        errdefer allocator.free(capabilities);
        for (inputs.capabilities, 0..) |input, index| {
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(CapabilityDefinition, capabilities[0..index], stable_id);
            capabilities[index] = .{
                .id = @enumFromInt(index),
                .stable_id = stable_id,
                .granted_by_default = input.granted_by_default,
            };
        }

        var occupied_slot_count: usize = 0;
        var visual_recipe_count: usize = 0;
        var coverage_count: usize = 0;
        var modifier_count: usize = 0;
        var capability_count: usize = 0;
        for (inputs.items) |input| {
            occupied_slot_count = try checkedAdd(occupied_slot_count, input.occupied_slots.len);
            visual_recipe_count = try checkedAdd(visual_recipe_count, input.visual_recipes.len);
            coverage_count = try checkedAdd(coverage_count, input.covered_body_regions.len);
            modifier_count = try checkedAdd(modifier_count, input.attribute_modifiers.len);
            capability_count = try checkedAdd(capability_count, input.capability_grants.len);
        }
        if (occupied_slot_count > maximum_item_references or coverage_count > maximum_item_references or
            modifier_count > maximum_item_references or capability_count > maximum_item_references or
            visual_recipe_count > maximum_visual_recipes)
        {
            return error.SupportedCountOverflow;
        }

        const items = allocator.alloc(EquipmentItem, inputs.items.len) catch return error.AllocationFailure;
        errdefer allocator.free(items);
        const occupied_slots = allocator.alloc(EquipmentSlotId, occupied_slot_count) catch return error.AllocationFailure;
        errdefer allocator.free(occupied_slots);
        const visual_recipes = allocator.alloc(ItemVisualRecipe, visual_recipe_count) catch return error.AllocationFailure;
        errdefer allocator.free(visual_recipes);
        const covered_body_regions = allocator.alloc(appearance.BodyRegionId, coverage_count) catch return error.AllocationFailure;
        errdefer allocator.free(covered_body_regions);
        const attribute_modifiers = allocator.alloc(AttributeModifier, modifier_count) catch return error.AllocationFailure;
        errdefer allocator.free(attribute_modifiers);
        const capability_grants = allocator.alloc(CapabilityId, capability_count) catch return error.AllocationFailure;
        errdefer allocator.free(capability_grants);

        var slot_cursor: usize = 0;
        var recipe_cursor: usize = 0;
        var coverage_cursor: usize = 0;
        var modifier_cursor: usize = 0;
        var capability_cursor: usize = 0;
        for (inputs.items, 0..) |input, item_index| {
            if (input.occupied_slots.len == 0 and input.visual_recipes.len == 0 and
                input.attribute_modifiers.len == 0 and input.capability_grants.len == 0)
            {
                return error.EmptyEquipmentItem;
            }
            const stable_id = try skeleton.DebugName.init(input.stable_id);
            try ensureUniqueName(EquipmentItem, items[0..item_index], stable_id);

            const slot_start = slot_cursor;
            for (input.occupied_slots) |name| {
                const slot_id = try findEquipmentSlot(equipment_slots, name);
                if (containsId(EquipmentSlotId, occupied_slots[slot_start..slot_cursor], slot_id)) return error.DuplicateItemSlot;
                occupied_slots[slot_cursor] = slot_id;
                slot_cursor += 1;
            }

            const recipe_start = recipe_cursor;
            for (input.visual_recipes) |recipe_input| {
                if (!recipe_input.local_to_binding.isFinite()) return error.NonFiniteTransform;
                const binding: VisualBinding = switch (recipe_input.binding) {
                    .attachment_point => |name| .{
                        .attachment_point = try findAttachmentPoint(appearance_definition.attachment_points, name),
                    },
                    .anatomy => |binding_input| binding: {
                        if (binding_input.maximum_matches == 0 or binding_input.maximum_matches > maximum_resolved_visuals) {
                            return error.InvalidMaximumMatches;
                        }
                        const role_id = try findAnatomyRole(anatomy_roles, binding_input.role);
                        const specific_instance = if (binding_input.specific_instance) |name|
                            try anatomy_definition.partInstanceId(name)
                        else
                            null;
                        switch (binding_input.selection) {
                            .first_compatible => {
                                if (specific_instance != null or binding_input.maximum_matches != 1) return error.InvalidBindingSelection;
                            },
                            .every_compatible => {
                                if (specific_instance != null) return error.InvalidBindingSelection;
                            },
                            .specific_instance => {
                                const part_id = specific_instance orelse return error.MissingSpecificAnatomyInstance;
                                if (!partMatchesRole(anatomy_definition, part_id, anatomy_roles[role_id.index()])) {
                                    return error.SpecificAnatomyRoleMismatch;
                                }
                                if (binding_input.maximum_matches != 1) return error.InvalidBindingSelection;
                            },
                        }
                        break :binding .{ .anatomy = .{
                            .role = role_id,
                            .selection = binding_input.selection,
                            .specific_instance = specific_instance,
                            .required = binding_input.required,
                            .maximum_matches = binding_input.maximum_matches,
                        } };
                    },
                };
                visual_recipes[recipe_cursor] = .{
                    .id = @enumFromInt(recipe_cursor),
                    .component = try findVisualComponent(visual_components, recipe_input.component),
                    .binding = binding,
                    .local_to_binding = recipe_input.local_to_binding,
                    .body_region = try findBodyRegion(appearance_definition.body_regions, recipe_input.body_region),
                    .visual_layer = try findVisualLayer(visual_layers, recipe_input.visual_layer),
                };
                recipe_cursor += 1;
            }

            const coverage_start = coverage_cursor;
            for (input.covered_body_regions) |name| {
                const region_id = try findBodyRegion(appearance_definition.body_regions, name);
                if (containsId(appearance.BodyRegionId, covered_body_regions[coverage_start..coverage_cursor], region_id)) {
                    return error.DuplicateCoveredBodyRegion;
                }
                covered_body_regions[coverage_cursor] = region_id;
                coverage_cursor += 1;
            }

            const modifier_start = modifier_cursor;
            for (input.attribute_modifiers) |modifier_input| {
                try properties.validateModifierAmount(modifier_input.operation, modifier_input.amount);
                const attribute_id = try findAttribute(attributes, modifier_input.attribute);
                for (attribute_modifiers[modifier_start..modifier_cursor]) |existing| {
                    if (existing.attribute == attribute_id and existing.operation == modifier_input.operation) {
                        return error.DuplicateAttributeModifier;
                    }
                }
                attribute_modifiers[modifier_cursor] = .{
                    .attribute = attribute_id,
                    .operation = modifier_input.operation,
                    .amount = modifier_input.amount,
                };
                modifier_cursor += 1;
            }

            const capability_start = capability_cursor;
            for (input.capability_grants) |name| {
                const capability_id = try findCapability(capabilities, name);
                if (containsId(CapabilityId, capability_grants[capability_start..capability_cursor], capability_id)) {
                    return error.DuplicateCapabilityGrant;
                }
                capability_grants[capability_cursor] = capability_id;
                capability_cursor += 1;
            }

            items[item_index] = .{
                .id = @enumFromInt(item_index),
                .stable_id = stable_id,
                .occupied_slot_start = @intCast(slot_start),
                .occupied_slot_count = @intCast(input.occupied_slots.len),
                .visual_recipe_start = @intCast(recipe_start),
                .visual_recipe_count = @intCast(input.visual_recipes.len),
                .coverage_start = @intCast(coverage_start),
                .coverage_count = @intCast(input.covered_body_regions.len),
                .modifier_start = @intCast(modifier_start),
                .modifier_count = @intCast(input.attribute_modifiers.len),
                .capability_start = @intCast(capability_start),
                .capability_count = @intCast(input.capability_grants.len),
            };
        }

        const default_loadout = allocator.alloc(EquipmentItemId, inputs.default_loadout.len) catch return error.AllocationFailure;
        errdefer allocator.free(default_loadout);
        var default_occupied = [_]bool{false} ** maximum_equipment_slots;
        for (inputs.default_loadout, 0..) |name, index| {
            const item_id = try findEquipmentItem(items, name);
            if (containsId(EquipmentItemId, default_loadout[0..index], item_id)) return error.DuplicateDefaultItem;
            const item = items[item_id.index()];
            for (occupied_slots[item.occupied_slot_start .. item.occupied_slot_start + item.occupied_slot_count]) |slot_id| {
                if (default_occupied[slot_id.index()]) return error.DefaultLoadoutSlotConflict;
                default_occupied[slot_id.index()] = true;
            }
            default_loadout[index] = item_id;
        }

        return .{
            .allocator = allocator,
            .equipment_slots = equipment_slots,
            .anatomy_roles = anatomy_roles,
            .visual_layers = visual_layers,
            .visual_components = visual_components,
            .attributes = attributes,
            .capabilities = capabilities,
            .items = items,
            .occupied_slots = occupied_slots,
            .visual_recipes = visual_recipes,
            .covered_body_regions = covered_body_regions,
            .attribute_modifiers = attribute_modifiers,
            .capability_grants = capability_grants,
            .default_loadout = default_loadout,
            .anatomy_token = anatomy_definition.owner_token,
            .appearance_token = appearance_definition.owner_token,
        };
    }

    pub fn deinit(definition: *Definition) void {
        definition.allocator.free(definition.default_loadout);
        definition.allocator.free(definition.capability_grants);
        definition.allocator.free(definition.attribute_modifiers);
        definition.allocator.free(definition.covered_body_regions);
        definition.allocator.free(definition.visual_recipes);
        definition.allocator.free(definition.occupied_slots);
        definition.allocator.free(definition.items);
        definition.allocator.free(definition.capabilities);
        definition.allocator.free(definition.attributes);
        definition.allocator.free(definition.visual_components);
        definition.allocator.free(definition.visual_layers);
        definition.allocator.free(definition.anatomy_roles);
        definition.allocator.free(definition.equipment_slots);
        definition.* = undefined;
    }

    pub fn view(definition: *const Definition) DefinitionView {
        return .{
            .equipment_slots = definition.equipment_slots,
            .anatomy_roles = definition.anatomy_roles,
            .visual_layers = definition.visual_layers,
            .visual_components = definition.visual_components,
            .attributes = definition.attributes,
            .capabilities = definition.capabilities,
            .items = definition.items,
            .occupied_slots = definition.occupied_slots,
            .visual_recipes = definition.visual_recipes,
            .covered_body_regions = definition.covered_body_regions,
            .attribute_modifiers = definition.attribute_modifiers,
            .capability_grants = definition.capability_grants,
            .default_loadout = definition.default_loadout,
            .anatomy_token = definition.anatomy_token,
            .appearance_token = definition.appearance_token,
            .owner_token = @intFromPtr(definition.items.ptr),
        };
    }

    pub fn slotId(definition: *const Definition, name: []const u8) !EquipmentSlotId {
        return findEquipmentSlot(definition.equipment_slots, name);
    }

    pub fn itemId(definition: *const Definition, name: []const u8) !EquipmentItemId {
        return findEquipmentItem(definition.items, name);
    }

    pub fn attributeId(definition: *const Definition, name: []const u8) !AttributeId {
        return findAttribute(definition.attributes, name);
    }

    pub fn visualComponentId(definition: *const Definition, name: []const u8) !VisualComponentId {
        return findVisualComponent(definition.visual_components, name);
    }

    pub fn capabilityId(definition: *const Definition, name: []const u8) !CapabilityId {
        return findCapability(definition.capabilities, name);
    }
};

pub const AnatomyContext = struct {
    definition: anatomy.DefinitionView,
    runtime: *const anatomy.Runtime,
    owning_character: u32 = 0,
};

pub const VisualSource = union(enum) {
    anatomy_part: anatomy.BodyPartInstanceId,
    attachment_point: appearance.AttachmentPointId,
};

pub const ResolvedVisualInstance = struct {
    item: EquipmentItemId,
    recipe: ItemVisualRecipeId,
    source: VisualSource,
    body_region: appearance.BodyRegionId,
    owning_character: u32,
    mesh_state: mesh.InstanceState = .{},
    secondary: secondary_motion.RuntimeState = .{},
};

pub const ActiveModifier = struct {
    item: EquipmentItemId,
    source_ordinal: u16,
    attribute: AttributeId,
    operation: AttributeOperation,
    amount: f32,
};

pub const ActiveCapability = struct {
    item: EquipmentItemId,
    capability: CapabilityId,
};

pub const ActiveCoverage = struct {
    item: EquipmentItemId,
    body_region: appearance.BodyRegionId,
};

pub const Loadout = struct {
    definition: DefinitionView,
    owning_character: u32,
    equipped_items: [maximum_equipped_items]EquipmentItemId = undefined,
    equipped_count: u16 = 0,
    slot_occupants: [maximum_equipment_slots]?EquipmentItemId = [_]?EquipmentItemId{null} ** maximum_equipment_slots,
    resolved_visuals: [maximum_resolved_visuals]ResolvedVisualInstance = undefined,
    resolved_visual_count: u16 = 0,
    active_modifiers: [maximum_active_modifiers]ActiveModifier = undefined,
    active_modifier_count: u16 = 0,
    active_capabilities: [maximum_active_capabilities]ActiveCapability = undefined,
    active_capability_count: u16 = 0,
    active_coverage: [maximum_active_coverage]ActiveCoverage = undefined,
    active_coverage_count: u16 = 0,

    pub fn init(definition: DefinitionView, context: AnatomyContext) !Loadout {
        var loadout = Loadout{ .definition = definition, .owning_character = context.owning_character };
        try loadout.resetToDefault(context);
        return loadout;
    }

    pub fn validateCompatibility(loadout: *const Loadout, context: AnatomyContext) !void {
        if (loadout.definition.anatomy_token != context.definition.owner_token) return error.EquipmentAnatomyDefinitionMismatch;
        if (context.owning_character != 0 and loadout.owning_character != context.owning_character) {
            return error.EquipmentCharacterOwnerMismatch;
        }
        try context.runtime.validateCompatibility(context.definition);
        if (loadout.definition.equipment_slots.len > maximum_equipment_slots) return error.EquipmentSlotCapacityExceeded;
    }

    pub fn equip(loadout: *Loadout, context: AnatomyContext, item_id: EquipmentItemId) !void {
        var candidate = loadout.*;
        try candidate.validateCompatibility(context);
        try candidate.insertItem(item_id, false);
        try candidate.rebuildDerived(context);
        loadout.* = candidate;
    }

    pub fn replace(loadout: *Loadout, context: AnatomyContext, item_id: EquipmentItemId) !void {
        var candidate = loadout.*;
        try candidate.validateCompatibility(context);
        const item = try candidate.definition.item(item_id);
        if (candidate.isEquipped(item_id)) return error.ItemAlreadyEquipped;
        var conflicts = [_]bool{false} ** maximum_item_definitions;
        for (candidate.definition.occupied_slots[item.occupied_slot_start .. item.occupied_slot_start + item.occupied_slot_count]) |slot_id| {
            if (candidate.slot_occupants[slot_id.index()]) |occupant| conflicts[occupant.index()] = true;
        }
        var index: usize = @intCast(candidate.equipped_count);
        while (index > 0) {
            index -= 1;
            const equipped_id = candidate.equipped_items[index];
            if (conflicts[equipped_id.index()]) candidate.removeAt(index);
        }
        try candidate.insertItem(item_id, true);
        try candidate.rebuildDerived(context);
        loadout.* = candidate;
    }

    pub fn unequip(loadout: *Loadout, context: AnatomyContext, item_id: EquipmentItemId) !void {
        var candidate = loadout.*;
        try candidate.validateCompatibility(context);
        _ = try candidate.definition.item(item_id);
        const index = candidate.equippedIndex(item_id) orelse return error.ItemNotEquipped;
        candidate.removeAt(index);
        try candidate.rebuildDerived(context);
        loadout.* = candidate;
    }

    pub fn resetToDefault(loadout: *Loadout, context: AnatomyContext) !void {
        var candidate = Loadout{ .definition = loadout.definition, .owning_character = context.owning_character };
        try candidate.validateCompatibility(context);
        for (candidate.definition.default_loadout) |item_id| try candidate.insertItem(item_id, false);
        try candidate.rebuildDerived(context);
        loadout.* = candidate;
    }

    pub fn rebind(loadout: *Loadout, context: AnatomyContext) !void {
        var candidate = loadout.*;
        try candidate.validateCompatibility(context);
        try candidate.rebuildDerived(context);
        loadout.* = candidate;
    }

    pub fn itemInSlot(loadout: *const Loadout, slot_id: EquipmentSlotId) !?EquipmentItemId {
        if (slot_id.index() >= loadout.definition.equipment_slots.len) return error.InvalidEquipmentSlotId;
        return loadout.slot_occupants[slot_id.index()];
    }

    pub fn equippedDefinition(loadout: *const Loadout, item_id: EquipmentItemId) !?*const EquipmentItem {
        const item = try loadout.definition.item(item_id);
        return if (loadout.isEquipped(item_id)) item else null;
    }

    pub fn isEquipped(loadout: *const Loadout, item_id: EquipmentItemId) bool {
        return loadout.equippedIndex(item_id) != null;
    }

    pub fn equippedItems(loadout: *const Loadout) []const EquipmentItemId {
        return loadout.equipped_items[0..loadout.equipped_count];
    }

    pub fn visuals(loadout: *const Loadout) []const ResolvedVisualInstance {
        return loadout.resolved_visuals[0..loadout.resolved_visual_count];
    }

    pub fn modifiers(loadout: *const Loadout) []const ActiveModifier {
        return loadout.active_modifiers[0..loadout.active_modifier_count];
    }

    pub fn capabilities(loadout: *const Loadout) []const ActiveCapability {
        return loadout.active_capabilities[0..loadout.active_capability_count];
    }

    pub fn coverage(loadout: *const Loadout) []const ActiveCoverage {
        return loadout.active_coverage[0..loadout.active_coverage_count];
    }

    pub fn hasCapability(loadout: *const Loadout, capability_id: CapabilityId) bool {
        for (loadout.capabilities()) |grant| {
            if (grant.capability == capability_id) return true;
        }
        return false;
    }

    pub fn coversRegion(loadout: *const Loadout, region_id: appearance.BodyRegionId) bool {
        for (loadout.coverage()) |entry| {
            if (entry.body_region == region_id) return true;
        }
        return false;
    }

    fn insertItem(loadout: *Loadout, item_id: EquipmentItemId, replacement: bool) !void {
        const item = try loadout.definition.item(item_id);
        if (loadout.isEquipped(item_id)) return error.ItemAlreadyEquipped;
        if (loadout.equipped_count >= maximum_equipped_items) return error.EquippedItemCapacityExceeded;
        if (!replacement) {
            for (loadout.definition.occupied_slots[item.occupied_slot_start .. item.occupied_slot_start + item.occupied_slot_count]) |slot_id| {
                if (loadout.slot_occupants[slot_id.index()] != null) return error.EquipmentSlotOccupied;
            }
        }
        var destination: usize = @intCast(loadout.equipped_count);
        while (destination > 0 and item_id.index() < loadout.equipped_items[destination - 1].index()) : (destination -= 1) {
            loadout.equipped_items[destination] = loadout.equipped_items[destination - 1];
        }
        loadout.equipped_items[destination] = item_id;
        loadout.equipped_count += 1;
    }

    fn removeAt(loadout: *Loadout, index: usize) void {
        var cursor = index;
        while (cursor + 1 < loadout.equipped_count) : (cursor += 1) {
            loadout.equipped_items[cursor] = loadout.equipped_items[cursor + 1];
        }
        loadout.equipped_count -= 1;
    }

    fn equippedIndex(loadout: *const Loadout, item_id: EquipmentItemId) ?usize {
        for (loadout.equipped_items[0..loadout.equipped_count], 0..) |equipped_id, index| {
            if (equipped_id == item_id) return index;
        }
        return null;
    }

    fn rebuildDerived(loadout: *Loadout, context: AnatomyContext) !void {
        try loadout.validateCompatibility(context);
        loadout.slot_occupants = [_]?EquipmentItemId{null} ** maximum_equipment_slots;
        for (loadout.resolved_visuals[0..loadout.resolved_visual_count]) |*visual| {
            visual.secondary.clear();
            visual.mesh_state = .{};
        }
        loadout.resolved_visual_count = 0;
        loadout.active_modifier_count = 0;
        loadout.active_capability_count = 0;
        loadout.active_coverage_count = 0;

        var previous_item_index: ?usize = null;
        for (loadout.equipped_items[0..loadout.equipped_count]) |item_id| {
            if (previous_item_index) |previous| {
                if (item_id.index() <= previous) return error.NonDeterministicEquippedItemOrder;
            }
            previous_item_index = item_id.index();
            const item = try loadout.definition.item(item_id);

            for (loadout.definition.occupied_slots[item.occupied_slot_start .. item.occupied_slot_start + item.occupied_slot_count]) |slot_id| {
                if (loadout.slot_occupants[slot_id.index()] != null) return error.EquipmentSlotOccupied;
                loadout.slot_occupants[slot_id.index()] = item_id;
            }

            for (loadout.definition.visual_recipes[item.visual_recipe_start .. item.visual_recipe_start + item.visual_recipe_count]) |recipe| {
                try loadout.expandRecipe(context, item_id, recipe);
            }

            for (loadout.definition.covered_body_regions[item.coverage_start .. item.coverage_start + item.coverage_count]) |region_id| {
                if (loadout.active_coverage_count >= maximum_active_coverage) return error.ActiveCoverageCapacityExceeded;
                loadout.active_coverage[loadout.active_coverage_count] = .{ .item = item_id, .body_region = region_id };
                loadout.active_coverage_count += 1;
            }

            for (
                loadout.definition.attribute_modifiers[item.modifier_start .. item.modifier_start + item.modifier_count],
                0..,
            ) |modifier, source_ordinal| {
                if (loadout.active_modifier_count >= maximum_active_modifiers) return error.ActiveModifierCapacityExceeded;
                loadout.active_modifiers[loadout.active_modifier_count] = .{
                    .item = item_id,
                    .source_ordinal = @intCast(source_ordinal),
                    .attribute = modifier.attribute,
                    .operation = modifier.operation,
                    .amount = modifier.amount,
                };
                loadout.active_modifier_count += 1;
            }

            for (loadout.definition.capability_grants[item.capability_start .. item.capability_start + item.capability_count]) |capability_id| {
                if (loadout.active_capability_count >= maximum_active_capabilities) return error.ActiveCapabilityCapacityExceeded;
                loadout.active_capabilities[loadout.active_capability_count] = .{
                    .item = item_id,
                    .capability = capability_id,
                };
                loadout.active_capability_count += 1;
            }
        }
    }

    fn expandRecipe(
        loadout: *Loadout,
        context: AnatomyContext,
        item_id: EquipmentItemId,
        recipe: ItemVisualRecipe,
    ) !void {
        switch (recipe.binding) {
            .attachment_point => |attachment_point| try loadout.appendVisual(item_id, recipe.id, .{
                .attachment_point = attachment_point,
            }, recipe.body_region),
            .anatomy => |binding| {
                const role = loadout.definition.anatomy_roles[binding.role.index()];
                var matches: u16 = 0;
                if (binding.selection == .specific_instance) {
                    const part_id = binding.specific_instance orelse return error.MissingSpecificAnatomyInstance;
                    if (try context.runtime.isPartActive(context.definition, part_id) and partMatchesRole(context.definition, part_id, role)) {
                        matches = 1;
                        try loadout.appendVisual(
                            item_id,
                            recipe.id,
                            .{ .anatomy_part = part_id },
                            context.definition.part_instances[part_id.index()].body_region,
                        );
                    }
                } else {
                    for (context.definition.part_instances) |part| {
                        if (!try context.runtime.isPartActive(context.definition, part.id)) continue;
                        if (!partMatchesRole(context.definition, part.id, role)) continue;
                        matches += 1;
                        if (matches > binding.maximum_matches) return error.CompatiblePartExpansionExceeded;
                        try loadout.appendVisual(item_id, recipe.id, .{ .anatomy_part = part.id }, part.body_region);
                        if (binding.selection == .first_compatible) break;
                    }
                }
                if (matches == 0 and binding.required) return error.MissingRequiredAnatomy;
                if (matches > binding.maximum_matches) return error.CompatiblePartExpansionExceeded;
            },
        }
    }

    fn appendVisual(
        loadout: *Loadout,
        item_id: EquipmentItemId,
        recipe_id: ItemVisualRecipeId,
        source: VisualSource,
        body_region: appearance.BodyRegionId,
    ) !void {
        if (loadout.resolved_visual_count >= maximum_resolved_visuals) return error.ResolvedVisualCapacityExceeded;
        loadout.resolved_visuals[loadout.resolved_visual_count] = .{
            .item = item_id,
            .recipe = recipe_id,
            .source = source,
            .body_region = body_region,
            .owning_character = loadout.owning_character,
        };
        loadout.resolved_visual_count += 1;
    }
};

fn validateInputCounts(inputs: DefinitionInputs) !void {
    if (inputs.equipment_slots.len == 0 or inputs.equipment_slots.len > maximum_equipment_slots or
        inputs.anatomy_roles.len == 0 or inputs.anatomy_roles.len > maximum_anatomy_roles or
        inputs.visual_layers.len == 0 or inputs.visual_layers.len > maximum_visual_layers or
        inputs.visual_components.len == 0 or inputs.visual_components.len > maximum_visual_components or
        inputs.items.len == 0 or inputs.items.len > maximum_item_definitions or
        inputs.attributes.len > maximum_attribute_definitions or
        inputs.capabilities.len > maximum_capability_definitions or
        inputs.default_loadout.len > maximum_equipped_items)
    {
        return error.SupportedCountOverflow;
    }
}

fn checkedAdd(left: usize, right: usize) !usize {
    return std.math.add(usize, left, right) catch return error.SupportedCountOverflow;
}

fn finiteArray(comptime count: usize, values: [count]f32) bool {
    for (values) |value| {
        if (!std.math.isFinite(value)) return false;
    }
    return true;
}

fn normalizedArray(comptime count: usize, values: [count]f32) bool {
    for (values) |value| {
        if (value < 0 or value > 1) return false;
    }
    return true;
}

fn ensureUniqueName(comptime T: type, values: []const T, candidate: skeleton.DebugName) !void {
    for (values) |*value| {
        if (candidate.eql(&value.stable_id)) return error.DuplicateStableIdentifier;
    }
}

fn containsId(comptime T: type, values: []const T, candidate: T) bool {
    for (values) |value| {
        if (value == candidate) return true;
    }
    return false;
}

fn nameEquals(name: *const skeleton.DebugName, text: []const u8) bool {
    return std.mem.eql(u8, name.slice(), text);
}

fn findEquipmentSlot(values: []const EquipmentSlot, name: []const u8) !EquipmentSlotId {
    for (values) |value| {
        if (nameEquals(&value.stable_id, name)) return value.id;
    }
    return error.MissingEquipmentSlotReference;
}

fn findAnatomyRole(values: []const AnatomyRole, name: []const u8) !AnatomyRoleId {
    for (values) |value| {
        if (nameEquals(&value.stable_id, name)) return value.id;
    }
    return error.MissingAnatomyRoleReference;
}

fn findVisualLayer(values: []const VisualLayer, name: []const u8) !VisualLayerId {
    for (values) |value| {
        if (nameEquals(&value.stable_id, name)) return value.id;
    }
    return error.MissingVisualLayerReference;
}

fn findVisualComponent(values: []const VisualComponent, name: []const u8) !VisualComponentId {
    for (values) |value| {
        if (nameEquals(&value.stable_id, name)) return value.id;
    }
    return error.MissingVisualComponentReference;
}

fn findEquipmentItem(values: []const EquipmentItem, name: []const u8) !EquipmentItemId {
    for (values) |value| {
        if (nameEquals(&value.stable_id, name)) return value.id;
    }
    return error.MissingEquipmentItemReference;
}

fn findAttribute(values: []const AttributeDefinition, name: []const u8) !AttributeId {
    for (values) |value| {
        if (nameEquals(&value.stable_id, name)) return value.id;
    }
    return error.MissingAttributeReference;
}

fn findCapability(values: []const CapabilityDefinition, name: []const u8) !CapabilityId {
    for (values) |value| {
        if (nameEquals(&value.stable_id, name)) return value.id;
    }
    return error.MissingCapabilityReference;
}

fn findAttachmentPoint(values: []const appearance.AttachmentPoint, name: []const u8) !appearance.AttachmentPointId {
    for (values) |value| {
        if (nameEquals(&value.debug_name, name)) return value.id;
    }
    return error.MissingAttachmentPointReference;
}

fn findBodyRegion(values: []const appearance.BodyRegion, name: []const u8) !appearance.BodyRegionId {
    for (values) |value| {
        if (nameEquals(&value.debug_name, name)) return value.id;
    }
    return error.MissingBodyRegionReference;
}

fn anatomyHasPartType(definition: anatomy.DefinitionView, part_type: skeleton.DebugName) bool {
    for (definition.part_definitions) |part_definition| {
        if (part_definition.type_tag.eql(&part_type)) return true;
    }
    return false;
}

fn partMatchesRole(
    definition: anatomy.DefinitionView,
    part_id: anatomy.BodyPartInstanceId,
    role: AnatomyRole,
) bool {
    if (part_id.index() >= definition.part_instances.len) return false;
    const part = definition.part_instances[part_id.index()];
    if (part.definition.index() >= definition.part_definitions.len) return false;
    return definition.part_definitions[part.definition.index()].type_tag.eql(&role.compatible_part_type);
}
