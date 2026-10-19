# FlightGame (working title)

An air-traffic-control arcade game for iPhone, iPad, Mac and Apple Vision
Pro. Draw paths to guide incoming aircraft to their matching runways, keep
them apart, and survive as traffic builds. On Vision Pro the airfield is a
diorama on your table.

> **Status:** planning. No code yet.

## Docs

- **[Game design](docs/GAME_DESIGN.md):** the loop, aircraft, paths,
  landing, difficulty, modes, maps, look and feel, accessibility.
- **[Architecture](docs/ARCHITECTURE.md):** tech decisions, modules,
  simulation, rendering, input, visionOS, services, content pipeline, testing.
- **[Roadmap](docs/ROADMAP.md):** phases with exit checks, technical spikes,
  risks, open questions.

## Key decisions at a glance

| Area          | Decision                                                            |
|---------------|---------------------------------------------------------------------|
| Rendering     | RealityKit on every platform. SceneKit is soft-deprecated and can't do visionOS volumes. |
| Art direction | Low-poly diorama: matte materials, soft daylight, tilted miniature camera. |
| Metal         | Used for specific jobs: `LowLevelMesh` path ribbons and shader-graph materials. No custom renderer. |
| GameplayKit   | Not a core dependency. Swift enums and our own seeded RNG replace it. |
| Gameplay core | Pure-Swift 2D simulation: deterministic, fixed timestep at 60 Hz, testable on Linux CI. |
| UI            | SwiftUI everywhere. Ornaments and attachments on visionOS.          |
| visionOS      | A volumetric tabletop airfield first. Immersive "Tower Mode" after launch. |
| Minimum OS    | iOS, iPadOS, macOS and visionOS 26.                                 |
| Project       | XcodeGen `project.yml`, one multiplatform target, local Swift packages. |
