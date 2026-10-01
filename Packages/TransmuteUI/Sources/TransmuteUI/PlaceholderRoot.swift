import SwiftUI

/// Placeholder root shown by each app until its real shell lands.
public struct PlaceholderRoot: View {
    let platform: String

    public init(platform: String) {
        self.platform = platform
    }

    public var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
    }

    private var content: some View {
        VStack(spacing: 12) {
            Image("Mark")
                .resizable()
                .scaledToFit()
                .frame(width: markSize, height: markSize)
                .accessibilityHidden(true)
            Text(verbatim: "Transmute")
                .brandFont(.largeTitle)
                .foregroundStyle(Color.brand(\.ink))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(Copy.emptyLog)
                .brandFont(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color.brandText(\.subtext))
            Text(verbatim: platform)
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
        }
    }

    private var markSize: CGFloat {
        #if os(watchOS)
            48
        #else
            96
        #endif
    }

    private var background: Color {
        #if os(watchOS)
            .watchScreen
        #else
            .brand(\.base)
        #endif
    }
}
