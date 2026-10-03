/// One week of training as plain values, for "This week, distilled" (#16). The app fills it
/// from its stats. Every number arrives already formatted, units included, so the summary can
/// repeat it as written and never has to format or convert one.
public struct WeekSummaryInput: Equatable, Sendable {
    public var sessionsDone: Int
    public var sessionsPlanned: Int
    /// The week's total volume, e.g. "8,420 kg".
    public var volume: String?
    /// Volume against last week, in percent, e.g. 6 or -12.
    public var volumeChangePercent: Int?
    /// New records, e.g. "Back squat 5RM, 115 kg".
    public var records: [String]
    /// What improved, e.g. "Bench press est. max 92.5 → 95 kg".
    public var wentUp: [String]
    /// Names of exercises that stopped progressing.
    public var stalled: [String]
    public var streakWeeks: Int
    /// The person's goal in their own words. May be empty.
    public var goal: String

    public init(
        sessionsDone: Int, sessionsPlanned: Int, volume: String? = nil, volumeChangePercent: Int? = nil,
        records: [String] = [], wentUp: [String] = [], stalled: [String] = [], streakWeeks: Int = 0, goal: String = ""
    ) {
        self.sessionsDone = sessionsDone
        self.sessionsPlanned = sessionsPlanned
        self.volume = volume
        self.volumeChangePercent = volumeChangePercent
        self.records = records
        self.wentUp = wentUp
        self.stalled = stalled
        self.streakWeeks = streakWeeks
        self.goal = goal
    }

    /// Nothing was logged this week.
    public var isEmpty: Bool {
        sessionsDone <= 0 && volume == nil && records.isEmpty && wentUp.isEmpty
    }

    /// Whether to offer "Rework next week": something stalled, or under half the planned
    /// sessions were done. Always decided here by rule, never by the model.
    public var suggestsRework: Bool {
        !stalled.isEmpty || (sessionsPlanned > 0 && sessionsDone * 2 < sessionsPlanned)
    }
}

/// The weekly summary as shown: a headline and a few short sentences.
public struct WeekSummary: Equatable, Sendable {
    /// One short sentence.
    public var headline: String
    /// Two to four short, plain sentences.
    public var lines: [String]
    /// Whether to offer "Rework next week".
    public var suggestsRework: Bool
    /// True when the model wrote it, false for the template.
    public var isFromAI: Bool

    public init(headline: String, lines: [String], suggestsRework: Bool, isFromAI: Bool) {
        self.headline = headline
        self.lines = lines
        self.suggestsRework = suggestsRework
        self.isFromAI = isFromAI
    }
}
