# Environment themes

## Scope

Prompt 26 adds layered environment presentation without adding a second world,
collision map, camera, renderer, or simulation route. The production evidence
route composes the Prompt 24/25D character and wardrobe presentation with the
Prompt 22 static collision coordinates:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-environment -j1
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo environment --scripted-input --frames 720
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo environment --interactive
```

The two shipped themes are:

- `violet_crystal_ruin`: an original violet crystal cavern and geometric ruin
  composition.
- `neutral_debug`: a restrained charcoal, blue-gray, cyan, and orange
  diagnostic chamber.

The supplied cavern image informed only high-level violet mood, depth, and
lighting composition. No referenced architecture, character, UI, logo, or
exact arrangement is used. The Prompt 23 atlases informed the established
crisp pixel-art language. Both Prompt 26 production atlases are original
project assets.

## Data and ownership

`environment_art.Definition` is an ordinary Prompt 23 art pack. Stable theme,
visual-role, region, page, and view identities resolve during initialization.
The seven visual roles are:

```text
far_backdrop
midground_structure
terrain_body
foreground_frame
decorative_ledge
accent_cluster
surface_white
```

`environment_theme.ThemeInput` contains only stable theme identity and visual
tints. It cannot contain collision boxes, player spawns, interaction
positions, or camera coordinates. `environment_theme.Catalog` resolves both
themes into fixed arrays and offsets their local page indices into the global
renderer page table.

The environment scene borrows the existing world, character, wardrobe, camera,
fixed clock, and global mixed render queue. It owns only:

- the immutable environment art definition;
- two fixed resolved theme records;
- the active two-value theme ID;
- a fixed-capacity collision-derived surface overlay;
- bounded evidence and debug state.

Theme selection does not decode a file, perform name lookup, allocate, create
or destroy a GPU resource, upload data, change draw topology capacity, or
write gameplay state.

## Layering and parallax

All environment sprites enter `UnifiedRenderQueue`. There is no environment
renderer.

| Layer | Scene order | Camera X factor | Purpose |
| --- | ---: | ---: | --- |
| Far backdrop | `-30000` | `0.12` | Deep cavern/chamber depth |
| Midground structure/accent | `-20000` band | `0.46` | Ruins, braces, crystals, beacons |
| Terrain/decorative ledges | `-10000` band | `1.00` | Gameplay-readable local world |
| Standable white tops | `-9500` | `1.00` | Collision-derived product language |
| Characters/wardrobe | `0` | `1.00` | Existing production presentation |
| Foreground framing | `10000` | `1.00` | Bounded edge occlusion |
| Detailed collider debug | `30000` | `1.00` | Optional cyan/orange diagnostics |

The far and midground factors are the established Prompt 22 factors. Camera
following and viewport changes remain `Camera2D` operations. The environment
route keeps the established 82 pixels-per-metre scale and horizontal follower,
with one theme-independent `+0.72 m` vertical composition offset so a complete
jump remains inside the deterministic 640 by 480 evidence frame. Both themes
use that same camera state. A resize changes only viewport projection; it does
not change character scale, world coordinates, collision, pending input, clock
state, theme selection, or camera center.

## Authoritative standable edges

White top edges are normal product presentation, not debug geometry. At scene
initialization `SurfaceOverlay.init` enumerates the existing immutable
`CollisionWorld.colliders` array in definition order and accepts only:

```text
solid == true
ground_query_eligible == true
```

For each accepted collider it copies exactly the collider ID, minimum X,
maximum X, and maximum Y. Submission uses that segment directly. The white
source is a declared `surface_white` art-pack region containing opaque white
pixels. It is not the procedural red/green/blue/yellow test texture. The
resulting quad is above terrain, behind characters, and below detailed debug.

The Prompt 22 environment has six such segments: the floor and five raised
platforms. The left/right walls are solid but ineligible and receive no white
top. Theme-owned floating decorative ledges are never added to the collision
world and therefore receive no white edge. Tests compare count, collider IDs,
and all endpoint coordinates exactly, and validate the cached overlay against
the collision world before every submission.

Detailed collider debug is a separate optional overlay. Eligible collider
outlines are cyan; non-eligible walls are orange. It remains visually and
semantically distinct from the persistent white product edges.

## Hot-swap invariants

`T` changes only `Presentation.active_theme` and a bounded diagnostic counter.
The switch operation snapshots and verifies:

- controller position, previous position, velocity, facing, grounding, support,
  jump/dash state, and simulation tick;
- male/female roots, facing, resolved presentation view, and view override;
- male/female interaction ownership;
- male/female equipment item fingerprints and current preset/custom state;
- pause state, fixed-clock accumulator, scene frame/tick, and pending input
  edges;
- camera center;
- complete collision and standable-surface fingerprints.

Both theme pages are decoded, uploaded, and retained before the first frame.
Switching selects already-resolved page/UV data. GPU creation and decode
metrics are sampled after initialization and must remain unchanged through
the complete scripted route.

Reset restores the production character/world reset contract and selects
`violet_crystal_ruin`. It does not rebuild collision or the surface overlay.

The scripted evidence route switches both themes while the controlled
character is stationary, then drives the unchanged controller onto collider
4. Completion requires the first floor-to-raised-platform landing to be
observed with a non-floor supporting-collider ID; a generic return to the floor
does not satisfy the route.

## Future level-editor boundary

A future level editor may author static collider inputs and stable IDs,
ground-query eligibility, spawn/interaction markers, camera bounds, and
theme-independent level identifiers. An environment theme may author art-pack
bindings, visual roles, color treatment, decorative non-collision placements,
and validated parallax/depth metadata.

Collision/world data must serialize separately from theme presentation. A
theme can be replaced without changing the level fingerprint. White standable
edges remain derived output and must never be hand-authored, painted into
terrain, or serialized as independent gameplay geometry. Future themes and
editor previews must use the same global queue and production camera; an
editor-only renderer or collision copy is outside this boundary.

## Bounds

- 2 themes.
- 2 environment texture pages.
- 7 semantic visual roles per theme.
- At most 64 derived surface segments, matching the collision-world maximum.
- 8 total production art pages and 9 renderer texture pages including the
  procedural page.
- No steady-state CPU allocation, GPU resource creation, file I/O, decode, or
  topology upload.

## Prompt 27 production integration

`visual_foundation.Scene` composes this environment scene directly; it does
not copy the world, collision, surface overlay, camera, theme catalog, or
character instances. The visible `--demo foundation` route therefore uses the
same eight colliders, six derived white surface segments, two preloaded themes,
parallax factors, theme switch, reset, and global queue as the focused Prompt
26 route.

The current 2,400-frame Prompt 27A acceptance matrix changes themes around movement, outfit
changes, jumps, raised-platform traversal, and three handshakes. Each
handshake record retains its active theme ID, and the route proves that a
theme change cannot alter interaction participants, role views, roots, contact
ticks, wardrobe identity, or collision fingerprints. Sixteen real D3D12
captures and metadata under `zig-out/p27a_evidence/candidate` include both
themes and detailed debug. The original nine Prompt 27 captures remain
historical under `zig-out/p27_visual_foundation`.

Prompt 27B traces the actual submitted far, midground, and gameplay anchors
and camera factors. The semantic route proves ordered displacement over
10.93 m of camera travel; independent D3D12 pixels measure
`30/113/246 px` of far/mid/gameplay movement with `0.48/0.16/0 px`
factor-prediction error. The collision-derived white edge remains between
terrain and characters in semantic order, projects within `0.5 px` of its
collider top, and contributes no white pixels inside opaque footwear.
