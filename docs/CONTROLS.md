# Production controls and interactive playground

Run the open-ended interactive playground with:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --demo playground --interactive
```

It runs until Escape, an SDL window-close request, or an optional `--frames` limit. Walk right toward the passive character. A handshake can begin only when both characters are grounded, the player faces right, the passive character faces left, and their fixed roots are within the authored `3.72 m ± 0.02 m` envelope. There is no root snap, facing correction, or motion warping. Hold Space for the higher jump; releasing it while rising produces the existing shorter jump.

The bounded production-path verification is:

```powershell
& '.\.deps\zig-0.16.0\zig.exe' build run -- --frames 1800 --demo playground --scripted-input
```

Synthetic input constructs the same per-key raw state used by SDL polling, then calls the one `SnapshotBuilder` mapping. It never constructs `CharacterIntent` directly.

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
| `E` | Produce an interaction intent; the fixed-position handshake route consumes its press edge |
| `R` | Reset controller, pending input, animation playback, procedural springs, previous-motion sampling, and interpolation state |
| `F1` | Toggle authoritative static-collider visualization |
| `F2` | Cycle normal speed, quarter speed, and paused |
| `F3` | Advance exactly one 240 Hz simulation/animation tick while paused |
| Escape | Exit the interactive playground |

Opposing keyboard directions cancel to zero. A keyboard direction has magnitude one and therefore wins an equal-magnitude gamepad tie. Zero input preserves the last meaningful facing direction.

The deterministic integrated route is selected with `--demo integrated --scripted-input`. Add `--debug-visualization` to display collider edges, roots, ground queries/hits, foot targets, IK segments/target, and the participant link. This flag is accepted only for the integrated demo and changes debug submissions/diagnostic counters, never fixed-tick input or simulation state.

## Gamepad

| Control | Action |
| --- | --- |
| Left stick horizontal | Move |
| South button | Jump |
| West button | Produce interaction intent |

The left-stick dead zone is `0.20`; magnitude outside it is rescaled continuously to `[0, 1]`. Keyboard and gamepad movement are merged by selecting the value with greater absolute magnitude. The lowest SDL joystick instance ID is selected deterministically. Add/remove events reopen the lowest available device, every opened handle is closed explicitly, and keyboard control remains available with no gamepad.

## Input timing

SDL state is sampled once per rendered frame. `FrameInputSnapshot` records pressed, held, and released state. `PendingInput` preserves jump press, jump release, and interaction press edges through a frame that executes no fixed tick. The first following tick consumes each edge once; later ticks in the same rendered frame receive held state without replaying the edge. Reset and pause transitions clear pending edges.

Keyboard gameplay edges come from previous/current polled physical state, never SDL keydown repeat or text input. `A` and Left Arrow are one logical left direction; `D` and Right Arrow are one logical right direction. Holding both logical directions resolves to zero independently of press order. Keyboard/gamepad action buttons merge by logical OR, so simultaneous sources produce one edge. Horizontal values use greatest absolute magnitude, with keyboard winning equal-magnitude ties.

On keyboard-focus loss, the current keyboard hold state is cleared, pending jump/interaction presses are discarded, and a required jump release is retained for the next fixed tick. Reset, debug, and interaction presses are not synthesized. Keys physically held across focus regain remain suppressed until released, so regain cannot create a phantom press. Gamepad polling remains independent; its live state continues to participate in the merged snapshot. Existing pending edges are cleared before new state from the focus-loss frame is accepted.

The latest playground input diagnostic is fixed-size and read-only. It exposes `keyboard_left_held`, `keyboard_right_held`, `jump_pressed`, `jump_held`, `jump_released`, `interact_pressed`, `reset_pressed`, `debug_toggle_pressed`, `merged_move_axis`, `substeps_this_frame`, and `pending_edge_count`. Interactive console output is transition-only and bounded by actual control transitions; held state is not printed each frame.

Playground reset restores both characters, the controlled physics state, animator/procedural state, interaction ownership and overrides, arm/foot constraints, fixed-step clock, and pending gameplay edges. The current debug-enabled choice and bounded lifetime input counters are retained so a reset neither hides the overlay nor erases verification evidence; the latest diagnostic is replaced by the reset frame with zero pending edges. No GPU resource is recreated.
