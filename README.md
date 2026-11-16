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

Each widget has its own settings (touch and hold the widget, then **Edit
Widget**; on the watch, edit the watch face):

- **Stop ID**: the number at the end of the Translink stop page URL (`000030`).
  You can paste the whole URL.
- **Walk to stop**: minutes from your desk to the stop. Used for the "leave in"
  time.
- **Routes**: optional filter, e.g. `199` or `195, 199`.

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
> account ($149 AUD/yr) extends that to a year.

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
