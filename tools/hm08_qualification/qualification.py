#!/usr/bin/env python3
"""Deterministic, read-only qualification of the pinned MPFB hm08 base mesh."""

from __future__ import annotations

import argparse
import collections
import hashlib
import json
import math
import os
import re
import statistics
import sys
from pathlib import Path

try:
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
except ImportError:
    bpy = None
    Vector = None
    BVHTree = None


MPFB_COMMIT = "437dd513888a92399d1d3200d2e80859fae55abc"
ASSET_SHA256 = "bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950"
LICENSE_SHA256 = "5f3ab0cf6f7ebe92efe4b83213131c617d308d164eeefd5da230373640b0c226"
CONFIG_SHA256 = "e8450599c2f97642f2cfa70d2163b70b7d796d552b4b69f8a9f7c52ec7a44a0a"
MIRROR_SHA256 = "e375beaf66dabd49b31af45dd497d9408a76db41870af523d1eb8476980b894e"
VERTEX_GROUPS_SHA256 = "cd88834f7353333820bd054f0a2a492f684daa2c84d8542e1007d6748a797a8e"
R1_SOURCE_SHA256 = "e501458b9cf78991aa4290bcecd81ebcc5cb112d4c735c2a9e0a381653766623"
R1_NORMALIZED_SHA256 = "88ed9f846a3ddc048bf219e5f8f63d6ffa75e167a07e64ecc527f1fec1be56ae"
R1_TOPOLOGY_SHA256 = "23a3575d1e8aa25bc14f630ead9e5f1fabef36b18acfccd0cdc407a6e750b931"
R1_TRIANGULATION_SHA256 = "1e587d27b6524888f14fe50b9e8912f107dea8627abf9435378f556d65f5fc5b"
R1_NEUTRAL_SIGNATURE = "aa7352786b5e564f2bab96f4f12edcaf08a837204ab70667be75a0ca488e89c8"
M02_SHA256 = "b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda"
M02_AUTHORING_SHA256 = "61127b694b5bfce3148f6ac2a4c40f11bf981cc4a72ab6427bbd3bd878e8eb88"
CANONICAL_HEIGHT_M = 1.8288
VISIBLE_VERTEX_COUNT = 13380
BRIDGE_SCHEMA = "hm08_qualification_bridge"
BRIDGE_VERSION = "1.0.0"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    position = fraction * (len(ordered) - 1)
    lower = int(math.floor(position))
    upper = min(lower + 1, len(ordered) - 1)
    amount = position - lower
    return ordered[lower] * (1.0 - amount) + ordered[upper] * amount


def vec_sub(a: tuple[float, float, float], b: tuple[float, float, float]):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vec_dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def vec_cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def vec_length(a):
    return math.sqrt(vec_dot(a, a))


def canonical_to_blender(position):
    return (position[0], -position[2], position[1])


def parse_obj(path: Path):
    vertices: list[tuple[float, float, float]] = []
    texcoords: list[tuple[float, float]] = []
    grouped_faces: dict[str, list[tuple[tuple[int, ...], tuple[int, ...]]]] = collections.defaultdict(list)
    group = "ungrouped"
    material_names: set[str] = set()
    with path.open("r", encoding="utf-8") as stream:
        for line_number, raw in enumerate(stream, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if parts[0] == "v":
                if len(parts) != 4:
                    raise ValueError(f"invalid vertex at OBJ line {line_number}")
                vertices.append((float(parts[1]), float(parts[2]), float(parts[3])))
            elif parts[0] == "vt":
                if len(parts) < 3:
                    raise ValueError(f"invalid texture coordinate at OBJ line {line_number}")
                texcoords.append((float(parts[1]), float(parts[2])))
            elif parts[0] == "g":
                group = " ".join(parts[1:])
            elif parts[0] == "usemtl":
                material_names.add(" ".join(parts[1:]))
            elif parts[0] == "f":
                face_vertices: list[int] = []
                face_texcoords: list[int] = []
                for token in parts[1:]:
                    fields = token.split("/")
                    vertex_index = int(fields[0])
                    if vertex_index <= 0:
                        raise ValueError(f"relative or zero vertex index at OBJ line {line_number}")
                    face_vertices.append(vertex_index - 1)
                    if len(fields) > 1 and fields[1]:
                        texture_index = int(fields[1])
                        if texture_index <= 0:
                            raise ValueError(f"relative or zero texture index at OBJ line {line_number}")
                        face_texcoords.append(texture_index - 1)
                grouped_faces[group].append((tuple(face_vertices), tuple(face_texcoords)))
    return vertices, texcoords, dict(grouped_faces), sorted(material_names)


def face_edges(face):
    return [tuple(sorted((face[index], face[(index + 1) % len(face)]))) for index in range(len(face))]


def connected_components(vertex_count: int, faces: list[tuple[int, ...]]):
    adjacency: list[set[int]] = [set() for _ in range(vertex_count)]
    used: set[int] = set()
    for face in faces:
        used.update(face)
        for index, vertex in enumerate(face):
            other = face[(index + 1) % len(face)]
            adjacency[vertex].add(other)
            adjacency[other].add(vertex)
    remaining = set(used)
    component_sizes: list[int] = []
    while remaining:
        root = min(remaining)
        stack = [root]
        remaining.remove(root)
        count = 0
        while stack:
            vertex = stack.pop()
            count += 1
            for other in adjacency[vertex]:
                if other in remaining:
                    remaining.remove(other)
                    stack.append(other)
        component_sizes.append(count)
    return sorted(component_sizes, reverse=True), adjacency, used


def topology_metrics(vertices, faces, texcoord_faces):
    edge_counts: collections.Counter[tuple[int, int]] = collections.Counter()
    duplicate_face_count = 0
    degenerate_face_count = 0
    face_signatures: set[tuple[int, ...]] = set()
    aspect_ratios: list[float] = []
    edge_lengths: list[float] = []
    arity_counts: collections.Counter[int] = collections.Counter()
    for face in faces:
        arity_counts[len(face)] += 1
        if len(set(face)) != len(face):
            degenerate_face_count += 1
        signature = tuple(sorted(face))
        if signature in face_signatures:
            duplicate_face_count += 1
        face_signatures.add(signature)
        local_lengths: list[float] = []
        for edge in face_edges(face):
            edge_counts[edge] += 1
            length = vec_length(vec_sub(vertices[edge[0]], vertices[edge[1]]))
            local_lengths.append(length)
            edge_lengths.append(length)
        if local_lengths and min(local_lengths) > 0.0:
            aspect_ratios.append(max(local_lengths) / min(local_lengths))
        else:
            aspect_ratios.append(float("inf"))
            degenerate_face_count += 1
    component_sizes, adjacency, used = connected_components(len(vertices), faces)
    valences = [len(adjacency[index]) for index in sorted(used)]
    valence_counts = collections.Counter(valences)
    boundary_edges = [edge for edge, count in edge_counts.items() if count == 1]
    non_manifold_edges = [edge for edge, count in edge_counts.items() if count > 2]
    duplicate_positions = len(vertices) - len(set(vertices))
    body_texture_corner_count = sum(len(face) for face in texcoord_faces)
    body_corner_count = sum(len(face) for face in faces)
    return {
        "vertex_count": len(vertices),
        "used_vertex_count": len(used),
        "unused_vertex_count": len(vertices) - len(used),
        "face_count": len(faces),
        "arity_counts": {str(key): arity_counts[key] for key in sorted(arity_counts)},
        "quad_percentage": 100.0 * arity_counts[4] / len(faces) if faces else 0.0,
        "boundary_edge_count": len(boundary_edges),
        "non_manifold_edge_count": len(non_manifold_edges),
        "connected_component_count": len(component_sizes),
        "connected_component_vertex_counts": component_sizes,
        "duplicate_position_count": duplicate_positions,
        "duplicate_face_count": duplicate_face_count,
        "degenerate_face_count": degenerate_face_count,
        "uv_corner_coverage": body_texture_corner_count / body_corner_count if body_corner_count else 0.0,
        "aspect_ratio": {
            "maximum": max(aspect_ratios) if aspect_ratios else 0.0,
            "p95": percentile(aspect_ratios, 0.95),
            "p99": percentile(aspect_ratios, 0.99),
            "over_8_count": sum(1 for value in aspect_ratios if value > 8.0),
        },
        "edge_length_native": {
            "minimum": min(edge_lengths) if edge_lengths else 0.0,
            "median": statistics.median(edge_lengths) if edge_lengths else 0.0,
            "p95": percentile(edge_lengths, 0.95),
            "p99": percentile(edge_lengths, 0.99),
            "maximum": max(edge_lengths) if edge_lengths else 0.0,
        },
        "valence_distribution": {str(key): valence_counts[key] for key in sorted(valence_counts)},
        "extraordinary_vertex_count": sum(1 for value in valences if value != 4),
        "boundary_edges": boundary_edges,
        "non_manifold_edges": non_manifold_edges,
        "adjacency": adjacency,
        "aspect_ratios": aspect_ratios,
    }


def parse_mirror(path: Path):
    mapping: dict[int, tuple[int, str]] = {}
    with path.open("r", encoding="utf-8") as stream:
        for line_number, raw in enumerate(stream, 1):
            parts = raw.split()
            if not parts:
                continue
            if len(parts) != 3:
                raise ValueError(f"invalid mirror record at line {line_number}")
            mapping[int(parts[0])] = (int(parts[1]), parts[2])
    return mapping


def symmetry_metrics(vertices, mirror_path: Path):
    mapping = parse_mirror(mirror_path)
    errors: list[float] = []
    missing: list[int] = []
    bad_reciprocal: list[int] = []
    for index in range(VISIBLE_VERTEX_COUNT):
        if index not in mapping:
            missing.append(index)
            continue
        other, side = mapping[index]
        if other < 0 or other >= VISIBLE_VERTEX_COUNT:
            missing.append(index)
            continue
        if mapping.get(other, (-1, ""))[0] != index:
            bad_reciprocal.append(index)
        a = vertices[index]
        b = vertices[other]
        errors.append(math.sqrt((a[0] + b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2))
        if side not in ("l", "r", "m"):
            raise ValueError(f"invalid mirror side marker {side!r} for vertex {index}")
    return {
        "mapping_record_count": len(mapping),
        "visible_missing_count": len(missing),
        "visible_nonreciprocal_count": len(bad_reciprocal),
        "maximum_position_error_native": max(errors) if errors else 0.0,
        "p99_position_error_native": percentile(errors, 0.99),
        "exact_position_match_count": sum(1 for error in errors if error == 0.0),
    }


def native_alignment(vertices):
    xs = [position[0] for position in vertices]
    ys = [position[1] for position in vertices]
    zs = [position[2] for position in vertices]
    native_height = max(ys) - min(ys)
    scale = CANONICAL_HEIGHT_M / native_height
    x_center = (min(xs) + max(xs)) * 0.5
    minimum_y = min(ys)
    ground_vertices = [position for position in vertices if position[1] <= minimum_y + 1.0e-4]
    return {
        "native_bbox": {
            "minimum": [min(xs), min(ys), min(zs)],
            "maximum": [max(xs), max(ys), max(zs)],
        },
        "native_height": native_height,
        "scale_native_to_meters": scale,
        "translation_before_scale": [-x_center, -min(ys), 0.0],
        "axis_mapping": "hm08 (X,Y,Z) -> canonical (X,Y,Z)",
        "canonical_height": CANONICAL_HEIGHT_M,
        "canonical_ground_y": 0.0,
        "native_ground_contact_vertex_count": len(ground_vertices),
        "native_ground_contact_x_range": [min(position[0] for position in ground_vertices), max(position[0] for position in ground_vertices)],
        "native_ground_contact_z_range": [min(position[2] for position in ground_vertices), max(position[2] for position in ground_vertices)],
    }


def align_native(position, alignment):
    translation = alignment["translation_before_scale"]
    scale = alignment["scale_native_to_meters"]
    return (
        (position[0] + translation[0]) * scale,
        (position[1] + translation[1]) * scale,
        (position[2] + translation[2]) * scale,
    )


def helper_metrics(vertices, grouped_faces):
    results = []
    for group in sorted(grouped_faces):
        if group == "body":
            continue
        faces = [record[0] for record in grouped_faces[group]]
        referenced = sorted({vertex for face in faces for vertex in face})
        components, _adjacency, _used = connected_components(len(vertices), faces)
        edge_counts: collections.Counter[tuple[int, int]] = collections.Counter()
        arities = collections.Counter()
        for face in faces:
            arities[len(face)] += 1
            edge_counts.update(face_edges(face))
        results.append({
            "group": group,
            "face_count": len(faces),
            "referenced_vertex_count": len(referenced),
            "minimum_vertex_id": min(referenced) if referenced else None,
            "maximum_vertex_id": max(referenced) if referenced else None,
            "arity_counts": {str(key): arities[key] for key in sorted(arities)},
            "boundary_edge_count": sum(1 for count in edge_counts.values() if count == 1),
            "non_manifold_edge_count": sum(1 for count in edge_counts.values() if count > 2),
            "connected_component_count": len(components),
        })
    return results


def helper_category_inventory(helper_records):
    categories = {
        "tongue": (lambda name: name == "helper-tongue", "useful anatomical and topology reference"),
        "eyes": (lambda name: name in {"helper-l-eye", "helper-r-eye"}, "useful anatomical and topology reference"),
        "eyelashes": (lambda name: name.startswith("helper-l-eyelashes") or name.startswith("helper-r-eyelashes"), "useful semantic mapping reference"),
        "teeth": (lambda name: name in {"helper-upper-teeth", "helper-lower-teeth"}, "useful anatomical reference; not individual canonical dentition"),
        "genital": (lambda name: name == "helper-genital", "useful receiver-area and topology reference; incomplete adult anatomy"),
        "joint_cubes": (lambda name: name.startswith("joint-"), "useful alignment reference; incompatible as canonical geometry or skeleton"),
        "garment_helpers": (lambda name: name in {"helper-skirt", "helper-tights"}, "irrelevant to shared-body topology qualification"),
        "hair_helper": (lambda name: name == "helper-hair", "irrelevant to shared-body topology qualification"),
    }
    output = {}
    for category, (predicate, classification) in categories.items():
        selected = [record for record in helper_records if predicate(record["group"])]
        output[category] = {
            "groups": [record["group"] for record in selected],
            "group_count": len(selected),
            "referenced_vertex_count_sum": sum(record["referenced_vertex_count"] for record in selected),
            "face_count_sum": sum(record["face_count"] for record in selected),
            "classification": classification,
        }
    return output


def helper_centers(vertices, grouped_faces, alignment):
    centers = {}
    for group in sorted(grouped_faces):
        if not group.startswith("joint-"):
            continue
        referenced = sorted({vertex for record in grouped_faces[group] for vertex in record[0]})
        if not referenced:
            continue
        aligned = [align_native(vertices[index], alignment) for index in referenced]
        centers[group] = [
            sum(position[axis] for position in aligned) / len(aligned) for axis in range(3)
        ]
    return centers


def parse_landmarks(report_path: Path):
    pattern = re.compile(
        r"^landmark id=(\S+) anchor=(\S+) mirror=(\S+) "
        r"world=\.\{ \.x = ([^,]+), \.y = ([^,]+), \.z = ([^ }]+) \}$"
    )
    landmarks = []
    for raw in report_path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(raw)
        if match:
            landmarks.append({
                "landmark_id": match.group(1),
                "anchor_id": match.group(2),
                "mirror_id": None if match.group(3) == "null" else match.group(3),
                "structural_position": [float(match.group(4)), float(match.group(5)), float(match.group(6))],
            })
    if len(landmarks) != 35:
        raise ValueError(f"expected 35 structural landmarks, parsed {len(landmarks)}")
    return landmarks


SURFACE_LANDMARKS = {
    "chin_landmark",
    "face_center_landmark",
    "head_top_landmark",
    "heel_left_landmark",
    "heel_right_landmark",
    "navel_landmark",
    "sternum_center_landmark",
    "toe_tip_left_landmark",
    "toe_tip_right_landmark",
    "waist_center_landmark",
    "fingertip_thumb_left_landmark",
    "fingertip_thumb_right_landmark",
    "fingertip_index_left_landmark",
    "fingertip_index_right_landmark",
    "fingertip_middle_left_landmark",
    "fingertip_middle_right_landmark",
    "fingertip_ring_left_landmark",
    "fingertip_ring_right_landmark",
    "fingertip_little_left_landmark",
    "fingertip_little_right_landmark",
}


def triangulate_quads(faces):
    triangles = []
    source_faces = []
    for face_index, face in enumerate(faces):
        if len(face) == 3:
            triangles.append(face)
            source_faces.append(face_index)
        elif len(face) == 4:
            triangles.append((face[0], face[1], face[2]))
            source_faces.append(face_index)
            triangles.append((face[0], face[2], face[3]))
            source_faces.append(face_index)
        else:
            for corner in range(1, len(face) - 1):
                triangles.append((face[0], face[corner], face[corner + 1]))
                source_faces.append(face_index)
    return triangles, source_faces


def triangle_intersects(a, b, vertices, epsilon=1.0e-10):
    points_a = [vertices[index] for index in a]
    points_b = [vertices[index] for index in b]
    edges_a = [vec_sub(points_a[(index + 1) % 3], points_a[index]) for index in range(3)]
    edges_b = [vec_sub(points_b[(index + 1) % 3], points_b[index]) for index in range(3)]
    axes = [vec_cross(edges_a[0], edges_a[1]), vec_cross(edges_b[0], edges_b[1])]
    axes.extend(vec_cross(edge_a, edge_b) for edge_a in edges_a for edge_b in edges_b)
    for axis in axes:
        length = vec_length(axis)
        if length <= epsilon:
            continue
        projections_a = [vec_dot(point, axis) for point in points_a]
        projections_b = [vec_dot(point, axis) for point in points_b]
        tolerance = epsilon * length
        if max(projections_a) < min(projections_b) - tolerance:
            return False
        if max(projections_b) < min(projections_a) - tolerance:
            return False
    return True


def self_intersection_metrics(vertices, faces):
    if BVHTree is None or Vector is None:
        return {"status": "not_run_outside_blender"}
    triangles, source_faces = triangulate_quads(faces)
    vectors = [Vector(position) for position in vertices]
    tree = BVHTree.FromPolygons(vectors, triangles, all_triangles=True, epsilon=1.0e-8)
    candidate_pairs = set()
    for left, right in tree.overlap(tree):
        if left >= right:
            continue
        triangle_left = triangles[left]
        triangle_right = triangles[right]
        if source_faces[left] == source_faces[right]:
            continue
        if set(triangle_left).intersection(triangle_right):
            continue
        candidate_pairs.add((left, right))
    intersections = []
    for left, right in sorted(candidate_pairs):
        if triangle_intersects(triangles[left], triangles[right], vertices):
            intersections.append({
                "triangle_a": left,
                "triangle_b": right,
                "face_a": source_faces[left],
                "face_b": source_faces[right],
            })
    return {
        "status": "completed",
        "nonadjacent_bvh_candidate_count": len(candidate_pairs),
        "detected_nonadjacent_triangle_intersection_count": len(intersections),
        "intersections": intersections,
    }


def region_for_position(position):
    x, y, z = position
    absolute_x = abs(x)
    if y > 1.48:
        return "head_face"
    if y > 1.28 and absolute_x > 0.24:
        return "shoulder_arm"
    if y > 0.98 and absolute_x > 0.55:
        return "hand_fingers"
    if 1.02 < y <= 1.48:
        return "torso_breast"
    if 0.78 < y <= 1.02:
        return "pelvis_groin_glute"
    if 0.39 < y <= 0.62:
        return "knee"
    if 0.12 < y <= 0.28:
        return "ankle_achilles"
    if y <= 0.16:
        return "foot_toes"
    return "limbs_other"


def critical_region_metrics(aligned_vertices, faces, metrics):
    result: dict[str, dict[str, object]] = {}
    face_regions = []
    for face in faces:
        center = tuple(sum(aligned_vertices[index][axis] for index in face) / len(face) for axis in range(3))
        face_regions.append(region_for_position(center))
    for region in sorted(set(face_regions)):
        face_indexes = [index for index, value in enumerate(face_regions) if value == region]
        ratios = [metrics["aspect_ratios"][index] for index in face_indexes]
        region_vertices = sorted({vertex for index in face_indexes for vertex in faces[index]})
        valences = [len(metrics["adjacency"][vertex]) for vertex in region_vertices]
        result[region] = {
            "face_count": len(face_indexes),
            "vertex_count": len(region_vertices),
            "aspect_ratio_maximum": max(ratios) if ratios else 0.0,
            "aspect_ratio_p95": percentile(ratios, 0.95),
            "aspect_ratio_over_8_count": sum(1 for ratio in ratios if ratio > 8.0),
            "extraordinary_vertex_count": sum(1 for valence in valences if valence != 4),
            "maximum_valence": max(valences) if valences else 0,
        }
    return result


def order_boundary_cycles(edges):
    adjacency: dict[int, set[int]] = collections.defaultdict(set)
    for left, right in edges:
        adjacency[left].add(right)
        adjacency[right].add(left)
    remaining = set(edges)
    cycles = []
    while remaining:
        seed = min(remaining)
        start = min(seed)
        candidates = sorted(adjacency[start])
        if not candidates:
            remaining.remove(seed)
            continue
        current = start
        previous = None
        ordered = [start]
        closed = False
        for _step in range(len(edges) + 2):
            next_candidates = [value for value in sorted(adjacency[current]) if value != previous]
            if not next_candidates:
                break
            following = next_candidates[0]
            edge = tuple(sorted((current, following)))
            if edge not in remaining and following != start:
                alternatives = [
                    value
                    for value in next_candidates[1:]
                    if tuple(sorted((current, value))) in remaining
                ]
                if not alternatives:
                    break
                following = alternatives[0]
                edge = tuple(sorted((current, following)))
            remaining.discard(edge)
            if following == start:
                closed = True
                break
            ordered.append(following)
            previous, current = current, following
        cycles.append({"closed": closed, "vertex_ids": ordered, "edge_count": len(ordered) if closed else max(0, len(ordered) - 1)})
    return sorted(cycles, key=lambda value: (-value["edge_count"], value["vertex_ids"]))


def seam_candidate(vertices, faces, predicate, target):
    selected = []
    for face in faces:
        center = tuple(sum(vertices[index][axis] for index in face) / len(face) for axis in range(3))
        selected.append(bool(predicate(center)))
    edge_faces: dict[tuple[int, int], list[int]] = collections.defaultdict(list)
    for face_index, face in enumerate(faces):
        for edge in face_edges(face):
            edge_faces[edge].append(face_index)
    boundary = []
    for edge, adjacent in edge_faces.items():
        if len(adjacent) != 2:
            continue
        if selected[adjacent[0]] != selected[adjacent[1]]:
            boundary.append(edge)
    cycles = order_boundary_cycles(boundary)
    for cycle in cycles:
        positions = [vertices[index] for index in cycle["vertex_ids"]]
        center = [sum(position[axis] for position in positions) / len(positions) for axis in range(3)]
        cycle["center"] = center
        cycle["target_distance"] = math.sqrt(sum((center[axis] - target[axis]) ** 2 for axis in range(3)))
    closed_cycles = [cycle for cycle in cycles if cycle["closed"]]
    chosen = min(closed_cycles, key=lambda value: (value["target_distance"], value["vertex_ids"])) if closed_cycles else None
    return {
        "boundary_edge_count": len(boundary),
        "cycle_count": len(cycles),
        "closed_cycle_count": len(closed_cycles),
        "candidate": chosen,
    }


def seam_candidates(vertices, faces):
    definitions = {
        "torso_pelvis_seam": (lambda p: p[1] < 1.02, (0.0, 1.02, 0.0)),
        "torso_neck_seam": (lambda p: p[1] > 1.43 and abs(p[0]) < 0.22, (0.0, 1.43, 0.0)),
        "neck_head_seam": (lambda p: p[1] > 1.50, (0.0, 1.50, 0.0)),
        "torso_arm_left_seam": (lambda p: p[0] < -0.22 and p[1] > 1.12, (-0.22, 1.42, 0.0)),
        "torso_arm_right_seam": (lambda p: p[0] > 0.22 and p[1] > 1.12, (0.22, 1.42, 0.0)),
        "wrist_hand_left_seam": (lambda p: p[0] < -0.43 and p[1] > 0.98, (-0.43, 1.17, 0.18)),
        "wrist_hand_right_seam": (lambda p: p[0] > 0.43 and p[1] > 0.98, (0.43, 1.17, 0.18)),
        "pelvis_thigh_left_seam": (lambda p: p[0] < 0.0 and p[1] < 0.86, (-0.12, 0.86, 0.0)),
        "pelvis_thigh_right_seam": (lambda p: p[0] > 0.0 and p[1] < 0.86, (0.12, 0.86, 0.0)),
        "ankle_foot_left_seam": (lambda p: p[0] < 0.0 and p[1] < 0.12, (-0.24, 0.12, 0.0)),
        "ankle_foot_right_seam": (lambda p: p[0] > 0.0 and p[1] < 0.12, (0.24, 0.12, 0.0)),
    }
    return {
        seam_id: seam_candidate(vertices, faces, predicate, target)
        for seam_id, (predicate, target) in definitions.items()
    }


def semantic_mapping_classification(record_id, owner_component_id):
    if owner_component_id in {
        "anus_module_01",
        "vulva_vaginal_canal_module_01",
        "penis_module_01",
        "scrotum_testicles_module_01",
        "tongue",
        "teeth_upper",
        "teeth_lower",
        "gums_palate_upper",
        "gums_lower",
        "mouth_cavity",
    }:
        return "requires new module geometry", "separate accepted component or optional module"
    if owner_component_id.startswith("fingernail_") or owner_component_id.startswith("toenail_"):
        return "requires new module geometry", "nail geometry is separate from visible hm08 skin"
    if owner_component_id in {"eye_left_01", "eye_right_01"} and not record_id.startswith("eyelid_"):
        return "requires new module geometry", "eyeball and corneal geometry is separate from visible hm08 skin"
    if record_id in {"perineal", "perineal_surface", "pubic", "pubic_surface"}:
        return "requires local retopology", "module-receiver and perineal foundation needs project-specific loops"
    if owner_component_id in {"ear_left_01", "ear_right_01"}:
        return "straightforward region split", "external ear is integrated in the continuous hm08 body"
    feature_tokens = (
        "areola",
        "breast",
        "brow",
        "cheek",
        "chin",
        "ear",
        "eyelid",
        "face",
        "gluteal_cleft",
        "groin",
        "iris",
        "jawline",
        "lip_",
        "mouth_external",
        "navel",
        "nipple",
        "nose",
        "pectoral",
        "pupil",
        "scalp",
        "sclera",
        "toe_pad",
    )
    if any(token in record_id for token in feature_tokens):
        return "straightforward region split", "feature-supporting topology exists in the visible body"
    return "direct mapping", "continuous visible-body skin has corresponding anatomical coverage"


def write_semantic_mapping(structural_source: Path, evidence_dir: Path):
    if sha256(structural_source) != M02_AUTHORING_SHA256:
        raise ValueError("M02 authoritative authoring source identity changed during hm08 qualification")
    source = json.loads(structural_source.read_text(encoding="utf-8"))
    rows = []
    for kind, records, id_key in (
        ("region", source["regions"], "region_id"),
        ("surface", source["surfaces"], "surface_id"),
    ):
        for record in records:
            classification, reason = semantic_mapping_classification(record[id_key], record["owner_component_id"])
            rows.append({
                "kind": kind,
                "id": record[id_key],
                "owner_component_id": record["owner_component_id"],
                "classification": classification,
                "reason": reason,
            })
    with (evidence_dir / "hm08.m02_semantic_mapping.tsv").open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("kind\tid\towner_component_id\tclassification\treason\n")
        for row in sorted(rows, key=lambda value: (value["kind"], value["id"])):
            stream.write("\t".join((row["kind"], row["id"], row["owner_component_id"], row["classification"], row["reason"])) + "\n")
    counts = collections.Counter(row["classification"] for row in rows)
    return {
        "region_count": len(source["regions"]),
        "surface_count": len(source["surfaces"]),
        "record_count": len(rows),
        "classification_counts": {key: counts[key] for key in sorted(counts)},
    }


def nearest_landmark_bindings(aligned_vertices, faces, report_path: Path):
    if BVHTree is None or Vector is None:
        return []
    triangles, source_faces = triangulate_quads(faces)
    tree = BVHTree.FromPolygons([Vector(value) for value in aligned_vertices], triangles, all_triangles=True)
    results = []
    for landmark in parse_landmarks(report_path):
        source = Vector(landmark["structural_position"])
        nearest, _normal, triangle_index, distance = tree.find_nearest(source)
        if nearest is None:
            raise ValueError(f"no nearest hm08 surface for {landmark['landmark_id']}")
        geometry = [float(nearest[0]), float(nearest[1]), float(nearest[2])]
        error_vector = [geometry[index] - landmark["structural_position"][index] for index in range(3)]
        results.append({
            **landmark,
            "classification": "surface_correspondence" if landmark["landmark_id"] in SURFACE_LANDMARKS else "internal_structural_reference",
            "mapping_feasibility": "direct surface correspondence" if landmark["landmark_id"] in SURFACE_LANDMARKS else "internal structural reference requiring derived binding",
            "nearest_body_face_index": source_faces[triangle_index],
            "geometry_position": geometry,
            "error_vector": error_vector,
            "distance": float(distance),
        })
    return results


def verify_inputs(args):
    expected = {
        Path(args.obj): ASSET_SHA256,
        Path(args.license): LICENSE_SHA256,
        Path(args.config): CONFIG_SHA256,
        Path(args.mirror): MIRROR_SHA256,
        Path(args.vertex_groups): VERTEX_GROUPS_SHA256,
        Path(args.r1_source): R1_SOURCE_SHA256,
    }
    actual = {}
    for path, expected_hash in expected.items():
        if not path.is_file():
            raise FileNotFoundError(path)
        actual_hash = sha256(path)
        actual[str(path)] = actual_hash
        if actual_hash != expected_hash:
            raise ValueError(f"SHA-256 mismatch for {path}: expected {expected_hash}, actual {actual_hash}")
    header = Path(args.obj).read_text(encoding="utf-8", errors="strict").splitlines()[:18]
    joined = "\n".join(header)
    if "basemesh hm08" not in joined or "explicitly released as CC0" not in joined:
        raise ValueError("hm08 OBJ is missing its expected asset and CC0 header")
    license_text = Path(args.license).read_text(encoding="utf-8", errors="strict")
    if not license_text.startswith("# Creative Commons CC0 1.0 Universal"):
        raise ValueError("asset license does not contain the pinned CC0 1.0 heading")
    return actual


def write_analysis(args, vertices, texcoords, grouped_faces, material_names, verified_hashes):
    body_records = grouped_faces.get("body")
    if body_records is None:
        raise ValueError("hm08 OBJ has no body group")
    body_vertices = vertices[:VISIBLE_VERTEX_COUNT]
    body_faces = [record[0] for record in body_records]
    body_texcoord_faces = [record[1] for record in body_records]
    for face in body_faces:
        if any(index >= VISIBLE_VERTEX_COUNT for index in face):
            raise ValueError("body group references a helper vertex")
    metrics = topology_metrics(body_vertices, body_faces, body_texcoord_faces)
    alignment = native_alignment(body_vertices)
    aligned_vertices = [align_native(position, alignment) for position in body_vertices]
    metrics["symmetry"] = symmetry_metrics(vertices, Path(args.mirror))
    metrics["critical_regions"] = critical_region_metrics(aligned_vertices, body_faces, metrics)
    metrics["self_intersection"] = self_intersection_metrics(aligned_vertices, body_faces)
    native_edges = metrics["edge_length_native"]
    metrics["edge_length_meters_after_alignment"] = {
        key: value * alignment["scale_native_to_meters"] for key, value in native_edges.items()
    }
    seams = seam_candidates(aligned_vertices, body_faces)
    metrics.pop("boundary_edges")
    metrics.pop("non_manifold_edges")
    metrics.pop("adjacency")
    metrics.pop("aspect_ratios")
    landmarks = nearest_landmark_bindings(aligned_vertices, body_faces, Path(args.structural_report))
    surface_distances = [entry["distance"] for entry in landmarks if entry["classification"] == "surface_correspondence"]
    internal_distances = [entry["distance"] for entry in landmarks if entry["classification"] == "internal_structural_reference"]
    landmark_summary = {
        "count": len(landmarks),
        "surface_correspondence_count": len(surface_distances),
        "internal_structural_reference_count": len(internal_distances),
        "surface_maximum": max(surface_distances) if surface_distances else 0.0,
        "surface_median": statistics.median(surface_distances) if surface_distances else 0.0,
        "surface_p90": percentile(surface_distances, 0.90),
        "internal_offset_maximum": max(internal_distances) if internal_distances else 0.0,
        "internal_offset_median": statistics.median(internal_distances) if internal_distances else 0.0,
        "internal_offset_p90": percentile(internal_distances, 0.90),
    }
    config = json.loads(Path(args.config).read_text(encoding="utf-8"))
    vertex_groups = json.loads(Path(args.vertex_groups).read_text(encoding="utf-8"))
    provenance = {
        "qualification_schema": BRIDGE_SCHEMA,
        "qualification_version": BRIDGE_VERSION,
        "external_asset_id": "makehuman_mpfb_hm08_core_basemesh",
        "upstream_project": "MakeHuman Community MPFB2",
        "repository_url": "https://github.com/makehumancommunity/mpfb2.git",
        "repository_commit": MPFB_COMMIT,
        "asset_path": "src/mpfb/data/3dobjs/base.obj",
        "asset_name": "hm08",
        "asset_bytes": Path(args.obj).stat().st_size,
        "asset_sha256": ASSET_SHA256,
        "license_path": "LICENSE.ASSETS.md",
        "license_bytes": Path(args.license).stat().st_size,
        "license_sha256": LICENSE_SHA256,
        "license": "CC0 1.0 Universal",
        "license_provenance": "PASS",
        "asset_header_license_evidence": "OBJ header explicitly identifies hm08 and CC0 release",
        "inspection_only": True,
        "canonical_authority": False,
        "r1_source_sha256": R1_SOURCE_SHA256,
        "r1_normalized_sha256": R1_NORMALIZED_SHA256,
        "r1_topology_sha256": R1_TOPOLOGY_SHA256,
        "r1_triangulation_sha256": R1_TRIANGULATION_SHA256,
        "r1_neutral_signature": R1_NEUTRAL_SIGNATURE,
        "m02_structural_sha256": M02_SHA256,
        "verified_file_hashes": verified_hashes,
    }
    helper_records = helper_metrics(vertices, grouped_faces)
    all_arity_counts = collections.Counter(
        len(record[0]) for records in grouped_faces.values() for record in records
    )
    output = {
        "provenance": provenance,
        "alignment": alignment,
        "raw_obj": {
            "total_vertex_count": len(vertices),
            "total_texture_coordinate_count": len(texcoords),
            "total_face_count": sum(len(records) for records in grouped_faces.values()),
            "group_count": len(grouped_faces),
            "material_names": material_names,
            "arity_counts": {str(key): all_arity_counts[key] for key in sorted(all_arity_counts)},
        },
        "visible_body": metrics,
        "helpers": helper_records,
        "helper_categories": helper_category_inventory(helper_records),
        "helper_joint_centers_canonical_inspection": helper_centers(vertices, grouped_faces, alignment),
        "hm08_config": config,
        "vertex_group_names": sorted(vertex_groups),
        "landmark_summary": landmark_summary,
        "landmarks": landmarks,
    }
    evidence_dir = Path(args.evidence_dir)
    evidence_dir.mkdir(parents=True, exist_ok=True)
    semantic_mapping = write_semantic_mapping(Path(args.structural_source), evidence_dir)
    output["seam_mapping_feasibility"] = seams
    output["m02_semantic_mapping"] = semantic_mapping
    (evidence_dir / "hm08.provenance.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    (evidence_dir / "hm08.qualification_metrics.json").write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    (evidence_dir / "hm08.seam_candidates.json").write_text(json.dumps(seams, indent=2) + "\n", encoding="utf-8")
    with (evidence_dir / "hm08.landmark_mapping.tsv").open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("landmark_id\tclassification\tmapping_feasibility\tanchor_x\tanchor_y\tanchor_z\tgeometry_x\tgeometry_y\tgeometry_z\terror_x\terror_y\terror_z\tdistance\tbody_face\n")
        for entry in sorted(landmarks, key=lambda value: value["landmark_id"]):
            values = [
                entry["landmark_id"],
                entry["classification"],
                entry["mapping_feasibility"],
                *[f"{value:.9f}" for value in entry["structural_position"]],
                *[f"{value:.9f}" for value in entry["geometry_position"]],
                *[f"{value:.9f}" for value in entry["error_vector"]],
                f"{entry['distance']:.9f}",
                str(entry["nearest_body_face_index"]),
            ]
            stream.write("\t".join(values) + "\n")
    return output, aligned_vertices, body_faces


def make_material(name, base_color, roughness=0.7, metallic=0.0):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = (*base_color, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*base_color, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return material


def object_from_faces(name, vertices, faces, collection, material, smooth=True):
    mesh = bpy.data.meshes.new(name + "__mesh")
    mesh.from_pydata([canonical_to_blender(position) for position in vertices], [], faces)
    mesh.validate(verbose=False, clean_customdata=False)
    mesh.update(calc_edges=True)
    for polygon in mesh.polygons:
        polygon.use_smooth = smooth
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def ensure_collection(name, parent=None):
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
    target_children = (parent or bpy.context.scene.collection).children
    if collection.name not in target_children:
        target_children.link(collection)
    return collection


def hide_collection(collection, hidden):
    collection.hide_render = hidden
    collection.hide_viewport = hidden
    for obj in collection.objects:
        obj.hide_render = hidden
        obj.hide_viewport = hidden


def select_region_faces(vertices, faces, predicate):
    selected = []
    for face in faces:
        center = tuple(sum(vertices[index][axis] for index in face) / len(face) for axis in range(3))
        if predicate(center):
            selected.append(face)
    if not selected:
        raise ValueError("qualification region selection produced no faces")
    return selected


def build_inspection_scene(args, vertices, grouped_faces, aligned_vertices, body_faces, output):
    if bpy is None:
        raise RuntimeError("Blender scene creation requires bpy")
    scene = bpy.context.scene
    scene["hm08_qualification_schema"] = BRIDGE_SCHEMA
    scene["hm08_qualification_version"] = BRIDGE_VERSION
    scene["hm08_asset_sha256"] = ASSET_SHA256
    scene["hm08_repository_commit"] = MPFB_COMMIT
    scene["hm08_license"] = "CC0-1.0"
    scene["r1_source_sha256"] = R1_SOURCE_SHA256
    scene["r1_normalized_sha256"] = R1_NORMALIZED_SHA256
    scene["m02_structural_sha256"] = M02_SHA256

    root = ensure_collection("HM08_QUALIFICATION")
    body_collection = ensure_collection("HM08_VISIBLE_BODY", root)
    helper_collection = ensure_collection("HM08_HELPERS_REFERENCE_ONLY", root)
    anchor_collection = ensure_collection("M02_STRUCTURAL_LANDMARKS", root)
    render_collection = ensure_collection("HM08_RENDER_SUPPORT", root)

    for collection in (body_collection, helper_collection, anchor_collection, render_collection):
        for obj in list(collection.objects):
            bpy.data.objects.remove(obj, do_unlink=True)

    neutral = make_material("hm08_neutral", (0.58, 0.43, 0.34), roughness=0.82)
    helper_material = make_material("hm08_helper_reference", (0.20, 0.52, 0.76), roughness=0.65)
    wire_material = make_material("hm08_wire", (0.025, 0.025, 0.03), roughness=0.9)
    r1_material = make_material("r1_comparison", (0.24, 0.46, 0.72), roughness=0.82)

    body = object_from_faces("hm08_visible_body", aligned_vertices, body_faces, body_collection, neutral)
    body["external_asset_id"] = "makehuman_mpfb_hm08_core_basemesh"
    body["asset_sha256"] = ASSET_SHA256
    body["license"] = "CC0-1.0"
    body["canonical_authority"] = False
    body["inspection_scale"] = output["alignment"]["scale_native_to_meters"]

    alignment = output["alignment"]
    helper_objects = {}
    for helper in output["helpers"]:
        group = helper["group"]
        records = grouped_faces[group]
        faces_global = [record[0] for record in records]
        referenced = sorted({index for face in faces_global for index in face})
        remap = {source: target for target, source in enumerate(referenced)}
        helper_vertices = [align_native(vertices[index], alignment) for index in referenced]
        helper_faces = [tuple(remap[index] for index in face) for face in faces_global]
        helper_obj = object_from_faces("hm08_ref__" + group, helper_vertices, helper_faces, helper_collection, helper_material)
        helper_obj["source_group"] = group
        helper_obj["canonical_authority"] = False
        helper_obj.hide_render = True
        helper_obj.hide_viewport = True
        helper_objects[group] = helper_obj
    helper_collection.hide_render = False
    helper_collection.hide_viewport = False

    for entry in parse_landmarks(Path(args.structural_report)):
        empty = bpy.data.objects.new("m02_anchor__" + entry["landmark_id"], None)
        empty.empty_display_type = "SPHERE"
        empty.empty_display_size = 0.012
        empty.location = canonical_to_blender(entry["structural_position"])
        empty["landmark_id"] = entry["landmark_id"]
        empty["anchor_id"] = entry["anchor_id"]
        empty["structural_authority"] = True
        anchor_collection.objects.link(empty)
    hide_collection(anchor_collection, True)

    r1 = bpy.data.objects.get("human_base_main_body")
    if r1 is None or r1.type != "MESH":
        raise ValueError("R1 working file does not contain human_base_main_body")
    if r1.get("cgb_source_authoritative_sha256") != R1_SOURCE_SHA256:
        raise ValueError("R1 working mesh source identity mismatch")
    r1["qualification_role"] = "current_r1_comparison_only"
    r1.data.materials.clear()
    r1.data.materials.append(r1_material)
    r1.hide_render = True
    r1.hide_viewport = True

    wire = body.copy()
    wire.data = body.data.copy()
    wire.name = "hm08_visible_body_wire"
    render_collection.objects.link(wire)
    wire.data.materials.clear()
    wire.data.materials.append(wire_material)
    modifier = wire.modifiers.new("hm08_control_edges", "WIREFRAME")
    modifier.thickness = 0.00115
    modifier.use_replace = True
    modifier.use_even_offset = True
    wire.hide_render = True
    wire.hide_viewport = True

    region_predicates = {
        "head": lambda p: p[1] > 1.43,
        "shoulder": lambda p: p[0] > 0.04 and p[1] > 1.20 and p[1] < 1.58,
        "torso": lambda p: abs(p[0]) < 0.42 and p[1] > 0.88 and p[1] < 1.50,
        "hand": lambda p: p[0] > 0.39 and p[1] > 0.98 and p[1] < 1.30,
        "pelvis": lambda p: abs(p[0]) < 0.42 and p[1] > 0.70 and p[1] < 1.10,
        "knee": lambda p: p[0] > 0.04 and p[0] < 0.33 and p[1] > 0.34 and p[1] < 0.65,
        "ankle": lambda p: p[0] > 0.10 and p[0] < 0.36 and p[1] < 0.30,
        "foot": lambda p: p[0] > 0.10 and p[0] < 0.38 and p[1] < 0.16,
    }
    region_objects = {}
    for region, predicate in region_predicates.items():
        region_faces = select_region_faces(aligned_vertices, body_faces, predicate)
        solid = object_from_faces(
            "hm08_region__" + region,
            aligned_vertices,
            region_faces,
            render_collection,
            neutral,
        )
        solid.hide_render = True
        solid.hide_viewport = True
        region_wire = solid.copy()
        region_wire.data = solid.data.copy()
        region_wire.name = "hm08_region_wire__" + region
        render_collection.objects.link(region_wire)
        region_wire.data.materials.clear()
        region_wire.data.materials.append(wire_material)
        region_modifier = region_wire.modifiers.new("hm08_region_control_edges", "WIREFRAME")
        region_modifier.thickness = 0.00115
        region_modifier.use_replace = True
        region_modifier.use_even_offset = True
        region_wire.hide_render = True
        region_wire.hide_viewport = True
        region_objects[region] = (solid, region_wire)

    Path(args.working).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.working).resolve()))
    genital_wire = helper_objects["helper-genital"].copy()
    genital_wire.data = helper_objects["helper-genital"].data.copy()
    genital_wire.name = "hm08_ref__helper-genital_wire"
    render_collection.objects.link(genital_wire)
    genital_wire.data.materials.clear()
    genital_wire.data.materials.append(wire_material)
    genital_modifier = genital_wire.modifiers.new("hm08_genital_reference_edges", "WIREFRAME")
    genital_modifier.thickness = 0.00115
    genital_modifier.use_replace = True
    genital_modifier.use_even_offset = True
    genital_wire.hide_render = True
    genital_wire.hide_viewport = True
    return body, wire, r1, region_objects, helper_objects, genital_wire


def point_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_render_scene(scene):
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.resolution_x = 1500
    scene.render.resolution_y = 1500
    scene.render.image_settings.color_depth = "8"
    scene.render.use_file_extension = True
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0
    scene.render.use_border = False
    scene.world.color = (0.055, 0.055, 0.065)
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.image_settings.compression = 15
    for obj in list(bpy.data.objects):
        if obj.type in ("LIGHT", "CAMERA") and obj.name.startswith("HM08_"):
            bpy.data.objects.remove(obj, do_unlink=True)
    camera_data = bpy.data.cameras.new("HM08_Review_Camera")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new("HM08_Review_Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    lights = [
        ("HM08_Key", (3.5, -4.5, 4.2), 1250.0, 4.0),
        ("HM08_Fill", (-4.0, -2.0, 2.2), 850.0, 5.0),
        ("HM08_Rim", (1.5, 4.0, 3.5), 1050.0, 3.5),
    ]
    for name, location, energy, size in lights:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(name, data)
        obj.location = location
        scene.collection.objects.link(obj)
        point_camera(obj, (0.0, 0.0, 0.95))
    return camera


def render_view(scene, camera, output_path: Path, target_canonical, camera_offset_canonical, ortho_scale, resolution=(1500, 1500)):
    target = canonical_to_blender(target_canonical)
    camera_canonical = tuple(target_canonical[index] + camera_offset_canonical[index] for index in range(3))
    camera.location = canonical_to_blender(camera_canonical)
    point_camera(camera, target)
    camera.data.ortho_scale = ortho_scale
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.filepath = str(output_path.resolve())
    bpy.ops.render.render(write_still=True)


def set_render_mode(body, wire, r1, region_objects, helper_objects, genital_wire, mode, region=None, helper_groups=()):
    body.hide_render = mode not in ("body", "wire") or region is not None or bool(helper_groups)
    wire.hide_render = mode != "wire" or region is not None
    r1.hide_render = mode != "r1"
    for solid, region_wire in region_objects.values():
        solid.hide_render = True
        region_wire.hide_render = True
    for helper in helper_objects.values():
        helper.hide_render = True
    genital_wire.hide_render = True
    if region is not None:
        solid, region_wire = region_objects[region]
        solid.hide_render = mode != "body"
        region_wire.hide_render = mode != "wire"
    for group in helper_groups:
        helper_objects[group].hide_render = False
    if mode == "helper_wire":
        genital_wire.hide_render = False


def render_evidence(args, body, wire, r1, region_objects, helper_objects, genital_wire):
    scene = bpy.context.scene
    camera = setup_render_scene(scene)
    output = Path(args.evidence_dir) / "images"
    output.mkdir(parents=True, exist_ok=True)
    views = [
        ("whole_front", (0.0, 0.92, 0.0), (0.0, 0.0, 4.0), 1.98, "body", None),
        ("whole_back", (0.0, 0.92, 0.0), (0.0, 0.0, -4.0), 1.98, "body", None),
        ("whole_left", (0.0, 0.92, 0.0), (-4.0, 0.0, 0.0), 1.98, "body", None),
        ("whole_right", (0.0, 0.92, 0.0), (4.0, 0.0, 0.0), 1.98, "body", None),
        ("whole_three_quarter", (0.0, 0.92, 0.0), (3.0, 0.0, 4.0), 1.98, "body", None),
        ("whole_wire_front", (0.0, 0.92, 0.0), (0.0, 0.0, 4.0), 1.98, "wire", None),
        ("whole_wire_side", (0.0, 0.92, 0.0), (-4.0, 0.0, 0.0), 1.98, "wire", None),
        ("head_front", (0.0, 1.62, 0.02), (0.0, 0.0, 2.0), 0.46, "body", None),
        ("head_side", (0.0, 1.62, 0.02), (-2.0, 0.0, 0.0), 0.46, "body", None),
        ("head_three_quarter", (0.0, 1.62, 0.02), (1.6, 0.0, 2.0), 0.46, "body", None),
        ("face_wire", (0.0, 1.62, 0.06), (0.0, 0.0, 2.0), 0.43, "wire", None),
        ("eyelid_topology", (-0.035, 1.67, 0.09), (0.0, 0.0, 1.0), 0.17, "wire", None),
        ("mouth_topology", (0.0, 1.56, 0.10), (0.0, 0.0, 1.0), 0.18, "wire", None),
        ("ear_topology", (-0.09, 1.63, 0.0), (-1.0, 0.0, 0.0), 0.25, "wire", None),
        ("shoulder_armpit", (0.25, 1.39, 0.0), (0.8, 0.0, 1.6), 0.52, "body", None),
        ("shoulder_armpit_wire", (0.25, 1.39, 0.0), (0.8, 0.0, 1.6), 0.52, "wire", None),
        ("torso_front", (0.0, 1.18, 0.0), (0.0, 0.0, 2.0), 0.88, "body", None),
        ("torso_side", (0.0, 1.18, 0.0), (-2.0, 0.0, 0.0), 0.88, "body", None),
        ("chest_breast", (0.0, 1.31, 0.05), (0.0, 0.0, 1.5), 0.55, "body", None),
        ("torso_wire", (0.0, 1.18, 0.0), (0.0, 0.0, 2.0), 0.88, "wire", None),
        ("hand_left_palm", (0.473, 1.166, 0.193), (0.0, 0.0, 1.0), 0.36, "body", None),
        ("hand_left_back", (0.473, 1.166, 0.193), (0.0, 0.0, -1.0), 0.36, "body", None),
        ("hand_left_side", (0.473, 1.166, 0.193), (1.0, 0.0, 0.0), 0.36, "body", None),
        ("hand_left_wire", (0.473, 1.166, 0.193), (0.0, 0.0, 1.0), 0.36, "wire", None),
        ("thumb_web_left", (0.447, 1.19, 0.16), (0.0, 0.0, 1.0), 0.20, "wire", None),
        ("pelvis_front", (0.0, 0.90, 0.0), (0.0, 0.0, 1.8), 0.58, "body", None),
        ("pelvis_back", (0.0, 0.90, 0.0), (0.0, 0.0, -1.8), 0.58, "body", None),
        ("pelvis_side", (0.0, 0.90, 0.0), (-1.8, 0.0, 0.0), 0.58, "body", None),
        ("pelvis_groin_wire", (0.0, 0.90, 0.03), (0.0, 0.0, 1.5), 0.54, "wire", None),
        ("knee_front", (0.174, 0.491, 0.035), (0.0, 0.0, 1.2), 0.36, "body", None),
        ("knee_side", (0.174, 0.491, 0.035), (1.2, 0.0, 0.0), 0.36, "body", None),
        ("knee_wire", (0.174, 0.491, 0.035), (0.0, 0.0, 1.2), 0.36, "wire", None),
        ("ankle_front", (0.241, 0.079, -0.001), (0.0, 0.0, 1.2), 0.34, "body", None),
        ("ankle_side", (0.241, 0.079, -0.001), (1.2, 0.0, 0.0), 0.34, "body", None),
        ("ankle_wire", (0.241, 0.079, -0.001), (0.0, 0.0, 1.2), 0.34, "wire", None),
        ("foot_top", (0.241, 0.07, 0.14), (0.0, 1.2, 0.0), 0.42, "body", "foot"),
        ("foot_side", (0.241, 0.07, 0.14), (1.2, 0.0, 0.0), 0.42, "body", None),
        ("foot_three_quarter", (0.241, 0.07, 0.14), (0.8, 0.6, 1.0), 0.42, "body", None),
        ("foot_sole", (0.241, 0.04, 0.14), (0.0, -1.2, 0.0), 0.42, "body", "foot"),
        ("foot_toes", (0.241, 0.06, 0.25), (0.0, 0.0, 1.0), 0.30, "body", None),
        ("foot_wire", (0.241, 0.07, 0.14), (0.0, 1.2, 0.0), 0.42, "wire", "foot"),
    ]
    for name, target, offset, scale, mode, region in views:
        set_render_mode(body, wire, r1, region_objects, helper_objects, genital_wire, mode, region)
        render_view(scene, camera, output / f"hm08_{name}.png", target, offset, scale)

    helper_views = [
        ("helper_genital_shaded", (0.0, 0.84, 0.106), (0.0, 0.0, 1.0), 0.38, "body", ("helper-genital",)),
        ("helper_genital_wire", (0.0, 0.84, 0.106), (0.0, 0.0, 1.0), 0.38, "helper_wire", ()),
        ("helper_tongue", (0.0, 1.62, 0.125), (0.0, 0.0, 1.0), 0.24, "body", ("helper-tongue",)),
        ("helper_eyes", (0.0, 1.696, 0.137), (0.0, 0.0, 1.0), 0.22, "body", ("helper-l-eye", "helper-r-eye")),
        ("helper_teeth", (0.0, 1.637, 0.137), (0.0, 0.0, 1.0), 0.22, "body", ("helper-upper-teeth", "helper-lower-teeth")),
    ]
    for name, target, offset, scale, mode, groups in helper_views:
        set_render_mode(body, wire, r1, region_objects, helper_objects, genital_wire, mode, helper_groups=groups)
        render_view(scene, camera, output / f"hm08_{name}.png", target, offset, scale)

    comparisons = [
        ("whole", (0.0, 0.92, 0.0), 2.0),
        ("head", (0.0, 1.62, 0.03), 0.50),
        ("shoulder", (0.0, 1.39, 0.0), 0.58),
        ("hand", (0.0, 1.11, 0.0), 0.38),
        ("pelvis", (0.0, 0.90, 0.0), 0.62),
        ("knee", (0.0, 0.51, 0.0), 0.40),
        ("ankle", (0.0, 0.16, 0.0), 0.38),
        ("foot", (0.0, 0.08, 0.08), 0.46),
    ]
    r1_targets = {
        "whole": (0.0, 0.92, 0.0),
        "head": (0.0, 1.62, 0.03),
        "shoulder": (-0.28, 1.39, 0.0),
        "hand": (-0.70, 1.15, 0.0),
        "pelvis": (0.0, 0.90, 0.0),
        "knee": (-0.10, 0.51, 0.0),
        "ankle": (-0.10, 0.16, 0.0),
        "foot": (-0.10, 0.08, 0.08),
    }
    hm08_targets = {
        "whole": (0.0, 0.92, 0.0),
        "head": (0.0, 1.62, 0.03),
        "shoulder": (0.25, 1.39, 0.0),
        "hand": (0.473, 1.166, 0.193),
        "pelvis": (0.0, 0.90, 0.0),
        "knee": (0.174, 0.491, 0.035),
        "ankle": (0.241, 0.079, -0.001),
        "foot": (0.241, 0.08, 0.14),
    }
    region_by_comparison = {
        "whole": None,
        "head": None,
        "shoulder": None,
        "hand": None,
        "pelvis": None,
        "knee": None,
        "ankle": None,
        "foot": None,
    }
    for name, _target, scale in comparisons:
        set_render_mode(body, wire, r1, region_objects, helper_objects, genital_wire, "r1")
        render_view(scene, camera, output / f"panel_r1_{name}.png", r1_targets[name], (0.0, 0.0, 4.0), scale)
        set_render_mode(body, wire, r1, region_objects, helper_objects, genital_wire, "body", region_by_comparison[name])
        render_view(scene, camera, output / f"panel_hm08_{name}.png", hm08_targets[name], (0.0, 0.0, 4.0), scale)
    body.hide_render = False
    return [str(path.relative_to(Path(args.evidence_dir))) for path in sorted(output.glob("*.png"))]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--obj", required=True)
    parser.add_argument("--license", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--mirror", required=True)
    parser.add_argument("--vertex-groups", required=True)
    parser.add_argument("--r1-source", required=True)
    parser.add_argument("--structural-report", required=True)
    parser.add_argument("--structural-source", required=True)
    parser.add_argument("--evidence-dir", required=True)
    parser.add_argument("--working", required=True)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:])

    verified_hashes = verify_inputs(args)
    vertices, texcoords, grouped_faces, material_names = parse_obj(Path(args.obj))
    output, aligned_vertices, body_faces = write_analysis(
        args, vertices, texcoords, grouped_faces, material_names, verified_hashes
    )
    if bpy is not None:
        body, wire, r1, region_objects, helper_objects, genital_wire = build_inspection_scene(
            args, vertices, grouped_faces, aligned_vertices, body_faces, output
        )
        if args.render:
            image_paths = render_evidence(
                args, body, wire, r1, region_objects, helper_objects, genital_wire
            )
            index = {
                "hm08_asset_sha256": ASSET_SHA256,
                "r1_source_sha256": R1_SOURCE_SHA256,
                "r1_topology_sha256": R1_TOPOLOGY_SHA256,
                "images": image_paths,
            }
            Path(args.evidence_dir, "hm08.visual_index.json").write_text(
                json.dumps(index, indent=2) + "\n", encoding="utf-8"
            )
    print("HM08_QUALIFICATION_PASS")
    print(f"asset_sha256={ASSET_SHA256}")
    print(f"visible_vertices={output['visible_body']['vertex_count']}")
    print(f"visible_faces={output['visible_body']['face_count']}")
    print(f"license_provenance={output['provenance']['license_provenance']}")


if __name__ == "__main__":
    main()
