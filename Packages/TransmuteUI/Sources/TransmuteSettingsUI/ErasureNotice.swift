import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// Says how delete-all went (#18), where the person lands afterwards: on onboarding's welcome
/// step, and in the Mac's Settings window. Shows nothing until there's something to report.
///
/// If iCloud couldn't be reached it says so and offers to try again, rather than claiming
/// everything is gone.
public struct ErasureNotice: View {
    @AppStorage(ErasureOutcome.defaultsKey) private var stored: String?
    @Environment(\.modelContext) private var context
    @State private var isRetrying = false

    public init() {}

    /// Forgets the report, once it's been seen or a new profile has been made.
    public static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: ErasureOutcome.defaultsKey)
    }

    public var body: some View {
        if let outcome = stored.flatMap(ErasureOutcome.init(rawValue:)) {
            VStack(alignment: .leading, spacing: 12) {
                StatusRow(tone: outcome == .cloudFailed ? .problem : .good, text: outcome.message)
                    .brandFont(.body)
                HStack {
                    if outcome == .cloudFailed {
                        Button {
                            retry()
                        } label: {
                            Text(SettingsDataCopy.erasedRetry)
                        }
                        .disabled(isRetrying)
                    }
                    Button {
                        stored = nil
                    } label: {
                        Text(SettingsDataCopy.erasedDismiss)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brand(\.mantle), in: .rect(cornerRadius: 16))
            .accessibilityElement(children: .contain)
        }
    }

    private func retry() {
        let container = context.container
        isRetrying = true
        Task { @MainActor in
            await DataEraser.retryCloud(for: container)
            isRetrying = false
        }
    }
}

#Preview("iCloud failed") {
    UserDefaults.standard.set(ErasureOutcome.cloudFailed.rawValue, forKey: ErasureOutcome.defaultsKey)
    return ErasureNotice().padding()
}
