const std = @import("std");

pub const EventType = enum(u8) {
    left_foot_contact,
    right_foot_contact,
    hand_contact,
    hand_release,
    interaction_complete,
    body_part_layer_change,
};

pub const LayerRestoration = enum(u8) {
    retain,
    restore_authored,
};

pub const LayerChangePayloadInput = extern struct {
    attachment_semantic: u8 = 0,
    requested_layer: u16 = 0,
    restoration: u8 = @intFromEnum(LayerRestoration.retain),
};

pub const LayerChangePayload = extern struct {
    attachment_semantic: u8,
    requested_layer: u16,
    restoration: LayerRestoration,
};

pub const EventInput = struct {
    id: u16,
    timestamp: f32,
    event_type: u8,
    layer_change: LayerChangePayloadInput = .{},
};

pub const EventRecord = struct {
    id: u16,
    timestamp: f32,
    event_type: EventType,
    layer_change: LayerChangePayload,
};

pub const EmittedEvent = struct {
    clip_id: u8,
    loop_index: u64,
    record: EventRecord,
};

pub const EventBuffer = struct {
    storage: []EmittedEvent,
    count: usize = 0,

    pub fn reset(buffer: *EventBuffer) void {
        buffer.count = 0;
    }

    pub fn append(buffer: *EventBuffer, clip_id: u8, loop_index: u64, record: EventRecord) !void {
        if (buffer.count >= buffer.storage.len) return error.EventOutputOverflow;
        buffer.storage[buffer.count] = .{
            .clip_id = clip_id,
            .loop_index = loop_index,
            .record = record,
        };
        buffer.count += 1;
    }

    pub fn items(buffer: *const EventBuffer) []const EmittedEvent {
        return buffer.storage[0..buffer.count];
    }
};

pub fn validateType(raw: u8) !EventType {
    if (raw >= std.enums.values(EventType).len) return error.UnknownEventType;
    return @enumFromInt(raw);
}

pub fn validateRestoration(raw: u8) !LayerRestoration {
    if (raw >= std.enums.values(LayerRestoration).len) return error.InvalidLayerEventData;
    return @enumFromInt(raw);
}
