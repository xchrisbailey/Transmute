# Beginner-friendly exercise demo videos

## Problem Statement

A beginner logging a planned exercise may not know how to perform it. Exercise names and written cues alone can be hard to interpret, and leaving the workout to search for a demonstration interrupts logging and can lead to a video of the wrong movement or equipment variant.

Transmute needs optional visual guidance beside the exercise being logged, without losing entered values, changing the workout, or making video playback a prerequisite for completing a session. New video licensing, subscriptions, and paid backend services are not acceptable for this first release. Offline video is not important.

## Solution

On iPhone, put **Watch demo** beside a planned exercise's name in the active workout when it has reviewed demo content. Open an in-app sheet with the video first and brief written setup and movement cues below. Use the official YouTube embedded player. Playback starts only after an explicit Play action; closing the sheet stops playback and returns to unchanged logging.

Choose videos while maintaining the exercise library, not through live searches when someone opens a demo. Generate candidates using the exercise name, equipment, and movement variant, then review the exact match before publishing. Save approved associations by stable exercise ID and demonstrated equipment. Where an exercise allows equipment alternatives, let the person choose the equipment demonstration to view without changing the workout itself.

Videos may require internet and may contain YouTube branding, advertising, related content, and playback-related data collection. Explain those trade-offs accurately. If playback fails, keep written guidance available and allow logging to continue. Include **Report wrong video**, opening a user-reviewed public GitHub issue with a copyable report fallback. Maintainers review reports and ship mapping corrections through app updates.

## User Stories

1. As a beginner, I want to find a demonstration beside the exercise I am logging, so that I do not have to leave my workout to search for help.
2. As a lifter, I want exercise guidance to be optional, so that familiar exercises remain quick to log.
3. As a beginner, I want the video to appear first in the guidance sheet, so that the movement is easy to find.
4. As a beginner, I want brief written setup and movement cues below the video, so that I can check important details without replaying it.
5. As a lifter, I want to choose when playback begins, so that opening help does not unexpectedly play audio or video.
6. As a lifter, I want closing the sheet to stop its video and audio, so that I can return to my workout without background playback.
7. As a lifter, I want entered weight and reps preserved when I open help, so that I do not have to enter them again.
8. As a lifter, I want previously logged sets left unchanged, so that watching a demonstration cannot alter my workout record.
9. As a lifter, I want to return to the same logging position and editing context, so that help does not interrupt where I was working.
10. As a lifter resting between sets, I want my rest timer to keep following elapsed time while I watch, so that guidance does not silently extend or pause rest.
11. As a lifter, I want playback to pause when I leave the app or it is interrupted, so that it does not continue unexpectedly.
12. As a lifter returning to the app, I want playback to remain paused until I press Play, so that returning does not cause surprise audio.
13. As a beginner, I want videos to match the actual movement, so that a similarly named exercise does not teach me something different.
14. As a beginner, I want videos to match the demonstrated equipment, so that I do not mistake a different implement for an approved substitute.
15. As a lifter whose exercise supports several equipment options, I want to choose which equipment demonstration to view, so that the guidance matches what I intend to use.
16. As a lifter, I want choosing a demonstration's equipment to leave my workout exercise and sets unchanged, so that viewing help is not treated as exercise substitution.
17. As a beginner, I want unsupported equipment choices to say that no reviewed demo is available, so that the app does not silently show a different variant.
18. As a lifter, I want a display-name correction to retain an exercise's reviewed demo, so that harmless renaming does not break guidance.
19. As a beginner, I want changed movements to receive fresh review, so that outdated videos are not silently reused.
20. As a lifter with a custom exercise, I want my supplied written cues to remain accessible, so that the lack of an automatic video does not erase my guidance.
21. As a beginner, I want custom exercises without reviewed content to avoid guessed videos, so that a custom name is not mistaken for a verified movement.
22. As a lifter without internet, I want available written cues and logging to work, so that video connectivity does not block my workout.
23. As a lifter encountering a removed, blocked, or failed video, I want a clear unavailable state and retry, so that I understand the problem without losing access to cues.
24. As a lifter, I want guidance that is understandable while muted, so that headphones and audio are not required.
25. As a lifter using spoken instruction, I want reviewed captions, so that I can follow essential speech without relying on unverified automatic captions.
26. As a VoiceOver user, I want labelled entry, equipment, reporting, and dismissal controls, so that I can operate the guide independently.
27. As a VoiceOver user, I want to navigate into and out of the video player without a focus trap, so that embedded content does not prevent me from returning to logging.
28. As a person using larger text, I want readable and scrollable cues and controls, so that the sheet remains usable without clipping important guidance.
29. As a lifter, I want an easy-to-find Close control, so that leaving the guide does not require a particular gesture.
30. As a person concerned about privacy, I want an accurate explanation of YouTube playback and possible ads, so that I am not misled by blanket claims about local-only data or no advertising.
31. As a person reporting an incorrect demo, I want Report wrong video available in the sheet, so that I can flag the exact association I saw.
32. As a reporter, I want the exercise, selected equipment, video link, and app version prefilled, so that I do not have to reconstruct useful context.
33. As a reporter, I want to add an optional description and review the issue before submitting, so that I control what is published.
34. As a reporter, I want to know that GitHub issues are public and require an account, so that I can make an informed choice about reporting.
35. As a reporter without a usable GitHub submission route, I want to copy the report, so that I can retain or share its details myself.
36. As a person concerned about privacy, I want reports to exclude workout history, Health data, and logs by default, so that a demo correction does not disclose private activity.
37. As a reporter, I want opening or copying a report to be distinguished from submitting it, so that I am not falsely told the maintainer received it.
38. As a maintainer, I want candidate discovery separated from approval, so that automatic matching saves search effort without publishing unverified guesses.
39. As a maintainer, I want saved, reviewed video associations rather than runtime searches, so that users see consistent content without a search backend.
40. As a maintainer, I want a traceable review record for each published association, so that I can understand and correct its movement, equipment, and caption decisions.
41. As a maintainer, I want to review reported mistakes before changing mappings, so that a report does not automatically remove content for everyone.
42. As a maintainer, I want to replace or remove a mapping in an app update, so that corrections follow the existing library distribution mechanism.
43. As a maintainer, I want the feature to introduce no video subscription, licensing purchase, or paid backend, so that demonstrations meet the agreed zero-cost constraint.
44. As a person using an older app version, I want no promise of instant corrections, so that bundled content updates are represented honestly.

## Implementation Decisions

### Scope and integration

- Implement the experience in the iPhone logging surface for an active planned workout. The existing SessionView, exercise header, ExerciseLibrary, and WorkoutSession are the integration points. Do not add watchOS or Mac video playback.
- Keep the selected video-first sheet hierarchy. Do not introduce cue-by-cue navigation or separate Demo/Form tabs from the discarded prototype alternatives.
- Expose Watch demo for reviewed library content; do not advertise an unreviewed candidate as playable guidance. Preserve existing access to written cues where no approved demo exists. A mapped video that later fails remains a graceful unavailable state inside the sheet.
- A viewing-only equipment selection must never call workout substitution, replace an exercise, change its saved identity, or modify sets. Preserve the current mirrored-session ownership rules; merely viewing guidance is not a workout write.
- Opening and dismissing help must preserve in-progress numeric entry, expanded editing context, entered values, logged sets, current exercise/set, and logging position. Closing via the explicit control or an available dismissal gesture has the same playback cleanup contract.
- No persisted model, CloudKit, plan, log, backup, or transfer-schema change is required by these decisions. Keep demo metadata in bundled library content and viewing state transient. If implementation discovers a genuine need for persisted changes, return for review rather than editing the shipped schema in place.
- Put all user-facing copy in the project's localized Copy system. Keep logging, error, accessibility, and reporting language plain and beginner-readable.

### Reviewed content and exact associations

- Use official YouTube embeds of selected instructional uploads, with embedding permitted. Public availability is not permission to download, bundle, rehost, or redistribute raw video files.
- Candidate generation happens during library maintenance using the exercise name, equipment, and movement variant. It is not an app-time search, automatic publication, or a requirement to build a discovery service. A candidate may come from a maintainer-assisted search; no paid API, runtime search key, or backend is required.
- Perform a quick exact-movement review before publishing each candidate. Check the meaningful distinctions: equipment, grip, stance, support, unilateral/bilateral execution, load position, range, tempo or pause, and complete drill sequence where relevant. Review the footage, not just its title or search ranking.
- Record approved associations by stable exercise ID and the equipment variant demonstrated. An exercise can have multiple equipment-specific associations. Validate alternatives against the library's equipment requirements, including groups with alternatives; do not treat every flattened equipment item as an interchangeable implement.
- Keep enough review information to trace the chosen video, demonstrated equipment, movement approval, review date, and caption/non-audio review. Never mark unreviewed metadata as approved. Exact internal representation is an implementation choice, not a new persisted user model.
- Retain approved associations across display-name changes. Do not rename stable exercise IDs. A change in movement meaning invalidates the assumption that an existing demo still matches and requires fresh review.
- Clearly label demonstrated equipment. For an exercise with alternatives, let the user choose the equipment demonstration to view. If a chosen alternative has no approved match, show the unavailable state and applicable written cues, never another variant's video. Do not imply that changing a demo selection records the equipment used in a workout.
- Custom exercises receive no automatic video association initially. Show user-supplied written cues where available; do not invent cues or derive an approved demo from a custom name.
- Publish only reviewed matches; complete coverage of the exercise library is not a launch promise. Do not fill coverage gaps with unreviewed guesses or similar-but-different movements. Supply actual reviewed content for the initial supported set rather than shipping prototype placeholders as demonstrations.
- Updates and corrections ship with the app's bundled library. Existing plans and logged exercise identities remain untouched. No remote manifest, kill switch, or instant correction channel is included; older installations retain their bundled association until updated.

### Player, lifecycle, and availability

- Use the official YouTube player through an iPhone-compatible embedded web view, not an extracted stream or native AVPlayer URL. Follow current app identity, inline playback, player sizing, branding, controls, and embedding requirements. Do not cover or strip required player UI, block its advertising, or promise related content can be removed.
- Opening the sheet does not autoplay. Require an explicit Play action. Do not equate no autoplay with no third-party network traffic when the embed loads.
- Dismissing the sheet stops video and audio. Backgrounding or a playback interruption pauses playback; returning to the app requires explicit Play and never automatically resumes it. Changing the viewed demo must not leave the previous video's audio playing or start the replacement automatically.
- Integrate playback lifecycle handling without taking ownership of the workout clock. Rest remains based on the existing absolute end time and elapsed wall-clock time; watching, backgrounding, and returning do not reset or extend it.
- Handle no network, load failure, embedding restrictions, removed/private/blocked videos, and other player errors as unavailable playback. Keep usable written guidance and dismissal available, offer retry for playback failure, and never block logging or replace the movement as a recovery action.
- Do not download or cache YouTube audiovisual files for offline viewing. Offline video support is not required. Existing bundled or user-supplied written guidance remains available without playback where it exists.
- Actual YouTube operation in the native sheet is a feasibility gate. If required lifecycle, accessibility, or provider-compliance behavior cannot be achieved, stop and surface the conflict rather than substituting another delivery method or silently weakening these requirements.

### Accessibility and privacy

- Every published demo must be understandable while muted, with brief written setup and movement cues available independently of successful playback. Any spoken instruction requires reviewed captions; do not assume automatic captions are correct or that all uploads have usable tracks.
- Support VoiceOver-labelled app controls, understandable equipment labels, a discoverable Close button, readable larger text, and scrollable cues. Verify navigation through the embedded player, exit from it, and return to the originating workout context without a focus trap.
- Keep the official player usable within YouTube's required dimensions and controls even at larger text sizes; app layout must adapt rather than cover or shrink the player into noncompliance.
- Update blanket claims of no ads, no analytics, and no third-party code wherever contradicted by the YouTube integration. Distinguish private workout storage from third-party video playback and accurately disclose possible ads, branding/related content, and playback-related data collection.
- Do not attach workout history, Health data, or private activity to player requests or report payloads. Do not claim that using an embed, disabling autoplay, or choosing a particular domain makes playback tracking-free.

### Reporting and correction

- Include Report wrong video in the guide for a mapped demo, including when that demo fails to play.
- Prepare an issue for the project's public GitHub tracker containing only exercise name and stable ID, selected demo equipment, video link, app version, and an optional user-written description. Encode prefilled values safely as content, not as additional URL parameters or executable navigation.
- Explain that reports are public and GitHub submission requires an account. Let the user inspect the report before handoff and review/submit it in GitHub; never create an issue automatically or report success merely because a browser opened.
- Provide Copy report when GitHub submission is unavailable or unwanted. Copying is user-initiated and is not delivery to the maintainer. Preserve the ability to cancel and return to the guide/workout without changing workout data. The app need not provision accounts, embed GitHub login, or detect authentication state.
- Do not collect or attach workout history, Health data, logs, or unrelated device diagnostics. Warn against including personal details in the optional description because the destination is public.
- A report flags an association for maintainer review, not automatic global removal. A maintainer confirms the problem, removes or replaces the affected reviewed mapping, and distributes the correction in an app update. Paid professional review is not required, but the agreed exact-movement and accessibility review still is.

## Testing Decisions

The user confirmed this testing split before spec publication. Assert externally observable behavior and state transitions, not private helpers, object layout, framework internals, or language operations. Prefer a few coherent integration scenarios over many trivial tests.

### One session-level behavioral integration seam

- Add the minimum production-used demo presentation/playback boundary necessary in the logging module. Exercise it with real WorkoutSession state and test SwiftData storage, substituting only external player, link-opening, and clipboard effects. This is a new integration seam, not an assertion that a player abstraction already exists.
- Cover the complete flow: resolve a reviewed association, open without autoplay, explicitly play, select another equipment demo, pause on background/interruption, remain paused on return, fail/retry, and dismiss with playback stopped.
- Assert the same workout exercise IDs, set identities, entered values, logged results, and current set before and after viewing. Viewing equipment must not execute substitution or mutate the workout. Use supplied dates at the existing rest-time API to prove that elapsed rest continues without introducing a test-only global clock.
- Cover custom and unmapped exercises, unavailable equipment-specific matches, and failed/blocked player responses without guessed replacements. Written cues and the ability to leave guidance remain available.
- Verify that report preparation contains only approved fields, correctly preserves punctuation and user text through URL encoding, requires explicit handoff/copy, and never treats a failed handoff or copying as successful submission. Do not perform real issue submissions in automated tests.
- Prior art: WorkoutSessionTests already exercise real session/rest behavior and fresh-store continuity; RunningWorkoutStateTests cover logging state coordination. Extend these behavioral patterns rather than pretending they already exercise rendered SwiftUI or embedded media.

### Existing library integrity seam

- Extend ExerciseLibraryTests to validate bundled demo associations: unique exercise/equipment keys, known stable IDs, valid equipment relationships, supported YouTube identifiers, and required review/caption metadata. Include unsupported/custom cases and rejection of invalid or ambiguous associations.
- Keep current ID uniqueness, equipment-requirement, and custom-library checks. A name-only edit must not require remapping a stable ID. Tests can enforce records and references, not whether a clip really demonstrates the right movement or whether captions are accurate.

### Native evidence automated state tests cannot provide

- Verify real official YouTube playback inside the iPhone sheet, including provider requirements and actual load errors. Do not count the HTML simulation or a fake player as proof of playback feasibility.
- Exercise explicit play, close/dismiss, background, interruption, and return with actual media. Verify audible pause/stop, no automatic restart, and no audio left behind by equipment changes or reporting handoff.
- Enter unfinished numeric text, expand an editor, log a set, and scroll the workout before opening help. Verify the editing context, entered values, logged sets, and logging position after dismissal and failure recovery. Model persistence assertions alone do not prove SwiftUI input or scroll retention.
- Verify actual VoiceOver traversal, entry/exit focus, equipment selection, reporting and Close controls, large accessibility text, scrollable cues, and reviewed captions. The requirement is usable native behavior, not merely the presence of accessibility labels.
- Verify a user-controlled GitHub handoff, the public/account notice, prefilled report review, cancellation, and Copy report fallback. Do not publish test reports to the public tracker without explicit authorization.
- Use the repository's private-simulator verification workflow for app UI evidence and real-device evidence where simulator behavior cannot establish the requirement. Document any unverified behavior honestly; it remains a gate, not a presumed pass.
- Manually review every shipped video association for exact movement/equipment, embedding availability, muted comprehension, and caption accuracy where speech exists. Recheck content when replacing a video; no automated metadata check substitutes for this review.

### Repository gates

- Run the normal repository check pipeline before pushing implementation: formatting, lint, package tests, and unsigned builds of all three apps. An iPhone-only addition must not break watchOS or Mac builds.
- Changes to the exercise library or its prompt-visible content also require the separate intelligence evaluation specified by repository orchestration. Do not report that evaluation as included in the normal check pipeline.

## Out of Scope

- Apple Watch or Mac video playback and cross-device demo handoff.
- Camera recording, form assessment, automatic exercise recognition, personalized coaching, or replacing professional instruction.
- Paid content procurement, professional-review purchases, video-provider subscriptions, paid backends, and any guarantee that ordinary internet/app distribution costs disappear.
- Runtime YouTube search, automatic approval of name-based guesses, a new discovery service, and universal video coverage for the library.
- Downloading/rehosting YouTube files, offline video, stripping provider controls/branding, ad blocking, or promises of tracking-free playback.
- Custom-exercise automatic videos, user-added video links, user video uploads, and video recording/production.
- Remote catalog refresh, instantaneous mapping revocation, forced updates, and server-side moderation.
- Persisting equipment viewed as workout equipment used, exercise substitution changes, and migrations of workout, plan, Health, CloudKit, backup, or transfer data.
- Automatic issue submission, private support infrastructure, in-app GitHub account management, and collecting workout/Health/log attachments for reports.
- Shipping the throwaway HTML prototype as production UI.

## Further Notes

- Implementation tracker: [Add beginner-friendly exercise demo videos](https://github.com/xchrisbailey/Transmute/issues/117). Publishing this spec does not implement the feature or approve any prototype media for release.
- Decisions were made in the completed [beginner-friendly exercise demos map](https://github.com/xchrisbailey/Transmute/issues/109). Its linked resolution comments are the source of the product choices; this file is the canonical implementation spec.
- The human selected the video-first layout in the [prototype and review instructions](https://github.com/xchrisbailey/Transmute/blob/eea6d39d478d8c950818670a75b6f14837ca6f85/Packages/TransmuteUI/Sources/TransmuteLogUI/Session/PrototypeExerciseDemo/README.md). Prototype media, form cues, and playback were illustrative; its evidence is not native playback or clinical validation.
- The [source investigation](https://github.com/xchrisbailey/Transmute/blob/41825243a41da1442a87fe8fbfb6b9b1438a20c6/docs/research/exercise-demo-sources.md) recorded provider constraints on 2026-11-01. Recheck current primary terms during implementation; do not treat an old research note as a permanent service guarantee.
- Relevant primary references: [YouTube developer policies](https://developers.google.com/youtube/terms/developer-policies), [required minimum functionality](https://developers.google.com/youtube/terms/required-minimum-functionality), [player parameters](https://developers.google.com/youtube/player_parameters), and [embedding help](https://support.google.com/youtube/answer/171780).
- The current code has no demo associations, embedded YouTube adapter, reporting composer, or remote library update mechanism. Existing tests do not prove the new native experience. These are implementation responsibilities, not completed work.
- Keep native player feasibility and accessibility verification early enough to expose conflicts before broad content population. If a requirement conflicts with official player constraints, return for a product decision rather than introducing cost or quietly changing the selected experience.
