import Foundation
import SwiftData

extension Profile {
    /// The one profile the app uses: the earliest made. Sync can leave a second after two devices
    /// each create one, and every reader must pick the same.
    public static func canonical(in context: ModelContext) throws -> Profile? {
        var descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
