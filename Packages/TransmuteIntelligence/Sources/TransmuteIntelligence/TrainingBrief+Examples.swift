import TransmuteCore

/// The people from the evaluation set in #8: a spread of goals, levels, kit and limitations
/// that every planning prompt is checked against.
extension TrainingBrief {
    /// The epic's example: 5′9″, 175 lb, intermediate tennis player, full gym, four days.
    public static let tennisPlayer = TrainingBrief(
        heightCm: 175.3, weightKg: 79.4, age: 34, sex: .male, experience: .intermediate,
        goal: "Improve overall performance on the court.",
        goalTags: [.sportPerformance, .power, .speed, .agility, .conditioning],
        sports: ["tennis, 4.0 NTRP, plays 3× a week"],
        schedule: Schedule(
            daysPerWeek: 4, preferredWeekdays: [1, 2, 4, 5], sessionMinutes: 60, weeks: 8,
            commitments: [
                Commitment(weekday: 3, label: "Practice", intensity: .moderate),
                Commitment(weekday: 6, label: "Match", intensity: .hard),
                Commitment(weekday: 7, label: "Practice", intensity: .light),
            ]),
        equipment: [
            .barbell, .dumbbell, .kettlebell, .bench, .rack, .pullUpBar, .medicineBall, .box, .cones, .band, .cable,
            .machine, .bike, .landmine, .plate,
        ])

    /// A beginner at home with dumbbells who wants to lose weight.
    public static let weightLossBeginner = TrainingBrief(
        heightCm: 165, weightKg: 92, age: 41, sex: .female, experience: .beginner,
        goal: "Lose 20 lb and feel stronger.", goalTags: [.weightLoss, .generalFitness],
        schedule: Schedule(daysPerWeek: 3, preferredWeekdays: [1, 3, 5], sessionMinutes: 45, weeks: 8),
        equipment: [.dumbbell])

    /// A runner adding strength around a running week.
    public static let runner = TrainingBrief(
        heightCm: 180, weightKg: 70, age: 29, experience: .intermediate,
        goal: "Run a faster half marathon and stop getting niggles.", goalTags: [.injuryResilience, .strength],
        sports: ["running, 35 km a week"],
        schedule: Schedule(
            daysPerWeek: 2, preferredWeekdays: [2, 5], sessionMinutes: 40, weeks: 6,
            commitments: [Commitment(weekday: 7, label: "Long run", intensity: .hard)]),
        equipment: [.dumbbell, .kettlebell, .band, .box, .bench])

    /// An experienced lifter chasing strength.
    public static let experiencedLifter = TrainingBrief(
        heightCm: 183, weightKg: 95, age: 32, sex: .male, experience: .advanced,
        goal: "Get stronger on squat, bench and deadlift.", goalTags: [.strength, .hypertrophy],
        schedule: Schedule(daysPerWeek: 4, preferredWeekdays: [1, 2, 4, 5], sessionMinutes: 75, weeks: 8),
        equipment: [.barbell, .dumbbell, .bench, .rack, .pullUpBar, .cable, .machine, .plate, .trapBar])

    /// Someone working around a sore knee.
    public static let kneeInjury = TrainingBrief(
        heightCm: 170, weightKg: 75, age: 45, sex: .female, experience: .intermediate,
        goal: "Stay fit and strong while my knee settles down.", goalTags: [.generalFitness, .strength],
        schedule: Schedule(daysPerWeek: 3, preferredWeekdays: [1, 3, 5], sessionMinutes: 45, weeks: 4),
        equipment: [.dumbbell, .cable, .machine, .bench, .band, .bike],
        limitations: "Left knee: no jumping, no deep squats or lunges, nothing that pounds the knee.")

    public static let evaluationSet: [(name: String, brief: TrainingBrief)] = [
        ("tennis player", .tennisPlayer), ("weight-loss beginner", .weightLossBeginner), ("runner", .runner),
        ("experienced lifter", .experiencedLifter), ("knee injury", .kneeInjury),
    ]
}
