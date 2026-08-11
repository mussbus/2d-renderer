#!/usr/bin/env python3
"""Render Prompt 2C-R4 evidence through the accepted R3 renderer."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


RENDERER = Path(__file__).with_name("render_human_geometry_r3_evidence.py")
SPEC = importlib.util.spec_from_file_location("r4_evidence_renderer", RENDERER)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load deterministic evidence renderer at {RENDERER}")
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)
MODULE.EXPECTED_AUTHORITY_SHA256 = "4bed342c289f1f1238c7397c524b63e32d2037737cde08304fe5c47af1b43b8f"
MODULE.EXPECTED_NORMALIZED_SHA256 = "d7fee949a5ee70c926f19dc46615fa965fa2d75176ba1fc0ea4e02d50aa9b096"
MODULE.EXPECTED_TOPOLOGY_SHA256 = "335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191"
MODULE.EVIDENCE_PROMPT = "Prompt 2C-R4"
MODULE.COLLECTION_NAME = "PROMPT_2C_R4_REVIEW"
MODULE.INDEX_FILENAME = "r4_visual_index.json"
MODULE.SUCCESS_LABEL = "R4_EVIDENCE_RENDER_OK"


if __name__ == "__main__":
    MODULE.main()
