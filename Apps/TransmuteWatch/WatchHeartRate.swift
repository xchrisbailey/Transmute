import SwiftUI
import TransmuteUI

/// The live heart rate: a red heart and the beats per minute. Nothing until the first reading.
struct WatchHeartRate: View {
    let bpm: Double?

    var body: some View {
        if let bpm {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .imageScale(.small)
                Text(verbatim: "\(Int(bpm.rounded()))")
                    .brandNumberFont(size: 13, relativeTo: .footnote)
            }
            .foregroundStyle(Color.brandText(\.alert))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(WatchCopy.heartRate))
            .accessibilityValue(Text(WatchCopy.beatsPerMinute(Int(bpm.rounded()))))
        }
    }
}
