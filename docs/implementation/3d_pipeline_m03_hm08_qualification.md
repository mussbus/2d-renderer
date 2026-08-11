# M03 Prompt 2C-T2 — hm08 external base-mesh qualification

**Status:** qualification complete; no adoption or canonical topology change

## Decision summary

The pinned official `hm08` visible body is materially more anatomy-driven and
deformation-ready than the current R1 topology. It is a strong shared-main-body
seed, but it is not a complete M03 human asset: project semantics, bindings,
surface channels, module receivers, and adult anatomy must be authored and
validated after a separately approved topology reset.

No external vertex or face has been assigned a canonical ID. The authoritative
R1 JSON and every M01/M02 identity remain outside this qualification workflow.

## Provenance and license gate

| Field | Pinned value |
| --- | --- |
| upstream project | MakeHuman Community MPFB2 |
| repository | `https://github.com/makehumancommunity/mpfb2.git` |
| repository commit | `437dd513888a92399d1d3200d2e80859fae55abc` |
| asset revision date | `2026-08-10T14:18:58+02:00` |
| asset | `src/mpfb/data/3dobjs/base.obj` |
| basemesh identity | `hm08` |
| asset bytes | 1,808,470 |
| asset SHA-256 | `bea00279464133e86b634220cd2774ebf3b470de280d11222a6b2269e4a8d950` |
| Git blob | `d26635e9326e3cca30778fd7b9c00062b03cce09` |
| asset license | CC0 1.0 Universal |
| license file | `LICENSE.ASSETS.md` |
| license bytes | 7,003 |
| license SHA-256 | `5f3ab0cf6f7ebe92efe4b83213131c617d308d164eeefd5da230373640b0c226` |
| license Git blob | `f3ede1fc3318f8d794e2cb51924186c62f02f71a` |
| result | `LICENSE_PROVENANCE = PASS` |

The exact OBJ header identifies the mesh as `hm08`, states that the asset was
explicitly released as CC0 in September 2020, and identifies the rights holders
at that release. The pinned repository's asset license is the complete CC0 1.0
text. These two independent pieces bind the selected geometry, rather than only
the upstream project in general, to the asset license.

The sparse inspection checkout is ignored at:

`.deps/external/mpfb2-437dd513888a92399d1d3200d2e80859fae55abc/`

The derived comparison file is ignored at:

`.authoring-work/hm08_qualification/hm08_vs_r1_inspection.blend`

Neither is canonical authority. MakeHuman, MPFB, and Blender extensions were
not installed.

## Raw topology

The source OBJ contains 19,158 vertices, 21,334 texture coordinates, 18,486
quad faces, 139 named groups, and no material directives. The official hm08
range metadata identifies visible-body vertices 0 through 13,379; everything
else was evaluated separately.

| Visible-body property | Result |
| --- | ---: |
| vertices | 13,380 |
| used vertices | 13,380 |
| faces | 13,378 |
| quads / triangles / n-gons | 13,378 / 0 / 0 |
| connected components | 1 |
| boundary edges | 0 |
| non-manifold edges | 0 |
| duplicate positions | 0 |
| duplicate faces | 0 |
| degenerate faces | 0 |
| UV corner coverage | 100% |
| detected non-adjacent triangle intersections | 0 |
| exact mirror matches | 13,380 / 13,380 |

The self-intersection check triangulated every quad deterministically with its
0–2 diagonal, used a Blender BVH to obtain non-adjacent candidates, and applied
a three-dimensional separating-axis test. It found zero candidate or confirmed
intersections.

## Alignment used for inspection

Native hm08 is right-handed with X lateral, Y up, Z forward, a 16.6589-unit
visible height, and a minimum body Y of -8.1676. Front renders confirm native
+Z is the face direction. The derived inspection transform was:

```text
scale = 1.8288 / 16.6589 = 0.10977915708720262
Xc = Xhm08 * scale
Yc = (Yhm08 + 8.1676) * scale
Zc = Zhm08 * scale
```

That produces exactly 1.8288 m height and Y=0 ground while retaining the native
sagittal origin. Blender then uses the accepted bridge conversion
`(Xc,Yc,Zc) -> (Xc,-Zc,Yc)`. No transform was baked into either source.

Upstream `joint-l-*` helper names lie on positive X while current M02 `*_left`
anchors lie on negative X. Qualification preserves geometry and records this as
a semantic side-label remap to resolve during adoption; it does not mirror the
mesh.

## Geometry quality

| Metric | Result |
| --- | ---: |
| maximum quad edge ratio | 13.8569823812 |
| P95 | 4.5025720176 |
| P99 | 7.0150187841 |
| quads above 8 | 80 |
| valence 3 | 164 |
| valence 4 | 13,060 |
| valence 5 | 156 |
| extraordinary vertices | 320 |
| maximum valence | 5 |

After height normalization, visible-body edge lengths are 0.000359 m minimum,
0.006174 m median, 0.028510 m P95, 0.040386 m P99, and 0.068296 m maximum.
The corresponding native values are 0.0032665, 0.0562443, 0.259703,
0.367888, and 0.622120 units. These figures are qualification evidence, not
accepted canonical density targets.

The 80 ratios above eight are localized by the deterministic coarse-region
audit: head/face 50, feet/toes 12, ankle/Achilles 10, and torso/breast 8. The
shoulder/arm maximum is 3.26431, pelvis/groin/glute 4.67934, and knee 2.43527.
These outliers require review or local correction after adoption, but they do
not negate the much stronger anatomical flow.

The face has concentric eyelid, orbital, nasal, lip, mouth-corner, jaw, and ear
flow. The torso has continuous shoulder/armpit routing and radial breast/nipple
flow. Hands include separate digits, thumb web, joint rings, and tapered tips.
The pelvis and thigh root are continuous and shaped, knees have circumferential
loops, and feet include arches, heel form, separate toes, and toe rings.

## Helper inventory

Helpers remain reference-only:

| Category | Vertices represented | Faces | Assessment |
| --- | ---: | ---: | --- |
| tongue | 226 | 224 | useful anatomical/topology reference; project tongue still separate |
| eyes | 144 | 140 | useful shape/topology reference; project eyeball/cornea identities remain authoritative |
| eyelashes | 250 | 184 | semantic reference only |
| upper/lower teeth | 136 | 96 | useful placement reference; not individual canonical dentition |
| genital helper | 200 | 182 | coarse open receiver-area cage; incomplete adult anatomy |
| joint cubes | 1,000 | 750 | alignment reference only; incompatible as project skeleton/geometry |
| tights/skirt/hair | 3,822 | 3,532 | irrelevant to shared-body qualification |

No helper, MakeHuman skeleton, rig, or weight data is proposed for adoption.

## Anatomy assessment

- **Whole body:** recognizably human neutral morphology with continuous volume,
  natural taper, and useful A-pose-like limb separation. Shape proportions and
  pose still need canonical adaptation.
- **Head/face:** materially ready as a seed. Orbital, lip, nose, cheek, jaw, and
  ear topology is substantially better than R1. Skull/back-neck shape needs
  position refinement.
- **Shoulder/armpit:** useful deltoid, pectoral, lat, and fold routing. The
  current shoulder silhouette is high and angular enough to need reshaping.
- **Torso/breasts:** continuous shared torso with radial nipple/breast topology.
  It supports low volume and later larger morphs without a sex-specific torso;
  areola membership can be assigned from existing rings.
- **Hands:** real three-dimensional palms, thumb opposition bases, webbing,
  digit joint rings, and tips. Canonical scale and rest-pose alignment are not
  yet matched.
- **Pelvis/glutes:** credible continuous hip, glute, cleft, and thigh-root form.
  The perineal/module receiving area needs project-specific local topology.
- **Knees/ankles/feet:** materially stronger articulation flow and silhouettes
  than R1. The ankle band and a few foot cells contain the main lower-body
  quality outliers.

The topology is suitable for later male/female, lean/heavy,
muscular/non-muscular, narrow/broad, short/tall, and low/high breast morphology.
That assessment concerns topology capacity, not acceptance of the default hm08
shape as the final `human_base`.

## Adult anatomy coverage

The visible body contains a generic closed pubic/perineal surface. It does not
provide accepted external anus geometry, an anal opening/canal, vulvar anatomy,
a vaginal opening/canal, a project-compatible penis, scrotum skin, or separate
testicles. The coarse upstream genital helper does not satisfy any of those
canonical requirements.

Adoption therefore still requires:

- local shared-body retopology for stable perineal and receiver loops;
- a separate default-enabled anus/perianal/canal module;
- separate independently toggleable vulva/vaginal, penis, and
  scrotum/testicles modules;
- all accepted receiver closures and interface-loop identities;
- exact compatibility with all eight optional-module combinations.

## M02 mapping feasibility

All 208 regions and 208 surfaces are classified in
`hm08.m02_semantic_mapping.tsv`:

| Classification | Region + surface records |
| --- | ---: |
| direct mapping | 67 |
| straightforward region split | 167 |
| requires local retopology | 4 |
| requires new module geometry | 178 |
| incompatible | 0 |

The large new-geometry count is expected because it counts both region and
surface records for individual teeth, nails, eyes/corneas, oral parts, and all
adult modules. It is not evidence against the shared-body seed.

### Seam feasibility

The continuous hm08 body provides closed ordered candidates for all 11 accepted
semantic seams. Deterministic boundary classification found:

| Seam | Candidate edges |
| --- | ---: |
| torso ↔ pelvis | 46 |
| torso ↔ neck | 94 |
| neck ↔ head | 56 |
| torso ↔ arm L/R | 36 each |
| wrist ↔ hand L/R | 28 each |
| pelvis ↔ thigh L/R | 32 each |
| ankle ↔ foot L/R | 20 each |

Exact ordered upstream vertex lists and canonical starts are in
`hm08.seam_candidates.json`. They are feasibility evidence, not promoted M03
seam bindings.

### Landmark feasibility

All 35 landmarks have an available hm08 relationship: 20 direct surface
correspondences and 15 internal structural references requiring derived
surface bindings. None is ambiguous or unavailable.

The height-only neutral alignment intentionally did not pose-fit hm08 to M02.
Surface distances are max 0.380083 m, median 0.214236 m, P90 0.369067 m;
internal-to-surface offsets are max 0.275025 m, median 0.084280 m, P90 0.270577
m. The largest differences are all hands/fingertips because hm08's native arm
pose/span differs sharply from the current canonical A-pose. Face center is
0.021093 m, chin 0.036316 m, knees 0.017667 m, and head top 0.015244 m.

These are adaptation measurements, not acceptable final binding errors. The
full position, vector, distance, face, and semantic classification for every
landmark is in `hm08.landmark_mapping.tsv`.

## R1 comparison

| Criterion | Result | Reason |
| --- | --- | --- |
| overall human form | `HM08_CLEARLY_BETTER` | credible continuous anatomy instead of a block scaffold |
| head | `HM08_CLEARLY_BETTER` | rounded cranium and anatomical transitions |
| face | `HM08_CLEARLY_BETTER` | explicit orbital, nose, lip, cheek, jaw, and ear flow |
| shoulder/armpit | `HM08_CLEARLY_BETTER` | socket/fold flow rather than shelf/grid topology |
| torso | `HM08_CLEARLY_BETTER` | anatomical curvature and taper |
| breast topology | `HM08_CLEARLY_BETTER` | integrated radial nipple/breast routing |
| hands | `HM08_CLEARLY_BETTER` | real digits, webbing, palms, and joint rings |
| pelvis/groin | `HM08_CLEARLY_BETTER` | continuous pelvis/thigh root and useful receiver foundation |
| glutes | `HM08_CLEARLY_BETTER` | shaped volumes, cleft, and fold flow |
| thigh root | `HM08_CLEARLY_BETTER` | anatomical emergence from pelvis |
| knees | `HM08_CLEARLY_BETTER` | circumferential articulation topology |
| ankles | `HM08_CLEARLY_BETTER` | malleolar/Achilles form despite local ratio outliers |
| feet/toes | `HM08_CLEARLY_BETTER` | heel, arch, instep, sole, separated toes, joint rings |
| topology regularity | `HM08_CLEARLY_BETTER` | 320 extraordinary vertices and 13.86 max ratio versus R1's 596 and 30.08 |
| deformation readiness | `HM08_CLEARLY_BETTER` | edge organization follows anatomical motion zones |
| semantic mapping effort | `R1_CLEARLY_BETTER` | R1 already carries project IDs, face sets, seams, and bindings |
| adult-module integration effort | `DIFFERENT_TRADEOFF` | R1 carries project receiver records; hm08 supplies the better anatomical foundation but needs new loops |

The side-by-side image inventory is in the evidence README.

## Adoption cost

| Region | Estimated work after approval |
| --- | --- |
| head | `RESHAPE_ONLY` |
| face | `RESHAPE_ONLY` |
| ears | `RESHAPE_ONLY` |
| neck | `RESHAPE_ONLY` |
| shoulders | `RESHAPE_ONLY` |
| torso | `RESHAPE_ONLY` |
| breasts | `RESHAPE_ONLY` |
| hands | `RESHAPE_ONLY` |
| pelvis | `RESHAPE_ONLY` |
| glutes | `RESHAPE_ONLY` |
| perineum | `LOCAL_RETOPOLOGY` |
| legs | `RESHAPE_ONLY` |
| knees | `RESHAPE_ONLY` |
| ankles | `LOCAL_RETOPOLOGY` |
| feet | `RESHAPE_ONLY` |
| toes | `RESHAPE_ONLY` |
| anus | `NEW_GEOMETRY_REQUIRED` |
| vulva/vaginal module | `NEW_GEOMETRY_REQUIRED` |
| penis module | `NEW_GEOMETRY_REQUIRED` |
| scrotum/testicles | `NEW_GEOMETRY_REQUIRED` |

The saved work versus repairing R1 is substantial: the expensive face, hands,
shoulder/armpit, breast, pelvis/thigh, knee, and foot topology is already
anatomically organized.

## Recommended topology reset

If the owner approves adoption:

1. preserve `MeshId = human_base_main_body` because conceptual mesh ownership
   is unchanged;
2. retain `topology_id = human_base_topology`, establish compatibility version
   2.0.0 as a new stable-ID namespace, and advance monotonic topology revision
   from 3 to 4;
3. assign fresh `VertexId` values 0–13,379 and `FaceId` values 0–13,377 through
   an explicit deterministic import of the pinned upstream order;
4. initialize cursors to `next_vertex_id = 13380` and
   `next_face_id = 13378`;
5. never claim correspondence between R1 and hm08 element IDs;
6. preserve all R1 identities and evidence as historical superseded M03
   candidates;
7. regenerate topology, triangulation, source, and neutral identities only
   after remapping and canonical validation.

The compatibility-major reset is what permits fresh numeric IDs without
violating non-reuse inside the old 1.0.0 namespace. If the owner requires the
1.0.0 namespace to remain, the alternative is to allocate all hm08 elements
above R1's existing cursors; that is valid but less clear for a wholesale
pre-acceptance replacement.

Every face set, topology loop, semantic assignment, material assignment, seam
binding, landmark binding, surface-coordinate corner, UV/chart record, anus
receiver, and optional-module interface must be rebuilt and reviewed. M02 does
not change.

## Evidence and reproducibility

Run:

```powershell
tools\hm08_qualification.ps1
```

Use `-SkipRender` for the text/scene qualification gate. The command verifies
all pinned inputs, reconstructs the derived inspection `.blend`, runs topology,
symmetry, intersection, seam, semantic, and landmark analysis, renders evidence
with Blender 4.5.9 LTS, and composes labeled R1 comparisons.

The complete inventory is at
`assets/canonical_model/human_base/geometry/evidence/prompt_2c_t2_hm08/README.md`.

## Final recommendation

`HM08 QUALIFIED — RECOMMEND ADOPTING AS SHARED MAIN-BODY TOPOLOGY SEED`

This is a recommendation for owner review, not adoption. Prompt 2C-R2 remains
blocked, and Prompt 2D/M04 remain unstarted.
