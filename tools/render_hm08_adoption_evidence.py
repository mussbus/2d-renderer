#!/usr/bin/env python3
"""Render derived Prompt 2C-T3 evidence from canonical geometry authority."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import bpy


EXPECTED_AUTHORITY_SHA256 = "29552addc3d550c4a423609598a0dfbc5d28629e62329fb11ef6ce52cab875bf"
HM08_PROVENANCE_SHA256 = "bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950"


def load_qualification_module(path: Path):
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
    source_path = Path(args.source)
    if sha256(source_path) != EXPECTED_AUTHORITY_SHA256:
        raise ValueError("T3 evidence renderer refuses an unreviewed authority identity")
    q = load_qualification_module(Path(args.qualification_module))
    document = json.loads(source_path.read_text(encoding="utf-8"))
    mesh_source = document["meshes"][0]
    vertices = [tuple(vertex["position_m"]) for vertex in mesh_source["vertices"]]
    faces = [tuple(face["vertex_ids"]) for face in mesh_source["faces"]]
    surfaces = [face["primary_surface_id"] for face in mesh_source["faces"]]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection = q.ensure_collection("HM08_T3_CANONICAL_ADOPTION")
    neutral = q.make_material("hm08_t3_neutral", (0.58, 0.43, 0.34), roughness=0.82)
    wire_material = q.make_material("hm08_t3_wire", (0.025, 0.025, 0.03), roughness=0.9)
    body = q.object_from_faces("human_base_main_body", vertices, faces, collection, neutral)
    body["canonical_authority_sha256"] = EXPECTED_AUTHORITY_SHA256
    body["external_origin_sha256"] = HM08_PROVENANCE_SHA256
    body["topology_version"] = "2.0.0"
    body["topology_revision"] = 4

    wire = body.copy()
    wire.data = body.data.copy()
    wire.name = "human_base_main_body_wire"
    collection.objects.link(wire)
    wire.data.materials.clear()
    wire.data.materials.append(wire_material)
    modifier = wire.modifiers.new("hm08_t3_control_edges", "WIREFRAME")
    modifier.thickness = 0.00115
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
        semantic.data.materials.append(q.make_material(f"hm08_t3_semantic_{index}", color, roughness=0.78))
    for polygon, surface in zip(semantic.data.polygons, surfaces, strict=True):
        polygon.material_index = surface_index[surface] % len(palette)
    semantic.hide_render = True

    scene = bpy.context.scene
    if scene.world is None:
        scene.world = bpy.data.worlds.new("hm08_t3_review_world")
    camera = q.setup_render_scene(scene)
    output = Path(args.evidence_dir) / "images"
    output.mkdir(parents=True, exist_ok=True)
    views = [
        ("whole_front", (0.0, 0.92, 0.0), (0.0, 0.0, 4.0), 2.05, "body"),
        ("whole_back", (0.0, 0.92, 0.0), (0.0, 0.0, -4.0), 2.05, "body"),
        ("whole_side", (0.0, 0.92, 0.0), (4.0, 0.0, 0.0), 2.05, "body"),
        ("whole_three_quarter", (0.0, 0.92, 0.0), (3.0, -2.4, 2.5), 2.05, "body"),
        ("whole_wire_front", (0.0, 0.92, 0.0), (0.0, 0.0, 4.0), 2.05, "wire"),
        ("whole_wire_side", (0.0, 0.92, 0.0), (4.0, 0.0, 0.0), 2.05, "wire"),
        ("semantic_surface_map", (0.0, 0.92, 0.0), (0.0, 0.0, 4.0), 2.05, "semantic"),
        ("head_front", (0.0, 1.67, 0.02), (0.0, 0.0, 3.0), 0.42, "body"),
        ("head_side", (0.0, 1.67, 0.02), (3.0, 0.0, 0.0), 0.42, "body"),
        ("head_wire", (0.0, 1.67, 0.02), (0.0, 0.0, 3.0), 0.42, "wire"),
        ("shoulder_armpit", (0.24, 1.38, 0.0), (2.0, -1.2, 2.5), 0.55, "body"),
        ("shoulder_armpit_wire", (0.24, 1.38, 0.0), (2.0, -1.2, 2.5), 0.55, "wire"),
        ("hand_palm", (-0.50, 1.14, 0.21), (0.0, 0.0, 2.0), 0.30, "body"),
        ("hand_back", (-0.50, 1.14, 0.21), (0.0, 0.0, -2.0), 0.30, "body"),
        ("hand_three_quarter", (-0.50, 1.14, 0.21), (-1.5, -1.2, 1.8), 0.30, "body"),
        ("hand_wire", (-0.50, 1.14, 0.21), (0.0, 0.0, 2.0), 0.30, "wire"),
        ("pelvis_front", (0.0, 0.90, 0.0), (0.0, 0.0, 2.5), 0.52, "body"),
        ("pelvis_back", (0.0, 0.90, 0.0), (0.0, 0.0, -2.5), 0.52, "body"),
        ("perineal_receiver", (0.0, 0.79, -0.01), (0.0, 2.0, 1.5), 0.34, "semantic"),
        ("pelvis_wire", (0.0, 0.90, 0.0), (0.0, 0.0, 2.5), 0.52, "wire"),
        ("knee", (-0.10, 0.50, 0.0), (0.0, 0.0, 2.0), 0.32, "body"),
        ("ankle", (-0.10, 0.10, 0.0), (2.0, 0.0, 1.5), 0.32, "body"),
        ("foot_top", (-0.10, 0.05, 0.13), (0.0, 2.0, 0.0), 0.42, "body"),
        ("foot_side", (-0.10, 0.06, 0.12), (2.0, 0.0, 0.0), 0.42, "body"),
        ("toe_wire", (-0.10, 0.04, 0.21), (0.0, 1.5, 2.0), 0.32, "wire"),
        ("torso_breast_front", (0.0, 1.27, 0.02), (0.0, 0.0, 2.5), 0.72, "body"),
        ("torso_breast_side", (0.0, 1.27, 0.02), (2.5, 0.0, 0.0), 0.72, "body"),
        ("torso_breast_wire", (0.0, 1.27, 0.02), (0.0, 0.0, 2.5), 0.72, "wire"),
    ]
    image_names = []
    for name, target, offset, scale, mode in views:
        body.hide_render = mode != "body"
        wire.hide_render = mode != "wire"
        semantic.hide_render = mode != "semantic"
        q.render_view(scene, camera, output / f"human_base_main_body_{name}.png", target, offset, scale)
        image_names.append(f"images/human_base_main_body_{name}.png")

    working = Path(args.working)
    working.parent.mkdir(parents=True, exist_ok=True)
    body.hide_render = False
    wire.hide_render = True
    semantic.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=str(working.resolve()), check_existing=False)
    write_json(Path(args.evidence_dir) / "hm08_t3_visual_index.json", {
        "source_sha256": EXPECTED_AUTHORITY_SHA256,
        "topology_version": "2.0.0",
        "topology_revision": 4,
        "images": image_names,
    })
    print(f"HM08_ADOPTION_RENDER_OK images={len(image_names)} working={working}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--qualification-module", required=True)
    parser.add_argument("--evidence-dir", required=True)
    parser.add_argument("--working", required=True)
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    render(parser.parse_args(arguments))


if __name__ == "__main__":
    main()
