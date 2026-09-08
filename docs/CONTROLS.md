# Production controls and interactive playground

Run the open-ended interactive playground with:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo playground --interactive
```

The primary integrated foundation playground is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo foundation --interactive
```

It retains every production movement, interaction, timing, debug, resize, and exit control. The focused `playground` route remains available unchanged.

It runs until Escape, an SDL window-close request, or an optional `--frames` limit. Walk right toward the passive character. A handshake can begin only when both characters are grounded, the player faces right, the passive character faces left, and their fixed roots are within the authored `3.72 m ± 0.02 m` envelope. There is no root snap, facing correction, or motion warping. Hold Space for the higher jump; releasing it while rising produces the existing shorter jump.

Character-presence overlap is continuously measured in this interactive route
but is not collision authority. Walking close to or through the passive
character does not terminate the process. Scripted acceptance evidence uses
the same measurement with fail-closed enforcement. The ordinary `0.02` and
active-interaction `0.15` thresholds are unchanged.

The bounded production-path verification is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 1800 --demo playground --scripted-input
```

Synthetic input constructs the same physical per-key/button state returned by
SDL polling, then calls the one application-owned `SnapshotBuilder` mapping in
`src/app/demo_actions.zig`. It never constructs `CharacterIntent` directly.

The bounded Prompt 14 camera and parallax route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 1100 --demo side-scroller --scripted-input
```

It holds the mapped left control until the character crosses the extended cave, then releases to demonstrate normal controller deceleration. The deterministic camera uses a `3.25 m` horizontal dead zone; cave background, midground, and gameplay layers respond at `0.125`, `0.45`, and `1.0` respectively. This route does not write controller position or bypass collision.

F4B2 retired the duplicate Prompt 20 attachment-secondary route and the
standalone Prompt 24 character-presentation routes. Attachment behavior remains
covered by permanent tests plus the retained `mesh-attachments` route.
Presentation behavior remains covered by permanent tests plus the retained
`foundation` and `anatomy-quality` inspection routes.

The visible playground window is resizable. Its 640×480 reference composition
uses 82 pixels per metre; every valid high-DPI drawable derives its scale as
`82 * drawable_height / 480`. Taller resolutions increase rendered pixel
detail while keeping the vertical world span fixed, and wider aspect ratios
expose additional horizontal world without stretching. Minimize can
temporarily produce no drawable and safely skips presentation while retaining
the last valid camera. Restore or repeated resize events refresh the drawable
pixel dimensions without recreating unrelated GPU resources. There are no
manual zoom controls.

## Controller demonstration

Run the interactive controller demonstration with:

```powershell
zig build run -- --demo controller
```

Run the finite deterministic acceptance route with:

```powershell
zig build run -- --frames 600 --demo controller --scripted-input
```

The scripted mode generates raw platform-neutral button and axis state, passes it through the same frame snapshot, pending-edge, `CharacterIntent`, controller, animation, sprite-batch, and SDL GPU path as interactive control, and exits nonzero if its required milestones do not complete.

F4B2 retired the Prompt 6 secondary-motion, Prompt 7 multi-character, and
Prompt 8 non-IK handshake scenario shells. Their fixed-tick, isolation,
ordering, transaction, ownership, cleanup, and allocation invariants now run
through `zig build test`.

Run the deterministic Prompt 9 IK route with:

```powershell
zig build run -- --frames 720 --demo handshake-ik --scripted-input
```

This route issues three real interaction requests. It demonstrates nominal contact, the mirrored arrangement, then a legal `3.74 m` perturbed spacing. Each run shows fixed-tick blend-in, full contact, blend-out, cleanup, and ordinary idle restoration. The target is the shared midpoint of both pre-IK hand sockets; demo code never assigns arm rotations directly.

F4B2 retired the Prompt 10 foot-planting scenario shell. Ground-query,
contact, leg-IK, jump/reset, schedule, and interaction-coexistence invariants
now run through `zig build test`.

## Keyboard

| Control | Action |
| --- | --- |
| `A` or Left Arrow | Move left |
| `D` or Right Arrow | Move right |
| Space | Jump; release while rising for a shorter jump |
| Left Shift | Dash when the resolved character capabilities grant it |
| `E` | Produce an interaction intent; the fixed-position handshake route consumes its press edge |
| `R` | Reset controller, pending input, animation playback, procedural springs, previous-motion sampling, and interpolation state |
| `F1` | Cycle visual-truth diagnostics: Off → Rig → Rig + Visual Registration → All Diagnostics → Off |
| `F4` | Capture one same-state visual-truth bundle; this is a frame diagnostic and never creates `CharacterIntent` |
| `F2` | Cycle normal speed, quarter speed, and paused |
| `F3` | Advance exactly one 240 Hz simulation/animation tick while paused |
| `C` | Cycle the controlled body preset in the foundation playground |
| `V` | Cycle global build in the foundation playground |
| `H` | Cycle short, long, and ponytail hair in the foundation playground |
| `L` | Legacy alias for cycling complete outfit presets in the Prompt 27 foundation route |
| `O` | Cycle complete outfit presets in wardrobe and foundation routes |
| `P` | Pause or resume wardrobe/foundation simulation |
| `T` | Cycle the preloaded environment theme in environment and foundation routes |
| `Q` | Cycle automatic, force side, and force front where presentation inspection is exposed |
| Escape | Exit the interactive playground |

Opposing keyboard directions cancel to zero. A keyboard direction has magnitude one and therefore wins an equal-magnitude gamepad tie. Zero input preserves the last meaningful facing direction.

The deterministic integrated route is selected with `--demo integrated --scripted-input`. Add `--debug-visualization` to display collider edges, roots, ground queries/hits, foot targets, IK segments/target, and the participant link. This flag is accepted only for the integrated demo and changes debug submissions/diagnostic counters, never fixed-tick input or simulation state.

## Gamepad

| Control | Action |
| --- | --- |
| Left stick horizontal | Move |
| South button | Jump |
| Right shoulder | Dash when the resolved character capabilities grant it |
| West button | Produce interaction intent |

The left-stick dead zone is `0.20`; magnitude outside it is rescaled continuously to `[0, 1]`. Keyboard and gamepad movement are merged by selecting the value with greater absolute magnitude. The lowest SDL joystick instance ID is selected deterministically. Add/remove events reopen the lowest available device, every opened handle is closed explicitly, and keyboard control remains available with no gamepad.

## Input timing

SDL state is sampled once per rendered frame into physical
`RawInputState`. The application mapper produces `FrameInputSnapshot` with
pressed, held, and released state. Its `PendingInput` preserves jump press,
jump release, dash press, and interaction press edges through a frame that
executes no fixed tick. The first following tick consumes each edge once;
later ticks in the same rendered frame receive held state without replaying
the edge. Reset and pause transitions clear pending edges.

Keyboard gameplay edges come from previous/current polled physical state, never SDL keydown repeat or text input. `A` and Left Arrow are one logical left direction; `D` and Right Arrow are one logical right direction. Holding both logical directions resolves to zero independently of press order. Keyboard/gamepad action buttons merge by logical OR, so simultaneous sources produce one edge. Horizontal values use greatest absolute magnitude, with keyboard winning equal-magnitude ties.

On keyboard-focus loss, the current keyboard hold state is cleared, pending jump/dash/interaction presses are discarded, and a required jump release is retained for the next fixed tick. Reset, debug, and interaction presses are not synthesized. Keys physically held across focus regain remain suppressed until released, so regain cannot create a phantom press. Gamepad polling remains independent; its live state continues to participate in the merged snapshot. Existing pending edges are cleared before new state from the focus-loss frame is accepted.

F4B2 retired the bounded Prompt 21 properties shell. Permanent property/controller tests synthesize the same production intents and retain denied/allowed dash, wall collision, facing, cooldown, and restoration coverage.

The original Prompt 22 procedural foundation scene is retained as a focused
1,800-frame regression:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build test-foundation
```

Its `C`, `V`, `H`, and `L` changes originate as
`RawInputState.KeyboardState`, become pressed/held/released fields in
`FrameInputSnapshot`, and are consumed as frame-level customization commands.
Movement, jump, dash, and interaction continue through
`PendingInput -> CharacterIntent`; no gameplay or character code polls SDL.
The scripted viewport changes call the same platform-neutral camera method as
real resize events and assert that pending edge count and authoritative
gameplay state are unchanged.

Prompt 27 keeps that input boundary while replacing the visible `foundation`
CLI owner with the production
character, wardrobe, and environment presentations. `L` remains a legacy
loadout-cycle alias; `O` performs the same complete outfit-preset cycle. `T`
changes the preloaded environment theme. `Q` cycles automatic/front/side
inspection, and an active handshake temporarily owns the required side view.
Completion, cancellation, and reset release that ownership.

| Input | Prompt 27 foundation action |
|---|---|
| `A` / Left Arrow | Move left; automatic side-left presentation |
| `D` / Right Arrow | Move right; automatic side-right presentation |
| `Space` | Jump; release while rising for a shorter jump |
| Left Shift | Dash |
| `E` | Request the eligible fixed-root handshake |
| `C` | Cycle body preset |
| `V` | Cycle global build |
| `H` | Cycle hair |
| `L` or `O` | Cycle complete transactional outfit presets |
| `T` | Cycle violet cavern / neutral debug environment |
| `Q` | Cycle automatic / forced-front / forced-side presentation |
| `P` | Pause/resume |
| `F1` | Cycle Off / Rig / Rig + Visual Registration / All Diagnostics |
| `F2` | Cycle normal / quarter-speed / paused time |
| `F3` | Advance one fixed tick while paused |
| `F4` | Capture one clean/debug/JSON/summary/manifest visual-truth bundle |
| `R` | Full integrated reset |
| Escape | Exit |

Deterministic route:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\engine_sandbox.exe' --demo foundation --scripted-input --frames 2400
& '.\.deps\zig-0.16.0\zig.exe' build p27a-review
```

This uses synthetic snapshots, not physical-keyboard evidence. Prompt 27A
shows a read-only acceptance HUD in the evidence window with current phase,
capture target, facing/view, outfit/theme, support/velocity, interaction
lifecycle/phase, and debug count. The HUD cannot mutate the route. Clean
D3D12 capture files exclude the HUD; capture 15 includes the actual detailed
production diagnostics. Owner visual acceptance remains pending.

Prompt 27B retains those controls and the same state-conditioned matrix. Its
script routes the partner clear and back with ordinary controller intent so
the player does not visibly traverse through the other character. An
allocation-free visible-bounds detector fails uncontrolled scripted overlap,
but this is not general interactive character collision: two manually
controlled characters can still pass through one another because controllers
collide only with the immutable static world. Prompt 27B also adds clean
camera-resize evidence and debug-only surface/sole/safe-bound/parallax rulers;
those rulers do not alter controls or simulation.

Foundation reset restores the player spawn, velocity, grounded/support state, air-jump and dash counters, interaction/IK/override ownership, foot locks, animator/procedural/breathing state, body/build/hair selection, per-part override, default loadout, resolved attributes/capabilities, mesh/secondary runtime state, fixed-step clock, pending edges, and camera center. It preserves the current nonzero viewport extent and creates no GPU resource.

VF-01 changes F1 from a toggle to the ordered mode cycle shown above. Reset
preserves the selected mode, matching the established rule that reset must not
hide an inspection overlay. F4 is sampled as a pressed/held/released
frame-level diagnostic edge. Holding it cannot repeat a capture; release and a
new press are required. F4 never enters `PendingInput` or
`CharacterIntent`.

Successful F4 captures are finalized under
`zig-out/manual_debug_captures/<UTC>_<monotonic-index>/`. Manual directory
names are timestamped; automated Prompt 27 evidence IDs and filenames remain
deterministic and untimestamped. An incomplete capture remains a hidden
`.incomplete` directory and is never presented as a complete bundle.

The latest playground input diagnostic is fixed-size and read-only. It exposes `keyboard_left_held`, `keyboard_right_held`, `jump_pressed`, `jump_held`, `jump_released`, `interact_pressed`, `reset_pressed`, `debug_toggle_pressed`, `merged_move_axis`, `substeps_this_frame`, and `pending_edge_count`. Interactive console output is transition-only and bounded by actual control transitions; held state is not printed each frame.

Playground reset restores both characters, the controlled physics state, animator/procedural state, interaction ownership and overrides, arm/foot constraints, fixed-step clock, and pending gameplay edges. The current debug-enabled choice and bounded lifetime input counters are retained so a reset neither hides the overlay nor erases verification evidence; the latest diagnostic is replaced by the reset frame with zero pending edges. No GPU resource is recreated.

## Prompt 25 wardrobe inspection

Run `zig build run -- --demo wardrobe --interactive`.

- O cycles the next complete typed outfit preset transactionally.
- P pauses or resumes simulation while leaving presentation available for inspection.
- Q cycles automatic, forced-side, and forced-front presentation.
- R resets the controlled female, clears her loadout state, equips the first preset, restores automatic timing, and unpauses.
- Movement and jump retain the established A/D, arrows, and Space mappings.

O and P are sampled by `sdl_input.PlatformInput` only as physical key state.
`demo_actions.SnapshotBuilder` maps them to application-owned
pressed/held/released fields in `FrameInputSnapshot`. Focus loss clears pending
customization edges and suppresses held keys until physical release, so
refocus cannot synthesize an outfit change or pause toggle. Preset selection
never bypasses `CharacterIntent` for movement and never polls SDL from scene
code.

The deterministic route is `zig build run -- --demo wardrobe --scripted-input --frames 600`. It uses programmatic scene selection for repeatable preset/view evidence and synthetic input tests for O/P edge semantics. It is not evidence of physical keyboard or gamepad use.

## Prompt 26 environment inspection

Run:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo environment --interactive
```

`T` swaps between the preloaded violet crystal ruin and neutral debug world in
place. The input edge does not enter `CharacterIntent`; it is consumed by the
environment presentation owner before the unchanged character snapshot enters
the controller. `F1` toggles detailed cyan/orange collider outlines, while the
thin white top edges remain visible as normal product presentation. `O`, `P`,
`Q`, movement, jump, reset, resize, and Escape retain their existing meanings.

VF-02 adds or remaps no controls. The VF-01 F1 cycle and F4 one-shot bundle
path now expose authoritative registration mode, policy, target, and residual
data for migrated components.

For repeatable VF-02 review, the initialization-only diagnostic selector is:

```powershell
& '.\zig-out\bin\engine_sandbox.exe' --demo foundation --interactive `
  --registration-proof-case <body-front|body-side-left|body-side-right|equipped-front|equipped-side-left|equipped-side-right>
```

It selects existing presets, view overrides, and authoritative controller
facing before the first simulation tick. It creates no gameplay intent and
cannot be applied after simulation begins. F4 then captures the ordinary
production queue and truth snapshot. The current schema-3 bundle identifies
rendered versus closed-footwear-suppressed records and exports the shared
anatomy/shoe point-axis evidence; the selector itself adds no presentation
authority.

VF-03 adds or remaps no interactive controls. For repeatable component-graph
review, use the initialization-only diagnostic selector:

```powershell
& '.\zig-out\bin\engine_sandbox.exe' --demo foundation --interactive `
  --component-proof-case <disabled|continuous-front|intentional-gap-front|continuous-side-left|continuous-side-right|intentional-gap-side-left|intentional-gap-side-right|two-modules> `
  --capture-manual-bundle
```

The selector chooses the bounded optional-arm preset, connection policy, and
presentation view before the first simulation tick. Active front and side
cases submit the optional upper arm, forearm, and hand through the real
character-art queue. `--capture-manual-bundle` invokes the same one-shot
frame-level capture request as F4; it does not create gameplay intent or a
parallel renderer. F1 still owns the four diagnostic modes and F4 still
captures exactly one same-state bundle per physical press. VF-03 bundles use
schema 4 and ordinary timestamped manual naming; automated Prompt evidence
names remain deterministic and untimestamped.


## Persistent Engine Lab

Normal Engine Lab launch opens the expanded two-level hub. Walk left from the
installations to the marked ledges. Hold Space for a full jump; press again while
airborne for one additional jump. Landing replenishes it. Left Shift dashes in
the movement direction, or facing direction when stationary. The far upper gap
can be crossed by jumping and then dashing. Falling returns to the safe floor.

| Keyboard / gamepad | Engine Lab action |
| --- | --- |
| A/D, arrows / left stick | Move |
| Space / south | Ground jump, then one additional air jump |
| Left Shift / right shoulder | Horizontal dash on a fresh press |
| E / west | Fire beside the launcher; eight concurrent projectiles |
| F1 / F2 | Reposition beside Links / Damping, preserving the running hub |
| P / T | Pause / execute one full simulation tick while paused |
| R | Reconstruct the entire expanded hub |
| F3 / Escape | Diagnostics / exit |

F1 Links shows the fixed parent/child anchors and their spring-driven masses.
F2 Damping compares three spring responses with different damping and plots their
recent offsets. They are persistent engine installations, not movement modes.
LAG is the accepted horizontal secondary-motion calibration above the actor.
The upper-right label shows logical world day/time from executed ticks. Pause
freezes it; navigation preserves it; reset returns to D0 23:59. Projectile activation
checks both horizontal and vertical proximity, including when above the launcher.
See the [traversal record](implementation/engine_lab_traversal_expansion.md) for
measured routes and pending owner visual/gamepad acceptance.
