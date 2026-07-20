# Controller Demonstration Controls

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

## Keyboard

| Control | Action |
| --- | --- |
| `A` or Left Arrow | Move left |
| `D` or Right Arrow | Move right |
| Space | Jump; release while rising for a shorter jump |
| `E` | Produce interaction intent; Prompt 5 deliberately has no interaction action |
| `R` | Reset controller, pending input, animation playback, procedural springs, previous-motion sampling, and interpolation state |
| `F1` | Toggle authoritative static-collider visualization |
| `F2` | Cycle normal speed, quarter speed, and paused |
| `F3` | Advance exactly one 240 Hz simulation/animation tick while paused |

Opposing keyboard directions cancel to zero. A keyboard direction has magnitude one and therefore wins an equal-magnitude gamepad tie. Zero input preserves the last meaningful facing direction.

## Gamepad

| Control | Action |
| --- | --- |
| Left stick horizontal | Move |
| South button | Jump |
| West button | Produce interaction intent |

The left-stick dead zone is `0.20`; magnitude outside it is rescaled continuously to `[0, 1]`. Keyboard and gamepad movement are merged by selecting the value with greater absolute magnitude. The lowest SDL joystick instance ID is selected deterministically. Add/remove events reopen the lowest available device, every opened handle is closed explicitly, and keyboard control remains available with no gamepad.

## Input timing

SDL state is sampled once per rendered frame. `FrameInputSnapshot` records pressed, held, and released state. `PendingInput` preserves jump press, jump release, and interaction press edges through a frame that executes no fixed tick. The first following tick consumes each edge once; later ticks in the same rendered frame receive held state without replaying the edge. Reset and pause transitions clear pending edges.
