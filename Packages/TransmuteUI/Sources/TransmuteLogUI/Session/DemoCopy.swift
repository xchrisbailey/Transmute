import Foundation
import TransmuteCore
import TransmuteUI

enum DemoCopy {
    static let watch = LocalizedStringResource(
        "plain.demo.watch", defaultValue: "Watch demo", bundle: .main, comment: "plain. Exercise guidance button.")
    static let close = LocalizedStringResource(
        "plain.demo.close", defaultValue: "Close demo", bundle: .main, comment: "plain. Dismiss exercise guidance.")
    static let play = LocalizedStringResource(
        "plain.demo.play", defaultValue: "Play", bundle: .main, comment: "plain. Explicit video playback button.")
    static let loading = LocalizedStringResource(
        "plain.demo.loading", defaultValue: "Loading demo…", bundle: .main, comment: "plain. Player loading status.")
    static let unavailable = LocalizedStringResource(
        "plain.demo.unavailable",
        defaultValue: "Video unavailable. You can still use the written cues and keep logging.",
        bundle: .main, comment: "plain. Video failure message.")
    static let retry = LocalizedStringResource(
        "plain.demo.retry", defaultValue: "Retry video", bundle: .main, comment: "plain. Retry failed playback.")
    static let linkStopped = LocalizedStringResource(
        "plain.demo.linkStopped",
        defaultValue: "Video stopped for an external link. Retry video when you want to watch again.",
        bundle: .main, comment: "plain. Player retired for a link; does not claim opening succeeded.")
    static let showCues = LocalizedStringResource(
        "plain.demo.showCues", defaultValue: "Show cues", bundle: .main,
        comment: "plain. Header button that opens written cues when there is no demo video.")
    static let equipmentNote = LocalizedStringResource(
        "plain.demo.equipmentNote",
        defaultValue: "Choosing equipment only changes which demonstration you watch. It does not change your workout.",
        bundle: .main, comment: "plain. Reassures that picking demo equipment is viewing only.")

    static func noMatch(_ equipment: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.demo.noMatch",
            defaultValue: "No reviewed demonstration is available for \(equipment). The written cues below still apply.",
            bundle: .main, comment: "plain. No reviewed demo for the chosen equipment; %@ is the equipment.")
    }

    /// Equipment names in a stable order, joined for the current language.
    static func equipmentName(_ equipment: Set<Equipment>) -> String {
        ListFormatter.localizedString(
            byJoining: equipment.sorted(by: { $0.rawValue < $1.rawValue }).map { String(localized: $0.label) })
    }

    static let cues = LocalizedStringResource(
        "plain.demo.cues", defaultValue: "Setup and movement", bundle: .main,
        comment: "plain. Written guidance heading.")
    static let equipment = LocalizedStringResource(
        "plain.demo.equipment", defaultValue: "Demonstrated equipment", bundle: .main,
        comment: "plain. Equipment heading.")
    static let player = LocalizedStringResource(
        "plain.demo.player", defaultValue: "YouTube demo player", bundle: .main,
        comment: "plain. Player accessibility label.")
    static let disclosure = LocalizedStringResource(
        "plain.demo.disclosure",
        defaultValue:
            "YouTube loads when a demonstration is shown and may collect playback-related data, show ads and suggest other videos. Transmute does not send your workout history or Health data to YouTube. Internet is required for video, not written cues.",
        bundle: .main, comment: "plain. Third-party playback disclosure; no tracking-free promise.")
    static let terms = LocalizedStringResource(
        "plain.demo.terms", defaultValue: "YouTube Terms of Service", bundle: .main,
        comment: "plain. External terms link.")
    static let privacy = LocalizedStringResource(
        "plain.demo.privacy", defaultValue: "Google Privacy Policy", bundle: .main,
        comment: "plain. External privacy link.")
}
