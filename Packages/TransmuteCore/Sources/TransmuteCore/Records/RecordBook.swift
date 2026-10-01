import Foundation
import SwiftData

/// What checking off a set did for records.
public struct RecordCheck {
    /// Records the set just turned to gold, the headline first. Empty when there's nothing to
    /// celebrate.
    public var gold: [PersonalRecord]
    /// Values the set would set but that jump too far to trust. Ask the person, then call
    /// `RecordBook.confirm(_:)` if they say it's right.
    public var needsConfirmation: [RecordMark]

    public init(gold: [PersonalRecord] = [], needsConfirmation: [RecordMark] = []) {
        self.gold = gold
        self.needsConfirmation = needsConfirmation
    }
}

/// Keeps `PersonalRecord` rows in step with logged sets (#13).
///
/// Records are derived data: for any exercise they're exactly what `RecordDetector.replay`
/// finds in its completed sets, oldest first. Checking off a set, confirming one, and editing
/// or deleting a past set (#14) all recompute the exercise and apply the difference, so rows
/// that still hold are kept as they are, stale ones are deleted, and recomputing twice changes
/// nothing. Nothing is saved; the caller saves with the rest of its change.
public struct RecordBook {
    public let context: ModelContext
    public let library: ExerciseLibrary

    public init(context: ModelContext, library: ExerciseLibrary = .bundled) {
        self.context = context
        self.library = library
    }

    /// Call after a set is checked off (or saved). Returns what's new for a toast.
    ///
    ///     set.complete()
    ///     let check = try RecordBook(context: context).check(set)
    @discardableResult
    public func check(_ set: LoggedSet) throws -> RecordCheck {
        guard let exerciseID = set.exercise?.exerciseID else { return RecordCheck() }
        let previousVolumeSessions = volumeRecordWorkouts(for: exerciseID)
        let outcome = try apply(exerciseID: exerciseID)
        let gold = outcome.inserted.filter { record in
            guard record.set === set else { return false }
            // Session volume turns gold once a session, however many sets raise it after.
            guard record.kind == .sessionVolume, let workout = set.exercise?.workout else { return true }
            return !previousVolumeSessions.contains(workout.persistentModelID)
        }
        let order = RecordDetector.headlineFirst(gold.map(\.mark))
        return RecordCheck(
            gold: gold.sorted { order.firstIndex(of: $0.mark) ?? 0 < order.firstIndex(of: $1.mark) ?? 0 },
            needsConfirmation: set.isRecordConfirmed ? [] : outcome.flagged[set.persistentModelID] ?? [])
    }

    /// The person says a suspicious set is right. Marks it confirmed and returns the records it
    /// sets.
    @discardableResult
    public func confirm(_ set: LoggedSet) throws -> RecordCheck {
        set.isRecordConfirmed = true
        return try check(set)
    }

    /// Rebuilds an exercise's records from all its completed sets. Call after a past set is
    /// edited or deleted, or a workout is deleted. Returns the rows it added.
    @discardableResult
    public func recompute(exerciseID: String) throws -> [PersonalRecord] {
        try apply(exerciseID: exerciseID).inserted
    }

    /// Recomputes every exercise that has logged sets or records.
    public func recomputeAll() throws {
        let logged = try context.fetch(FetchDescriptor<LoggedExercise>()).map(\.exerciseID)
        let recorded = try context.fetch(FetchDescriptor<PersonalRecord>()).map(\.exerciseID)
        for exerciseID in Set(logged + recorded) {
            try recompute(exerciseID: exerciseID)
        }
    }

    /// How the exercise is measured: from the library, then the user's custom exercises, then
    /// guessed from what was logged.
    public func tracking(for exerciseID: String, sets: [LoggedSet] = []) -> TrackingType {
        if let tracking = library.exercise(id: exerciseID)?.tracking { return tracking }
        let custom = FetchDescriptor<CustomExercise>(predicate: #Predicate { $0.exerciseID == exerciseID })
        if let tracking = (try? context.fetch(custom))?.first?.tracking { return tracking }
        let sample = sets.first { $0.reps != nil || $0.seconds != nil || $0.meters != nil }
        switch (sample?.weightKg, sample?.reps, sample?.meters) {
        case (.some, .some, _): return .weightReps
        case (_, .some, _): return .reps
        case (_, _, .some): return .distanceTime
        default: return .time
        }
    }

    // MARK: Applying

    private struct Outcome {
        var inserted: [PersonalRecord] = []
        var flagged: [PersistentIdentifier: [RecordMark]] = [:]
    }

    private struct Key: Hashable {
        let set: PersistentIdentifier
        let slot: RecordSlot
    }

    private func apply(exerciseID: String) throws -> Outcome {
        let (sessions, sets) = try history(for: exerciseID)
        let replay = RecordDetector.replay(sessions, tracking: tracking(for: exerciseID, sets: sets))

        var outcome = Outcome()
        for event in replay.needsConfirmation {
            outcome.flagged[sets[event.setID].persistentModelID, default: []].append(event.mark)
        }

        var existing: [Key: PersonalRecord] = [:]
        for record in try records(for: exerciseID) {
            guard let set = record.set, !set.isDeleted else {
                context.delete(record)
                continue
            }
            let key = Key(set: set.persistentModelID, slot: record.mark.slot)
            if existing[key] == nil {
                existing[key] = record
            } else {
                context.delete(record)
            }
        }

        for event in replay.records {
            let set = sets[event.setID]
            let date = set.completedAt ?? set.exercise?.workout?.startedAt ?? .now
            let key = Key(set: set.persistentModelID, slot: event.mark.slot)
            if let record = existing.removeValue(forKey: key) {
                if record.value != event.mark.value { record.value = event.mark.value }
                if record.date != date { record.date = date }
            } else {
                let record = PersonalRecord(exerciseID: exerciseID, mark: event.mark, date: date, set: set)
                context.insert(record)
                outcome.inserted.append(record)
            }
        }
        for record in existing.values {
            context.delete(record)
        }
        return outcome
    }

    /// The exercise's sets as sessions, oldest first, and the sets indexed by `RecordSet.id`.
    private func history(for exerciseID: String) throws -> ([RecordSession], [LoggedSet]) {
        let descriptor = FetchDescriptor<LoggedExercise>(predicate: #Predicate { $0.exerciseID == exerciseID })
        let exercises = try context.fetch(descriptor).filter { !$0.isDeleted && $0.workout?.isDeleted != true }

        // One exercise can appear twice in a workout; both count as one session.
        var byWorkout: [PersistentIdentifier: [LoggedExercise]] = [:]
        for exercise in exercises {
            byWorkout[exercise.workout?.persistentModelID ?? exercise.persistentModelID, default: []].append(exercise)
        }
        let groups = byWorkout.values.map { group in
            (start: group.compactMap { $0.workout?.startedAt }.min() ?? .distantPast, exercises: group)
        }
        .sorted { $0.start < $1.start }

        var all: [LoggedSet] = []
        var sessions: [RecordSession] = []
        for group in groups {
            let sets = group.exercises.flatMap { exercise in
                (exercise.sets ?? []).filter { !$0.isDeleted && $0.isCompleted }.map { (exercise.order, $0) }
            }
            .sorted { lhs, rhs in
                let left = (lhs.1.completedAt ?? group.start, lhs.0, lhs.1.order)
                let right = (rhs.1.completedAt ?? group.start, rhs.0, rhs.1.order)
                return left < right
            }
            .map(\.1)
            var session: [RecordSet] = []
            for set in sets {
                session.append(set.recordSet(id: all.count))
                all.append(set)
            }
            sessions.append(RecordSession(sets: session))
        }
        return (sessions, all)
    }

    private func records(for exerciseID: String) throws -> [PersonalRecord] {
        try context.fetch(FetchDescriptor<PersonalRecord>(predicate: #Predicate { $0.exerciseID == exerciseID }))
    }

    private func volumeRecordWorkouts(for exerciseID: String) -> Set<PersistentIdentifier> {
        let records = (try? records(for: exerciseID)) ?? []
        return Set(
            records.filter { $0.kind == .sessionVolume }.compactMap { $0.set?.exercise?.workout?.persistentModelID })
    }
}

extension LoggedSet {
    /// This set as record detection sees it.
    public func recordSet(id: Int) -> RecordSet {
        RecordSet(
            id: id, weightKg: weightKg, reps: reps, seconds: seconds, meters: meters, isWarmUp: isWarmUp,
            isCompleted: isCompleted, isConfirmed: isRecordConfirmed)
    }
}

extension PersonalRecord {
    public convenience init(exerciseID: String, mark: RecordMark, date: Date, set: LoggedSet? = nil) {
        self.init(exerciseID: exerciseID, kind: mark.kind, value: mark.value, date: date, set: set)
        reps = mark.slot.reps
        meters = mark.slot.meters
    }

    /// The record as a value: its slot and value.
    public var mark: RecordMark {
        RecordMark(kind: kind, value: value, reps: reps, meters: meters)
    }
}
