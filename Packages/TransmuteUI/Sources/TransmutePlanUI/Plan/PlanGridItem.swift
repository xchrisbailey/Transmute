import CoreTransferable
import Foundation
import TransmuteCore
import UniformTypeIdentifiers

/// What a drag in the plan grid carries: where the day or exercise sits, never the models.
struct PlanGridItem: Codable, Hashable, Transferable {
    var plan: UUID
    var week: Int
    var weekday: Weekday
    /// The exercise's `order` in its day; nil when the whole day is being dragged.
    var exercise: Int?

    init(day: PlanDay, in plan: Plan, exercise: PlannedExercise? = nil) {
        self.plan = plan.id
        week = day.week
        weekday = day.weekday
        self.exercise = exercise?.order
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }

    /// Applies a drop on a weekday of a week, and says whether anything could move.
    ///
    /// A day moves within its own week, swapping with a session already there. An exercise
    /// moves to a day that has a session: to the place of the row it landed on, or last when
    /// it landed on the card.
    func drop(in plan: Plan, week: Int, weekday: Weekday, onto row: PlannedExercise? = nil) -> Bool {
        guard self.plan == plan.id,
            let source = PlanEditor.day(of: plan, week: self.week, weekday: self.weekday)
        else { return false }
        guard let exercise else {
            guard week == self.week, weekday != self.weekday else { return false }
            PlanEditor.move(source, to: weekday)
            return true
        }
        guard let target = PlanEditor.day(of: plan, week: week, weekday: weekday),
            let moving = source.orderedExercises.first(where: { $0.order == exercise }), moving !== row
        else { return false }
        let index = row.flatMap { row in target.orderedExercises.firstIndex { $0 === row } }
        PlanEditor.move(moving, to: target, at: index)
        return true
    }
}
