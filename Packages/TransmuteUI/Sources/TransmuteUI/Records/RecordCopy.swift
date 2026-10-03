import Foundation

/// Strings for records (#13). Labels and values stay plain; the gold headings use the voice.
enum RecordCopy {
    static let estimatedOneRepMax = LocalizedStringResource(
        "plain.records.estimatedOneRepMax", defaultValue: "Est. 1RM", bundle: .main,
        comment: "plain. Record label: estimated one-rep max.")

    static func repMax(reps: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.records.repMax", defaultValue: "\(reps)RM", bundle: .main,
            comment: "plain. Record label: heaviest load for this many reps, e.g. 5RM.")
    }

    static let maxReps = LocalizedStringResource(
        "plain.records.maxReps", defaultValue: "Max reps", bundle: .main,
        comment: "plain. Record label: most reps in one set.")

    static func bestTime(distance: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.records.bestTime", defaultValue: "Best \(distance)", bundle: .main,
            comment: "plain. Record label: fastest time over a distance, e.g. Best 20 m.")
    }

    static let longestTime = LocalizedStringResource(
        "plain.records.longestTime", defaultValue: "Longest time", bundle: .main,
        comment: "plain. Record label: longest hold or effort.")

    static let longestDistance = LocalizedStringResource(
        "plain.records.longestDistance", defaultValue: "Longest distance", bundle: .main,
        comment: "plain. Record label: furthest distance in one set.")

    static let sessionVolume = LocalizedStringResource(
        "plain.records.sessionVolume", defaultValue: "Session volume", bundle: .main,
        comment: "plain. Record label: most load × reps for one exercise in one session.")

    static func reps(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.records.reps", defaultValue: "\(count) reps", bundle: .main,
            comment: "plain. A max reps record's value. Always two or more, since a record beats a best.")
    }

    static let title = LocalizedStringResource(
        "plain.records.title", defaultValue: "Records", bundle: .main, comment: "plain. Records screen title.")

    static func also(_ labels: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.records.also", defaultValue: "Also \(labels)", bundle: .main,
            comment: "plain. Other records the same set set, e.g. Also 3RM and Est. 1RM.")
    }

    static let goldThisBlock = LocalizedStringResource(
        "voice.records.goldThisBlock", defaultValue: "Turned to gold this block", bundle: .main,
        comment: "voice. Heading for records set since the plan started.")

    static let noGoldThisBlock = LocalizedStringResource(
        "voice.records.noGoldThisBlock", defaultValue: "Nothing's turned to gold this block yet.", bundle: .main,
        comment: "voice. No records since the plan started.")

    static let empty = LocalizedStringResource(
        "voice.records.empty", defaultValue: "Nothing's turned to gold yet. Beat a best and it will.", bundle: .main,
        comment: "voice. No records at all. The first session of an exercise sets the bests to beat.")
}
