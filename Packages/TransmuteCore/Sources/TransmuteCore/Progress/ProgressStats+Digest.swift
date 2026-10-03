import Foundation

extension ProgressStats {
    /// Everything the weekly summary says about one ISO week.
    public struct WeekDigest: Equatable, Sendable {
        public var weekStart: Date
        /// Planned sessions done in the plan week. Without a plan, or outside its weeks, the
        /// finished workouts of the week.
        public var sessionsDone: Int
        /// 0 without a plan, or outside its weeks.
        public var sessionsPlanned: Int
        public var volumeKg: Double
        /// Against the week before, as a fraction. `nil` when that week had no volume.
        public var volumeChange: Double?
        /// Records set this week, one per set with its headline, newest first.
        public var records: [Gold]
        /// Key lifts whose best estimated one-rep max this week beat their last session before
        /// the week.
        public var wentUp: [Move]
        /// Key lifts trained this week whose last three sessions never beat the first of the
        /// three. A lift that went up this week isn't listed.
        public var stalled: [Move]
        /// See `ProgressStats.streak(_:)`. 0 without a plan.
        public var streakWeeks: Int
        /// Nothing was logged this week.
        public var isEmpty: Bool

        /// A record set this week.
        public struct Gold: Equatable, Sendable {
            public var exerciseID: String
            public var name: String
            public var mark: RecordMark

            public init(exerciseID: String, name: String, mark: RecordMark) {
                self.exerciseID = exerciseID
                self.name = name
                self.mark = mark
            }
        }

        /// A key lift's estimated one-rep max between two sessions.
        public struct Move: Equatable, Sendable {
            public var exerciseID: String
            public var name: String
            public var fromKg: Double
            public var toKg: Double

            public init(exerciseID: String, name: String, fromKg: Double, toKg: Double) {
                self.exerciseID = exerciseID
                self.name = name
                self.fromKg = fromKg
                self.toKg = toKg
            }
        }

        public init(
            weekStart: Date, sessionsDone: Int = 0, sessionsPlanned: Int = 0, volumeKg: Double = 0,
            volumeChange: Double? = nil, records: [Gold] = [], wentUp: [Move] = [], stalled: [Move] = [],
            streakWeeks: Int = 0, isEmpty: Bool = true
        ) {
            self.weekStart = weekStart
            self.sessionsDone = sessionsDone
            self.sessionsPlanned = sessionsPlanned
            self.volumeKg = volumeKg
            self.volumeChange = volumeChange
            self.records = records
            self.wentUp = wentUp
            self.stalled = stalled
            self.streakWeeks = streakWeeks
            self.isEmpty = isEmpty
        }
    }

    /// The summary of the ISO week `now` falls in.
    public static func digest(
        plan: Plan?, workouts: [Workout], records: [PersonalRecord], now: Date = .now,
        calendar: Calendar = .init(identifier: .iso8601), library: ExerciseLibrary = .bundled
    ) -> WeekDigest {
        let span = week(of: now, calendar: calendar)
        let logged = workouts.count { $0.endedAt != nil && span.contains($0.startedAt) }
        var digest = WeekDigest(weekStart: span.lowerBound, sessionsDone: logged, isEmpty: logged == 0)

        if let plan {
            let current = planWeek(of: plan, on: now, calendar: calendar)
            if (1...max(plan.weekCount, 1)).contains(current) {
                let entry = adherence(of: plan, week: current, isCurrent: true, calendar: calendar)
                digest.sessionsDone = entry.done
                digest.sessionsPlanned = entry.planned
            }
            digest.streakWeeks = streak(adherence(of: plan, now: now, calendar: calendar))
        }

        let volume = volumeKPI(workouts, now: now, calendar: calendar)
        digest.volumeKg = volume.thisWeekKg
        digest.volumeChange = volume.change
        digest.records = gold(records, in: span, library: library)

        for exerciseID in keyLifts(of: plan, workouts: workouts, library: library) {
            let trend = maxTrend(of: exerciseID, workouts: workouts, records: records)
                .filter { $0.date < span.upperBound }
            let title = name(of: exerciseID, in: library)
            if let rise = rise(trend, weekStart: span.lowerBound) {
                digest.wentUp.append(.init(exerciseID: exerciseID, name: title, fromKg: rise.from, toKg: rise.to))
            } else if let stall = stall(trend, weekStart: span.lowerBound) {
                digest.stalled.append(.init(exerciseID: exerciseID, name: title, fromKg: stall.from, toKg: stall.to))
            }
        }
        return digest
    }

    // MARK: Helpers

    static func gold(_ records: [PersonalRecord], in week: Range<Date>, library: ExerciseLibrary) -> [WeekDigest.Gold] {
        RecordBoard.gold(records.filter { $0.date < week.upperBound }, since: week.lowerBound)
            .compactMap(\.first)
            .map { .init(exerciseID: $0.exerciseID, name: name(of: $0.exerciseID, in: library), mark: $0.mark) }
    }

    /// The last session before the week and the best of the week, when the week's is higher.
    static func rise(_ trend: [MaxPoint], weekStart: Date) -> (from: Double, to: Double)? {
        guard let before = trend.last(where: { $0.date < weekStart })?.kg,
            let best = trend.filter({ $0.date >= weekStart }).map(\.kg).max(), best > before + tolerance
        else { return nil }
        return (before, best)
    }

    /// The first and last of the latest three sessions, when the latest is in the week and
    /// neither of the later two beat the first.
    static func stall(_ trend: [MaxPoint], weekStart: Date) -> (from: Double, to: Double)? {
        let recent = Array(trend.suffix(3))
        guard recent.count == 3, recent[2].date >= weekStart,
            max(recent[1].kg, recent[2].kg) <= recent[0].kg + tolerance
        else { return nil }
        return (recent[0].kg, recent[2].kg)
    }
}
