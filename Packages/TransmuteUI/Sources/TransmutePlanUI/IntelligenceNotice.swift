import SwiftUI
import TransmuteIntelligence
import TransmuteUI

/// Explains why brewing isn't possible right now, in plain words (#3). Shown in place of AI
/// actions; existing plans and logging keep working around it.
public struct IntelligenceNotice: View {
    let availability: IntelligenceAvailability
    @Environment(\.openURL) private var openURL

    public init(availability: IntelligenceAvailability) {
        self.availability = availability
    }

    public var body: some View {
        if !availability.canGenerate {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(message)
                        .brandFont(.body)
                        .foregroundStyle(Color.brand(\.ink))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    if availability.resolvesOnItsOwn {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                }
                if availability == .turnedOff, let settingsURL {
                    Button {
                        openURL(settingsURL)
                    } label: {
                        Text(Copy.openSettings)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brand(\.mantle), in: .rect(cornerRadius: 16))
            .accessibilityElement(children: .contain)
        }
    }

    private var message: LocalizedStringResource {
        switch availability {
        case .available, .turnedOff: Copy.aiUnavailable
        case .deviceNotEligible: Copy.aiDeviceNotEligible
        case .modelNotReady: Copy.aiNotReady
        }
    }

    private var settingsURL: URL? {
        #if os(iOS)
            URL(string: UIApplication.openSettingsURLString)
        #else
            URL(string: "x-apple.systempreferences:")
        #endif
    }
}

extension IntelligenceError {
    /// What to tell someone when a generation fails.
    public var message: LocalizedStringResource {
        switch self {
        case .unavailable(.deviceNotEligible): Copy.aiDeviceNotEligible
        case .unavailable(.modelNotReady): Copy.aiNotReady
        case .unavailable: Copy.aiUnavailable
        case .refused, .guardrail: Copy.aiRefused
        case .rateLimited: Copy.aiBusy
        case .unsupportedLanguage: Copy.aiLanguage
        case .tooLong, .searchLoop, .malformedOutput, .failed: Copy.aiFailed
        }
    }
}

#Preview("Turned off") {
    IntelligenceNotice(availability: .turnedOff).padding()
}

#Preview("Downloading") {
    IntelligenceNotice(availability: .modelNotReady).padding()
}
