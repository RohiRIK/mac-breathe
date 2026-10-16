import Foundation

/// The built-in techniques, in display order (grouped by goal).
public enum Catalog {
    public static let all: [Technique] = calm + sleep + focus + balance + energy

    public static func technique(id: String) -> Technique? { all.first { $0.id == id } }

    private static func repeated(_ count: Int, _ steps: [Step]) -> [Step] {
        Array(repeating: steps, count: count).flatMap { $0 }
    }

    static let calm: [Technique] = [
        Technique(
            id: "sigh", name: "Physiological Sigh", goal: .calm, difficulty: .beginner,
            pattern: "2 in · 1 more in · 6 out",
            what: "A double breath in re-opens the small air sacs in the lungs, and a long breath out slows the heart. In a Stanford study, 5 minutes a day of cyclic sighing improved mood more than mindfulness meditation.",
            bestFor: "The fastest stress relief: one to three sighs bring you down in under a minute.",
            how: "Breathe in through the nose, then sip in a little more on top. Let it all out slowly through the mouth.",
            suggested: .minutes(1),
            cycle: [Step(.inhale, 2, to: 0.8), Step(.inhale, 1, to: 1, cue: "Sip in a little more"), Step(.exhale, 6, cue: "Slowly, through the mouth")]),
        Technique(
            id: "extended-exhale", name: "Extended Exhale", goal: .calm, difficulty: .beginner,
            pattern: "4 in · 6 out",
            what: "Breathing out longer than you breathe in signals the body to switch into rest mode.",
            bestFor: "Anxiety, a racing heart, the minutes after a hard meeting.",
            how: "Breathe in through the nose for 4. Breathe out gently for 6, as if through a straw.",
            suggested: .minutes(3),
            cycle: [Step(.inhale, 4), Step(.exhale, 6)]),
        Technique(
            id: "7-11", name: "7-11 Breathing", goal: .calm, difficulty: .intermediate,
            pattern: "7 in · 11 out",
            what: "A very long breath out, often taught for panic. Counting to 11 also gives the mind one simple job.",
            bestFor: "Panic and strong anxiety.",
            how: "Breathe in to the belly for 7, out for 11. If 11 is too long, slow the pace in Settings.",
            suggested: .minutes(3),
            cycle: [Step(.inhale, 7), Step(.exhale, 11)]),
        Technique(
            id: "humming", name: "Humming Bee", goal: .calm, difficulty: .intermediate,
            pattern: "4 in · 8 out, humming",
            what: "Bhramari. The hum lengthens the breath out, and its vibration is soothing. Humming also raises nitric oxide in the nose.",
            bestFor: "Racing thoughts, tension headaches, winding down after screens.",
            how: "Breathe in through the nose. Close the lips and hum like a bee all the way out.",
            suggested: .minutes(3),
            cycle: [Step(.inhale, 4), Step(.exhale, 8, cue: "Hum")]),
        Technique(
            id: "pursed-lip", name: "Pursed-Lip", goal: .calm, difficulty: .beginner,
            pattern: "2 in · 4 out",
            what: "Breathing out through pursed lips keeps the airways open longer and slows the breathing rate.",
            bestFor: "Feeling short of breath, recovering after stairs or exercise.",
            how: "Breathe in through the nose for 2. Purse the lips as if to whistle and breathe out for 4.",
            suggested: .minutes(3),
            cycle: [Step(.inhale, 2, cue: "Through the nose"), Step(.exhale, 4, cue: "Through pursed lips")]),
    ]

    static let sleep: [Technique] = [
        Technique(
            id: "4-7-8", name: "4-7-8", goal: .sleep, difficulty: .intermediate,
            pattern: "4 in · 7 hold · 8 out",
            what: "Dr. Andrew Weil's relaxing breath. The long hold and longer breath out slow everything down.",
            bestFor: "Falling asleep and winding down at night.",
            how: "Tongue behind the upper front teeth. In through the nose for 4, hold for 7, out through the mouth with a whoosh for 8. Start with 4 rounds.",
            caution: "Skip the hold if you feel dizzy.",
            suggested: .cycles(4),
            cycle: [Step(.inhale, 4), Step(.hold, 7), Step(.exhale, 8, cue: "Whoosh, through the mouth")]),
        Technique(
            id: "sleep-taper", name: "Sleep Taper", goal: .sleep, difficulty: .intermediate,
            pattern: "4 in · 6 out, slowing down",
            what: "Starts at an easy pace and stretches each breath a little every minute, easing you toward a sleep rhythm.",
            bestFor: "Lying in bed with the lights off.",
            how: "Follow the orb. Do not force the slower breaths; if one feels too long, breathe normally and rejoin.",
            suggested: .minutes(10),
            cycle: [Step(.inhale, 4), Step(.exhale, 6)], slowdown: 0.05),
        Technique(
            id: "belly", name: "Belly Breathing", goal: .sleep, difficulty: .beginner,
            pattern: "4 in · 6 out, into the belly",
            what: "Diaphragmatic breathing. Teaches deep breathing with the diaphragm instead of shallow chest breathing.",
            bestFor: "Beginners, and settling the body before sleep.",
            how: "One hand on the chest, one on the belly. Only the belly hand should rise and fall.",
            suggested: .minutes(5),
            cycle: [Step(.inhale, 4, cue: "Belly rises"), Step(.exhale, 6, cue: "Belly falls")]),
    ]

    static let focus: [Technique] = [
        Technique(
            id: "box", name: "Box Breathing", goal: .focus, difficulty: .intermediate,
            pattern: "4 in · 4 hold · 4 out · 4 hold",
            what: "Four equal sides. The steady rhythm calms the body while keeping you alert; taught to Navy SEALs.",
            bestFor: "Focus under pressure: before a presentation, an exam or a hard call.",
            how: "In for 4, hold full for 4, out for 4, hold empty for 4. Keep the shoulders soft.",
            caution: "Skip the holds if you feel dizzy.",
            suggested: .minutes(4),
            cycle: [Step(.inhale, 4), Step(.hold, 4), Step(.exhale, 4), Step(.rest, 4)]),
        Technique(
            id: "triangle", name: "Triangle", goal: .focus, difficulty: .beginner,
            pattern: "4 in · 4 hold · 4 out",
            what: "Box breathing without the empty hold. Easier, still steadying.",
            bestFor: "Light focus, and beginners working up to Box.",
            how: "In for 4, hold for 4, out for 4.",
            suggested: .minutes(3),
            cycle: [Step(.inhale, 4), Step(.hold, 4), Step(.exhale, 4)]),
        Technique(
            id: "ujjayi", name: "Ujjayi (Ocean Breath)", goal: .focus, difficulty: .intermediate,
            pattern: "5 in · 5 out, soft throat sound",
            what: "A slight narrowing of the throat makes a soft ocean sound, which keeps attention on the breath.",
            bestFor: "Deep work, yoga, staying present.",
            how: "Breathe through the nose. Gently narrow the back of the throat, as if fogging a mirror with the mouth closed.",
            suggested: .minutes(5),
            cycle: [Step(.inhale, 5, cue: "Soft ocean sound"), Step(.exhale, 5, cue: "Soft ocean sound")]),
    ]

    static let balance: [Technique] = [
        Technique(
            id: "coherent", name: "Coherent Breathing", goal: .balance, difficulty: .beginner,
            pattern: "5.5 in · 5.5 out",
            what: "Resonance breathing at about 5.5 breaths a minute, the rate most linked to higher heart rate variability (HRV).",
            bestFor: "A 10-minute daily practice for overall balance.",
            how: "Smooth, even breaths through the nose, no pauses at the top or bottom.",
            suggested: .minutes(10),
            cycle: [Step(.inhale, 5.5), Step(.exhale, 5.5)]),
        Technique(
            id: "equal", name: "Equal Breathing", goal: .balance, difficulty: .beginner,
            pattern: "4 in · 4 out",
            what: "Sama Vritti. The simplest pattern: breaths in and out of equal length.",
            bestFor: "Your first session, or a quick reset between tasks.",
            how: "In through the nose for 4, out through the nose for 4.",
            suggested: .minutes(2),
            cycle: [Step(.inhale, 4), Step(.exhale, 4)]),
        Technique(
            id: "alternate-nostril", name: "Alternate Nostril", goal: .balance, difficulty: .intermediate,
            pattern: "4 in left · 4 out right · 4 in right · 4 out left",
            what: "Nadi Shodhana. Switching sides gives the hands and mind a gentle rhythm; calming and balancing.",
            bestFor: "A midday reset, or before meditating.",
            how: "Right thumb closes the right nostril, ring finger the left. Follow the side shown under the orb.",
            suggested: .minutes(5),
            cycle: [Step(.inhale, 4, cue: "Left nostril"), Step(.exhale, 4, cue: "Right nostril"),
                    Step(.inhale, 4, cue: "Right nostril"), Step(.exhale, 4, cue: "Left nostril")]),
        Technique(
            id: "light", name: "Light Breathing", goal: .balance, difficulty: .intermediate,
            pattern: "3 in · 4 out, small and soft",
            what: "Buteyko-style reduced breathing: smaller, quieter breaths than usual. A slight air hunger is expected.",
            bestFor: "Habitual over-breathing, and calm without deep breaths.",
            how: "Breathe only through the nose, so softly a feather would not move. The orb stays small on purpose.",
            suggested: .minutes(5),
            cycle: [Step(.inhale, 3, to: 0.55, cue: "Small and soft"), Step(.exhale, 4, to: 0.25, cue: "Relax")]),
    ]

    static let energy: [Technique] = [
        Technique(
            id: "bellows", name: "Bellows Breath", goal: .energy, difficulty: .advanced,
            pattern: "20 fast breaths · rest, 3 rounds",
            what: "Bhastrika. Fast, full breaths in and out pump air like bellows and wake you up quickly.",
            bestFor: "A morning start or the afternoon slump.",
            how: "Breathe forcefully in and out through the nose, about one second each, moving the belly. Rest between rounds.",
            caution: "Can cause dizziness or tingling. Sit down. Not while driving, in water, pregnant, or with heart problems, high blood pressure or epilepsy. Stop if you feel unwell.",
            suggested: .cycles(3),
            cycle: repeated(20, [Step(.inhale, 1), Step(.exhale, 1)])
                + [Step(.rest, 30, to: 0.35, cue: "Breathe normally")]),
        Technique(
            id: "kapalabhati", name: "Skull Shining", goal: .energy, difficulty: .advanced,
            pattern: "30 sharp breaths out · rest, 3 rounds",
            what: "Kapalabhati. Short, sharp breaths out from the belly with a passive breath in. Energising and warming.",
            bestFor: "Morning energy and clearing a foggy head.",
            how: "Take a full breath in. Then snap the belly in to push air out of the nose; let the breath in happen by itself.",
            caution: "Can cause dizziness. Sit down, on an empty stomach. Not while driving, in water, pregnant, or with heart problems, high blood pressure, hernia or epilepsy.",
            suggested: .cycles(3),
            cycle: [Step(.inhale, 2)]
                + repeated(30, [Step(.exhale, 0.4, to: 0.55, cue: "Snap the belly"), Step(.inhale, 0.6, to: 1)])
                + [Step(.exhale, 3), Step(.rest, 20, to: 0.35, cue: "Breathe normally")]),
        Technique(
            id: "wim-hof", name: "Wim Hof Method", goal: .energy, difficulty: .advanced,
            pattern: "30 deep breaths · 60 hold empty · 15 hold full, 3 rounds",
            what: "Rapid deep breathing followed by a long hold on empty lungs. Strongly stimulating; practised to build stress and cold tolerance.",
            bestFor: "Experienced breathers who want a strong energy boost.",
            how: "30 deep breaths: fully in, let go out. After the last, breathe out and hold empty. Then one deep recovery breath, hold 15 seconds, let go.",
            caution: "Can cause fainting. Always sit or lie down. Never in or near water, while driving, standing, pregnant, or with heart problems or epilepsy.",
            suggested: .cycles(3),
            cycle: repeated(30, [Step(.inhale, 1.5), Step(.exhale, 1.5, to: 0.3)])
                + [Step(.exhale, 2, cue: "Let it all out"), Step(.rest, 60, cue: "Hold empty, relax"),
                   Step(.inhale, 2, cue: "Recovery breath"), Step(.hold, 15), Step(.exhale, 2)]),
    ]
}
