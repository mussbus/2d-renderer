"""Lossless offline bridge between canonical geometry JSON and Blender 4.5.9.

The JSON remains authoritative. Blender indices are working-storage details;
canonical u32 IDs live in explicit split high/low mesh attributes.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys
from typing import Any, Iterable

import bpy


BRIDGE_SCHEMA_ID = "canonical_geometry_blender_bridge"
BRIDGE_VERSION = "1.0.0"
EXPECTED_BLENDER_VERSION = (4, 5, 9)
UNALLOCATED_HALF = -1
ALLOCATED_STATE = 1
UNALLOCATED_STATE = 0
U16_MAX = 0xFFFF
U32_MAX = 0xFFFFFFFF

ATTR_VERTEX_ID_HIGH = "cgb_vertex_id_high"
ATTR_VERTEX_ID_LOW = "cgb_vertex_id_low"
ATTR_VERTEX_STATE = "cgb_vertex_state"
ATTR_VERTEX_ALLOCATION_ORDER = "cgb_vertex_allocation_order"
ATTR_FACE_ID_HIGH = "cgb_face_id_high"
ATTR_FACE_ID_LOW = "cgb_face_id_low"
ATTR_FACE_STATE = "cgb_face_state"
ATTR_FACE_ALLOCATION_ORDER = "cgb_face_allocation_order"
ATTR_FACE_SEMANTIC_STATE = "cgb_face_semantic_state"
ATTR_DIAGONAL = "cgb_diagonal"
ATTR_PRIMARY_SURFACE = "cgb_primary_surface"
ATTR_MATERIAL = "cgb_material"
ATTR_REGION_SET = "cgb_region_set"
ATTR_CORNER_SURFACE = "cgb_corner_surface"
ATTR_CORNER_CHART = "cgb_corner_chart"
ATTR_CORNER_SURFACE_U = "cgb_corner_surface_u"
ATTR_CORNER_SURFACE_V = "cgb_corner_surface_v"
ATTR_CORNER_TEXTURE_SPACE = "cgb_corner_texture_space"
ATTR_CORNER_UV_ISLAND = "cgb_corner_uv_island"
ATTR_CORNER_U = "cgb_corner_u"
ATTR_CORNER_V = "cgb_corner_v"
ATTR_CORNER_OVERLAP = "cgb_corner_overlap"
ATTR_LOOP_MEMBERSHIP_COUNT = "cgb_loop_membership_count"


class BridgeError(RuntimeError):
    """A fail-closed bridge validation error."""


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", float(value)))[0]


def canonical_to_blender(position: Iterable[float]) -> tuple[float, float, float]:
    x, y, z = (f32(value) for value in position)
    return (x, f32(-z), y)


def blender_to_canonical(position: Iterable[float]) -> list[float]:
    x, y, z = (f32(value) for value in position)
    return [x, z, f32(-y)]


def split_u32(value: int) -> tuple[int, int]:
    if not isinstance(value, int) or value < 0 or value > U32_MAX:
        raise BridgeError(f"canonical ID is outside u32: {value!r}")
    return (value >> 16, value & U16_MAX)


def combine_u32(high: int, low: int, label: str) -> int | None:
    if high == UNALLOCATED_HALF and low == UNALLOCATED_HALF:
        return None
    if high < 0 or high > U16_MAX or low < 0 or low > U16_MAX:
        raise BridgeError(f"{label} has invalid split-u32 halves ({high}, {low})")
    return (high << 16) | low


def stable_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n").encode("utf-8")


def candidate_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=False, indent=2, allow_nan=False) + "\n").encode("utf-8")


def require_blender_version() -> None:
    if tuple(bpy.app.version) != EXPECTED_BLENDER_VERSION:
        raise BridgeError(
            f"bridge requires Blender 4.5.9 exactly; active version is {bpy.app.version_string}"
        )


def require_identity_transform(obj: bpy.types.Object) -> None:
    tolerance = 1.0e-7
    if any(abs(float(value)) > tolerance for value in obj.location):
        raise BridgeError(f"object {obj.name!r} has non-identity location")
    if any(abs(float(value)) > tolerance for value in obj.rotation_euler):
        raise BridgeError(f"object {obj.name!r} has non-identity rotation")
    if any(abs(float(value) - 1.0) > tolerance for value in obj.scale):
        raise BridgeError(f"object {obj.name!r} has non-identity scale")


def set_int_attribute(mesh: bpy.types.Mesh, name: str, domain: str, values: list[int]) -> None:
    attribute = mesh.attributes.get(name)
    if attribute is not None:
        mesh.attributes.remove(attribute)
    attribute = mesh.attributes.new(name=name, type="INT", domain=domain)
    if len(attribute.data) != len(values):
        raise BridgeError(f"attribute {name!r} length mismatch while importing")
    attribute.data.foreach_set("value", values)


def set_float_attribute(mesh: bpy.types.Mesh, name: str, domain: str, values: list[float]) -> None:
    attribute = mesh.attributes.get(name)
    if attribute is not None:
        mesh.attributes.remove(attribute)
    attribute = mesh.attributes.new(name=name, type="FLOAT", domain=domain)
    if len(attribute.data) != len(values):
        raise BridgeError(f"attribute {name!r} length mismatch while importing")
    attribute.data.foreach_set("value", [f32(value) for value in values])


def read_int_attribute(mesh: bpy.types.Mesh, name: str, domain: str) -> list[int]:
    attribute = mesh.attributes.get(name)
    if attribute is None or attribute.data_type != "INT" or attribute.domain != domain:
        raise BridgeError(f"missing or incompatible required {domain} INT attribute {name!r}")
    values = [0] * len(attribute.data)
    attribute.data.foreach_get("value", values)
    return values


def read_float_attribute(mesh: bpy.types.Mesh, name: str, domain: str) -> list[float]:
    attribute = mesh.attributes.get(name)
    if attribute is None or attribute.data_type != "FLOAT" or attribute.domain != domain:
        raise BridgeError(f"missing or incompatible required {domain} FLOAT attribute {name!r}")
    values = [0.0] * len(attribute.data)
    attribute.data.foreach_get("value", values)
    return [f32(value) for value in values]


def require_index(index: int, values: list[Any], label: str) -> Any:
    if index < 0 or index >= len(values):
        raise BridgeError(f"{label} table index {index} is invalid")
    return values[index]


def table_index(values: list[Any], value: Any, label: str) -> int:
    try:
        return values.index(value)
    except ValueError as error:
        raise BridgeError(f"{label} value {value!r} is absent from sidecar table") from error


def collect_tables(document: dict[str, Any]) -> dict[str, list[Any]]:
    surface_ids: set[str] = set()
    material_ids: set[str] = set()
    chart_ids: set[str] = set()
    texture_space_ids: set[str] = set()
    uv_island_ids: set[str] = set()
    overlap_group_ids: set[str] = set()
    region_sets: set[tuple[str, ...]] = set()
    for mesh in document["meshes"]:
        for face in mesh["faces"]:
            surface_ids.add(face["primary_surface_id"])
            material_ids.add(face["material_instance_id"])
            region_sets.add(tuple(face["region_ids"]))
            for corner in face["surface_coordinates"]:
                surface_ids.add(corner["surface_id"])
                chart_ids.add(corner["chart_id"])
            for corner in face["texture_coordinates"]:
                texture_space_ids.add(corner["texture_space_id"])
                uv_island_ids.add(corner["uv_island_id"])
                if corner.get("overlap_group_id") is not None:
                    overlap_group_ids.add(corner["overlap_group_id"])
    return {
        "surface_ids": sorted(surface_ids),
        "material_instance_ids": sorted(material_ids),
        "chart_ids": sorted(chart_ids),
        "texture_space_ids": sorted(texture_space_ids),
        "uv_island_ids": sorted(uv_island_ids),
        "overlap_group_ids": sorted(overlap_group_ids),
        "region_sets": [list(value) for value in sorted(region_sets)],
    }


def working_file_id(source_hash: str, normalized_hash: str) -> str:
    payload = (
        "canonical_geometry_blender_working_file_v1\0"
        + BRIDGE_VERSION
        + "\0"
        + source_hash
        + "\0"
        + normalized_hash
    ).encode("ascii")
    return sha256_bytes(payload)


def write_sidecar(
    source_path: Path,
    sidecar_path: Path,
    document: dict[str, Any],
    source_hash: str,
    normalized_hash: str,
) -> tuple[dict[str, Any], str]:
    sidecar = {
        "bridge_schema_id": BRIDGE_SCHEMA_ID,
        "bridge_version": BRIDGE_VERSION,
        "blender_version": "4.5.9 LTS",
        "working_file_id": working_file_id(source_hash, normalized_hash),
        "source": {
            "authoritative_path": source_path.as_posix(),
            "authoritative_sha256": source_hash,
            "normalized_geometry_sha256": normalized_hash,
            "geometry_asset_id": document["asset_identity"]["geometry_asset_id"],
            "topology_id": document["topology_identity"]["topology_id"],
            "topology_compatibility_version": document["topology_identity"]["compatibility_version"],
            "topology_revision": document["topology_identity"]["revision"],
            "structural_normalized_sha256": document["structural_compatibility"]["normalized_source_sha256"],
        },
        "tables": collect_tables(document),
        "document_template": document,
    }
    encoded = stable_json_bytes(sidecar)
    sidecar_path.parent.mkdir(parents=True, exist_ok=True)
    sidecar_path.write_bytes(encoded)
    return sidecar, sha256_bytes(encoded)


def require_sidecar(path: Path) -> tuple[dict[str, Any], str]:
    if not path.is_file():
        raise BridgeError(f"required derived sidecar is missing: {path}")
    encoded = path.read_bytes()
    try:
        sidecar = json.loads(encoded)
    except json.JSONDecodeError as error:
        raise BridgeError(f"derived sidecar is malformed: {error}") from error
    if sidecar.get("bridge_schema_id") != BRIDGE_SCHEMA_ID or sidecar.get("bridge_version") != BRIDGE_VERSION:
        raise BridgeError("derived sidecar bridge identity is incompatible")
    return sidecar, sha256_bytes(encoded)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for collection in list(bpy.data.collections):
        if collection.users == 0:
            bpy.data.collections.remove(collection)


def apply_root_properties(sidecar: dict[str, Any], sidecar_hash: str) -> None:
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["cgb_bridge_schema_id"] = BRIDGE_SCHEMA_ID
    scene["cgb_bridge_version"] = BRIDGE_VERSION
    scene["cgb_blender_version"] = "4.5.9 LTS"
    scene["cgb_working_file_id"] = sidecar["working_file_id"]
    scene["cgb_source_authoritative_sha256"] = sidecar["source"]["authoritative_sha256"]
    scene["cgb_source_normalized_sha256"] = sidecar["source"]["normalized_geometry_sha256"]
    scene["cgb_sidecar_sha256"] = sidecar_hash
    scene["cgb_geometry_asset_id"] = sidecar["source"]["geometry_asset_id"]
    scene["cgb_topology_id"] = sidecar["source"]["topology_id"]
    scene["cgb_topology_revision"] = int(sidecar["source"]["topology_revision"])
    scene["cgb_structural_normalized_sha256"] = sidecar["source"]["structural_normalized_sha256"]
    scene["cgb_coordinate_contract"] = "canonical_to_blender:(X,Y,Z)->(X,-Z,Y)"


def face_lookup(document: dict[str, Any]) -> dict[tuple[str, int], dict[str, Any]]:
    result: dict[tuple[str, int], dict[str, Any]] = {}
    for mesh in document["meshes"]:
        for face in mesh["faces"]:
            result[(mesh["mesh_id"], int(face["face_id"]))] = face
    return result


def build_mesh_object(mesh_source: dict[str, Any], sidecar: dict[str, Any]) -> bpy.types.Object:
    mesh_id = mesh_source["mesh_id"]
    vertices = sorted(mesh_source["vertices"], key=lambda item: int(item["vertex_id"]))
    faces = sorted(mesh_source["faces"], key=lambda item: int(item["face_id"]))
    vertex_index = {int(vertex["vertex_id"]): index for index, vertex in enumerate(vertices)}
    if len(vertex_index) != len(vertices):
        raise BridgeError(f"source mesh {mesh_id!r} contains duplicate VertexIds")
    face_vertex_indexes: list[list[int]] = []
    for face in faces:
        try:
            face_vertex_indexes.append([vertex_index[int(value)] for value in face["vertex_ids"]])
        except KeyError as error:
            raise BridgeError(f"source face {face['face_id']} references a missing VertexId") from error

    mesh = bpy.data.meshes.new(f"{mesh_id}__canonical_working_mesh")
    mesh.from_pydata(
        [canonical_to_blender(vertex["position_m"]) for vertex in vertices],
        [],
        face_vertex_indexes,
    )
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(mesh_id, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)

    vertex_halves = [split_u32(int(vertex["vertex_id"])) for vertex in vertices]
    set_int_attribute(mesh, ATTR_VERTEX_ID_HIGH, "POINT", [value[0] for value in vertex_halves])
    set_int_attribute(mesh, ATTR_VERTEX_ID_LOW, "POINT", [value[1] for value in vertex_halves])
    set_int_attribute(mesh, ATTR_VERTEX_STATE, "POINT", [ALLOCATED_STATE] * len(vertices))
    set_int_attribute(mesh, ATTR_VERTEX_ALLOCATION_ORDER, "POINT", [0] * len(vertices))

    face_halves = [split_u32(int(face["face_id"])) for face in faces]
    set_int_attribute(mesh, ATTR_FACE_ID_HIGH, "FACE", [value[0] for value in face_halves])
    set_int_attribute(mesh, ATTR_FACE_ID_LOW, "FACE", [value[1] for value in face_halves])
    set_int_attribute(mesh, ATTR_FACE_STATE, "FACE", [ALLOCATED_STATE] * len(faces))
    set_int_attribute(mesh, ATTR_FACE_ALLOCATION_ORDER, "FACE", [0] * len(faces))
    set_int_attribute(mesh, ATTR_FACE_SEMANTIC_STATE, "FACE", [ALLOCATED_STATE] * len(faces))

    tables = sidecar["tables"]
    set_int_attribute(mesh, ATTR_DIAGONAL, "FACE", [0 if face["diagonal"] == "v0_v2" else 1 for face in faces])
    set_int_attribute(mesh, ATTR_PRIMARY_SURFACE, "FACE", [
        table_index(tables["surface_ids"], face["primary_surface_id"], "surface") for face in faces
    ])
    set_int_attribute(mesh, ATTR_MATERIAL, "FACE", [
        table_index(tables["material_instance_ids"], face["material_instance_id"], "material") for face in faces
    ])
    set_int_attribute(mesh, ATTR_REGION_SET, "FACE", [
        table_index(tables["region_sets"], face["region_ids"], "region set") for face in faces
    ])

    corner_surface: list[int] = []
    corner_chart: list[int] = []
    corner_surface_u: list[float] = []
    corner_surface_v: list[float] = []
    corner_texture_space: list[int] = []
    corner_uv_island: list[int] = []
    corner_u: list[float] = []
    corner_v: list[float] = []
    corner_overlap: list[int] = []
    for face in faces:
        for surface_corner, texture_corner in zip(face["surface_coordinates"], face["texture_coordinates"], strict=True):
            corner_surface.append(table_index(tables["surface_ids"], surface_corner["surface_id"], "corner surface"))
            corner_chart.append(table_index(tables["chart_ids"], surface_corner["chart_id"], "chart"))
            corner_surface_u.append(surface_corner["coordinate"][0])
            corner_surface_v.append(surface_corner["coordinate"][1])
            corner_texture_space.append(table_index(tables["texture_space_ids"], texture_corner["texture_space_id"], "texture space"))
            corner_uv_island.append(table_index(tables["uv_island_ids"], texture_corner["uv_island_id"], "UV island"))
            corner_u.append(texture_corner["uv"][0])
            corner_v.append(texture_corner["uv"][1])
            overlap = texture_corner.get("overlap_group_id")
            corner_overlap.append(-1 if overlap is None else table_index(tables["overlap_group_ids"], overlap, "overlap group"))
    set_int_attribute(mesh, ATTR_CORNER_SURFACE, "CORNER", corner_surface)
    set_int_attribute(mesh, ATTR_CORNER_CHART, "CORNER", corner_chart)
    set_float_attribute(mesh, ATTR_CORNER_SURFACE_U, "CORNER", corner_surface_u)
    set_float_attribute(mesh, ATTR_CORNER_SURFACE_V, "CORNER", corner_surface_v)
    set_int_attribute(mesh, ATTR_CORNER_TEXTURE_SPACE, "CORNER", corner_texture_space)
    set_int_attribute(mesh, ATTR_CORNER_UV_ISLAND, "CORNER", corner_uv_island)
    set_float_attribute(mesh, ATTR_CORNER_U, "CORNER", corner_u)
    set_float_attribute(mesh, ATTR_CORNER_V, "CORNER", corner_v)
    set_int_attribute(mesh, ATTR_CORNER_OVERLAP, "CORNER", corner_overlap)

    mark_loop_edges(mesh, mesh_source, sidecar["document_template"])
    obj["cgb_mesh_id"] = mesh_id
    obj["cgb_source_authoritative_sha256"] = sidecar["source"]["authoritative_sha256"]
    obj["cgb_source_normalized_sha256"] = sidecar["source"]["normalized_geometry_sha256"]
    obj["cgb_working_file_id"] = sidecar["working_file_id"]
    obj["cgb_topology_id"] = sidecar["source"]["topology_id"]
    obj["cgb_topology_revision"] = int(sidecar["source"]["topology_revision"])
    obj["cgb_next_vertex_id"] = int(mesh_source["next_vertex_id"])
    obj["cgb_next_face_id"] = int(mesh_source["next_face_id"])
    obj["cgb_subdivision_policy"] = mesh_source["subdivision_policy"]
    obj["cgb_symmetry_axis"] = "canonical_X"
    if mesh_source["subdivision_policy"] == "catmull_clark_v1":
        modifier = obj.modifiers.new(name="Canonical Catmull-Clark v1 Preview", type="SUBSURF")
        modifier.subdivision_type = "CATMULL_CLARK"
        modifier.levels = 1
        modifier.render_levels = 1
        modifier.show_viewport = False
        modifier.show_render = False
    return obj


def mark_loop_edges(mesh: bpy.types.Mesh, mesh_source: dict[str, Any], document: dict[str, Any]) -> None:
    counts: dict[tuple[int, int], int] = {}
    mesh_id = mesh_source["mesh_id"]
    loop_records: list[dict[str, Any]] = list(mesh_source.get("boundary_loops", []))
    loop_records.extend(item for item in document.get("topology_loops", []) if item["mesh_id"] == mesh_id)
    loop_records.extend(item for item in document.get("seam_bindings", []) if item["mesh_id"] == mesh_id)
    for record in loop_records:
        for edge in record["directed_edges"]:
            key = tuple(sorted((int(edge["from_vertex_id"]), int(edge["to_vertex_id"]))))
            counts[key] = counts.get(key, 0) + 1
    vertex_high = read_int_attribute(mesh, ATTR_VERTEX_ID_HIGH, "POINT")
    vertex_low = read_int_attribute(mesh, ATTR_VERTEX_ID_LOW, "POINT")
    ids = [combine_u32(high, low, "VertexId") for high, low in zip(vertex_high, vertex_low, strict=True)]
    membership: list[int] = []
    for edge in mesh.edges:
        first = ids[edge.vertices[0]]
        second = ids[edge.vertices[1]]
        if first is None or second is None:
            membership.append(0)
            continue
        count = counts.get(tuple(sorted((first, second))), 0)
        membership.append(count)
        edge.use_seam = count > 0
    set_int_attribute(mesh, ATTR_LOOP_MEMBERSHIP_COUNT, "EDGE", membership)


def add_landmark_binding_markers(document: dict[str, Any], objects: dict[str, bpy.types.Object]) -> None:
    collection = bpy.data.collections.new("M03 Canonical Landmark Bindings")
    bpy.context.scene.collection.children.link(collection)
    for binding in document.get("geometry_bindings", []):
        landmark_id = binding.get("landmark_id")
        if landmark_id is None:
            continue
        obj = objects.get(binding["mesh_id"])
        if obj is None:
            raise BridgeError(f"landmark binding references missing mesh {binding['mesh_id']!r}")
        face_id = int(binding["face_id"])
        face_ids = decode_ids(obj.data, "face")
        try:
            polygon_index = face_ids.index(face_id)
        except ValueError as error:
            raise BridgeError(f"landmark binding references missing FaceId {face_id}") from error
        polygon = obj.data.polygons[polygon_index]
        points = [obj.data.vertices[index].co for index in polygon.vertices]
        u = float(binding["local_face_coordinate"][0])
        v = float(binding["local_face_coordinate"][1])
        location = (
            points[0] * ((1.0 - u) * (1.0 - v))
            + points[1] * (u * (1.0 - v))
            + points[2] * (u * v)
            + points[3] * ((1.0 - u) * v)
        )
        marker = bpy.data.objects.new(f"landmark__{landmark_id}", None)
        marker.empty_display_type = "SPHERE"
        marker.empty_display_size = 0.008
        marker.location = location
        marker["cgb_landmark_id"] = landmark_id
        marker["cgb_geometry_binding_id"] = binding["geometry_binding_id"]
        marker["cgb_face_id"] = face_id
        collection.objects.link(marker)


def decode_ids(mesh: bpy.types.Mesh, domain: str) -> list[int | None]:
    if domain == "vertex":
        high_name, low_name, blender_domain = ATTR_VERTEX_ID_HIGH, ATTR_VERTEX_ID_LOW, "POINT"
    elif domain == "face":
        high_name, low_name, blender_domain = ATTR_FACE_ID_HIGH, ATTR_FACE_ID_LOW, "FACE"
    else:
        raise BridgeError(f"unsupported ID domain {domain!r}")
    high_values = read_int_attribute(mesh, high_name, blender_domain)
    low_values = read_int_attribute(mesh, low_name, blender_domain)
    return [
        combine_u32(high, low, f"{domain} ID at element {index}")
        for index, (high, low) in enumerate(zip(high_values, low_values, strict=True))
    ]


def validate_ids(
    label: str,
    ids: list[int | None],
    states: list[int],
    original_ids: set[int],
    original_cursor: int,
    current_cursor: int,
) -> list[int]:
    if len(ids) != len(states):
        raise BridgeError(f"{label} ID/state length mismatch")
    allocated: list[int] = []
    for index, (value, state) in enumerate(zip(ids, states, strict=True)):
        if state == UNALLOCATED_STATE or value is None:
            raise BridgeError(f"{label} element {index} remains UNALLOCATED")
        if state != ALLOCATED_STATE:
            raise BridgeError(f"{label} element {index} has invalid allocation state {state}")
        allocated.append(value)
    if len(set(allocated)) != len(allocated):
        raise BridgeError(f"duplicate canonical {label} ID")
    if current_cursor < original_cursor:
        raise BridgeError(f"{label} allocation cursor regressed")
    if any(value >= current_cursor for value in allocated):
        raise BridgeError(f"{label} ID is not below the allocation cursor")
    for value in allocated:
        if value < original_cursor and value not in original_ids:
            raise BridgeError(f"retired {label} ID {value} was reused")
    return allocated


def require_working_binding(sidecar: dict[str, Any], sidecar_hash: str, source_path: Path) -> None:
    scene = bpy.context.scene
    actual_source_hash = file_sha256(source_path)
    expected = sidecar["source"]["authoritative_sha256"]
    checks = {
        "source authority": (actual_source_hash, expected),
        "scene source authority": (scene.get("cgb_source_authoritative_sha256"), expected),
        "scene normalized source": (scene.get("cgb_source_normalized_sha256"), sidecar["source"]["normalized_geometry_sha256"]),
        "scene bridge schema": (scene.get("cgb_bridge_schema_id"), BRIDGE_SCHEMA_ID),
        "scene bridge version": (scene.get("cgb_bridge_version"), BRIDGE_VERSION),
        "scene Blender version": (scene.get("cgb_blender_version"), "4.5.9 LTS"),
        "scene working file": (scene.get("cgb_working_file_id"), sidecar["working_file_id"]),
        "scene sidecar": (scene.get("cgb_sidecar_sha256"), sidecar_hash),
        "scene structural source": (scene.get("cgb_structural_normalized_sha256"), sidecar["source"]["structural_normalized_sha256"]),
    }
    for label, (actual, wanted) in checks.items():
        if actual != wanted:
            raise BridgeError(f"stale or mismatched {label}: expected {wanted!r}, actual {actual!r}")


def export_mesh(mesh_source: dict[str, Any], obj: bpy.types.Object, sidecar: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    require_identity_transform(obj)
    mesh = obj.data
    if not isinstance(mesh, bpy.types.Mesh):
        raise BridgeError(f"canonical object {obj.name!r} is not a Blender mesh")
    mesh_id = mesh_source["mesh_id"]
    if obj.get("cgb_mesh_id") != mesh_id:
        raise BridgeError(f"object {obj.name!r} has stale mesh identity")
    if obj.get("cgb_source_authoritative_sha256") != sidecar["source"]["authoritative_sha256"]:
        raise BridgeError(f"object {obj.name!r} has stale source identity")
    if obj.get("cgb_working_file_id") != sidecar["working_file_id"]:
        raise BridgeError(f"object {obj.name!r} belongs to a different working file")

    original_vertices = {int(value["vertex_id"]): value for value in mesh_source["vertices"]}
    vertex_ids = validate_ids(
        "VertexId",
        decode_ids(mesh, "vertex"),
        read_int_attribute(mesh, ATTR_VERTEX_STATE, "POINT"),
        set(original_vertices),
        int(mesh_source["next_vertex_id"]),
        int(obj["cgb_next_vertex_id"]),
    )
    vertices = [
        {"vertex_id": vertex_id, "position_m": blender_to_canonical(mesh.vertices[index].co)}
        for index, vertex_id in enumerate(vertex_ids)
    ]
    vertices.sort(key=lambda item: item["vertex_id"])

    original_faces = {int(value["face_id"]): value for value in mesh_source["faces"]}
    face_ids = validate_ids(
        "FaceId",
        decode_ids(mesh, "face"),
        read_int_attribute(mesh, ATTR_FACE_STATE, "FACE"),
        set(original_faces),
        int(mesh_source["next_face_id"]),
        int(obj["cgb_next_face_id"]),
    )
    diagonal = read_int_attribute(mesh, ATTR_DIAGONAL, "FACE")
    primary_surface = read_int_attribute(mesh, ATTR_PRIMARY_SURFACE, "FACE")
    material = read_int_attribute(mesh, ATTR_MATERIAL, "FACE")
    region_set = read_int_attribute(mesh, ATTR_REGION_SET, "FACE")
    semantic_state = read_int_attribute(mesh, ATTR_FACE_SEMANTIC_STATE, "FACE")
    corner_surface = read_int_attribute(mesh, ATTR_CORNER_SURFACE, "CORNER")
    corner_chart = read_int_attribute(mesh, ATTR_CORNER_CHART, "CORNER")
    corner_surface_u = read_float_attribute(mesh, ATTR_CORNER_SURFACE_U, "CORNER")
    corner_surface_v = read_float_attribute(mesh, ATTR_CORNER_SURFACE_V, "CORNER")
    corner_texture_space = read_int_attribute(mesh, ATTR_CORNER_TEXTURE_SPACE, "CORNER")
    corner_uv_island = read_int_attribute(mesh, ATTR_CORNER_UV_ISLAND, "CORNER")
    corner_u = read_float_attribute(mesh, ATTR_CORNER_U, "CORNER")
    corner_v = read_float_attribute(mesh, ATTR_CORNER_V, "CORNER")
    corner_overlap = read_int_attribute(mesh, ATTR_CORNER_OVERLAP, "CORNER")
    tables = sidecar["tables"]

    faces: list[dict[str, Any]] = []
    connectivity_changed = False
    for index, polygon in enumerate(mesh.polygons):
        if semantic_state[index] != ALLOCATED_STATE:
            raise BridgeError(f"FaceId {face_ids[index]} lacks explicitly assigned semantic metadata")
        if len(polygon.vertices) != 4:
            raise BridgeError(f"FaceId {face_ids[index]} is not an authoritative quad")
        ordered_vertex_ids = [vertex_ids[vertex_index] for vertex_index in polygon.vertices]
        face_id = face_ids[index]
        original = original_faces.get(face_id)
        if original is not None and ordered_vertex_ids != [int(value) for value in original["vertex_ids"]]:
            raise BridgeError(
                f"existing FaceId {face_id} connectivity changed; retire it and explicitly allocate a replacement"
            )
        if original is None:
            connectivity_changed = True
        if diagonal[index] not in (0, 1):
            raise BridgeError(f"FaceId {face_id} has invalid triangulation diagonal {diagonal[index]}")
        surface_coordinates: list[dict[str, Any]] = []
        texture_coordinates: list[dict[str, Any]] = []
        for loop_index in polygon.loop_indices:
            surface_coordinates.append({
                "surface_id": require_index(corner_surface[loop_index], tables["surface_ids"], "corner surface"),
                "chart_id": require_index(corner_chart[loop_index], tables["chart_ids"], "chart"),
                "coordinate": [corner_surface_u[loop_index], corner_surface_v[loop_index]],
            })
            overlap_index = corner_overlap[loop_index]
            texture_coordinates.append({
                "texture_space_id": require_index(corner_texture_space[loop_index], tables["texture_space_ids"], "texture space"),
                "uv_island_id": require_index(corner_uv_island[loop_index], tables["uv_island_ids"], "UV island"),
                "uv": [corner_u[loop_index], corner_v[loop_index]],
                "overlap_group_id": None if overlap_index == -1 else require_index(overlap_index, tables["overlap_group_ids"], "overlap group"),
            })
        faces.append({
            "face_id": face_id,
            "vertex_ids": ordered_vertex_ids,
            "diagonal": "v0_v2" if diagonal[index] == 0 else "v1_v3",
            "primary_surface_id": require_index(primary_surface[index], tables["surface_ids"], "primary surface"),
            "material_instance_id": require_index(material[index], tables["material_instance_ids"], "material"),
            "region_ids": list(require_index(region_set[index], tables["region_sets"], "region set")),
            "surface_coordinates": surface_coordinates,
            "texture_coordinates": texture_coordinates,
        })
    faces.sort(key=lambda item: item["face_id"])
    if set(original_faces) != set(face_ids):
        connectivity_changed = True

    exported = copy.deepcopy(mesh_source)
    exported["next_vertex_id"] = int(obj["cgb_next_vertex_id"])
    exported["next_face_id"] = int(obj["cgb_next_face_id"])
    exported["vertices"] = vertices
    exported["faces"] = faces
    return exported, connectivity_changed


def import_command(args: argparse.Namespace) -> None:
    require_blender_version()
    source_path = Path(args.source).resolve()
    working_path = Path(args.working).resolve()
    sidecar_path = Path(args.sidecar).resolve()
    source_bytes = source_path.read_bytes()
    source_hash = sha256_bytes(source_bytes)
    if source_hash != args.source_hash:
        raise BridgeError(f"authoritative source hash mismatch: expected {args.source_hash}, actual {source_hash}")
    document = json.loads(source_bytes)
    if document["structural_compatibility"]["normalized_source_sha256"] != args.structural_hash:
        raise BridgeError("canonical geometry targets an unexpected M02 structural identity")
    sidecar, sidecar_hash = write_sidecar(
        source_path,
        sidecar_path,
        document,
        source_hash,
        args.normalized_hash,
    )
    clear_scene()
    apply_root_properties(sidecar, sidecar_hash)
    objects: dict[str, bpy.types.Object] = {}
    for mesh_source in document["meshes"]:
        obj = build_mesh_object(mesh_source, sidecar)
        objects[mesh_source["mesh_id"]] = obj
    add_landmark_binding_markers(document, objects)
    working_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(working_path), check_existing=False)
    print(
        "BRIDGE_IMPORT_OK "
        f"source_sha256={source_hash} sidecar_sha256={sidecar_hash} "
        f"meshes={len(document['meshes'])} working={working_path}"
    )


def export_command(args: argparse.Namespace) -> None:
    require_blender_version()
    source_path = Path(args.source).resolve()
    candidate_path = Path(args.candidate).resolve()
    if candidate_path == source_path:
        raise BridgeError("candidate export refuses to overwrite the authoritative geometry JSON")
    sidecar, sidecar_hash = require_sidecar(Path(args.sidecar).resolve())
    require_working_binding(sidecar, sidecar_hash, source_path)
    document = copy.deepcopy(sidecar["document_template"])
    object_by_mesh_id = {
        obj.get("cgb_mesh_id"): obj
        for obj in bpy.data.objects
        if obj.type == "MESH" and obj.get("cgb_mesh_id") is not None
    }
    if len(object_by_mesh_id) != len(document["meshes"]):
        raise BridgeError("working file canonical mesh-object count does not match the sidecar")
    exported_meshes: list[dict[str, Any]] = []
    topology_changed = False
    for mesh_source in document["meshes"]:
        obj = object_by_mesh_id.get(mesh_source["mesh_id"])
        if obj is None:
            raise BridgeError(f"working file is missing canonical mesh {mesh_source['mesh_id']!r}")
        exported, changed = export_mesh(mesh_source, obj, sidecar)
        exported_meshes.append(exported)
        topology_changed = topology_changed or changed
    exported_meshes.sort(key=lambda item: item["mesh_id"])
    document["meshes"] = exported_meshes
    source_revision = int(sidecar["source"]["topology_revision"])
    working_revision = int(bpy.context.scene.get("cgb_topology_revision", -1))
    required_revision = source_revision + 1 if topology_changed else source_revision
    if working_revision != required_revision:
        raise BridgeError(
            f"topology revision must be {required_revision} for this candidate; working value is {working_revision}"
        )
    for obj in object_by_mesh_id.values():
        if int(obj.get("cgb_topology_revision", -1)) != working_revision:
            raise BridgeError(f"object {obj.name!r} topology revision does not match the scene")
    document["topology_identity"]["revision"] = working_revision
    encoded = candidate_json_bytes(document)
    candidate_path.parent.mkdir(parents=True, exist_ok=True)
    candidate_path.write_bytes(encoded)
    summary = compare_semantic_identity(
        sidecar["document_template"],
        document,
        allow_position_edits=args.allow_position_edits,
    )
    print(
        "BRIDGE_EXPORT_OK "
        f"candidate_authoring_sha256={sha256_bytes(encoded)} "
        f"vertices={summary['vertex_count']} faces={summary['face_count']} "
        f"position_edits={summary['position_edit_count']} "
        f"semantic_faces={summary['semantic_face_count']} seams={summary['seam_count']} "
        f"bindings={summary['binding_count']} candidate={candidate_path}"
    )


def compare_semantic_identity(
    original: dict[str, Any],
    candidate: dict[str, Any],
    *,
    allow_position_edits: bool = False,
) -> dict[str, int]:
    original_meshes = {mesh["mesh_id"]: mesh for mesh in original["meshes"]}
    candidate_meshes = {mesh["mesh_id"]: mesh for mesh in candidate["meshes"]}
    if set(original_meshes) != set(candidate_meshes):
        raise BridgeError("round-trip mesh identity set changed")
    vertex_count = 0
    face_count = 0
    semantic_face_count = 0
    position_edit_count = 0
    for mesh_id, before in original_meshes.items():
        after = candidate_meshes[mesh_id]
        before_vertices = {int(value["vertex_id"]): value for value in before["vertices"]}
        after_vertices = {int(value["vertex_id"]): value for value in after["vertices"]}
        if set(before_vertices) != set(after_vertices):
            raise BridgeError(f"round-trip VertexId set changed for mesh {mesh_id!r}")
        for vertex_id, before_vertex in before_vertices.items():
            expected = [f32(value) for value in before_vertex["position_m"]]
            actual = [f32(value) for value in after_vertices[vertex_id]["position_m"]]
            if expected != actual:
                if not allow_position_edits:
                    raise BridgeError(f"round-trip f32 position changed for VertexId {vertex_id}")
                position_edit_count += 1
        before_faces = {int(value["face_id"]): value for value in before["faces"]}
        after_faces = {int(value["face_id"]): value for value in after["faces"]}
        if set(before_faces) != set(after_faces):
            raise BridgeError(f"round-trip FaceId set changed for mesh {mesh_id!r}")
        for face_id, before_face in before_faces.items():
            after_face = after_faces[face_id]
            for field in ("vertex_ids", "diagonal", "primary_surface_id", "material_instance_id", "region_ids"):
                if before_face[field] != after_face[field]:
                    raise BridgeError(f"round-trip face {face_id} field {field!r} changed")
            if not corners_equal_f32(before_face["surface_coordinates"], after_face["surface_coordinates"], "coordinate"):
                raise BridgeError(f"round-trip face {face_id} surface coordinates changed")
            if not corners_equal_f32(before_face["texture_coordinates"], after_face["texture_coordinates"], "uv"):
                raise BridgeError(f"round-trip face {face_id} texture coordinates changed")
            semantic_face_count += 1
        if before["next_vertex_id"] != after["next_vertex_id"] or before["next_face_id"] != after["next_face_id"]:
            raise BridgeError(f"round-trip allocation cursor changed for mesh {mesh_id!r}")
        vertex_count += len(before_vertices)
        face_count += len(before_faces)
    for field in ("face_sets", "topology_loops", "seam_bindings", "geometry_bindings", "module_interfaces", "collision_proxies"):
        if original.get(field, []) != candidate.get(field, []):
            raise BridgeError(f"round-trip root semantic field {field!r} changed")
    return {
        "vertex_count": vertex_count,
        "face_count": face_count,
        "semantic_face_count": semantic_face_count,
        "position_edit_count": position_edit_count,
        "seam_count": len(candidate.get("seam_bindings", [])),
        "binding_count": len(candidate.get("geometry_bindings", [])),
    }


def corners_equal_f32(before: list[dict[str, Any]], after: list[dict[str, Any]], numeric_field: str) -> bool:
    if len(before) != len(after):
        return False
    for first, second in zip(before, after, strict=True):
        for key in first:
            if key == numeric_field:
                if [f32(value) for value in first[key]] != [f32(value) for value in second[key]]:
                    return False
            elif first[key] != second.get(key):
                return False
    return True


def allocate_command(args: argparse.Namespace) -> None:
    require_blender_version()
    sidecar, sidecar_hash = require_sidecar(Path(args.sidecar).resolve())
    require_working_binding(sidecar, sidecar_hash, Path(args.source).resolve())
    changed = False
    source_meshes = {mesh["mesh_id"]: mesh for mesh in sidecar["document_template"]["meshes"]}
    for obj in bpy.data.objects:
        mesh_id = obj.get("cgb_mesh_id")
        if obj.type != "MESH" or mesh_id not in source_meshes:
            continue
        changed = allocate_domain(obj, "vertex") or changed
        changed = allocate_domain(obj, "face") or changed
    if changed:
        next_revision = int(sidecar["source"]["topology_revision"]) + 1
        bpy.context.scene["cgb_topology_revision"] = next_revision
        for obj in bpy.data.objects:
            if obj.type == "MESH" and obj.get("cgb_mesh_id") in source_meshes:
                obj["cgb_topology_revision"] = next_revision
        bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, check_existing=False)
    print(f"BRIDGE_ALLOCATION_OK changed={str(changed).lower()}")


def allocate_domain(obj: bpy.types.Object, domain: str) -> bool:
    mesh = obj.data
    if domain == "vertex":
        blender_domain = "POINT"
        state_name = ATTR_VERTEX_STATE
        order_name = ATTR_VERTEX_ALLOCATION_ORDER
        high_name = ATTR_VERTEX_ID_HIGH
        low_name = ATTR_VERTEX_ID_LOW
        cursor_property = "cgb_next_vertex_id"
    else:
        blender_domain = "FACE"
        state_name = ATTR_FACE_STATE
        order_name = ATTR_FACE_ALLOCATION_ORDER
        high_name = ATTR_FACE_ID_HIGH
        low_name = ATTR_FACE_ID_LOW
        cursor_property = "cgb_next_face_id"
    states = read_int_attribute(mesh, state_name, blender_domain)
    orders = read_int_attribute(mesh, order_name, blender_domain)
    highs = read_int_attribute(mesh, high_name, blender_domain)
    lows = read_int_attribute(mesh, low_name, blender_domain)
    pending = [(orders[index], index) for index, state in enumerate(states) if state == UNALLOCATED_STATE]
    if not pending:
        return False
    if any(order <= 0 for order, _ in pending) or len({order for order, _ in pending}) != len(pending):
        raise BridgeError(f"unallocated {domain} elements require unique positive explicit allocation orders")
    pending.sort()
    cursor = int(obj[cursor_property])
    for _, index in pending:
        if cursor > U32_MAX:
            raise BridgeError(f"{domain} allocation cursor exhausted")
        highs[index], lows[index] = split_u32(cursor)
        states[index] = ALLOCATED_STATE
        orders[index] = 0
        cursor += 1
    obj[cursor_property] = cursor
    set_int_attribute(mesh, high_name, blender_domain, highs)
    set_int_attribute(mesh, low_name, blender_domain, lows)
    set_int_attribute(mesh, state_name, blender_domain, states)
    set_int_attribute(mesh, order_name, blender_domain, orders)
    return True


def self_test_command(_: argparse.Namespace) -> None:
    require_blender_version()
    basis = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
    expected = ((1.0, -0.0, 0.0), (0.0, -0.0, 1.0), (0.0, -1.0, 0.0))
    for source, wanted in zip(basis, expected, strict=True):
        converted = canonical_to_blender(source)
        if converted != wanted or blender_to_canonical(converted) != [f32(value) for value in source]:
            raise BridgeError("basis-vector coordinate conversion failed")
    asymmetric = (-0.37125, 1.2345, 0.19875)
    if blender_to_canonical(canonical_to_blender(asymmetric)) != [f32(value) for value in asymmetric]:
        raise BridgeError("asymmetric left/right coordinate round trip failed")
    fixtures = [
        (0.0, 0.0, 0.0),
        (0.0, 1.8288, 0.0),
        (-0.7, 0.0, 0.3),
        (0.1259765625, 0.9876543, -0.333251953125),
    ]
    for fixture in fixtures:
        expected_bits = [struct.pack("<f", value) for value in fixture]
        actual_bits = [struct.pack("<f", value) for value in blender_to_canonical(canonical_to_blender(fixture))]
        if expected_bits != actual_bits:
            raise BridgeError("representative f32 coordinate round trip changed bits")
    x_axis = canonical_to_blender((1.0, 0.0, 0.0))
    y_axis = canonical_to_blender((0.0, 1.0, 0.0))
    z_axis = canonical_to_blender((0.0, 0.0, 1.0))
    cross = (
        x_axis[1] * y_axis[2] - x_axis[2] * y_axis[1],
        x_axis[2] * y_axis[0] - x_axis[0] * y_axis[2],
        x_axis[0] * y_axis[1] - x_axis[1] * y_axis[0],
    )
    if cross != z_axis:
        raise BridgeError("coordinate conversion does not preserve handedness/winding")
    if min(blender_to_canonical(canonical_to_blender(value))[1] for value in fixtures) != 0.0:
        raise BridgeError("ground-plane fixture changed")
    if max(blender_to_canonical(canonical_to_blender(value))[1] for value in fixtures) != f32(1.8288):
        raise BridgeError("canonical-height fixture changed")

    original = {1, 2, 9}
    validate_ids("VertexId", [1, 2, 9], [1, 1, 1], original, 10, 10)
    expected_failures = (
        ([1, 1], [1, 1], original, 10, 10, "duplicate"),
        ([1, None], [1, 0], original, 10, 10, "UNALLOCATED"),
        ([1, 7], [1, 1], original, 10, 10, "retired"),
        ([1, 10], [1, 1], original, 10, 10, "cursor"),
    )
    for ids, states, originals, original_cursor, current_cursor, message in expected_failures:
        try:
            validate_ids("VertexId", ids, states, originals, original_cursor, current_cursor)
        except BridgeError as error:
            if message not in str(error):
                raise BridgeError(f"fail-closed ID test returned unexpected error: {error}") from error
        else:
            raise BridgeError(f"fail-closed ID test did not reject {message}")
    print("BRIDGE_SELF_TEST_OK cases=coordinate_basis,roundtrip,handedness,left_right,winding,ground,height,f32,stable_ids,duplicate,unallocated,retired,cursor")


def negative_test_command(args: argparse.Namespace) -> None:
    require_blender_version()
    source_path = Path(args.source).resolve()
    sidecar, sidecar_hash = require_sidecar(Path(args.sidecar).resolve())
    require_working_binding(sidecar, sidecar_hash, source_path)
    scene = bpy.context.scene
    original_hash = scene["cgb_sidecar_sha256"]
    scene["cgb_sidecar_sha256"] = "0" * 64
    expect_bridge_error(
        lambda: require_working_binding(sidecar, sidecar_hash, source_path),
        "stale or mismatched scene sidecar",
    )
    scene["cgb_sidecar_sha256"] = original_hash
    original_source = scene["cgb_source_authoritative_sha256"]
    scene["cgb_source_authoritative_sha256"] = "f" * 64
    expect_bridge_error(
        lambda: require_working_binding(sidecar, sidecar_hash, source_path),
        "stale or mismatched scene source authority",
    )
    scene["cgb_source_authoritative_sha256"] = original_source
    temporary = bpy.data.meshes.new("cgb_negative_missing_attribute")
    try:
        expect_bridge_error(
            lambda: read_int_attribute(temporary, ATTR_VERTEX_ID_HIGH, "POINT"),
            "missing or incompatible",
        )
    finally:
        bpy.data.meshes.remove(temporary)
    expect_bridge_error(lambda: require_index(-1, ["valid"], "semantic"), "invalid")
    expect_bridge_error(lambda: require_index(1, ["valid"], "semantic"), "invalid")
    obj = canonical_objects()[0]
    semantic_states = read_int_attribute(obj.data, ATTR_FACE_SEMANTIC_STATE, "FACE")
    semantic_states[0] = UNALLOCATED_STATE
    set_int_attribute(obj.data, ATTR_FACE_SEMANTIC_STATE, "FACE", semantic_states)
    mesh_source = next(
        value for value in sidecar["document_template"]["meshes"]
        if value["mesh_id"] == obj["cgb_mesh_id"]
    )
    expect_bridge_error(
        lambda: export_mesh(mesh_source, obj, sidecar),
        "lacks explicitly assigned semantic metadata",
    )
    semantic_states[0] = ALLOCATED_STATE
    set_int_attribute(obj.data, ATTR_FACE_SEMANTIC_STATE, "FACE", semantic_states)
    print(
        "BRIDGE_NEGATIVE_TEST_OK "
        "cases=stale_source,stale_sidecar,missing_id,invalid_semantic_index,missing_face_semantics"
    )


def expect_bridge_error(operation: Any, expected_text: str) -> None:
    try:
        operation()
    except BridgeError as error:
        if expected_text not in str(error):
            raise BridgeError(f"negative test expected {expected_text!r}, actual error was {error!r}") from error
    else:
        raise BridgeError(f"negative test did not fail closed for {expected_text!r}")


def canonical_objects() -> list[bpy.types.Object]:
    return [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.get("cgb_mesh_id") is not None]


def select_polygons(obj: bpy.types.Object, polygon_indexes: set[int]) -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for polygon in obj.data.polygons:
        polygon.select = polygon.index in polygon_indexes


def select_face_set_command(args: argparse.Namespace) -> None:
    sidecar, sidecar_hash = require_sidecar(Path(args.sidecar).resolve())
    require_working_binding(sidecar, sidecar_hash, Path(args.source).resolve())
    record = next(
        (value for value in sidecar["document_template"].get("face_sets", []) if value["face_set_id"] == args.face_set_id),
        None,
    )
    if record is None:
        raise BridgeError(f"unknown canonical face set {args.face_set_id!r}")
    obj = next((value for value in canonical_objects() if value.get("cgb_mesh_id") == record["mesh_id"]), None)
    if obj is None:
        raise BridgeError(f"face set mesh {record['mesh_id']!r} is missing")
    face_ids = decode_ids(obj.data, "face")
    wanted = {int(value) for value in record["face_ids"]}
    indexes = {index for index, value in enumerate(face_ids) if value in wanted}
    if len(indexes) != len(wanted):
        raise BridgeError("face-set selection found stale or missing FaceIds")
    select_polygons(obj, indexes)
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, check_existing=False)
    print(f"BRIDGE_SELECT_OK kind=face_set id={args.face_set_id} faces={len(indexes)}")


def select_region_command(args: argparse.Namespace) -> None:
    sidecar, sidecar_hash = require_sidecar(Path(args.sidecar).resolve())
    require_working_binding(sidecar, sidecar_hash, Path(args.source).resolve())
    selected = 0
    selected_object: bpy.types.Object | None = None
    selected_indexes: set[int] = set()
    for obj in canonical_objects():
        region_indexes = read_int_attribute(obj.data, ATTR_REGION_SET, "FACE")
        indexes = {
            index
            for index, region_index in enumerate(region_indexes)
            if args.region_id in require_index(region_index, sidecar["tables"]["region_sets"], "region set")
        }
        if indexes:
            if selected_object is not None:
                raise BridgeError("region selection spans multiple meshes; select each mesh explicitly")
            selected_object = obj
            selected_indexes = indexes
            selected += len(indexes)
    if selected_object is None:
        raise BridgeError(f"no faces belong to canonical region {args.region_id!r}")
    select_polygons(selected_object, selected_indexes)
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, check_existing=False)
    print(f"BRIDGE_SELECT_OK kind=region id={args.region_id} faces={selected}")


def mark_unallocated_command(args: argparse.Namespace) -> None:
    sidecar, sidecar_hash = require_sidecar(Path(args.sidecar).resolve())
    require_working_binding(sidecar, sidecar_hash, Path(args.source).resolve())
    obj = next((value for value in canonical_objects() if value.get("cgb_mesh_id") == args.mesh_id), None)
    if obj is None:
        raise BridgeError(f"unknown canonical mesh {args.mesh_id!r}")
    vertex_indexes = parse_explicit_indexes(args.vertex_indexes)
    face_indexes = parse_explicit_indexes(args.face_indexes)
    mark_domain_unallocated(obj, "vertex", vertex_indexes)
    mark_domain_unallocated(obj, "face", face_indexes)
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, check_existing=False)
    print(
        f"BRIDGE_MARK_UNALLOCATED_OK mesh={args.mesh_id} "
        f"vertices={len(vertex_indexes)} faces={len(face_indexes)}"
    )


def parse_explicit_indexes(text: str) -> list[int]:
    if text.strip() == "":
        return []
    values = [int(value) for value in text.split(",")]
    if any(value < 0 for value in values) or len(set(values)) != len(values):
        raise BridgeError("explicit Blender element indexes must be unique non-negative integers")
    return values


def mark_domain_unallocated(obj: bpy.types.Object, domain: str, indexes: list[int]) -> None:
    if not indexes:
        return
    if domain == "vertex":
        blender_domain = "POINT"
        count = len(obj.data.vertices)
        state_name = ATTR_VERTEX_STATE
        order_name = ATTR_VERTEX_ALLOCATION_ORDER
        high_name = ATTR_VERTEX_ID_HIGH
        low_name = ATTR_VERTEX_ID_LOW
    else:
        blender_domain = "FACE"
        count = len(obj.data.polygons)
        state_name = ATTR_FACE_STATE
        order_name = ATTR_FACE_ALLOCATION_ORDER
        high_name = ATTR_FACE_ID_HIGH
        low_name = ATTR_FACE_ID_LOW
    if any(index >= count for index in indexes):
        raise BridgeError(f"explicit {domain} index is outside the current Blender mesh")
    states = read_int_attribute(obj.data, state_name, blender_domain)
    orders = read_int_attribute(obj.data, order_name, blender_domain)
    highs = read_int_attribute(obj.data, high_name, blender_domain)
    lows = read_int_attribute(obj.data, low_name, blender_domain)
    for order, index in enumerate(indexes, start=1):
        states[index] = UNALLOCATED_STATE
        orders[index] = order
        highs[index] = UNALLOCATED_HALF
        lows[index] = UNALLOCATED_HALF
    set_int_attribute(obj.data, state_name, blender_domain, states)
    set_int_attribute(obj.data, order_name, blender_domain, orders)
    set_int_attribute(obj.data, high_name, blender_domain, highs)
    set_int_attribute(obj.data, low_name, blender_domain, lows)


def invalid_candidate_command(args: argparse.Namespace) -> None:
    source_path = Path(args.candidate).resolve()
    output_path = Path(args.output).resolve()
    if source_path == output_path:
        raise BridgeError("invalid-fixture generation refuses to overwrite its valid candidate")
    document = json.loads(source_path.read_bytes())
    document["meshes"][0]["faces"][0]["primary_surface_id"] = "bridge_invalid_surface"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(candidate_json_bytes(document))
    print(f"BRIDGE_INVALID_CANDIDATE_OK output={output_path}")


def copy_face_semantics_command(args: argparse.Namespace) -> None:
    sidecar, sidecar_hash = require_sidecar(Path(args.sidecar).resolve())
    require_working_binding(sidecar, sidecar_hash, Path(args.source).resolve())
    obj = next((value for value in canonical_objects() if value.get("cgb_mesh_id") == args.mesh_id), None)
    if obj is None:
        raise BridgeError(f"unknown canonical mesh {args.mesh_id!r}")
    face_ids = decode_ids(obj.data, "face")
    try:
        source_index = face_ids.index(args.source_face_id)
    except ValueError as error:
        raise BridgeError(f"semantic source FaceId {args.source_face_id} is absent") from error
    targets = parse_explicit_indexes(args.target_polygon_indexes)
    if not targets or any(index >= len(obj.data.polygons) for index in targets):
        raise BridgeError("semantic target polygon indexes must identify existing Blender quads")
    face_attributes = (ATTR_DIAGONAL, ATTR_PRIMARY_SURFACE, ATTR_MATERIAL, ATTR_REGION_SET)
    face_values = {name: read_int_attribute(obj.data, name, "FACE") for name in face_attributes}
    semantic_states = read_int_attribute(obj.data, ATTR_FACE_SEMANTIC_STATE, "FACE")
    corner_int_attributes = (
        ATTR_CORNER_SURFACE,
        ATTR_CORNER_CHART,
        ATTR_CORNER_TEXTURE_SPACE,
        ATTR_CORNER_UV_ISLAND,
        ATTR_CORNER_OVERLAP,
    )
    corner_float_attributes = (
        ATTR_CORNER_SURFACE_U,
        ATTR_CORNER_SURFACE_V,
        ATTR_CORNER_U,
        ATTR_CORNER_V,
    )
    corner_int_values = {name: read_int_attribute(obj.data, name, "CORNER") for name in corner_int_attributes}
    corner_float_values = {name: read_float_attribute(obj.data, name, "CORNER") for name in corner_float_attributes}
    source_polygon = obj.data.polygons[source_index]
    if len(source_polygon.loop_indices) != 4:
        raise BridgeError("semantic source face is not a quad")
    for target_index in targets:
        target_polygon = obj.data.polygons[target_index]
        if len(target_polygon.loop_indices) != 4:
            raise BridgeError(f"semantic target polygon {target_index} is not a quad")
        for name in face_attributes:
            face_values[name][target_index] = face_values[name][source_index]
        for source_loop, target_loop in zip(source_polygon.loop_indices, target_polygon.loop_indices, strict=True):
            for name in corner_int_attributes:
                corner_int_values[name][target_loop] = corner_int_values[name][source_loop]
            for name in corner_float_attributes:
                corner_float_values[name][target_loop] = corner_float_values[name][source_loop]
        semantic_states[target_index] = ALLOCATED_STATE
    for name in face_attributes:
        set_int_attribute(obj.data, name, "FACE", face_values[name])
    set_int_attribute(obj.data, ATTR_FACE_SEMANTIC_STATE, "FACE", semantic_states)
    for name in corner_int_attributes:
        set_int_attribute(obj.data, name, "CORNER", corner_int_values[name])
    for name in corner_float_attributes:
        set_float_attribute(obj.data, name, "CORNER", corner_float_values[name])
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, check_existing=False)
    print(
        f"BRIDGE_COPY_SEMANTICS_OK mesh={args.mesh_id} source_face_id={args.source_face_id} "
        f"targets={len(targets)}"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Canonical geometry Blender bridge")
    subparsers = parser.add_subparsers(dest="command", required=True)
    importer = subparsers.add_parser("import")
    importer.add_argument("--source", required=True)
    importer.add_argument("--source-hash", required=True)
    importer.add_argument("--normalized-hash", required=True)
    importer.add_argument("--structural-hash", required=True)
    importer.add_argument("--working", required=True)
    importer.add_argument("--sidecar", required=True)
    importer.set_defaults(handler=import_command)
    exporter = subparsers.add_parser("export")
    exporter.add_argument("--source", required=True)
    exporter.add_argument("--sidecar", required=True)
    exporter.add_argument("--candidate", required=True)
    exporter.add_argument("--allow-position-edits", action="store_true")
    exporter.set_defaults(handler=export_command)
    allocator = subparsers.add_parser("allocate")
    allocator.add_argument("--source", required=True)
    allocator.add_argument("--sidecar", required=True)
    allocator.set_defaults(handler=allocate_command)
    self_test = subparsers.add_parser("self-test")
    self_test.set_defaults(handler=self_test_command)
    negative_test = subparsers.add_parser("negative-test")
    negative_test.add_argument("--source", required=True)
    negative_test.add_argument("--sidecar", required=True)
    negative_test.set_defaults(handler=negative_test_command)
    face_set = subparsers.add_parser("select-face-set")
    face_set.add_argument("--source", required=True)
    face_set.add_argument("--sidecar", required=True)
    face_set.add_argument("--face-set-id", required=True)
    face_set.set_defaults(handler=select_face_set_command)
    region = subparsers.add_parser("select-region")
    region.add_argument("--source", required=True)
    region.add_argument("--sidecar", required=True)
    region.add_argument("--region-id", required=True)
    region.set_defaults(handler=select_region_command)
    unallocated = subparsers.add_parser("mark-unallocated")
    unallocated.add_argument("--source", required=True)
    unallocated.add_argument("--sidecar", required=True)
    unallocated.add_argument("--mesh-id", required=True)
    unallocated.add_argument("--vertex-indexes", default="")
    unallocated.add_argument("--face-indexes", default="")
    unallocated.set_defaults(handler=mark_unallocated_command)
    invalid_candidate = subparsers.add_parser("make-invalid-candidate")
    invalid_candidate.add_argument("--candidate", required=True)
    invalid_candidate.add_argument("--output", required=True)
    invalid_candidate.set_defaults(handler=invalid_candidate_command)
    copy_semantics = subparsers.add_parser("copy-face-semantics")
    copy_semantics.add_argument("--source", required=True)
    copy_semantics.add_argument("--sidecar", required=True)
    copy_semantics.add_argument("--mesh-id", required=True)
    copy_semantics.add_argument("--source-face-id", required=True, type=int)
    copy_semantics.add_argument("--target-polygon-indexes", required=True)
    copy_semantics.set_defaults(handler=copy_face_semantics_command)
    return parser


def main() -> int:
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = build_parser()
    args = parser.parse_args(arguments)
    try:
        args.handler(args)
    except (BridgeError, KeyError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"BLENDER_BRIDGE_ERROR: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
