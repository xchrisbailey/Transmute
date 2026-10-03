import Foundation

/// The JSON backup: everything in the store, as plain values (#18).
///
/// ```
/// {
///   "formatVersion": 1,
///   "exportedAt": "2026-10-03T09:30:00Z",
///   "appVersion": "1.0",
///   "profile": { …, "bodyweights": [ … ] },
///   "customExercises": [ … ],
///   "plans": [ { "id": …, "days": [ { "exercises": [ { "sets": [ … ] } ] } ] } ],
///   "workouts": [ { "id": …, "planDay": { "plan": …, "day": 0 }, "exercises": [ { "sets": [ … ] } ] } ],
///   "records": [ { …, "set": { "workout": …, "exercise": 1, "set": 0 } } ]
/// }
/// ```
///
/// Dates are ISO 8601 in UTC, to the millisecond. Quantities are metric, as stored. Vocabulary
/// values (experience, equipment, record kind…) are the raw strings the models store, so a
/// backup from a newer catalog still reads. Children are nested under their parent in order;
/// the two relationships that cross the tree are written as references: a workout's plan day
/// (`PlanDayRef`) and a record's set (`SetRef`).
///
/// These types are the format. Changing a key's name or meaning needs a new `formatVersion`;
/// adding an optional key doesn't, because missing keys decode as `nil`.
struct Backup: Codable, Equatable {
    /// The version this build writes, and the newest it reads.
    static let currentFormatVersion = 1

    var formatVersion = Backup.currentFormatVersion
    var exportedAt: Date
    /// The app's marketing version, when the exporter knows it.
    var appVersion: String?
    var profile: ProfileBackup?
    var customExercises: [CustomExerciseBackup] = []
    var plans: [PlanBackup] = []
    var workouts: [WorkoutBackup] = []
    var records: [RecordBackup] = []

    init(exportedAt: Date, appVersion: String?) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        profile = try container.decodeIfPresent(ProfileBackup.self, forKey: .profile)
        customExercises = try container.decodeIfPresent([CustomExerciseBackup].self, forKey: .customExercises) ?? []
        plans = try container.decodeIfPresent([PlanBackup].self, forKey: .plans) ?? []
        workouts = try container.decodeIfPresent([WorkoutBackup].self, forKey: .workouts) ?? []
        records = try container.decodeIfPresent([RecordBackup].self, forKey: .records) ?? []
    }

    /// A plan day, by its place in the plan's `days` in this backup.
    struct PlanDayRef: Codable, Equatable {
        var plan: UUID
        var day: Int
    }

    /// A logged set, by its place in the workout's `exercises` and that exercise's `sets`.
    struct SetRef: Codable, Equatable {
        var workout: UUID
        var exercise: Int
        var set: Int
    }
}

// MARK: - Reading and writing

extension Backup {
    /// Only the version, so a newer backup is turned away before its unknown shape fails to decode.
    private struct Header: Decodable {
        var formatVersion: Int
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(BackupDate.string(from: date))
        }
        return try encoder.encode(self)
    }

    init(data: Data) throws {
        guard !data.isEmpty else { throw DataTransferError.emptyFile }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = BackupDate.date(from: text) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "\(text) isn't an ISO 8601 date"))
            }
            return date
        }
        do {
            let version = try decoder.decode(Header.self, from: data).formatVersion
            guard version <= Backup.currentFormatVersion else {
                throw DataTransferError.newerBackup(formatVersion: version, supported: Backup.currentFormatVersion)
            }
            self = try decoder.decode(Backup.self, from: data)
        } catch let error as DecodingError {
            throw DataTransferError.unreadableBackup(detail: String(describing: error))
        }
    }
}

/// ISO 8601 in UTC, with milliseconds only when there are any: "2026-10-03T09:30:00Z",
/// "2026-10-03T09:30:00.250Z". Rounds to the millisecond, so writing a date that was read
/// gives the same text back.
enum BackupDate {
    static func string(from date: Date) -> String {
        let milliseconds = (date.timeIntervalSince1970 * 1_000).rounded()
        let seconds = (milliseconds / 1_000).rounded(.down)
        let fraction = Int(milliseconds - seconds * 1_000)
        let whole = Date(timeIntervalSince1970: seconds).formatted(.iso8601)
        return fraction == 0 ? whole : whole.dropLast() + String(format: ".%03dZ", fraction)
    }

    static func date(from text: String) -> Date? {
        (try? Date(text, strategy: .iso8601))
            ?? (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
    }
}
