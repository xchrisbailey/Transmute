import Foundation
import SwiftData

/// Merges a backup into a store. See `DataTransfer.importBackup` for the rules.
struct BackupRestore {
    let backup: Backup
    let context: ModelContext
    private var summary = ImportSummary(source: .backup)
    /// Days of the backup's plans by plan id, in the backup's order, for `PlanDayRef`.
    private var days: [UUID: [PlanDay]] = [:]
    /// Sets of the workouts this restore added, for `SetRef`.
    private var sets: [UUID: [[LoggedSet]]] = [:]

    init(backup: Backup, context: ModelContext) {
        self.backup = backup
        self.context = context
    }

    mutating func run() throws -> ImportSummary {
        let hadHistory =
            try context.fetchCount(FetchDescriptor<Workout>()) > 0
            || context.fetchCount(FetchDescriptor<PersonalRecord>()) > 0
        try restoreProfile()
        try restoreCustomExercises()
        try restorePlans()
        try restoreWorkouts()
        try restoreRecords(asWritten: !hadHistory)
        try context.save()
        return summary
    }

    private mutating func restoreProfile() throws {
        guard let saved = backup.profile else { return }
        let profile: Profile
        if let existing = try context.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])).first {
            profile = existing
            summary.profile = .kept
        } else {
            profile = Profile()
            saved.apply(to: profile)
            context.insert(profile)
            summary.profile = .added
        }
        var known = (profile.bodyweights ?? []).map(BodyweightBackup.init)
        for entry in saved.bodyweights ?? [] {
            if known.contains(where: entry.matches) {
                summary.bodyweights.skipped += 1
            } else {
                profile.bodyweights?.append(entry.model())
                known.append(entry)
                summary.bodyweights.added += 1
            }
        }
    }

    private mutating func restoreCustomExercises() throws {
        var known = Set(try context.fetch(FetchDescriptor<CustomExercise>()).map(\.exerciseID))
        for saved in backup.customExercises {
            if known.insert(saved.exerciseID).inserted {
                context.insert(saved.model())
                summary.customExercises.added += 1
            } else {
                summary.customExercises.skipped += 1
            }
        }
    }

    private mutating func restorePlans() throws {
        let existing = try context.fetch(FetchDescriptor<Plan>())
        var known = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var hasActive = existing.contains(where: \.isActive)
        for saved in backup.plans {
            if let plan = known[saved.id] {
                days[saved.id] = Self.matchingDays(of: plan, to: saved)
                summary.plans.skipped += 1
                continue
            }
            let (plan, planDays) = saved.model()
            // Only one plan is active at a time, and the one already here wins.
            if hasActive { plan.isActive = false }
            hasActive = hasActive || plan.isActive
            context.insert(plan)
            known[saved.id] = plan
            days[saved.id] = planDays
            summary.plans.added += 1
        }
    }

    /// The days of a plan that was already in the store, lined up with the backup's. Empty when
    /// the plan has been edited since, so workouts don't attach to the wrong day.
    private static func matchingDays(of plan: Plan, to saved: PlanBackup) -> [PlanDay] {
        let current = plan.backupDays
        let same =
            current.count == saved.days.count
            && zip(current, saved.days).allSatisfy { $0.week == $1.week && $0.weekday == $1.weekday }
        return same ? current : []
    }

    private mutating func restoreWorkouts() throws {
        var known = Set(try context.fetch(FetchDescriptor<Workout>()).map(\.id))
        for saved in backup.workouts {
            guard known.insert(saved.id).inserted else {
                summary.workouts.skipped += 1
                continue
            }
            let planDay = saved.planDay.flatMap { ref in
                days[ref.plan].flatMap { $0.indices.contains(ref.day) ? $0[ref.day] : nil }
            }
            let (workout, workoutSets) = saved.model(planDay: planDay)
            context.insert(workout)
            sets[saved.id] = workoutSets
            summary.workouts.added += 1
            summary.setsAdded += workoutSets.joined().count
        }
    }

    /// Into an empty history the backup's records go back exactly as they were. Into an existing
    /// one they're derived again, since records depend on every set of an exercise.
    private mutating func restoreRecords(asWritten: Bool) throws {
        let before = try context.fetchCount(FetchDescriptor<PersonalRecord>())
        if asWritten {
            for saved in backup.records {
                context.insert(saved.model(set: saved.set.flatMap(set(for:))))
            }
        } else if summary.workouts.added > 0 {
            let library = try ExerciseLibrary.bundled.addingCustomExercises(in: context)
            try RecordBook(context: context, library: library).recomputeAll()
        }
        summary.recordsAdded = max(0, try context.fetchCount(FetchDescriptor<PersonalRecord>()) - before)
    }

    private func set(for ref: Backup.SetRef) -> LoggedSet? {
        guard let exercises = sets[ref.workout], exercises.indices.contains(ref.exercise),
            exercises[ref.exercise].indices.contains(ref.set)
        else { return nil }
        return exercises[ref.exercise][ref.set]
    }
}
