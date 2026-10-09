import SwiftUI
import TransmuteUI

/// The version and build number the About section shows, read from a bundle's Info.plist.
struct AboutInfo: Equatable {
    /// What stands in for a version or build number the bundle doesn't have.
    static let missing = "–"

    let version: String
    let build: String

    init(infoDictionary: [String: Any]?) {
        version = Self.value("CFBundleShortVersionString", in: infoDictionary)
        build = Self.value("CFBundleVersion", in: infoDictionary)
    }

    /// The running app's own version and build.
    static var current: AboutInfo { AboutInfo(infoDictionary: Bundle.main.infoDictionary) }

    private static func value(_ key: String, in infoDictionary: [String: Any]?) -> String {
        guard let text = infoDictionary?[key] as? String else { return missing }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? missing : trimmed
    }
}

/// About (#58): the version and build the app is running, where the catalog came from, and the
/// licence for the fonts it ships.
struct AboutSection: View {
    private let info = AboutInfo.current
    @State private var showsLicence = false

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(versionLine)
                    .brandFont(.body)
                    .foregroundStyle(Color.brand(\.ink))
                buildRow
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            Text(SettingsAboutCopy.catalog)
                .foregroundStyle(Color.brand(\.ink))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showsLicence = true
            } label: {
                Label {
                    Text(SettingsAboutCopy.licence)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "doc.text")
                        .accessibilityHidden(true)
                }
            }
        } header: {
            Text(SettingsScreenCopy.paneAbout)
        }
        // A sheet rather than a pushed screen: on the Mac a push swaps the Settings tabs for a back
        // button and leaves the wrong tab lit.
        .sheet(isPresented: $showsLicence) {
            FontLicenceSheet()
        }
    }

    /// The `voice.about` line, with the version itself in the number font at the body size (15).
    private var versionLine: AttributedString {
        var line = AttributedString(String(localized: Copy.about(version: info.version)))
        if let range = line.range(of: info.version) {
            line[range].font = .brandNumber(size: 15, relativeTo: .body)
        }
        return line
    }

    /// "Build" and its number (label size, 13.5) side by side, or one under the other when they don't fit.
    private var buildRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                buildLabel
                buildNumber
            }
            VStack(alignment: .leading, spacing: 2) {
                buildLabel
                buildNumber
            }
        }
    }

    private var buildLabel: some View {
        Text(SettingsAboutCopy.build)
            .brandFont(.label)
            .foregroundStyle(Color.brandText(\.subtext))
    }

    private var buildNumber: some View {
        Text(info.build)
            .brandNumberFont(size: 13.5, relativeTo: .subheadline)
            .foregroundStyle(Color.brand(\.ink))
    }
}

/// The licence on its own sheet, with a way to close it.
struct FontLicenceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FontLicenceView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text(SettingsAboutCopy.done)
                        }
                    }
                }
        }
        #if os(macOS)
            .frame(minWidth: 560, minHeight: 480)
        #endif
    }
}

/// The SIL Open Font License for Geist and Geist Mono, shown as it's written in the bundled
/// `OFL.txt`.
struct FontLicenceView: View {
    private let text = Self.bundledText()

    var body: some View {
        ScrollView {
            Group {
                if let text {
                    Text(verbatim: text)
                } else {
                    Text(SettingsAboutCopy.licenceMissing)
                }
            }
            .brandFont(.label)
            .foregroundStyle(Color.brand(\.ink))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color.brand(\.base))
        .navigationTitle(Text(SettingsAboutCopy.licence))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private static func bundledText() -> String? {
        guard let url = Bundle.main.url(forResource: "OFL", withExtension: "txt") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
