# Height-relative viewport scaling evidence

Date: 2026-07-31

Baseline HEAD: `bbc4f0ffd9328940ceeb269e2bc294bb4914beed`

This is new corrective numeric evidence. It is deliberately outside the
historical Prompt 27/27A accepted-evidence locations, and no historical
capture, report, manifest, or golden was regenerated.

## Focused command

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-camera -Doptimize=Debug -j1 --summary all --cache-dir '.zig-cache\camera-scaling-debug' --global-cache-dir '.zig-cache\camera-scaling-global'
```

Observed result: exit code 0; 12/12 focused tests passed.

## Height scaling

The test uses the production `Camera2D.setViewport` path and measures a known
one-metre vertical reference at the unchanged camera center. The reference's
world height is therefore exactly `1.0 m`; its measured pixel height is the
last column below.

| Viewport | Effective px/m | Vertical span (m) | Horizontal span (m) | Camera center (m) | 1 m reference (px) |
|---|---:|---:|---:|---:|---:|
| 640×480 | 82.000000 | 5.853658700 | 7.804878000 | (0.000000, 1.646341) | 82.000 |
| 1280×720 | 123.000000 | 5.853658700 | 10.406504000 | (0.000000, 1.646341) | 123.000 |
| 1920×1080 | 184.500000 | 5.853658700 | 10.406504000 | (0.000000, 1.646341) | 184.500 |
| 2560×1440 | 246.000000 | 5.853658700 | 10.406504000 | (0.000000, 1.646341) | 246.000 |
| 3840×2160 | 369.000000 | 5.853658700 | 10.406504000 | (0.000000, 1.646341) | 369.000 |

The 1080p and 2160p viewports have identical horizontal and vertical world
spans. Their known-reference pixel-height ratio is `369 / 184.5 = 2`, so the
higher resolution supplies twice the pixels rather than twice the world.

## Aspect behavior at equal height

At drawable height 1080, the vertical span remained `5.853658700 m` while the
measured horizontal spans were:

| Width | Horizontal span (m) |
|---:|---:|
| 960 | 5.203252000 |
| 1920 | 10.406504000 |
| 2560 | 13.875339000 |

The focused gate also passed uniform one-metre X/Y projection, inverse
world/presentation transforms, the multi-size return to exactly 82 px/m at
640×480, transactional zero-height rejection, and recovery to 184.5 px/m at
the next valid 1920×1080 update.

## Scene and runtime boundary

`test-foundation` passed 4/4 and compared controller state, animation state and
time, character world transform, metre-space collider half-extents, camera
center, loadout/appearance/gameplay state, and pending input edges across
resize. `test-visual-foundation` passed
50/50, including eight subsequent production update/submission cycles that
retained 184.5 px/m after a 1920×1080 resize. `test-environment` passed 13/13.

The unchanged Prompt 27B production fixture emitted 9,752 semantic metrics
with zero failures. Its 2,395 ordinary same-viewport camera measurements
peaked at `12.915119 px/render` under the unchanged `16 px/render` maximum.
Four drawable changes were classified separately as viewport reprojections;
the original incremental and direct-resize route timing remains intact.

The final full Debug suite and `check` target each passed 434/434 tests. Debug,
ReleaseSafe, and ReleaseFast executable builds passed 20/20 build steps. The
physical-GPU smoke passed 22/22 steps using the actual `direct3d12` SDL GPU
driver, DXIL shaders, one indexed-instanced draw for two instances, and exact
640×480 readback pixels within channel tolerance 1. The repository audit also
confirmed all 12 historical Prompt 25D 640×480 D3D12 goldens unchanged.

The automated rendered GPU evidence remained the fixed 640×480 smoke route;
no physical drag-resize run at 1280×720 or 1920×1080 and no real visible
3840×2160 window were exercised. The larger rows are headless production-camera
math, including the required 1080p-to-2160p `2.0` pixel-height ratio. Physical
drag-resize, DPI-transition, and visible 4K behavior remain pending manual
owner review.
