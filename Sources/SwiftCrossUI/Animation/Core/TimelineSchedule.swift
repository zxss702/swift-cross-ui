import Foundation

/// A schedule that produces dates for timeline-driven updates.
public protocol TimelineSchedule {
    associatedtype Entries: Sequence where Entries.Element == Date

    typealias Mode = TimelineScheduleMode

    func entries(from startDate: Date, mode: Mode) -> Entries
}

/// A mode that controls the frequency of timeline entries.
public enum TimelineScheduleMode: Hashable, Sendable {
    case normal
    case lowFrequency
}

extension TimelineSchedule {
    public static func periodic(
        from startDate: Date,
        by interval: TimeInterval
    ) -> PeriodicTimelineSchedule {
        PeriodicTimelineSchedule(from: startDate, by: interval)
    }

    public static var everyMinute: EveryMinuteTimelineSchedule {
        EveryMinuteTimelineSchedule()
    }

    public static func explicit<S: Sequence>(
        _ dates: S
    ) -> ExplicitTimelineSchedule<S> where Self == ExplicitTimelineSchedule<S>, S.Element == Date {
        ExplicitTimelineSchedule(dates)
    }
}

/// A timeline schedule that repeats at a fixed interval.
public struct PeriodicTimelineSchedule: TimelineSchedule, Sendable {
    public struct Entries: Sequence, IteratorProtocol {
        public typealias Element = Date

        private var nextDate: Date
        private let interval: TimeInterval

        init(startDate: Date, interval: TimeInterval) {
            self.nextDate = startDate
            self.interval = interval
        }

        public mutating func next() -> Date? {
            defer {
                nextDate = nextDate.addingTimeInterval(interval)
            }
            return nextDate
        }
    }

    public var startDate: Date
    public var interval: TimeInterval

    public init(from startDate: Date, by interval: TimeInterval) {
        self.startDate = startDate
        self.interval = interval
    }

    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(startDate: max(self.startDate, startDate), interval: interval)
    }
}

/// A timeline schedule that produces one entry per minute.
public struct EveryMinuteTimelineSchedule: TimelineSchedule, Sendable {
    public struct Entries: Sequence, IteratorProtocol {
        public typealias Element = Date

        private var nextDate: Date

        init(startDate: Date) {
            let interval = floor(startDate.timeIntervalSinceReferenceDate / 60) * 60
            self.nextDate = Date(timeIntervalSinceReferenceDate: interval)
        }

        public mutating func next() -> Date? {
            defer {
                nextDate = nextDate.addingTimeInterval(60)
            }
            return nextDate
        }
    }

    public static var everyMinute: EveryMinuteTimelineSchedule {
        EveryMinuteTimelineSchedule()
    }

    public init() {}

    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(startDate: startDate)
    }
}

/// A timeline schedule backed by an explicit sequence of dates.
public struct ExplicitTimelineSchedule<Entries: Sequence>: TimelineSchedule
where Entries.Element == Date {
    public var dates: Entries

    public init(_ dates: Entries) {
        self.dates = dates
    }

    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        dates
    }
}

