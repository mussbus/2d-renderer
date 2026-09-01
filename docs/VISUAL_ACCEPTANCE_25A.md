# Prompt 25A Visual Acceptance

> Historical evidence only. Prompt 25C quantitatively rejects this previously
> accepted Prompt 25B-derived output for footwear orientation/registration/fit,
> clothing fit, and articulation geometry. Nothing in this document is a
> current visual golden or overrides `VISUAL_GEOMETRY.md`.

## Evidence source

The acceptance route is:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\engine_sandbox.exe' --frames 600 --demo visual-quality --scripted-input
```

It writes eleven 640 by 480 P6 captures from the same prepared global
sprite/mesh queue that is submitted to the visible SDL GPU window. The capture
copy uses a persistent transfer buffer created before the resource checkpoint;
it does not create a per-frame resource or a per-character path. The runtime
must report Direct3D 12, DXIL agreement, exactly eleven captures, six decoded
art pages after Prompt 25B, zero post-stabilization allocation, and zero
GPU-resource delta.

Normal-size PNGs, nearest-neighbor 2x PNGs, the contact sheet, and the direct
before/after comparison are under:

```text
zig-out/p25a_visual_gpu/
zig-out/p25a_visual_gpu_final_contact.png
zig-out/p25b_visual/
zig-out/p25b_followup_final/
```

The rejected Prompt 25 capture remains unchanged at
`zig-out/p25_visual_final/contact_00.png`.

## Checklist

Every capture was inspected at normal presentation size and nearest-neighbor
2x. `P` means the pixels passed the stated criterion. `N/A` is used only where
the capture intentionally has no removable clothing or shows the other authored
view.

Abbreviations: `Float` floating body parts; `Gap` large background-colored
joint gaps; `Foot` detached feet; `Hand` detached hands; `Sh`, `El`, `Hip`,
`Knee`, and `Ank` connected shoulders, elbows, hips, knees, and ankles; `Prop`
coherent proportions; `Sil` one-character silhouette; `Worn` clothing conforms
to the body; `Layer` wardrobe registration; `Hair` hair/headwear registration;
`Base` modesty surface is not a censor/debug rectangle; `Detail` coherent pixel
and detail scale; `Front` and `Side` intentionally authored view; `Seg`
segmentation is not conspicuous at normal scale.

| Capture | Float | Gap | Foot | Hand | Sh | El | Hip | Knee | Ank | Prop | Sil | Worn | Layer | Hair | Base | Detail | Front | Side | Seg |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01 base front | P | P | P | P | P | P | P | P | P | P | P | N/A | N/A | P | P | P | P | N/A | P |
| 02 base side | P | P | P | P | P | P | P | P | P | P | P | N/A | N/A | P | P | P | N/A | P | P |
| 03 wide brim and male outfit front | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P |
| 04 wide brim and male outfit side | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P | P |
| 05 ivory blouse front | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P |
| 06 ivory blouse side | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P | P |
| 07 layered custom front | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P |
| 08 layered custom side | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P | P |
| 09 locomotion stride | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P | P |
| 10 jump rise | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P | P |
| 11 jump fall | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | P | N/A | P | P |

These marks are based on the following concrete pixel observations:

| Capture | Concrete observation |
| --- | --- |
| `01_base_front.png` | The final hard-gate capture shows compact torso-owned deltoids flowing into narrow upper arms without round balls, dark elbow bands, or arm-root compression. The male neutral base bridge remains behind cap-free proximal thighs, so lower torso, pelvis, and thighs read continuously without resembling shorts or a codpiece. Female hands remain proportionate to the forearms. |
| `02_base_side.png` | The dedicated profile heads, torsos, pelvises, hands, and feet read as side art. Both arm chains stay within/along the torso silhouette, both legs reach the feet, and the male pelvis layer conceals the former horizontal hip seam. |
| `03_wide_brim_and_male_outfit_front.png` | The brim crosses the female crown without replacing long hair. Halter and shorts are centered on both bodies, thigh-highs meet the lower legs, and reflected `0.05/0.95` shoe pivots keep two distinct shoes on their corresponding semantic feet instead of piling both at viewer right. |
| `04_wide_brim_and_male_outfit_side.png` | Hat and hair retain a readable profile. Tops wrap the profile torso, shorts meet the pelvis, legwear follows both shins, and shoe soles remain at the planted foot line. |
| `05_ivory_blouse_front.png` | Alpha-tight sleeve extraction puts both puffed sleeves at the shoulders and both cuffs at the wrists. The blouse center remains independent from the sleeves, shorts remain independent from the blouse, and the shoe cutouts cover the semantic feet. |
| `06_ivory_blouse_side.png` | The two topology-expanded sleeves overlap the profile shoulders instead of floating at the elbows. The blouse collar follows the neck, the shorts follow the side pelvis, and the footwear remains grounded. |
| `07_layered_custom_front.png` | Ivory blouse and sleeves remain visible beneath the separately occupied outer cardigan and outer sleeves. The cardigan center, skirt, gloves, patterned legwear, hat, hair, and shoes retain their intended layer order without collapsing into a monolithic outfit. |
| `08_layered_custom_side.png` | The cardigan follows the profile torso while the ivory underlayer remains visible at the neck and sleeve edges. Skirt, glove, legwear, hat/hair, and footwear retain registration in the side view. |
| `09_locomotion_stride.png` | Hip and knee rotation produces a continuous bent leg; the leading and trailing shoes follow their semantic feet. Cardigan, blouse sleeves, glove, skirt, and long hair follow the same authoritative pose without opening a background gap. |
| `10_jump_rise.png` | Compression/bend at hip, knee, and ankle remains covered during ascent. The shoes remain attached, the blouse/cardigan stack stays on the torso and arms, and no secondary visual separates from its owner. |
| `11_jump_fall.png` | The falling pose keeps both leg chains, feet, hands, sleeves, and layered torso continuous. The altered bend differs from rise while preserving the same authored side silhouette and layer registration. |

## Acceptance conclusion

The final output is a substantial visual correction over the rejected baseline:
ordinary front, side, locomotion, rise, and fall poses no longer expose large
background gaps or detached paper-doll chains. Anatomy remains modular and
clothing remains reusable; the renderer conceals those boundaries through
source extraction, pivots, controlled overlap, projection, and layer order.

Minor enlarged-scale limitations are recorded in
`PROMPT25A_DECISION_RECORD.md` and `PROMPT25B_DECISION_RECORD.md`; none becomes
a normal-scale background gap or a detached body part.

The final verification snapshot passed the complete aggregate gate, the
104-file repository audit, Debug/ReleaseSafe/ReleaseFast builds, D3D12/DXIL GPU
smoke, Prompt 23/24/25 regression routes, and this exact 600-frame route.
The route retained 127456 initialized/final bytes, submitted 60 sprites through
15 global ranges/draws, and reported zero update, submission, queue, or
GPU-resource growth.
