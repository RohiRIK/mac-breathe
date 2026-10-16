import MacBreatheUI
import SwiftUI

@main
struct MacBreatheApp: App {
    @State private var session = BreathSession()

    var body: some Scene {
        MenuBarExtra {
            PanelView(session: session)
        } label: {
            MenuBarLabel(session: session)
        }
        .menuBarExtraStyle(.window)

        Window("Mac Breathe", id: BreathWindow.id) {
            BreathWindow(session: session)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 760, height: 720)
        // Opened from the panel, or at launch by MenuBarLabel (Settings › General › Start in).
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(session: session)
        }
        .windowResizability(.contentSize)
    }
}

/// Menu bar icon: a leaf that swells and shrinks with the breath during a session.
/// It is the only view rendered at launch, so it also opens the big window when "Start in" says so
/// (`defaultLaunchBehavior(.presented)` is ignored for an `LSUIElement` app).
struct MenuBarLabel: View {
    let session: BreathSession
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Prefs.menuBarBreathes) private var menuBarBreathes = true

    var body: some View {
        Group {
            if session.isRunning, menuBarBreathes {
                Image(nsImage: MenuBarIcon.image(level: session.level))
            } else {
                Image(systemName: MenuBarIcon.symbol)
            }
        }
        .accessibilityLabel(session.isRunning ? "Mac Breathe, breathing \(session.technique.name)" : "Mac Breathe")
        .task {
            if UserDefaults.standard.string(forKey: Prefs.startIn) == "window" {
                NSApp.activate()
                openWindow(id: BreathWindow.id)
            }
        }
    }
}
