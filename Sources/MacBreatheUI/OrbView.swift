import AppKit
import MacBreatheCore
import SwiftUI

/// The breathing orb at one level (0 = smallest, 1 = full). Pure drawing; callers animate the level.
struct OrbView: View {
    let level: Double
    var style: OrbStyle = .circle
    var theme: OrbTheme = .ember

    /// Smallest size as a fraction of the frame, so the orb never vanishes.
    private var scale: Double { 0.35 + 0.65 * min(max(level, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                // Guide ring: the size a full breath reaches.
                Circle()
                    .strokeBorder(theme.colors[1].opacity(0.12), lineWidth: max(side / 160, 1))
                switch style {
                case .circle: circle(side)
                case .petals: petals(side)
                case .rings: rings(side)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var gradient: RadialGradient {
        RadialGradient(colors: theme.colors, center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: 200)
    }

    private func circle(_ side: Double) -> some View {
        Circle()
            .fill(RadialGradient(colors: theme.colors, center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: side * scale * 0.6))
            .shadow(color: theme.colors[1].opacity(0.35 * level), radius: side / 12)
            .frame(width: side * scale, height: side * scale)
    }

    /// Six overlapping petals that open outward and turn a little as the breath fills.
    private func petals(_ side: Double) -> some View {
        let petal = side * 0.5 * (0.55 + 0.45 * level)
        return ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(RadialGradient(colors: theme.colors, center: .center, startRadius: 0, endRadius: petal * 0.6))
                    .frame(width: petal, height: petal)
                    .offset(x: side * 0.24 * level)
                    .rotationEffect(.degrees(Double(i) * 60 + 30 * level))
                    .opacity(0.55)
                    .blendMode(.plusLighter)
            }
        }
        .frame(width: side, height: side)
    }

    /// Concentric rings that spread apart on the in-breath.
    private func rings(_ side: Double) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let fraction = (Double(i) + 1) / 4
                Circle()
                    .stroke(theme.colors[i % 2 == 0 ? 1 : 0].opacity(1 - fraction * 0.6), lineWidth: side / 40)
                    .frame(width: side * scale * fraction, height: side * scale * fraction)
            }
            Circle()
                .fill(gradient)
                .frame(width: side * scale * 0.18, height: side * scale * 0.18)
        }
    }
}

/// Live orb with one soft word under it, drawn from the shared session every frame.
/// `large` = the big window's dark canvas; otherwise the menu bar panel.
struct BreathingView: View {
    let session: BreathSession
    var large = false
    @AppStorage(Prefs.orbStyle) private var style: OrbStyle = .circle
    @AppStorage(Prefs.orbTheme) private var theme: OrbTheme = .ember
    @AppStorage(Prefs.showPhaseWords) private var showWords = true
    @AppStorage(Prefs.showCountdown) private var showCountdown = false

    var body: some View {
        TimelineView(.animation(paused: !session.isRunning)) { context in
            let state = session.state(at: context.date)
            let leadIn = session.leadIn(at: context.date)
            VStack(spacing: large ? 28 : 10) {
                ZStack {
                    OrbView(level: state.level, style: style, theme: theme)
                    if let leadIn {
                        Text("\(leadIn)")
                            .font(.system(size: large ? 56 : 30, weight: .ultraLight, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .contentTransition(.numericText(countsDown: true))
                    }
                }
                words(state, leadIn: leadIn)
                    .frame(height: large ? 64 : 40)
            }
        }
    }

    private func words(_ state: BreathState, leadIn: Int?) -> some View {
        let breathing = session.isRunning && leadIn == nil
        let word = breathing && showWords ? state.phase.title : ""
        let detail = breathing ? (showWords ? state.cue ?? "" : "") + (showCountdown ? " \(state.secondsLeft)" : "")
            : large ? "" : session.isRunning ? "" : session.technique.pattern
        return VStack(spacing: 4) {
            Text(word)
                .font(large ? .system(size: 30, weight: .light) : .title3.weight(.regular))
                .foregroundStyle(large ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.primary))
            Text(detail.trimmingCharacters(in: .whitespaces))
                .font(large ? .title3.weight(.light) : .callout)
                .monospacedDigit()
                .foregroundStyle(large ? AnyShapeStyle(.white.opacity(0.45)) : AnyShapeStyle(.secondary))
                .lineLimit(1)
        }
        .animation(.easeInOut(duration: 0.6), value: word)
        .accessibilityElement(children: .combine)
    }
}

/// Explanation of a technique: pattern, what it does, best for, how, caution.
struct TechniqueCard: View {
    let technique: Technique

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(technique.goal.title, systemImage: technique.goal.symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(technique.difficulty.title) · \(technique.suggested.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(technique.pattern).font(.headline)
            section("What it does", technique.what)
            section("Best for", technique.bestFor)
            section("How", technique.how)
            if let caution = technique.caution {
                Label(caution, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(technique.difficulty == .advanced ? .red : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Inline warning before the first Advanced session (no modal: alerts are unreliable in a menu bar panel).
struct AdvancedWarning: View {
    let session: BreathSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(session.technique.name) is an advanced technique", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(session.technique.caution ?? "")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", action: session.cancelWarning)
                Button("I Understand, Start") { session.start(acknowledged: true) }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .padding(10)
        .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
    }
}

/// Menu bar icon: a leaf. During a session it swells and shrinks with the breath.
public enum MenuBarIcon {
    public static let symbol = "leaf"

    public static func image(level: Double) -> NSImage {
        let size = NSSize(width: 20, height: 18)
        let points = 9 + 6 * min(max(level, 0), 1)
        let config = NSImage.SymbolConfiguration(pointSize: points, weight: .regular)
        guard let leaf = NSImage(systemSymbolName: level > 0.5 ? "leaf.fill" : "leaf", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return NSImage(size: size) }
        let image = NSImage(size: size, flipped: false) { rect in
            let s = leaf.size
            leaf.draw(in: NSRect(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2, width: s.width, height: s.height))
            return true
        }
        image.isTemplate = true
        return image
    }
}

#Preview("Orb styles") {
    HStack(spacing: 20) {
        ForEach(OrbStyle.allCases) { style in
            VStack {
                OrbView(level: 0.2, style: style, theme: .ember).frame(width: 120)
                OrbView(level: 1, style: style, theme: .sunset).frame(width: 120)
                Text(style.title)
            }
        }
    }
    .padding()
}

#Preview("Card") {
    TechniqueCard(technique: Catalog.technique(id: "wim-hof")!).frame(width: 360).padding()
}
