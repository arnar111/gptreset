# Install Codex Reset Tracker on an iPhone without a Mac

GitHub Actions builds the app on a Mac runner and uploads it to TestFlight. You install that build with the TestFlight app. You do not need Xcode or a Mac.

Sign in to Apple with the Apple ID that owns the Developer Program membership (`addibackup92@gmail.com`). A paid Apple Developer Program membership is required. TestFlight is not available on a free Apple ID.

The workflow is [`.github/workflows/ios-testflight.yml`](../.github/workflows/ios-testflight.yml).

| When | What it does |
| --- | --- |
| Pull request | Compiles the app, the widget, and the notification extension for the iOS Simulator. No Apple secrets. No upload. |
| Push to `main` | Same compile, then archives and uploads to TestFlight if the four secrets below are set. If they are missing, the upload is skipped and the compile can still pass. |
| Actions → **iOS TestFlight** → **Run workflow** | Same upload, on the branch you pick. This run fails immediately if a secret is missing. |

Each upload uses marketing version `1.0.0` and a build number of `<workflow run>.<attempt>`, so a re-run does not collide with the previous upload.

## 1. Create the identifiers

Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).

### App Group

Identifiers → the filter menu → **App Groups** → **+**.

- Description: `Codex Reset Tracker`
- Identifier: `group.com.arnar111.codexresettracker`

Register it.

### App IDs

Identifiers → **App IDs** → **+** → **App**. Create these three. Use **Explicit** bundle IDs, not a wildcard.

**App**

- Description: `Codex Reset Tracker`
- Bundle ID: `com.arnar111.codexresettracker`
- Capabilities: **App Groups**, **Push Notifications**
- App Groups → Configure → enable `group.com.arnar111.codexresettracker`

**Widget**

- Description: `Codex Reset Tracker Widget`
- Bundle ID: `com.arnar111.codexresettracker.widget`
- Capabilities: **App Groups** → the same group

**Notification extension**

Register this App ID as well. The archive signs three bundle IDs, and the upload fails if this one is missing.

- Description: `Codex Reset Tracker Notification`
- Bundle ID: `com.arnar111.codexresettracker.notification`
- Capabilities: none. Do not enable App Groups on this id. The extension does not read the shared store. App Groups stay on the app id and the widget id only.

Save each one. Push Notifications belongs only on the app id. The widget and the app must both include the App Group, or the widget cannot read the shared reset data.

You do not register iPhones, and you do not create a distribution certificate or a provisioning profile by hand. TestFlight uses App Store profiles, which are not tied to a device. The workflow asks Xcode to create those profiles.

## 2. Create the App Store Connect app

Open [App Store Connect → Apps](https://appstoreconnect.apple.com/apps) → **+** → **New App**.

- Platforms: **iOS**
- Name: `Codex Reset Tracker`
- Primary language: English
- Bundle ID: `com.arnar111.codexresettracker` (it appears in the list only after step 1)
- SKU: `codex-reset-tracker`
- User Access: Full Access

Create the app. You can leave screenshots and the description empty until you want a public App Store release. TestFlight does not need them.

## 3. Create the App Store Connect API key

Open [Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).

Generate a **Team** key:

- Name: `GitHub Actions`
- Access: **Admin**

Admin is required. This workflow has no Mac, so Xcode on the runner must create the Apple Distribution certificate and the App Store profiles. An App Manager key can upload a build that is already signed, but it cannot create those signing assets. A Developer key is not enough either.

Download the `.p8` file when Apple offers it. Apple shows that file once. Store it somewhere private, not in this git repository.

On the same page, copy:

- **Issuer ID** (the UUID at the top of the keys page)
- **Key ID** (the 10-character id on the new key’s row)

Also copy the **Team ID** from [Membership details](https://developer.apple.com/account) (10 characters). It is the same value you will use for `APPLE_TEAM_ID` and, later, for `APNS_TEAM_ID` if you deploy push.

## 4. How signing works in CI

Simulator compiles stay on **Automatic** signing and do not use a distribution identity.

The TestFlight archive uses **Manual** signing and the **Apple Distribution** identity. Xcode rejects Automatic signing combined with that identity. Before the archive, the workflow uses the API key to create the three App IDs if they are missing, one Apple Distribution certificate, and an App Store profile for each bundle id. The certificate’s private key is encrypted and kept in the Actions cache so the next run reuses it instead of minting another certificate. App Store profiles do not contain device UDIDs. The workflow does not register devices.

The IPA export uses method `app-store-connect` (Apple’s current name for `app-store`), destination `export`, and the same manual distribution profiles. `xcrun altool` (or Transporter) uploads it.

Release archives use `CodexResetTrackerRelease.entitlements`, so TestFlight builds talk to production APNs (`sandbox: false`). That is separate from the API key above. Push still needs the worker secrets in the README (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_PRIVATE_KEY`). The APNs `.p8` and the App Store Connect `.p8` are different files.

Do not commit either file. `.gitignore` already ignores `*.p8`, `.env`, and `backend/.dev.vars`.

## 5. GitHub Actions secrets

Open [the repository’s Actions secrets](https://github.com/arnar111/gptreset/settings/secrets/actions) → **New repository secret**. Create exactly these four. The names are case-sensitive.

| Secret | What to paste | Where you copied it |
| --- | --- | --- |
| `ASC_KEY_ID` | Key ID, 10 characters | App Store Connect API keys table |
| `ASC_ISSUER_ID` | Issuer ID, a UUID | Top of the App Store Connect API page |
| `ASC_PRIVATE_KEY` | The entire `.p8` file, including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` | The file you downloaded once |
| `APPLE_TEAM_ID` | Team ID, 10 characters | developer.apple.com → Membership details |

`ASC_PRIVATE_KEY` is a multiline secret. Paste the file as-is. If the paste drops the line breaks, base64-encode the file and paste that single line instead. The workflow accepts either form.

`.env.example` lists the same names as blank placeholders so they are easy to find. The workflow does not read `.env`. Nothing in that file should ever be a real key.

There is no fifth secret for a certificate password, a `.p12`, or a match passphrase.

## 6. Run the upload

After the secrets exist and this workflow is on `main`:

1. Open [Actions → iOS TestFlight](https://github.com/arnar111/gptreset/actions/workflows/ios-testflight.yml).
2. **Run workflow**.
3. Branch: `main`.
4. **Run workflow** again to start it.

A push to `main` does the same upload without the manual click.

The job is **Upload to TestFlight**. A green run means App Store Connect accepted the binary. Processing still takes a few minutes after that.

## 7. Install with TestFlight

1. In App Store Connect, open the app → **TestFlight**.
2. Wait until the build leaves “Processing”. The first time, if Apple asks about encryption, answer that the app does not use non-exempt encryption. The project already sets `ITSAppUsesNonExemptEncryption` to false, so this prompt usually does not appear.
3. Internal testing is enough for your own phone. The Account Holder is an internal tester. The iPhone’s App Store Apple ID should be `addibackup92@gmail.com`, or another user you add under Users and Access.
4. On the iPhone, install **TestFlight** from the App Store.
5. Open the TestFlight invite, or open TestFlight, and install **Codex Reset Tracker**.
6. The phone needs iOS 18 or later. TestFlight installs do not need Developer Mode.
7. Long-press the Home Screen or Lock Screen to add the **Codex Reset** and **Banked resets** widgets.

To put the app on a phone that uses a different Apple ID, add that person in TestFlight. An internal tester must also be an App Store Connect user. An external tester can be any email, but the first external build has to pass Beta App Review.

## When the upload fails

| Log message | What to fix |
| --- | --- |
| Missing GitHub secret | Step 5. A manual run fails on purpose when a secret is empty. |
| No signing certificate / no profiles | The API key is not Admin, or one of the three App IDs from step 1 is missing. The notification id is `com.arnar111.codexresettracker.notification`. |
| Your team has no devices / iOS App Development provisioning profiles | Do not register a device. Re-run **iOS TestFlight**. The archive is manual Apple Distribution with App Store profiles. |
| conflicting provisioning settings | Automatic signing was combined with an Apple Distribution identity. The archive step must stay `CODE_SIGN_STYLE=Manual`. |
| certificate limit | Revoke an unused Apple Distribution certificate in the developer portal, then re-run. Do not register devices. |
| agreement | Accept the latest Apple Developer agreement in the browser, then re-run. |
| Profile does not include the App Group or Push | Enable those capabilities on the App IDs, then re-run. |
| No suitable application record | Create the App Store Connect app in step 2 with bundle id `com.arnar111.codexresettracker`. |
| Authentication failed / key not found | Issuer ID, Key ID, and the `.p8` are not the same key. |
| Bundle version must be higher | Re-run the workflow. The build number includes the attempt, so the new upload is a new build. |
| Build did not produce the widget | The compile job failed before upload. Open the **Build app and widgets** log. |

If the upload itself fails after the IPA was exported, the workflow attaches that IPA to the failed run for 7 days. It is a signed App Store binary. Download it only to retry an upload, and do not commit it.
