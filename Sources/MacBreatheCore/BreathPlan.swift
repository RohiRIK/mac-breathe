import Foundation

/// User choices that reshape a technique's timing.
public struct PlanOptions: Sendable, Equatable {
    /// nil = the technique's suggested length.
    public var minutes: Double?
    /// Speed: 0.8 = 20 % slower breaths, 1.2 = 20 % faster.
    public var pace: Double
    /// Halves every hold.
    public var beginner: Bool
    /// Stretch breaths a little each minute (on top of a technique's own slowdown).
    public var slowdown: Bool

    public init(minutes: Double? = nil, pace: Double = 1, beginner: Bool = false, slowdown: Bool = false) {
        self.minutes = minutes
        self.pace = pace
        self.beginner = beginner
        self.slowdown = slowdown
    }

    /// Fraction added to breath length per minute when `slowdown` is on.
    public static let slowdownRate = 0.04
    /// Slowdown never stretches a breath past this factor.
    public static let maxStretch = 1.5
}

/// A timed segment of a session.
public struct Segment: Sendable, Equatable {
    public let start: Double
    public let duration: Double
    public let from: Double
    public let to: Double
    public let phase: Phase
    public let cue: String?
    public let cycle: Int
    public var end: Double { start + duration }
}

/// Where a session is at a moment in time.
public struct BreathState: Sendable, Equatable {
    public let phase: Phase
    public let cue: String?
    /// Orb size, 0 (smallest) … 1 (full).
    public let level: Double
    /// Whole seconds left in this phase, for the countdown.
    public let secondsLeft: Int
    public let cycle: Int
    public let finished: Bool

    /// Before a session starts: smallest orb, nothing counting.
    public static let idle = BreathState(phase: .rest, cue: nil, level: 0, secondsLeft: 0, cycle: 0, finished: false)
}

/// The whole session laid out in advance, so the state is a pure function of elapsed time.
public struct BreathPlan: Sendable, Equatable {
    public let segments: [Segment]
    public let cycles: Int
    public var duration: Double { segments.last?.end ?? 0 }

    public init(technique: Technique, options: PlanOptions = .init()) {
        let pace = min(max(options.pace, 0.5), 2)
        let rate = technique.slowdown + (options.slowdown ? PlanOptions.slowdownRate : 0)
        let target: Double?
        var cycleLimit: Int?
        switch (options.minutes, technique.suggested) {
        case (let m?, _): target = m * 60
        case (nil, .minutes(let m)): target = m * 60
        case (nil, .cycles(let n)): target = nil; cycleLimit = n
        }

        var segments: [Segment] = []
        var t = 0.0
        var level = 0.0
        var cycle = 0
        // Always at least one cycle; then stop at the first cycle boundary past the target.
        while true {
            let stretch = min(1 + rate * t / 60, PlanOptions.maxStretch)
            for step in technique.cycle {
                var seconds = step.seconds / pace
                if step.phase.isHold {
                    if options.beginner { seconds /= 2 }
                } else {
                    seconds *= stretch
                }
                let to = step.level ?? level
                segments.append(Segment(start: t, duration: seconds, from: level, to: to,
                                        phase: step.phase, cue: step.cue, cycle: cycle))
                t += seconds
                level = to
            }
            cycle += 1
            if let cycleLimit, cycle >= cycleLimit { break }
            if let target, t >= target { break }
        }
        // Settle back to the smallest size if the cycle ended full (e.g. Triangle never empties).
        if level > 0.001 {
            segments.append(Segment(start: t, duration: 2, from: level, to: 0, phase: .exhale, cue: nil, cycle: cycle - 1))
        }
        self.segments = segments
        self.cycles = cycle
    }

    public func state(at elapsed: Double) -> BreathState {
        guard let last = segments.last else {
            return BreathState(phase: .rest, cue: nil, level: 0, secondsLeft: 0, cycle: 0, finished: true)
        }
        if elapsed >= last.end {
            return BreathState(phase: .rest, cue: nil, level: last.to, secondsLeft: 0, cycle: last.cycle, finished: true)
        }
        let t = max(elapsed, 0)
        let segment = segments[segmentIndex(at: t)]
        let p = segment.duration > 0 ? (t - segment.start) / segment.duration : 1
        let eased = (1 - cos(.pi * min(max(p, 0), 1))) / 2
        return BreathState(
            phase: segment.phase, cue: segment.cue,
            level: segment.from + (segment.to - segment.from) * eased,
            secondsLeft: Int((segment.end - t).rounded(.up)),
            cycle: segment.cycle, finished: false)
    }

    /// Binary search for the segment containing `t` (start ≤ t < end).
    public func segmentIndex(at t: Double) -> Int {
        var lo = 0, hi = segments.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if segments[mid].start <= t { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }
}
