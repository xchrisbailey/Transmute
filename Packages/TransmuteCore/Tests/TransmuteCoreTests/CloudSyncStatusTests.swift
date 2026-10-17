import CloudKit
import SwiftData
import Testing

@testable import TransmuteCore

struct CloudSyncStatusTests {
    @Test func aLocalStoreIsNotSyncing() async throws {
        // swiftlint:disable:next use_make_test_container
        let container = try TransmuteStore.makeContainer(.inMemory)
        #expect(await TransmuteStore.cloudSyncStatus(of: container) == .notSyncing)
    }

    @Test func everyAccountStatusHasAPlainMeaning() {
        #expect(CloudSyncStatus(.available) == .available)
        #expect(CloudSyncStatus(.noAccount) == .signedOut)
        #expect(CloudSyncStatus(.restricted) == .restricted)
        #expect(CloudSyncStatus(.temporarilyUnavailable) == .temporarilyUnavailable)
        #expect(CloudSyncStatus(.couldNotDetermine) == .unknown)
    }
}
