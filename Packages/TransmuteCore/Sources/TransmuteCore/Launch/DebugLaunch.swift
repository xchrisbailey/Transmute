import Foundation
import SwiftData

/// Acts on the launch arguments in a debug build, and does nothing in Release.
public enum DebugLaunch {
    @MainActor
    public static func apply(to container: ModelContainer, arguments: Set<LaunchArgument> = LaunchArgument.passed()) {
        #if DEBUG
            if arguments.contains(.initCloudKitSchema) {
                TransmuteStore.initializeCloudKitSchemaForLaunch()
            }
            let context = container.mainContext
            guard arguments.contains(.seedSample), (try? context.fetchCount(FetchDescriptor<Profile>())) == 0
            else { return }
            let (profile, plan) = SampleData.insert(into: context)
            if arguments.contains(.sampleSession) {
                startSession(of: plan, for: profile, in: context, arguments: arguments)
            }
            try? context.save()
        #endif
    }

    #if DEBUG
        /// The iPhone logs the first set too, to see the session screen. The watch stops at the
        /// set screen unless `-sampleRest` asks for the rest ring. The Mac has no session to
        /// start.
        @MainActor
        private static func startSession(
            of plan: Plan, for profile: Profile, in context: ModelContext, arguments: Set<LaunchArgument>
        ) {
            #if os(iOS) || os(watchOS)
                guard let day = plan.orderedDays.first(where: { $0.week == PlanEditor.week(of: plan) }) else { return }
                let workout = WorkoutSession.start(day, profile: profile, in: context)
                #if os(iOS)
                    let logsFirstSet = true
                #else
                    let logsFirstSet = arguments.contains(.sampleRest)
                #endif
                if logsFirstSet, let first = WorkoutSession.currentSet(of: workout) {
                    WorkoutSession.complete(first, in: workout)
                }
            #endif
        }
    #endif
}
