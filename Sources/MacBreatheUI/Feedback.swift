import AppKit
import AVFoundation
import MacBreatheCore
import UserNotifications

/// Haptics, sounds and voice at each phase change. Reads its settings on every call.
@MainActor
final class Feedback {
    /// How far ahead a phase sound is booked on the audio clock.
    static let lookahead = 0.15

    private let defaults: UserDefaults
    private let speech = AVSpeechSynthesizer()
    private let sounds = SoundEngine()
    private var idleTask: Task<Void, Never>?

    init(defaults: UserDefaults) { self.defaults = defaults }

    private var volume: Float { Float(defaults.double(forKey: Prefs.volume)) }
    private var choice: SoundChoice { SoundChoice(rawValue: defaults.string(forKey: Prefs.sound) ?? "") ?? .handpan }
    private var bell: SoundEngine.Sound? { (BellChoice(rawValue: defaults.string(forKey: Prefs.bell) ?? "") ?? .gong).sound }
    private var background: SoundEngine.Sound? { (AmbienceChoice(rawValue: defaults.string(forKey: Prefs.ambience) ?? "") ?? .off).sound }

    /// Session start: warm up the engine and render the plan's sounds so the first one is on time.
    func prepare(_ plan: BreathPlan) {
        idleTask?.cancel()
        let choice = choice
        let needed = Set(plan.segments.filter { $0.duration >= 1.5 }.compactMap { choice.sound(for: $0.phase, seconds: $0.duration) })
        sounds.prepare(Array(needed) + [bell, background].compactMap { $0 })
    }

    /// The session begins (with the 3-2-1, if any): bell, then the background fades in.
    func sessionStarted() {
        if defaults.bool(forKey: Prefs.bellAtStart), let bell { sounds.play(bell, volume: volume) }
        if let background { sounds.startBackground(background, volume: Float(defaults.double(forKey: Prefs.ambienceVolume))) }
    }

    /// Book the sound for a phase that starts `delay` seconds from now.
    func schedule(_ segment: Segment, in delay: Double) {
        // Fast breathing (Bellows, Wim Hof) would turn sounds into noise.
        guard segment.duration >= 1.5, let sound = choice.sound(for: segment.phase, seconds: segment.duration) else { return }
        sounds.play(sound, volume: volume, in: delay)
    }

    /// A phase just began: haptic tap and spoken cue.
    func begin(_ segment: Segment) {
        if defaults.bool(forKey: Prefs.haptics) {
            // Felt only while a finger rests on a Force Touch trackpad.
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        guard segment.duration >= 1.5, defaults.bool(forKey: Prefs.voice) else { return }
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: segment.cue ?? segment.phase.title)
        utterance.volume = volume
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        speech.speak(utterance)
    }

    func finished() {
        if let bell { sounds.play(bell, volume: volume) }
    }

    func stop() {
        speech.stopSpeaking(at: .word)
        sounds.stopBackground()
        // Let the last breath or the bell ring out before pausing the engine.
        idleTask?.cancel()
        idleTask = Task {
            try? await Task.sleep(for: .seconds(7))
            if !Task.isCancelled { sounds.idle() }
        }
    }

    /// Settings preview of a bell.
    func preview(_ choice: BellChoice) {
        idleTask?.cancel()
        if let sound = choice.sound { sounds.play(sound, volume: volume, in: 0.05) }
    }

    /// Settings preview of a background: 8 s, fading in and out.
    func preview(_ choice: AmbienceChoice, volume: Double) {
        idleTask?.cancel()
        guard let sound = choice.sound else { return sounds.stopBackground() }
        sounds.startBackground(sound, volume: Float(volume))
        idleTask = Task {
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled { sounds.stopBackground() }
        }
    }

    /// Settings preview: one breath in and out, 4 s each.
    func preview(_ choice: SoundChoice) {
        idleTask?.cancel()
        for (i, phase) in [Phase.inhale, .exhale].enumerated() {
            if let sound = choice.sound(for: phase, seconds: 4) { sounds.play(sound, volume: volume, in: 0.1 + Double(i) * 4) }
        }
    }
}

/// "Time to breathe" notifications. Permission is requested only from the Settings toggle.
enum Reminders {
    static let prefix = "breathe-reminder-"

    @MainActor
    static func reschedule(_ defaults: UserDefaults = .standard) {
        let on = defaults.bool(forKey: Prefs.remindersOn)
        let triggers = ReminderSchedule.triggers(
            everyHours: defaults.integer(forKey: Prefs.reminderEvery),
            quietStart: defaults.integer(forKey: Prefs.quietStart),
            quietEnd: defaults.integer(forKey: Prefs.quietEnd),
            weekdaysOnly: defaults.bool(forKey: Prefs.weekdaysOnly))
        let name = BreathSession.technique(defaults).name
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            guard on, await center.notificationSettings().authorizationStatus == .authorized else { return }
            for (i, components) in triggers.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "Time to breathe"
                content.body = "Take a minute for \(name)."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(i)", content: content, trigger: trigger))
            }
        }
    }

    /// Asks for permission (first time only) and returns whether notifications are allowed.
    static func requestAccess() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func openNotificationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }
}
