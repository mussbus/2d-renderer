# Prompts 27A–27H — Reopened Visual Foundation Correction Roadmap

## MULTI-PROMPT EXECUTION CONTRACT

The following message contains Prompts 27A through 27H.

They are provided together only so that Codex has the complete correction roadmap and understands the dependency order.

**DO NOT implement more than one prompt at a time.**

### Execution rules

1. Begin with Prompt 27A only.
2. Treat Prompts 27B–27H as future context, not current implementation requirements.
3. Complete every requirement, test, verification step, documentation update, audit, and `IMPLEMENTATION REPORT` required by the current prompt.
4. Do not begin, partially implement, scaffold, or “get ahead” on a later prompt.
5. After completing the current prompt, stop and wait for explicit authorization to continue.
6. Later prompts may inform extension points and architectural decisions, but they are not permission to implement future work.
7. If an earlier prompt proves that a later assumption is invalid, report the discrepancy rather than silently redesigning the later roadmap.
8. Do not weaken, remove, rename out of discovery, skip, or disable existing tests merely because visual acceptance has been reopened.
9. Preserve the current automated Prompt 27 results as regression-protected:
   - deterministic simulation;
   - fixed-tick input;
   - interaction lifecycle;
   - root invariance;
   - IK ownership and cleanup;
   - outfit/theme/view hot swapping;
   - unified sprite/mesh rendering;
   - D3D12/DXIL execution;
   - allocation/resource bounds;
   - reset behavior.
10. The prior Prompt 27 **manual visual acceptance is reopened**. Preserve its historical report and captures. Do not rewrite history to claim they were never accepted.
11. Do not silently overwrite or bless old captures/goldens. Create clearly named candidate evidence for these correction prompts.
12. Codex may verify automated state, geometry, rendering, and capture generation. Codex must not claim owner/manual visual acceptance unless the user explicitly approves the candidate evidence.
13. A zero exit code, zero socket separation, passing metadata, or a filename describing a state is not sufficient evidence that the visible image is correct.
14. When production artwork changes:
    - preserve the prior asset or commit boundary;
    - generate bounded candidates;
    - inspect them through the real production D3D12 route;
    - reject and restore failed candidates;
    - do not retain visually inferior art merely because tests pass.
15. Do not reset, clean, restore, overwrite, discard, stage, or commit user changes.
16. Do not begin Prompt 28 or a gameplay vertical slice during Prompts 27A–27H.

### Required workflow

```text
Prompt 27A
→ implementation
→ tests / verification
→ IMPLEMENTATION REPORT
→ STOP AND WAIT

Prompt 27B
→ implementation
→ tests / verification
→ IMPLEMENTATION REPORT
→ STOP AND WAIT

Prompt 27C
→ implementation
→ tests / verification
→ IMPLEMENTATION REPORT
→ STOP AND WAIT

Prompt 27D
→ implementation
→ tests / verification
→ IMPLEMENTATION REPORT
→ STOP AND WAIT

Prompt 27E
→ implementation
→ tests / verification
→ IMPLEMENTATION REPORT
→ STOP AND WAIT

Prompt 27F
→ implementation
→ tests / verification
→ IMPLEMENTATION REPORT
→ STOP AND WAIT

Prompt 27G
→ implementation
→ tests / verification
→ IMPLEMENTATION REPORT
→ STOP AND WAIT

Prompt 27H
→ candidate evidence and automated acceptance
→ owner/manual review
→ explicit approval or rejection
→ final report / golden promotion only after approval
→ STOP
```

### Common pre-change requirements for every prompt

Before changing files:

1. Read and obey `AGENTS.md`.
2. Require exactly Zig 0.16.0.
3. Record current HEAD.
4. Record full working-tree status, including untracked files.
5. Inspect the actual repository rather than assuming it exactly matches an earlier report.
6. Read the relevant Prompt 25D, 25E, 26, and 27 decision records, implementation reports, architecture docs, controls, testing docs, and current production routes.
7. Distinguish:
   - authoritative simulation state;
   - visual presentation state;
   - capture/evidence state;
   - owner/manual acceptance.
8. Run the smallest honest baseline necessary before editing.
9. If a host/cache/ACL failure occurs, distinguish environment failure from project failure and retry only with an equivalent command and cleanly documented cache path.
10. Preserve all existing source and resource invariants unless the current prompt explicitly changes them.

### Common empirical-verification contract

Every Prompt 27A–27H result must be supported by empirical evidence appropriate
to the claim. Source inspection, a zero exit code, a passing boolean, a semantic
filename, or internally consistent metadata is not sufficient by itself.

#### 1. Instrument and freeze the baseline before correction

Before changing the production behavior or content under evaluation:

1. Define the measurement method.
2. Define the required case matrix.
3. Define the units.
4. Define acceptance thresholds or target ranges.
5. Add controlled valid and invalid fixtures where applicable.
6. Run the current production baseline.
7. Preserve the raw baseline report and rendered evidence under a unique path.
8. Record hashes for persistent baseline artifacts.

Do not tune a production asset and its acceptance threshold together merely to
make the result pass.

If a threshold must change after the baseline is frozen, the implementation
report must state:

- old threshold;
- new threshold;
- empirical/design rationale;
- affected cases;
- before/after results;
- negative fixtures proving that the new threshold still rejects a minimally
  invalid case.

A threshold change may not be hidden as an ordinary refactor.

#### 2. Use independent evidence sources

Where a claim concerns visible rendering, validate it through the actual
production D3D12 readback pixels.

Where the corresponding semantic/world geometry exists, also calculate the
same relationship from authoritative transforms or landmarks.

Examples:

- semantic sole-to-collider distance versus rendered sole-to-white-line pixels;
- semantic hand-contact orientation versus rendered hand-axis orientation;
- semantic garment coverage versus opaque rendered coverage;
- configured parallax factors versus measured screen-space displacement.

A visual metric must not rely exclusively on the same value or function that
generated the visual being tested.

If independent measurements disagree beyond the declared tolerance, fail the
acceptance gate and report the discrepancy.

#### 3. Preserve raw per-case data

Every quantitative report must preserve machine-readable raw results in JSON,
CSV, or another deterministic repository-approved format.

For every metric report:

- case identity;
- style/body;
- view;
- facing;
- pose or interaction phase;
- outfit/item where applicable;
- morphology values;
- actual value;
- unit;
- allowed minimum;
- allowed maximum;
- pass/fail outcome;
- source of the measurement.

Also report:

- total case count;
- failure count;
- minimum;
- maximum;
- median or mean where useful;
- worst-case case identity.

No average, aggregate count, or selected representative case may conceal a
failing required case.

#### 4. Required matrix coverage

The implementation must enumerate the required matrix before running it.

Missing required cases are failures, not skipped successes.

Do not remove difficult cases, rename tests out of discovery, suppress metrics,
or reduce matrices to make a report pass.

Any exclusion must be explicitly documented and marked [BLOCKED] or
[OUT OF SCOPE] with justification.

#### 5. Controlled positive and negative fixtures

Each newly introduced metric must include, where technically possible:

- a known-valid fixture;
- a minimally invalid fixture just beyond the boundary;
- a clearly invalid fixture.

The metric must accept the valid fixture and reject both invalid fixtures.

Negative fixtures must not depend on special production stable IDs or branches
that recognize the fixture by name.

#### 6. No production-ID or screenshot-coordinate exceptions

Prohibit:

- stable-ID-specific automatic passes;
- outfit-name-specific tolerance branches unless the distinction represents a
  documented design contract;
- hardcoded acceptance-camera coordinates that recognize one screenshot;
- hidden metric suppression;
- pass overrides;
- fallback-to-pass behavior when measurement data is missing.

A missing, nonfinite, incomplete, or unreadable measurement must fail closed.

#### 7. Repeatability

Run every critical deterministic evidence route at least twice from the same
committed inputs and require identical:

- authoritative measurements;
- case counts;
- pass/fail outcomes;
- capture IDs and capture-state metadata;
- persistent artifact hashes where byte identity is expected.

Where fixed-tick behavior is relevant, also run an alternate render-frame
schedule and require identical fixed-tick outcomes.

Document any expected nondeterministic fields and exclude only those fields
from byte comparison.

#### 8. Before/after effect evidence

For every production correction, report:

- baseline actual value;
- corrected actual value;
- absolute change;
- percentage change where meaningful;
- unchanged acceptance threshold;
- affected and unaffected regression cases.

Passing after a correction is not enough; the report must show what changed
empirically.

#### 9. Rendered evidence cannot be cherry-picked

Capture states must be declared in advance and selected by deterministic,
state-conditioned predicates.

Use filmstrips or bounded phase sequences where temporal behavior matters.

Do not select a single favorable frame manually from an unrestricted recording
and present it as complete evidence.

Preserve failed candidate evidence or at minimum its manifest, measurements,
and rejection rationale.

#### 10. Separate automated evidence from aesthetic acceptance

Automated measurements may establish:

- state correctness;
- geometry correctness;
- bounded registration;
- resource correctness;
- deterministic rendering;
- absence of defined defects.

They cannot establish the complete aesthetic judgment that a human pose,
garment, hairstyle, animation, or interaction looks convincing.

Therefore:

- automated acceptance must be reported separately;
- D3D12 evidence generation must be reported separately;
- manual visual acceptance remains [PENDING OWNER REVIEW] until the user
  explicitly approves the candidate package;
- no golden promotion may occur before that approval.

### Common reporting requirements

Every prompt must end with an `IMPLEMENTATION REPORT` containing:

- baseline HEAD;
- initial and final Git status;
- scope completed;
- files created;
- files modified;
- architecture confirmed;
- architecture discrepancies found;
- exact commands, exit codes, and relevant output;
- automated acceptance criteria as `[PASS]`, `[FAIL]`, or `[BLOCKED]`;
- D3D12/GPU acceptance where applicable;
- manual visual acceptance status, which must be `[PENDING OWNER REVIEW]` unless the user explicitly approved it;
- resource/allocation evidence;
- known limitations;
- unresolved failures;
- no-placeholder audit;
- explicit statement that the next prompt and Prompt 28 were not started.

Begin Prompt 27A only.

---

# Prompt 27A — Evidence Integrity, State-Conditioned Captures, and Human Visual-Review Harness

## Engineering brief

### Purpose

Prompt 27’s automated integration work remains valuable, but the visual evidence route is not trustworthy enough to support manual acceptance.

Several named captures were written when the script merely entered a phase rather than when the visible state named by the file was actually present. As a result, a file named for:

- stopped front idle;
- airborne jump;
- detailed debug visualization;

may visibly show:

- residual side locomotion;
- a grounded frame;
- no readable debug overlay.

This milestone repairs the evidence layer before any further art, animation, garment, camera, or interaction correction.

The goal is:

```text
authoritative state
+ resolved presentation state
+ rendered diagnostic evidence
→ state-conditioned capture
→ metadata
→ reviewable contact sheet/video
```

A screenshot filename must never be treated as proof of its own contents.

## Codex implementation prompt

Continue from the completed Prompt 27 repository state.

Reopen Prompt 27 manual visual acceptance and implement a state-conditioned visual evidence harness.

Preserve all Prompt 0–27 automated behavior.

Do not modify production character art.

Do not modify production garment art.

Do not modify locomotion clips.

Do not modify collision or camera behavior.

Do not redesign the handshake.

Do not begin Prompt 27B.

---

## 1. Preserve historical Prompt 27 evidence

Preserve the existing Prompt 27 report and captures as historical evidence.

Do not overwrite:

- the old implementation report;
- the old nine captures;
- old timing/resource records.

Create a decision record explaining:

- automated Prompt 27 acceptance remains regression-protected;
- manual visual acceptance has been reopened;
- the old evidence is retained as the original baseline;
- new evidence uses a separate directory and manifest.

Use a new path equivalent to:

```text
zig-out/p27a_evidence/
```

Do not silently repurpose the old `p27_visual_foundation` directory.

---

## 2. Replace phase-entry capture scheduling

Inspect the current capture scheduler.

Do not capture merely because:

- `script.phase == stop_left`;
- `script.phase == full_jump`;
- `script.phase == debug_release`;
- a counter reached a frame number.

Create the smallest bounded data-driven capture specification that can express:

- stable capture ID;
- filename;
- required script stage, if any;
- authoritative-state predicate;
- presentation-state predicate;
- optional interaction predicate;
- minimum consecutive stable ticks or frames;
- timeout;
- required debug-submission count where applicable.

A capture must fire only when every required condition is true.

---

## 3. Required capture predicates

At minimum implement honest predicates for:

### Initial front idle

Require:

- grounded;
- horizontal and vertical velocity within documented idle thresholds;
- automatic presentation mode;
- resolved front view;
- no active interaction;
- stable for a bounded number of consecutive fixed ticks.

### Stop/front/facing-left

Require:

- grounded;
- no active interaction;
- gameplay facing remains left;
- horizontal velocity below the documented idle threshold;
- animator/presentation no longer in a visible walk stride;
- resolved front view;
- stable for a bounded number of consecutive fixed ticks.

### Side-left and side-right locomotion

Require:

- horizontal speed above a documented threshold;
- matching gameplay facing;
- resolved side view;
- feet/pose sampled from a valid locomotion phase.

### Jump rise

Require:

- airborne;
- positive authoritative vertical velocity;
- visible character bounds clearly above the supporting surface;
- resolved side view.

### Jump apex

Require:

- airborne;
- absolute vertical velocity below a bounded apex threshold;
- resolved side view.

### Jump fall

Require:

- airborne;
- negative authoritative vertical velocity;
- resolved side view.

### Raised-platform landing

Require:

- a real landing event;
- supporting collider is the required raised collider;
- grounded after contact;
- visible feet within the surface-contact contract.

### Theme switch

Require:

- theme changed;
- gameplay fingerprint unchanged;
- character/root/camera state recorded before and after.

### Interaction captures

Provide distinct predicates for:

- eligible approach;
- reach;
- first contact;
- held contact;
- release;
- cleanup/front restoration.

### Detailed debug

Require:

- detailed debug flag enabled;
- nonzero diagnostic primitive submissions;
- expected categories present, such as collider/root/ground/IK/participant-link primitives;
- capture metadata records the submitted counts.

---

## 4. Stable-state hold and inspection pacing

The route must hold important review states long enough to inspect.

At minimum:

- front idle states: at least 60 rendered frames;
- forced front/side outfit inspection states: at least 60 rendered frames;
- interaction reach/contact/release states: enough frames to show the phase clearly;
- debug state: at least 60 rendered frames;
- reset final state: at least 60 rendered frames.

Do not slow the authoritative fixed-tick simulation inconsistently.

Use:

- state-machine holds;
- time-mode controls;
- deterministic waiting;

rather than editing positions or poses directly.

---

## 5. Capture metadata

Write deterministic metadata for every capture.

Use a machine-readable format such as JSON.

At minimum record:

- capture ID;
- filename;
- render frame;
- simulation tick;
- script phase;
- consecutive stable-tick count;
- entity IDs;
- character position and velocity;
- gameplay facing;
- presentation mode and resolved view;
- grounded state;
- supporting collider;
- animation state and normalized time where available;
- body/build/hair selection;
- outfit preset;
- environment theme;
- interaction ID, lifecycle, phase, and elapsed ticks;
- contact/release/complete ticks where applicable;
- active IK and ordering claims;
- debug primitive counts;
- camera center and viewport;
- texture/resource/allocation counters.

The manifest must fail validation if a capture lacks required metadata.

---

## 6. On-screen acceptance HUD

Add a bounded read-only acceptance HUD for the evidence route.

It must display clearly:

- current script phase;
- current capture target;
- gameplay facing;
- resolved view;
- current outfit;
- current theme;
- grounded/support state;
- velocity;
- interaction lifecycle/phase;
- debug primitive count.

Use the existing renderer/debug presentation architecture.

Do not:

- create a second UI renderer;
- poll SDL from the scene;
- allocate each frame;
- expose mutable debug controls through the HUD.

The HUD may be disabled for clean art captures and enabled for evidence/debug captures.

---

## 7. Contact sheets and review package

Create a deterministic tool that:

- converts the PPM captures to PNG where the repository’s established tooling permits;
- creates labeled contact sheets;
- produces an ordered manifest;
- identifies missing captures;
- identifies duplicate image hashes;
- identifies metadata/capture mismatches;
- does not approve visual quality.

Create at minimum:

- one clean-state contact sheet;
- one locomotion/jump filmstrip;
- one interaction phase filmstrip;
- one detailed-debug sheet.

---

## 8. Capture integrity tests

Add focused tests covering:

- stop/front capture cannot fire while side view is active;
- stop/front capture cannot fire while velocity exceeds the idle threshold;
- jump-rise capture cannot fire while grounded;
- jump-fall capture cannot fire with positive vertical velocity;
- detailed-debug capture cannot fire with zero debug submissions;
- interaction-contact capture cannot fire before the contact semantic;
- cleanup capture cannot fire while any interaction/view/IK/override ownership remains;
- stable-tick requirement resets if a predicate becomes false;
- timeout fails honestly;
- metadata records match the state used by the predicate;
- capture order is deterministic across render schedules.

Include controlled bad fixtures for each major predicate.

---

## 9. Manual acceptance boundary

Codex must not declare the visuals acceptable.

The implementation report must split:

- capture-integrity automated acceptance;
- D3D12 evidence-generation acceptance;
- owner/manual visual acceptance.

The final manual field for Prompt 27A must be:

```text
[PENDING OWNER REVIEW]
```

unless the user explicitly reviews and approves the generated package.

---

## Demonstration

Run a bounded D3D12 route that creates honest captures for:

1. initial front idle;
2. side-left walk;
3. stopped front view while facing left;
4. side-right walk;
5. short-jump rise;
6. apex;
7. fall;
8. raised-platform landing;
9. theme switch in place;
10. interaction approach;
11. interaction reach;
12. interaction contact;
13. interaction release;
14. interaction cleanup/front restoration;
15. detailed debug;
16. reset stable front.

The purpose is evidence integrity, not visual correction.

---

## Explicitly out of scope

Do not implement:

- character-art correction;
- garment-art correction;
- animation retuning;
- camera correction;
- character collision;
- handshake redesign;
- new interactions;
- Prompt 27B or later work;
- Prompt 28.

---

## Completion requirements

Prompt 27A is complete only when:

- captures are state-conditioned rather than phase-conditioned;
- every capture has validated metadata;
- filenames and predicates describe the same state;
- capture timing cannot fire early;
- important states are held for inspection;
- detailed-debug evidence proves actual diagnostic submissions;
- contact sheets are generated deterministically;
- old evidence remains preserved;
- manual visual acceptance remains pending;
- Prompt 27B was not started.

End with the required `IMPLEMENTATION REPORT`.

---

# Prompt 27B — Ground Contact, Camera Framing, Parallax Evidence, and Character Presence

## Engineering brief

### Purpose

The current integrated route exposes contradictions among:

- authoritative standable surfaces;
- semantic foot planting;
- visible shoe soles;
- white collision-derived top edges;
- camera framing;
- character presence.

The white line means “this is the true standable surface,” but visible footwear may extend below or be bisected by the line. During vertical traversal, hats or heads may leave the viewport. The scripted path may also drive one character visibly through another.

This milestone fixes world/character presentation coherence before anatomy, animation, wardrobe, or handshake art is retuned.

## Codex implementation prompt

Continue from the completed Prompt 27A state.

Use the Prompt 27A state-conditioned evidence harness.

Correct visual ground contact, camera-safe framing, measurable parallax evidence, and integrated-route character presence.

Preserve the authoritative world, collision, controller, fixed-tick simulation, environment themes, and interaction manager.

Do not reauthor anatomy.

Do not reauthor garments.

Do not retune locomotion clips.

Do not redesign the handshake.

Do not begin Prompt 27C.

---

## 1. Establish one foot-to-surface truth

Document and implement the production relationship:

```text
authoritative supporting collider top
→ canonical planted foot point
→ visual foot/footwear sole landmark
→ rendered surface edge
```

Inspect the actual current path before changing it.

Do not use:

- raw sprite bottom;
- atlas rectangle bottom;
- arbitrary opaque bounds;

as the sole contact truth if semantic sole landmarks already exist or should exist.

---

## 2. Ground-contact validation

For each grounded planted foot, measure in acceptance-camera pixels:

- semantic sole point to authoritative collider top;
- heel and toe height relative to the surface;
- whether the white surface edge intersects opaque footwear pixels;
- whether the foot is visually above, on, or below the surface.

Use documented, evidence-derived tolerances.

Do not globally loosen Prompt 25D registration tolerances.

Airborne, swinging, or intentionally lifted feet must not be judged as planted.

Validate left and right feet independently.

---

## 3. Surface-edge draw ordering

The collision-derived white edge must remain truthful and visible, but it must not cut through footwear.

Use semantic ordering so the edge is:

- above terrain enough to remain readable;
- below character anatomy and footwear;
- below detailed debug primitives;
- independent of environment theme.

Do not paint white edges into atlas art.

Do not offset the collision line away from the actual collider merely to hide an alignment defect.

---

## 4. Correct the lowest responsible layer

If soles are below the surface, determine whether the root cause is:

- footwear pivot;
- foot visual pivot;
- sole landmark;
- planted-foot visual correction;
- character root-to-foot presentation transform;
- surface overlay order.

Fix the lowest correct layer.

Do not move the physics root or collider to match incorrect artwork.

Do not introduce a special-case offset for one outfit.

---

## 5. Camera-safe framing

Add a bounded camera presentation contract based on visible production bounds, including:

- head;
- hair;
- headwear;
- feet;
- long garments where relevant.

At 640×480 and resized viewports, require:

- documented minimum top headroom during full jump;
- documented minimum bottom clearance;
- no head or hat clipping during raised-platform traversal;
- no abrupt camera teleport;
- no gameplay-state change caused by framing;
- deterministic behavior across render schedules.

The camera may use:

- bounded vertical look-ahead;
- a vertical dead zone;
- safe-region correction;
- another existing-compatible policy.

Do not add a second gameplay camera.

---

## 6. Character presence and pass-through

The integrated evidence route must no longer drive one character visibly through another.

First inspect whether the project intentionally allows character pass-through.

Implement the smallest generalized correction consistent with the architecture.

Acceptable outcomes are:

### Preferred

A bounded, deterministic character-presence blocker or soft-stop policy that:

- is data/role based, not entity-name based;
- prevents ordinary locomotion from occupying the passive participant’s visible body space;
- does not teleport either root;
- does not manufacture handshake eligibility;
- is deterministic;
- composes with static collision;
- releases or behaves predictably during interaction.

### Minimum acceptable if broad character collision is intentionally deferred

- rewrite the production foundation route so it never passes one participant through the other;
- add an explicit documented known gap for interactive character collision;
- add an automated overlap detector that fails the scripted route if the visible participant bounds exceed the allowed overlap.

Do not pretend route avoidance is a general collision system.

---

## 7. Measured parallax proof

Replace purely configuration-derived evidence with real transformed presentation evidence.

Track one or more stable world anchors in:

- far layer;
- midground layer;
- gameplay/terrain layer.

As the camera moves, measure their relative screen displacement.

Require:

- far displacement magnitude < midground displacement magnitude < gameplay displacement magnitude;
- deterministic results;
- nonzero visible separation;
- no theme change to authoritative camera/world state.

---

## 8. Tests

Add focused tests for:

- planted sole alignment;
- left/right foot independence;
- white edge below footwear;
- wrong sole landmark fixture fails;
- wrong footwear pivot fixture fails;
- camera safe bounds during full jump;
- camera safe bounds on raised platform;
- resize invariance;
- real parallax displacement ordering;
- participant overlap detection;
- presence policy determinism if implemented;
- no root teleport;
- no collision fingerprint change from theme switching;
- no steady-state allocation or GPU-resource growth.

Preserve existing foot-planting, environment, and interaction tests.

---

## Demonstration

Use Prompt 27A’s evidence harness to capture:

1. front idle feet and surface;
2. side-left planted foot;
3. side-right planted foot;
4. jump with safe headroom;
5. raised-platform landing;
6. theme switch with unchanged contact;
7. camera resize;
8. player approaching but not passing through the passive participant;
9. debug overlay showing collider top, sole landmarks, and camera-safe bounds.

---

## Explicitly out of scope

Do not implement:

- anatomy reauthoring;
- clothing reauthoring;
- locomotion clip redesign;
- handshake pose redesign;
- general NPC pathfinding;
- combat collision;
- Prompt 27C or later work;
- Prompt 28.

---

## Completion requirements

Prompt 27B is complete only when:

- planted soles visually agree with authoritative standable tops;
- white edges do not bisect footwear;
- camera preserves full character/headwear visibility through required traversal;
- parallax is proven by measured screen displacement;
- the scripted route has no uncontrolled full-body participant pass-through;
- all gameplay/resource invariants remain green;
- candidate visual evidence is generated;
- owner/manual visual acceptance remains pending;
- Prompt 27C was not started.

End with the required `IMPLEMENTATION REPORT`.

---

# Prompt 27C — Production Anatomy Silhouette, Proportion, and Joint-Continuity Reauthoring

## Engineering brief

### Purpose

The current segmented characters remain visibly mechanical in several areas:

- shoulders attach like narrow sockets;
- elbows and knees read as hinges;
- wrists and ankles change width abruptly;
- pelvis and thighs read as separate blocks;
- hands and arms are disproportionate;
- front and side stances disagree;
- foot orientation is awkward.

Clothing and animation cannot be judged reliably while the underlying body silhouette remains unstable.

This milestone corrects production anatomy and hardens the validator so these defects cannot pass again.

## Codex implementation prompt

Continue from the completed Prompt 27B state.

Reauthor and retune the production male and female anatomy presentation.

Preserve:

- one authoritative skeleton;
- anatomy identity;
- morphology architecture;
- front/side presentation;
- fixed-tick simulation;
- animation ownership;
- IK;
- foot planting;
- equipment bindings;
- Prompt 23 art resources;
- unified sprite/mesh rendering.

Do not retune locomotion clips beyond the minimum needed to inspect static/key poses.

Do not convert production garments.

Do not redesign the handshake.

Do not begin Prompt 27D.

---

## 1. Freeze and document the current anatomy baseline

Preserve:

- current production atlases;
- Prompt 25D reports;
- Prompt 27A/B captures;
- current semantic landmarks and pivots.

Create before/after comparison evidence.

Do not overwrite approved historical goldens.

---

## 2. Correct production proportions

Inspect and correct, where evidence requires:

- upper-arm length;
- forearm length;
- hand length and width;
- thigh length;
- shin length;
- foot length;
- neck/head relationship;
- torso/pelvis height;
- male/female stance width.

Do not impose one universal body proportion.

Use body/style-specific authored contracts.

The target is coherent adult anatomy, not identical male/female proportions.

---

## 3. Shoulder silhouette

Correct:

- neck-to-shoulder slope;
- deltoid/upper-arm transition;
- shoulder root placement;
- front and side shoulder contours;
- morphology response.

Shoulders must not attach at the square corners of a torso rectangle.

The torso and upper arm should form a continuous silhouette through ordinary motion.

Do not solve this with an oversized opaque blob.

---

## 4. Elbow and wrist continuity

Correct:

- upper-arm distal contour;
- forearm proximal contour;
- elbow overlap;
- forearm distal contour;
- hand proximal contour;
- wrist overlap;
- edge shading.

Avoid:

- dark transverse crop lines;
- bead-like joints;
- severe width discontinuities;
- pointed gaps;
- excessive overlap blobs.

---

## 5. Pelvis, hip, and thigh continuity

Correct:

- waist-to-pelvis silhouette;
- pelvis-to-thigh bridge;
- front hip spacing;
- side hip/buttock/upper-thigh contour;
- thigh proximal width;
- body-relative ordering.

The pelvis must not read as:

- a separate codpiece;
- a floating connector;
- a rectangular plate;
- a broad rear shelf.

Preserve the `base_presentation` ownership/modesty boundary.

---

## 6. Knee and ankle continuity

Correct:

- thigh distal contour;
- shin proximal contour;
- knee overlap;
- shin distal contour;
- ankle/foot transition;
- edge shading;
- width continuity.

Keep the semantic joint at the authoritative skeletal joint.

Do not move grounded feet merely to hide an ankle defect.

---

## 7. Foot orientation and stance

Correct:

- female inward-turning boots/feet where visually unintended;
- male outward-turning stance where visually excessive;
- front-view bilateral foot orientation;
- side-view forward axis;
- sole axis;
- ankle-to-foot attachment.

Preserve foot planting and canonical foot sockets.

---

## 8. Visual-geometry validator hardening

Extend Prompt 25D’s validator with bounded production checks for:

- shoulder slope;
- shoulder contour continuity;
- parent/child width ratio near joints;
- hand-to-forearm length and width ratios;
- arm-to-torso proportion;
- pelvis-to-thigh silhouette continuity;
- knee and ankle width continuity;
- foot forward axis;
- front bilateral stance symmetry;
- excessive dark/transverse joint edge where a deterministic metric is practical.

Use style/view/semantic-region-specific contracts where necessary.

Do not introduce a broad generic threshold that accidentally approves every body.

---

## 9. Controlled bad fixtures

Add negative fixtures for:

- square/flat shoulder;
- shoulder gap;
- shoulder blob;
- oversized hand;
- overlong arm;
- wrist pinch;
- floating pelvis;
- excessive hip overlap;
- knee bead;
- ankle gap;
- reversed foot direction;
- excessive toe-in/toe-out.

Each fixture must fail the intended metric without depending on a production stable ID.

---

## 10. Morphology matrix

Validate at minimum:

- nominal;
- low/high global build;
- low/high shoulder width;
- low/high torso width;
- low/high upper-arm thickness;
- low/high thigh/shin thickness.

Relevant landmarks and joint continuity must remain valid.

Do not create one sprite per morphology value.

Use the existing deformation/morphology response architecture.

---

## 11. Production evidence

Create body-only or minimal-neutral-clothing captures for:

- male front;
- male side-left;
- male side-right;
- female front;
- female side-left;
- female side-right;
- arm relaxed;
- arm extended;
- elbow bent;
- deep knee bend;
- neutral standing;
- selected morphology extremes.

Use close-up contact sheets for:

- shoulders;
- elbows/wrists;
- pelvis/hips;
- knees/ankles;
- feet.

---

## 12. Art-generation policy

Original project art may be reauthored with approved tools, including image generation, but:

- preserve source/previous atlas versions;
- use generated output only as a bounded candidate;
- restore true alpha and atlas dimensions deterministically;
- inspect through real D3D12 rendering;
- reject candidates with flat crop faces, boxy silhouettes, accidental clothing, checkerboard backgrounds, or collateral redraw;
- do not retain a candidate merely because the source-art audit passes.

---

## Tests and verification

At minimum run:

- source-art audit;
- focused visual-geometry tests;
- production visual-geometry report;
- character presentation tests;
- foot-planting regression;
- wardrobe-binding regression;
- Prompt 27A evidence integrity;
- real D3D12 anatomy capture route;
- aggregate tests if production art/runtime changed broadly;
- Debug, ReleaseSafe, and ReleaseFast builds where required;
- formatting and repository audit.

Manual visual acceptance remains pending owner review.

---

## Explicitly out of scope

Do not implement:

- locomotion animation redesign;
- garment schema;
- garment conversion;
- handshake redesign;
- environment redesign;
- character editor;
- Prompt 27D or later work;
- Prompt 28.

---

## Completion requirements

Prompt 27C is complete only when:

- base anatomy is visually and quantitatively coherent without garments hiding defects;
- shoulders, elbows, wrists, hips, knees, ankles, hands, and feet pass the new contracts;
- controlled bad fixtures fail;
- existing simulation/resource invariants remain green;
- before/after D3D12 evidence exists;
- owner/manual visual acceptance remains pending;
- Prompt 27D was not started.

End with the required `IMPLEMENTATION REPORT`.

---

# Prompt 27D — Locomotion, Jump, Landing, and View-Transition Presentation

## Engineering brief

### Purpose

The current movement is mechanically correct but visually stiff:

- walking can read as marching or sliding;
- weight transfer is weak;
- arms and legs extend like rigid bars;
- jump states do not form distinct silhouettes;
- front/side restoration may capture a residual stride;
- camera/evidence can show a phase before the visual pose settles.

This milestone retunes presentation animation while preserving authoritative physics and the shared animation architecture.

## Codex implementation prompt

Continue from the completed Prompt 27C state.

Reauthor and retune side locomotion, jump, fall, landing, and front/side presentation transitions.

Preserve:

- controller and collision behavior;
- 240 Hz authoritative clock;
- gameplay facing;
- one shared animation state machine;
- anatomy and morphology;
- IK/foot planting ownership;
- equipment identity;
- unified rendering.

Do not create a second front-view gameplay animator.

Do not convert garments.

Do not redesign the handshake.

Do not begin Prompt 27E.

---

## 1. Walk-cycle quality

Reauthor or retune the production side walk to provide clear:

- contact pose;
- down/weight-acceptance pose;
- passing pose;
- up/recovery pose.

Address:

- locked straight knees;
- exaggerated scissoring;
- weak weight transfer;
- insufficient arm swing;
- rigid torso;
- foot sliding;
- leg/arm phase mismatch.

Preserve deterministic sampling and existing gameplay speed.

---

## 2. Foot planting integration

Foot planting remains visual correction over authoritative motion.

Require:

- planted-foot world drift within documented tolerance;
- no visible skating during contact;
- clean release before swing;
- no airborne locks;
- fresh acquisition after landing;
- no physics/controller changes caused by animation tuning.

Do not let IK destroy the authored walk silhouette.

---

## 3. Jump presentation phases

Create clearly distinguishable visual phases:

1. anticipation/takeoff;
2. rise;
3. apex;
4. fall;
5. landing compression;
6. recovery.

Use authoritative controller state and existing animation state.

Do not:

- change gravity;
- change jump impulse;
- change collision;
- move the root for presentation;
- create a second physics jump.

Short and held jumps must use the same gameplay mechanics while producing readable presentation.

---

## 4. Landing presentation

Landing should visibly communicate impact without:

- sinking through the floor;
- breaking foot locks;
- causing excessive limb compression;
- changing physics support.

Integrate existing landing compression and secondary motion.

---

## 5. Front/side transition policy

The automatic presentation policy must remain:

- grounded stable idle → front;
- locomotion/airborne/interaction → side.

Add the smallest deterministic settling policy needed so:

- stopping does not visibly remain in a stride when front presentation is captured;
- front restoration waits for a stable idle condition;
- starting movement does not flash stale front art;
- left/right gameplay facing remains unchanged;
- interaction view ownership still overrides automatic policy.

A bounded hysteresis/settle-tick rule is acceptable.

Do not add an arbitrary render-delta crossfade that alters simulation.

---

## 6. Transition evidence

Use Prompt 27A’s harness to capture:

- front idle;
- first side movement frame after starting;
- side-left steady walk;
- stop while gameplay facing left;
- stable front restoration with facing left;
- side-right steady walk;
- stable front restoration with facing right;
- jump rise;
- apex;
- fall;
- landing;
- recovery to front idle.

Capture filmstrips, not only single favorable frames.

---

## 7. Quantitative validation

Add or extend metrics for:

- planted-foot drift;
- stride symmetry;
- left/right mirrored equivalence;
- knee angle bounds;
- elbow angle bounds;
- arm/leg phase relationship;
- torso vertical/rotational motion bounds;
- jump pose distinction;
- landing timing;
- front-restoration stable ticks;
- no one-frame missing/stale art;
- finite secondary state.

Use controlled bad fixtures where practical.

---

## 8. Tests

At minimum cover:

- deterministic walk sampling;
- identical results across render schedules;
- foot-lock regression;
- short/held jump state invariance;
- jump rise/apex/fall capture predicates;
- landing and recovery;
- front restoration preserving gameplay facing;
- interaction-owned side view remains authoritative;
- reset;
- no steady-state allocation;
- no resource creation from view transitions.

---

## Explicitly out of scope

Do not implement:

- new movement mechanics;
- sprinting;
- combat locomotion;
- garment schema;
- production garment conversion;
- handshake redesign;
- camera redesign beyond regression fixes;
- Prompt 27E or later work;
- Prompt 28.

---

## Completion requirements

Prompt 27D is complete only when:

- walking reads as weighted locomotion rather than rigid translation;
- jump phases are visibly distinct;
- foot planting remains stable;
- stop/front restoration visibly occurs only after a stable idle;
- gameplay facing and physics remain unchanged by presentation;
- state-conditioned D3D12 filmstrips exist;
- owner/manual visual acceptance remains pending;
- Prompt 27E was not started.

End with the required `IMPLEMENTATION REPORT`.

---

# Prompt 27E — Generalized Garment Fragment, Directional Reflection, Collar, Shoulder, and Hair Schema

## Engineering brief

### Purpose

Prompt 25E documented important authoring gaps but intentionally did not change runtime schema.

The current wardrobe is an accepted mirror-safe/single-layer subset, yet the real production review demonstrates requirements that the schema does not cleanly express:

- a blouse that needs directional side treatment;
- collars and straps wrapping behind/in front of the neck;
- clothing fit following sloped shoulders and armholes;
- skirts/dresses split into front/back or near/far fragments;
- hairstyles composed around headwear without losing the crown.

This milestone implements the generalized schema and runtime support.

It is not the full production wardrobe conversion.

## Codex implementation prompt

Continue from the completed Prompt 27D state.

Implement the smallest bounded generalized presentation schema required for:

- stable garment fragment identity;
- explicit side reflection policy;
- directional side variants;
- semantic body-relative depth;
- neck/collar coverage;
- shoulder/armhole geometry;
- hair/headwear fragment composition.

Preserve:

- logical equipment identity;
- topology-aware bindings;
- loadout transactions;
- art-pack resources;
- deformation;
- meshes;
- secondary motion;
- unified render queue;
- allocation/resource invariants.

Do not convert all production garments in this prompt.

Do not redesign the handshake.

Do not begin Prompt 27F.

---

## 1. Stable fragment identity

Introduce a compact typed identity for authored visual fragments.

One logical garment may own a bounded set of fragments.

Each fragment must support concepts equivalent to:

- stable fragment ID;
- owning item ID;
- presentation view;
- direction/reflection policy;
- anatomy or attachment binding;
- pivot/landmarks;
- semantic depth relation;
- coverage contribution;
- deformation response;
- optional mesh;
- optional secondary motion.

No per-frame string lookup.

No unbounded dynamic fragment collection.

---

## 2. Explicit side reflection policy

Support policies equivalent to:

### Mirror safe

One canonical side visual may reflect with gameplay facing.

### Authored directional variants

Separate side-left and side-right visual definitions.

### Mixed-fragment composition

Some fragments reflect while others select directional artwork.

Changing facing must not:

- change equipment identity;
- recreate loadout state;
- decode images;
- create GPU resources;
- reset animation or secondary motion;
- swap anatomical left/right identity incorrectly.

Validate missing or contradictory variants.

---

## 3. Semantic body-relative depth

Define bounded semantic depth relationships equivalent to:

- behind body;
- behind torso;
- behind neck/head;
- behind far arm;
- behind far leg;
- between far and near limbs;
- in front of torso;
- in front of lower neck/upper chest;
- in front of near arm;
- in front of near leg;
- foreground accessory.

Resolve these through the existing global numeric ordering system.

Do not create a second renderer.

Do not store arbitrary renderer callbacks in item definitions.

Do not require content authors to guess anonymous magic layer numbers where a semantic relation is needed.

---

## 4. Neck and collar semantics

Add first-class visual-authoring geometry equivalent to:

- neck-base center;
- left/right neck base;
- collar band;
- clavicle/upper-chest line;
- rear-neck region;
- front lower-neck region.

Allow a garment to declare:

- neck intentionally exposed;
- front collar coverage;
- rear collar coverage;
- full/high-neck coverage.

Do not require low-neck garments to cover the neck.

Do not infer intent solely from accidental pixel overlap.

---

## 5. Shoulder slope and armhole semantics

Expose bounded authoring geometry equivalent to:

- neck base;
- left/right shoulder slope;
- shoulder seam;
- shoulder root;
- armhole reference;
- upper-chest span.

A fitted garment must be able to validate against the actual shoulder contour rather than an axis-aligned torso rectangle or physics collider.

Sleeve proximal openings must be able to register to the shoulder/armhole contract.

---

## 6. Skirt and long-garment composition

Support generalized fragment recipes for:

### Front view

- rear/back panel behind pelvis/legs;
- waist/body section;
- front panel ahead of appropriate leg portions;
- optional deformable hem.

### Side view

- far fabric behind the far leg;
- central waist/body section;
- near fabric in front of the near leg;
- directional behavior under facing changes.

Do not implement general cloth simulation.

Use existing sprite/mesh/secondary-motion primitives.

---

## 7. Hair and headwear composition

Support a hairstyle recipe with bounded fragments such as:

- back hair;
- crown/top hair;
- side/front framing;
- optional ponytail/secondary fragment.

Headwear must compose between appropriate hair fragments.

Removing a hat must not expose a missing crown if the hairstyle is intended to include one.

Do not implement hat-name-specific hair branches.

---

## 8. Compatibility migration

Existing production items must remain valid.

Provide explicit migration/default behavior for legacy recipes.

A legacy item may default to:

- one fragment;
- existing view behavior;
- mirror-safe side policy;
- resolved current numeric ordering.

Document that this is a compatibility subset, not the full authoring model.

Do not silently reinterpret a directional production item as mirror-safe in Prompt 27F.

---

## 9. Synthetic and isolated production proofs

Provide bounded proof definitions for:

- mirror-safe simple garment;
- directional blouse;
- mixed mirrored/directional garment;
- rear/front collar;
- front/back skirt;
- near/far side skirt;
- hair crown + back hair + headwear + front hair.

These proofs may use technical original art.

Do not convert the complete catalog.

---

## 10. Validation

Validate:

- duplicate fragment IDs;
- missing fragment owner;
- missing directional variant;
- invalid mixed-reflection declaration;
- invalid anatomy binding;
- invalid semantic depth relation;
- contradictory coverage;
- collar intent without required landmarks;
- shoulder-fit declaration without shoulder geometry;
- fragment cycles or ambiguous ordering;
- capacity overflow;
- cleanup/reset;
- view/facing hot swap;
- no steady-state allocation or GPU creation.

---

## 11. Documentation and future editor boundary

Update the authoring contract with exact steps for:

- adding a fragment;
- choosing reflection policy;
- authoring side-left/right variants;
- binding collars;
- binding sleeves to armholes;
- composing skirts;
- composing hair/headwear;
- previewing all required views/facings;
- exporting the same runtime definitions a future editor will produce.

Do not implement editor UI.

---

## Explicitly out of scope

Do not implement:

- complete production wardrobe conversion;
- general cloth physics;
- garment collision;
- inventory/economy;
- handshake changes;
- environment redesign;
- Prompt 27F or later work;
- Prompt 28.

---

## Completion requirements

Prompt 27E is complete only when:

- the runtime can represent all documented garment/hair cases without item-specific renderer code;
- existing wardrobe behavior remains compatible;
- synthetic/isolated proofs pass;
- new schemas are bounded, typed, deterministic, and allocation-free in steady state;
- D3D12 proof captures exist;
- owner/manual visual acceptance remains pending;
- Prompt 27F was not started.

End with the required `IMPLEMENTATION REPORT`.

---

# Prompt 27F — Production Wardrobe and Hairstyle Conversion and Reauthoring

## Engineering brief

### Purpose

Prompt 27E provides the schema. This milestone converts and corrects the actual production content.

The priority defects include:

- ivory blouse reading backwards under side reflection;
- detached/tubular sleeves;
- flat neck holes and collars;
- shoulder fit based on rectangular torso assumptions;
- long garment reading as a rear cape/tail;
- female long hair missing a complete crown when headwear is removed.

The entire 15-preset production wardrobe must be inspected in front, side-left, and side-right presentation.

## Codex implementation prompt

Continue from the completed Prompt 27E state.

Convert production wardrobe and hairstyle definitions to the new generalized fragment/reflection/depth schema where required.

Reauthor original project art where source pixels are the root cause.

Preserve:

- 30 logical wardrobe item identities;
- 15 outfit preset identities;
- transactional loadouts;
- cosmetic gameplay invariance;
- topology-aware bindings;
- deformation/mesh/secondary systems;
- art-pack resource ownership;
- unified rendering;
- Prompt 27A evidence integrity.

Do not redesign the handshake.

Do not begin Prompt 27G.

---

## 1. Production wardrobe inventory

Audit all production items and presets.

For every visible item record:

- logical ID;
- presets using it;
- front visual;
- side-left behavior;
- side-right behavior;
- reflection policy;
- fragment list;
- semantic depth relations;
- neck/collar intent;
- shoulder/armhole fit;
- mesh/secondary use;
- known visual defects;
- conversion status.

Do not omit items because they are visually simple.

---

## 2. Ivory blouse correction

The ivory blouse must become a production proof of directional correctness.

Correct:

- side-left and side-right front/back construction;
- placket/fold/silhouette direction;
- sleeve/torso shoulder continuity;
- sleeve proximal armhole fit;
- neckline/collar behavior;
- movement under both facings;
- front return after movement.

Use:

- authored directional variants;
- mixed fragments;
- another generalized 27E mechanism.

Do not use an item-name branch in renderer code.

---

## 3. Collar and neckline correction

Inspect halter, blouse, jacket, and other relevant upper garments.

Where the design wraps or covers the neck:

- rear straps/collar render behind the neck;
- front trim renders ahead of upper chest/lower neck;
- coverage intent matches visible pixels;
- no fake painted hole overlays the body;
- no garment stops abruptly at a square torso top.

Low-neck garments may intentionally expose the neck.

---

## 4. Shoulder and sleeve correction

For every sleeved/fitted upper garment:

- fit the actual shoulder slope;
- align shoulder seam;
- align sleeve proximal opening;
- avoid detached tubes;
- avoid oversized overlap blobs;
- preserve deformation across morphology;
- preserve topology-aware repeated sleeve binding.

Validate front, side-left, and side-right.

---

## 5. Long garment and skirt layering

Convert long garments that require wraparound presentation.

At minimum the formal long garment must provide:

- coherent waist/body section;
- rear/far panel;
- front/near panel;
- correct leg occlusion;
- appropriate mesh/secondary motion;
- no pelvis-attached cape/tail appearance;
- no detachment during ordinary movement.

Apply the schema to other skirts/dresses where required.

---

## 6. Hair/headwear correction

Correct production female long hair so it remains a complete hairstyle:

- with no hat;
- with wide-brim hat;
- with other compatible headwear;
- in front;
- side-left;
- side-right;
- movement;
- reset/outfit changes.

Require:

- crown/top hair;
- back hair;
- appropriate front/side framing;
- deterministic headwear ordering;
- finite secondary state;
- no bald-looking scalp unless the selected hairstyle is intentionally bald.

Inspect male buzz/bald behavior as a regression.

---

## 7. Footwear and legwear regression

Because fragment/order changes may affect lower-body visuals, verify:

- stockings;
- boots;
- heels;
- shoes;
- front and side variants;
- left/right reflection;
- foot planting;
- white surface relation from Prompt 27B.

Do not regress Prompt 25D’s footwear geometry.

---

## 8. All-preset visual matrix

Create a deterministic wardrobe review route generating at minimum:

For each of 15 presets:

- front idle;
- side-left idle or slow locomotion;
- side-right idle or slow locomotion;
- representative movement pose.

Also create focused matrices for:

- collar/neck;
- shoulders/sleeves;
- hair/headwear;
- skirts/long garments;
- footwear.

Clearly label preset and view/facing.

Do not force all 15 presets through the handshake; that belongs to Prompt 27G’s representative compatibility checks.

---

## 9. Validation and negative fixtures

Add/extend tests for:

- directional variant resolution;
- mirror-safe control item;
- mixed-fragment reflection;
- collar front/back ordering;
- shoulder/armhole registration;
- skirt near/far ordering;
- crown hair presence with/without headwear;
- no stale fragment after outfit/view/facing changes;
- no resource creation on outfit changes;
- no steady-state allocation;
- reset cleanup.

Controlled bad fixtures must catch:

- backwards directional blouse;
- collar entirely in front of neck;
- missing crown hair;
- skirt entirely behind both legs;
- detached sleeve.

---

## 10. Art quality and candidate policy

Where artwork changes:

- preserve prior assets;
- keep stable IDs;
- use original project-local art only;
- inspect actual D3D12 output;
- reject candidates that merely satisfy geometry but look worse;
- do not silently approve new goldens.

The implementation report must list every reauthored production region.

---

## Explicitly out of scope

Do not implement:

- new outfit economy;
- new wardrobe categories unrelated to fixes;
- general cloth simulation;
- handshake redesign;
- environment redesign;
- Prompt 27G or later work;
- Prompt 28.

---

## Completion requirements

Prompt 27F is complete only when:

- every preset has front/side-left/side-right evidence;
- the ivory blouse no longer reads backwards;
- collar/neck content uses correct front/behind composition where intended;
- sleeves connect through shoulder/armhole geometry;
- long garments wrap around the body/legs rather than reading as rear tails;
- hair remains complete with and without headwear;
- all automated/resource regressions pass;
- candidate review package exists;
- owner/manual visual acceptance remains pending;
- Prompt 27G was not started.

End with the required `IMPLEMENTATION REPORT`.

---

# Prompt 27G — Handshake Approach, Authored Pose, Grip Geometry, and Interaction Readability

## Engineering brief

### Purpose

The current handshake proves:

- deterministic eligibility;
- fixed roots;
- role timing;
- side-view ownership;
- ordering;
- IK cleanup;
- near-zero hand-socket separation.

It does not yet look like a convincing handshake.

The visible result can show:

- participants too far apart;
- nearly locked elbows;
- overextended arms;
- kinked wrists;
- fingertip or glove-edge contact;
- no readable clasp;
- no distinct reach/hold/release phases.

This milestone reauthors the existing handshake only.

Authored animation must define the pose. IK must provide bounded corrective alignment rather than inventing the whole interaction.

## Codex implementation prompt

Continue from the completed Prompt 27F state.

Rework the existing fixed-position handshake presentation and approach behavior.

Preserve:

- existing interaction manager;
- typed interaction definition;
- shared fixed-tick timing;
- participant roles;
- locks;
- root invariance during active interaction;
- physics isolation;
- declarative side-view ownership;
- bounded occlusion profiles;
- cleanup/reset;
- unified rendering.

Do not implement a new interaction type.

Do not implement carrying, hugs, root parenting, furniture anchors, or a general full-body solver.

Do not begin Prompt 27H.

---

## 1. Reevaluate authored spacing

The current approximately 3.72 m spacing was derived from long maximum reach and produces overextended arms.

Derive a new authored spacing from:

- corrected anatomy proportions;
- bent-elbow handshake pose;
- hand/grip geometry;
- participant body clearance.

Maintain a bounded eligibility envelope around the authored separation.

Do not:

- teleport roots;
- snap participants;
- change facing automatically;
- warp motion after interaction start.

Interactive approach may stop at the eligible distance through the generalized presence/approach policy established earlier.

---

## 2. Role-specific authored clips

Create or retune role clips with visually distinct phases:

1. ready/anticipation;
2. reach;
3. clasp;
4. hold;
5. release;
6. recovery.

Requirements:

- elbows remain plausibly bent;
- shoulders do not stretch away from torsos;
- wrists use compatible orientation;
- hands approach along compatible paths;
- nonparticipating arms remain natural;
- feet remain planted;
- roots remain fixed during the active interaction.

Use one shared authoritative timeline.

---

## 3. Semantic hand-contact frame

Point coincidence is insufficient.

Define the smallest bounded contact geometry equivalent to:

- palm/contact center;
- hand forward axis;
- hand up or grip axis;
- optional contact span/zone.

At contact validate:

- center separation;
- orientation error;
- wrist angle;
- elbow angle;
- arm extension ratio;
- limited intentional overlap;
- shoulder continuity.

Do not implement finger simulation.

---

## 4. IK as correction

IK should correct small residual differences from the authored pose.

Define and validate:

- maximum allowed pre-IK positional error;
- maximum IK angular correction;
- maximum arm stretch;
- no elbow flip;
- no wrist inversion;
- finite results;
- symmetry under mirrored participant arrangement.

A pose requiring extreme IK to reach contact must fail rather than pass because endpoints eventually coincide.

---

## 5. Approach readability

The evidence route must show:

- participants approaching;
- stopping at eligible distance;
- facing one another;
- no body pass-through;
- interaction request;
- reach;
- clasp;
- hold;
- release;
- cleanup/front restoration.

Do not stage only the already-extended contact pose.

---

## 6. Occlusion and clothing

Verify body and equipment ordering through every phase.

At minimum test with:

- `wide_brim_crimson`;
- `garnet_formal`;
- `ivory_blouse_red_shorts`.

Require:

- hands/palms ordered intentionally;
- forearms ordered intentionally;
- sleeves/gloves inherit bound anatomy interaction ordering;
- long-garment fragments remain correct;
- no item-specific handshake branches.

Test in:

- violet cavern;
- neutral debug theme.

Theme must not alter eligibility, timing, pose, or contact.

---

## 7. Interaction metrics

Record per session:

- interaction ID/type;
- participant IDs/roles;
- outfit;
- theme;
- authored separation;
- actual root separation;
- contact/release/complete ticks;
- requested views;
- pre/post-IK center separation;
- orientation error;
- wrist angles;
- elbow angles;
- arm extension ratios;
- shoulder continuity;
- body/equipment ordering;
- root invariance;
- secondary-state finiteness;
- cleanup state.

Add controlled bad fixtures for:

- fingertip-only contact;
- parallel hands instead of compatible clasp;
- locked elbows;
- hyperextended arm;
- excessive wrist kink;
- excessive IK correction;
- participant spacing outside envelope;
- incorrect sleeve/glove ordering.

---

## 8. Evidence package

Use Prompt 27A’s harness to create:

- approach frame;
- reach frame;
- first-contact frame;
- held-clasp frame;
- release frame;
- cleanup/front frame;

for all three representative outfits.

Include close-up crops of:

- shoulders;
- elbows;
- wrists;
- hands/contact.

Create a slow-motion or quarter-speed deterministic video/filmstrip.

---

## 9. Interactive usability

Keep `E` as the interaction request.

The eligibility envelope may remain strict enough for deterministic interaction, but the interactive route should provide useful diagnostics when ineligible:

- too far;
- too close;
- wrong facing;
- not grounded;
- wrong state;
- occupied.

Do not silently snap the character.

---

## Tests and regression

At minimum run:

- handshake;
- handshake IK;
- visual-foundation interaction tests;
- foot planting;
- wardrobe ordering;
- environment invariance;
- reset/cancellation;
- render/allocation/resource bounds;
- D3D12 interaction route;
- aggregate tests/builds required by changed interaction/animation code.

---

## Explicitly out of scope

Do not implement:

- new interactions;
- hugs;
- carrying;
- root parenting;
- furniture/world anchors;
- arbitrary multi-contact solving;
- cinematic camera systems;
- Prompt 27H or later work;
- Prompt 28.

---

## Completion requirements

Prompt 27G is complete only when:

- the pose visibly reads as a handshake without relying on filenames or metrics;
- participants stand at a natural authored distance;
- elbows and wrists remain plausible;
- hands share compatible contact position and orientation;
- reach/clasp/hold/release are visibly distinct;
- IK remains bounded correction;
- all three representative outfits and both themes remain correct;
- cleanup/reset/resource invariants pass;
- owner/manual visual acceptance remains pending;
- Prompt 27H was not started.

End with the required `IMPLEMENTATION REPORT`.

---

# Prompt 27H — Final Integrated Visual Foundation Reacceptance and Owner-Approved Goldens

## Engineering brief

### Purpose

Prompts 27A–27G repair:

- evidence integrity;
- ground/camera/presence;
- anatomy;
- movement;
- garment schema;
- production wardrobe/hair;
- handshake presentation.

Prompt 27H adds no broad new system.

It performs final integrated reacceptance through a slower, state-conditioned, labeled route and a separate all-preset wardrobe matrix.

This milestone must not repeat the original mistake of converting command success into manual visual approval.

## Codex implementation prompt

Continue from the completed Prompt 27G state.

Build the final Prompt 27 reacceptance package.

Do not add major features.

Do not begin Prompt 28.

The first execution of Prompt 27H must produce candidate evidence and stop with:

```text
MANUAL VISUAL ACCEPTANCE: PENDING OWNER REVIEW
```

Only after the user explicitly approves the candidates may Codex:

- promote candidate goldens;
- update the final acceptance manifest;
- issue the final completion report.

---

## 1. Preserve failed/reopened history

Preserve:

- original Prompt 27 report;
- original nine captures;
- Prompt 27A reopened-audit record;
- intermediate candidate evidence from 27B–27G.

Document that the new package supersedes the old manual visual acceptance while preserving its historical automated results.

Do not delete or rewrite old evidence.

---

## 2. Final integrated route

Create a deterministic, human-reviewable route demonstrating:

1. initial front idle;
2. male hair change;
3. female body/build/hair inspection;
4. outfit change while idle;
5. violet environment;
6. side-left locomotion;
7. stopped front restoration while gameplay facing remains left;
8. side-right locomotion;
9. short jump rise/apex/fall/landing;
10. full jump with camera headroom;
11. raised-platform landing;
12. measured parallax;
13. neutral-debug theme switch in place;
14. detailed collision/foot/camera debug;
15. return to violet theme;
16. directional blouse side-left;
17. directional blouse side-right;
18. collar/neck composition;
19. hair with and without headwear;
20. layered long garment;
21. approach to interaction partner;
22. handshake reach;
23. clasp;
24. hold;
25. release;
26. cleanup/front restoration;
27. viewport resize;
28. reset;
29. stable final state.

Every capture must use Prompt 27A’s state-conditioned predicate and metadata.

---

## 3. Separate wardrobe matrix

Do not make the integrated video excessively long.

Create a separate deterministic matrix for all 15 presets showing:

- front;
- side-left;
- side-right;
- representative movement pose.

Create focused close-ups for:

- collars/necklines;
- shoulders/sleeves;
- skirts/long garments;
- hair/headwear;
- footwear/ground contact.

The matrix must name each preset and view/facing.

---

## 4. Final debug evidence

Provide a genuinely readable detailed-debug package showing:

- static colliders;
- white standable tops;
- character roots;
- ground probes/hits;
- sole landmarks;
- foot IK targets;
- arm IK chain and contact frame;
- participant link;
- camera-safe bounds;
- semantic fragment/depth visualization where useful.

Record nonzero primitive counts and visible pixel changes.

---

## 5. Final automated acceptance

Run all required gates, including:

- focused Prompt 27A–27G tests;
- presentation;
- wardrobe;
- environment;
- handshake;
- handshake IK;
- foot planting;
- visual geometry;
- production geometry report;
- source-art audits;
- documentation/repository audits;
- aggregate Debug tests;
- aggregate ReleaseFast tests;
- `zig build check`;
- Debug application build;
- ReleaseSafe application build;
- ReleaseFast application build;
- actual D3D12/DXIL GPU smoke;
- final integrated route;
- final wardrobe matrix;
- allocation/resource stability;
- formatting;
- `git diff --check`.

Do not reduce existing test counts by deleting or hiding tests.

---

## 6. Performance/resource evidence

Report:

- decoded/configured texture-page count;
- wardrobe item/preset count;
- environment theme count;
- production view count;
- collision-derived surface count;
- peak sprites;
- peak meshes;
- sprite/mesh ranges;
- draw calls;
- upload bytes;
- initialized/final allocator bytes;
- steady-state allocations;
- GPU resource creation/destruction delta;
- fragment counts;
- interaction record bounds.

Changes from the original Prompt 27 metrics must be explained honestly.

Do not manipulate scene content merely to preserve an obsolete draw count.

---

## 7. Owner review package

Generate:

- ordered capture manifest;
- metadata files;
- clean contact sheet;
- locomotion/jump filmstrip;
- all-preset wardrobe contact sheets;
- handshake phase sheets for all three outfits;
- debug sheet;
- before/after comparison against original Prompt 27;
- a concise manual-review checklist.

The checklist must ask explicitly:

### Evidence integrity

- Does each image visibly match its filename/state?

### Ground/camera

- Do soles meet standable surfaces?
- Do white edges stay beneath footwear?
- Is the full character/headwear framed through jumps?

### Anatomy

- Do shoulders, elbows, wrists, hips, knees, and ankles read continuously?
- Are hands/arms/feet proportionate?

### Movement

- Does walking show believable weight transfer?
- Are jump phases distinct?
- Does front restoration occur only after a real stop?

### Clothing/hair

- Does the ivory blouse face correctly left and right?
- Do collars wrap correctly?
- Do sleeves join the shoulder?
- Do long garments wrap around legs?
- Is hair complete with and without hats?

### Interaction

- Does approach read clearly?
- Does the handshake look like a handshake?
- Are reach/clasp/hold/release distinct?
- Are hands, wrists, elbows, shoulders, sleeves, and gloves plausible?

### World/debug

- Is parallax visible?
- Are characters readable against the cavern?
- Is the detailed debug overlay useful?

---

## 8. Approval boundary

On the first Prompt 27H execution:

- do not modify approved golden manifests;
- do not report manual visual acceptance as pass;
- do not declare Prompt 27H complete;
- stop after producing candidate evidence and the automated report.

Required status:

```text
Automated acceptance: [PASS/FAIL/BLOCKED]
D3D12 evidence generation: [PASS/FAIL/BLOCKED]
Manual visual acceptance: [PENDING OWNER REVIEW]
Golden promotion: [NOT PERFORMED]
```

After explicit user approval:

1. promote only the approved candidate images;
2. write the approved manifest with hashes and provenance;
3. rerun comparison;
4. issue the final Prompt 27H implementation report.

If the user rejects any image, preserve the candidate and report the precise blocker. Do not self-correct into an unbounded loop without a new explicit instruction.

---

## Explicitly out of scope

Do not implement:

- Prompt 28;
- gameplay vertical slice;
- new interactions;
- combat;
- dialogue;
- save systems;
- editors;
- runtime 3D;
- general cloth simulation;
- unrelated foundation expansion.

---

## Completion requirements

Prompt 27H is complete only after:

- all automated gates pass;
- candidate evidence is complete and truthful;
- the user explicitly approves manual visual acceptance;
- approved goldens are promoted;
- final comparison passes;
- the report separates automated, D3D12, resource, and manual evidence;
- Prompt 28 was not started.

End with the required final `IMPLEMENTATION REPORT`.

Do not begin Prompt 28.
