#!/usr/bin/env python3
"""Generate deterministic Prompt 2C-R4 geometry and registration evidence."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import statistics
import sys
from pathlib import Path


SURFACE_LANDMARK = "SURFACE_CORRESPONDENCE"
INTERNAL_LANDMARK = "INTERNAL_STRUCTURAL_REFERENCE"
BREAST_SURFACES = {
    "breast_left_surface",
    "breast_right_surface",
    "nipple_left_surface",
    "nipple_right_surface",
    "areola_left_surface",
    "areola_right_surface",
}
GLUTE_SURFACES = {"glute_left_surface", "glute_right_surface", "gluteal_cleft_surface"}
HAND_REGIONS = {
    "palm_left", "palm_right", "hand_dorsum_left", "hand_dorsum_right",
    "thumb_left", "thumb_right", "index_left", "index_right", "middle_left", "middle_right",
    "ring_left", "ring_right", "little_left", "little_right",
}
FOOT_REGIONS = {
    "midfoot_left", "midfoot_right", "forefoot_left", "forefoot_right",
    "heel_left", "heel_right", "sole_left", "sole_right", "toe_big_left", "toe_big_right",
    "toe_index_left", "toe_index_right", "toe_middle_left", "toe_middle_right",
    "toe_ring_left", "toe_ring_right", "toe_little_left", "toe_little_right",
}


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location("r4_geometry_analysis", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load geometry analysis support at {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    position = fraction * (len(ordered) - 1)
    lower = int(math.floor(position))
    upper = min(lower + 1, len(ordered) - 1)
    blend = position - lower
    return ordered[lower] * (1.0 - blend) + ordered[upper] * blend


def parse_validation(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key] = value
    return result


def load_geometry(path: Path):
    document = json.loads(path.read_text(encoding="utf-8"))
    mesh = document["meshes"][0]
    vertices = [tuple(float(value) for value in vertex["position_m"]) for vertex in mesh["vertices"]]
    vertex_ids = [int(vertex["vertex_id"]) for vertex in mesh["vertices"]]
    if vertex_ids != list(range(len(vertex_ids))):
        raise ValueError("R4 analysis requires the accepted topology-v2 sequential VertexId namespace")
    faces = [tuple(int(value) for value in face["vertex_ids"]) for face in mesh["faces"]]
    face_ids = [int(face["face_id"]) for face in mesh["faces"]]
    if face_ids != list(range(len(face_ids))):
        raise ValueError("R4 analysis requires the accepted topology-v2 sequential FaceId namespace")
    return document, mesh, vertices, faces


def semantic_vertex_sets(mesh: dict) -> tuple[dict[str, set[int]], dict[str, set[int]]]:
    surfaces: dict[str, set[int]] = {}
    regions: dict[str, set[int]] = {}
    for face in mesh["faces"]:
        ids = {int(value) for value in face["vertex_ids"]}
        surfaces.setdefault(face["primary_surface_id"], set()).update(ids)
        for region in face["region_ids"]:
            regions.setdefault(region, set()).update(ids)
    return surfaces, regions


def bounds(points: list[tuple[float, float, float]]) -> dict[str, float]:
    if not points:
        raise ValueError("measurement region contains no vertices")
    return {
        "width": max(point[0] for point in points) - min(point[0] for point in points),
        "height": max(point[1] for point in points) - min(point[1] for point in points),
        "depth": max(point[2] for point in points) - min(point[2] for point in points),
        "minimum_z": min(point[2] for point in points),
        "maximum_z": max(point[2] for point in points),
    }


def semantic_points(vertices, table: dict[str, set[int]], names: set[str]):
    ids: set[int] = set()
    for name in names:
        ids.update(table.get(name, set()))
    return [vertices[index] for index in sorted(ids)]


def spatial_points(vertices, minimum_y: float, maximum_y: float, maximum_abs_x: float):
    return [point for point in vertices if minimum_y <= point[1] <= maximum_y and abs(point[0]) <= maximum_abs_x]


def measurements(mesh: dict, vertices) -> dict[str, float]:
    surfaces, regions = semantic_vertex_sets(mesh)
    breast = semantic_points(vertices, surfaces, BREAST_SURFACES)
    glute = semantic_points(vertices, surfaces, GLUTE_SURFACES)
    thigh = [point for point in semantic_points(vertices, regions, {"thigh_left", "thigh_right"}) if point[1] >= 0.72]
    left_hand = semantic_points(vertices, regions, {name for name in HAND_REGIONS if name.endswith("_left")})
    left_foot = semantic_points(vertices, regions, {name for name in FOOT_REGIONS if name.endswith("_left")})
    head = spatial_points(vertices, 1.498, 1.8288, 0.18)
    shoulder = semantic_points(vertices, surfaces, {"shoulder_left_surface", "shoulder_right_surface"})
    chest = spatial_points(vertices, 1.1176, 1.4986, 0.215)
    waist = spatial_points(vertices, 1.016, 1.1176, 0.25)
    hip = spatial_points(vertices, 0.8128, 1.016, 0.25)
    overall = bounds(list(vertices))
    return {
        "mesh_visible_height": overall["height"],
        "mesh_visible_shoulder_width": bounds(shoulder)["width"],
        "mesh_chest_width": bounds(chest)["width"],
        "mesh_chest_depth": bounds(chest)["depth"],
        "mesh_waist_width": bounds(waist)["width"],
        "mesh_hip_width": bounds(hip)["width"],
        "mesh_hip_glute_depth": bounds(hip)["depth"],
        "mesh_breast_projection_from_reference_plane": bounds(breast)["maximum_z"] - 0.065,
        "mesh_breast_base_width": bounds(breast)["width"],
        "mesh_glute_projection_from_origin": -bounds(glute)["minimum_z"],
        "mesh_upper_thigh_width": bounds(thigh)["width"],
        "mesh_head_height": bounds(head)["height"],
        "mesh_hand_length": bounds(left_hand)["width"],
        "mesh_foot_length": bounds(left_foot)["depth"],
    }


def bilinear(points, u: float, v: float):
    weights = ((1.0 - u) * (1.0 - v), u * (1.0 - v), u * v, (1.0 - u) * v)
    return [sum(points[index][axis] * weights[index] for index in range(4)) for axis in range(3)]


def landmark_report(document: dict, mesh: dict, vertices, r3_report: dict):
    face_by_id = {int(face["face_id"]): face for face in mesh["faces"]}
    baseline = {entry["landmark_id"]: entry for entry in r3_report["landmark_rows"]}
    records = []
    for binding in document["geometry_bindings"]:
        landmark_id = binding.get("landmark_id")
        if landmark_id is None:
            continue
        prior = baseline[landmark_id]
        face = face_by_id[int(binding["face_id"])]
        points = [vertices[int(vertex_id)] for vertex_id in face["vertex_ids"]]
        u, v = (float(value) for value in binding["local_face_coordinate"])
        surface = bilinear(points, u, v)
        anchor = [float(value) for value in prior["anchor"]]
        offset = [surface[index] - anchor[index] for index in range(3)]
        distance = math.sqrt(sum(value * value for value in offset))
        classification = prior["classification"]
        records.append({
            "landmark_id": landmark_id,
            "anchor_id": prior["anchor_id"],
            "classification": classification,
            "face_id": int(binding["face_id"]),
            "surface_id": face["primary_surface_id"],
            "local_u": u,
            "local_v": v,
            "anchor": anchor,
            "surface": surface,
            "offset": offset,
            "distance_m": distance,
            "interpretation": "visible_surface_registration" if classification == SURFACE_LANDMARK else "intentional_internal_to_surface_offset",
        })
    records.sort(key=lambda value: value["landmark_id"])
    if len(records) != 35:
        raise ValueError(f"expected 35 landmark bindings, actual {len(records)}")
    if sum(record["classification"] == SURFACE_LANDMARK for record in records) != 18:
        raise ValueError("R4 surface-landmark classification count changed")
    if sum(record["classification"] == INTERNAL_LANDMARK for record in records) != 17:
        raise ValueError("R4 internal-landmark classification count changed")
    summaries = {}
    for classification, key in ((SURFACE_LANDMARK, "surface_correspondence"), (INTERNAL_LANDMARK, "internal_structural_reference")):
        distances = [record["distance_m"] for record in records if record["classification"] == classification]
        summaries[key] = {
            "count": len(distances),
            "median_m": statistics.median(distances),
            "p90_m": percentile(distances, 0.90),
            "maximum_m": max(distances),
        }
    return records, summaries


def compare_non_position_identity(r3_document: dict, r4_document: dict) -> bool:
    left = json.loads(json.dumps(r3_document))
    right = json.loads(json.dumps(r4_document))
    for document in (left, right):
        for mesh in document["meshes"]:
            for vertex in mesh["vertices"]:
                vertex["position_m"] = [0.0, 0.0, 0.0]
    return left == right


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def run(args: argparse.Namespace) -> None:
    source_path = Path(args.source).resolve()
    r3_path = Path(args.r3_source).resolve()
    t3_path = Path(args.t3_source).resolve()
    output = Path(args.output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)
    validation = parse_validation(Path(args.validation).resolve())
    if validation["candidate_authoring_sha256"] != sha256(source_path):
        raise ValueError("candidate validation does not match R4 source bytes")
    q = load_module(Path(args.qualification_module).resolve())
    r4_document, r4_mesh, r4_vertices, r4_faces = load_geometry(source_path)
    r3_document, r3_mesh, r3_vertices, r3_faces = load_geometry(r3_path)
    _, t3_mesh, t3_vertices, t3_faces = load_geometry(t3_path)
    if r4_faces != r3_faces or r4_faces != t3_faces:
        raise ValueError("R4 topology differs from the accepted HM08 topology")
    texture_faces = [[None] * 4 for _ in r4_faces]
    r4_quality = q.topology_metrics(r4_vertices, r4_faces, texture_faces)
    r3_quality = q.topology_metrics(r3_vertices, r3_faces, texture_faces)
    t3_quality = q.topology_metrics(t3_vertices, t3_faces, texture_faces)
    self_intersection = q.self_intersection_metrics(r4_vertices, r4_faces)
    if self_intersection.get("status") != "completed":
        raise ValueError("R4 self-intersection evidence must run under Blender")
    r3_report = json.loads(Path(args.r3_report).read_text(encoding="utf-8"))
    landmarks, landmark_summaries = landmark_report(r4_document, r4_mesh, r4_vertices, r3_report)

    outliers = []
    r3_created_remaining = 0
    r4_created = 0
    r3_created_improved = 0
    for index, ratio in enumerate(r4_quality["aspect_ratios"]):
        if ratio <= 8.0:
            continue
        face = r4_mesh["faces"][index]
        t3_ratio = t3_quality["aspect_ratios"][index]
        r3_ratio = r3_quality["aspect_ratios"][index]
        lineage = "HM08_SEED_OUTLIER" if t3_ratio > 8.0 else "R3_CREATED_OUTLIER"
        if lineage == "R3_CREATED_OUTLIER":
            r3_created_remaining += 1
            if ratio < r3_ratio:
                r3_created_improved += 1
        if r3_ratio <= 8.0:
            lineage = "R4_CREATED_OUTLIER"
            r4_created += 1
        outliers.append({
            "face_id": int(face["face_id"]),
            "surface_id": face["primary_surface_id"],
            "t3_aspect_ratio": t3_ratio,
            "r3_aspect_ratio": r3_ratio,
            "r4_aspect_ratio": ratio,
            "lineage": lineage,
        })
    outliers.sort(key=lambda value: (-value["r4_aspect_ratio"], value["face_id"]))

    r3_measurements = measurements(r3_mesh, r3_vertices)
    r4_measurements = measurements(r4_mesh, r4_vertices)
    measurement_delta = {key: r4_measurements[key] - r3_measurements[key] for key in r4_measurements}
    report = {
        "prompt": "Prompt 2C-R4",
        "identities": {
            "authority_sha256": validation["candidate_authoring_sha256"],
            "normalized_geometry_sha256": validation["normalized_geometry_sha256"],
            "control_topology_sha256": validation["control_topology_sha256"],
            "triangulation_sha256": validation["triangulation_sha256"],
            "neutral_geometry_signature": validation["neutral_geometry_signature"],
            "structural_normalized_sha256": validation["structural_normalized_sha256"],
        },
        "topology": {
            "revision": int(r4_document["topology_identity"]["revision"]),
            "vertex_count": len(r4_vertices),
            "quad_count": len(r4_faces),
            "derived_triangle_count": len(r4_faces) * 2,
            "id_changes": 0,
            "connectivity_changes": 0,
            "non_position_semantic_identity_equal_to_r3": compare_non_position_identity(r3_document, r4_document),
        },
        "quality": {
            "connected_component_count": r4_quality["connected_component_count"],
            "boundary_edge_count": r4_quality["boundary_edge_count"],
            "non_manifold_edge_count": r4_quality["non_manifold_edge_count"],
            "duplicate_face_count": r4_quality["duplicate_face_count"],
            "degenerate_face_count": r4_quality["degenerate_face_count"],
            "aspect_ratio": r4_quality["aspect_ratio"],
            "extraordinary_vertex_count": r4_quality["extraordinary_vertex_count"],
            "valence_distribution": r4_quality["valence_distribution"],
            "r3_created_outliers_remaining": r3_created_remaining,
            "r3_created_outliers_improved": r3_created_improved,
            "r4_created_outliers": r4_created,
        },
        "measurements": {
            "r3": r3_measurements,
            "r4": r4_measurements,
            "delta_r4_minus_r3": measurement_delta,
            "classification": "OPEN_TUNING_GEOMETRY_VALUES",
        },
        "landmarks": landmark_summaries,
        "landmark_bindings": landmarks,
        "aspect_outliers": outliers,
        "self_intersection": self_intersection,
        "neutrality_classification": "SLIGHT_FEMALE_LEAN",
    }
    write_json(output / "human_base_main_body_r4_report.json", report)
    write_json(output / "human_base_main_body_r4_self_intersection.json", self_intersection)
    with (output / "human_base_main_body_r4_landmark_bindings.tsv").open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("landmark_id\tclassification\tanchor_id\tface_id\tsurface_id\tanchor_x\tanchor_y\tanchor_z\tsurface_x\tsurface_y\tsurface_z\toffset_x\toffset_y\toffset_z\tdistance_m\tinterpretation\n")
        for record in landmarks:
            values = [
                record["landmark_id"], record["classification"], record["anchor_id"], str(record["face_id"]), record["surface_id"],
                *(f"{value:.9f}" for value in record["anchor"]), *(f"{value:.9f}" for value in record["surface"]),
                *(f"{value:.9f}" for value in record["offset"]), f"{record['distance_m']:.9f}", record["interpretation"],
            ]
            stream.write("\t".join(values) + "\n")
    with (output / "r4_aspect_outliers.tsv").open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("face_id\tsurface_id\tt3_aspect_ratio\tr3_aspect_ratio\tr4_aspect_ratio\tlineage\n")
        for record in outliers:
            stream.write(
                f"{record['face_id']}\t{record['surface_id']}\t{record['t3_aspect_ratio']:.9f}\t"
                f"{record['r3_aspect_ratio']:.9f}\t{record['r4_aspect_ratio']:.9f}\t{record['lineage']}\n"
            )
    print(
        "R4_ANALYSIS_OK "
        f"outliers={len(outliers)} intersections={self_intersection['detected_nonadjacent_triangle_intersection_count']} "
        f"surface_landmarks={landmark_summaries['surface_correspondence']['count']} "
        f"internal_landmarks={landmark_summaries['internal_structural_reference']['count']}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--r3-source", required=True)
    parser.add_argument("--t3-source", required=True)
    parser.add_argument("--r3-report", required=True)
    parser.add_argument("--validation", required=True)
    parser.add_argument("--qualification-module", required=True)
    parser.add_argument("--output-dir", required=True)
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    run(parser.parse_args(arguments))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"R4_ANALYSIS_ERROR: {error}", file=sys.stderr)
        raise SystemExit(2) from error
