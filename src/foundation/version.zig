const std = @import("std");

pub const SchemaVersion = Version("schema");
pub const AssetVersion = Version("asset");
pub const ProducerVersion = Version("producer_compiler");
pub const GeneratorVersion = Version("generator");
pub const AlgorithmVersion = Version("algorithm");

pub const ParseError = error{
    EmptyComponent,
    InvalidCharacter,
    LeadingZero,
    MissingComponent,
    TooManyComponents,
    Overflow,
};

fn Version(comptime kind_name: []const u8) type {
    return struct {
        const Self = @This();

        major: u32,
        minor: u32,
        patch: u32,

        pub const kind = kind_name;

        pub fn init(major: u32, minor: u32, patch: u32) Self {
            return .{ .major = major, .minor = minor, .patch = patch };
        }

        pub fn parse(text: []const u8) ParseError!Self {
            var parts: [3]u32 = undefined;
            var part_index: usize = 0;
            var start: usize = 0;
            var cursor: usize = 0;
            while (cursor <= text.len) : (cursor += 1) {
                if (cursor != text.len and text[cursor] != '.') continue;
                if (part_index == parts.len) return error.TooManyComponents;
                const component = text[start..cursor];
                if (component.len == 0) return error.EmptyComponent;
                if (component.len > 1 and component[0] == '0') return error.LeadingZero;
                var value: u32 = 0;
                for (component) |byte| {
                    if (byte < '0' or byte > '9') return error.InvalidCharacter;
                    value = std.math.mul(u32, value, 10) catch return error.Overflow;
                    value = std.math.add(u32, value, byte - '0') catch return error.Overflow;
                }
                parts[part_index] = value;
                part_index += 1;
                start = cursor + 1;
            }
            if (part_index != parts.len) return error.MissingComponent;
            return .{ .major = parts[0], .minor = parts[1], .patch = parts[2] };
        }

        pub fn format(self: Self, output: []u8) error{OutputTooSmall}![]const u8 {
            return std.fmt.bufPrint(output, "{d}.{d}.{d}", .{ self.major, self.minor, self.patch }) catch
                return error.OutputTooSmall;
        }

        pub fn eql(a: Self, b: Self) bool {
            return a.major == b.major and a.minor == b.minor and a.patch == b.patch;
        }

        pub fn order(a: Self, b: Self) std.math.Order {
            if (a.major != b.major) return std.math.order(a.major, b.major);
            if (a.minor != b.minor) return std.math.order(a.minor, b.minor);
            return std.math.order(a.patch, b.patch);
        }
    };
}
