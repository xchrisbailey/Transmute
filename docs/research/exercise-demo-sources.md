# Exercise demonstration video sources

Research date: **2026-11-01**. Factual investigation for [Find trustworthy, usable sources for exercise demo videos](https://github.com/xchrisbailey/Transmute/issues/110), part of [Find the way to beginner-friendly exercise demos](https://github.com/xchrisbailey/Transmute/issues/109). This is not a content-policy decision or implementation spec.

## Answer

There are viable sources, but **publicly watchable is not permission to download, bundle, or redistribute**. Two starting approaches deserve a human choice:

- **Best control:** a deliberately small, professionally reviewed set of owned/commissioned clips, or purchased files under an explicit commercial app licence. This permits native playback without a third-party player; offline distribution must be covered by the actual rights grant. ExerciseVideoAPI is a concrete downloadable-file candidate, not an endorsement or a verified chain-of-title finding.
- **Fastest documented hosted route:** MuscleWiki's paid API expressly supports native iOS streaming, including AVPlayer media tokens. It forbids offline video storage and rehosting. It requires its embedded branding and a legal disclosure. Its catalogue needs per-asset editorial review: a checked variant page contained instructions for a different movement.

YouTube embeds are technically feasible inside an iPhone app but impose player UI, advertising/privacy exposure, and availability risk. ExRx offers credible exercise-reference content and app licensing, but public information does not settle price or offline rights; its Economy browser-link plan does not meet the map's in-app direction. Your Move is a hosted alternative with advertised on-device offline rights at a higher tier, subject to contract clarification. None establishes complete exact coverage of Transmute's library. [M1–M3, E1–E3, Y1–Y4, V1–V2, U1–U2]

**Recommendation, not selection:** start with a small explicitly reviewed manifest of exact exercise matches and the existing written cues, rather than automatically mapping an entire vendor library. Prefer owned/licensed files if offline, no third-party viewer tracking, and UI control matter most; evaluate MuscleWiki if streaming-only and recurring cost are acceptable. Do not silently replace an unsupported variant with its parent movement. No provider was contacted, no account created, nothing purchased, and no playback integration implemented.

## Scope and evidence limits

Primary provider documentation, public exercise pages and the checked-out library were inspected. All external URLs below were accessed **2026-11-01**; listed page-update dates are publisher dates, not access dates. Prices are public dollar-denominated list prices, before any unverified taxes or negotiated terms. Counts and quality credentials are provider claims, not independent certification.

This was a document/metadata investigation, **not a motion-by-motion video audit or an iPhone playback test**. Public-page matches below are candidates, not approved assets. No paid API catalogue was accessed. Captions, absence of ads, accuracy of every frame, author permissions, and distribution rights are not inferred from an MP4 URL. There is no existing research-note directory on the base revision, so this note uses `docs/research/`.

## Grounding in the current library

Base revision: [`d5fba76`](https://github.com/xchrisbailey/Transmute/tree/d5fba76). The bundled [`exercises.json`](https://github.com/xchrisbailey/Transmute/blob/d5fba76/Packages/TransmuteCore/Sources/TransmuteCore/Resources/exercises.json) contains **298 entries**: 151 strength, 48 mobility, 40 power, 33 speed/agility, and 26 conditioning. These were counted directly from `exercises`, grouped by `category`.

[`LibraryExercise`](https://github.com/xchrisbailey/Transmute/blob/d5fba76/Packages/TransmuteCore/Sources/TransmuteCore/Library/LibraryExercise.swift) already has stable IDs, aliases, equipment alternatives, unilateral status, beginner cues and mistakes, plus easier/harder links. It also accommodates user-created `custom-` IDs. The inspected type has no video association. This is context only; no schema change is proposed here.

The catalogue is not just a list of gym lifts. Tennis footwork, reactive drills, interval prescriptions and rehabilitation-style movements make a universal gym-video coverage promise implausible without an audit. Equipment alternatives also mean that one ID can legitimately describe more than one implement; a dumbbell demonstration does not prove a kettlebell variant is covered.

### Representative exact-match checks

“Candidate” means the public description matches the distinguishing movement; footage and licensed API identity still need review.

| Transmute entry and defining detail | Primary-source evidence | Result / substitution to reject |
| --- | --- | --- |
| `bodyweight-squat`: unweighted squat | MuscleWiki's [glute directory](https://musclewiki.com/exercises/glutes/3) lists Bodyweight Squat with knee/hip flexion and standing return. ACE's [Bodyweight Squat](https://www.acefitness.org/resources/everyone/exercise-library/135/bodyweight-squat/) specifies no equipment. | Candidate movement match. ACE is a technique reference, not an established video distribution licence. Do not substitute loaded back squats. |
| `dumbbell-romanian-deadlift`: two dumbbells, hip hinge, soft knees | MuscleWiki's [Dumbbell Romanian Deadlift](https://musclewiki.com/exercise/dumbbell-romanian-deadlift), also described in [its lower-back directory](https://musclewiki.com/exercises/lowerback/2). | Candidate. Not conventional deadlift or stiff-leg deadlift, which are separate local entries. |
| `single-leg-romanian-deadlift`: unsupported single-leg hinge with dumbbell or kettlebell | ACE's [Single-arm, Single-leg Romanian Dead Lift](https://www.acefitness.org/resources/everyone/exercise-library/127/single-arm-single-leg-romanian-dead-lift/) uses a dumbbell; its [Single Leg Romanian Dead Lift](https://www.acefitness.org/resources/everyone/exercise-library/350/single-leg-romanian-dead-lift/) instead uses a cable and includes an arm pull. | The similarly named cable exercise is **not** the local weighted free-weight variant. Even reputable libraries require equipment and execution checks. No ACE reuse rights established. |
| `heels-elevated-goblet-squat`: chest-held weight, heels on plate/wedge | MuscleWiki's [Dumbbell Heels Up Goblet Squat](https://musclewiki.com/exercise/dumbbell-heels-up-goblet-squat) exists by name, but the fetched instructions say “Take a half kneeling stance” and rotate a dumbbell to the opposing side. | **Hold/reject pending review.** A real title/instruction inconsistency, not evidence that the actual video shows the wrong exercise. Neither plain goblet squat nor a kneeling woodchop is an acceptable substitute. |
| `kettlebell-swing`: two-hand Russian swing to chest height | MuscleWiki's [Kettlebell Swing](https://musclewiki.com/exercise/kettlebell-swing), described in [its directory](https://musclewiki.com/exercises/lowerback/2), explicitly reaches chest height. | Candidate; reject an overhead/American swing or single-arm swing. |
| `deadlift`: conventional barbell lift | ExerciseVideoAPI [sample](https://exercisevideoapi.com/samples), metadata ID 242, explicitly says conventional deadlift. | Candidate; not sumo, trap-bar or Romanian deadlift. |
| `chin-up` versus `pull-up`: underhand versus overhand grip | ExerciseVideoAPI's [“Standard Under hand Grip Pull Ups” sample](https://exercisevideoapi.com/samples), ID 117, explicitly describes chin-ups. Local cues distinguish both grips. | Candidate for **chin-up only**, despite the provider's “Pull Ups” title. |
| `dumbbell-bench-press`: flat bench, two dumbbells | ExerciseVideoAPI [sample](https://exercisevideoapi.com/samples), ID 137, specifies dumbbell and bench. | Candidate; do not reuse for incline, barbell, or single-arm local entries. |
| `back-squat` versus `pause-back-squat`: high/upper-back bar placement versus two-second bottom pause | NSCA's [High Bar Back Squat](https://www.nsca.com/education/videos/exercise-technique-high-bar-back-squat/) is a named institutional technique reference (May 2015). ExerciseVideoAPI's [Barbell Squats sample](https://exercisevideoapi.com/samples), ID 237, describes a back squat without promising a pause. | Back-squat candidates, **not** pause-back-squat coverage. NSCA page availability does not grant app reuse rights. |
| `pallof-press` versus `half-kneeling-pallof-press` | ExerciseVideoAPI [metadata example](https://exercisevideoapi.com/) ID 299 is Cable Pallof Press; it does not establish the half-kneeling, inside-knee-down setup. | Candidate for a cable Pallof press only after stance review. Kneeling version remains unconfirmed. |
| `spider-drill`: tennis court/cone runs returning to centre | ExerciseVideoAPI's [Spider Plank sample](https://exercisevideoapi.com/samples), ID 39, is plank knee-to-elbow movement. | **Not a match.** A name-token match would be materially wrong. Exact tennis drill coverage unconfirmed. |
| `tennis-point-intervals`, `kettlebell-complex`, `tyler-twist` | Local cues respectively prescribe 10s work/20s rest, swing–clean–press–squat without putting down the bell, and controlled flexible-bar wrist work. | No exact vendor match established in this investigation. Generic footwork, one kettlebell swing, or a dumbbell wrist curl must not stand in. |

These examples demonstrate common matches, naming traps, a provider metadata error and specialist gaps; **they do not calculate coverage percentage**. A vendor's 300, 1,988 or 2,200 exercises is not a denominator for our 298 IDs.

## Source comparison

### Owned or commissioned clips

Rights depend on who makes the footage and the agreement, not merely who pays. The US Copyright Office explains that a commissioned work is not automatically a work made for hire; qualifying categories and a signed written agreement matter. This is US guidance, not a conclusion about the project's jurisdiction. [C1]

- **Permission needed:** a documented ownership transfer or licence covering commercial iOS display, editing/transcoding, CDN hosting, app-bundle distribution, on-device downloads/offline viewing, intended territories and term. Obtain performer/voice/location releases and music rights where relevant. Those are procurement requirements, not rights already held.
- **Playback:** owned/licensed local or HTTPS assets can use Apple's native `VideoPlayer`/AVPlayer path; local and remote media are documented. Actual codec, caption tracks and device behaviour still need validation. [A1]
- **Branding/privacy:** with sufficient rights, Transmute controls branding and can avoid a third-party embedded player and its ads. Local files can avoid a playback network request; a chosen CDN still has its own logging/privacy obligations. This is a design capability, not a claim that hosting is automatically private.
- **Cost/coverage:** no defensible public production quote; trainer review, filming, equipment, editing, captioning, hosting and ongoing replacement cost remain unpriced. Exact specialist variants can be commissioned, but only those produced are covered.
- **Accessibility:** production can deliberately show setup, full range, both sides and useful camera angles, with edited captions for speech and text descriptions for visual information. Ownership alone does not make footage accessible or technically correct.

### Purchased files: ExerciseVideoAPI

The provider advertises **300 filmed HD MP4s**, up to 30 seconds, a **$699 one-time perpetual non-exclusive commercial licence** for the purchaser's own products, and a $1,999 agency option. It explicitly advertises self-hosting on a CDN/server **or app bundle**, white-labelling and re-encoding, while retaining copyright and prohibiting resale/redistribution of raw files. Thus “own outright” in the headline means licensed files, **not transferred copyright**. [V1]

- **Offline/download:** developer downloads and bundled distribution are expressly advertised. This supports an app-bundle offline path; it is **not permission to give users standalone downloadable MP4s**. Retain and inspect the actual delivered licence before buying/shipping, especially any separately cached offline mode and end-user extraction obligations. The full licence is described as being in `Docs.zip`; it was not acquired.
- **Attribution/ads/privacy:** white-label/unbranded delivery is explicit. A full attribution clause was not verified; do not equate white-label with every notice being waived. Self-hosted delivery needs no vendor embedded player, so no vendor-player ad dependency; infrastructure privacy becomes Transmute's responsibility. [V1]
- **Quality/accessibility:** “certified trainer” is a provider claim with no named credential verified here. Samples and structured metadata are public, including conventional deadlift and dumbbell bench press. Captions, audio descriptions and review process are not established. A 20 GB advertised source download is not an appropriate assumed mobile payload; compression/delivery would need separate planning. [V1–V2]
- **Availability:** purchased files reduce runtime vendor dependence but do not eliminate takedown/rights problems or the need to retain a licence. No purchase or sample-media download was performed.

### Hosted native streaming: MuscleWiki API

The **2026-10-08 API terms** control over conflicting marketing descriptions. Paid plans include commercial app use; media must play within the application using API-streamed URLs. No rehosting, bulk harvesting or offline media storage. Text metadata may be cached for 30 days; video only transiently for playback. Terms section 3 and FAQ/header guidance differ in image-cache specificity (the FAQ says thumbnails private on-device for 24 hours, bodymaps `no-store`); do not rely on an expansive reading to cache media. [M1–M2]

- **iPhone:** provider explicitly documents MP4/HTTPS streams and backend-minted 15-minute media tokens usable by AVPlayer without custom headers. Permanent API keys belong on the backend, not in the app binary. Transparent non-storing proxying is also permitted. This is documented support, not a tested integration. [M1–M2]
- **Cost:** Testing $10/month/1,000 calls; Growth $39.99/30,000; Professional $99.99/100,000; Enterprise $199.99/300,000. Free access is playground-only, not an app tier. **Every stream Range request counts**, so calls are not plays or users. Growth and above offer prepaid 5,000-call top-ups for $10; quota exhaustion otherwise returns 429. Cost cannot be estimated without observed player requests and expected usage. Prices can change with seven days' notice. [M1–M3]
- **Attribution:** exact disclosure “Exercise data and videos provided by MuscleWiki.com” in terms/privacy/equivalent; embedded branding must remain unobscured. Visible linked in-app credit is encouraged, not required. Do not crop or cover the watermark. [M1]
- **Ads/privacy:** documented direct media avoids a YouTube-style player requirement, but no contractual ad-free or no-logging guarantee was established. Provider/CDN still receive streaming traffic. No API-specific retention/subprocessor commitment was verified; assess actual data flow and contract before selection. Do not send workout logs or Health data just to retrieve a demo. [M1–M2; last sentence is recommendation]
- **Trust/accessibility/availability:** provider claims 1,988 exercises, 7,700+ videos, usually front/side views and male/female demonstrators, plus multilingual text. That is useful non-audio support, not proof of captions or fitness-for-purpose. The terms disclaim accuracy and allow exercise/media removal; the API is unversioned. The checked heels-up goblet squat instructions require manual review before trusting even apparent exact matches. [M1–M2; table above]

### Licensed reference library: ExRx

ExRx advertises 2,100+ API exercises and elsewhere 2,200+ site exercises, including weight training, stretches, plyometrics and cardio. These mixed counts are not a verified API inventory. It supplies preparation/execution instructions, equipment and bilateral/unilateral fields, thumbnails and **Vimeo video**. Public terms were updated **2026-08-10**. [E1, E3]

- **Rights/cost:** app use has a dedicated licence/application process; public access or the separate personal offline-download product does not confer app distribution rights. Economy provides limited fields and a button that opens the exercise page in the user's browser. Premium includes videos and instructions. Exact fees, quotas, caching/download/offline rights, cancellation handling and full attribution clauses were **not publicly established by the checked pages**. No inquiry was sent. [E1–E3]
- **iPhone:** licensed mobile-app use is explicitly supported, but the public page identifies Vimeo media, not a guaranteed AVPlayer file grant. The player, embedding-domain restrictions and iOS configuration depend on the negotiated delivery agreement. Economy is a poor fit for the confirmed in-app experience. [E1–E2]
- **Trust/accessibility:** longstanding specialist reference and detailed classification make it worth considering; endorsement claims do not remove the need for a qualified per-clip review. Written preparation/execution supports comprehension without audio, but API-caption coverage was not established. [E1]
- **Ads/privacy/availability:** the public site says it relies on ads. Do not assume that public-site behaviour equals the paid API experience, or that Vimeo hosting is tracking-free. Contract must settle player branding/ads/privacy, cache and removal conditions; default public terms prohibit removing watermarks and republishing without permission. [E1, E3]

### External embeds: curated YouTube videos

Use only rights-holder uploads with embedding enabled, through the official player and applicable terms. YouTube allows uploaders to disable embedding and restricts some age-limited playback to YouTube. **Embedding does not grant a raw-file licence.** The developer policies prohibit downloading/caching audiovisual copies without YouTube's prior written approval and prohibit offline playback. A creator's separate file licence would need a separate delivery path; it is not permission to extract the YouTube stream. [Y1, Y4]

- **iPhone in-app:** current requirements explicitly support `WKWebView`; this is an embedded web player, **not a native AVPlayer media URL**. Supply app identity via the required Referer/base URL configuration; missing identity can cause error 153. `playsinline=1` plus inline-enabled WebView supports inline iOS playback. Minimum player viewport is 200×200 pixels. [Y2–Y4]
- **UI/branding/ads:** no covering any player part with overlays; retain YouTube identity and controls as required. `modestbranding` does nothing, and `rel=0` limits related videos to the same channel rather than removing them. Ads cannot be blocked by the integration (developer policies). No autoplay is compatible with the map, but does not remove these constraints. [Y1–Y3]
- **Privacy:** player load already shares basic data; playback shares more. `autoplay=false` limits pre-interaction sharing, not all collection. Privacy-enhanced embeds do not guarantee zero tracking or no ads; YouTube's help describes them as website-only and directs applications to WebView embedding. Do not promise native-app “no cookies” based on the domain name. Required privacy/terms disclosures still apply. [Y1, Y4]
- **Cost/accessibility/coverage:** no per-clip purchase price is specified by these embed docs, but editorial selection, monitoring, API quota/compliance and privacy costs remain. Caption controls can request existing tracks, not create accurate captions. Review each upload's captions and non-audio instructional completeness. Availability, region restrictions, embedding permission and creator edits/removals remain external. A reputable organisation's exercise page (for example NSCA's high-bar squat) is a discovery/trust signal, not proof of an embeddable YouTube asset or redistribution rights. [Y1–Y4; NSCA link in table]

### Hosted offline-capable alternative: Your Move

Its pricing page advertises 2,005+ videos, in-app iOS use via Bunny CDN, $19/month Starter with watermark, $29 Pro clean video, and **$79 Scale with on-device offline cache**. Self-hosting requires a separate licence. Monthly Starter/Pro have rolling distinct-video caps of 250/350, separate from video-minute quotas; yearly plans and Scale remove the variety cap. This makes the fine print relevant even to our 298-entry catalogue. [U1]

API terms restrict use to registered brands, prohibit sharing raw files/responses, make URLs time-limited, and require stopping video use/deleting cached files when the subscription ends. The general terms shown below the API supplement are dated **2025-08-07**; the supplement itself has no verified date. Pricing says excess minutes never block requests, whereas API terms reserve throttling/degradation/suspension above limits. Treat availability guarantees as **unsettled**, not unlimited service. Brand/attribution requirements also need the actual issued Brand License; general IP notices coexist with clean-video marketing. [U1–U2]

This is a realistic **conditional alternative**, not a cleared source: exact variant coverage, clinical/editorial credentials, captions, native-player stream format, offline expiry enforcement, ad/analytics commitments and contract precedence were not verified. Do not equate no watermark with no required credit, or offline cache with perpetual ownership. [U1–U2]

## What the eventual sourcing decision must settle

The factual investigation can close without selecting a provider. The human must still choose the trade-off between recurring hosted streaming, ownership/licensed-file procurement, offline support, third-party branding/privacy and coverage breadth. No new product decision is made here.

Before any content ships, the selected approach needs these concrete gates (recommendations, not approved acceptance criteria):

1. **Rights record per asset:** source/rights holder, exact licence/version/date, app/territory/term scope, host versus embed versus bundle/cache permission, attribution and termination/removal rules. Never commit purchased raw footage to this public research branch.
2. **Exact mapping review:** local stable ID plus vendor asset ID; inspect implement, grip, load position, stance, support, unilateral/bilateral action, range, tempo/pause and full drill sequence. Keep an explicit unsupported state for custom entries and unmatched variants. A parent's easier/harder relationship is not a video equivalence.
3. **Editorial review:** a qualified exercise professional checks setup, execution, safety information and compatibility with existing cues. Quarantine conflicting titles/instructions instead of copying provider cues automatically.
4. **Accessibility review:** understandable while muted, useful written setup/form cues independent of network playback, captions for speech, and text alternatives describing essential visual information. Demonstrator angles alone are not accessibility conformance. Audit real selected media; no provider-wide caption promise was verified here.
5. **Later device evidence:** user-initiated in-app play and close, progress preserved, interruption handling, unavailable/deleted/expired/quota-limited content, offline behaviour consistent with licence, captions/VoiceOver and network/privacy disclosures. No such behaviour is claimed as tested by this research.

The inaccessible or contract-only facts above are documented procurement/verification limits, not permission inferred from silence. Future investigation should be scoped after the human's content-policy choice; this research does not buy access, contact vendors, open implementation work, or resolve any human-decision ticket.

## Primary-source register

All accessed **2026-11-01**. Undated means no meaningful publication/update date was established on the checked page.

- **M1:** [MuscleWiki API terms](https://api.musclewiki.com/api-terms), updated 2026-10-08; sections 1–8 govern use, media, caching, removal and attribution.
- **M2:** [MuscleWiki API FAQ](https://api.musclewiki.com/faq), undated; native-player tokens, formats, count, streaming metering and cache details.
- **M3:** [MuscleWiki pricing](https://api.musclewiki.com/pricing), undated; monthly prices and plan limits.
- **E1:** [ExRx content licensing](https://exrx.net/Store/Other/Licensing), undated; app API, categories, fields and Vimeo media.
- **E2:** [ExRx API FAQ](https://exrx.net/Store/Other/APIFAQ), undated; Economy browser links versus Premium video and inquiry-only pricing.
- **E3:** [ExRx terms of use](https://exrx.net/Notes/Legal), updated 2026-08-10; public use, watermark and republication restrictions.
- **Y1:** [YouTube developer policies](https://developers.google.com/youtube/terms/developer-policies), accessed current version; III.A disclosures, III.E content/offline/data handling, III.F player/ads rules.
- **Y2:** [YouTube required minimum functionality](https://developers.google.com/youtube/terms/required-minimum-functionality), footer updated 2026-11-01; iOS WebView identity, dimensions and overlays.
- **Y3:** [YouTube player parameters](https://developers.google.com/youtube/player_parameters), footer updated 2026-11-01; captions, inline iOS, branding deprecation and related videos.
- **Y4:** [YouTube embedding help](https://support.google.com/youtube/answer/171780), undated; embedding permission, age restrictions, error 153 and privacy-enhanced limitations.
- **V1:** [ExerciseVideoAPI product/licensing/pricing](https://exercisevideoapi.com/), undated; purchased-file model, prices, app bundle and raw-file restrictions. Full delivered contract not acquired.
- **V2:** [ExerciseVideoAPI samples and metadata](https://exercisevideoapi.com/samples), undated; named public exercise candidates and variant distinctions.
- **U1:** [Your Move API pricing](https://ymove.app/exercise-api/pricing), undated; tier-dependent watermark/offline/self-hosting and usage limits.
- **U2:** [Your Move terms and API supplement](https://ymove.app/terms-and-conditions), general terms updated 2025-08-07; brand and active-subscription restrictions.
- **C1:** [US Copyright Office: Work Made for Hire](https://copyright.gov/register/se-hire.html) and [Title 17 chapter 2](https://www.copyright.gov/title17/92chap2.html), current pages; commissioning is not automatic copyright ownership. Legal jurisdiction/application not determined here.
- **A1:** [Apple VideoPlayer documentation](https://developer.apple.com/documentation/avkit/videoplayer), read through its [official documentation JSON](https://developer.apple.com/tutorials/data/documentation/avkit/videoplayer.json), undated; native UI and local/remote AVPlayer input.

Movement-page primary citations and their access date are in the matching table. The report deliberately preserves short descriptions of the observed mismatches rather than copying a provider exercise dataset.
