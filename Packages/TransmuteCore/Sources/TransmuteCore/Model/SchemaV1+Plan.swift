import Foundation
import SwiftData

extension SchemaV1 {

    @Model public final class Plan {
        public var id = UUID()
        public var createdAt = Date.now
        public var name = ""
        public var goalSummary = ""
        /// One sentence: "Why this plan".
        public var rationale = ""
        public var startDate = Date.now
        public var weekCount = 4
        /// Only one plan is active at a time; older plans stay for history.
        public var isActive = true
        /// Where it was brewed, e.g. "Apple Intelligence on iPhone".
        public var brewedBy: String?
        /// The plan's phases in order, for the phase bar.
        public var phases: [PlanPhase] = []

        @Relationship(deleteRule: .cascade, inverse: \PlanDay.plan)
        public var days: [PlanDay]? = []

        public init(name: String, goalSummary: String = "", startDate: Date = .now, weekCount: Int = 4) {
            self.name = name
            self.goalSummary = goalSummary
            self.startDate = startDate
            self.weekCount = weekCount
        }

        /// The phase a week falls in.
        public func phase(forWeek week: Int) -> PlanPhase? {
            phases.first { $0.weeks.contains(week) }
        }

        /// Days in week order, then by weekday.
        public var orderedDays: [PlanDay] {
            (days ?? []).sorted { ($0.week, $0.weekday) < ($1.week, $1.weekday) }
        }
    }

    @Model public final class PlanDay {
        /// 1-based week of the plan.
        public var week = 1
        public var weekday: Weekday = 1
        /// Short name, e.g. "Lower A" or "Speed and agility".
        public var focus = ""
        public var notes = ""
        /// Set when the person changes the day by hand, so a rebrew leaves it alone (#10).
        public var isEdited = false
        public var plan: Plan?

        @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.day)
        public var exercises: [PlannedExercise]? = []

        @Relationship(deleteRule: .nullify, inverse: \Workout.planDay)
        public var workouts: [Workout]? = []

        public init(week: Int, weekday: Weekday, focus: String, notes: String = "") {
            self.week = week
            self.weekday = weekday
            self.focus = focus
            self.notes = notes
        }

        public var orderedExercises: [PlannedExercise] {
            (exercises ?? []).sorted { $0.order < $1.order }
        }
    }

    @Model public final class PlannedExercise {
        public var exerciseID = ""
        public var order = 0
        /// Exercises sharing a group number are done as a superset.
        public var supersetGroup: Int?
        public var notes = ""
        public var day: PlanDay?

        @Relationship(deleteRule: .cascade, inverse: \PlannedSet.exercise)
        public var sets: [PlannedSet]? = []

        public init(exerciseID: String, order: Int, supersetGroup: Int? = nil, notes: String = "") {
            self.exerciseID = exerciseID
            self.order = order
            self.supersetGroup = supersetGroup
            self.notes = notes
        }

        public var orderedSets: [PlannedSet] {
            (sets ?? []).sorted { $0.order < $1.order }
        }
    }

    /// A target. Which fields are set depends on the exercise's tracking type.
    @Model public final class PlannedSet {
        public var order = 0
        public var targetReps: Int?
        /// Upper end of a rep range, e.g. 8 in "6–8".
        public var targetRepsMax: Int?
        public var targetSeconds: Double?
        public var targetMeters: Double?
        public var targetLoadKg: Double?
        /// 0–1, e.g. 0.75 for 75% of 1RM.
        public var targetPercentOneRepMax: Double?
        public var targetRPE: Double?
        public var restSeconds: Double?
        /// For intervals: rounds of `targetSeconds` work and `intervalRestSeconds` rest.
        public var rounds: Int?
        public var intervalRestSeconds: Double?
        public var isWarmUp = false
        public var exercise: PlannedExercise?

        public init(order: Int) {
            self.order = order
        }
    }
}
