import MacBreatheCore
import SwiftUI

/// UserDefaults keys shared by the panel, big window, menu bar label and Settings window.
public enum Prefs {
    public static let techniqueID = "techniqueID"
    /// Comma-separated technique ids shown in the quick-pick menus.
    public static let favorites = "favorites"
    public static let customInhale = "customInhale"
    public static let customHold = "customHold"
    public static let customExhale = "customExhale"
    public static let customRest = "customRest"
    public static let advancedAcknowledged = "advancedAcknowledged"
    // Session
    /// 0 = the technique's suggested length.
    public static let sessionMinutes = "sessionMinutes"
    public static let pace = "pace"
    public static let beginner = "beginner"
    public static let slowdown = "slowdown"
    public static let leadIn = "leadIn"
    // Look
    public static let orbStyle = "orbStyle"
    public static let orbTheme = "orbTheme"
    public static let showPhaseWords = "showPhaseWords"
    public static let showCountdown = "showCountdown"
    public static let menuBarBreathes = "menuBarBreathes"
    public static let fullScreenByDefault = "fullScreenByDefault"
    public static let theme = "theme"
    // Sound & Feel
    public static let haptics = "haptics"
    public static let sound = "sound"
    public static let volume = "volume"
    public static let voice = "voice"
    public static let bell = "bell"
    public static let bellAtStart = "bellAtStart"
    public static let ambience = "ambience"
    public static let ambienceVolume = "ambienceVolume"
    // Reminders
    public static let remindersOn = "remindersOn"
    public static let reminderEvery = "reminderEvery"
    public static let quietStart = "quietStart"
    public static let quietEnd = "quietEnd"
    public static let weekdaysOnly = "weekdaysOnly"
    // General
    public static let startIn = "startIn"
    public static let hotKeyEnabled = "hotKeyEnabled"
    // Progress
    public static let practiceLog = "practiceLog"

    /// Defaults for keys whose "off" value is not the right first-run value.
    public static func register() {
        UserDefaults.standard.register(defaults: [
            techniqueID: "box", pace: 1.0, leadIn: true, showPhaseWords: true,
            menuBarBreathes: true, haptics: true, volume: 0.6, bellAtStart: true, ambienceVolume: 0.4, reminderEvery: 2,
            quietStart: 22, quietEnd: 8, hotKeyEnabled: true, sound: "handpan",
            customInhale: 4.0, customHold: 2.0, customExhale: 6.0, customRest: 0.0,
        ])
    }
}

enum OrbStyle: String, CaseIterable, Identifiable {
    case circle, petals, rings
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum OrbTheme: String, CaseIterable, Identifiable {
    case ember, candle, rose, sunset, ocean, forest, lavender, mono, accent
    var id: Self { self }
    var title: String { self == .accent ? "Accent Color" : rawValue.capitalized }
    var colors: [Color] {
        switch self {
        case .ember: [Color(red: 1, green: 0.82, blue: 0.55), Color(red: 0.86, green: 0.42, blue: 0.24)]
        case .candle: [Color(red: 1, green: 0.93, blue: 0.75), Color(red: 0.95, green: 0.65, blue: 0.3)]
        case .rose: [Color(red: 1, green: 0.8, blue: 0.72), Color(red: 0.8, green: 0.4, blue: 0.42)]
        case .ocean: [Color(red: 0.35, green: 0.85, blue: 0.95), Color(red: 0.1, green: 0.4, blue: 0.9)]
        case .sunset: [Color(red: 1, green: 0.75, blue: 0.4), Color(red: 0.95, green: 0.3, blue: 0.5)]
        case .forest: [Color(red: 0.6, green: 0.95, blue: 0.7), Color(red: 0.1, green: 0.55, blue: 0.4)]
        case .lavender: [Color(red: 0.85, green: 0.75, blue: 1), Color(red: 0.5, green: 0.35, blue: 0.9)]
        case .mono: [Color.gray.opacity(0.5), Color.primary.opacity(0.8)]
        case .accent: [Color.accentColor.opacity(0.45), Color.accentColor]
        }
    }

    /// Very dark background for the big window, tinted to match (warm for the warm themes).
    var canvas: Color {
        switch self {
        case .ember, .candle, .sunset: Color(red: 0.09, green: 0.06, blue: 0.045)
        case .rose: Color(red: 0.09, green: 0.055, blue: 0.06)
        case .ocean, .accent: Color(red: 0.04, green: 0.05, blue: 0.08)
        case .forest: Color(red: 0.04, green: 0.07, blue: 0.055)
        case .lavender: Color(red: 0.06, green: 0.05, blue: 0.09)
        case .mono: Color(red: 0.06, green: 0.06, blue: 0.06)
        }
    }
}

enum SoundChoice: String, CaseIterable, Identifiable {
    case handpan, bowl, koshi, birds, rainstick, ocean, pad, off
    var id: Self { self }
    var title: String {
        switch self {
        case .handpan: "Handpan"
        case .bowl: "Singing Bowl"
        case .koshi: "Koshi Chimes"
        case .birds: "Birds"
        case .rainstick: "Rain Stick"
        case .ocean: "Ocean"
        case .pad: "Warm Pad"
        case .off: "Off"
        }
    }

    /// Recorded choices play clips from `Resources/Sounds/<raw>-<phase>.m4a` (CC0, THIRD_PARTY_NOTICES.md).
    private var isRecorded: Bool { ![.ocean, .pad, .off].contains(self) }
    /// Recorded choices with their own hold clip; the others stay quiet on holds.
    private var hasHold: Bool { [.handpan, .bowl].contains(self) }

    /// The sound for a phase of this length; nil = silent (empty holds are always quiet).
    func sound(for phase: Phase, seconds: Double) -> SoundEngine.Sound? {
        guard phase != .rest else { return nil }
        if isRecorded {
            if phase == .hold && !hasHold { return nil }
            return .file("\(rawValue)-\(phase.rawValue)")
        }
        // Half-second steps: close enough to the phase, and a slowing session reuses sounds.
        let tenths = Int((seconds * 2).rounded()) * 5
        switch self {
        case .ocean: return .ocean(phase, tenths: tenths)
        case .pad: return .pad(phase, tenths: tenths)
        default: return nil
        }
    }
}

enum StartIn: String, CaseIterable, Identifiable {
    case menuBar, window
    var id: Self { self }
    var title: String { self == .menuBar ? "Menu Bar Panel" : "Big Window" }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension OrbTheme {
    /// Settings window background: the big window's tint in dark mode, warm paper in light mode.
    var paper: Color {
        let dark = NSColor(canvas)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : NSColor(red: 0.98, green: 0.955, blue: 0.92, alpha: 1)
        })
    }
}

/// Bell at the start and end of a session (recorded CC0 clips).
enum BellChoice: String, CaseIterable, Identifiable {
    case gong, tibetan, bowl, koshi, handpan, none
    var id: Self { self }
    var title: String {
        switch self {
        case .gong: "Soft Gong"
        case .tibetan: "Tibetan Bowl"
        case .bowl: "Singing Bowl"
        case .koshi: "Koshi Chimes"
        case .handpan: "Handpan"
        case .none: "None"
        }
    }

    var sound: SoundEngine.Sound? {
        switch self {
        case .gong: .file("gong-end")
        case .tibetan: .file("bell-tibetan")
        case .bowl: .file("bowl-inhale")
        case .koshi: .file("koshi-inhale")
        case .handpan: .file("handpan-inhale")
        case .none: nil
        }
    }
}

/// Quiet background that loops for the whole session.
enum AmbienceChoice: String, CaseIterable, Identifiable {
    case off, birds, waves, crystal, handpan
    var id: Self { self }
    var title: String {
        switch self {
        case .off: "Off"
        case .birds: "Birds in the Trees"
        case .waves: "Ocean Waves"
        case .crystal: "Crystal Bowls"
        case .handpan: "Handpan Music"
        }
    }

    var sound: SoundEngine.Sound? { self == .off ? nil : .file("ambience-\(rawValue)") }
}
