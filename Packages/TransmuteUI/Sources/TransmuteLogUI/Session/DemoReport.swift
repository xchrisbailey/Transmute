import Foundation
import TransmuteCore

/// A wrong-video report, written in English for the maintainer and built only from the demo on view,
/// the app version and what the person typed. Nothing about the workout can reach it.
struct DemoReport: Equatable {
    /// Keeps the prefilled GitHub link well inside what the site accepts, whatever the language typed.
    static let maxDescriptionBytes = 1000
    private static let newIssue = "https://github.com/xchrisbailey/Transmute/issues/new"

    let demo: ViewedDemo
    let appVersion: String?
    private(set) var description: String
    /// True while the last text typed was longer than fits, so the person is told rather than left guessing.
    private(set) var isDescriptionCut = false

    init(demo: ViewedDemo, appVersion: String?, description: String = "") {
        self.demo = demo
        self.appVersion = appVersion
        self.description = Self.clamped(description)
        isDescriptionCut = self.description != description
    }

    mutating func setDescription(_ text: String) {
        description = Self.clamped(text)
        isDescriptionCut = description != text
    }

    private static func clamped(_ text: String) -> String {
        var bytes = 0
        return String(
            text.prefix { character in
                bytes += character.utf8.count
                return bytes <= maxDescriptionBytes
            })
    }

    private var equipmentList: String {
        demo.equipment.map(\.rawValue).sorted().joined(separator: ", ")
    }

    var title: String { "Wrong demo video: \(demo.exerciseName) (\(equipmentList))" }

    var body: String {
        var lines = [
            "Wrong demo video report", "",
            "- Exercise: \(demo.exerciseName)",
            "- Exercise ID: \(demo.exerciseID)",
            "- Demo equipment: \(equipmentList)",
            "- Video: https://www.youtube.com/watch?v=\(demo.videoID)",
            "- App version: \(appVersion ?? "unknown")",
        ]
        let note = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { lines += ["", "Description:", note] }
        return lines.joined(separator: "\n")
    }

    /// What Copy report puts on the clipboard: the title, then the body.
    var copyText: String { "\(title)\n\n\(body)" }

    /// The fixed project tracker with the title and body as percent-encoded values, so no typed
    /// character can end a value, add a parameter or change where the link goes.
    var url: URL {
        let unreserved = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        func encoded(_ text: String) -> String {
            text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
        }
        return URL(string: "\(Self.newIssue)?title=\(encoded(title))&body=\(encoded(body))")!
    }
}
