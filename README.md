# Glidepath

An air-traffic-control arcade game for iPhone, iPad, Mac and Apple Vision
Pro. Draw paths to guide incoming aircraft to their matching runways, keep
them apart, and survive as traffic builds. On Vision Pro the airfield is a
diorama on your table.

> **Status:** Phase 1. The game is playable as a flat 2D playtest on iPhone,
> iPad and Mac, while the rules get tuned. Vision Pro shows the 3D
> placeholder for now. See the [roadmap](docs/ROADMAP.md).

## Playtest controls

| Action                  | iPhone and iPad              | Mac                              |
|-------------------------|------------------------------|----------------------------------|
| Draw a path             | Drag from an aircraft; several fingers at once | Drag from an aircraft |
| Change level            | Tap an aircraft, then ▲ / ▼  | Hover and press ↑ / ↓, or click for ▲ / ▼ |
| Pause                   | Pause button                 | Space or the pause button        |
| Map, mode, autopilot, 3D preview | ⋯ menu              | ⋯ menu                           |

Land each aircraft on the runway with its colour and glyph: ● props on the
short runway, ▲ jets on the long one, ■ helicopters on the pad (from any
direction). A path locks on and turns solid when it ends lined up with the
right runway. Coastal Field has one flight level. Test Range has three, plus
terrain you can only clear by flying above it.

## Getting started

You need a Mac with Xcode 26 or later, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig  # set your team ID and bundle ID prefix
xcodegen generate
open Glidepath.xcodeproj
```

Choose the **Glidepath** scheme, then an iPhone, iPad, Mac or Apple Vision
Pro destination. Run `xcodegen generate` again whenever `project.yml`
changes. The `.xcodeproj` isn't committed.

**Core tests** run anywhere Swift 6.2 or later is installed, Linux included:

```sh
swift test --package-path Packages/FlightCore
```

**Formatting:**

```sh
swift format lint --strict --recursive App Packages       # what CI checks
swift format format --in-place --recursive App Packages   # fix in place
```

## Layout

| Path                      | What's there                                                  |
|---------------------------|---------------------------------------------------------------|
| `project.yml`             | XcodeGen spec for the multiplatform `Glidepath` app target     |
| `App/`                    | The app entry point and its scenes per platform                |
| `Config/`                 | Shared xcconfig, your local signing settings, visionOS Info.plist |
| `Packages/FlightCore`     | Rules and simulation, plus level and difficulty JSON. Pure Swift, so it builds and tests on Linux. |
| `Packages/FlightScene`    | RealityKit: the game view, scene, input and camera            |
| `Packages/FlightUI`       | SwiftUI: menus, HUD and screens                               |
| `Packages/FlightServices` | Game Center, saved progress, audio and haptics                |
| `Packages/FlightContent`  | Models, materials and level files                             |
| `docs/`                   | Design, architecture and roadmap                              |

## Docs

- **[Game design](docs/GAME_DESIGN.md):** the loop, aircraft, paths, flight
  levels, landing, difficulty, modes, maps, look and feel, accessibility.
- **[Architecture](docs/ARCHITECTURE.md):** tech decisions, modules,
  simulation, rendering, input, visionOS, services, content pipeline, testing.
- **[Roadmap](docs/ROADMAP.md):** decision log, phases with exit checks,
  technical spikes, risks, open questions.

## Key decisions at a glance

| Area          | Decision                                                            |
|---------------|---------------------------------------------------------------------|
| Rendering     | RealityKit on every platform. SceneKit is soft-deprecated and can't do visionOS volumes. |
| Art direction | Low-poly diorama: matte materials, soft daylight, tilted miniature camera. |
| Metal         | Used for specific jobs: `LowLevelMesh` path ribbons and shader-graph materials. No custom renderer. |
| GameplayKit   | Not a core dependency. Swift enums and our own seeded RNG replace it. |
| Gameplay core | Pure-Swift simulation, 2D plus up to three flight levels: deterministic, fixed timestep at 60 Hz, testable on Linux CI. |
| Using 3D      | Flight levels: aircraft stack at different heights and pass over each other. Same rules on every platform. On Vision Pro you set the level with your hand. Coastal Field stays single-level. |
| UI            | SwiftUI everywhere. Ornaments and attachments on visionOS.          |
| visionOS      | A volumetric tabletop airfield first. Immersive "Tower Mode" after launch. |
| Minimum OS    | iOS, iPadOS, macOS and visionOS 26.                                 |
| Project       | XcodeGen `project.yml`, one multiplatform target, local Swift packages. |
