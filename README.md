# Codex Reset Tracker

A small native iPhone app that tracks **global** OpenAI Codex / ChatGPT Work usage-reset announcements.

It reads the public [Codex Resets](https://codex-resets.com/) API. It does not sign in to ChatGPT, scrape X/Twitter, estimate remaining usage, or show ads. It is not affiliated with OpenAI.

Data from [Codex Resets](https://codex-resets.com/).

## What you see

- The latest **confirmed full reset**, and how long ago it happened
- How many **banked resets** this iPhone still has available
- Whether another reset is **scheduled** (a schedule is not a completed reset)
- History of announcements, with a link to the original post when Codex Resets has one
- Home Screen and Lock Screen widgets
- A widget action, **Used banked reset**, that marks one local credit used without opening the app
- Push alerts for full, banked, and scheduled resets once you add your own APNs key

Times use the iPhone time zone. Settings can switch the display to UTC.

## Reset rules

| Upstream | In the app |
| --- | --- |
| `reset_type: regular` on an executed announcement | Full reset. Usage limits were reset. Banked credits stay. |
| `reset_type: banked` | One banked credit is recorded locally, once per upstream id. |
| `reset_type: combined`, or both `is_full_reset` and `adds_banked_reset` | Full timestamp updates and the bank gains one. One combined alert. |
| `scheduled_reset` | Shown as scheduled. A passed `scheduled_for` does **not** mean it completed. |
| Same announcement fetched again | No second credit and no second alert. |

The public API does not know whether *you* redeemed a banked credit. The count lives on the device:

- `BankedResetRecord` stores `eventID`, `receivedAt`, and optional `usedAt`
- Announcements that already existed on the first successful history sync are remembered and **not** added to the available count
- **Mark one as used** consumes the oldest available credit and never goes below zero
- **Correct banked count** adds or retires manual rows whose ids cannot collide with upstream ids, so a later API event still adds one
- A full reset does not clear the bank

The first successful sync does not notify for announcements already on the server. Alerts start with events that show up after that.

Widget celebration mode lasts **6 hours** after a confirmed full reset (change it in Settings, 1–24). A scheduled reset never turns celebration on.

## Architecture

```
Codex Resets API
  GET /api/v1/status
  GET /api/v1/resets
        │
        ▼
CodexResetsAPIClient → DTOs → ResetNormalizer → ResetEvent
        │
        ▼
StateReducer + BankedInventory + NotificationPlanner
        │
        ├── App Group JSON (app, widgets, widget intent)
        └── Cloudflare Worker cron (every 2 minutes) → APNs
```

The iPhone does not poll in the background. Opening the app, or bringing it to the foreground, refetches immediately. If the network fails and a cache exists, the cache stays on screen with “Unable to refresh.”

There is no webhook, SSE, or RSS feed on the Codex Resets API (confirmed from the OpenAPI document and a live response on 22 Sep 2026). The worker polls `/api/v1/status` and one page of `/api/v1/resets`, sends `If-None-Match` when it has an ETag, and honors `429` + `Retry-After`.

Verified endpoints, no API key:

- `GET https://codex-resets.com/api/v1/status`
- `GET https://codex-resets.com/api/v1/resets?limit=&cursor=&from=&to=&order=`
- Docs: https://codex-resets.com/api/docs
- OpenAPI: https://codex-resets.com/api/openapi.json

`regular` and `banked` are the types the API publishes today. Combined is supported so a future explicit value, or the optional booleans `is_full_reset` / `adds_banked_reset`, does not get forced into one bucket. Unknown types are kept in history and do not move the full-reset time or the bank.

## Project layout

```
Package.swift                  Shared logic and tests (no UIKit)
Sources/CodexResetCore/
  API/                         Client, DTOs, normalizer
  Logic/                       Bank, notifications, refresh, widgets, time
  Models/
  Persistence/                 JSON file + App Group store
Tests/CodexResetCoreTests/
ios/CodexResetTracker/         SwiftUI app
ios/CodexResetWidget/          WidgetKit extension + AppIntent
ios/CodexResetTracker.xcodeproj
backend/                       Cloudflare Worker
scripts/generate_app_icon.py
.env.example
```

Identifiers, unless you change them everywhere they appear:

| | |
| --- | --- |
| App bundle id | `com.arnar111.codexresettracker` |
| Widget bundle id | `com.arnar111.codexresettracker.widget` |
| App Group | `group.com.arnar111.codexresettracker` |
| URL scheme | `codexreset://latest` and `codexreset://event/<id>` |
| Deployment | iOS 18, iPhone |

## Tests

Core logic is a Swift package so it runs without Xcode. The worker tests run in Node.

```bash
swift test
node --test backend/test/*.test.js
# or
make test
```

On 22 Sep 2026, `swift test` passed 22 tests (Swift 6.2 on Linux) and `node --test` passed 10. That covers the product cases: full, banked, duplicate fetches, combined, scheduled vs completed, mark-used, restart, offline cache, and malformed fields. This environment cannot run Xcode, so the iOS target has not been compiled here.

## Run it on a Mac

You need Xcode 16 or newer.

```bash
git clone https://github.com/arnar111/gptreset.git
cd gptreset
open ios/CodexResetTracker.xcodeproj
```

1. Select the **CodexResetTracker** scheme.
2. Signing & Capabilities → set your Team on **both** the app and the widget targets.
3. The entitlements already request Push Notifications and the App Group. Xcode will offer to register them if your team can. If it does not, create them on the developer site (below) and download a new profile.
4. Pick an iPhone simulator to try the UI, widgets, and local alerts.
5. Remote push only works on a **physical iPhone**.

Build from the terminal:

```bash
xcodebuild \
  -project ios/CodexResetTracker.xcodeproj \
  -scheme CodexResetTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet \
  build
```

Change the simulator name to one listed by `xcrun simctl list devices available`.

### Capabilities

App target:

- Push Notifications
- App Groups → `group.com.arnar111.codexresettracker`
- Background Modes → Remote notifications (already in `Info.plist`)

Widget target:

- App Groups → the same group

Debug builds use the development APNs environment. Release / TestFlight builds use `CodexResetTrackerRelease.entitlements` (`aps-environment` = `production`) and register with `sandbox: false`.

## Install on your iPhone

1. Connect the iPhone and trust the computer.
2. In Xcode, choose your iPhone as the run destination.
3. On the phone, if iOS blocks the developer app: Settings → Privacy & Security → Developer Mode → on, then restart.
4. Run the CodexResetTracker scheme. The widget extension is embedded.
5. Allow notifications when the app asks. You can change Full / Banked / Scheduled later in Settings. All three default to on.
6. Add widgets: long-press the Home Screen or Lock Screen → **Codex Reset** (status) or **Banked resets**.
7. On a Home Screen widget, **Used banked reset** marks one credit used. The count is shared with the app through the App Group.
8. Pull to refresh on Status or History. The screen also refreshes whenever the app becomes active.

Simulator notes: the interface, widgets, bank, and local notifications work. APNs delivery does not. The app says so in Settings.

## Push server

The worker is ready to deploy. It is **not deployed** from this repository, because that needs your Cloudflare account and an Apple APNs key.

```bash
npm install -g wrangler
cd backend
wrangler login
wrangler kv namespace create RESET_TRACKER
```

Put the printed id into `backend/wrangler.toml` in place of `replace-with-kv-namespace-id`.

```bash
wrangler secret put APNS_KEY_ID
wrangler secret put APNS_TEAM_ID
wrangler secret put APNS_BUNDLE_ID
wrangler secret put APNS_PRIVATE_KEY
wrangler deploy
```

`APNS_BUNDLE_ID` is `com.arnar111.codexresettracker`.

`APNS_PRIVATE_KEY` is the contents of the Apple `.p8` file, including the BEGIN/END lines. You can paste real newlines, or a single line with `\n` escapes. See `.env.example` and `backend/.dev.vars.example`. Do not commit either file after you fill it in.

Local worker (no Apple push until the secrets exist):

```bash
cp backend/.dev.vars.example backend/.dev.vars
wrangler dev
curl http://127.0.0.1:8787/health
```

Cron does not run under `wrangler dev` unless you trigger it:

```bash
curl "http://127.0.0.1:8787/cdn-cgi/handler/scheduled"
```

Wrangler versions differ on that URL. `wrangler dev --test-scheduled` is the current flag.

After deploy, copy the worker origin, such as `https://codex-reset-tracker.<account>.workers.dev`, into the app under **Settings → Push server**. The app registers:

`PUT /v1/devices/<install-uuid>`

```json
{
  "apnsToken": "64-or-more hex characters",
  "sandbox": true,
  "timeZone": "Atlantic/Reykjavik",
  "preferences": { "full": true, "banked": true, "scheduled": true }
}
```

`DELETE` the same path when every alert toggle is off. `GET /health` reports whether APNs is configured and whether the first poll has baselined. It does not return tokens or the private key.

The first poll records current upstream ids and does not push them. Later polls push new ids. Devices that have not opted into a kind are skipped. A `410` from APNs drops that device. Registration is limited to 30 requests per IP per hour.

Until the worker URL is saved and APNs registration succeeds, a debug build and the Simulator show a **local** notification when the app itself discovers a new event. A registered device relies on APNs so the same event is not alerted twice. Opening the app still updates the UI and widgets if a push was missed.

## APNs key, the part only you can do

1. [Apple Developer](https://developer.apple.com/account) → Certificates, Identifiers & Profiles → **Keys** → create a key → enable **Apple Push Notifications service (APNs)**.
2. Download the `.p8` once. Note the **Key ID**.
3. Note your **Team ID** (Membership details).
4. Identifiers → App IDs:
   - `com.arnar111.codexresettracker` with **Push Notifications** and **App Groups**
   - `com.arnar111.codexresettracker.widget` with **App Groups**
5. Identifiers → App Groups → `group.com.arnar111.codexresettracker`, and attach it to both App IDs.
6. Xcode → Signing & Capabilities → your team on both targets. Let Xcode create the development provisioning profiles.
7. Put the four `APNS_*` values into the worker with `wrangler secret put`, then `wrangler deploy`.
8. On the iPhone, Settings → Push server → paste the worker URL → Save. Settings should say **Registered for reset alerts** after the token arrives.
9. Confirm `GET https://<worker>/health` shows `"apnsConfigured": true` after the secrets are set. It stays `false` until all four are present.

There is no sample `.p8` in this repo. Pushes cannot be sent until those secrets exist.

## Privacy

No account, no analytics SDK, no advertising ID, no location, no contact data, no ChatGPT access. The only identifier sent to your worker is an anonymous install UUID plus the APNs token, the sandbox flag, the time zone name used to format scheduled alerts, and the three notification toggles. The token is stored in the iOS keychain and in the worker’s KV so it can send reset alerts. `PrivacyInfo.xcprivacy` declares no tracked data.

## Known limitations

- Xcode has not been run in the environment that produced this tree. Build once on a Mac before shipping.
- Remote notifications need a physical iPhone, a paid or free developer team that can use push, and the worker secrets above.
- Banked availability is local. Codex Resets cannot see which credits you have redeemed.
- The API has no combined type in the live feed today. Combined handling is ready for an explicit upstream value.
- History cache is the latest pages (50 per page, up to 2 pages per refresh), not a private copy of the entire archive.
- The worker polls every 2 minutes, so an alert can lag by about that long, plus APNs delivery.
- Widget text is generated when WidgetKit asks for a timeline (about every minute for 30 minutes, then a reload). It can be a minute behind the app.
