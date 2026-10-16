import MacBreatheCore
import Observation
import ServiceManagement
import SwiftUI

/// The one breathing session shared by the panel, the big window and the menu bar icon.
/// Views draw the orb from `state(at:)` every frame; a 15 Hz tick drives cues, the icon and the end.
@MainActor @Observable
public final class BreathSession {
    public private(set) var technique: Technique
    public private(set) var plan: BreathPlan
    /// When breathing starts (after the 3-2-1 lead-in); nil = idle.
    public private(set) var startDate: Date?
    /// Orb level at tick rate, for the menu bar icon.
    public private(set) var level: Double = 0
    /// Start was pressed on an Advanced technique that has not been acknowledged yet.
    public private(set) var showsWarning = false
    /// The last session ran to its end (not stopped early); cleared on the next start.
    public private(set) var finishedSession = false
    public private(set) var opensAtLogin: Bool
    public private(set) var message: String?

    public var isRunning: Bool { startDate != nil }

    private let defaults: UserDefaults
    private let feedback: Feedback
    private let hotKey = HotKey()
    private var lastSegment = -1
    private var bookedSegment = -1
    private var loop: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    /// `observeSystem: false` for previews: no login item, hotkey, reminders or defaults observer.
    public init(defaults: UserDefaults = .standard, observeSystem: Bool = true) {
        Prefs.register()
        self.defaults = defaults
        self.feedback = Feedback(defaults: defaults)
        let technique = Self.technique(defaults)
        self.technique = technique
        self.plan = BreathPlan(technique: technique, options: Self.options(defaults))
        self.opensAtLogin = observeSystem && SMAppService.mainApp.status == .enabled
        guard observeSystem else { return }
        hotKey.action = { [weak self] in self?.toggle() }
        hotKey.isEnabled = defaults.bool(forKey: Prefs.hotKeyEnabled)
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.defaultsChanged() }
        }
        Reminders.reschedule(defaults)
    }

    // MARK: Technique

    static func technique(_ defaults: UserDefaults) -> Technique {
        let id = defaults.string(forKey: Prefs.techniqueID) ?? "box"
        if id == "custom" {
            return .custom(inhale: defaults.double(forKey: Prefs.customInhale), hold: defaults.double(forKey: Prefs.customHold),
                           exhale: defaults.double(forKey: Prefs.customExhale), rest: defaults.double(forKey: Prefs.customRest))
        }
        return Catalog.technique(id: id) ?? Catalog.all[0]
    }

    static func options(_ defaults: UserDefaults) -> PlanOptions {
        let minutes = defaults.double(forKey: Prefs.sessionMinutes)
        return PlanOptions(minutes: minutes > 0 ? minutes : nil, pace: defaults.double(forKey: Prefs.pace),
                           beginner: defaults.bool(forKey: Prefs.beginner), slowdown: defaults.bool(forKey: Prefs.slowdown))
    }

    public func select(_ id: String) {
        guard id != technique.id || id == "custom" else { return }
        if isRunning { stop() }
        showsWarning = false
        // Each breath starts at its own recommended length.
        defaults.set(0.0, forKey: Prefs.sessionMinutes)
        defaults.set(id, forKey: Prefs.techniqueID)
        reload()
    }

    private func reload() {
        let technique = Self.technique(defaults)
        let plan = BreathPlan(technique: technique, options: Self.options(defaults))
        if technique != self.technique { self.technique = technique }
        if plan != self.plan { self.plan = plan }
    }

    private func defaultsChanged() {
        hotKey.isEnabled = defaults.bool(forKey: Prefs.hotKeyEnabled)
        // A running session keeps the plan it started with.
        if !isRunning { reload() }
    }

    // MARK: Running

    public func toggle() { isRunning ? stop() : start() }

    public func start(acknowledged: Bool = false) {
        if technique.needsWarning, !acknowledged, !defaults.bool(forKey: Prefs.advancedAcknowledged) {
            showsWarning = true
            return
        }
        if acknowledged { defaults.set(true, forKey: Prefs.advancedAcknowledged) }
        showsWarning = false
        reload()
        finishedSession = false
        startDate = Date().addingTimeInterval(defaults.bool(forKey: Prefs.leadIn) ? 3 : 0)
        bookedSegment = -1
        feedback.prepare(plan)
        feedback.sessionStarted()
        lastSegment = -1
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(66))
            }
        }
    }

    public func cancelWarning() { showsWarning = false }

    public func stop() {
        loop?.cancel()
        loop = nil
        if let startDate { record(seconds: min(Date().timeIntervalSince(startDate), plan.duration)) }
        startDate = nil
        level = 0
        lastSegment = -1
        feedback.stop()
    }

    private func tick() {
        guard let startDate else { return }
        let t = Date().timeIntervalSince(startDate)
        bookNextSound(at: t)
        guard t >= 0 else { return }
        let state = plan.state(at: t)
        level = state.level
        if state.finished {
            feedback.finished()
            finishedSession = true
            stop()
            return
        }
        let index = plan.segmentIndex(at: t)
        if index != lastSegment {
            lastSegment = index
            feedback.begin(plan.segments[index])
        }
    }

    /// Books the next phase sound on the audio clock once it is within the lookahead, so it lands
    /// exactly on the phase change instead of up to a tick late.
    private func bookNextSound(at t: Double) {
        // In order, so the first phase (t = 0) is booked too; a phase already well under way is skipped.
        while bookedSegment + 1 < plan.segments.count {
            let segment = plan.segments[bookedSegment + 1]
            let lead = segment.start - t
            guard lead <= Feedback.lookahead else { return }
            bookedSegment += 1
            if lead > -0.25 { feedback.schedule(segment, in: max(lead, 0)) }
        }
    }

    private func record(seconds: Double) {
        // Ignore accidental starts.
        guard seconds >= 10 else { return }
        let log = PracticeLog(json: defaults.string(forKey: Prefs.practiceLog) ?? "")
        defaults.set(log.adding(seconds, on: Date()).json, forKey: Prefs.practiceLog)
    }

    // MARK: Drawing

    /// Breath state for a frame. Idle and lead-in show the smallest orb.
    public func state(at date: Date) -> BreathState {
        guard let startDate, date >= startDate else {
            return .idle
        }
        return plan.state(at: date.timeIntervalSince(startDate))
    }

    /// 3, 2, 1 before the first breath; nil otherwise.
    public func leadIn(at date: Date) -> Int? {
        guard let startDate, date < startDate else { return nil }
        return Int(startDate.timeIntervalSince(date).rounded(.up))
    }

    /// Seconds left in the session (including any lead-in), for "2:40 left".
    public func remaining(at date: Date) -> Double {
        guard let startDate else { return plan.duration }
        return max(plan.duration - date.timeIntervalSince(startDate), 0)
    }

    // MARK: App

    public func refreshLoginItem() { opensAtLogin = SMAppService.mainApp.status == .enabled }

    public func setOpensAtLogin(_ on: Bool) {
        message = nil
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            message = "Could not change Open at Login: \(error.localizedDescription)"
        }
        let status = SMAppService.mainApp.status
        opensAtLogin = status == .enabled
        if status == .requiresApproval {
            message = "Allow Mac Breathe in System Settings › General › Login Items."
        }
    }

    public func quit() {
        stop()
        NSApp.terminate(nil)
    }
}
