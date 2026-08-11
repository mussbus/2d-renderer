const std = @import("std");
const geometry = @import("canonical_geometry");
const human_geometry = @import("canonical_human_geometry");

pub fn main(init: std.process.Init) !void {
    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    if (arguments.len < 2 or arguments.len > 3) return error.InvalidArguments;

    const allocator = std.heap.page_allocator;
    const candidate_path = arguments[1];
    var loaded = try human_geometry.authority.loadCandidate(allocator, init.io, candidate_path);
    defer loaded.deinit();

    const raw_bytes = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        candidate_path,
        allocator,
        .limited(geometry.loader.default_maximum_source_bytes),
    );
    defer allocator.free(raw_bytes);

    var source = try geometry.hashing.sourceHashAlloc(allocator, loaded.geometry.normalized());
    defer source.deinit();
    const topology = try geometry.hashing.topologyHashAlloc(allocator, loaded.definition());
    const triangulation = try geometry.hashing.triangulationHashAlloc(allocator, loaded.definition());
    const neutral = try geometry.hashing.neutralSignatureAlloc(
        allocator,
        loaded.definition(),
        loaded.structural_sha256,
        source.geometry_source_sha256,
        topology,
    );
    const raw_hash = geometry.hashing.hashBytes(raw_bytes);

    var vertex_count: usize = 0;
    var face_count: usize = 0;
    for (loaded.definition().meshes) |mesh| {
        vertex_count += mesh.vertices.len;
        face_count += mesh.faces.len;
    }

    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();
    const writer = &output.writer;
    try writer.print("candidate_authoring_bytes={d}\n", .{raw_bytes.len});
    try writer.print("candidate_authoring_sha256={s}\n", .{&raw_hash.toHex()});
    try writer.print("normalized_geometry_bytes={d}\n", .{source.canonical_bytes.len});
    try writer.print("normalized_geometry_sha256={s}\n", .{&source.geometry_source_sha256.toHex()});
    try writer.print("control_topology_sha256={s}\n", .{&topology.toHex()});
    try writer.print("triangulation_sha256={s}\n", .{&triangulation.toHex()});
    try writer.print("neutral_geometry_signature={s}\n", .{&neutral.toHex()});
    try writer.print("structural_normalized_sha256={s}\n", .{&loaded.structural_sha256.toHex()});
    try writer.print("mesh_count={d}\nvertex_count={d}\nface_count={d}\n", .{ loaded.definition().meshes.len, vertex_count, face_count });
    try writer.print("face_set_count={d}\ntopology_loop_count={d}\nseam_binding_count={d}\ngeometry_binding_count={d}\n", .{
        loaded.definition().face_sets.len,
        loaded.definition().topology_loops.len,
        loaded.definition().seam_bindings.len,
        loaded.definition().geometry_bindings.len,
    });
    for (loaded.definition().meshes) |mesh| {
        try writer.print("mesh={s} next_vertex_id={d} next_face_id={d}\n", .{
            mesh.mesh_id.value.bytes,
            mesh.next_vertex_id,
            mesh.next_face_id,
        });
    }

    std.debug.print("{s}", .{output.written()});
    if (arguments.len == 3) try writeFile(init.io, arguments[2], output.written());
}

fn writeFile(io: std.Io, path: []const u8, bytes: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}
