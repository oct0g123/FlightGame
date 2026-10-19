# Roadmap

Phases are ordered so the riskiest questions get answered first. Each phase
has an exit check. We don't move on until the check passes.

## Decisions

| Date       | Decision | Notes |
|------------|----------|-------|
| 2026-10-19 | **RealityKit on every platform.** No SceneKit. | SceneKit is soft-deprecated and can't do visionOS volumes. Metal is used only through RealityKit (`LowLevelMesh`, shader graphs). See [ARCHITECTURE.md §1](ARCHITECTURE.md#1-key-decisions). |
| 2026-10-19 | **Low-poly diorama art direction.** | Matte materials, soft daylight, tilted miniature camera on flat screens. |
| 2026-10-19 | **Altitude is part of the rules, as flight levels.** Aircraft stack at up to three heights and pass over and under each other. | Same rules on every platform. On Vision Pro you set the level with hand height while drawing. On iPhone and iPad you tap for ▲/▼. On Mac you scroll. See [GAME_DESIGN.md](GAME_DESIGN.md#flight-levels). |
| 2026-10-19 | **Coastal Field stays single-level.** Island Strip adds a second level, and Mountain Valley has three. | New players learn the basics first. A single-level map plays exactly like the classic game. |
| 2026-10-19 | **Fully free 3D flight is deferred.** | It's harder to read, depth is hard to control precisely, and it would split the rules across platforms. It could come back later as an experimental Vision Pro-only mode. |
| 2026-10-19 | **The game is called Glidepath.** | Trademark and App Store name checks are still to do (Phase 5). Code modules keep the brand-neutral `Flight` prefix, so a rename would only touch the app target. |

## Phase 0: Foundation

**Status:** built. Waiting on a first launch on each simulator.

- [x] XcodeGen `project.yml` and the multiplatform `Glidepath` app target.
- [x] Packages (`FlightCore`, `FlightScene`, `FlightUI`, `FlightServices`,
  `FlightContent`). They're empty apart from a greybox airfield in a
  `RealityView` and a title badge.
- [x] Swift 6 settings, the `swift-format` config, `.gitignore`, and
  per-developer signing through `Config/Local.xcconfig`.
- [x] CI: on Linux, lint and test the core; on macOS, test the core and build
  for the iOS Simulator, macOS and the visionOS Simulator.
- [ ] Launch on the iPhone simulator, on the Mac and on the Vision Pro
  simulator. This needs Xcode on a Mac.

**Exit check:** the greybox `RealityView` app launches on the iPhone
simulator, on the Mac, and on the Vision Pro simulator, and CI is green.

## Phase 1: Core simulation and a playable 2D debug build

- Build `FlightCore`:
  - `Vec2`, the RNG streams, the world model, and the step pipeline.
  - Paths, landing, collision with hysteresis, the spawner with fairness,
    difficulty profiles, and level JSON.
  - Flight levels: climb and descent, the vertical separation check,
    descent planning with "too high" rejection, level marks, and obstacles.
  - `GameSession`, `PathDrawingController`, replay, and the autopilot.
- Build a `DebugCanvasView`: a SwiftUI `Canvas` that draws circles, lines and
  runways, and is playable with touch or mouse on iPhone and Mac. It shows
  each aircraft's level as a number, with ▲/▼ on tap and the arrow keys on
  Mac.
- Write unit tests, a determinism test, and an autopilot soak test.

**Exit check:** the game is *fun with circles*, both single-level and with
three levels. If the loop isn't fun at this stage, art won't fix it, and this
is the cheapest point to tune the feel.

## Phase 2: RealityKit vertical slice on iPhone and iPad

- Run spikes S1, S3, S4 and S5 (below).
- Build the Coastal Field greybox:
  - placeholder aircraft
  - path ribbons
  - arrival markers and conflict rings
  - camera rig with aspect fitting
  - HUD, pause and game over
- Build a two-level greybox test map for S5, with level badges, drop lines
  and ▲/▼ controls.
- Wire up basic sounds and haptics.

**Exit check:** the full loop is playable on a physical iPhone at a steady
frame rate, an iPad handles several paths drawn at once, and testers can
read and change levels on the test map.

## Phase 3: visionOS volume

- Run spike S2 (drawing input and hand-height levels).
- Put the shared scene in a volumetric window, with resize handling and
  viewpoint changes.
- Add the HUD ornament, attachment panels, hover effects on aircraft, and
  spatial engine audio.
- Add level planes while drawing, stepped path ribbons, and drop lines.

**Exit check:** a 10-minute run is comfortable and precise on Vision Pro
hardware, not only in the simulator, including on the multi-level test map.

## Phase 4: macOS

- Mouse input, window resizing and full screen.
- Menu commands and keyboard shortcuts.
- Scroll-to-change-level.

**Exit check:** feature parity with iPad, minus multi-touch.

## Phase 5: Art, audio and feel

- Final aircraft models, plus final Coastal Field terrain and lighting.
- Shader graphs for paths, rings, water, runway lights and level planes.
- Particle effects, engine and ambient audio, and music.
- Juice: banking, touchdown puffs, slow motion on crashes, and Reduce Motion
  variants.
- Interactive tutorial, plus a short second lesson on flight levels that
  plays the first time a multi-level map is opened.
- Trademark and App Store name check for Glidepath, before the app icon and
  logo are made.

**Exit check:** someone who has never played it gets to a first landing
without help and wants another go.

## Phase 6: Content and meta

- **Island Strip:** two levels and crossing runways.
- **Mountain Valley:** three levels, with peaks that block the lower ones.
- Daily Challenge and Relaxed mode.
- Game Center leaderboards (including the recurring daily one) and
  achievements.
- Profile storage with iCloud key-value sync.
- Settings and an accessibility pass.
- String catalogs, with English first and more languages later.

## Phase 7: Ship

- Performance pass with Instruments on the oldest supported iPhone and on
  Vision Pro.
- Privacy manifest and App Store metadata.
- Screenshots and previews for every platform, including visionOS.
- TestFlight beta, fix pass, then submission.

## Post-launch candidates

- **Tower Mode:** mixed immersive play on visionOS, with the airfield on your
  real table and aircraft descending from around the room to their arrival
  levels.
- **SharePlay co-op:** a host-authoritative shared airspace, with Personas
  around the table on Vision Pro.
- **Free Flight:** an experimental Vision Pro-only mode with continuous
  altitude, played in the immersive space, if flight levels prove popular.
- **New content:** seaplanes, emergency aircraft, wind, storm cells drifting
  through one level, departures that climb out through gates at a set height,
  an aircraft-carrier map and a night map.
- **"Watch the best run"** replays.
- **tvOS,** if a good control scheme turns up.

## Technical spikes

| ID | Question | Approach | Pass criteria |
|----|----------|----------|---------------|
| S1 | Can a `LowLevelMesh` ribbon with a shader-graph dash and fade material be updated per frame cheaply on all three platforms? | Draw 20 ribbons of 2,000 points each, rewritten every frame, with level steps. | < 1 ms of CPU per frame on iPhone, and it looks the same on iOS, macOS and visionOS. |
| S2 | What is the best way to draw paths, and pick levels, on visionOS? | Compare indirect pinch with straight-down projection against head-to-hand raycasting; try two-handed drawing; try `SpatialEventGesture` with `selectionRay` against targeted `DragGesture`. Test hand-height level picking with several band sizes, against pinch-and-flick. | Testers can reliably thread a path between two aircraft that are close together, and pick the intended level at least 95% of the time. If hand height can't reach that, pinch-and-flick becomes the main level control. |
| S3 | Does multi-touch through `SpatialEventGesture` on `RealityView` map accurately to the ground? | Map touches through our own camera ray and plane math, and draw debug crosses where each touch lands. | Error < 2 pt at the screen edges, and three simultaneous fingers are stable. |
| S4 | Perspective or orthographic camera, and how should each aspect ratio be fitted? | Try both cameras on iPhone landscape, iPad 4:3, a wide Mac window and a visionOS volume. | We pick one, and no device shows a cropped playfield. |
| S5 | Can players read and change levels on a phone screen? | Two-level greybox with chevron badges, drop lines and shadow offset; tap for ▲/▼. | Testers name the level of a moving aircraft correctly at least 90% of the time, and changing level doesn't cause accidental path redraws. |

## Risks

| Risk | Mitigation |
|------|------------|
| Drawing on visionOS feels imprecise. | Run spike S2 early. Use enlarged targets and nearest-aircraft snapping, and smooth paths. If needed, use a per-platform game-speed multiplier. |
| Hand height doesn't reliably pick a level. | Snap to levels with hysteresis and tune the band size in S2. Pinch-and-flick is the fallback. |
| Flight levels make the game hard to read on iPhone. | Coastal Field stays single-level and levels are introduced gradually. Chevron badges, drop lines and shadow offset carry the height, and S5 tests it. Any map can drop to fewer levels. |
| A RealityKit API is buggy on one platform (for example, early `MeshInstancesComponent` betas crashed). | Put a plain-entity fallback behind a feature flag for each newer API. |
| Art scope grows. | One-page style guide, the poly and texture budgets, and finishing one map completely before starting the next. |
| The game looks too much like Flight Control. | Original name, art, audio and UI. Only the genre mechanics are shared, and flight levels set it apart further. |
| Floating-point results differ across CPU architectures. | Separate RNG streams, tolerance-based cross-architecture replay tests, and host-authoritative networking. |
| Aircraft are too small to read on iPhone. | A minimum on-screen aircraft size enforced by the camera rig, and a per-device field scale. |

## Open questions

1. **Minimum OS.** I recommend 26 everywhere, and Phase 0 is set up that way.
   Do you want wider reach (18), or to go to 27 now?
2. **Business model.** Paid up front, free with map packs, or pitching to
   Apple Arcade? The answer affects whether StoreKit is in v1.
3. **visionOS scope for v1.** I recommend the volume only, with Tower Mode
   after launch. Or should immersive play be part of launch?
4. **Failure rules.** One crash ends the run in Classic, and Relaxed has three
   strikes. Is that right?
5. **Leaderboards across platforms.** If visionOS gets a speed multiplier, or
   hand-height level control turns out to be an advantage, should it have its
   own leaderboards?
6. **Map unlocks.** Unlock maps through progression, or make everything
   available from the start?
7. **Multiplayer.** How important is SharePlay co-op to you? It's cheap to
   keep possible, but expensive to build.
