import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// One day of the plan (#10): exercises in order with targets, supersets grouped, and every
/// edit: reorder, add, remove, swap, change targets, move to another weekday, or rework the
/// whole day with AI.
struct PlanDayView: View {
    @Bindable var day: PlanDay
    let plan: Plan
    let profile: Profile
    let service: any IntelligenceService

    @Environment(\.modelContext) private var context
    @State private var showsPicker = false
    @State private var showsRework = false
    @State private var showsGlossary = false
    let library = ExerciseLibrary.bundled

    private var units: Units {
        Units(profile)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: day.focus)
                        .brandFont(.largeTitle)
                        .foregroundStyle(Color.brand(\.ink))
                        .accessibilityAddTraits(.isHeader)
                    Text(PlanEditor.date(of: day, in: plan), format: .dateTime.weekday(.wide).day().month())
                        .brandFont(.label)
                        .foregroundStyle(Color.brandText(\.subtext))
                    if !day.notes.isEmpty {
                        Text(verbatim: "\(String(localized: PlanCopy.cuesFromLibrary)): \(day.notes)")
                            .brandFont(.body)
                            .foregroundStyle(Color.brand(\.ink))
                    }
                    Text(BrewCopy.minutes(day.estimatedMinutes))
                        .brandFont(.label)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
                Picker(selection: weekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(verbatim: TrainingBrief.weekdayName(weekday)).tag(weekday)
                    }
                } label: {
                    Text(PlanCopy.moveDay)
                }
            }
            Section {
                if day.orderedExercises.isEmpty {
                    Text(PlanCopy.emptyDay)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
                ForEach(day.orderedExercises) { planned in
                    NavigationLink {
                        PlannedExerciseView(planned: planned, equipment: Set(profile.equipment), units: units)
                    } label: {
                        PlannedExerciseRow(planned: planned, units: units, library: library)
                    }
                }
                .onMove { source, destination in
                    PlanEditor.move(in: day, from: source, to: destination)
                }
                .onDelete { offsets in
                    let ordered = day.orderedExercises
                    for index in offsets.sorted(by: >) {
                        PlanEditor.remove(ordered[index], from: day, in: context)
                    }
                }
                Button {
                    showsPicker = true
                } label: {
                    Label {
                        Text(PlanCopy.addExercise)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            } header: {
                Text(PlanCopy.session)
            } footer: {
                Button {
                    showsGlossary = true
                } label: {
                    Text(PlanCopy.whatsThis)
                }
                .buttonStyle(.borderless)
            }
            Section {
                Button {
                    showsRework = true
                } label: {
                    Label {
                        Text(Copy.reworkDay)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand(\.magic))
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationTitle(Text(verbatim: day.focus))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            UndoButtons()
            #if os(iOS)
                ToolbarItem {
                    EditButton()
                }
            #endif
        }
        .sheet(isPresented: $showsPicker) {
            NavigationStack {
                ExercisePicker(
                    initialQuery: ExerciseQuery(availableEquipment: Set(profile.equipment).union([.bodyweight]))
                ) { exercise in
                    PlanEditor.add(exercise, to: day)
                    showsPicker = false
                }
                .navigationTitle(Text(PlanCopy.addExercise))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showsPicker = false
                        } label: {
                            Text(ProfileCopy.cancel)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showsRework) {
            ReworkDaySheet(day: day, plan: plan, profile: profile, service: service)
        }
        .sheet(isPresented: $showsGlossary) {
            GlossaryView()
        }
    }

    private var weekday: Binding<Weekday> {
        Binding {
            day.weekday
        } set: {
            PlanEditor.move(day, to: $0)
        }
    }
}

/// An exercise in a day: name, one-line targets, and its superset if it has one. Reads as a
/// sentence for VoiceOver.
struct PlannedExerciseRow: View {
    let planned: PlannedExercise
    let units: Units
    let library: ExerciseLibrary

    @Environment(\.effortDisplay) private var effort

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if let group = planned.supersetGroup {
                    Label {
                        Text(PlanCopy.superset)
                    } icon: {
                        Image(systemName: "link")
                    }
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.magic))
                    .accessibilityValue(Text(verbatim: "\(group)"))
                }
            }
            Text(verbatim: library.exercise(id: planned.exerciseID)?.name ?? planned.exerciseID)
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brand(\.ink))
            Text(verbatim: SetTargets(planned.orderedSets).summary(units: units, showing: effort))
                .brandNumberFont(size: 15)
                .foregroundStyle(Color.brandText(\.subtext))
            if !planned.notes.isEmpty {
                Text(verbatim: planned.notes)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Plain explanations of the terms plans use (#22).
struct GlossaryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                term(PlanCopy.rpeTerm, PlanCopy.rpeHelp)
                term(PlanCopy.oneRepMaxTerm, PlanCopy.oneRepMaxHelp)
                term(PlanCopy.superset, PlanCopy.supersetHelp)
                term(PlanCopy.deloadTerm, PlanCopy.deloadHelp)
            }
            .navigationTitle(Text(PlanCopy.whatsThis))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(PlanCopy.done)
                    }
                }
            }
        }
    }

    private func term(_ name: LocalizedStringResource, _ help: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .brandFont(.exerciseTitle)
            Text(help)
                .brandFont(.body)
                .foregroundStyle(Color.brandText(\.subtext))
        }
        .accessibilityElement(children: .combine)
    }
}
