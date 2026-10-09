import TransmuteCore

/// What a set row reads from its model: whether the set holds a record, and which warm-up it is.
extension LoggedSet {
    /// The records this set set. They stay when a later set beats them and go when an edit
    /// means the set was never a record, because `RecordBook` deletes their rows then.
    var recordMarks: [RecordMark] {
        (records ?? [])
            .sorted { ($0.kindRaw, $0.value) < ($1.kindRaw, $1.value) }
            .map(\.mark)
    }

    /// The rule History marks gold by: the set has rows in `records`.
    var holdsRecord: Bool {
        !(records ?? []).isEmpty
    }

    /// Which warm-up this is in its exercise, from 1, or nil for a working set.
    var warmUpNumber: Int? {
        guard isWarmUp, let sets = exercise?.orderedSets.filter(\.isWarmUp),
            let index = sets.firstIndex(where: { $0 === self })
        else { return nil }
        return index + 1
    }
}
