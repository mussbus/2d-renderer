# Prompt 26 decision record

## Production composition

Decision: add an environment evidence scene that owns `wardrobe_demo.Scene`
rather than duplicating Prompt 24/25D character art or replacing Prompt 22.
`wardrobe_demo.Scene.initWithConfiguration` is an additive initializer for
caller-supplied static colliders and spawn/facing values; the original
initializer and all prior routes retain their exact defaults.

Rationale: the environment milestone needs the accepted male/female art and
wardrobe while retaining one collision/controller/clock implementation.
Composition preserves those paths and keeps Prompt 26 presentation-only.

## Theme identity

Decision: theme identity is a two-value enum and art-pack view identity, not a
filesystem path, string lookup, or mutable pack.

Rationale: both themes must be available before steady state. Fixed resolved
records make switching allocation-free and prevent file I/O or GPU ownership
from entering the input path.

## Collision-derived edges

Decision: cache a fixed projection of eligible collider tops at scene
initialization, then validate it against the immutable collision world before
submission.

Rationale: the authoritative world is immutable in this milestone. Caching
avoids redundant semantic discovery while the validation prevents drift. The
projection copies exact source coordinates and IDs; it is not a separately
authored collision representation.

Decision: reserve a four-by-four opaque white atlas region in each theme page.

Rationale: the renderer's page-zero procedural texture is a colored test
checker, so tinting it white would not produce white pixels. Declaring a real
white art-pack region keeps product edges honest without adding a texture,
renderer branch, or per-frame resource.

## Decorative ledges

Decision: decorative ledges are fixed theme presentation placements and never
enter `CollisionWorld`.

Rationale: this proves the visible-art/collision boundary and ensures the
white-edge derivation cannot accidentally bless visual-only geometry.

## Debug separation

Decision: persistent white tops use the world-order band; optional collider
outlines use the existing debug-overlay band and cyan/orange colors.

Rationale: a player-facing standability cue must remain visible without debug,
while detailed collider inspection must remain unmistakably diagnostic.

## Art provenance and processing

Decision: use original generated pixel-art source compositions, then
deterministically crop, nearest-neighbor resize, remove the generated
checkerboard matte, pack fixed atlas cells, and reserve the white source
region.

Rationale: the generation output did not honor exact canvas dimensions or
true alpha. Deterministic post-processing produced the required 1024×1024 RGBA
runtime assets and stable region coordinates. The source cavern reference was
used only for violet mood/depth; Prompt 23 assets were used only for project
style continuity.

## Evidence-route staging

Decision: switch themes while the controlled character is stationary, then
drive the unchanged controller through a real jump onto the first raised
collider. Record the first non-floor supporting-collider landing frame and
capture that exact frame.

Rationale: root-state snapshots prove an in-place switch quantitatively, while
paired stationary captures make that preservation visually inspectable.
Requiring a non-floor support ID prevents an ordinary return to the floor from
overstating platform evidence.

Decision: retain the established 82 pixels-per-metre scale and give the
environment route one theme-independent `+0.72 m` vertical camera composition
offset.

Rationale: the default staging leaves insufficient headroom for a complete
jump in a 640 by 480 frame. The offset changes neither physics nor projection
scale and is identical for both themes.

## Host condition and resolution

Early whole-application attempts stopped at Zig's cache layer with
`manifest_create AccessDenied` before semantic compilation. Fresh repository
and temporary caches showed the same transient host condition. A later
single-threaded warmed repository cache succeeded: the linked Debug
application built, the 720-frame real D3D12/DXIL route completed, and all seven
readback captures were produced. The transient failures are retained here so
future maintainers do not misclassify them as source compilation results.
