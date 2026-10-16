import MacBreatheCore
import SwiftUI

/// Menu bar panel: technique quick-pick, orb, Start/Stop, then commands. Preferences live in Settings.
public struct PanelView: View {
    let session: BreathSession
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.theme) private var theme: AppTheme = .system
    @FocusState private var focused: Bool
    @State private var height: CGFloat = 0

    public init(session: BreathSession) { self.session = session }

    private func showSettings() {
        dismiss()
        NSApp.activate()
        openSettings()
    }

    private func showWindow() {
        dismiss()
        NSApp.activate()
        openWindow(id: BreathWindow.id)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TechniqueMenu(session: session)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            BreathingView(session: session)
                .frame(height: 250)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)

            if session.showsWarning {
                AdvancedWarning(session: session).padding(.horizontal, 4).padding(.bottom, 8)
            } else {
                StartStopRow(session: session).padding(.horizontal, 8).padding(.bottom, 4)
            }

            MenuDivider()
            CommandRow(title: "Open Big Window", key: "⌘O", action: showWindow)
            MenuDivider()
            CommandRow(title: "Settings…", key: "⌘,", action: showSettings)
            CommandRow(title: "Quit Mac Breathe", key: "⌘Q", action: session.quit)
        }
        .padding(6)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .background(FitWindowHeight(height: height))
        .preferredColorScheme(theme.colorScheme)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.space) { session.toggle(); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(keys: ["q", ",", "o"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            switch press.key {
            case "q": session.quit()
            case ",": showSettings()
            default: showWindow()
            }
            return .handled
        }
    }
}

/// One calm Begin / Stop button with the session length under it.
struct StartStopRow: View {
    let session: BreathSession
    @AppStorage(Prefs.orbTheme) private var theme: OrbTheme = .ember

    var body: some View {
        VStack(spacing: 6) {
            Button(action: session.toggle) {
                Text(session.isRunning ? "Stop" : "Begin")
                    .frame(width: 120)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(theme.colors[1])
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
            .help(session.isRunning ? "Stop (Space)" : "Begin (Space, or ⌥⌘B from any app)")
            if session.isRunning { RemainingTime(session: session) } else { LengthMenu(session: session) }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Technique pop-up: favorites first, then every technique grouped by goal.
struct TechniqueMenu: View {
    let session: BreathSession
    @AppStorage(Prefs.favorites) private var favorites = ""

    var body: some View {
        Menu {
            let favorites = Catalog.all.filter { self.favorites.split(separator: ",").contains(Substring($0.id)) }
            if !favorites.isEmpty {
                Section("Favorites") { ForEach(favorites) { item($0) } }
            }
            ForEach(Goal.allCases) { goal in
                Section(goal.title) {
                    ForEach(Catalog.all.filter { $0.goal == goal }) { item($0) }
                }
            }
            Divider()
            Button("Custom") { session.select("custom") }
        } label: {
            Text(session.technique.name).font(.headline.weight(.medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Choose a technique")
    }

    private func item(_ technique: Technique) -> some View {
        Button {
            session.select(technique.id)
        } label: {
            if technique.id == session.technique.id {
                Label(technique.name, systemImage: "checkmark")
            } else {
                Text(technique.name)
            }
        }
    }
}

#Preview("Panel") {
    PanelView(session: BreathSession(observeSystem: false))
}

/// Session length, under the orb: starts at the technique's recommended time; click to change.
struct LengthMenu: View {
    let session: BreathSession
    var onDark = false
    @AppStorage(Prefs.sessionMinutes) private var minutes = 0.0

    var body: some View {
        Menu {
            Button { minutes = 0 } label: { item("Recommended · \(session.technique.suggested.title)", minutes == 0) }
            Divider()
            ForEach([1.0, 2, 3, 5, 10, 15, 20], id: \.self) { m in
                Button { minutes = m } label: { item("\(Int(m)) min", minutes == m) }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text(minutes == 0 ? session.technique.suggested.title : "\(Int(minutes)) min")
                if minutes == 0 { Text("· recommended").opacity(0.7) }
            }
            .font(onDark ? .callout : .caption)
            .foregroundStyle(onDark ? AnyShapeStyle(.white.opacity(0.55)) : AnyShapeStyle(.secondary))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Session length")
    }

    @ViewBuilder
    private func item(_ title: String, _ on: Bool) -> some View {
        if on { Label(title, systemImage: "checkmark") } else { Text(title) }
    }
}

/// Time left in a running session, ticking once a second.
struct RemainingTime: View {
    let session: BreathSession
    var onDark = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Duration.seconds(session.remaining(at: context.date).rounded(.up)).formatted(.time(pattern: .minuteSecond)))
                .font(onDark ? .callout : .caption)
                .monospacedDigit()
                .foregroundStyle(onDark ? AnyShapeStyle(.white.opacity(0.45)) : AnyShapeStyle(.tertiary))
        }
    }
}
