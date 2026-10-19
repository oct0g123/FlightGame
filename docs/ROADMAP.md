# Roadmap

Phases are ordered so the riskiest questions get answered first. Each phase
has an exit check. We don't move on until the check passes.

## Phase 0: Foundation

- Set up XcodeGen `project.yml`, the multiplatform app target, and empty
  packages (`FlightCore`, `FlightScene`, `FlightUI`, `FlightServices`,
  `FlightContent`).
- Add the Swift 6 settings, the `swift-format` config, and `.gitignore`.
- Add CI: Linux `swift test` for the core, and macOS `xcodebuild` for the iOS
  Simulator, macOS and the visionOS Simulator.

**Exit check:** an empty `RealityView` app launches on the iPhone simulator,
on the Mac, and on the Vision Pro simulator, and CI is green.

## Phase 1: Core simulation and a playable 2D debug build

- Build `FlightCore`:
  - `Vec2`, the RNG streams, the world model, and the step pipeline.
  - Paths, landing, collision with hysteresis, the spawner with fairness,
    difficulty profiles, and level JSON.
  - `GameSession`, `PathDrawingController`, replay, and the autopilot.
- Build a `DebugCanvasView`: a SwiftUI `Canvas` that draws circles, lines and
  runways, and is playable with touch or mouse on iPhone and Mac.
- Write unit tests, a determinism test, and an autopilot soak test.

**Exit check:** the game is *fun with circles*. If the loop isn't fun at this
stage, art won't fix it, and this is the cheapest point to tune the feel.

## Phase 2: RealityKit vertical slice on iPhone and iPad

- Run spikes S1, S3 and S4 (below).
- Build the Coastal Field greybox:
  - placeholder aircraft
  - path ribbons
  - arrival markers and conflict rings
  - camera rig with aspect fitting
  - HUD, pause and game over
- Wire up basic sounds and haptics.

**Exit check:** the full loop is playable on a physical iPhone at a steady
frame rate, and an iPad handles several paths drawn at once.

## Phase 3: visionOS volume

- Run spike S2 (input).
- Put the shared scene in a volumetric window, with resize handling and
  viewpoint changes.
- Add the HUD ornament, attachment panels, hover effects on aircraft, and
  spatial engine audio.

**Exit check:** a 10-minute run is comfortable and precise on Vision Pro
hardware, not only in the simulator.

## Phase 4: macOS

- Mouse input, window resizing and full screen.
- Menu commands and keyboard shortcuts.

**Exit check:** feature parity with iPad, minus multi-touch.

## Phase 5: Art, audio and feel

- Final aircraft models, plus final Coastal Field terrain and lighting.
- Shader graphs for paths, rings, water and runway lights.
- Particle effects, engine and ambient audio, and music.
- Juice: banking, touchdown puffs, slow motion on crashes, and Reduce Motion
  variants.
- Interactive tutorial.

**Exit check:** someone who has never played it gets to a first landing
without help and wants another go.

## Phase 6: Content and meta

- Island Strip and Mountain Valley maps, including the no-fly-zone rule.
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
  real table and aircraft arriving from around the room.
- **SharePlay co-op:** a host-authoritative shared airspace, with Personas
  around the table on Vision Pro.
- **New content:** seaplanes, emergency aircraft, wind, an aircraft-carrier
  map and a night map.
- **"Watch the best run"** replays.
- **tvOS,** if a good control scheme turns up.

## Technical spikes

| ID | Question | Approach | Pass criteria |
|----|----------|----------|---------------|
| S1 | Can a `LowLevelMesh` ribbon with a shader-graph dash and fade material be updated per frame cheaply on all three platforms? | Draw 20 ribbons of 2,000 points each, rewritten every frame. | < 1 ms of CPU per frame on iPhone, and it looks the same on iOS, macOS and visionOS. |
| S2 | What is the best way to draw paths on visionOS? | Compare indirect pinch with straight-down projection against head-to-hand raycasting; try two-handed drawing; try `SpatialEventGesture` with `selectionRay` against targeted `DragGesture`. | Testers can reliably thread a path between two aircraft that are close together. |
| S3 | Does multi-touch through `SpatialEventGesture` on `RealityView` map accurately to the ground? | Map touches through our own camera ray and plane math, and draw debug crosses where each touch lands. | Error < 2 pt at the screen edges, and three simultaneous fingers are stable. |
| S4 | Perspective or orthographic camera, and how should each aspect ratio be fitted? | Try both cameras on iPhone landscape, iPad 4:3, a wide Mac window and a visionOS volume. | We pick one, and no device shows a cropped playfield. |

## Risks

| Risk | Mitigation |
|------|------------|
| Drawing on visionOS feels imprecise. | Run spike S2 early. Use enlarged targets and nearest-aircraft snapping, and smooth paths. If needed, use a per-platform game-speed multiplier. |
| A RealityKit API is buggy on one platform (for example, early `MeshInstancesComponent` betas crashed). | Put a plain-entity fallback behind a feature flag for each newer API. |
| Art scope grows. | One-page style guide, the poly and texture budgets, and finishing one map completely before starting the next. |
| The game looks too much like Flight Control. | Original name, art, audio and UI. Only the genre mechanics are shared. |
| Floating-point results differ across CPU architectures. | Separate RNG streams, tolerance-based cross-architecture replay tests, and host-authoritative networking. |
| Aircraft are too small to read on iPhone. | A minimum on-screen aircraft size enforced by the camera rig, and a per-device field scale. |

## Open questions

1. **Name and theme.** Ideas so far: *Glidepath*, *Holding Pattern*, *Clear to
   Land*, *Tower*. All need trademark and App Store checks.
2. **Minimum OS.** I recommend 26 everywhere. Do you want wider reach (18), or
   to go to 27 now?
3. **Business model.** Paid up front, free with map packs, or pitching to
   Apple Arcade? The answer affects whether StoreKit is in v1.
4. **Art direction.** I'm proposing a low-poly diorama. Is that the look you
   want, or would you prefer something flatter and more top-down like the
   original?
5. **visionOS scope for v1.** I recommend the volume only, with Tower Mode
   after launch. Or should immersive play be part of launch?
6. **Failure rules.** One crash ends the run in Classic, and Relaxed has three
   strikes. Is that right?
7. **Leaderboards across platforms.** If visionOS gets a speed multiplier,
   should it have its own leaderboards?
8. **Map unlocks.** Unlock maps through progression, or make everything
   available from the start?
9. **Multiplayer.** How important is SharePlay co-op to you? It's cheap to
   keep possible, but expensive to build.
