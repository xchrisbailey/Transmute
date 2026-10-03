import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmutePlanUI
import TransmuteUI

/// The screen people open most (#11): today's session with its targets and one mauve
/// button, Begin the work. Rest days say so and point at the next session. A workout left
/// running, even by a killed app, opens straight back up.
public struct TodayView: View {
    let plan: Plan?
    let profile: Profile

    @Environment(\.modelContext) private var context
    @Environment(\.sessionLink) private var link
    @Environment(\.health) private var health
    @Environment(\.effortDisplay) private var effort
    @State private var showsMirrored = false
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }, sort: \Workout.startedAt, order: .reverse)
    private var running: [Workout]
    @State private var session: Workout?
    @State private var didResume = false
    /// Set to true from outside to begin a workout, as the Mac's New Workout command and a
    /// widget's button do.
    @Binding var beginsWorkout: Bool
    let library = ExerciseLibrary.bundled

    public init(plan: Plan?, profile: Profile, beginsWorkout: Binding<Bool> = .constant(false)) {
        self.plan = plan
        self.profile = profile
        _beginsWorkout = beginsWorkout
    }

    /// A workout is already going, here or on the watch.
    private var isBusy: Bool {
        !running.isEmpty || link?.mirrored?.isFinished == false
    }

    private var units: Units {
        Units(profile)
    }

    public var body: some View {
        List {
            if let link, let mirrored = link.mirrored, !mirrored.isFinished {
                Section {
                    Button {
                        showsMirrored = true
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(LogCopy.onWatch)
                                    .brandFont(.exerciseTitle)
                                Text(verbatim: mirrored.title)
                                    .brandFont(.label)
                                    .foregroundStyle(Color.brandText(\.subtext))
                            }
                        } icon: {
                            Image(systemName: "applewatch")
                                .foregroundStyle(Color.brand(\.now))
                        }
                        .frame(minHeight: 44)
                    }
                }
            } else if let workout = running.first {
                Section {
                    Button {
                        open(workout)
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(LogCopy.resume)
                                    .brandFont(.exerciseTitle)
                                Text(verbatim: workout.title)
                                    .brandFont(.label)
                                    .foregroundStyle(Color.brandText(\.subtext))
                            }
                        } icon: {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(Color.brand(\.now))
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            if let plan {
                planned(TodayPlan(plan: plan), in: plan)
            }
            Section {
                Button {
                    begin(nil)
                } label: {
                    Label {
                        Text(LogCopy.logWorkout)
                    } icon: {
                        Image(systemName: "plus")
                    }
                    .frame(minHeight: 44)
                }
                .disabled(isBusy)
                NavigationLink {
                    RecordsView(since: plan?.startDate, units: units)
                } label: {
                    Label {
                        Text(LogCopy.records)
                    } icon: {
                        Image(systemName: "medal")
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationTitle(Text(LogCopy.today))
        .onAppear {
            // A workout still running at launch was cut off; pick it straight back up.
            // One the watch is running stays the watch's: it shows up through the link.
            if !didResume, let workout = running.first, workout.startedOn != .watch {
                didResume = true
                open(workout)
            }
        }
        .onChange(of: link?.mirrored == nil) { _, isGone in
            if isGone { showsMirrored = false }
        }
        .onChange(of: beginsWorkout, initial: true) { _, isWanted in
            guard isWanted else { return }
            beginsWorkout = false
            beginNext()
        }
        #if os(iOS)
            .fullScreenCover(item: $session) { workout in
                SessionView(workout: workout, profile: profile) { session = nil }
            }
            .fullScreenCover(isPresented: $showsMirrored) {
                if let link {
                    MirroredSessionView(link: link, units: units) { showsMirrored = false }
                }
            }
        #else
            .sheet(item: $session) { workout in
                SessionView(workout: workout, profile: profile) { session = nil }
                .frame(minWidth: 480, minHeight: 640)
            }
        #endif
    }

    @ViewBuilder private func planned(_ today: TodayPlan, in plan: Plan) -> some View {
        if let day = today.day {
            Section {
                header(day, in: plan)
                if today.isDone {
                    Text(LogCopy.doneToday)
                        .brandFont(.body)
                        .foregroundStyle(Color.brandText(\.done))
                }
            }
            if !today.isDone {
                reasonSection(day)
            }
            Section {
                ForEach(day.orderedExercises) { planned in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: library.exercise(id: planned.exerciseID)?.name ?? planned.exerciseID)
                            .brandFont(.exerciseTitle)
                            .foregroundStyle(Color.brand(\.ink))
                        Text(verbatim: SetTargets(planned.orderedSets).summary(units: units, showing: effort))
                            .brandNumberFont(size: 15)
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if !today.isDone {
                Section {
                    Button {
                        begin(day)
                    } label: {
                        Text(Copy.beginWork)
                            .brandFont(.exerciseTitle)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand(\.magic))
                    .disabled(isBusy)
                    .listRowBackground(Color.clear)
                }
            } else if let next = today.next {
                Section {
                    nextLine(next, in: plan)
                }
            }
        } else {
            restDay(today, in: plan)
        }
    }
}

extension TodayView {
    private func restDay(_ today: TodayPlan, in plan: Plan) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(BrewCopy.week(today.week))
                    .brandFont(.label)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.brandText(\.subtext))
                Text(LogCopy.restDay)
                    .brandFont(.largeTitle)
                    .foregroundStyle(Color.brand(\.ink))
                    .accessibilityAddTraits(.isHeader)
                Text(LogCopy.restDayBody)
                    .brandFont(.body)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            if let next = today.next {
                nextLine(next, in: plan)
            } else {
                Text(LogCopy.planEnded)
                    .brandFont(.body)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }
    }

    private func header(_ day: PlanDay, in plan: Plan) -> some View {
        let dayNumber = (plan.orderedDays.filter { $0.week == day.week }.firstIndex { $0 === day } ?? 0) + 1
        return VStack(alignment: .leading, spacing: 6) {
            Text(LogCopy.eyebrow(week: day.week, day: dayNumber))
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
            Text(verbatim: day.focus)
                .brandFont(.largeTitle)
                .foregroundStyle(Color.brand(\.ink))
                .accessibilityAddTraits(.isHeader)
            Text(BrewCopy.minutes(day.estimatedMinutes))
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
            if !day.notes.isEmpty {
                Text(verbatim: day.notes)
                    .brandFont(.body)
                    .foregroundStyle(Color.brand(\.ink))
            }
        }
        .padding(.vertical, 4)
    }

    private func nextLine(_ day: PlanDay, in plan: Plan) -> some View {
        Text(
            LogCopy.next(
                day.focus,
                on: PlanEditor.date(of: day, in: plan).formatted(.dateTime.weekday(.wide)))
        )
        .brandFont(.body)
        .foregroundStyle(Color.brand(\.ink))
    }

    @ViewBuilder private func reasonSection(_ day: PlanDay) -> some View {
        if let line = fromYourPlan(day) {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LogCopy.fromYourPlan)
                        .brandFont(.label)
                        .foregroundStyle(Color.brandText(\.magic))
                    Text(line)
                        .brandFont(.body)
                        .foregroundStyle(Color.brand(\.ink))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The most telling reason today's numbers differ from last time, e.g. "Back squat goes
    /// up 2.5 kg since every set moved well on Monday." Load changes first, then volume.
    private func fromYourPlan(_ day: PlanDay) -> LocalizedStringResource? {
        let ranked: [ProgressionReason.Kind] = [
            .addLoad, .drop, .deload, .rpeUp, .rpeDown, .fromEstimate, .addReps, .addRound, .addTime,
            .addDistance, .faster, .hold, .retry, .holdEffort, .calibrate,
        ]
        let reasons = day.orderedExercises.map { planned in
            let history = (try? ProgressionEngine.history(of: planned.exerciseID, in: context)) ?? []
            return (planned, ProgressionEngine.next(for: planned, history: history, profile: profile).reason)
        }
        for kind in ranked {
            if let (planned, reason) = reasons.first(where: { $0.1.kind == kind }) {
                let name = library.exercise(id: planned.exerciseID)?.name ?? planned.exerciseID
                return ProgressionCopy.sentence(for: reason, exercise: name, units: units)
            }
        }
        return nil
    }

}

extension TodayView {
    /// Goes back into a running workout if there is one; otherwise begins today's session
    /// when it's planned and not yet logged, or a workout off the plan.
    private func beginNext() {
        if let workout = running.first {
            // Already on screen when the launch that brought this also resumed it.
            if session == nil { open(workout) }
            return
        }
        guard !isBusy else { return }
        let today = plan.map { TodayPlan(plan: $0) }
        begin(today.flatMap { $0.isDone ? nil : $0.day })
    }

    private func begin(_ day: PlanDay?) {
        if let day {
            open(WorkoutSession.start(day, profile: profile, in: context))
        } else {
            open(WorkoutSession.startAdHoc(title: String(localized: LogCopy.adHocTitle), in: context))
        }
    }

    /// Shows a running workout and, when there's a watch, wakes it to record heart rate and
    /// mirror the session (#15). Without a watch or Health access the workout runs as before.
    private func open(_ workout: Workout) {
        session = workout
        guard let link, workout.startedOn != .watch else { return }
        link.own(workout, in: context, library: library)
        guard health.isAvailable, !link.live.isMirroring else { return }
        let exercises = workout.orderedExercises.compactMap { library.exercise(id: $0.exerciseID) }
        Task {
            try? await health.requestAccess(.workouts)
            try? await link.live.start(activity: .infer(from: exercises), at: workout.startedAt)
        }
    }
}
