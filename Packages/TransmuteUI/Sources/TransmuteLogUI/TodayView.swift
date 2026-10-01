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
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }, sort: \Workout.startedAt, order: .reverse)
    private var running: [Workout]
    @State private var session: Workout?
    @State private var didResume = false
    let library = ExerciseLibrary.bundled

    public init(plan: Plan?, profile: Profile) {
        self.plan = plan
        self.profile = profile
    }

    private var units: Units {
        Units(system: profile.unitSystem)
    }

    public var body: some View {
        List {
            if let workout = running.first {
                Section {
                    Button {
                        session = workout
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
                .disabled(!running.isEmpty)
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
            if !didResume, let workout = running.first {
                didResume = true
                session = workout
            }
        }
        #if os(iOS)
            .fullScreenCover(item: $session) { workout in
                SessionView(workout: workout, profile: profile) { session = nil }
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
            Section {
                ForEach(day.orderedExercises) { planned in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: library.exercise(id: planned.exerciseID)?.name ?? planned.exerciseID)
                            .brandFont(.exerciseTitle)
                            .foregroundStyle(Color.brand(\.ink))
                        Text(verbatim: SetTargets(planned.orderedSets).summary(units: units))
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
                    .disabled(!running.isEmpty)
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

    private func begin(_ day: PlanDay?) {
        if let day {
            session = WorkoutSession.start(day, in: context)
        } else {
            session = WorkoutSession.startAdHoc(title: String(localized: LogCopy.adHocTitle), in: context)
        }
    }
}
