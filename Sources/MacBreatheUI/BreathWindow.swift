import AppKit
import MacBreatheCore
import SwiftUI

/// The big window: a dark, quiet canvas with the orb and one word. Choosing a technique and reading
/// about it sit behind one tap; while breathing, every control fades away until the mouse moves.
/// The app shows a Dock icon only while this window is open.
public struct BreathWindow: View {
    public static let id = "breathe"

    let session: BreathSession
    @AppStorage(Prefs.fullScreenByDefault) private var fullScreenByDefault = false
    @AppStorage(Prefs.orbTheme) private var theme: OrbTheme = .ember
    @State private var window: NSWindow?
    @State private var choosing = false
    @State private var showsInfo = false
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var showsWellDone = false

    public init(session: BreathSession) { self.session = session }

    public var body: some View {
        ZStack {
            Canvas(theme: theme, session: session)
            VStack(spacing: 0) {
                Spacer(minLength: 40)
                BreathingView(session: session, large: true)
                    .padding(.horizontal, 60)
                Spacer(minLength: 24)
                footer
                    .frame(height: 120)
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 520, minHeight: 560)
        .background(WindowReader(window: $window))
        .onContinuousHover { _ in revealControls() }
        .onKeyPress(.space) { session.toggle(); return .handled }
        .onExitCommand {
            if window?.styleMask.contains(.fullScreen) == true { window?.toggleFullScreen(nil) }
            else if session.isRunning { session.stop() }
        }
        .onChange(of: session.isRunning) { _, running in
            if running { revealControls() } else { controlsVisible = true }
            if !running, session.finishedSession { wellDone() }
        }
        .sheet(isPresented: $choosing) { TechniqueChooser(session: session, isPresented: $choosing) }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
        .onChange(of: window) {
            if fullScreenByDefault, let window, !window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if session.showsWarning {
            AdvancedWarning(session: session).frame(maxWidth: 440)
        } else if session.isRunning {
            VStack(spacing: 12) {
                Button("Stop", action: session.stop)
                    .buttonStyle(QuietButtonStyle())
                RemainingTime(session: session, onDark: true)
            }
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.8), value: controlsVisible)
                .help("Stop (Space)")
        } else if showsWellDone {
            Text("Well done")
                .font(.title2.weight(.light))
                .foregroundStyle(.white.opacity(0.8))
                .transition(.opacity)
        } else {
            idleControls.transition(.opacity)
        }
    }

    private var idleControls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                Button { choosing = true } label: {
                    HStack(spacing: 4) {
                        Text(session.technique.name)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .help("Choose another technique")
                Button { showsInfo.toggle() } label: { Image(systemName: "info.circle") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.5))
                    .help("About \(session.technique.name)")
                    .popover(isPresented: $showsInfo, arrowEdge: .top) {
                        TechniqueCard(technique: session.technique).frame(width: 340).padding(18)
                    }
            }
            .font(.title3)
            .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 10) {
                Text(session.technique.pattern).foregroundStyle(.white.opacity(0.45))
                LengthMenu(session: session, onDark: true)
            }
            .font(.callout)
            Button("Begin") { session.start() }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .help("Begin (Space)")
        }
    }

    private func revealControls() {
        controlsVisible = true
        hideTask?.cancel()
        guard session.isRunning else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { controlsVisible = false }
        }
    }

    private func wellDone() {
        withAnimation(.easeInOut(duration: 0.6)) { showsWellDone = true }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeInOut(duration: 0.8)) { showsWellDone = false }
        }
    }
}

/// Deep background with a soft glow that swells with the breath.
private struct Canvas: View {
    let theme: OrbTheme
    let session: BreathSession

    var body: some View {
        TimelineView(.animation(paused: !session.isRunning)) { context in
            let level = session.state(at: context.date).level
            ZStack {
                theme.canvas
                RadialGradient(colors: [theme.colors[1].opacity(0.10 + 0.14 * level), .clear],
                               center: .center, startRadius: 0, endRadius: 700)
            }
            .ignoresSafeArea()
        }
    }
}

/// Soft capsule button for the dark canvas.
struct QuietButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(prominent ? .medium : .regular))
            .foregroundStyle(.white.opacity(prominent ? 0.95 : 0.6))
            .padding(.horizontal, prominent ? 44 : 28)
            .padding(.vertical, prominent ? 12 : 8)
            .background(.white.opacity(configuration.isPressed ? 0.22 : prominent ? 0.14 : 0.07), in: .capsule)
            .contentShape(.capsule)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// One-tap technique picker sheet for the big window.
struct TechniqueChooser: View {
    let session: BreathSession
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose a breath").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { isPresented = false }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            ScrollView {
                TechniqueRows(selected: session.technique.id, showsBestFor: true) { id in
                    session.select(id)
                    isPresented = false
                }
                .padding(12)
            }
        }
        .frame(width: 440, height: 560)
    }
}

/// Quiet list of techniques: goal headings in small caps, a name per row (and what it is best for).
/// Right-click a row to add it to Favorites (shown first in the panel's menu).
struct TechniqueRows: View {
    let selected: String
    var showsBestFor = false
    var includesCustom = false
    let select: (String) -> Void
    @AppStorage(Prefs.favorites) private var favorites = ""
    @AppStorage(Prefs.orbTheme) private var theme: OrbTheme = .ember

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(Goal.allCases) { goal in
                section(goal.title) {
                    ForEach(Catalog.all.filter { $0.goal == goal }) { row($0.id, $0.name, $0.bestFor, advanced: $0.difficulty == .advanced) }
                }
            }
            if includesCustom {
                section("Yours") { row("custom", "Custom", "Your own rhythm.", advanced: false) }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            content()
        }
    }

    private func row(_ id: String, _ name: String, _ bestFor: String, advanced: Bool) -> some View {
        let ids = favorites.split(separator: ",").map(String.init)
        let favorite = ids.contains(id)
        let isSelected = id == selected
        return Button { select(id) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.body.weight(isSelected ? .semibold : .regular))
                    if showsBestFor {
                        Text(bestFor).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if favorite { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.secondary) }
                if advanced, showsBestFor { Text("Advanced").font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, showsBestFor ? 6 : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(isSelected ? AnyShapeStyle(theme.colors[1].opacity(0.22)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
        .contextMenu {
            if id != "custom" {
                Button(favorite ? "Remove from Favorites" : "Add to Favorites") {
                    favorites = (favorite ? ids.filter { $0 != id } : ids + [id]).joined(separator: ",")
                }
            }
        }
    }
}

/// Hands the hosting `NSWindow` to SwiftUI (for full screen).
struct WindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { if window !== view.window { window = view.window } }
    }
}

#Preview("Big window") {
    BreathWindow(session: BreathSession(observeSystem: false)).frame(width: 900, height: 700)
}

#Preview("Chooser") {
    TechniqueChooser(session: BreathSession(observeSystem: false), isPresented: .constant(true))
}
