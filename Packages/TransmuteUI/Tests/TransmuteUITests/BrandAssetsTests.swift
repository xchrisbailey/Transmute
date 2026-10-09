import Foundation
import Testing

@testable import TransmuteUI

/// Checks the pieces of the brand that live outside the package: the app's String Catalog
/// and the bundled fonts.
struct BrandAssetsTests {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    nonisolated(unsafe) static let catalog: [String: Any] = {
        let url = repo.appending(path: "Apps/Shared/Localizable.xcstrings")
        let json = (try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) }
        return (json as? [String: Any])?["strings"] as? [String: Any] ?? [:]
    }()

    static let resources: [LocalizedStringResource] = [
        Copy.brewPlan, Copy.distilling(week: 1), Copy.rebrew, Copy.reworkDay, Copy.whyThisPlan("x"),
        Copy.brewedOn(device: "iPhone"), Copy.beginWork, Copy.logSet, Copy.rest("1:48"),
        Copy.gold(exercise: "Squat", record: "5RM", value: "115 kg"), Copy.workDone(sets: 18, moved: "8,420 kg"),
        Copy.weekDistilled, Copy.streak(weeks: 3), Copy.emptyLog, Copy.deleteWorkout("Lower A", date: "Sep 28"),
        Copy.healthAccess, Copy.aiUnavailable, Copy.savePlanError, Copy.about(version: "1.0"),
        Copy.aiNotReady, Copy.aiDeviceNotEligible, Copy.aiRefused, Copy.aiBusy, Copy.aiLanguage, Copy.aiFailed,
        Copy.openSettings, Copy.restLeft("1 minute"), Copy.restOverSpoken, Copy.addRestSpoken,
        Copy.lessRestSpoken, Copy.skipRestSpoken,
    ]

    @Test(arguments: resources)
    func copyIsInTheCatalog(_ resource: LocalizedStringResource) throws {
        let entry = try #require(Self.catalog[resource.key] as? [String: Any], "\(resource.key) missing")
        let comment = try #require(entry["comment"] as? String)
        let tone = resource.key.split(separator: ".").first.map(String.init)
        #expect(comment.hasPrefix("\(tone ?? "")."), "\(resource.key) comment should start with its tone")
    }

    @Test func everyCatalogKeyIsVoiceOrPlain() {
        #expect(!Self.catalog.isEmpty)
        for key in Self.catalog.keys {
            #expect(key.hasPrefix("voice.") || key.hasPrefix("plain."), "\(key)")
        }
    }

    @Test func catalogRendersTheBrandBookExamples() {
        func english(_ key: String) -> String? {
            let entry = Self.catalog[key] as? [String: Any]
            let english = (entry?["localizations"] as? [String: Any])?["en"] as? [String: Any]
            return (english?["stringUnit"] as? [String: Any])?["value"] as? String
        }
        #expect(String(format: english("voice.gold")!, "Squat", "5RM", "115 kg") == "Gold. Squat 5RM, 115 kg.")
        #expect(
            String(format: english("voice.workDone")!, 18, "8,420 kg") == "The work is done. 18 sets, 8,420 kg moved.")
        #expect(String(format: english("voice.distilling")!, 1) == "Distilling week 1…")
    }

    @Test(arguments: [GeistWeight.regular, .medium, .semiBold, .bold, .extraBold])
    func fontFilesMatchPostScriptNames(_ weight: GeistWeight) {
        let fonts = Self.repo.appending(path: "Resources/Fonts")
        #expect(FileManager.default.fileExists(atPath: fonts.appending(path: "\(weight.geist).otf").path))
        #expect(FileManager.default.fileExists(atPath: fonts.appending(path: "\(weight.geistMono).otf").path))
    }

    @Test func boldTextStepsUp() {
        for style in BrandTextStyle.allCases {
            #expect(style.weight.bolder > style.weight || style.weight == .extraBold)
        }
    }
}

extension BrandAssetsTests {
    /// Every `voice.` or `plain.` key written anywhere in the packages or apps is in the catalog,
    /// so no screen falls back to an untranslated default.
    @Test func everyKeyInTheSourceIsInTheCatalog() throws {
        let pattern = /"((?:voice|plain)\.[A-Za-z0-9.]+)"/
        var missing: [String] = []
        for folder in ["Packages", "Apps"] {
            let root = Self.repo.appending(path: folder)
            let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = files?.nextObject() as? URL {
                guard url.pathExtension == "swift", !url.path.contains("/.build/"), !url.path.contains("/Tests/")
                else { continue }
                let source = try String(contentsOf: url, encoding: .utf8)
                for match in source.matches(of: pattern) where Self.catalog[String(match.1)] == nil {
                    missing.append("\(url.lastPathComponent): \(match.1)")
                }
            }
        }
        #expect(missing.isEmpty, "\(missing)")
    }
}
