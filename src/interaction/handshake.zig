const interaction = @import("interaction");
const authored = @import("authored_clips");
const state_machine = @import("state_machine");
const clip = @import("clip");
const skeleton = @import("skeleton");

// Each authored contact pose reaches about 1.86 m from its root toward the partner.
pub const authored_horizontal_separation: f32 = 3.72;
pub const horizontal_tolerance: f32 = 0.02;
pub const minimum_horizontal_separation: f32 = authored_horizontal_separation - horizontal_tolerance;
pub const maximum_horizontal_separation: f32 = authored_horizontal_separation + horizontal_tolerance;
pub const maximum_vertical_root_difference: f32 = 0.02;

pub fn definition(definitions: *const authored.Definitions) !interaction.Definition {
    return interaction.Definition.init(.{
        .type_id = .handshake,
        .debug_name = "fixed_position_handshake",
        .declared_participant_count = interaction.participant_count,
        .role_a_state = state_machine.StateId.handshake_role_a,
        .role_b_state = state_machine.StateId.handshake_role_b,
        .role_a_clip_raw = @intFromEnum(clip.ClipId.handshake_role_a),
        .role_b_clip_raw = @intFromEnum(clip.ClipId.handshake_role_b),
        .role_a_socket = skeleton.SocketSemantic.right_hand,
        .role_b_socket = skeleton.SocketSemantic.right_hand,
        .allowed_start_states = .{ .idle, .walk },
        .envelope = .{
            .authored_horizontal_separation = authored_horizontal_separation,
            .minimum_horizontal_separation = minimum_horizontal_separation,
            .maximum_horizontal_separation = maximum_horizontal_separation,
            .maximum_vertical_root_difference = maximum_vertical_root_difference,
            .facing_tolerance_radians = 0,
        },
        .completion_behavior = .grounded_motion_fallback,
    }, definitions.library.clips, &definitions.machine);
}
