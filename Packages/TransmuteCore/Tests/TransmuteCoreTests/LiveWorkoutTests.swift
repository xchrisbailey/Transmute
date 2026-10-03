import Foundation
import Testing

@testable import TransmuteCore

#if canImport(HealthKit)
    import HealthKit
#endif

@MainActor
struct LiveWorkoutTests {
    @Test func theStandInNeverStartsOrSaves() async throws {
        let live: any LiveWorkout = UnavailableLiveWorkout()
        await #expect(throws: HealthServiceError.unavailable) {
            try await live.start(activity: .traditionalStrength, at: .now)
        }
        live.pause()
        live.resume()
        await live.send(Data([1, 2, 3]))
        #expect(try await live.finish(workoutID: UUID(), title: "Lower A", at: .now) == nil)
        await live.discard()

        #expect(live.state == .idle)
        #expect(live.heartRate == nil)
        #expect(live.averageHeartRate == nil)
        #expect(live.activeEnergyKcal == nil)
        #expect(!live.isMirroring)
    }

    @Test func theStandInsMessagesEndStraightAway() async {
        let live = UnavailableLiveWorkout()
        var messages: [Data] = []
        for await message in live.incoming {
            messages.append(message)
        }
        #expect(messages.isEmpty)
    }

    #if canImport(HealthKit)
        @Test func sessionStatesMapToLiveStates() {
            #expect(LiveWorkoutState(HKWorkoutSessionState.notStarted) == .idle)
            #expect(LiveWorkoutState(HKWorkoutSessionState.prepared) == .idle)
            #expect(LiveWorkoutState(HKWorkoutSessionState.running) == .running)
            #expect(LiveWorkoutState(HKWorkoutSessionState.paused) == .paused)
            #expect(LiveWorkoutState(HKWorkoutSessionState.stopped) == .ended)
            #expect(LiveWorkoutState(HKWorkoutSessionState.ended) == .ended)
        }

        @Test func metadataMarksTheWorkoutAsTransmutes() {
            let id = UUID()
            let metadata = HealthWorkoutRecord.metadata(workoutID: id, title: "Lower A")
            #expect(metadata.count == 2)
            #expect(metadata[HealthWorkoutRecord.workoutIDKey] as? String == id.uuidString)
            #expect(metadata[HKMetadataKeyWorkoutBrandName] as? String == "Lower A")
        }
    #endif
}
