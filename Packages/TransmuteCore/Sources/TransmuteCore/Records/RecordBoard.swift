import Foundation
import SwiftData

/// Arranges stored records for display: the current bests per exercise, and the records set
/// since a date grouped by the set that set them.
public enum RecordBoard {
    /// The best row in each slot for each exercise, in table order: estimated 1RM, rep maxes
    /// from 1RM up, max reps, best times by distance, longest distance and time, session volume.
    public static func bests(_ records: [PersonalRecord]) -> [String: [PersonalRecord]] {
        var best: [String: [RecordSlot: PersonalRecord]] = [:]
        for record in records {
            let mark = record.mark
            if let current = best[record.exerciseID]?[mark.slot] {
                let isBetter = mark.beats(current.value) || (mark.value == current.value && record.date > current.date)
                guard isBetter else { continue }
            }
            best[record.exerciseID, default: [:]][mark.slot] = record
        }
        return best.mapValues { slots in
            slots.values.sorted { $0.mark.tableOrder.lexicographicallyPrecedes($1.mark.tableOrder) }
        }
    }

    /// Records set on or after `date`, one group per set with its headline first, newest set
    /// first. Feeds "Turned to gold this block" and a session summary.
    public static func gold(_ records: [PersonalRecord], since date: Date) -> [[PersonalRecord]] {
        var groups: [PersistentIdentifier: [PersonalRecord]] = [:]
        for record in records where record.date >= date {
            let key = record.set?.persistentModelID ?? record.persistentModelID
            groups[key, default: []].append(record)
        }
        return groups.values
            .map { group in
                let order = RecordDetector.headlineFirst(group.map(\.mark))
                return group.sorted { order.firstIndex(of: $0.mark) ?? 0 < order.firstIndex(of: $1.mark) ?? 0 }
            }
            .sorted { ($0.first?.date ?? .distantPast) > ($1.first?.date ?? .distantPast) }
    }
}

extension RecordMark {
    /// Where the mark sits in an exercise's records table.
    var tableOrder: [Double] {
        let kind: Double =
            switch slot.kind {
            case .estimatedOneRepMax: 0
            case .repMax: 1
            case .maxReps: 2
            case .bestTime: 3
            case .longestDistance: 4
            case .longestTime: 5
            case .sessionVolume: 6
            }
        return [kind, Double(slot.reps ?? 0), slot.meters ?? 0]
    }
}
