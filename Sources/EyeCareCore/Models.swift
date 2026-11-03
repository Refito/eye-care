import Foundation

public struct DropTime: Codable, Hashable, Identifiable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int
    public var id: String { String(format: "%02d:%02d", hour, minute) }

    public init(hour: Int, minute: Int) {
        self.hour = min(23, max(0, hour))
        self.minute = min(59, max(0, minute))
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.hour * 60 + lhs.minute < rhs.hour * 60 + rhs.minute
    }

    public func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var dropsEnabled = false
    public var dropTimes = [
        DropTime(hour: 9, minute: 0), DropTime(hour: 14, minute: 0), DropTime(hour: 19, minute: 0),
    ]
    public var soundEnabled = false
    public var restSoundEnabled = true
    public var showCountdown = false
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case dropsEnabled, dropTimes, soundEnabled, restSoundEnabled, showCountdown
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dropsEnabled = try values.decodeIfPresent(Bool.self, forKey: .dropsEnabled) ?? false
        dropTimes = try values.decodeIfPresent([DropTime].self, forKey: .dropTimes) ?? dropTimes
        soundEnabled = try values.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false
        restSoundEnabled = try values.decodeIfPresent(Bool.self, forKey: .restSoundEnabled) ?? true
        showCountdown = try values.decodeIfPresent(Bool.self, forKey: .showCountdown) ?? false
    }
}

public struct CareEvent: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case eyeBreak, drops }
    public var id: UUID
    public var date: Date
    public var kind: Kind
    public var scheduledTime: DropTime?
    public var scheduledDay: Date?

    public init(
        id: UUID = UUID(), date: Date, kind: Kind, scheduledTime: DropTime? = nil,
        scheduledDay: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.scheduledTime = scheduledTime
        self.scheduledDay = scheduledDay
    }
}

public struct CareData: Codable, Equatable, Sendable {
    public var settings = Settings()
    public var events: [CareEvent] = []
    public init() {}

    public func events(on day: Date, kind: CareEvent.Kind? = nil, calendar: Calendar = .current)
        -> [CareEvent]
    {
        events.filter {
            calendar.isDate($0.date, inSameDayAs: day) && (kind == nil || $0.kind == kind)
        }
    }

    public func isCompleted(_ slot: DropTime, on day: Date, calendar: Calendar = .current) -> Bool {
        events.contains {
            $0.kind == .drops && $0.scheduledTime == slot
                && calendar.isDate($0.scheduledDay ?? $0.date, inSameDayAs: day)
        }
    }

    public func slotToLog(at now: Date, calendar: Calendar = .current) -> DropTime? {
        guard settings.dropsEnabled else { return nil }
        let remaining = settings.dropTimes.sorted().filter {
            !isCompleted($0, on: now, calendar: calendar)
        }
        // A manual log satisfies the earliest unlogged slot already due, or a slot within 30 minutes.
        return remaining.first {
            $0.date(on: now, calendar: calendar) <= now.addingTimeInterval(30 * 60)
        }
    }

    public mutating func removeEvent(id: UUID) { events.removeAll { $0.id == id } }

    public mutating func prune(before date: Date) { events.removeAll { $0.date < date } }
}

public struct DropOccurrence: Identifiable, Equatable, Sendable {
    public var time: DropTime
    public var date: Date
    public var id: String { "drops-\(time.id)-\(Int(date.timeIntervalSince1970))" }
}

public enum DropSchedule {
    public static func upcoming(
        data: CareData, after now: Date, days: Int = 7, calendar: Calendar = .current
    ) -> [DropOccurrence] {
        guard data.settings.dropsEnabled else { return [] }
        let slots = Array(Set(data.settings.dropTimes)).sorted()
        return (0..<max(0, days)).flatMap { offset -> [DropOccurrence] in
            guard
                let day = calendar.date(
                    byAdding: .day, value: offset, to: calendar.startOfDay(for: now))
            else { return [] }
            return slots.compactMap { slot in
                let date = slot.date(on: day, calendar: calendar)
                guard date > now, !data.isCompleted(slot, on: day, calendar: calendar) else {
                    return nil
                }
                return DropOccurrence(time: slot, date: date)
            }
        }.sorted { $0.date < $1.date }
    }
}

public struct BreakClock: Sendable {
    public enum Phase: Sendable { case focus, due, resting }
    public private(set) var phase: Phase = .focus
    public private(set) var deadline: Date
    public private(set) var isPaused = false
    private var pausedSeconds: TimeInterval = 0
    public static let workDuration: TimeInterval = 20 * 60
    public static let restDuration: TimeInterval = 20

    public init(now: Date) { deadline = now.addingTimeInterval(Self.workDuration) }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, isPaused ? pausedSeconds : deadline.timeIntervalSince(now))
    }

    /// Returns true only when an explicitly started rest finishes.
    @discardableResult public mutating func advance(to now: Date) -> Bool {
        guard !isPaused, now >= deadline else { return false }
        switch phase {
        case .focus: phase = .due
        case .due: break
        case .resting:
            reset(at: now)
            return true
        }
        return false
    }

    public mutating func startRest(at now: Date) {
        phase = .resting
        isPaused = false
        deadline = now.addingTimeInterval(Self.restDuration)
    }

    public mutating func reset(at now: Date, duration: TimeInterval = Self.workDuration) {
        phase = .focus
        isPaused = false
        deadline = now.addingTimeInterval(duration)
    }

    public mutating func pause(at now: Date) {
        guard !isPaused else { return }
        pausedSeconds = remaining(at: now)
        isPaused = true
    }

    public mutating func resume(at now: Date) {
        guard isPaused else { return }
        deadline = now.addingTimeInterval(pausedSeconds)
        isPaused = false
    }
}
