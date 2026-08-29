const std = @import("std");
const foundation = @import("foundation");
const canonical_model = @import("canonical_model");
const canonical_geometry = @import("canonical_geometry");

const canonical_data = foundation.canonical_data;

test "canonical JSON primitives use UTF-8 escaping shortest f32 and no newline" {
    var output: [256]u8 = undefined;
    var writer = canonical_data.Writer.init(&output);
    try writer.jsonString("A\n\t\x01 café");
    try std.testing.expectEqualStrings("\"A\\n\\t\\u0001 café\"", writer.bytes());

    writer = canonical_data.Writer.init(&output);
    try writer.f32Value(-0.0);
    try std.testing.expectEqualStrings("0", writer.bytes());
    try std.testing.expectError(error.NonFiniteFloat, writer.f32Value(std.math.inf(f32)));
    try std.testing.expectError(error.NonFiniteFloat, writer.f32Value(-std.math.inf(f32)));
    try std.testing.expectError(error.NonFiniteFloat, writer.f32Value(std.math.nan(f32)));
    try std.testing.expectError(error.InvalidUtf8, writer.jsonString(&.{ 0xc3, 0x28 }));
    try std.testing.expect(std.mem.indexOfScalar(u8, writer.bytes(), '\n') == null);
}

test "canonical object and record order ignore insertion order while semantic arrays preserve it" {
    const fields_one = [_]canonical_data.Field{
        .{ .name = "zeta", .canonical_value = "2" },
        .{ .name = "alpha", .canonical_value = "1" },
    };
    const fields_two = [_]canonical_data.Field{
        .{ .name = "alpha", .canonical_value = "1" },
        .{ .name = "zeta", .canonical_value = "2" },
    };
    var output_one: [128]u8 = undefined;
    var output_two: [128]u8 = undefined;
    var scratch_one: [2]usize = undefined;
    var scratch_two: [2]usize = undefined;
    var writer_one = canonical_data.Writer.init(&output_one);
    var writer_two = canonical_data.Writer.init(&output_two);
    try writer_one.object(&fields_one, &scratch_one);
    try writer_two.object(&fields_two, &scratch_two);
    try std.testing.expectEqualStrings("{\"alpha\":1,\"zeta\":2}", writer_one.bytes());
    try std.testing.expectEqualStrings(writer_one.bytes(), writer_two.bytes());

    writer_one = canonical_data.Writer.init(&output_one);
    try writer_one.semanticArray(&.{ "2", "1" });
    try std.testing.expectEqualStrings("[2,1]", writer_one.bytes());

    const records = [_]canonical_data.Record{
        .{ .key = "b", .canonical_value = "{\"id\":\"b\"}" },
        .{ .key = "a", .canonical_value = "{\"id\":\"a\"}" },
    };
    writer_one = canonical_data.Writer.init(&output_one);
    try writer_one.sortedRecordArray(&records, &scratch_one);
    try std.testing.expectEqualStrings("[{\"id\":\"a\"},{\"id\":\"b\"}]", writer_one.bytes());
}

test "canonical data rejects duplicate keys and uses versioned hash domains" {
    const duplicates = [_]canonical_data.Field{
        .{ .name = "same", .canonical_value = "1" },
        .{ .name = "same", .canonical_value = "2" },
    };
    var output: [64]u8 = undefined;
    var scratch: [2]usize = undefined;
    var writer = canonical_data.Writer.init(&output);
    try std.testing.expectError(error.DuplicateKey, writer.object(&duplicates, &scratch));

    const first = try canonical_data.hashDomainSeparated("foundation.test.v1", &.{ "ab", "c" });
    const second = try canonical_data.hashDomainSeparated("foundation.test.v1", &.{ "a", "bc" });
    const other_domain = try canonical_data.hashDomainSeparated("foundation.test.v2", &.{ "ab", "c" });
    try std.testing.expectEqualStrings(
        "bb8e5938e4750fb1bb120a2f01bee778569fcfc6b382baa0ee4409ee4ce39f01",
        &first.formatLowerHex(),
    );
    try std.testing.expect(!first.eql(second));
    try std.testing.expect(!first.eql(other_domain));
    try std.testing.expectError(error.InvalidHashDomain, canonical_data.hashDomainSeparated("Foundation Test", &.{}));
}

test "canonical UUID hash and version encodings are lowercase and stable" {
    const uuid = try foundation.identity.AssetId.parseCanonical("01890f46-0f13-7cc2-98c4-dc0c0c07398f");
    const digest = try canonical_data.Sha256Digest.parseLowerHex("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
    var output: [192]u8 = undefined;
    var writer = canonical_data.Writer.init(&output);
    try writer.uuidValue(uuid.bytes);
    try writer.byte(',');
    try writer.sha256Value(digest);
    try writer.byte(',');
    try writer.versionValue(12, 0, 37);
    try std.testing.expectEqualStrings(
        "\"01890f46-0f13-7cc2-98c4-dc0c0c07398f\",\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"12.0.37\"",
        writer.bytes(),
    );
    try std.testing.expectError(error.InvalidUuid, writer.uuidValue([_]u8{0} ** 16));
}

test "foundation f32 text conforms to protected canonical model serialization" {
    const samples = [_]f32{ 0.0, -0.0, 0.1, -17.25, 1.0e-7, 16_777_216.0 };
    for (samples) |sample| {
        var foundation_output: [64]u8 = undefined;
        var protected_output: [64]u8 = undefined;
        var writer = canonical_data.Writer.init(&foundation_output);
        try writer.f32Value(sample);
        const protected = try canonical_model.serialization.serializeF32(sample, &protected_output);
        try std.testing.expectEqualStrings(protected, writer.bytes());
    }
}

test "protected canonical-model fixture bytes and hash remain unchanged" {
    const authoring = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "tests/fixtures/canonical_model/minimal_valid_authoring.json",
        std.testing.allocator,
        .limited(64 * 1024),
    );
    defer std.testing.allocator.free(authoring);
    const golden = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "tests/fixtures/canonical_model/valid/minimal_valid_canonical.json",
        std.testing.allocator,
        .limited(64 * 1024),
    );
    defer std.testing.allocator.free(golden);
    var parsed = try canonical_model.parsing.parse(std.testing.allocator, authoring);
    defer parsed.deinit();
    const normalized = canonical_model.normalization.NormalizedDefinition{
        .source = &parsed.value,
        .coordinate_contract = parsed.value.coordinate_contract orelse canonical_model.coordinate.canonical,
    };
    var serialization_buffer: [16 * 1024]u8 = undefined;
    const hashed = try canonical_model.hashing.hashNormalized(normalized, &serialization_buffer);
    try std.testing.expectEqualStrings(golden, hashed.canonical_bytes);
    try std.testing.expectEqual(@as(usize, 12_022), hashed.canonical_bytes.len);
    try std.testing.expectEqualStrings("b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d", &hashed.source_definition_hash.toHex());
}

test "protected canonical-geometry fixture bytes and hash remain unchanged" {
    const authoring = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        "tests/fixtures/canonical_geometry/valid_open_module.authoring.json",
        std.testing.allocator,
        .limited(64 * 1024),
    );
    defer std.testing.allocator.free(authoring);
    var parsed = try canonical_geometry.parsing.parse(std.testing.allocator, authoring);
    defer parsed.deinit();
    const bytes = try canonical_geometry.serialization.serializeAlloc(
        std.testing.allocator,
        canonical_geometry.normalization.normalize(&parsed.value),
    );
    defer std.testing.allocator.free(bytes);
    const digest = canonical_geometry.hashing.hashBytes(bytes);
    try std.testing.expectEqual(@as(usize, 7_019), bytes.len);
    try std.testing.expectEqualStrings("4774698cde129491562f9da468b3e4338c3c672a665701f620c8f3ce9088921e", &digest.toHex());
}
