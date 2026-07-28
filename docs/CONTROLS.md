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

The bounded production-path verification is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 1800 --demo playground --scripted-input
```

Synthetic input constructs the same per-key raw state used by SDL polling, then calls the one `SnapshotBuilder` mapping. It never constructs `CharacterIntent` directly.

The bounded Prompt 14 camera and parallax route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 1100 --demo side-scroller --scripted-input
```

It holds the mapped left control until the character crosses the extended cave, then releases to demonstrate normal controller deceleration. The deterministic camera uses a `3.25 m` horizontal dead zone; cave background, midground, and gameplay layers respond at `0.125`, `0.45`, and `1.0` respectively. This route does not write controller position or bypass collision.

The bounded Prompt 20 modular attachment-secondary route is timeline-driven and needs no physical input:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 240 --demo attachment-secondary
```

It uses copied authoritative velocity/landing/facing samples to demonstrate cape, long-hair, ponytail, and loose-sleeve response plus cape unequip/re-equip. It never creates `CharacterIntent`, moves a controller root, or assigns spring nodes from the script.

The Prompt 24 visual-inspection route is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo character-presentation --interactive
```

`Q` cycles automatic, force side, and force front. `H` toggles bald/buzz hair for the controlled male. These are frame-level presentation commands: neither changes gameplay facing or constructs a gameplay intent. The scripted acceptance route uses exactly 360 frames and requires `--scripted-input` instead of `--interactive`.

The visible playground window is resizable. Larger drawable pixel dimensions reveal more world at the same 82 pixels per metre. Minimize can temporarily produce no drawable and safely skips presentation; restore or repeated resize events refresh the high-DPI pixel dimensions without recreating unrelated GPU resources.

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

Run the Prompt 6 procedural-motion evidence route with:

```powershell
zig build run -- --frames 900 --demo secondary-motion --scripted-input
```

This separate script starts idle, walks at a rescaled `0.60` gamepad axis, changes to full reverse input, settles, and sends a real reset edge. It then delegates to the unchanged controller route. Every spring update occurs inside a resulting fixed simulation tick; the script never assigns controller or spring state directly.

Run the deterministic Prompt 7 two-character occlusion route with:

```powershell
zig build run -- --frames 720 --demo multi-character
```

This route is timeline-driven rather than player-controlled. Nine fixed 80-frame phases demonstrate both actor orders, both hand-over-hand orders, forearm-over-torso interleaving, exact restoration, and independent character mirroring. It does not implement a handshake or character-to-character physics.

Run the deterministic Prompt 8 paired-interaction route with:

```powershell
zig build run -- --frames 720 --demo handshake --scripted-input
```

This route generates two real `interact_pressed` edges through `SnapshotBuilder`, `PendingInput`, and `CharacterIntent`. The first starts with A left of B; after normal completion the demo stages the same stable entities in the mirrored idle arrangement and issues a new press. The coordinator never moves either root. Holding the button across several render frames produces only one request, and a release/new press is required for the mirrored run.

Run the deterministic Prompt 9 IK route with:

```powershell
zig build run -- --frames 720 --demo handshake-ik --scripted-input
```

This route issues three real interaction requests. It demonstrates nominal contact, the mirrored arrangement, then a legal `3.74 m` perturbed spacing. Each run shows fixed-tick blend-in, full contact, blend-out, cleanup, and ordinary idle restoration. The target is the shared midpoint of both pre-IK hand sockets; demo code never assigns arm rotations directly.

Run the deterministic Prompt 10 foot-placement route with:

```powershell
zig build run -- --frames 1200 --demo foot-planting --scripted-input
```

The feedback-driven script idles, walks with alternating contacts, jumps from a live foot lock, verifies no airborne locks, lands and replants from fresh samples, then uses ordinary controller movement to jump onto the first raised platform and records its different ground height. It ends idle and grounded on that platform. A hidden IK-disabled character receives the identical intent trace for exact physics and animation-timing comparison; only the enabled character is rendered.

## Keyboard

| Control | Action |
| --- | --- |
| `A` or Left Arrow | Move left |
| `D` or Right Arrow | Move right |
| Space | Jump; release while rising for a shorter jump |
| Left Shift | Dash when the resolved character capabilities grant it |
| `E` | Produce an interaction intent; the fixed-position handshake route consumes its press edge |
| `R` | Reset controller, pending input, animation playback, procedural springs, previous-motion sampling, and interpolation state |
| `F1` | Toggle authoritative static-collider visualization |
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

SDL state is sampled once per rendered frame. `FrameInputSnapshot` records pressed, held, and released state. `PendingInput` preserves jump press, jump release, dash press, and interaction press edges through a frame that executes no fixed tick. The first following tick consumes each edge once; later ticks in the same rendered frame receive held state without replaying the edge. Reset and pause transitions clear pending edges.

Keyboard gameplay edges come from previous/current polled physical state, never SDL keydown repeat or text input. `A` and Left Arrow are one logical left direction; `D` and Right Arrow are one logical right direction. Holding both logical directions resolves to zero independently of press order. Keyboard/gamepad action buttons merge by logical OR, so simultaneous sources produce one edge. Horizontal values use greatest absolute magnitude, with keyboard winning equal-magnitude ties.

On keyboard-focus loss, the current keyboard hold state is cleared, pending jump/dash/interaction presses are discarded, and a required jump release is retained for the next fixed tick. Reset, debug, and interaction presses are not synthesized. Keys physically held across focus regain remain suppressed until released, so regain cannot create a phantom press. Gamepad polling remains independent; its live state continues to participate in the merged snapshot. Existing pending edges are cleared before new state from the focus-loss frame is accepted.

The bounded Prompt 21 route is `zig build run -- --frames 240 --demo properties`. It synthesizes controller intents only after resolving real equipment declarations, proves denied and allowed dash behavior, and checks wall collision, facing, cooldown state, and restoration without adding a second input path.

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
| `F1` | Toggle detailed collider visualization |
| `F2` | Cycle normal / quarter-speed / paused time |
| `F3` | Advance one fixed tick while paused |
| `R` | Full integrated reset |
| Escape | Exit |

Deterministic route:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\skeletal_gpu_demo.exe' --demo foundation --scripted-input --frames 2400
& '.\.deps\zig-0.16.0\zig.exe' build p27a-review
```

This uses synthetic snapshots, not physical-keyboard evidence. Prompt 27A
shows a read-only acceptance HUD in the evidence window with current phase,
capture target, facing/view, outfit/theme, support/velocity, interaction
lifecycle/phase, and debug count. The HUD cannot mutate the route. Clean
D3D12 capture files exclude the HUD; capture 15 includes the actual detailed
production diagnostics. Owner visual acceptance remains pending.

Foundation reset restores the player spawn, velocity, grounded/support state, air-jump and dash counters, interaction/IK/override ownership, foot locks, animator/procedural/breathing state, body/build/hair selection, per-part override, default loadout, resolved attributes/capabilities, mesh/secondary runtime state, fixed-step clock, pending edges, and camera center. It preserves the current nonzero viewport extent and creates no GPU resource.

The latest playground input diagnostic is fixed-size and read-only. It exposes `keyboard_left_held`, `keyboard_right_held`, `jump_pressed`, `jump_held`, `jump_released`, `interact_pressed`, `reset_pressed`, `debug_toggle_pressed`, `merged_move_axis`, `substeps_this_frame`, and `pending_edge_count`. Interactive console output is transition-only and bounded by actual control transitions; held state is not printed each frame.

Playground reset restores both characters, the controlled physics state, animator/procedural state, interaction ownership and overrides, arm/foot constraints, fixed-step clock, and pending gameplay edges. The current debug-enabled choice and bounded lifetime input counters are retained so a reset neither hides the overlay nor erases verification evidence; the latest diagnostic is replaced by the reset frame with zero pending edges. No GPU resource is recreated.

## Prompt 25 wardrobe inspection

Run `zig build run -- --demo wardrobe --interactive`.

- O cycles the next complete typed outfit preset transactionally.
- P pauses or resumes simulation while leaving presentation available for inspection.
- Q cycles automatic, forced-side, and forced-front presentation.
- R resets the controlled female, clears her loadout state, equips the first preset, restores automatic timing, and unpauses.
- Movement and jump retain the established A/D, arrows, and Space mappings.

O and P are sampled only by `sdl_input.PlatformInput`, then carried as platform-neutral pressed/held/released fields in `FrameInputSnapshot`. Focus loss clears pending customization edges and suppresses held keys until physical release, so refocus cannot synthesize an outfit change or pause toggle. Preset selection never bypasses `CharacterIntent` for movement and never polls SDL from scene code.

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
