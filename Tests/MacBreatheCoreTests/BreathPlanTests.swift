import Foundation
import Testing
@testable import MacBreatheCore

@Suite struct CatalogTests {
    @Test func eighteenUniqueTechniques() {
        #expect(Catalog.all.count == 18)
        #expect(Set(Catalog.all.map(\.id)).count == 18)
        #expect(Set(Catalog.all.map(\.goal)) == Set(Goal.allCases))
    }

    @Test func everyTechniqueIsExplainedAndRunnable() {
        for t in Catalog.all {
            #expect(!t.what.isEmpty && !t.bestFor.isEmpty && !t.how.isEmpty && !t.pattern.isEmpty, "\(t.id)")
            #expect(t.cycleSeconds > 0, "\(t.id)")
            #expect(t.cycle.allSatisfy { $0.seconds > 0 }, "\(t.id)")
            // Advanced techniques always carry a safety caution.
            if t.difficulty == .advanced { #expect(t.caution != nil, "\(t.id)") }
        }
    }

    @Test func customDropsZeroHolds() {
        let t = Technique.custom(inhale: 4, hold: 0, exhale: 6, rest: 0)
        #expect(t.cycle.map(\.phase) == [.inhale, .exhale])
        #expect(t.pattern == "4 in · 6 out")
        #expect(Technique.custom(inhale: 0, hold: 0, exhale: 0, rest: 0).cycleSeconds == 8)
    }
}

@Suite struct BreathPlanTests {
    let box = Catalog.technique(id: "box")!

    @Test func orbGrowsOnInhaleAndShrinksOnExhale() {
        let plan = BreathPlan(technique: box)
        #expect(plan.state(at: 0).level == 0)
        #expect(plan.state(at: 2).level > 0.4 && plan.state(at: 2).level < 0.6)
        #expect(plan.state(at: 2).phase == .inhale)
        #expect(plan.state(at: 5).phase == .hold)
        #expect(plan.state(at: 5).level == 1)
        #expect(plan.state(at: 10).phase == .exhale)
        #expect(plan.state(at: 10).level < 1 && plan.state(at: 10).level > 0)
        #expect(plan.state(at: 13).phase == .rest)
        #expect(plan.state(at: 13).level == 0)
    }

    @Test func countdownCountsWholeSecondsLeftInPhase() {
        let plan = BreathPlan(technique: box)
        #expect(plan.state(at: 0).secondsLeft == 4)
        #expect(plan.state(at: 0.5).secondsLeft == 4)
        #expect(plan.state(at: 3.2).secondsLeft == 1)
    }

    @Test func suggestedMinutesEndAtCycleBoundary() {
        let plan = BreathPlan(technique: box)  // 4 min suggested, 16 s cycles
        #expect(plan.cycles == 15)
        #expect(plan.duration == 240)
        #expect(plan.state(at: 240).finished)
        #expect(!plan.state(at: 239.9).finished)
    }

    @Test func chosenMinutesOverrideSuggested() {
        // 1 min of Box: cycles until ≥ 60 s → 4 cycles = 64 s.
        let plan = BreathPlan(technique: box, options: PlanOptions(minutes: 1))
        #expect(plan.cycles == 4)
        #expect(plan.duration == 64)
    }

    @Test func suggestedCyclesRunExactly() {
        let plan = BreathPlan(technique: Catalog.technique(id: "4-7-8")!)
        #expect(plan.cycles == 4)
        #expect(plan.duration == 76)
    }

    @Test func paceAndBeginnerReshapeTiming() {
        let slow = BreathPlan(technique: box, options: PlanOptions(minutes: 1, pace: 0.8))
        #expect(slow.segments[0].duration == 5)
        let easy = BreathPlan(technique: box, options: PlanOptions(minutes: 1, beginner: true))
        #expect(easy.segments.map(\.duration).prefix(4) == [4, 2, 4, 2])
    }

    @Test func slowdownStretchesBreathsNotHolds() {
        let taper = BreathPlan(technique: Catalog.technique(id: "sleep-taper")!)
        let first = taper.segments.first!.duration
        let late = taper.segments.last { $0.phase == .inhale }!.duration
        #expect(first == 4)
        #expect(late > 5 && late <= 4 * PlanOptions.maxStretch)

        let boxSlow = BreathPlan(technique: box, options: PlanOptions(minutes: 5, slowdown: true))
        #expect(boxSlow.segments.filter { $0.phase == .hold }.allSatisfy { $0.duration == 4 })
    }

    @Test func holdsKeepLevelAndCycleEndsSmall() {
        let triangle = BreathPlan(technique: Catalog.technique(id: "triangle")!, options: PlanOptions(minutes: 0.1))
        #expect(triangle.segments.map(\.phase) == [.inhale, .hold, .exhale])
        let sigh = BreathPlan(technique: Catalog.technique(id: "sigh")!)
        #expect(sigh.segments[0].to == 0.8 && sigh.segments[1].from == 0.8)
        #expect(sigh.segments.last!.to == 0)
        // Wim Hof ends a round full after the recovery hold, then breathes out to empty.
        let wim = BreathPlan(technique: Catalog.technique(id: "wim-hof")!)
        #expect(wim.cycles == 3)
        #expect(wim.segments.last!.to == 0)
    }

    @Test func endsWithAnExtraExhaleIfCycleEndsFull() {
        let full = Technique(id: "x", name: "x", goal: .calm, difficulty: .beginner, pattern: "", what: "", bestFor: "", how: "",
                             suggested: .cycles(1), cycle: [Step(.inhale, 4), Step(.hold, 2)])
        let plan = BreathPlan(technique: full)
        #expect(plan.segments.last!.phase == .exhale)
        #expect(plan.duration == 8)
    }
}

@Suite struct PracticeTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }

    func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 12))!
    }

    @Test func streakCountsBackFromTodayOrYesterday() {
        let log = PracticeLog()
            .adding(60, on: day(12), calendar: calendar)
            .adding(60, on: day(13), calendar: calendar)
            .adding(60, on: day(14), calendar: calendar)
        #expect(log.streak(today: day(14), calendar: calendar) == 3)
        #expect(log.streak(today: day(15), calendar: calendar) == 3)  // not practised yet today
        #expect(log.streak(today: day(16), calendar: calendar) == 0)
    }

    @Test func weekMinutesAndRoundTrip() {
        let log = PracticeLog()
            .adding(120, on: day(12), calendar: calendar)  // Monday
            .adding(180, on: day(12), calendar: calendar)
            .adding(600, on: day(11), calendar: calendar)  // previous week (Sunday)
        #expect(log.minutesThisWeek(today: day(15), calendar: calendar) == 5)
        #expect(log.totalMinutes == 15)
        #expect(PracticeLog(json: log.json) == log)
        #expect(PracticeLog(json: "garbage") == PracticeLog())
    }
}

@Suite struct ReminderScheduleTests {
    @Test func skipsQuietHoursThatWrapMidnight() {
        #expect(ReminderSchedule.hours(everyHours: 2, quietStart: 22, quietEnd: 8) == [8, 10, 12, 14, 16, 18, 20])
        #expect(ReminderSchedule.hours(everyHours: 3, quietStart: 21, quietEnd: 9) == [9, 12, 15, 18])
    }

    @Test func daytimeQuietHoursAndNone() {
        #expect(ReminderSchedule.hours(everyHours: 4, quietStart: 12, quietEnd: 14) == [2, 6, 10, 14, 18, 22])
        #expect(ReminderSchedule.hours(everyHours: 4, quietStart: 0, quietEnd: 0) == [1, 5, 9, 13, 17, 21])
    }

    @Test func weekdaysOnlyMakesOneTriggerPerWeekday() {
        let t = ReminderSchedule.triggers(everyHours: 4, quietStart: 22, quietEnd: 8, weekdaysOnly: true)
        #expect(t.count == 5 * 4)  // 8, 12, 16, 20
        #expect(Set(t.compactMap(\.weekday)) == [2, 3, 4, 5, 6])
        #expect(ReminderSchedule.triggers(everyHours: 4, quietStart: 22, quietEnd: 8, weekdaysOnly: false).count == 4)
    }
}
