# Architecture

> Status: draft for discussion. Code blocks are design sketches, not compiled
> code. API details flagged as *spike* get verified on device before we
> commit to them (see [ROADMAP.md](ROADMAP.md#technical-spikes)).

## 1. Key decisions

### 1.1 RealityKit, not SceneKit

SceneKit was proposed. I recommend **RealityKit on every platform** instead.

- **SceneKit is in maintenance mode.** At WWDC25 Apple soft-deprecated it. It
  now gets critical fixes only, and Apple points new projects to RealityKit.
  SwiftUI's `SceneView` is deprecated in iOS 26.
- **visionOS needs RealityKit.** Volumes and immersive spaces are
  RealityKit-only. On Vision Pro, SceneKit could only draw inside a flat
  window, which would waste the platform we want to focus on.
- **One engine for every platform.** RealityKit and `RealityView` now run on
  iOS, iPadOS, macOS, visionOS and tvOS 26. That gives us one scene graph, one
  asset pipeline (Reality Composer Pro / USD) and one material system.
- **It already does what we need.** Its entity–component–system model suits a
  game. It also provides spatial audio, particles, grounding shadows, gaze
  hover effects, image-based lighting and GPU instancing
  (`MeshInstancesComponent`).

### 1.2 Metal for specific jobs, not a custom renderer

- **Path lines:** `LowLevelMesh`, which holds our own vertex buffers and can
  be written from the CPU or from a Metal compute kernel. Each path is a
  ribbon mesh that is rewritten only when that path changes.
- **Materials:** `ShaderGraphMaterial` (MaterialX) authored in Reality
  Composer Pro. These work on every RealityKit platform, including visionOS.
  Uses: dashed and fading path lines, pulsing warning rings, water, runway
  lights.
- **Avoid `CustomMaterial`.** Metal surface shaders aren't available on
  visionOS, so using them would give us two different looks to maintain.
- **Rejected: a full custom Metal renderer** (CompositorServices on visionOS,
  `MTKView` elsewhere). We would lose volumes, SwiftUI attachments and system
  hover effects, and spend months on rendering instead of the game. At about
  40 aircraft we won't need it. We would revisit only if profiling showed a
  real bottleneck.

### 1.3 GameplayKit isn't a core dependency

| GameplayKit offers          | We use instead                               | Why                                      |
|-----------------------------|----------------------------------------------|------------------------------------------|
| `GKStateMachine`            | A Swift `enum` with associated values         | Type-safe, and a state can't be out of sync with its data |
| `GKRandomSource`            | A small seeded PRNG (xoshiro256**) in `FlightCore` | Same sequence on every OS version and on Linux CI, so daily seeds and replays reproduce |
| `GKEntity` / `GKComponent`  | RealityKit ECS for presentation, plain structs for the simulation | Avoids running two ECS frameworks side by side |
| `GKAgent2D` steering        | Our own path following                       | Aircraft follow drawn paths, not flocking or seeking |
| `GKNoise`                   | Possibly, in tooling only                    | Terrain and texture generation           |

GameplayKit hasn't had a meaningful update in years. It isn't worth tying the
core to it, and adopting it later for one specific job is easy.

### 1.4 The simulation is 2D; the presentation is 3D

Everything that decides the game happens on a flat plane. The simulation is
**2D, deterministic, fixed-timestep, pure Swift, and imports no Apple
frameworks.** The presentation layer maps it into 3D: field `(x, y)` becomes
the ground plane, and altitude is cosmetic (a glide descent onto runways,
helicopters hovering low). On visionOS that altitude gives real depth.

This buys us:

- Unit tests that run anywhere, including Linux CI.
- Headless bot runs for balancing.
- Replays for bug reports.
- Identical rules on every platform.
- The freedom to change the renderer without touching gameplay.

### 1.5 SwiftUI for all UI

Menus, HUD, settings and the game-over screen are SwiftUI. The game itself is
a `RealityView`. On visionOS we use ornaments and `ViewAttachmentComponent`.
UIKit and AppKit only where there's no alternative.

### 1.6 Minimum OS 26 everywhere

iOS/iPadOS 26, macOS 26 and visionOS 26.

- That release gives us `RealityView` on every platform,
  `MeshInstancesComponent`, `ViewAttachmentComponent`, `GestureComponent`,
  `PresentationComponent` and Liquid Glass.
- For a game shipping in 2027 it costs little reach.
- 27 is current, but nothing in it is essential to this design. Revisit if
  Reality Composer Pro 3 features become compelling.

## 2. System overview

```
 ┌──────────────── App target ────────────────┐
 │ iOS · iPadOS · macOS · visionOS            │
 │ FlightGameApp: scenes per platform         │
 └──────┬──────────────┬───────────────┬──────┘
        │              │               │
 ┌──────▼─────┐ ┌──────▼───────┐ ┌─────▼──────────┐
 │ FlightUI   │ │ FlightScene  │ │ FlightServices │
 │ SwiftUI    │►│ RealityKit   │ │ GameKit, save, │
 │ menus, HUD │ │ view, input, │ │ audio, haptics │
 └──────┬─────┘ │ presenters   │ └─────┬──────────┘
        │       └──┬───────┬───┘       │
        │          │ ┌─────▼────────┐  │
        │          │ │FlightContent │  │
        │          │ │RCP: USDZ,    │  │
        │          │ │shader graphs │  │
        │          │ └──────────────┘  │
 ┌──────▼──────────▼───────────────────▼──────┐
 │ FlightCore (pure Swift, no Apple imports)  │
 │ model · simulation · levels · difficulty   │
 │ RNG · replay · autopilot · GameSession     │
 └────────────────────────────────────────────┘
```

Arrows point toward dependencies. `FlightCore` depends on nothing but the
Swift standard library and Foundation.

### Data flow for one frame

```
 touch / mouse / pinch
        │  platform gesture
        ▼
 InputRouter (FlightScene)    screen or 3D → field space
        │  PointerEvent(id, phase, point)
        ▼
 PathDrawingController (Core) picks aircraft → Commands
        │
        ▼
 GameSession.advance(dt)      fixed 60 Hz ticks
        │  Simulation.step(&world, commands) → [GameEvent]
        ├──────────────► HUDState (only when values change) → SwiftUI
        ├──────────────► Presenters → RealityKit entities
        └──────────────► AudioDirector, haptics
```

## 3. Modules

All modules are local Swift packages under `Packages/`, consumed by a single
multiplatform app target.

| Module           | Depends on                     | Responsibility                                       |
|------------------|--------------------------------|------------------------------------------------------|
| `FlightCore`     | Foundation                     | Rules: world model, step pipeline, paths, landing, collision, spawning, difficulty, RNG, level schema, replay, autopilot, `GameSession`, `PathDrawingController` |
| `FlightScene`    | Core, Content, RealityKit      | `GameView` (wraps `RealityView`), scene building from level data, presenters, path ribbons, camera rig, input routing per platform |
| `FlightUI`       | Core, Scene, Services, SwiftUI | App navigation, title / attract mode, HUD, pause, game over, settings, tutorial overlays |
| `FlightServices` | Core, GameKit, AVFAudio        | Profile and stats storage, iCloud key-value sync, Game Center, audio director, haptics |
| `FlightContent`  | (Reality Composer Pro package) | USDZ models, terrain, shader graphs, particle presets, audio files, level JSON |

## 4. Simulation (`FlightCore`)

### 4.1 Space and time

- **Field units:** each map is a rectangle, 160 × 100 u by default. The
  origin is bottom-left, `+y` points away from the player, and headings are
  radians counter-clockwise from `+x`.
- **Fixed timestep:** 60 Hz (`dt = 1/60`). Presentation interpolates between
  the previous and current tick, so 90 Hz (Vision Pro) and 120 Hz (ProMotion)
  displays look smooth without a faster simulation.
- **No tunnelling:** the fastest aircraft moves about 0.17 u per tick, far
  less than any collision radius, so it can't skip past another aircraft
  between checks.
- **`Float` throughout.** No `Double` mixed into positions.

### 4.2 World state

```swift
public struct World: Sendable {
    public var tick: UInt64 = 0
    public var aircraft: [Aircraft] = []   // dense; removal = swap-remove
    public let level: Level                // runways, bounds, no-fly zones
    public var spawner: SpawnerState
    public var score = Score()
    public var phase: Phase = .playing     // .playing, .crashed(a, b, at)
    var rng: RandomStreams                 // separate streams, see 4.9
}

public struct Aircraft: Sendable, Identifiable {
    public let id: AircraftID
    public let kind: AircraftKind          // .prop, .jet, .heli …
    public var position: Vec2
    public var previousPosition: Vec2      // for render interpolation
    public var heading: Float
    public var previousHeading: Float
    public var turnRate: Float             // drives the visual bank
    public var altitude: Float             // cosmetic, 0…1
    public var state: FlightState          // .entering, .flying,
                                           // .landing(runway, s), .landed
    public var path: FlightPath?
    public var hasEnteredField: Bool
}
```

`Vec2` is a thin wrapper over `SIMD2<Float>`, which is in the standard
library, plus our own `length`, `normalize` and `dot`. The `simd` module isn't
available on Linux.

### 4.3 Step pipeline

`Simulation.step(_ world: inout World, commands: [Command]) -> [GameEvent]`
is a pure function of its inputs. Each tick runs in this order:

1. **Apply commands:** start, extend or finish paths, with validation.
2. **Spawner:** advance the difficulty clock, emit entry warnings, spawn
   aircraft (with fairness checks).
3. **Movement:** follow the path or fly straight, turn back at the edge, keep
   within turn-rate limits, update altitude.
4. **Landing:** commit-zone checks and landing roll-out. Remove aircraft that
   have landed.
5. **Separation:** proximity warnings (with begin/end hysteresis) and
   collisions. A crash sets `phase = .crashed`.
6. **Scoring and events.**

With at most about 40 aircraft, the all-pairs check is about 800 distance
tests per tick, so we don't need a spatial hash.

### 4.4 Commands and events

```swift
public enum Command: Sendable, Codable {
    case startPath(AircraftID, at: Vec2)
    case extendPath(AircraftID, points: [Vec2])
    case finishPath(AircraftID)
}

public enum GameEvent: Sendable {
    case arrivalWarning(edgePoint: Vec2, kind: AircraftKind, in: Float)
    case spawned(AircraftID)
    case pathCommitted(AircraftID, RunwayID)
    case pathRejected(AircraftID, at: Vec2)          // wrong runway
    case touchedDown(AircraftID, RunwayID)
    case landed(AircraftID)
    case conflictBegan(AircraftID, AircraftID)
    case conflictEnded(AircraftID, AircraftID)
    case crashed(AircraftID, AircraftID, at: Vec2)
}
```

Commands are `Codable` from day one, so replays and future SharePlay come
almost for free.

### 4.5 Paths

```swift
public struct FlightPath: Sendable {
    var points: [Vec2]          // resampled every 1.0 u
    var head: Int               // first point not yet consumed
    var committedRunway: RunwayID?
    var isDrawing: Bool
}
```

- **Input processing:**
  1. Drop raw points closer than 0.5 u to the previous one.
  2. Smooth with Chaikin over a short trailing window.
  3. Resample to uniform 1.0 u spacing, so arc length is just index × spacing.
  4. Clamp to the field inset.
  5. Cap a path at 2,000 points.
- **Following:** pure pursuit toward a lookahead point (about 0.3 s ahead),
  limited by each kind's maximum turn rate: props 120°/s, jets 90°/s, helis
  180°/s. If the player draws a corner sharper than the aircraft can fly, it
  cuts the corner slightly, which reads as natural. `head` advances to the
  nearest point ahead within a small window. If this feels too loose, we can
  add an exact-follow mode.
- **Commit:** on every extend, check whether the last point is inside the
  capture radius of a runway that accepts this kind, and whether the tail's
  direction (the last 4 u) is within that runway's heading tolerance. If so,
  replace the tail with a generated glide segment blended onto the centreline,
  set `committedRunway`, and ignore further extends.
- **End of path:** an uncommitted path that runs out leaves the aircraft
  flying straight on its last heading.

### 4.6 Landing

- **Runway data:** `threshold`, `heading`, `length`, `captureRadius`,
  `headingTolerance`, and accepted kinds. A helipad is a runway with
  `anyHeading = true` and zero length.
- **Touchdown:** reaching the threshold on a committed path switches the
  aircraft to `.landing(runway, s: 0)`. It then follows the centreline,
  decelerating over the runway length, with altitude going to 0. It can't
  collide while landing, and it leaves the max-airborne count.
- **Glide:** altitude lerps down over the last few units of a committed path.
  It is cosmetic, but it's computed here, so it's deterministic and identical
  on every platform.

### 4.7 Separation and crashes

- **Collision:** when the distance between two aircraft is less than the sum
  of their radii, and both are airborne and not landing, they crash.
- **Warning:** a conflict begins below the warning distance and ends above
  1.1 × that distance. The gap stops the warning flickering on and off.
- **After a crash:** the simulation freezes. Presentation plays the slow
  motion and visual effects, and the UI shows the game-over panel.
- **Relaxed mode:** instead of ending the game, a crash removes both aircraft
  and costs a strike.

### 4.8 Spawning and difficulty

Difficulty curves come from data (`DifficultyProfile`, decoded from JSON):

```json
{
  "id": "classic",
  "spawnInterval": { "start": 6.0, "end": 1.6, "halfLife": 90 },
  "maxAirborne":   [[0, 3], [60, 6], [180, 10], [360, 16]],
  "mix": [
    [0,  { "prop": 1.0 }],
    [30, { "prop": 0.6, "jet": 0.4 }],
    [90, { "prop": 0.45, "jet": 0.35, "heli": 0.2 }]
  ],
  "speedScale": [[0, 1.0], [300, 1.1]],
  "warningLead": 2.0
}
```

The spawn interval decays exponentially:
`interval(t) = end + (start − end) · 0.5^(t / halfLife)`.

Each spawn works like this:

1. Draw the kind from `mix(t)`.
2. Pick an entry point on an allowed edge, 5 u outside the bounds, with a
   heading toward a point in the interior (biased toward the centre, ±30°).
3. Emit `arrivalWarning` `warningLead` seconds early.
4. **Fairness check:** project the newcomer's straight-line course 4 s ahead
   against every aircraft's projected course. If the closest approach is
   under twice the warning distance, re-pick the edge (up to 6 tries), or else
   delay the spawn by 0.5 s.

### 4.9 Determinism, replays and the daily challenge

- **Separate RNG streams:**
  - The *schedule* stream decides kind, edge and timing.
  - The *fairness* stream handles re-picks.
  - The *cosmetic* stream drives variation that doesn't affect play.

  Because fairness re-picks have their own stream, a daily seed produces the
  same arrival script for every player, even though their play differs.
- **Replay:** `{ version, levelID, profileID, seed, [(tick, Command)] }`.
  Used for bug reports, golden tests and, later, "watch the best run".
- **Float caveat:** `sqrt` is exact under IEEE rules, but trig functions can
  differ by an ulp between Apple silicon and x86 Linux. Golden replays compare
  results within a tolerance across architectures, and exactly on the same
  architecture. Future multiplayer would therefore be host-authoritative, not
  lockstep (see section 8.6).

### 4.10 `GameSession` and `PathDrawingController`

`GameSession` is the bridge between the pure `step` function and the app.
It is platform-agnostic (Observation is part of the Swift toolchain, so this
still builds and tests on Linux).

```swift
@MainActor @Observable
public final class GameSession {
    public private(set) var hud = HUDState()            // SwiftUI observes
    @ObservationIgnored public private(set) var world: World
    @ObservationIgnored public private(set) var alpha: Float = 0
    @ObservationIgnored public private(set) var frameEvents: [GameEvent] = []
    @ObservationIgnored private var pending: [Command] = []
    @ObservationIgnored private var accumulator = 0.0
    @ObservationIgnored private var recorder: ReplayRecorder?

    public var isPaused = false

    public func advance(by dt: Double) {
        frameEvents.removeAll(keepingCapacity: true)
        guard !isPaused, world.phase == .playing else { return }
        accumulator += min(dt, 0.25)                    // clamp hitches
        while accumulator >= Simulation.dt {
            recorder?.record(pending, at: world.tick)
            frameEvents += Simulation.step(&world, commands: pending)
            pending.removeAll(keepingCapacity: true)
            accumulator -= Simulation.dt
        }
        alpha = Float(accumulator / Simulation.dt)
        hud.update(from: world)                        // writes only on change
    }
}
```

`PathDrawingController` turns pointer events into commands:

- It keeps a map from pointer IDs to aircraft IDs, so multi-touch works.
- On `.began`, it picks the nearest aircraft within the grab radius. The grab
  radius is in field units and supplied by the platform layer.
- It forwards moves as `extendPath` and releases as `finishPath`.
- It has no platform types, so it is unit-tested with synthetic pointer
  streams.

### 4.11 Autopilot

The autopilot is a simple bot that issues the same commands a player would.
It flies a path to an approach point 12 u before the threshold, then onto the
runway, and has a skill parameter for reaction delay. It is used for:

- **Attract mode** behind the menus.
- **Soak tests:** 30 minutes of simulated time, checking invariants.
- **Balance runs:** survival-time distributions per difficulty profile.

## 5. Presentation (`FlightScene`)

### 5.1 Scene graph

```
FieldRoot          scaled to fit the view or volume
├─ Terrain         USDZ; trees/houses via MeshInstancesComponent
├─ Runways         built from level data; class colour + glyph
├─ AircraftLayer   one pooled entity per aircraft
├─ PathLayer       one LowLevelMesh ribbon per path
├─ MarkerLayer     arrival arrows, conflict rings, runway glow
└─ Lighting        directional light + IBL
```

**Coordinate mapping:** field `(x, y)` maps to RealityKit
`(x, altitude, −y)`, and a heading `θ` maps to a rotation of `θ` about `+Y`.
RealityKit is Y-up, so field `(cos θ, sin θ)` lands on
`(cos θ, 0, −sin θ)`, which is consistent.

### 5.2 Frame loop

```swift
RealityView { content in
    let controller = SceneController(session: session, level: level)
    content.add(controller.fieldRoot)
    controller.updateSubscription = content.subscribe(to: SceneEvents.Update.self) {
        controller.frame(dt: $0.deltaTime)  // session.advance + presenters
    }
}
```

The frame loop is a single `SceneEvents.Update` subscription, which works the
same way on every platform. `SceneController.frame`:

1. Calls `session.advance(by:)`.
2. Feeds `session.frameEvents` to presenters, the audio director and haptic
   triggers.
3. Syncs transforms using `session.alpha` for interpolation.

RealityKit `System`s are used only for self-contained visual behaviour such as
propeller spin, rotor blur and ring pulses.

### 5.3 Presenters

- **`AircraftPresenter`:**
  - Keeps a map from `AircraftID` to `Entity`.
  - Pools entities per kind. They're cloned from prototypes loaded once at
    start, so mesh resources are shared.
  - Each frame, it sets position and yaw by interpolating previous and current
    state, and applies a bank of `clamp(turnRate / maxTurnRate) · 30°`.
  - Each aircraft entity carries `GroundingShadowComponent` and, on visionOS,
    `InputTargetComponent`, an enlarged `CollisionComponent` and
    `HoverEffectComponent`.
- **`PathPresenter`:** one `LowLevelMesh` per path, allocated for 2,000 points
  (4,000 vertices). Each vertex has a position (`float3`) and a UV (`u` = arc
  length, `v` = side), and the mesh is rewritten only when the path changes.
  A shader-graph material draws dashes from `u`, fades the part that has been
  flown, and takes a `Tint` parameter: white while drawing, the runway colour
  once committed. CPU writes are plenty at this size. The API allows Metal
  compute writes if we ever need them.
- **`MarkerPresenter`:**
  - Arrival arrows at the field edge, with the kind's glyph and a countdown
    pulse.
  - Conflict rings: flat disks under aircraft, with a pulsing shader graph.
  - A runway glow while an aircraft that can use it is being dragged.
- **Effects:** `ParticleEmitterComponent` presets authored in Reality
  Composer Pro: jet contrails, touchdown puffs, crash smoke and sparks. All
  subtle.

### 5.4 Camera and fitting (flat screens)

- **`CameraRig`:** a `PerspectiveCameraComponent` with a narrow field of view
  (about 30°), pitched 55–60° down. That gives the miniature look. An
  `OrthographicCameraComponent` is the alternative, decided in spike S4.
- **Fitting:** the rig solves for camera distance so the field rectangle plus
  a margin fits the viewport's aspect ratio, and recomputes on resize. Terrain
  extends well past the playable bounds, so wide iPhones, 4:3 iPads and odd
  Mac window shapes show scenery instead of black bars.
- **Input:** we own the camera, so a screen point maps to a ray and then to
  the ground plane with simple math we can unit-test, without relying on
  framework hit-testing.

### 5.5 Lighting and materials

- **Lights:** one `DirectionalLightComponent` with shadows, plus an
  `ImageBasedLightComponent` built from a soft custom environment. In visionOS
  volumes the system's room lighting blends with our image-based light.
- **Materials:** physically based materials with high roughness for the matte
  diorama look. Shader graphs only where something animates (water, paths,
  rings, runway lights).

## 6. Input

All input becomes `PointerEvent(id, phase, fieldPoint)` and goes through the
same `PathDrawingController`.

| Platform             | Gesture                                                      | To field space                                            |
|----------------------|--------------------------------------------------------------|-----------------------------------------------------------|
| iPhone, iPad         | `SpatialEventGesture` (several touches, each with an ID)     | Screen point → camera ray → ground plane (our own math)   |
| Mac                  | `DragGesture(minimumDistance: 0)`                            | Same as iPhone and iPad                                   |
| visionOS volume      | `DragGesture().targetedToAnyEntity()`; handles indirect pinch and direct touch | `value.convert(location3D, from: .local, to: fieldRoot)`, then drop the height |
| visionOS immersive   | Same as the volume                                           | Same as the volume                                        |

- **Grab radius:**
  - Flat screens: 44 pt converted to field units at the current zoom.
  - visionOS: aircraft collision shapes are about twice their visual size,
    plus nearest-aircraft snapping in field space, so gaze imprecision doesn't
    matter.
- **Spike S2** settles three visionOS questions before we commit:
  - Does an indirect-pinch drag feel better projected straight down, or
    raycast from the head through the hand?
  - Can two hands drive two paths at the same time?
  - Does `SpatialEventGesture` with `selectionRay` beat targeted drags?
- **Apple Pencil** works as touch for free. Pencil hover can show a preview
  of which aircraft will be grabbed.

## 7. UI (`FlightUI`)

### 7.1 App flow

```
launch → title (attract mode) ─► playing ⇄ paused
              ▲                     │
              │                     ▼
              └──── menu ◄──── game over ──► retry
```

- **`AppModel`** (`@Observable`) holds the navigation state, settings and the
  profile.
- **`GameSession`** is created for each run.
- **On iPhone, iPad and Mac,** the game's `RealityView` stays mounted behind
  all menus. The title screen is the live airfield in attract mode, so menu
  transitions are just overlays fading in and out.
- **Screens:** Title, Map select, Daily, Settings, How to play, HUD, Pause,
  Game over.
- **Performance:** the HUD observes `session.hud` only. That value changes a
  few times per second at most, never once per frame, so SwiftUI does no work
  on frames where nothing visible changed.
- **App lifecycle:** going to the background (`scenePhase`) pauses
  automatically.

### 7.2 Feedback hooks

```swift
HUDView(hud: session.hud)
    .sensoryFeedback(.success, trigger: session.hud.landed)
    .sensoryFeedback(.warning, trigger: session.hud.conflictCount)
    .sensoryFeedback(.error,   trigger: session.hud.crashed)
```

A custom crash pattern on iPhone uses Core Haptics.

## 8. visionOS

### 8.1 Scenes

```swift
@main struct FlightGameApp: App {
    var body: some Scene {
        WindowGroup(id: "airfield") { AirfieldVolume() }
            .windowStyle(.volumetric)
            .defaultSize(width: 1.2, height: 0.45, depth: 0.8, in: .meters)
            .windowResizability(.contentSize)

        ImmersiveSpace(id: "tower") { TowerSpace() }       // post-v1
            .immersionStyle(selection: $style, in: .mixed)
    }
}
```

- **v1 is volume-first.** The same `FieldRoot` as iOS is scaled so the field
  spans about 90% of the volume's width. With a 160 u field in a 1.2 m volume,
  a jet is about 4.5 cm long.
- **Resizing:** read the volume size with `GeometryReader3D`, convert it to
  scene units, and rescale `FieldRoot`. Gameplay is unaffected because it all
  happens in field units.
- **Menus and HUD:**
  - The HUD (score, best, pause) is an ornament attached to the volume.
  - Game over and pause are `ViewAttachmentComponent` panels floating above
    the field.
  - The title and map select live in the volume itself, with the attract-mode
    airfield behind them.
- **Viewpoint changes:** `onVolumeViewpointChange` turns the HUD and panels
  toward whichever side of the table the player is on.

### 8.2 Input and comfort

- **Indirect pinch is the main input.** Look at the aircraft, pinch, and move
  your hand in your lap. Direct touch (reaching into the volume) also works,
  but we don't design around it because it is tiring over a 10-minute run.
- **Gaze highlight:** `HoverEffectComponent` on every aircraft, with group
  IDs so the aircraft and its ring highlight together. This tells the player
  what a pinch will grab, which is the most important usability detail on
  this platform.
- **Size and speed:** keep the field near table height and comfortably within
  view. Game speed may need a per-platform multiplier, which spike S2 will
  tell us. That raises a leaderboard question (see open questions).

### 8.3 Spatial audio

Each aircraft entity gets a `SpatialAudioComponent` playing a looped engine
sound. To keep busy skies pleasant rather than a drone, only the six or so
nearest or most urgent aircraft are audible. Landing chimes play from the
runway itself, and the ambient bed comes from the terrain.

### 8.4 Performance

- Hold 90 fps.
- Use `MeshInstancesComponent` for repeated scenery (with a plain-entity
  fallback behind a flag).
- Keep aircraft under about 3k triangles each, use few materials, and use
  compressed textures (ASTC).
- Profile with the RealityKit Trace template in Instruments on device every
  milestone.

### 8.5 Tower Mode (post-v1, mixed immersive)

- **Placement:** the airfield sits on a real table, via an `AnchorEntity` on
  a horizontal plane classified as a table, with a manual-placement fallback.
- **Arrivals:** aircraft enter from a ring around the room at about eye height
  and descend along scripted 3D approach curves. They join the 2D field at
  its edge, which is when they become controllable.
- **Rules:** unchanged. The approach is presentation only.

### 8.6 SharePlay co-op (post-v1)

- **Host-authoritative:**
  - The host runs the simulation.
  - Guests send `Command`s.
  - The host broadcasts compact snapshots at 15–20 Hz, and guests interpolate.
- **Vision Pro:** spatial Personas stand around the same table.
- **Effort:** because the core is already command-driven, this is mostly
  networking work.

## 9. iOS, iPadOS and macOS details

- **iPhone:**
  - Landscape only.
  - HUD inside safe areas, with a left-handed option.
  - The field is kept large enough that a light prop is at least about 32 pt
    long.
- **iPad:**
  - Any orientation.
  - Several paths at once with several fingers.
  - Pencil hover preview.
  - Stage Manager window resizing handled by the camera rig.
- **macOS:**
  - A native target, not Catalyst.
  - Resizable window with a minimum size.
  - Menu commands: New Game ⌘N, Pause Space/Esc, Restart ⌘R.
  - Full-screen support.
- **tvOS:** RealityKit makes rendering easy there, but drawing paths with a
  Siri Remote is the hard part. We'll evaluate after v1.

## 10. Services (`FlightServices`)

- **Profile:**
  - A `Codable` JSON file in Application Support holding best score per map
    and mode, lifetime stats and unlocks.
  - Mirrored to `NSUbiquitousKeyValueStore` for iCloud sync. Conflicts merge
    by taking the maximum.
  - Settings use `@AppStorage`. SwiftData would be more than this needs.
- **Game Center:**
  - Authenticate at launch without blocking anything.
  - Submit scores at game over.
  - One leaderboard per map, plus a *recurring* daily leaderboard for the
    Daily Challenge.
  - Achievements.
  - The access point appears on the title screen only. Runs also show up in
    Apple's Games app.
- **Audio:**
  - `AudioDirector` consumes `GameEvent`s.
  - RealityKit audio for in-world sounds, and `AVAudioPlayer` for music.
  - On iOS the audio session uses the `.ambient` category, so the game
    respects the silent switch and mixes with the player's own music.
- **Privacy:** no third-party SDKs and no tracking in v1. Ship a privacy
  manifest.

## 11. Content pipeline

- **Modelling:** Blender → USDZ → the `FlightContent` Reality Composer Pro
  package. Shader graphs and particle presets are authored there too.
- **Level files:**

  ```json
  {
    "id": "coastal-field",
    "name": "Coastal Field",
    "field": { "width": 160, "height": 100 },
    "terrain": "Maps/CoastalField",
    "runways": [
      { "id": "long",  "accepts": ["jet"],  "threshold": [38, 30],
        "heading": 0, "length": 52, "captureRadius": 6, "headingTolerance": 35 },
      { "id": "short", "accepts": ["prop"], "threshold": [62, 66],
        "heading": 45, "length": 28, "captureRadius": 5, "headingTolerance": 35 },
      { "id": "pad",   "accepts": ["heli"], "threshold": [124, 72],
        "anyHeading": true, "captureRadius": 4 }
    ],
    "noFlyZones": [],
    "spawnEdges": ["north", "east", "south", "west"],
    "profiles": ["classic", "relaxed", "daily"]
  }
  ```

  Runway headings in JSON are degrees, counter-clockwise from east, and are
  converted to radians when decoded.
- **Budgets:**

  | Asset              | Budget                                       |
  |--------------------|----------------------------------------------|
  | Aircraft           | ≤ 3k tris, 1 material, shared atlas texture  |
  | Terrain per map    | ≤ 60k tris before instancing                 |
  | Scenery props      | ≤ 500 tris, instanced                        |
  | Textures           | ≤ 2048², ASTC                                |
  | Total memory       | < 300 MB                                     |
- **Level validator:** a tool that fails CI if runways sit outside the field,
  capture zones overlap, or approach corridors are blocked.

## 12. Performance targets

| Metric                    | Target                                       |
|---------------------------|----------------------------------------------|
| Frame rate                | 60 fps on the oldest supported iPhone, 120 fps on ProMotion devices, 90 fps on Vision Pro |
| Simulation tick           | < 0.2 ms with 40 aircraft                    |
| Draw calls                | < 100                                        |
| Steady-state allocations  | About zero per frame: pooled entities, reused buffers, `removeAll(keepingCapacity:)` |
| Cold launch to title      | < 2 s                                        |

## 13. Testing and tooling

- **Unit tests** (Swift Testing) in `FlightCore`:
  - Geometry, and path smoothing and resampling.
  - Pursuit following.
  - Landing capture, including heading-tolerance edge cases.
  - Collision and hysteresis.
  - Spawn fairness and difficulty curves.
  - Level decoding and validation.
  - `PathDrawingController` with synthetic multi-touch streams.
- **Determinism tests:** the same seed and replay produce the same world hash
  on the same architecture, and match within a tolerance across
  architectures.
- **Soak tests:** the autopilot plays 30 minutes of simulated time while
  checking invariants: no NaNs, a bounded aircraft count, no aircraft stuck
  outside the field.
- **Balance CLI** (`Tools/balance`): runs N bot games per profile and skill
  level, and writes survival-time distributions as CSV for tuning curves.
- **Debug overlay** (debug builds only):
  - A 2D Canvas view of the simulation (also our Phase 1 playable).
  - Sliders for difficulty parameters.
  - A frame-time readout.
  - Replay export.
- **App builds:** `xcodebuild` for the iOS Simulator, macOS and the visionOS
  Simulator in CI. Instruments profiling on device each milestone.

## 14. Project layout and build

```
FlightGame/
├─ project.yml            XcodeGen spec → FlightGame.xcodeproj
├─ App/
│  ├─ FlightGameApp.swift  scenes per platform
│  ├─ Platform/            iOS/, macOS/, visionOS/ specifics
│  └─ Resources/           asset catalog, Info.plist, entitlements
├─ Packages/
│  ├─ FlightCore/          Sources/, Tests/
│  ├─ FlightScene/
│  ├─ FlightUI/
│  ├─ FlightServices/
│  └─ FlightContent/       Reality Composer Pro package
├─ Tools/
│  ├─ balance/             headless bot runs
│  └─ levelcheck/          level validator
└─ docs/
```

- **Project file:** XcodeGen generates the `.xcodeproj` from `project.yml`,
  and the generated project is gitignored. The project stays text-defined and
  mergeable, and it can be edited from environments without Xcode, including
  cloud agent sessions. Tuist is the heavier alternative.
- **One multiplatform app target:** iPhone, iPad, Mac and Apple Vision
  destinations. Platform branches (`#if os(visionOS)`) are confined to
  `App/Platform` and the input and camera files in `FlightScene`.
- **Swift settings:**
  - Swift 6 language mode with complete strict concurrency.
  - App and UI modules use default MainActor isolation.
  - `FlightCore` value types are `Sendable` and nonisolated.
- **Formatting:** `swift-format`, with a config checked into the repo.
- **CI (GitHub Actions):**
  - **Linux:** `swift test` for `FlightCore` in the official Swift container.
    It's fast and cheap.
  - **macOS:** build the app for the three platforms and run `FlightCore`
    tests again natively.
