import Foundation
import SwiftData

/// What a complication or widget shows at a glance (#15): today's session, whether it's done,
/// and the next lift. A plain value, so a timeline can hold it after the store is closed.
///
/// Only exercise names, numbers and unit symbols are formatted here; words such as "Rest day"
/// belong to whoever draws it.
public struct TodayGlance: Hashable, Sendable {
    /// What the plan has today.
    public enum Day: Hashable, Sendable {
        /// No active plan, or the plan has run out.
        case nothingPlanned
        /// The plan continues, but not today.
        case rest
        /// A session, by the plan day's focus, e.g. "Lower A".
        case session(String)
    }

    /// The WidgetKit kind of the watch widget that shows this, for the app to reload after a
    /// set is logged or the plan changes.
    public static let watchWidgetKind = "\(Transmute.bundlePrefix).watch.today"

    public var day: Day
    /// Today's session already has a finished workout.
    public var isDone: Bool
    /// A workout is going right now.
    public var isRunning: Bool
    /// During a workout, the current set's exercise. Otherwise the first exercise of today's
    /// session, or of the next session on a rest day or once today's is done.
    public var nextLift: NextLift?

    public init(day: Day = .nothingPlanned, isDone: Bool = false, isRunning: Bool = false, nextLift: NextLift? = nil) {
        self.day = day
        self.isDone = isDone
        self.isRunning = isRunning
        self.nextLift = nextLift
    }

    /// Today's session name, or `nil` on a rest day or without a plan.
    public var sessionName: String? {
        if case .session(let name) = day { name } else { nil }
    }

    /// One exercise and its targets, e.g. "Bench press 5×5 · 80 kg".
    public struct NextLift: Hashable, Sendable {
        /// The exercise's name from the library, or its id when the library doesn't know it.
        public var name: String
        /// Working sets, or rounds for intervals.
        public var sets: Int
        /// What one set is, in figures: "5", "0:45" or "10 m". `nil` when nothing is set.
        public var amount: String?
        /// The load in the user's unit, e.g. "80 kg", when it's known.
        public var load: String?
        /// `amount` as VoiceOver should say it: "5", "45 seconds", "10 metres".
        public var spokenAmount: String?
        /// `load` as VoiceOver should say it: "80 kilograms".
        public var spokenLoad: String?

        public init(
            name: String, sets: Int, amount: String? = nil, load: String? = nil, spokenAmount: String? = nil,
            spokenLoad: String? = nil
        ) {
            self.name = name
            self.sets = sets
            self.amount = amount
            self.load = load
            self.spokenAmount = spokenAmount
            self.spokenLoad = spokenLoad
        }

        /// The numbers alone: "5×5 · 80 kg", "3×0:45", "6×10 m". `nil` when there are none.
        public var detail: String? {
            guard let amount, sets > 0 else { return nil }
            return ["\(sets)×\(amount)", load].compactMap(\.self).joined(separator: " · ")
        }

        /// The name and the numbers on one line: "Bench press 5×5 · 80 kg".
        public var text: String {
            [name, detail].compactMap(\.self).joined(separator: " ")
        }
    }
}

// MARK: - Building one

extension TodayGlance {
    /// The glance for a date.
    /// - Parameters:
    ///   - plan: The active plan, if there is one.
    ///   - workout: The workout still going, if there is one.
    ///   - profile: With one, a planned lift's numbers come from the progression engine, as
    ///     they will when the session starts. Without one, the plan's targets are used.
    ///   - units: The unit loads and distances are shown in.
    public init(
        plan: Plan?, workout: Workout? = nil, profile: Profile? = nil, units: Units,
        library: ExerciseLibrary = .bundled, on date: Date = .now, calendar: Calendar = .init(identifier: .iso8601)
    ) {
        let today = plan.map { TodayPlan(plan: $0, on: date, calendar: calendar) }
        let done = today?.isDone ?? false
        let planned: Day =
            if let focus = today?.day?.focus {
                .session(focus)
            } else if today?.next != nil {
                .rest
            } else {
                .nothingPlanned
            }

        if let workout, workout.endedAt == nil {
            let lift = WorkoutSession.currentSet(of: workout).flatMap { set in
                set.exercise.map { NextLift(current: set, of: $0, units: units, library: library) }
            }
            self.init(
                day: workout.title.isEmpty ? planned : .session(workout.title), isDone: false, isRunning: true,
                nextLift: lift)
            return
        }

        let upcoming = done ? today?.next : (today?.day ?? today?.next)
        let lift = upcoming?.orderedExercises.first.map {
            NextLift(planned: $0, profile: profile, units: units, library: library, before: date)
        }
        self.init(day: planned, isDone: done, isRunning: false, nextLift: lift)
    }

    /// Reads the active plan, the running workout, the profile and custom exercises from a
    /// store. An empty store gives `.nothingPlanned` with no lift.
    public static func load(
        from context: ModelContext, on date: Date = .now, calendar: Calendar = .init(identifier: .iso8601),
        locale: Locale = .current
    ) throws -> TodayGlance {
        let plans = try context.fetch(
            FetchDescriptor<Plan>(
                predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        let profile = try context.fetch(FetchDescriptor<Profile>()).first
        let custom = try context.fetch(FetchDescriptor<CustomExercise>())
        return TodayGlance(
            plan: plans.first, workout: try WorkoutSession.current(in: context), profile: profile,
            units: Units(profile, locale: locale),
            library: ExerciseLibrary.bundled.adding(custom.map(LibraryExercise.init)), on: date, calendar: calendar)
    }
}

extension TodayGlance.NextLift {
    /// The exercise of the set being done, at that set's numbers.
    init(current set: LoggedSet, of exercise: LoggedExercise, units: Units, library: ExerciseLibrary) {
        let working = exercise.orderedSets.filter { !$0.isWarmUp }
        self.init(
            exerciseID: exercise.exerciseID, sets: set.isWarmUp ? exercise.orderedSets.count : working.count,
            values: Values(
                reps: set.reps, seconds: set.seconds, meters: set.meters, loadKg: set.weightKg, rounds: set.rounds),
            units: units, library: library)
    }

    /// A planned exercise, by its first working set.
    init(planned: PlannedExercise, profile: Profile?, units: Units, library: ExerciseLibrary, before date: Date) {
        let context = planned.modelContext
        var targets = planned.orderedSets.map(SetTarget.init)
        if let profile {
            let history = context.flatMap { try? ProgressionEngine.history(of: planned.exerciseID, in: $0) }
            targets =
                ProgressionEngine.next(for: planned, history: history ?? [], profile: profile, library: library)
                .targets
        }
        let working = targets.filter { !$0.isWarmUp }
        let first = working.first ?? targets.first
        var values = Values(
            reps: first?.reps, seconds: first?.seconds, meters: first?.meters, loadKg: first?.loadKg,
            rounds: first?.rounds)
        if values.loadKg == nil, values.reps != nil, let context {
            // The plan left the load open: a session would start from the last one lifted.
            values.loadKg = WorkoutSession.lastWorkingLoad(of: planned.exerciseID, before: date, in: context)
        }
        self.init(
            exerciseID: planned.exerciseID, sets: working.isEmpty ? targets.count : working.count, values: values,
            units: units, library: library)
    }

    struct Values {
        var reps: Int?
        var seconds: Double?
        var meters: Double?
        var loadKg: Double?
        var rounds: Int?
    }

    /// The short form follows the plan screen's summary: intervals as rounds of work, then
    /// reps, distance or time, whichever the exercise is measured in. A load only goes with reps.
    init(exerciseID: String, sets: Int, values: Values, units: Units, library: ExerciseLibrary) {
        let name = library.exercise(id: exerciseID)?.name ?? exerciseID
        if let rounds = values.rounds, let seconds = values.seconds {
            self.init(
                name: name, sets: rounds, amount: Units.clock(seconds: seconds),
                spokenAmount: Self.spoken(seconds: seconds, locale: units.locale))
        } else if let reps = values.reps {
            self.init(
                name: name, sets: sets, amount: "\(reps)", load: values.loadKg.map { units.formatWeight(kg: $0) },
                spokenAmount: "\(reps)", spokenLoad: values.loadKg.map { Self.spoken(kg: $0, units: units) })
        } else if let meters = values.meters {
            self.init(
                name: name, sets: sets, amount: units.formatDistance(meters: meters),
                spokenAmount: Self.spoken(meters: meters, units: units))
        } else if let seconds = values.seconds {
            self.init(
                name: name, sets: sets, amount: Units.clock(seconds: seconds),
                spokenAmount: Self.spoken(seconds: seconds, locale: units.locale))
        } else {
            self.init(name: name, sets: sets)
        }
    }

    // MARK: Spoken forms

    /// e.g. "80 kilograms" or "176.5 pounds", rounded as `Units.formatWeight` rounds.
    static func spoken(kg: Double, units: Units) -> String {
        let value = (units.displayWeight(kg: kg) * 2).rounded() / 2
        return wide(Measurement(value: value, unit: units.weight == .metric ? UnitMass.kilograms : .pounds), units)
    }

    /// e.g. "10 metres", "1.5 kilometres" or "1 mile", in the units `Units.formatDistance` picks.
    static func spoken(meters: Double, units: Units) -> String {
        if meters < 1_000 {
            return wide(Measurement(value: meters.rounded(), unit: UnitLength.meters), units)
        }
        switch units.distance {
        case .metric: return wide(Measurement(value: meters / 1_000, unit: UnitLength.kilometers), units)
        case .imperial: return wide(Measurement(value: meters / Units.metresPerMile, unit: UnitLength.miles), units)
        }
    }

    /// e.g. "45 seconds" or "1 minute, 30 seconds".
    static func spoken(seconds: Double, locale: Locale) -> String {
        Duration.seconds(seconds.rounded()).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(locale))
    }

    private static func wide<U: Dimension>(_ measurement: Measurement<U>, _ units: Units) -> String {
        measurement.formatted(
            .measurement(
                width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2))
            ).locale(units.locale))
    }
}
