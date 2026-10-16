import MacBreatheCore
import SwiftUI
import UserNotifications

/// ⌘, Settings window. Every app preference lives here, never in the menu bar panel.
/// Calm on purpose: four tabs, warm paper background, few words; details fold away.
public struct SettingsView: View {
    let session: BreathSession
    @AppStorage(Prefs.theme) private var theme: AppTheme = .system
    @AppStorage(Prefs.orbTheme) private var orbTheme: OrbTheme = .ember

    public init(session: BreathSession) { self.session = session }

    public var body: some View {
        TabView {
            Tab("Breath", systemImage: "leaf") { BreathSettings(session: session) }
            Tab("Practice", systemImage: "timer") { PracticeSettings() }
            Tab("Look", systemImage: "circle.circle") { LookSettings() }
            Tab("General", systemImage: "gearshape") { GeneralSettings(session: session) }
        }
        .frame(width: 620, height: 560)
        .background(orbTheme.paper)
        .preferredColorScheme(theme.colorScheme)
        // Toggles and selections in the orb's color, not system blue.
        .tint(orbTheme.colors[1])
    }
}

/// Grouped form on the warm paper background.
private struct CalmForm<Content: View>: View {
    @ViewBuilder var content: Content
    @AppStorage(Prefs.orbTheme) private var orbTheme: OrbTheme = .ember

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .toggleStyle(.switch)
            .scrollContentBackground(.hidden)
            .background(orbTheme.paper)
    }
}

// MARK: Breath

private struct BreathSettings: View {
    let session: BreathSession
    @State private var showsMore = false
    @AppStorage(Prefs.customInhale) private var inhale = 4.0
    @AppStorage(Prefs.customHold) private var hold = 2.0
    @AppStorage(Prefs.customExhale) private var exhale = 6.0
    @AppStorage(Prefs.customRest) private var rest = 0.0

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                TechniqueRows(selected: session.technique.id, includesCustom: true) { session.select($0) }
                    .padding(12)
            }
            .frame(width: 210)
            Divider().opacity(0.5)
            ScrollView {
                VStack(spacing: 14) {
                    PreviewOrb(technique: session.technique).frame(width: 130, height: 130)
                        .padding(.top, 8)
                    VStack(spacing: 4) {
                        Text(session.technique.name).font(.title2.weight(.light))
                        Text("\(session.technique.pattern) · \(session.technique.suggested.title)").foregroundStyle(.secondary)
                    }
                    Text(session.technique.bestFor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let caution = session.technique.caution, session.technique.difficulty == .advanced {
                        Text(caution)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if session.technique.id == "custom" {
                        customEditor
                    } else {
                        DisclosureGroup("More about it", isExpanded: $showsMore) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(session.technique.what)
                                Text(session.technique.how).foregroundStyle(.secondary)
                                if let caution = session.technique.caution, session.technique.difficulty != .advanced {
                                    Text(caution).foregroundStyle(.secondary)
                                }
                            }
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                        }
                        .frame(maxWidth: 320)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
        }
        .onChange(of: session.technique.id) { showsMore = false }
    }

    private var customEditor: some View {
        VStack(spacing: 6) {
            stepper("Breathe in", $inhale, range: 1...15)
            stepper("Hold", $hold, range: 0...20)
            stepper("Breathe out", $exhale, range: 1...20)
            stepper("Hold empty", $rest, range: 0...20)
        }
        .frame(maxWidth: 260)
    }

    private func stepper(_ title: String, _ value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 0.5) {
            LabeledContent(title, value: "\(value.wrappedValue.formatted(.number.precision(.fractionLength(0...1)))) s")
        }
    }
}

/// A small orb that loops one cycle of a technique, so the rhythm can be seen before starting.
private struct PreviewOrb: View {
    let technique: Technique
    @AppStorage(Prefs.orbStyle) private var style: OrbStyle = .circle
    @AppStorage(Prefs.orbTheme) private var theme: OrbTheme = .ember
    @State private var start = Date()

    var body: some View {
        let plan = BreathPlan(technique: technique, options: PlanOptions(minutes: 0.01))
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: max(plan.duration, 1))
            OrbView(level: plan.state(at: t).level, style: style, theme: theme)
        }
        .onChange(of: technique.id) { start = Date() }
        .help("One cycle of \(technique.name)")
    }
}

// MARK: Practice

private struct PracticeSettings: View {
    @AppStorage(Prefs.pace) private var pace = 1.0
    @AppStorage(Prefs.beginner) private var beginner = false
    @AppStorage(Prefs.slowdown) private var slowdown = false
    @AppStorage(Prefs.leadIn) private var leadIn = true
    @AppStorage(Prefs.haptics) private var haptics = true
    @AppStorage(Prefs.sound) private var sound: SoundChoice = .handpan
    @AppStorage(Prefs.volume) private var volume = 0.6
    @AppStorage(Prefs.voice) private var voice = false
    @AppStorage(Prefs.bell) private var bell: BellChoice = .gong
    @AppStorage(Prefs.bellAtStart) private var bellAtStart = true
    @AppStorage(Prefs.ambience) private var ambience: AmbienceChoice = .off
    @AppStorage(Prefs.ambienceVolume) private var ambienceVolume = 0.4
    @State private var feedback = Feedback(defaults: .standard)

    var body: some View {
        CalmForm {
            Section {
                LabeledContent {
                    HStack {
                        Picker("Breath sounds", selection: $sound) {
                            ForEach(SoundChoice.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button("Play", systemImage: "play.circle") { feedback.preview(sound) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .font(.title3)
                            .disabled(sound == .off)
                            .help("Hear one breath in and out")
                    }
                } label: {
                    Text("Breath sounds")
                    Text("A gentle sound as each breath in and out begins.")
                }
                .onChange(of: sound) { feedback.preview(sound) }
                LabeledContent("Volume") {
                    Slider(value: $volume, in: 0...1).frame(width: 200)
                }
                Toggle("Spoken cues", isOn: $voice)
                Toggle(isOn: $haptics) {
                    Text("Trackpad taps")
                    Text("Felt with a finger resting on the trackpad.")
                }
            }
            Section("Bell & Background") {
                Picker(selection: $bell) {
                    ForEach(BellChoice.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("Bell")
                    Text("Rings when the session ends.")
                }
                .onChange(of: bell) { feedback.preview(bell) }
                Toggle("Also ring at the start", isOn: $bellAtStart)
                    .disabled(bell == .none)
                Picker(selection: $ambience) {
                    ForEach(AmbienceChoice.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("Background")
                    Text("Plays quietly for the whole session.")
                }
                .onChange(of: ambience) { feedback.preview(ambience, volume: ambienceVolume) }
                if ambience != .off {
                    LabeledContent("Background volume") {
                        Slider(value: $ambienceVolume, in: 0...1) { editing in
                            if !editing { feedback.preview(ambience, volume: ambienceVolume) }
                        }
                        .frame(width: 200)
                    }
                }
            }
            Section("Rhythm") {
                Toggle("3-2-1 before starting", isOn: $leadIn)
                LabeledContent("Pace") {
                    HStack {
                        Text("Slower").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $pace, in: 0.8...1.2, step: 0.05).frame(width: 160)
                        Text("Faster").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $beginner) {
                    Text("Shorter holds")
                    Text("Halves every hold while long ones still feel hard.")
                }
                Toggle(isOn: $slowdown) {
                    Text("Slow down gradually")
                    Text("Breaths lengthen a little each minute.")
                }
            }
            Section {
                Text("Session length is under the orb: each breath starts at its recommended time, and you can change it there.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Look

private struct LookSettings: View {
    @AppStorage(Prefs.orbStyle) private var style: OrbStyle = .circle
    @AppStorage(Prefs.orbTheme) private var orbTheme: OrbTheme = .ember
    @AppStorage(Prefs.showPhaseWords) private var showWords = true
    @AppStorage(Prefs.showCountdown) private var showCountdown = false
    @AppStorage(Prefs.menuBarBreathes) private var menuBarBreathes = true
    @AppStorage(Prefs.fullScreenByDefault) private var fullScreen = false
    @AppStorage(Prefs.theme) private var theme: AppTheme = .system

    var body: some View {
        CalmForm {
            Section("Orb") {
                HStack(spacing: 18) {
                    ForEach(OrbStyle.allCases) { s in
                        choice(s.title, selected: style == s, size: 60) { OrbView(level: 0.8, style: s, theme: orbTheme) } action: { style = s }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                HStack(spacing: 8) {
                    ForEach(OrbTheme.allCases) { t in
                        choice(t.title, selected: orbTheme == t, size: 34) { OrbView(level: 1, style: .circle, theme: t) } action: { orbTheme = t }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            Section("While Breathing") {
                Toggle("Words (Breathe in, Hold…)", isOn: $showWords)
                Toggle("Seconds", isOn: $showCountdown)
                Toggle("Menu bar leaf breathes", isOn: $menuBarBreathes)
                Toggle("Big window in full screen", isOn: $fullScreen)
            }
            Section {
                Picker("Appearance", selection: $theme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func choice<Content: View>(_ title: String, selected: Bool, size: CGFloat,
                                       @ViewBuilder content: () -> Content, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                content()
                    .frame(width: size, height: size)
                    .padding(3)
                    .overlay { if selected { Circle().strokeBorder(.tint, lineWidth: 2) } }
                Text(title).font(.caption2).foregroundStyle(selected ? .primary : .secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: General

private struct GeneralSettings: View {
    let session: BreathSession
    @AppStorage(Prefs.startIn) private var startIn: StartIn = .menuBar
    @AppStorage(Prefs.hotKeyEnabled) private var hotKey = true
    @AppStorage(Prefs.remindersOn) private var remindersOn = false
    @AppStorage(Prefs.reminderEvery) private var every = 2
    @AppStorage(Prefs.quietStart) private var quietStart = 22
    @AppStorage(Prefs.quietEnd) private var quietEnd = 8
    @AppStorage(Prefs.weekdaysOnly) private var weekdaysOnly = false
    @AppStorage(Prefs.practiceLog) private var practiceJSON = ""
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var confirmReset = false

    var body: some View {
        let log = PracticeLog(json: practiceJSON)
        let streak = log.streak(today: Date())
        CalmForm {
            Section {
                Toggle("Open at Login", isOn: Binding(get: { session.opensAtLogin }, set: session.setOpensAtLogin))
                if let message = session.message { Text(message).foregroundStyle(.red) }
                Picker("Start in", selection: $startIn) {
                    ForEach(StartIn.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Begin or stop with ⌥⌘B", isOn: $hotKey)
            }
            Section("Reminders") {
                Toggle("Remind me to breathe", isOn: Binding(get: { remindersOn }, set: { on in
                    remindersOn = on
                    guard on else { return }
                    Task {
                        _ = await Reminders.requestAccess()
                        status = await Reminders.status()
                        Reminders.reschedule()
                    }
                }))
                if remindersOn {
                    if status == .denied {
                        LabeledContent {
                            Button("Open Settings…", action: Reminders.openNotificationSettings)
                        } label: {
                            Text("Notifications are off for Mac Breathe").foregroundStyle(.red)
                        }
                    }
                    Picker("Every", selection: $every) {
                        ForEach(1...4, id: \.self) { Text($0 == 1 ? "hour" : "\($0) hours").tag($0) }
                    }
                    LabeledContent("Quiet hours") {
                        HStack {
                            Picker("From", selection: $quietStart) { hours }.labelsHidden()
                            Text("to")
                            Picker("Until", selection: $quietEnd) { hours }.labelsHidden()
                        }
                        .fixedSize()
                    }
                    Toggle("Weekdays only", isOn: $weekdaysOnly)
                }
            }
            Section("Your Practice") {
                LabeledContent("Streak", value: streak == 1 ? "1 day" : "\(streak) days")
                LabeledContent("This week", value: "\(Int(log.minutesThisWeek(today: Date()).rounded())) min")
                LabeledContent("All time", value: "\(Int(log.totalMinutes.rounded())) min")
                Button("Reset…", role: .destructive) { confirmReset = true }
                    .disabled(log.secondsByDay.isEmpty)
            }
        }
        .onAppear(perform: session.refreshLoginItem)
        .task { status = await Reminders.status() }
        .onChange(of: [every, quietStart, quietEnd]) { Reminders.reschedule() }
        .onChange(of: weekdaysOnly) { Reminders.reschedule() }
        .onChange(of: remindersOn) { if !remindersOn { Reminders.reschedule() } }
        .confirmationDialog("Reset your practice?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { practiceJSON = "" }
        } message: {
            Text("Your streak and minutes will be erased. This cannot be undone.")
        }
    }

    private var hours: some View {
        ForEach(0..<24, id: \.self) { h in
            Text(Calendar.current.date(from: DateComponents(hour: h))!.formatted(date: .omitted, time: .shortened)).tag(h)
        }
    }
}

#Preview("Settings") {
    SettingsView(session: BreathSession(observeSystem: false))
}
