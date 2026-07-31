# ADR-006: Height-relative viewport scaling

Status: accepted, pending manual resize review

Date: 2026-07-31

## Decision

The normal production camera preserves the established 640×480 composition at
82 pixels per metre. Its immutable vertical world span is `480 / 82`, or
approximately `5.85365854 m`. For every positive drawable height, the camera
atomically calculates:

```text
effective_pixels_per_metre = 82 * drawable_height / 480
```

The calculation never uses the previous viewport or scale. One effective
pixels-per-metre value applies to both axes. Resolution changes at the same
aspect ratio show the same world with more or fewer pixels; aspect-ratio
changes affect horizontal visibility only.

The existing Prompt 27B 16-pixel top and bottom safe-region margins are
interpreted at the 480p reference and converted to constant world margins
through 82 px/m. They therefore scale in rendered pixels with drawable height
without moving the camera center solely because resolution changed. The
historical 640×480 ruler remains exactly 16 pixels.

Prompt 27B classifies a changed drawable as viewport reprojection, not as a
same-viewport world-camera step. The first submitted frame at a non-reference
height places its visible bounds at the midpoint of the valid vertical
safe-region interval only when those bounds independently require correction.
Already-safe identical bounds keep the exact prior center. Later frames resume
nearest-edge correction under the unchanged 16 px/render limit. Returning to
the 480-pixel reference height does not request that one-frame recenter.

## Authority and lifetime

Logical SDL window coordinates are not camera authority. Resize, pixel-size,
and restore events query `SDL_GetWindowSizeInPixels`. The renderer also accepts
the dimensions returned when the SDL GPU swapchain texture is acquired and
stores the latest valid drawable width and height once. Production scene
cameras synchronize from those values before per-frame publication, and the
renderer reapplies them before GPU encoding.

Zero or minimized drawable dimensions mark presentation unavailable. They do
not mutate the last valid camera or calculate a scale. The next positive size
derives directly from the immutable reference values.

## Compatibility and supersession

At 640×480 the camera remains 82 px/m, retains the same center and world
extents, and leaves fixed D3D12 readback captures and historical evidence
unchanged. This decision supersedes the former fixed-pixel-density resize
policy documented for Prompt 14. Historical reports remain historical.

No manual zoom, pan redesign, UI scale, art/atlas change, shader change,
simulation change, or new character-authoring pipeline is part of this
decision. Manual physical drag-resize and visible 4K acceptance remain owner
review work.

The focused numeric results are recorded in the current
[height-relative viewport evidence report](../reports/viewport-height-scaling-evidence.md).
