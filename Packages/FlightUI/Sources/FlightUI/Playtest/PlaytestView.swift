import FlightCore
import FlightScene
import SwiftUI

// Vision Pro gets gameplay in Phase 3; until then it shows the 3D placeholder.
#if !os(visionOS)
/// The Phase 1 playable: the real simulation drawn with flat shapes, to tune
/// the feel before any art exists.
struct PlaytestView: View {
    @State private var model = PlaytestModel()
    #if os(macOS)
    @State private var hoverLocation: CGPoint?
    @FocusState private var isFocused: Bool
    #endif

    /// Room above the field for the HUD.
    private static let fieldInsets = EdgeInsets(top: 64, leading: 16, bottom: 16, trailing: 16)

    var body: some View {
        if model.isShowing3D {
            preview3D
        } else {
            playtest
        }
    }

    private var playtest: some View {
        GeometryReader { proxy in
            let transform = FieldTransform(
                field: model.session.world.level.size, in: proxy.size, insets: Self.fieldInsets)
            TimelineView(.animation(minimumInterval: nil, paused: model.isFrozen)) { timeline in
                ZStack {
                    Canvas { context, _ in
                        FieldRenderer(
                            world: model.session.world, alpha: model.session.alpha,
                            transform: transform, held: model.held, flashes: model.flashes
                        )
                        .draw(in: &context)
                    }
                    levelControls(transform)
                }
                .onChange(of: timeline.date) { _, date in model.frame(at: date) }
            }
            .contentShape(Rectangle())
            .gesture(pointerGesture(transform))
            #if os(macOS)
            .onContinuousHover { phase in
                if case .active(let location) = phase {
                    hoverLocation = location
                } else {
                    hoverLocation = nil
                }
            }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onAppear { isFocused = true }
            .onKeyPress(.upArrow) { keyboardLevelChange(1, transform) }
            .onKeyPress(.downArrow) { keyboardLevelChange(-1, transform) }
            .onKeyPress(.space) {
                model.togglePause()
                return .handled
            }
            #endif
        }
        .background(Palette.sky.ignoresSafeArea())
        .overlay(alignment: .top) { PlaytestHUD(model: model) }
        .overlay {
            if model.session.hud.isOver { GameOverCard(model: model) }
        }
        .sensoryFeedback(.success, trigger: model.session.hud.landed)
        .sensoryFeedback(trigger: model.session.hud.conflicts) { old, new in
            new > old ? .warning : nil
        }
        .sensoryFeedback(.error, trigger: model.session.hud.strikesLeft)
    }

    private var preview3D: some View {
        ZStack(alignment: .topLeading) {
            GameView()
                .ignoresSafeArea()
            Button {
                model.isShowing3D = false
            } label: {
                Label("Playtest", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .overlay(alignment: .top) {
            TitleBadge()
                .padding()
        }
    }

    // MARK: - Level controls

    @ViewBuilder
    private func levelControls(_ transform: FieldTransform) -> some View {
        if let controls = model.levelControls,
            let plane = model.session.world.aircraft(controls.aircraft)
        {
            let point = transform.point(plane.position(interpolatedBy: model.session.alpha))
            VStack(spacing: 4) {
                Button {
                    model.changeLevel(of: plane.id, by: 1)
                } label: {
                    Image(systemName: "chevron.up").frame(width: 36, height: 30)
                }
                .disabled(plane.targetLevel >= model.session.world.level.ceiling(for: plane.kind))
                Text("\(plane.targetLevel)")
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
                Button {
                    model.changeLevel(of: plane.id, by: -1)
                } label: {
                    Image(systemName: "chevron.down").frame(width: 36, height: 30)
                }
                .disabled(plane.targetLevel <= 1)
            }
            .buttonStyle(.borderless)
            .padding(6)
            .background(.regularMaterial, in: Capsule())
            .position(x: point.x + 46, y: point.y)
        }
    }

    // MARK: - Input

    #if os(macOS)
    private func pointerGesture(_ transform: FieldTransform) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                model.pointer("mouse", phase: .active, at: value.location, transform: transform)
            }
            .onEnded { value in
                model.pointer("mouse", phase: .ended, at: value.location, transform: transform)
            }
    }

    private func keyboardLevelChange(_ delta: Int, _ transform: FieldTransform) -> KeyPress.Result {
        let target =
            hoverLocation.flatMap { model.aircraft(near: $0, transform: transform) }
            ?? model.levelControls?.aircraft
        guard let target else { return .ignored }
        model.changeLevel(of: target, by: delta)
        return .handled
    }
    #else
    /// Every finger draws its own path.
    private func pointerGesture(_ transform: FieldTransform) -> some Gesture {
        SpatialEventGesture()
            .onChanged { events in
                for event in events {
                    model.pointer(
                        event.id, phase: Self.phase(event.phase), at: event.location,
                        transform: transform)
                }
            }
            .onEnded { events in
                for event in events {
                    let phase: PlaytestModel.PointerPhase =
                        event.phase == .cancelled ? .cancelled : .ended
                    model.pointer(event.id, phase: phase, at: event.location, transform: transform)
                }
            }
    }

    private static func phase(_ phase: SpatialEventCollection.Event.Phase)
        -> PlaytestModel.PointerPhase
    {
        switch phase {
        case .active: .active
        case .ended: .ended
        default: .cancelled
        }
    }
    #endif
}

/// Score, strikes and controls along the top.
private struct PlaytestHUD: View {
    let model: PlaytestModel

    var body: some View {
        let hud = model.session.hud
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(hud.landed)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("landed · \(model.levelName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if model.session.world.profile.strikes > 1 {
                HStack(spacing: 2) {
                    ForEach(0..<model.session.world.profile.strikes, id: \.self) { index in
                        Image(systemName: index < hud.strikesLeft ? "heart.fill" : "heart")
                            .foregroundStyle(Palette.warning)
                    }
                }
                .accessibilityLabel("\(hud.strikesLeft) strikes left")
            }
            Spacer()
            Button {
                model.togglePause()
            } label: {
                Image(systemName: model.session.isPaused ? "play.fill" : "pause.fill")
            }
            .accessibilityLabel(model.session.isPaused ? "Resume" : "Pause")
            .disabled(hud.isOver)
            Button {
                model.restart()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel("Restart")
            menu
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var menu: some View {
        Menu {
            Picker(
                "Map",
                selection: Binding(get: { model.levelID }, set: { model.select(level: $0) })
            ) {
                ForEach(PlaytestModel.levels) { level in
                    Text(level.name).tag(level.id)
                }
            }
            Picker(
                "Mode",
                selection: Binding(get: { model.profileID }, set: { model.select(profile: $0) })
            ) {
                ForEach(PlaytestModel.profiles, id: \.id) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            Toggle(
                "Autopilot",
                isOn: Binding(get: { model.autopilotIsOn }, set: { model.autopilotIsOn = $0 }))
            Button("3D preview", systemImage: "cube") { model.isShowing3D = true }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Options")
    }
}

private struct GameOverCard: View {
    let model: PlaytestModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Crash!")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Landed \(model.session.hud.landed) in \(model.session.hud.seconds) s")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("Play again") { model.restart() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}
#endif
