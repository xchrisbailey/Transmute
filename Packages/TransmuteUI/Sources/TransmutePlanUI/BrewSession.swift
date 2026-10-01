import Foundation
import Observation
import SwiftData
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// One brew, from tapping Brew to keeping the plan. Holds what the screen shows while the plan
/// distils, and only saves when the person keeps it.
@MainActor @Observable
public final class BrewSession {
    public enum State: Equatable {
        case idle
        case brewing
        case preview(BrewedPlan)
        case failed(IntelligenceError)
    }

    /// A finished day as the progress list shows it.
    public struct DistilledDay: Equatable, Identifiable {
        public let id: Int
        public let phase: String
        public let focus: String
        public let exercises: [String]
    }

    public private(set) var state = State.idle
    /// The line under the progress: sketching, or the day being distilled.
    public private(set) var status: LocalizedStringResource?
    public private(set) var planName: String?
    public private(set) var rationale: String?
    public private(set) var phases: [PlanPhase] = []
    public private(set) var distilled: [DistilledDay] = []
    /// Exercises of the day being written, as they stream in.
    public private(set) var current: [String] = []

    let brewer: PlanBrewer
    private var task: Task<Void, Never>?

    public init(brewer: PlanBrewer) {
        self.brewer = brewer
    }

    public var isBrewing: Bool {
        state == .brewing
    }

    public func start(_ brief: TrainingBrief, units: UnitSystem) {
        task?.cancel()
        reset()
        state = .brewing
        task = Task {
            do {
                for try await progress in brewer.brew(brief, units: units) {
                    apply(progress)
                }
            } catch is CancellationError {
                state = .idle
            } catch let error as IntelligenceError {
                state = .failed(error)
            } catch {
                state = .failed(.failed(detail: "\(error)"))
            }
            status = nil
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        reset()
    }

    /// Saves the previewed plan as the active one.
    @discardableResult
    public func keep(in context: ModelContext, startDate: Date = .now, device: String) throws -> Plan? {
        guard case .preview(let plan) = state else { return nil }
        let saved = try plan.insert(
            into: context, startDate: Self.startOfWeek(startDate),
            brewedBy: "\(brewer.service.providerName) on \(device)")
        reset()
        return saved
    }

    /// Plans start on the Monday of this week, so week one lines up with the calendar.
    static func startOfWeek(_ date: Date) -> Date {
        Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    func apply(_ progress: PlanBrewer.Progress) {
        switch progress {
        case .outlining:
            status = BrewCopy.outlining
        case .outlined(let name, let rationale, let phases):
            planName = name
            self.rationale = rationale
            self.phases = phases
        case .distilling(let phase, let focus, let exercises):
            status = phase.firstWeek == 1 ? BrewCopy.distillingDay(focus) : Copy.distilling(week: phase.firstWeek)
            current = exercises
        case .distilled(let phase, let focus, let exercises):
            distilled.append(DistilledDay(id: distilled.count, phase: phase.name, focus: focus, exercises: exercises))
            current = []
        case .finished(let plan):
            state = .preview(plan)
        }
    }

    private func reset() {
        state = .idle
        status = nil
        planName = nil
        rationale = nil
        phases = []
        distilled = []
        current = []
    }
}
