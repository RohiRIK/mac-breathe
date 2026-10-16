import Foundation

/// Seconds practised per local day, keyed "yyyy-MM-dd". Stored as JSON in UserDefaults.
public struct PracticeLog: Codable, Sendable, Equatable {
    public private(set) var secondsByDay: [String: Double]

    public init(secondsByDay: [String: Double] = [:]) { self.secondsByDay = secondsByDay }

    public init(json: String) {
        self = (try? JSONDecoder().decode(Self.self, from: Data(json.utf8))) ?? .init()
    }

    public var json: String {
        (try? JSONEncoder().encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func adding(_ seconds: Double, on date: Date, calendar: Calendar = .current) -> PracticeLog {
        guard seconds > 0 else { return self }
        let key = Self.key(date, calendar: calendar)
        return PracticeLog(secondsByDay: secondsByDay.merging([key: seconds], uniquingKeysWith: +))
    }

    /// Consecutive days with practice, ending today (or yesterday, so the streak survives until tonight).
    public func streak(today: Date, calendar: Calendar = .current) -> Int {
        func practised(_ d: Date) -> Bool { (secondsByDay[Self.key(d, calendar: calendar)] ?? 0) > 0 }
        var day = calendar.startOfDay(for: today)
        if !practised(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while practised(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    /// Minutes practised in the calendar week containing `today`.
    public func minutesThisWeek(today: Date, calendar: Calendar = .current) -> Double {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: today) else { return 0 }
        var total = 0.0
        var day = week.start
        while day < week.end {
            total += secondsByDay[Self.key(day, calendar: calendar)] ?? 0
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return total / 60
    }

    public var totalMinutes: Double { secondsByDay.values.reduce(0, +) / 60 }
}

/// When "Time to breathe" reminders fire.
public enum ReminderSchedule {
    /// Hours (0–23) to remind, every `everyHours` starting when quiet hours end, skipping quiet hours.
    /// Quiet hours run from `quietStart` up to (not including) `quietEnd` and may wrap past midnight.
    public static func hours(everyHours: Int, quietStart: Int, quietEnd: Int) -> [Int] {
        let step = max(everyHours, 1)
        func quiet(_ h: Int) -> Bool {
            if quietStart == quietEnd { return false }
            return quietStart < quietEnd ? (h >= quietStart && h < quietEnd) : (h >= quietStart || h < quietEnd)
        }
        let first = quietStart == quietEnd ? 9 : quietEnd
        return stride(from: 0, to: 24, by: step)
            .map { (first + $0) % 24 }
            .filter { !quiet($0) }
            .sorted()
    }

    /// Calendar triggers: one per hour, or one per hour per weekday (Mon–Fri, Gregorian weekday 2–6).
    public static func triggers(everyHours: Int, quietStart: Int, quietEnd: Int, weekdaysOnly: Bool) -> [DateComponents] {
        let hours = hours(everyHours: everyHours, quietStart: quietStart, quietEnd: quietEnd)
        guard weekdaysOnly else { return hours.map { DateComponents(hour: $0, minute: 0) } }
        return (2...6).flatMap { weekday in hours.map { DateComponents(hour: $0, minute: 0, weekday: weekday) } }
    }
}
