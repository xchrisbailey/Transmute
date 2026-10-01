import Foundation

/// What Transmute reads from and writes to Health. The app works with no access at all: every
/// read returns `nil` or empty when Health is missing or the person said no.
///
/// `HealthKitService` implements this on iPhone and Apple Watch. The Mac has no Health store,
/// so it uses `UnavailableHealthService`, as do tests and previews.
public protocol HealthService: Sendable {
    /// Whether this device has a Health store at all. False on the Mac.
    var isAvailable: Bool { get }

    /// Asks for what one feature needs, the first time it needs it. Health doesn't say what was
    /// denied, so callers just read and handle missing values.
    func requestAccess(_ scope: HealthAccessScope) async throws

    /// Height, weight, birth year and sex, for prefilling the profile (#6).
    func bodyMetrics() async -> HealthBodyMetrics

    /// Bodyweight samples since a date, newest last.
    func bodyweights(since date: Date) async -> [HealthBodyweight]

    /// Recent resting heart rate in beats per minute, as optional context for plans.
    func restingHeartRate() async -> Double?

    /// Latest VO2 max in mL/kg/min, as optional context for plans.
    func vo2Max() async -> Double?

    /// Workouts other apps recorded, such as tennis from the Workout app, so the plan knows how
    /// hard the week was. Transmute's own workouts are left out, so nothing counts twice.
    func otherWorkouts(in interval: DateInterval) async -> [OtherWorkout]

    /// Saves a finished Transmute workout and returns the Health workout's id.
    func save(_ workout: HealthWorkoutRecord) async throws -> UUID

    /// Saves a bodyweight entered in Transmute and returns the sample's id.
    func saveBodyweight(kg: Double, at date: Date) async throws -> UUID

    /// Deletes a workout Transmute saved, when the person deletes it from their log (#14).
    /// Workouts other apps wrote are never touched; a workout that's already gone is fine.
    func deleteWorkout(id: UUID) async throws
}

/// The groups of data a feature asks for together, so prompts come one feature at a time.
public enum HealthAccessScope: Sendable, CaseIterable {
    /// Read height, bodyweight, birth date and sex; write bodyweight. For the profile.
    case profile
    /// Read other apps' workouts, resting heart rate and VO2 max. For planning around the week.
    case trainingLoad
    /// Write workouts with energy and heart rate. For finishing a session.
    case workouts
}

public struct HealthBodyMetrics: Equatable, Sendable {
    public var heightCm: Double?
    public var weightKg: Double?
    public var birthYear: Int?
    public var sex: Sex?

    public init(heightCm: Double? = nil, weightKg: Double? = nil, birthYear: Int? = nil, sex: Sex? = nil) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.birthYear = birthYear
        self.sex = sex
    }

    public var isEmpty: Bool {
        self == HealthBodyMetrics()
    }
}

public struct HealthBodyweight: Equatable, Sendable {
    /// The Health sample's id, stored on the entry so it's never imported twice.
    public var id: UUID
    public var date: Date
    public var kg: Double
    /// True when Transmute wrote it, so it already exists as an entry.
    public var isFromTransmute: Bool

    public init(id: UUID, date: Date, kg: Double, isFromTransmute: Bool = false) {
        self.id = id
        self.date = date
        self.kg = kg
        self.isFromTransmute = isFromTransmute
    }
}

/// A workout another app recorded. Read-only context, never logged in Transmute.
public struct OtherWorkout: Equatable, Sendable, Identifiable {
    public var id: UUID
    /// The activity's name in English, e.g. "tennis" or "running".
    public var activity: String
    public var start: Date
    public var end: Date
    public var energyKcal: Double?
    public var averageHeartRate: Double?

    public init(
        id: UUID, activity: String, start: Date, end: Date, energyKcal: Double? = nil,
        averageHeartRate: Double? = nil
    ) {
        self.id = id
        self.activity = activity
        self.start = start
        self.end = end
        self.energyKcal = energyKcal
        self.averageHeartRate = averageHeartRate
    }

    public var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
}

/// Stands in for Health where there isn't one: the Mac, tests and previews.
public struct UnavailableHealthService: HealthService {
    public init() {}

    public var isAvailable: Bool { false }
    public func requestAccess(_ scope: HealthAccessScope) async throws {}
    public func bodyMetrics() async -> HealthBodyMetrics { HealthBodyMetrics() }
    public func bodyweights(since date: Date) async -> [HealthBodyweight] { [] }
    public func restingHeartRate() async -> Double? { nil }
    public func vo2Max() async -> Double? { nil }
    public func otherWorkouts(in interval: DateInterval) async -> [OtherWorkout] { [] }

    public func save(_ workout: HealthWorkoutRecord) async throws -> UUID {
        throw HealthServiceError.unavailable
    }

    public func saveBodyweight(kg: Double, at date: Date) async throws -> UUID {
        throw HealthServiceError.unavailable
    }

    public func deleteWorkout(id: UUID) async throws {
        throw HealthServiceError.unavailable
    }
}

public enum HealthServiceError: Error, Equatable, Sendable {
    /// No Health store on this device.
    case unavailable
    /// Health refused the save, usually because write access was denied.
    case notAuthorized
}
