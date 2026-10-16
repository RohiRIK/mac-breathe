import Foundation

/// What the body does during one step.
public enum Phase: String, Sendable, Codable {
    case inhale, hold, exhale, rest

    public var title: String {
        switch self {
        case .inhale: "Breathe in"
        case .hold: "Hold"
        case .exhale: "Breathe out"
        case .rest: "Hold empty"
        }
    }

    /// Holds (full or empty) shrink in Beginner mode; breaths stretch with the gradual slowdown.
    public var isHold: Bool { self == .hold || self == .rest }
}

/// One timed step: the orb moves from the previous level to `level` (0 = smallest, 1 = full).
public struct Step: Sendable, Equatable {
    public let phase: Phase
    public let seconds: Double
    /// nil = keep the current size (holds).
    public let level: Double?
    /// Extra instruction under the phase word ("Hum", "Left nostril").
    public let cue: String?

    public init(_ phase: Phase, _ seconds: Double, to level: Double? = nil, cue: String? = nil) {
        self.phase = phase
        self.seconds = seconds
        self.level = level ?? (phase == .inhale ? 1 : phase == .exhale ? 0 : nil)
        self.cue = cue
    }
}

public enum Goal: String, Sendable, CaseIterable, Identifiable {
    case calm, sleep, focus, balance, energy
    public var id: Self { self }

    public var title: String {
        switch self {
        case .calm: "Calm & Anxiety"
        case .sleep: "Sleep"
        case .focus: "Focus"
        case .balance: "Balance & Daily"
        case .energy: "Energy"
        }
    }

    public var symbol: String {
        switch self {
        case .calm: "leaf"
        case .sleep: "moon.stars"
        case .focus: "scope"
        case .balance: "circle.lefthalf.filled"
        case .energy: "bolt"
        }
    }
}

public enum Difficulty: Int, Sendable, CaseIterable, Identifiable, Comparable {
    case beginner = 1, intermediate, advanced
    public var id: Self { self }
    public var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// How long a session runs when the user picks "Suggested".
public enum Suggested: Sendable, Equatable {
    case minutes(Double)
    case cycles(Int)

    public var title: String {
        switch self {
        case .minutes(let m): m == 1 ? "1 min" : "\(Int(m)) min"
        case .cycles(let n): n == 1 ? "1 round" : "\(n) rounds"
        }
    }
}

/// A breathing technique: one cycle of steps, repeated, plus the explanation shown in the app.
public struct Technique: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let goal: Goal
    public let difficulty: Difficulty
    /// Short pattern, e.g. "4 in · 7 hold · 8 out".
    public let pattern: String
    public let what: String
    public let bestFor: String
    public let how: String
    public let caution: String?
    public let suggested: Suggested
    public let cycle: [Step]
    /// Built-in gradual slowdown (fraction per minute), used by Sleep Taper.
    public let slowdown: Double

    public init(id: String, name: String, goal: Goal, difficulty: Difficulty, pattern: String,
                what: String, bestFor: String, how: String, caution: String? = nil,
                suggested: Suggested, cycle: [Step], slowdown: Double = 0) {
        self.id = id
        self.name = name
        self.goal = goal
        self.difficulty = difficulty
        self.pattern = pattern
        self.what = what
        self.bestFor = bestFor
        self.how = how
        self.caution = caution
        self.suggested = suggested
        self.cycle = cycle
        self.slowdown = slowdown
    }

    public var cycleSeconds: Double { cycle.reduce(0) { $0 + $1.seconds } }
    public var needsWarning: Bool { difficulty == .advanced }

    /// The user's own pattern from Settings. Zero-length holds are left out.
    public static func custom(inhale: Double, hold: Double, exhale: Double, rest: Double) -> Technique {
        let steps = [Step(.inhale, inhale), Step(.hold, hold), Step(.exhale, exhale), Step(.rest, rest)]
            .filter { $0.seconds > 0 }
        func n(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(0...1))) }
        var parts = ["\(n(inhale)) in"]
        if hold > 0 { parts.append("\(n(hold)) hold") }
        parts.append("\(n(exhale)) out")
        if rest > 0 { parts.append("\(n(rest)) hold") }
        return Technique(
            id: "custom", name: "Custom", goal: .balance, difficulty: hold + rest > 8 ? .intermediate : .beginner,
            pattern: parts.joined(separator: " · "),
            what: "Your own rhythm, set in Settings › Technique.",
            bestFor: "Practising a pattern from a teacher, book or class.",
            how: "Adjust the in, hold and out lengths until the rhythm feels easy, never strained.",
            suggested: .minutes(3), cycle: steps.isEmpty ? [Step(.inhale, 4), Step(.exhale, 4)] : steps)
    }
}
