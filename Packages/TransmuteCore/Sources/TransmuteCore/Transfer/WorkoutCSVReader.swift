import Foundation

/// Workouts read from another app's CSV, before they're matched to the library.
struct ImportedWorkouts {
    struct Workout {
        var title: String
        var startedAt: Date
        var endedAt: Date?
        var notes = ""
        var exercises: [Exercise] = []
    }

    struct Exercise {
        var name: String
        var notes = ""
        var sets: [LoggedSetValues] = []
    }

    struct LoggedSetValues {
        var weightKg: Double?
        var reps: Int?
        var seconds: Double?
        var meters: Double?
        var rpe: Double?
        var isWarmUp = false
        var notes = ""
    }

    var source: ImportSummary.Source
    var workouts: [Workout] = []
    var unreadableRows = 0

    /// Adds a set row. Rows of one workout share a start time and title; within it, a run of
    /// rows with the same exercise name is one exercise.
    mutating func add(_ set: LoggedSetValues, exercise: Exercise, workout: Workout) {
        let index =
            workouts.firstIndex { $0.startedAt == workout.startedAt && $0.title == workout.title }
            ?? {
                workouts.append(workout)
                return workouts.count - 1
            }()
        if workouts[index].exercises.last?.name != exercise.name {
            workouts[index].exercises.append(exercise)
        }
        workouts[index].exercises[workouts[index].exercises.count - 1].sets.append(set)
    }
}

/// Reads Strong and Hevy exports. Columns are found by name, so their order and any extra
/// columns don't matter.
///
/// Strong: `Date, Workout Name, Duration, Exercise Name, Set Order, Weight, Reps, Distance,
/// Seconds, Notes, Workout Notes, RPE`, with dates like "2026-09-14 18:05:00" and durations
/// like "1h 5m". Some versions add `Weight Unit` and `Distance Unit` columns or put the unit
/// in the header ("Weight (kg)"), and some separate with semicolons.
///
/// Hevy: `title, start_time, end_time, description, exercise_title, superset_id,
/// exercise_notes, set_index, set_type, weight_kg, reps, distance_km, duration_seconds, rpe`,
/// with `weight_lbs` and `distance_miles` for imperial accounts and dates like
/// "14 Sep 2026, 18:05".
struct WorkoutCSVReader {
    let table: CSVTable
    let fallbackUnits: UnitSystem
    let timeZone: TimeZone

    /// `nil` when the header row is neither app's.
    func read() -> ImportedWorkouts? {
        if table.has("exercise_title", "start_time", "set_index") { return readHevy() }
        if table.has("workout name", "exercise name", "set order", "date") { return readStrong() }
        return nil
    }

    // MARK: Strong

    private func readStrong() -> ImportedWorkouts {
        var file = ImportedWorkouts(source: .strong)
        let weight = table.column(measuring: "weight")
        let distance = table.column(measuring: "distance")
        let duration = table.column(measuring: "duration")
        for row in table.rows {
            let cell = { (names: String...) in CSVTable.text(row, names.lazy.compactMap { table.column($0) }.first) }
            let name = cell("exercise name")
            guard let start = date(cell("date")), !name.isEmpty else {
                file.unreadableRows += 1
                continue
            }
            // Strong lists rest timers and notes as rows of their own.
            let order = cell("set order").lowercased()
            if order.contains("rest") || order == "note" { continue }

            var workout = ImportedWorkouts.Workout(title: cell("workout name"), startedAt: start)
            workout.endedAt = Self.seconds(inDuration: CSVTable.text(row, duration?.index)).map(
                start.addingTimeInterval)
            workout.notes = cell("workout notes")
            var set = ImportedWorkouts.LoggedSetValues()
            set.weightKg = CSVTable.number(row, weight?.index).flatMap { value in
                Self.kilograms(value, unit: [cell("weight unit"), weight?.unit ?? ""], fallback: fallbackUnits)
            }
            set.meters = CSVTable.number(row, distance?.index).flatMap { value in
                Self.meters(value, unit: [cell("distance unit"), distance?.unit ?? ""], fallback: fallbackUnits)
            }
            set.reps = Self.positive(CSVTable.number(row, table.column("reps"))).map { Int($0.rounded()) }
            set.seconds = Self.positive(CSVTable.number(row, table.column("seconds")))
            set.rpe = Self.positive(CSVTable.number(row, table.column("rpe")))
            set.isWarmUp = order == "w" || order.hasPrefix("warm")
            set.notes = cell("notes")
            file.add(set, exercise: .init(name: name), workout: workout)
        }
        return file
    }

    // MARK: Hevy

    private func readHevy() -> ImportedWorkouts {
        var file = ImportedWorkouts(source: .hevy)
        let weight = table.column("weight_kg").map { ($0, "kg") } ?? table.column("weight_lbs").map { ($0, "lbs") }
        let distance =
            table.column("distance_km").map { ($0, "km") } ?? table.column("distance_miles").map { ($0, "mi") }
            ?? table.column("distance_meters").map { ($0, "m") }
        for row in table.rows {
            let cell = { (name: String) in CSVTable.text(row, table.column(name)) }
            let name = cell("exercise_title")
            guard let start = date(cell("start_time")), !name.isEmpty else {
                file.unreadableRows += 1
                continue
            }
            var workout = ImportedWorkouts.Workout(title: cell("title"), startedAt: start)
            workout.endedAt = date(cell("end_time"))
            workout.notes = cell("description")
            var set = ImportedWorkouts.LoggedSetValues()
            set.weightKg = CSVTable.number(row, weight?.0).flatMap {
                Self.kilograms($0, unit: [weight?.1 ?? ""], fallback: fallbackUnits)
            }
            set.meters = CSVTable.number(row, distance?.0).flatMap {
                Self.meters($0, unit: [distance?.1 ?? ""], fallback: fallbackUnits)
            }
            set.reps = Self.positive(CSVTable.number(row, table.column("reps"))).map { Int($0.rounded()) }
            set.seconds = Self.positive(CSVTable.number(row, table.column("duration_seconds")))
            set.rpe = Self.positive(CSVTable.number(row, table.column("rpe")))
            set.isWarmUp = cell("set_type").lowercased().hasPrefix("warm")
            file.add(set, exercise: .init(name: name, notes: cell("exercise_notes")), workout: workout)
        }
        return file
    }

    // MARK: Values

    /// Both apps write wall-clock times with no zone.
    private func date(_ text: String) -> Date? {
        if let date = try? Date(text, strategy: .iso8601) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "d MMM yyyy, HH:mm", "d MMM yyyy, HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// Both apps write 0 for a measure the set doesn't use.
    static func positive(_ value: Double?) -> Double? {
        value.flatMap { $0 > 0 ? $0 : nil }
    }

    /// The first unit named wins; with none, the fallback system's.
    static func kilograms(_ value: Double, unit: [String], fallback: UnitSystem) -> Double? {
        let unit = unit.first { !$0.isEmpty }?.lowercased()
        let isPounds = unit.map { $0.hasPrefix("lb") || $0.hasPrefix("pound") } ?? (fallback == .imperial)
        return positive(isPounds ? value / Units.poundsPerKilogram : value)
    }

    /// With no unit named, kilometres or miles by the fallback system.
    static func meters(_ value: Double, unit: [String], fallback: UnitSystem) -> Double? {
        let factor: Double
        switch unit.first(where: { !$0.isEmpty })?.lowercased() {
        case "m", "meters", "metres": factor = 1
        case "km", "kilometers", "kilometres": factor = 1_000
        case "mi", "mile", "miles": factor = Units.metresPerMile
        case "ft", "feet": factor = 0.304_8
        case "yd", "yards": factor = 0.914_4
        default: factor = fallback == .metric ? 1_000 : Units.metresPerMile
        }
        return positive(value * factor)
    }

    /// "1h 5m", "45m" and "30s" as Strong writes them, or a bare number of seconds.
    static func seconds(inDuration text: String) -> Double? {
        if let seconds = Double(text) { return positive(seconds) }
        var total = 0.0
        for part in text.lowercased().split(separator: " ") {
            guard let value = Double(part.dropLast()), let unit = part.last else { return nil }
            switch unit {
            case "h": total += value * 3_600
            case "m": total += value * 60
            case "s": total += value
            default: return nil
            }
        }
        return positive(total)
    }
}
