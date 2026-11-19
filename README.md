# Bus Times

An iPhone widget and Apple Watch complication that show the next buses at a
Translink (South East Queensland) stop, plus **when you need to leave** to
catch each one.

Set up by default for **Adelaide St, Stop 30 (near Macrossan St)**, served by
routes 195 (Merthyr), 196 (New Farm) and 199 (Teneriffe).

## What you get

| Where | Sizes | Shows |
| --- | --- | --- |
| iPhone Home Screen | Small, Medium | "Leave in 4 min", the next 3–4 buses with countdowns and delays, a refresh button |
| iPhone Lock Screen | Rectangular, Circular, Inline | Leave-in time and the next buses |
| Apple Watch face / Smart Stack | Rectangular, Circular, Corner, Inline | Leave-in time and the next buses |
| iPhone and Watch apps | — | Full live list, refreshed every 30 seconds |

### Home and work stops

The widgets and complications know two stops:

| | Default | Used for |
| --- | --- | --- |
| 🏠 **Home** | `725` Merthyr Rd at Alford Street, stop 12 (city-bound, route 199) | Getting into work |
| 💼 **Work** | `000030` Adelaide Street Stop 30 near Macrossan St | Getting home |

Each widget's **Show** option can be:

- **Nearest** (the default): uses your iPhone's or Apple Watch's location to
  show whichever stop is closer. If location is off or unavailable, it shows
  the home stop before midday and the work stop after.
- **Home stop** or **Work stop**: always that stop.

To change a widget's options, touch and hold it and tap **Edit Widget** (on
the watch, edit the face). Each stop has its own walk time and optional route
filter. The apps have the same switch at the top, and their stops are set
under ⚙️.

**Location permission.** Open the app once and allow location. On iPhone,
choose **While Using the App or Widgets** in Settings › Bus Times › Location,
so the widgets can use it too. Open the watch app once as well, so the watch
complications can use location. Location is only used on the device to compare
distances; it's never sent anywhere. A widget re-checks where you are each
time it refreshes (roughly every 10–15 minutes, at the system's discretion).

Stop IDs: use the number at the end of a Translink stop page URL. You can also
paste the whole URL. Any Translink stop works, because the app bundles
Translink's stop list (`Shared/Resources/stops.csv`, rebuilt with
`python3 Tools/make_stops.py`). Some stops come in pairs with the same name,
one for each direction: for example, Alford St stop 12 is `725` towards the
City and `724` towards Teneriffe.

## Where the data comes from

Translink's open [GTFS-Realtime feed](https://translink.com.au/about-translink/open-data/gtfs-rt),
which is free and needs no API key:
`https://gtfsrt.api.translink.com.au/api/realtime/SEQ/TripUpdates/Bus`.

The times are live predictions, delays included. When this was built, they
matched the Translink stop page exactly. The feed covers roughly the next hour
or so of trips. The app decodes the feed's protobuf format itself, so there are
no third-party dependencies.

## Building it

You need a Mac with **Xcode 15 or later**, an iPhone on **iOS 17+**, and, for
the watch, an Apple Watch on **watchOS 10+**.

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and generate the
   project:
   ```sh
   brew install xcodegen
   xcodegen generate
   open BusTimes.xcodeproj
   ```
2. In `project.yml`, change `BASE_BUNDLE_ID` from `com.example.bustimes` to
   something unique, such as `com.yourname.bustimes`. Then run
   `xcodegen generate` again.
3. In Xcode, select each of the four targets. Under **Signing & Capabilities**,
   choose your **Team** (sign in with your Apple ID under Xcode → Settings →
   Accounts if you need to).
4. Plug in your iPhone, choose the **BusTimes** scheme and your phone, and press
   Run. The watch app installs onto a paired watch along with it. You can also
   run the **BusTimesWatch** scheme directly.
5. Add the widget: touch and hold the Home Screen → **Edit** → **Add Widget** →
   **Bus Times**. For the watch, edit a watch face and choose Bus Times for a
   complication slot.

> With a free Apple ID (no paid developer account), apps you install yourself
> expire after 7 days and need re-running from Xcode. A paid Apple Developer
> account ($149 AUD/yr) lets you use TestFlight instead (see below).

## TestFlight from GitHub (no Mac needed)

GitHub Actions builds and uploads the app on GitHub's Mac machines. You only
need a web browser, and Safari on an iPhone works.

> On a private repo, Mac build time counts 10× against your free GitHub
> Actions minutes (2,000/month on the free plan, so about 200 Mac minutes).
> One TestFlight upload takes about 10–15 Mac minutes.

**One-time setup**

1. **Register the bundle ID.** On [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list)
   go to Identifiers → **+** → App IDs → App, enter a description ("Bus
   Times") and a bundle ID, e.g. `com.yourname.bustimes`. Leave the
   capabilities as they are. The widget and watch IDs are created
   automatically during the build.
2. **Create the app record.** In [App Store Connect](https://appstoreconnect.apple.com/apps)
   go to **+ → New App**: iOS, a unique name (e.g. "Bus Times SEQ"), language,
   the bundle ID from step 1, and any SKU (e.g. `bustimes`).
3. **Create an API key.** In App Store Connect go to **Users and Access →
   Integrations → App Store Connect API → Team Keys → +**. Name it "GitHub" and
   give it **Admin** access (needed so Apple can sign the app in the cloud).
   Note the **Issuer ID** and **Key ID**, then download the `.p8` file. You
   can only download it once.
4. **Find your Team ID.** It's on developer.apple.com → Account → Membership
   details (10 characters, e.g. `A1B2C3D4E5`).
5. **Add them to GitHub.** In the repo, go to **Settings → Secrets and variables
   → Actions**.
   - **Variables** tab: `BUNDLE_ID` = your bundle ID; `TEAM_ID` = your Team ID
   - **Secrets** tab: `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8`, which is
     the whole text of the `.p8` file, including the `-----BEGIN PRIVATE
     KEY-----` and `-----END PRIVATE KEY-----` lines. On an iPhone, open the
     file from the Files app, select all the text and copy it. If Files won't
     show it as text, rename it to end in `.txt` first.

**Each time you want a new build**

1. In GitHub, go to **Actions → TestFlight → Run workflow**.
2. Wait about 15 minutes for the run, then 5–30 minutes for Apple's
   processing. Apple emails you when the build is ready.
3. The first time only: in App Store Connect, go to **TestFlight → Internal
   Testing → +**, create a group, and add yourself.
4. Install it from the **TestFlight** app on your iPhone. The watch app comes
   with it.

Build numbers are set automatically from the run number, so you never need to
bump them by hand for these uploads.

## TestFlight from a Mac

This needs a paid Apple Developer Program membership ($149 AUD/yr). TestFlight
builds last 90 days, compared with 7 days when you run from Xcode on a free
Apple ID. The watch app and complications come with the iPhone app: you upload
one build and install it once.

The project already has what App Store Connect checks for: app icons for
iPhone and Watch, privacy manifests, `ITSAppUsesNonExemptEncryption = NO`
(no export-compliance question on each build), and matching version numbers
across all four targets.

1. **Pick a bundle ID.** In `project.yml`, set `BASE_BUNDLE_ID` (e.g.
   `com.yourname.bustimes`) and `DEVELOPMENT_TEAM` (your 10-character Team
   ID, at developer.apple.com → Account → Membership). Run
   `xcodegen generate`.
2. **Create the app record.** In [App Store Connect](https://appstoreconnect.apple.com)
   go to **Apps → + → New App**, choose iOS, enter a name (it has to be unique
   on the App Store, so try something like "Bus Times SEQ"), and select your
   bundle ID. If it isn't in the list, build once in Xcode with automatic
   signing (Xcode registers all four IDs), or add it under Certificates, IDs &
   Profiles → Identifiers. Use any SKU, e.g. `bustimes`.
3. **Archive.** In Xcode, choose the **BusTimes** scheme and **Any iOS Device
   (arm64)** as the destination, then go to **Product → Archive**.
4. **Upload.** In the Organizer window that opens, click **Distribute App →
   TestFlight Internal Only** (or **App Store Connect**) and follow the prompts.
5. **Wait for processing.** This takes roughly 5–30 minutes. Apple emails you
   when it's done.
6. **Add yourself as a tester.** In App Store Connect, go to **TestFlight →
   Internal Testing → +**, create a group, and add your Apple ID. Internal
   testers don't need Apple's beta review.
7. **Install.** Get the **TestFlight** app from the App Store on your iPhone,
   accept the invite, and tap Install. The watch app installs automatically if
   **Watch app → General → Automatic App Install** is on; otherwise install
   it from the Watch app's **Available Apps** list.

For later updates, bump `CURRENT_PROJECT_VERSION` in `project.yml` (every
upload needs a new build number), run `xcodegen generate`, and repeat steps 3–5.

To share it with friends outside your developer team, use **External
Testing**. That adds a short beta review by Apple, and you'll need to give a
privacy policy URL and beta test notes.

## How fresh is it?

Each time a widget fetches data, it gets the exact predicted time for every
upcoming bus and pre-builds a minute-by-minute timeline. So the countdowns
stay accurate between fetches. iOS and watchOS decide how often widgets may
fetch new data (usually every 10–15 minutes, less often if the daily budget runs
low). That matters when a bus gets later after the last fetch. To get the
latest:

- tap the ↻ button on the Home Screen widget,
- open the app (this also refreshes the widgets), or
- check the "Updated" time on the medium widget.

## Checking the feed without building anything

`Tools/next_buses.py` is a dependency-free Python version of the same decoder:

```sh
python3 Tools/next_buses.py 000030 --walk 5
python3 Tools/next_buses.py 000030 --routes 199
```

## Project layout

```
Shared/Core/     Feed download, protobuf decoder, departure model (every target)
Shared/AppUI/    Departure list and settings views (iPhone and Watch apps)
Shared/Widget/   Widget config, timeline provider, and all widget layouts
iOS/App/         iPhone app
iOS/Widget/      iPhone widget extension entry point
Watch/App/       Apple Watch app
Watch/Widget/    Apple Watch complication extension entry point
Tools/           Command-line feed checker
project.yml      XcodeGen project definition
```

## Troubleshooting

- **"No buses in the next hour"** late at night is normal. Otherwise, check the
  stop ID with `Tools/next_buses.py`.
- **The watch app doesn't install with the iPhone app.** Run the
  `BusTimesWatch` scheme with your watch selected as the destination.
- **The widget isn't in the gallery.** Run the app once, then look again. If
  it's still missing, restart the phone.
