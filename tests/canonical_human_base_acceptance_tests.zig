const std = @import("std");
const canonical = @import("canonical_model");

const authoring_path = "assets/canonical_model/human_base/human_base.authoring.json";
const canonical_path = "assets/canonical_model/human_base/human_base.canonical.json";
const report_path = "assets/canonical_model/human_base/human_base.structural_report.txt";
const invalid_directory = "tests/fixtures/canonical_model/human_base/invalid";
const canonical_byte_count: usize = 379_458;
const canonical_sha256 = "7b579784f239d90ae9757a0aec1967fc37cf752733a4ac13409977f6f3212381";
const m01_phase_f_sha256 = "b1da6274c03d4a70de124f9ab81af8d870882c53ff759ca7d3c9e68b482d7f6d";

test "Prompt 2E readable human_base normalizes to the committed canonical golden" {
    const authoring = try readFixture(authoring_path);
    defer std.testing.allocator.free(authoring);
    const golden = try readFixture(canonical_path);
    defer std.testing.allocator.free(golden);

    try std.testing.expect(std.mem.indexOfAny(u8, authoring, " \t\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, authoring, "\"morphology_parameters\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, authoring, "\"component_id\": \"vulva_vaginal_canal_module_01\"").? <
        std.mem.indexOf(u8, authoring, "\"component_id\": \"body\"").?);
    try std.testing.expect(std.mem.indexOf(u8, golden, "\"component_id\":\"body\"").? <
        std.mem.indexOf(u8, golden, "\"component_id\":\"vulva_vaginal_canal_module_01\"").?);

    var parsed = try canonical.parsing.parse(std.testing.allocator, authoring);
    defer parsed.deinit();
    try canonical.human_structural_validation.validatePrompt2D(&parsed.value);
    var diagnostics: [1024]canonical.diagnostics.Diagnostic = undefined;
    const normalized = try canonical.normalization.normalize(&parsed.value, .{}, &diagnostics);
    try std.testing.expect(normalized.isValid());
    const generated = try canonical.serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(generated);
    try std.testing.expectEqualStrings(golden, generated);

    var mirror_diagnostics: [1024]canonical.diagnostics.Diagnostic = undefined;
    const mirror_normalized = try canonical.normalization.normalize(&canonical.human_base.source, .{}, &mirror_diagnostics);
    try std.testing.expect(mirror_normalized.isValid());
    const mirror_bytes = try canonical.serialization.serializeAlloc(std.testing.allocator, mirror_normalized.normalized.?);
    defer std.testing.allocator.free(mirror_bytes);
    try std.testing.expectEqualStrings(golden, mirror_bytes);

    var golden_parse = try canonical.parsing.parse(std.testing.allocator, golden);
    defer golden_parse.deinit();
    try canonical.human_structural_validation.validatePrompt2D(&golden_parse.value);
    var golden_diagnostics: [1024]canonical.diagnostics.Diagnostic = undefined;
    const golden_normalized = try canonical.normalization.normalize(&golden_parse.value, .{}, &golden_diagnostics);
    try std.testing.expect(golden_normalized.isValid());
    const round_trip = try canonical.serialization.serializeAlloc(std.testing.allocator, golden_normalized.normalized.?);
    defer std.testing.allocator.free(round_trip);
    try std.testing.expectEqualStrings(golden, round_trip);

    try std.testing.expectEqual(canonical_byte_count, golden.len);
    try std.testing.expectEqual(@as(u8, '}'), golden[golden.len - 1]);
    try std.testing.expect(golden[golden.len - 1] != '\n');
    const digest_hex = sha256Hex(golden);
    try std.testing.expectEqualStrings(canonical_sha256, &digest_hex);
    std.debug.print("PROMPT2E_GOLDEN bytes={d} final_byte=0x{x:0>2} newline=no sha256={s}\n", .{ golden.len, golden[golden.len - 1], &digest_hex });
}

test "Prompt 3 keeps authoring authoritative and evidence updates explicit" {
    try std.testing.expectEqualStrings(authoring_path, canonical.human_base.authoritative_authoring_path);

    const exporter = try readFixture("tools/export_human_base_evidence.zig");
    defer std.testing.allocator.free(exporter);
    try std.testing.expect(std.mem.indexOf(u8, exporter, "readFileAlloc(init.io, authoring_path") != null);
    try std.testing.expect(std.mem.indexOf(u8, exporter, "writeFile(init.io, authoring_path") == null);
    try std.testing.expect(std.mem.indexOf(u8, exporter, "human_base.source") == null);

    const build_source = try readFixture("build.zig");
    defer std.testing.allocator.free(build_source);
    try std.testing.expect(std.mem.indexOf(u8, build_source, "human_base_export_step.dependOn(&run_human_base_export.step)") != null);
    try std.testing.expect(std.mem.indexOf(u8, build_source, "test_step.dependOn(&run_human_base_export.step)") == null);
    try std.testing.expect(std.mem.indexOf(u8, build_source, "full_test_step.dependOn(&run_human_base_export.step)") == null);
    try std.testing.expect(std.mem.indexOf(u8, build_source, "check_step.dependOn(&run_human_base_export.step)") == null);
    try std.testing.expect(std.mem.indexOf(u8, build_source, "verify_step.dependOn(&run_human_base_export.step)") == null);
}

test "Prompt 2E repeats parse validate normalize serialize hash and reports five times" {
    const authoring = try readFixture(authoring_path);
    defer std.testing.allocator.free(authoring);
    const golden = try readFixture(canonical_path);
    defer std.testing.allocator.free(golden);
    const stored_report = try readFixture(report_path);
    defer std.testing.allocator.free(stored_report);

    for (0..5) |iteration| {
        var parsed = try canonical.parsing.parse(std.testing.allocator, authoring);
        defer parsed.deinit();
        try canonical.human_structural_validation.validatePrompt2D(&parsed.value);
        var diagnostics: [1024]canonical.diagnostics.Diagnostic = undefined;
        const normalized = try canonical.normalization.normalize(&parsed.value, .{}, &diagnostics);
        try std.testing.expect(normalized.isValid());
        const generated = try canonical.serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
        defer std.testing.allocator.free(generated);
        try std.testing.expectEqualStrings(golden, generated);
        try std.testing.expectEqualStrings(canonical_sha256, &sha256Hex(generated));

        const report = try canonical.human_evidence.generateAlloc(std.testing.allocator, &parsed.value);
        defer std.testing.allocator.free(report);
        try std.testing.expectEqualStrings(stored_report, report);
        std.debug.print("PROMPT2E_REPEAT iteration={d} bytes={d} sha256={s} report_bytes={d}\n", .{ iteration + 1, generated.len, canonical_sha256, report.len });
    }
}

test "Prompt 2E controlled material mutation changes canonical bytes and hash" {
    const authoring = try readFixture(authoring_path);
    defer std.testing.allocator.free(authoring);
    const golden = try readFixture(canonical_path);
    defer std.testing.allocator.free(golden);
    var parsed = try canonical.parsing.parse(std.testing.allocator, authoring);
    defer parsed.deinit();

    var source = parsed.value;
    const instances = try std.testing.allocator.dupe(canonical.material.MaterialInstance, source.material_instances);
    defer std.testing.allocator.free(instances);
    const instance_index = findMaterialInstanceIndex(instances, "human_base_skin") orelse return error.MissingMaterialInstance;
    const properties = try std.testing.allocator.dupe(canonical.material.MaterialProperty, instances[instance_index].properties);
    defer std.testing.allocator.free(properties);
    instances[instance_index].properties = properties;
    source.material_instances = instances;
    const property_index = findMaterialPropertyIndex(properties, "base_color") orelse return error.MissingMaterialProperty;
    switch (properties[property_index].value) {
        .linear_srgb_rgba => |color| {
            var changed = color;
            changed.channels[0] += 0.01;
            properties[property_index].value = .{ .linear_srgb_rgba = changed };
        },
        else => return error.UnexpectedMaterialPropertyType,
    }

    var diagnostics: [1024]canonical.diagnostics.Diagnostic = undefined;
    const normalized = try canonical.normalization.normalize(&source, .{}, &diagnostics);
    try std.testing.expect(normalized.isValid());
    const mutated = try canonical.serialization.serializeAlloc(std.testing.allocator, normalized.normalized.?);
    defer std.testing.allocator.free(mutated);
    try std.testing.expect(!std.mem.eql(u8, golden, mutated));
    const original_hash = sha256Hex(golden);
    const mutated_hash = sha256Hex(mutated);
    try std.testing.expect(!std.mem.eql(u8, &original_hash, &mutated_hash));
    std.debug.print("PROMPT2E_MUTATION original={s} mutated={s}\n", .{ &original_hash, &mutated_hash });
}

test "Prompt 2E file-backed human invalid fixture matrix fails closed precisely" {
    inline for (canonical.human_acceptance.invalid_fixture_specs) |spec| {
        var path_buffer: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ invalid_directory, spec.file_name });
        const bytes = try readFixture(path);
        defer std.testing.allocator.free(bytes);
        var parsed = try canonical.parsing.parse(std.testing.allocator, bytes);
        defer parsed.deinit();

        const diagnostic = canonical.human_acceptance.diagnose(spec, &parsed.value) orelse return error.InvalidFixtureAccepted;
        try expectDiagnosticEqual(spec.expected, diagnostic);
        const repeated = canonical.human_acceptance.diagnose(spec, &parsed.value) orelse return error.InvalidFixtureAccepted;
        try expectDiagnosticEqual(diagnostic, repeated);
        std.debug.print("PROMPT2E_INVALID fixture={s} code={s} object={s} id={s} property={s}\n", .{
            spec.fixture_id,
            @tagName(diagnostic.code),
            diagnostic.object_type,
            diagnostic.object_id orelse "null",
            diagnostic.property orelse "null",
        });
    }
    try std.testing.expectEqual(@as(usize, 17), canonical.human_acceptance.invalid_fixture_specs.len);
}

test "Prompt 3 large-source diagnostic capacity fails explicitly without truncation" {
    const bytes = try readFixture(invalid_directory ++ "/01_missing_skeleton_root.json");
    defer std.testing.allocator.free(bytes);
    var parsed = try canonical.parsing.parse(std.testing.allocator, bytes);
    defer parsed.deinit();
    var no_storage: [0]canonical.diagnostics.Diagnostic = .{};
    try std.testing.expectError(
        error.DiagnosticCapacityExceeded,
        canonical.normalization.normalize(&parsed.value, .{}, &no_storage),
    );
}

test "Prompt 2E structural evidence locks counts measurements modules and anatomy identities" {
    const report = try readFixture(report_path);
    defer std.testing.allocator.free(report);
    inline for (.{
        "LOCKED_COUNTS components=48 bones=149 shared_bones=140 optional_penis_bones=9 joints=148 controls=116 spine_controls=5 regions=206 surfaces=206 materials=11 anchors=106 sockets=22 mounts=20 attachments=20 landmarks=35 seams=11 sites=25 effectors=6 collision_proxies=0",
        "total_height=1.828800 shoulder_breadth=0.350000 hip_breadth=0.200000 arm_span=1.630712 torso_length=0.560000 leg_length=0.950000 upper_arm_length=0.310000 forearm_length=0.270000 thigh_length=0.450000 lower_leg_length=0.430000 hand_length=0.145000 foot_length=0.260000 head_height=0.308800",
        "component=anus_module_01 requirement=optional default_state=enabled multiplicity=0..1",
        "component=vulva_vaginal_canal_module_01 requirement=optional default_state=disabled multiplicity=0..1",
        "component=penis_module_01 requirement=optional default_state=disabled multiplicity=0..1",
        "component=scrotum_testicles_module_01 requirement=optional default_state=disabled multiplicity=0..1",
        "anchor=anterior_genital_anchor present=yes",
        "anchor=perineal_center_anchor present=yes",
        "anchor=posterior_anal_anchor present=yes",
        "anchor=groin_left_anchor present=yes",
        "anchor=groin_right_anchor present=yes",
        "anchor=pubic_center_anchor present=yes",
        "site=posterior_anal_site present=yes",
        "site=vulva_structural_site present=yes",
        "site=penis_structural_site present=yes",
        "site=scrotum_structural_site present=yes",
        "INVALID_FIXTURE_DIAGNOSTICS",
        "fixture=17_invalid_optional_module_multiplicity file=17_invalid_optional_module_multiplicity.json stage=prompt_2a code=invalid_optional_module_multiplicity",
        "OPEN_TUNING_VALUES",
        "human_base.open_tuning.skin_linear_srgb_rgba={ 0.52, 0.32, 0.22, 1 }",
        "human_rig.open_tuning.pelvis_height_m=0.95",
        "human_controls.open_tuning.centered_neutral=0.5",
        "human_attachments.open_tuning.posterior_anal_back_m=0.08",
        "human_joints.open_tuning profile=human_shoulder_mobility",
        "collision_proxy_dimensions=none deferred_from_M02",
    }) |evidence| try std.testing.expect(std.mem.indexOf(u8, report, evidence) != null);
}

test "Prompt 2E keeps one shared human_base and records derived-profile deferral" {
    const authoring = try readFixture(authoring_path);
    defer std.testing.allocator.free(authoring);
    try std.testing.expectEqualStrings(
        "deferred_until_configuration_records_can_prove_shared_human_base_without_duplicate_rigs",
        canonical.human_acceptance.derived_profile_decision,
    );
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, authoring, "\"asset_id\": \"human_base\""));
    try std.testing.expect(std.mem.indexOf(u8, authoring, "male_human_base") == null);
    try std.testing.expect(std.mem.indexOf(u8, authoring, "female_human_base") == null);
}

test "Prompt 2E preserves accepted M01 phase-F golden identity" {
    const bytes = try readFixture("tests/fixtures/canonical_model/valid/minimal_valid_canonical.json");
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings(m01_phase_f_sha256, &sha256Hex(bytes));
}

fn readFixture(path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(2 * 1024 * 1024));
}

fn sha256Hex(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn expectDiagnosticEqual(expected: canonical.human_acceptance.Diagnostic, actual: canonical.human_acceptance.Diagnostic) !void {
    try std.testing.expectEqual(expected.code, actual.code);
    try std.testing.expectEqualStrings(expected.object_type, actual.object_type);
    try expectOptionalStringEqual(expected.object_id, actual.object_id);
    try expectOptionalStringEqual(expected.property, actual.property);
    try std.testing.expectEqualStrings(expected.message, actual.message);
}

fn expectOptionalStringEqual(expected: ?[]const u8, actual: ?[]const u8) !void {
    try std.testing.expect((expected == null) == (actual == null));
    if (expected) |value| try std.testing.expectEqualStrings(value, actual.?);
}

fn findMaterialInstanceIndex(records: []const canonical.material.MaterialInstance, id: []const u8) ?usize {
    for (records, 0..) |record, index| if (std.mem.eql(u8, record.material_instance_id.value.bytes, id)) return index;
    return null;
}

fn findMaterialPropertyIndex(records: []const canonical.material.MaterialProperty, id: []const u8) ?usize {
    for (records, 0..) |record, index| if (std.mem.eql(u8, record.property_id.value.bytes, id)) return index;
    return null;
}
