import SwiftUI
import TransmuteCore

/// Placeholder root shown by each app until its real shell lands.
public struct PlaceholderRoot: View {
    let platform: String

    public init(platform: String) {
        self.platform = platform
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text("Transmute")
                .font(.largeTitle.weight(.heavy))
            Text(platform)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
