# Shipping Transmute to TestFlight

The one-time setup that only the account holder can do, in order. After it, pushing a `v*` tag builds the iPhone app (with the watch app inside) and the Mac app in Xcode Cloud and puts both in TestFlight for internal testers.

You need a paid Apple Developer Program membership, Xcode 27 on your Mac, and admin rights on the GitHub repo.

## What gets signed

Four bundle IDs cover all six targets. The Mac app and its widgets reuse the iPhone IDs, so one App Store Connect record covers iPhone, Apple Watch and Mac (universal purchase, #20).

| Bundle ID | Targets | Capabilities |
|---|---|---|
| `computer.srcery.transmute` | TransmuteiOS, TransmuteMac | App Groups, iCloud (CloudKit), HealthKit (iPhone only), Push Notifications |
| `computer.srcery.transmute.widgets` | TransmuteWidgets, TransmuteMacWidgets | App Groups |
| `computer.srcery.transmute.watchkitapp` | TransmuteWatch | App Groups, iCloud (CloudKit), HealthKit, Push Notifications |
| `computer.srcery.transmute.watchkitapp.widgets` | TransmuteWatchWidgets | App Groups |

Shared by all of them:

- App Group `group.computer.srcery.transmute`, so widgets read the app's store.
- iCloud container `iCloud.computer.srcery.transmute`, for SwiftData sync.

Push Notifications is there because CloudKit sync wakes the app with silent pushes. The entitlements files say `development`; Xcode switches that to `production` when it signs for TestFlight.

## 1. Find your Team ID

[developer.apple.com/account](https://developer.apple.com/account) → **Membership details** → **Team ID** (10 characters, like `AB12CD34EF`). It isn't a secret. You'll paste it in two places.

## 2. Register the identifiers

[Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) → **Identifiers** → **+**.

Xcode's automatic signing can create most of this for you, but registering it by hand first means Xcode Cloud and your Mac agree from the start.

1. **App Groups** → Continue. Description `Transmute`, identifier `group.computer.srcery.transmute`.
2. **iCloud Containers** → Continue. Description `Transmute`, identifier `iCloud.computer.srcery.transmute`.
3. **App IDs** → **App** → Continue, once per row of the table above. Choose **Explicit** and type the bundle ID. If it asks for platforms, include iOS and macOS for the first two. Tick the capabilities from the table, then after saving each one:
   - **App Groups** → **Configure** → tick `group.computer.srcery.transmute`.
   - **iCloud** → choose **Include CloudKit support** → **Configure** → tick `iCloud.computer.srcery.transmute`.

You don't need to make certificates or provisioning profiles. Xcode and Xcode Cloud manage those.

## 3. Sign locally once

This proves the capabilities line up before the cloud tries.

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
# set DEVELOPMENT_TEAM to your Team ID in Config/Local.xcconfig
xcodegen generate
open Transmute.xcodeproj
```

In Xcode → **Settings** → **Accounts**, make sure your Apple ID is signed in with the team. Then run **TransmuteiOS** on your iPhone (the watch app installs with it) and **TransmuteMac** on your Mac. If a target's **Signing & Capabilities** tab shows a red error, it names the capability or ID that's missing from step 2.

While the app is running on your phone, use it end to end: onboard, brew a plan, log a workout, log bodyweight. That creates every CloudKit record type in the **Development** environment, which step 4 needs.

This is also the moment for the device checks still open on #4 (sync between two devices) and #15 (heart rate, Health save and mirroring on a real iPhone and watch).

## 4. Deploy the CloudKit schema

TestFlight and App Store builds talk to CloudKit's **Production** environment, which starts empty. Until the schema is deployed there, TestFlight builds won't sync.

1. Open the [CloudKit Console](https://icloud.developer.apple.com/) → **CloudKit Database** → `iCloud.computer.srcery.transmute`.
2. Check **Schema** → **Record Types** in Development lists the `CD_` types SwiftData made (Profile, Plan, Workout and the rest).
3. **Deploy Schema Changes…** → **Deploy**.

Repeat this whenever a SwiftData model changes, before shipping the build that changes it. Production schema can be added to but never have fields removed, so treat a deployed field as permanent.

## 5. Create the App Store Connect record

[App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.

- **Platforms**: tick **iOS** and **macOS**. The watch app ships inside the iOS app, so there's no separate watchOS box to tick.
- **Name**: `Transmute`. App names are unique across the store; if it's taken, use something like `Transmute: Workout Planner`. Only the store listing uses this, not the home screen.
- **Primary language**: English (U.S.).
- **Bundle ID**: `computer.srcery.transmute`.
- **SKU**: `transmute` (only you see it).
- **User Access**: Full Access.

Picking both platforms with the same bundle ID is what makes it universal purchase.

## 6. Set up TestFlight internal testing

In the new app → **TestFlight** → **Internal Testing** → **+**:

1. Name the group `srcery`. Leave **Enable automatic distribution** on, so every build lands without a click.
2. Add yourself. Internal testers have to be App Store Connect users on the team, which you are as account holder.

Install the **TestFlight** app on your iPhone and your Mac and sign in with the same Apple ID. The watch app arrives through the iPhone: in the iPhone **Watch** app, turn on automatic app install or install Transmute from **Available Apps**.

## 7. Connect Xcode Cloud

Xcode Cloud clones the repo, runs `ci_scripts/ci_post_clone.sh` (which installs XcodeGen, generates the project and writes the signing settings), archives, signs with cloud-managed certificates and uploads to TestFlight. The Developer Program includes 25 compute hours a month.

1. With `Transmute.xcodeproj` open from step 3, choose the **TransmuteiOS** scheme, then **Product** → **Xcode Cloud** → **Create Workflow…**.
2. Select the **Transmute** app, then **Next**. Xcode asks to connect to GitHub: **Grant Access**, sign in, and install the Xcode Cloud GitHub app on `xchrisbailey/Transmute` only.
3. Edit the default workflow before saving it:
   - **General**: name it `TestFlight`.
   - **Environment**: Xcode **27** (latest release), macOS latest. Under **Environment Variables** add `TRANSMUTE_TEAM_ID` with your Team ID. Leave **Secret** off; it isn't one.
   - **Start Conditions**: delete the branch condition, add **Tag Changes**, and set it to tags beginning with `v`.
   - **Actions**: delete any Build or Test actions. Add **Archive** for **iOS** with scheme `TransmuteiOS`, deployment preparation **TestFlight (Internal Testing Only)**. Add another **Archive** for **macOS** with scheme `TransmuteMac`, same deployment preparation.
   - **Post-Actions**: add **TestFlight Internal Testing** for each archive, group `srcery`.
4. **Save**. Xcode offers to start a build; skip that, because no tag exists yet.

The project file isn't committed; the post-clone script generates it. If the workflow editor refuses to save because it can't find `TransmuteiOS` or `TransmuteMac` in the repository, reply in the thread with the exact message and we'll switch approach.

## 8. Ship the first build

```bash
git tag v0.1.0
git push origin v0.1.0
```

Watch it in Xcode (**Report navigator** → **Cloud**) or App Store Connect → **Xcode Cloud**. When processing finishes, TestFlight shows the build, with the last few commit subjects as **What to Test**, and your devices offer the install.

For later builds, bump `MARKETING_VERSION` in `project.yml` when the version should change, then tag. Xcode Cloud sets the build number itself and counts up from 1. If you ever upload a build by hand from Xcode, raise the next number in App Store Connect → **Xcode Cloud** → **Settings** → **Build Number** so the two don't collide.

## If something fails

| Symptom | Likely cause |
|---|---|
| Post-clone fails with `set TRANSMUTE_TEAM_ID` | The environment variable from step 7 is missing or misspelled. |
| Signing fails naming a capability or App Group | The App ID in step 2 is missing that capability, or it isn't configured with the group or container. |
| `ITMS-90xxx` about an invalid bundle or missing icon | Upload validation. The log names the target; the iOS, Mac and watch icons are all in `Apps/Shared/Assets.xcassets/AppIcon.appiconset`. |
| TestFlight build runs but nothing syncs | The Production CloudKit schema wasn't deployed (step 4), or is behind the models. |
| Build stuck "Missing Compliance" | Shouldn't happen: `ITSAppUsesNonExemptEncryption` is `NO` in every Info.plist. Answer "None of the algorithms mentioned above" if it does. |
| Watch app missing on the watch | Install it from the iPhone **Watch** app; TestFlight on the iPhone owns it. |

## A local fallback

To ship without Xcode Cloud, with signing set up through step 6: in Xcode choose **Any iOS Device (arm64)**, then **Product** → **Archive** → **Distribute App** → **TestFlight Internal Only**. Do the same with **TransmuteMac** and **My Mac**. Raise `CURRENT_PROJECT_VERSION` in `project.yml` before each manual upload, since uploads need a new build number.
