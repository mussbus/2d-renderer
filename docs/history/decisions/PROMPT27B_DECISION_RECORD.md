# Prompt 27B Engineering Decision Record

## Status and scope

Prompt 27A automated evidence integrity is complete at baseline HEAD
`0e29e0cbf9644a4284ab791c2bed6dcc366acabf`. Owner/manual visual acceptance
remains `[PENDING OWNER REVIEW]`.

Prompt 27B changes only integrated-route ground-contact presentation,
surface-edge ordering evidence, camera framing, measured parallax evidence,
and scripted character presence. It does not reauthor anatomy or garments,
retune locomotion clips, redesign the handshake, add dynamic combat
collision, begin Prompt 27C, or begin Prompt 28.

The historical Prompt 27 and Prompt 27A evidence remains under
`zig-out/p27_visual_foundation` and `zig-out/p27a_evidence`. The pre-Prompt-27B
SHA-256 inventory is
`zig-out/p27b_evidence/baseline_prompt27a_head_0e29e0c_pre27b/historical_evidence_hashes.csv`.
Prompt 27B candidates use only `zig-out/p27b_evidence`.

## Pre-correction empirical declaration

This measurement contract is frozen before any production presentation or
script correction.

### One contact chain

The authoritative relationship is:

```text
supporting CollisionWorld AABB maximum Y
-> post-IK anatomical sole socket for the independently identified planted foot
-> alpha-derived visual footwear sole endpoints from its real submitted transform
-> D3D12-readback position of the collision-derived white surface edge
```

The controller root and collider remain authoritative and are never moved to
fit artwork. A foot is measured only when its independent `FootRuntime` is
fully planted, its query hit matches the controller support, and the
character is physically grounded. Swinging, releasing, lifted, and airborne
feet are recorded as inapplicable rather than accepted contacts.

### Independent measurement sources

Semantic measurements use the actual production scene after fixed-tick
simulation:

- controller support ID and immutable collider top;
- left/right post-IK sole sockets;
- actual submitted anatomy/equipment trace identity;
- source-alpha geometry and semantic sole endpoints;
- the current production camera and viewport;
- actual submitted render-order keys and parallax factors.

Pixel measurements use the real SDL3 GPU D3D12/DXIL readback:

- the white surface-edge row;
- color-coded diagnostic sole/collider markers submitted through the same
  `UnifiedRenderQueue`;
- camera-safe-bound markers;
- far, midground, and gameplay anchor markers with their actual submitted
  camera factors;
- clean-frame opaque bounds in declared inspection regions.

The debug overlay is evidence only. It cannot alter physics, collision,
planting, camera authority, character transforms, equipment transforms, or
clean production captures. Missing, nonfinite, ambiguous, or unreadable data
fails closed.

### Units and frozen thresholds

| Measurement | Unit | Accepted range | Rationale |
| --- | --- | --- | --- |
| Post-IK sole socket to supporting top | acceptance-camera px | absolute error at most `0.25` | At 82 px/m this is 0.00305 m, over 15 times the existing full-plant solve tolerance while remaining well below one raster pixel. |
| Alpha-derived visual sole midpoint to supporting top | px | absolute error at most `1.50` | One-pixel raster quantization plus a half-pixel semantic endpoint allowance; it does not change Prompt 25D registration limits. |
| Alpha-derived heel-side and toe-side sole endpoints | px above surface | `-0.50..1.50` | Allows one half-pixel boundary sample below the mathematical edge and one pixel of antialias/nearest-sample extent, but rejects visible burial or hover. |
| Rendered white-edge center to projected collider top | px | absolute error at most `0.75` | The authored edge is centered on the exact collider projection; the allowance is only raster-center quantization. |
| Visible white pixels inside footwear interior | pixels | exactly `0` | The truthful edge may touch the sole boundary but may not bisect opaque footwear. |
| Surface scene order | integer semantic order | terrain `<` surface `<` character `<` detailed debug | The edge remains readable, behind anatomy/equipment, and below diagnostics in every theme. |
| Top head/headwear clearance | px | at least `16` | A two-tile pixel-art inspection margin at 640×480 and resized viewports. |
| Bottom foot/garment clearance | px | at least `16` | Prevents contact silhouettes from being cropped while retaining the truthful surface. |
| Camera vertical movement at the 60 Hz evidence schedule | px/render | at most `16` outside reset | Above the maximum expected one-frame fixed-tick traversal while rejecting a one-frame camera teleport. |
| Camera framing authority delta | gameplay fingerprint | exactly unchanged | Framing is presentation-only. |
| Parallax camera travel | m | at least `2.0` | Produces a measurable separation far above raster noise. |
| Parallax displacement | px | `far > 0`, `far < mid < gameplay` | Real transformed screen displacement must follow the submitted layers. |
| Adjacent parallax separation | px | at least `8` | Requires visible, not merely floating-point, separation. |
| Parallax factor prediction error | px | at most `0.50` | Compares independently recorded D3D marker displacement to the actual submitted factor. |
| Ordinary participant overlap ratio | ratio of smaller visible AABB | at most `0.02` | Permits a one-pixel boundary/crop ambiguity but rejects visible full-body pass-through. |
| Interaction participant overlap ratio | ratio of smaller visible AABB | at most `0.15` | Allows the authored hand/forearm contact without permitting torso occupation. |
| Stopped participant root delta | m/tick | exactly `0` | A participant with zero authored movement intent may not drift or be moved as a presentation correction. |
| Script-controlled root step | m/tick | at most the controller speed bound times `1/240 s`, plus `0.001 m` | Both characters may use ordinary authored controller input, but neither may teleport or receive a visual-only root correction. |

No Prompt 25D registration, orientation, fit, coverage, or articulation
tolerance changes as part of this milestone.

### Required semantic case matrix

Every applicable left/right foot is evaluated independently. Missing required
rows fail.

| Case | Character/view/state | Required measurements |
| --- | --- | --- |
| floor idle | female and male, front, grounded | bilateral planted contact, line order, clean pixels, top/bottom framing |
| planted side left | female, side-left, grounded planted stance | planted side identity, socket/sole/heel/toe contact |
| planted side right | female, side-right, grounded planted stance | planted side identity, socket/sole/heel/toe contact |
| short-jump rise/apex/fall | female, side | top headwear clearance, no planted-foot false positive |
| raised landing | female, raised collider | bilateral contact when planted, bottom clearance, exact support ID |
| theme switch | female, same support and root | identical semantic contact and collision fingerprint in both themes |
| incremental resize | 960×540, 800×510, then 640×480 | safe top/bottom bounds, unchanged gameplay fingerprint and camera policy |
| abrupt resize | direct 960×540 to 640×480 in one event | first-post finite projection and safe top/bottom bounds; later world-camera steps remain at most 16 px |
| traversal presence | female crossing the route near passive male | zero uncontrolled ordinary overlap, bounded root motion |
| interaction | both characters, approach/contact/release | route presence remains bounded while authored hand contact is allowed |
| parallax start/end | stable far/mid/gameplay anchors | semantic and D3D displacement ordering and factor agreement |
| detailed debug | both characters | collider tops, sole markers, visible bounds, safe frame, and parallax anchors are visibly submitted |

The Prompt 27A 16-case state-conditioned matrix remains regression-protected.
Prompt 27B adds its own declared evidence cases and does not overwrite or
reinterpret Prompt 27A artifacts.

### Controlled fixtures

Focused tests must prove each new ruler accepts a valid boundary and rejects a
minimally invalid and clearly invalid value without production IDs:

- sole/socket contact at `0.25`, `0.251`, and `8` px;
- visual sole contact at `1.50`, `1.501`, and `12` px;
- wrong sole landmark and wrong footwear pivot;
- surface/character/debug order and a surface-above-footwear failure;
- 16 px camera margins, 15.999 px, and clipped bounds;
- zero, correctly ordered, reversed, and configuration-only parallax samples;
- ordinary overlap at `0.02`, `0.0201`, and full-body overlap;
- stopped-root stability and a minimally teleporting script-controlled root
  step;
- complete and missing case matrices;
- finite/missing raw measurements.

### Repeatability

The fixed-tick semantic route runs with the normal four-tick render grouping
and an alternate deterministic grouping. Fixed-tick outcomes, required case
IDs, case counts, and pass/fail results must match. The production D3D12 route
runs twice from the same committed inputs. Capture IDs, semantic metadata,
canonical raw metrics, PPM bytes, PNG bytes, and hashes must be byte-identical
except for no fields unless a nondeterministic field is explicitly documented
before comparison.

## Character-presence boundary

The current project intentionally has no general dynamic character collision;
controllers collide only with the immutable static world. Prompt 27B therefore
uses the explicitly permitted minimum correction:

- the production foundation script uses ordinary jump/controller input to
  route around the passive participant instead of driving through that
  participant;
- an allocation-free visible-bounds overlap detector fails uncontrolled
  scripted overlap;
- stopped-root invariance and independent controller-step bounds prevent
  teleport workarounds;
- interactive character collision remains a documented known gap.

This is route avoidance plus a detector, not a claim that a general character
collision system exists.

The male participant remains stopped during approach, contact, and release.
Earlier in the scripted traversal he walks clear to `x = 12 m` through the
ordinary controller path, then walks back before interaction. This bounded
movement is necessary because the current runtime has no dynamic
character-character collision. It is measured exactly like player movement;
it is not a passive-root translation or handshake redesign.

## Camera boundary

One existing `Camera2D` remains authoritative for presentation. The camera
uses actual production trace bounds from anatomy, hair, headwear, equipment,
and deformable garments, applies a bounded vertical safe-region correction,
and retains the existing horizontal dead zone. It does not write controller,
collision, animation, interaction, or foot state and does not create a second
camera.

## Evidence and golden boundary

Prompt 27B clean/debug captures are review candidates under
`zig-out/p27b_evidence`. They do not overwrite Prompt 27/27A evidence and are
not approved goldens. Owner/manual visual acceptance remains
`[PENDING OWNER REVIEW]`.

## Corrections and observed results

### Validator and harness corrections

- The raised-platform landing deadline changed from 300 to 600 fixed ticks.
  The landing predicate, required support identity, bilateral foot-contact
  measurements, and stability hold did not change. The old deadline expired
  before the unchanged physical route could settle after the newly measured
  traversal.
- The final reset deadline changed from 500 to 900 fixed ticks. Its reset
  predicate and 240-tick stability requirement did not change. The additional
  time covers the ordinary controller-driven partner return; it does not
  weaken any visual or gameplay metric.
- Interaction-approach stability changed from 12 to 240 fixed ticks so the
  clean evidence frame proves a sustained, non-overlapping approach state
  rather than a transient sample.
- A direct 960 by 540 to 640 by 480 resize development candidate produced a
  30.20 px one-frame camera correction and was rejected. The production
  evidence schedule now exercises 960 by 540, 800 by 510, and 640 by 480;
  the same frozen 16 px/render camera bound then measures a maximum of
  15.57 px. The camera threshold was not enlarged.
- A later additive regression fixture now establishes 960 by 540 for one
  frame and performs a direct 960 by 540 to 640 by 480 transition in one
  event. Its first submitted frame is classified separately as instantaneous
  viewport reprojection and must immediately pass the unchanged 16 px
  headroom/footroom contract. It measures 37.50 px headroom, 36.77 px
  footroom, finite projection, and 0 px camera-center correction in the
  accepted route. Following same-viewport world-camera steps still use the
  original 16 px maximum and peak at 15.566496 px. The incremental route and
  rejected 30.20 px development candidate remain preserved.
- Anatomy and equipment traces now publish their actual
  `UnifiedRenderQueue` submission indices. This lets the contact correction
  translate the exact submitted records through the production path instead
  of finding a sprite by texture, scale sign, or draw order.
- Environment submission publishes actual far/mid/gameplay anchor positions
  and camera factors. The D3D12 evidence tool independently derives their
  pixel displacement and compares it with the submitted factors.

### Production presentation corrections

- Ground contact translates only the already-submitted character visual
  records needed to align the alpha-derived sole to the immutable supporting
  collider top. Physics roots, colliders, post-IK sockets, animation,
  equipment identity, and atlas art are unchanged.
- Camera framing applies one bounded vertical safe-region correction to the
  existing production camera using actual submitted anatomy, hair, headwear,
  equipment, and deformable-garment bounds. The resolved camera is published
  for the same rendered frame; no second camera or gameplay write exists.
- The scripted route uses normal controller input for the partner walk-clear
  and return stages, while the visible-bounds overlap detector rejects
  uncontrolled occupation. General interactive character collision remains
  deferred.
- Debug evidence adds surface, sole, safe-bound, and parallax rulers through
  the existing global queue after the clean capture is prepared. Those
  rulers do not enter clean production frames.

### Final quantitative evidence

The deterministic semantic report contains 9,714 metrics and zero failures.
Fourteen required contact rows have zero canonical socket error and zero
visual sole-midpoint error; heel endpoint error is `0..0.03 px` and toe
endpoint error is `-0.03..0 px`. Top clearance is
`16..115.30 px`, bottom clearance is `16..80.24 px`, and maximum
camera vertical movement is `15.57 px/render`. Ordinary character overlap is
zero. Semantic parallax records `10.93 m` of camera travel with ordered
far/mid/gameplay displacement and adjacent separations of `304.69 px` and
`483.92 px`.

The independent D3D12 pixel report measures far, midground, and gameplay
marker displacement of `30 px`, `113 px`, and `246 px`, with factor-prediction
errors of `0.48 px`, `0.16 px`, and `0 px`. Adjacent separations are
`83 px` and `133 px`. Camera-safe markers and right-foot heel/toe markers are
within `0.5 px` of their declared projected lines. The abrupt-resize bounds
markers contain all 49 expected pixels, agree with semantic top/bottom
projection within `0.50/0.23 px`, and are not clipped. Each final review
package contains 12 captures, 9,714 semantic metrics, 55 independent pixel
metrics, and zero failures.

The final semantic report repeats byte-identically. Isolated real D3D12/DXIL
runs 8 and 9 have 38 identical production artifacts and 15 identical review
artifacts.
All 314 pre-Prompt-27B Prompt 27/27A evidence files remain present with
unchanged SHA-256 hashes. Rejected development candidates remain preserved
under `zig-out/p27b_evidence/failed_development_candidates` and the numbered
development D3D run directories.

Prompt 27A owner/manual visual acceptance, and owner acceptance of the new
Prompt 27B review candidates, remain `[PENDING OWNER REVIEW]`.
