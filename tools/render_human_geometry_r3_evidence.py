#!/usr/bin/env python3
"""Render persistent Prompt 2C-R3 review evidence from canonical geometry."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import bpy


EXPECTED_AUTHORITY_SHA256 = "35a7ab3c433795bcd47975050a5f7ee74a72c43ba3c5d754f9ebbce7886716f7"
EXPECTED_TOPOLOGY_SHA256 = "335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191"
EXPECTED_NORMALIZED_SHA256 = "7354f67a78000abf4cad63177a492e45ee72a993a9d0a17b5b6ec7c8b1861417"
EVIDENCE_PROMPT = "Prompt 2C-R3"
COLLECTION_NAME = "PROMPT_2C_R3_REVIEW"
INDEX_FILENAME = "r3_visual_index.json"
SUCCESS_LABEL = "R3_EVIDENCE_RENDER_OK"


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location("hm08_qualification", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load inspection renderer at {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def render(args) -> None:
    source_path = Path(args.source).resolve()
    if sha256(source_path) != EXPECTED_AUTHORITY_SHA256:
        raise ValueError("R3 evidence renderer refuses an unreviewed geometry authority")
    q = load_module(Path(args.qualification_module).resolve())
    document = json.loads(source_path.read_text(encoding="utf-8"))
    mesh_source = document["meshes"][0]
    vertices = [tuple(vertex["position_m"]) for vertex in mesh_source["vertices"]]
    faces = [tuple(face["vertex_ids"]) for face in mesh_source["faces"]]
    surfaces = [face["primary_surface_id"] for face in mesh_source["faces"]]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection = q.ensure_collection(COLLECTION_NAME)
    neutral = q.make_material("r3_neutral", (0.58, 0.43, 0.34), roughness=0.82)
    wire_material = q.make_material("r3_wire", (0.018, 0.020, 0.026), roughness=0.9)
    body = q.object_from_faces("human_base_main_body", vertices, faces, collection, neutral)
    body["canonical_authority_sha256"] = EXPECTED_AUTHORITY_SHA256
    body["normalized_geometry_sha256"] = EXPECTED_NORMALIZED_SHA256
    body["control_topology_sha256"] = EXPECTED_TOPOLOGY_SHA256

    wire = body.copy()
    wire.data = body.data.copy()
    wire.name = "human_base_main_body_wire"
    collection.objects.link(wire)
    wire.data.materials.clear()
    wire.data.materials.append(wire_material)
    modifier = wire.modifiers.new("r3_control_edges", "WIREFRAME")
    modifier.thickness = 0.0010
    modifier.use_replace = True
    modifier.use_even_offset = True
    wire.hide_render = True

    semantic = body.copy()
    semantic.data = body.data.copy()
    semantic.name = "human_base_main_body_semantic"
    collection.objects.link(semantic)
    palette = [
        (0.80, 0.32, 0.28), (0.28, 0.55, 0.82), (0.30, 0.72, 0.42), (0.82, 0.62, 0.25),
        (0.62, 0.38, 0.78), (0.25, 0.72, 0.72), (0.82, 0.42, 0.68), (0.58, 0.68, 0.25),
    ]
    surface_index = {surface: index for index, surface in enumerate(sorted(set(surfaces)))}
    for index, color in enumerate(palette):
        semantic.data.materials.append(q.make_material(f"r3_semantic_{index}", color, roughness=0.78))
    for polygon, surface in zip(semantic.data.polygons, surfaces, strict=True):
        polygon.material_index = surface_index[surface] % len(palette)
    semantic.hide_render = True

    scene = bpy.context.scene
    if scene.world is None:
        scene.world = bpy.data.worlds.new("r3_review_world")
    camera = q.setup_render_scene(scene)
    image_dir = Path(args.evidence_dir).resolve() / "images"
    image_dir.mkdir(parents=True, exist_ok=True)
    views = [
        ("whole_front", (0.0, 0.92, 0.0), (0.0, 0.0, 4.0), 2.05, "body"),
        ("whole_back", (0.0, 0.92, 0.0), (0.0, 0.0, -4.0), 2.05, "body"),
        ("whole_left", (0.0, 0.92, 0.0), (-4.0, 0.0, 0.0), 2.05, "body"),
        ("whole_right", (0.0, 0.92, 0.0), (4.0, 0.0, 0.0), 2.05, "body"),
        ("whole_front_three_quarter", (0.0, 0.92, 0.0), (3.0, -2.4, 2.5), 2.05, "body"),
        ("whole_back_three_quarter", (0.0, 0.92, 0.0), (-3.0, 2.4, -2.5), 2.05, "body"),
        ("whole_wire_front", (0.0, 0.92, 0.0), (0.0, 0.0, 4.0), 2.05, "wire"),
        ("whole_wire_side", (0.0, 0.92, 0.0), (4.0, 0.0, 0.0), 2.05, "wire"),
        ("semantic_surface_map", (0.0, 0.92, 0.0), (0.0, 0.0, 4.0), 2.05, "semantic"),
        ("head_front", (0.0, 1.67, 0.02), (0.0, 0.0, 3.0), 0.42, "body"),
        ("head_side", (0.0, 1.67, 0.02), (3.0, 0.0, 0.0), 0.42, "body"),
        ("head_three_quarter", (0.0, 1.67, 0.02), (2.2, -1.8, 2.2), 0.42, "body"),
        ("head_wire", (0.0, 1.67, 0.02), (0.0, 0.0, 3.0), 0.42, "wire"),
        ("eye_topology", (-0.032, 1.725, 0.10), (0.0, 0.0, 2.0), 0.18, "wire"),
        ("nose_mouth", (0.0, 1.635, 0.09), (0.0, 0.0, 2.0), 0.28, "body"),
        ("ear", (-0.095, 1.675, 0.0), (-2.0, 0.0, 0.3), 0.25, "body"),
        ("shoulder_armpit", (-0.23, 1.38, 0.0), (-2.0, -1.2, 2.5), 0.55, "body"),
        ("shoulder_armpit_wire", (-0.23, 1.38, 0.0), (-2.0, -1.2, 2.5), 0.55, "wire"),
        ("torso_front", (0.0, 1.27, 0.02), (0.0, 0.0, 2.5), 0.72, "body"),
        ("torso_side", (0.0, 1.27, 0.02), (2.5, 0.0, 0.0), 0.72, "body"),
        ("breast_front", (0.0, 1.31, 0.08), (0.0, 0.0, 2.0), 0.48, "body"),
        ("breast_side", (0.0, 1.31, 0.08), (2.0, 0.0, 0.0), 0.48, "body"),
        ("breast_wire", (0.0, 1.31, 0.08), (0.0, 0.0, 2.0), 0.48, "wire"),
        ("hand_palm", (-0.77, 1.13, 0.0), (0.0, 0.0, 2.0), 0.30, "body"),
        ("hand_back", (-0.77, 1.13, 0.0), (0.0, 0.0, -2.0), 0.30, "body"),
        ("hand_three_quarter", (-0.77, 1.13, 0.0), (-1.5, -1.2, 1.8), 0.30, "body"),
        ("thumb_web", (-0.75, 1.13, 0.015), (0.0, 0.0, 2.0), 0.18, "wire"),
        ("hand_wire", (-0.77, 1.13, 0.0), (0.0, 0.0, 2.0), 0.30, "wire"),
        ("pelvis_front", (0.0, 0.90, 0.0), (0.0, 0.0, 2.5), 0.52, "body"),
        ("pelvis_back", (0.0, 0.90, 0.0), (0.0, 0.0, -2.5), 0.52, "body"),
        ("pelvis_side", (0.0, 0.90, 0.0), (2.5, 0.0, 0.0), 0.52, "body"),
        ("pelvis_wire", (0.0, 0.90, 0.0), (0.0, 0.0, 2.5), 0.52, "wire"),
        ("perineal_receiver", (0.0, 0.79, -0.01), (0.0, 2.0, 1.5), 0.34, "semantic"),
        ("knee_front", (-0.12, 0.50, 0.0), (0.0, 0.0, 2.0), 0.32, "body"),
        ("knee_side", (-0.12, 0.50, 0.0), (2.0, 0.0, 0.0), 0.32, "body"),
        ("knee_wire", (-0.12, 0.50, 0.0), (0.0, 0.0, 2.0), 0.32, "wire"),
        ("ankle_achilles", (-0.10, 0.11, 0.0), (2.0, 0.0, 1.5), 0.30, "body"),
        ("ankle_wire", (-0.10, 0.11, 0.0), (2.0, 0.0, 1.5), 0.30, "wire"),
        ("foot_top", (-0.10, 0.05, 0.12), (0.0, 2.0, 0.0), 0.42, "body"),
        ("foot_side", (-0.10, 0.06, 0.12), (2.0, 0.0, 0.0), 0.42, "body"),
        ("foot_three_quarter", (-0.10, 0.06, 0.12), (1.7, 1.4, 1.7), 0.42, "body"),
        ("foot_sole", (-0.10, 0.03, 0.12), (0.0, -2.0, 0.4), 0.42, "body"),
        ("toe_wire", (-0.10, 0.04, 0.21), (0.0, 1.5, 2.0), 0.32, "wire"),
    ]
    image_names = []
    for name, target, offset, scale, mode in views:
        body.hide_render = mode != "body"
        wire.hide_render = mode != "wire"
        semantic.hide_render = mode != "semantic"
        path = image_dir / f"human_base_main_body_{name}.png"
        q.render_view(scene, camera, path, target, offset, scale, resolution=(1500, 1500))
        image_names.append(f"images/{path.name}")

    write_json(Path(args.evidence_dir) / INDEX_FILENAME, {
        "prompt": EVIDENCE_PROMPT,
        "authority_sha256": EXPECTED_AUTHORITY_SHA256,
        "normalized_geometry_sha256": EXPECTED_NORMALIZED_SHA256,
        "control_topology_sha256": EXPECTED_TOPOLOGY_SHA256,
        "topology_revision": int(document["topology_identity"]["revision"]),
        "images": image_names,
    })
    print(f"{SUCCESS_LABEL} images={len(image_names)} evidence={args.evidence_dir}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--qualification-module", required=True)
    parser.add_argument("--evidence-dir", required=True)
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    render(parser.parse_args(arguments))


if __name__ == "__main__":
    main()
