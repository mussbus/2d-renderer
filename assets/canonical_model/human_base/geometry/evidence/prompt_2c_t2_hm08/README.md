# Prompt 2C-T2 hm08 qualification evidence

This directory contains derived inspection evidence only. It does not contain
canonical geometry and does not authorize replacement of
`human_base_geometry.authoring.json`.

- hm08 asset SHA-256: `bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950`
- current R1 source SHA-256: `e501458b9cf78991aa4290bcecd81ebcc5cb112d4c735c2a9e0a381653766623`
- current R1 topology SHA-256: `23a3575d1e8aa25bc14f630ead9e5f1fabef36b18acfccd0cdc407a6e750b931`
- current M02 structural SHA-256: `b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda`

## Deterministic text evidence

- `hm08.provenance.json`: exact source, revision, hashes, license, and authority status.
- `hm08.qualification_metrics.json`: raw/body/helper topology, alignment,
  quality, intersection, symmetry, landmark, seam, and mapping results.
- `hm08.landmark_mapping.tsv`: all 35 M02 landmark feasibility records.
- `hm08.seam_candidates.json`: ordered candidate edge loops for all 11 M02 seams.
- `hm08.m02_semantic_mapping.tsv`: all 208 regions and 208 surfaces.
- `hm08.visual_index.json`: machine-readable image inventory.

## Whole body

- `images/hm08_whole_front.png`: front neutral form.
- `images/hm08_whole_back.png`: back and glute form.
- `images/hm08_whole_left.png`: left side silhouette.
- `images/hm08_whole_right.png`: right side silhouette.
- `images/hm08_whole_three_quarter.png`: depth and transition inspection.
- `images/hm08_whole_wire_front.png`: full control topology, front.
- `images/hm08_whole_wire_side.png`: full control topology, side.

## Head and face

- `images/hm08_head_front.png`
- `images/hm08_head_side.png`
- `images/hm08_head_three_quarter.png`
- `images/hm08_face_wire.png`
- `images/hm08_eyelid_topology.png`
- `images/hm08_mouth_topology.png`
- `images/hm08_ear_topology.png`

## Shoulder and torso

- `images/hm08_shoulder_armpit.png`
- `images/hm08_shoulder_armpit_wire.png`
- `images/hm08_torso_front.png`
- `images/hm08_torso_side.png`
- `images/hm08_chest_breast.png`
- `images/hm08_torso_wire.png`

## Hands

- `images/hm08_hand_left_palm.png`
- `images/hm08_hand_left_back.png`
- `images/hm08_hand_left_side.png`
- `images/hm08_hand_left_wire.png`
- `images/hm08_thumb_web_left.png`

## Pelvis and lower body

- `images/hm08_pelvis_front.png`
- `images/hm08_pelvis_back.png`
- `images/hm08_pelvis_side.png`
- `images/hm08_pelvis_groin_wire.png`
- `images/hm08_knee_front.png`
- `images/hm08_knee_side.png`
- `images/hm08_knee_wire.png`
- `images/hm08_ankle_front.png`
- `images/hm08_ankle_side.png`
- `images/hm08_ankle_wire.png`
- `images/hm08_foot_top.png`
- `images/hm08_foot_side.png`
- `images/hm08_foot_three_quarter.png`
- `images/hm08_foot_sole.png`
- `images/hm08_foot_toes.png`
- `images/hm08_foot_wire.png`

## Upstream helpers, inspected separately

- `images/hm08_helper_genital_shaded.png`
- `images/hm08_helper_genital_wire.png`
- `images/hm08_helper_tongue.png`
- `images/hm08_helper_eyes.png`
- `images/hm08_helper_teeth.png`

The genital helper is a coarse open reference cage and is not accepted adult
anatomy. The other helper images likewise show reference data, not project
geometry.

## Direct R1 comparison

- `images/compare_r1_vs_hm08_whole.png`
- `images/compare_r1_vs_hm08_head.png`
- `images/compare_r1_vs_hm08_shoulder.png`
- `images/compare_r1_vs_hm08_hand.png`
- `images/compare_r1_vs_hm08_pelvis.png`
- `images/compare_r1_vs_hm08_knee.png`
- `images/compare_r1_vs_hm08_ankle.png`
- `images/compare_r1_vs_hm08_foot.png`

`panel_r1_*.png` and `panel_hm08_*.png` are the deterministic source panels
used to compose those comparisons.
