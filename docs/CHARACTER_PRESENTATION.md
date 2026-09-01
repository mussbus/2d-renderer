# Character Presentation

## Facing and view authority

Gameplay `Facing` remains the authoritative left/right direction. Prompt 24 adds a separate presentation `View` with `side` and `front` values. A grounded idle character automatically uses front; walking, dashing, jumping, rising, falling, and landing use side. The decision reads fixed-tick controller and animation state, never render delta.

An interaction definition owns a validated `PresentationDefinition` with one
optional view per semantic role, an automatic-view suppression flag, and a
typed occlusion-profile ID. The existing handshake requests side for both
roles, suppresses ordinary automatic selection while active, and claims those
views when participant locks are reserved. Completion, cancellation, reset,
or startup rollback releases them. Interaction authority has precedence over
the bounded debug override; the debug override has precedence over automatic
policy. Release immediately resumes ordinary policy. A synthetic definition
test selects front/front, proving that side view is content data rather than a
manager constant.

View changes are presentation-only. They do not modify the character root, controller velocity, collider, grounding/support, jump or dash state, resolved properties, equipment, interaction lock, animation clock, or anatomy topology. The last meaningful gameplay facing is retained while a character is shown from the front.

## Shared pose interpretation

Side presentation uses the existing evaluated appearance world transforms and the established single character-root X reflection. Only one side atlas is authored; anatomical left/right IDs, sockets, attachments, IK targets, equipment bindings, and spring ownership remain stable.

Front presentation is a fixed-capacity projection of the same authoritative local pose. It preserves the character world position, vertical pose motion, torso/head animation, breathing deformation, attachment-local deformation, and attachment secondary transform. View-specific arm rest offsets are presentation data; there is no front gameplay animator or second simulation.

Front projection never applies facing reflection. Its explicit semantic layers place anatomical left limbs behind the trunk and anatomical right limbs in front, independent of submission order. Anatomy names do not change according to screen position.

Every actual view transition clears bounded visual secondary state. The next fixed visual tick initializes springs from the new view's resolved rest configuration. This prevents stale side displacement from being mirrored into front space, avoids one-frame wrong-view hair, and leaves independent characters unchanged.

Prompt 27 adds one interaction-owned side-projection rule: the participating
right-arm chain preserves the authored animation/IK plane so coincident
authoritative hand sockets also render as coincident hands. The other arm and
the legs retain the ordinary readable side-profile remap. This affects only
presentation matrices after animation and IK; it cannot write canonical pose,
socket, target, root, physics, or timing state.

Wardrobe visuals retain their authored clothing layer and inherit only the
interaction layer of the actual bound anatomy semantic. Gloves, sleeves, and
other bound equipment therefore follow participant-qualified contact ordering
without outfit-specific branches. Cleanup releases both body and equipment
effects with the same owned interaction handles.

## Corrected base-anatomy production art pack

Prompt 24A replaced the clothing-baked pages. Prompt 25A re-authored that
separated content for continuous external presentation as two RGBA
nearest-sampled atlases:

- `assets/art/p25a_male_base_anatomy_atlas.png`, 1600 by 983: adult
  lean/athletic base anatomy, open overlap connectors, original buzz-cut art,
  and separate training-vest overlays;
- `assets/art/p25a_female_base_anatomy_atlas.png`, 1599 by 984: adult curvy base
  anatomy, open overlap connectors, original long-hair art, and separate
  training-vest overlays.

Prompt 25B adds `assets/art/p25b_anatomy_components_atlas.png`, 1792 by
1024 RGBA. Its 28 alpha-tight regions replace the production pelvis, arm,
hand, leg, and foot bindings for both styles and both views. It contains real
forearm and calf/shin art rather than source aliases. Male/female heads,
torsos, face features, hair, and training vests remain on the Prompt 25A pages.

Before the correction, the torso pixels contained a top, arms contained sleeves/cuffs, pelvis and legs contained trousers/shorts/stockings, and feet contained shoes or boots. Those images are no longer build inputs or installed assets. The corrected canonical torso, upper arm, forearm, pelvis, thigh, shin, foot, and hand regions contain only base-form pixels. Arms, legs, hands, and feet are bare neutral anatomy. Torso and pelvis use a smooth, opaque, skin-adjacent permanent modesty surface with no fabric edge, seam, waistband, neckline, or equipped-garment identity. That surface is classified as `base_presentation`: it is not an equipment item, cannot be unequipped, and preserves a neutral silhouette beneath arbitrary future clothing.

The two style pages deliberately co-pack character presentation and garment-only
vest regions; the component page co-packs male/female and side/front anatomy.
Across all three pages, `character_art.zig` still defines 68 regions, 92
`.character` semantic/view bindings, and four `.equipment` vest bindings.
Texture-page location is batching policy only. Typed binding kind, semantic ID,
and region ID retain ownership. `Presentation` resolves all canonical body
parts without resolving a garment. `Definition.validateAnatomyClothingBoundary`
rejects character/equipment identity crossover and verifies that the distinct
torso and vest identities genuinely share their style page.

Each style resolves side and front head, torso, pelvis, segmented arms/hands, segmented legs/feet, face features, and its supported hair. Bald means no active hair visual. Buzz cut and long hair are real view-specific regions. Authored region size, pivot, overlap, and rest rotation are content metadata; the engine does not impose pixel density or nearest sampling on future packs.

Prompt 25B removes front shoulder-root compression, mirrors anatomical left
components in front view, and derives side projection directly from the
authoritative pose before one view-specific arm remap. Prompt 25D projects
bilateral roots onto the strict profile centerline while preserving their
semantic identities and front/back draw order.
The final front torsos use compact rounded torso-owned deltoids without
sleeve-like arm stubs. Narrow curved-end upper-arm art is registered beneath
them through transparent atlas lead-in rather than a second shoulder bulb,
pose compression, or connector patch. Front forearms draw one local overlap
step above their upper arms to cover the source edge without changing either
joint transform. The male base-presentation pelvis uses a taller bridge behind
the torso and re-authored thighs; it remains character anatomy rather than
equipment.

Pelvis/thigh/shin connector order applies to both styles. Front equipment bound
to a left anatomy part mirrors both signed X scale and the authored horizontal
pivot. Negating scale without complementing the pivot caused the rejected
female shoes to collapse onto the same screen foot even though their semantic
bindings were correct. The corrected submissions retain the separate left and
right foot transforms. These are bounded presentation decisions over existing
semantic parts, not new anatomy, animation, or rendering paths.

The supplied reference images informed only broad adult proportions, build, limb length, and silhouette. No source pixels, logos, text, clothing catalog, or source-game assets were traced or copied. The third reference is explicit and was not supplied to image generation; only the brief's broad non-explicit body-shape requirements were used.

Both characters submit through the existing global `UnifiedRenderQueue`. The
final scripted frame has 46 sprites across three decoded atlas pages, four page
ranges, and four indexed-instanced draws. There is no per-character renderer
and no per-part command submission.

## Demonstration

F4B2 retired the standalone scripted character-presentation route after its
continuing invariants were mapped to `tests/character_presentation_tests.zig`.
Run them with `zig build test-presentation` or the aggregate `zig build test`.

The permanent suite retains automatic/forced views, facing invariance,
front/side projection, bald/buzz/long-hair mapping, interaction-owned side view
and cleanup, spring reset, character isolation, input behavior, and bounded
queue submission.

The retired open-ended shell formerly exposed `Q` and `H` directly. Current
visual inspection uses the retained production `foundation` and
`anatomy-quality` routes; their movement, interaction, presentation, and reset
mappings remain documented in `CONTROLS.md`.

## Prompt 27C production anatomy presentation

The current base anatomy uses the Prompt 27C male, female, and component
pages. Front/side binding identity is unchanged; authored sizes and pivots
were retuned only where the visible body disagreed with the active
presentation contract. Front feet retain their style-specific visible span
and use top/three-quarter source silhouettes plus a bounded bilateral toe-out
rotation while preserving anatomical side,
canonical foot sockets, and foot planting. Side feet retain their canonical
forward axis.

Shoulder continuity is torso-owned, with the upper arm remaining a separately
articulated anatomy component underneath that contour. Elbow, wrist, hip,
knee, and ankle endpoints use bounded overlap and softened source edges
rather than connector patches. The pelvis remains the permanent
`base_presentation` modesty surface, not removable clothing.

The body-only D3D12 inspection route is:

```powershell
$env:SDL_GPU_DRIVER = 'direct3d12'
& '.\zig-out\bin\engine_sandbox.exe' --demo anatomy-quality --scripted-input --frames 600
```

It selects eight poses through production state predicates and submits both
styles through the ordinary global queue. Prompt 27C owner/manual visual
acceptance remains `[PENDING OWNER REVIEW]`.

## VF-02 registered production placement

The migrated core anatomy no longer uses authored size, pivot, and rest
rotation as an independent final authority. The active front/side projection
supplies targets and current atlas alpha geometry supplies source landmarks.
The shared registration solver produces the final request.

Segment bindings cover both upper arms, forearms, thighs, and shins. Front
feet use a `point_axis` binding: the alpha-derived ankle is the sole positional
target, while the authored `sole_back -> sole_front` axis is the orientation
constraint. Explicit 16-degree male and 13-degree female toe-out data describe
the physical ground-plane lateral/depth direction. Front projection maps only
the signed lateral component to the view's horizontal support tangent; it
does not reinterpret ground-plane depth as vertical screen/world Y. The final
front base-foot rotations are therefore `0` radians in the current proof
poses, not approximately `+/-75.8` or `+/-79.3` degrees. Heel, toe, sole-back,
and sole-front remain transformed evidence, not independent targets. The
former base-anatomy and wardrobe-shoe hard-coded front-foot `+/-78` degree
branches are both removed. The nose is the first point-bound face feature.
Torso and pelvis use view-specific bounded frames.

Authored metadata remains available to unmigrated components and explicit
transverse/profile policies. Non-shoe wardrobe presentation remains a
classified compatibility adapter. An equipped shoe is authoritative: it
registers its alpha-derived ankle and authored sole axis to the exact
`PointAxisTarget` stored by the anatomy-foot registration. In front view it
also uses the registered base foot's full authored transverse scale; no
independent rotation or depth multiplier remains. Closed-footwear metadata
suppresses the covered base-foot pixels but keeps their diagnostic record,
with `ankle` declared as the exposed anatomy anchor. Production submission,
diagnostic trace, JSON, and validation observe the same solved shoe request.
Front reflection never swaps left/right anatomical identity. Side-left and
side-right tests require the same stable components and targets.

The existing whole-character ground-alignment pass remains after character
submission. It translates the queue request and both sides of registration
evidence together, so it cannot hide or change a structural residual.

## VF-03 component projection

Front, side-right, and side-left presentation resolve all current appearance
transform-source categories before evaluating typed component parents and
sockets. Component view requirements are validated at graph compilation;
unsupported front or side sources fail instead of disappearing.

Eyes are point-bound to typed head-eye sockets. Each eyebrow is a separate
bounded atlas region and point-bound visual owned by the brow socket of its
eye component. Moving, rotating, or scaling the eye component therefore
moves the eyebrow child without an independent head offset. Hair is
point-bound to the typed scalp component relationship and retains its
attachment-owned secondary deformation after the anchor.

These direct point visuals use the same registration request observed by
production, VF-01, JSON, and validation. Inactive legacy combined-brow
attachments remain transitional compatibility data and are not selected by
current face presets.

VF-03-R1 adds production presentation for optional arm visuals. Front,
side-left, and side-right all resolve the same stable component, module,
shoulder, elbow, wrist, hand-tip, and visual identities. Reflection changes
the projected world chain and signed presentation scale without swapping
graph ownership. Each visual's segment transform is calculated once from the
projected endpoints and is shared by final submission, trace, diagnostics,
and JSON.

Paired continuous and intentional-gap cases use the same character, camera,
viewport, module, arm pose, animation state, and draw order. Continuous puts
the child root on the torso socket. Intentional-gap applies only the declared
`0.08 m` root vector, leaving visible empty pixels before the upper-arm
proximal boundary. Technical tints and deterministic socket locations keep
the optional chain visible without changing canonical pose, animation, or IK
authority.
