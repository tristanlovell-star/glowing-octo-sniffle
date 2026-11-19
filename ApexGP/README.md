# Apex GP

An Apple TV racing game. Pick a current road car, make it your own in the
garage, and race it against AI rivals on the circuits of the 2026 Formula 1
calendar.

## What's in it

**16 road cars**, each with real trim levels that change how it drives:

| | Trims |
| --- | --- |
| Toyota GR86 | GR86, GR86 GTS |
| Mazda MX-5 | 1.5 Roadster, 2.0 GT, 2.0 GT RS |
| Porsche 911 | Carrera, Carrera GTS, Turbo S, GT3 |
| Ford Mustang | GT, Dark Horse |
| Chevrolet Corvette | Stingray, E-Ray, Z06 |
| Toyota GR Yaris | GR Yaris, Rallye |
| Honda Civic Type R | Type R |
| Volkswagen Golf R | Golf R, Black Edition |
| BMW M3 | Competition, CS |
| Tesla Model 3 | Rear-Wheel Drive, Long Range, Performance |
| Hyundai Ioniq 5 N | Ioniq 5 N |
| Ford Ranger Raptor | Raptor |
| Toyota GR Supra | GT, Final Edition |
| Nissan Z | Z, Z NISMO |
| Ferrari 296 GTB | 296 GTB, Assetto Fiorano |
| Lamborghini Temerario | Temerario, Alleggerita |

**The garage** lets you change:

- **Trim**: power, weight, drive (RWD/FWD/AWD), grip, top speed
- **Paint**: each car's own factory colours (Soul Red Crystal, Guards Red,
  Grabber Blue, Verde Mantis…) plus fun ones on every car: Chrome, Gold Rush,
  Hot Pink, Lime Time, Matte Black and more. Solid, metallic, pearl, matte and
  chrome finishes all look different.
- **Wheels**: 5-spoke, 10-spoke, Y-spoke, mesh, turbine or rally dish;
  17- to 22-inch; silver, gloss black, gunmetal, bronze, gold, chrome, white or
  body colour
- **Brake calipers**: red, yellow, blue, green, orange, black, silver
- **Rear wing**: factory, none, ducktail or GT wing (a big wing adds grip in
  fast corners but costs a little top speed)
- **Stripes**: twin racing, centre or side, in eight colours
- **Roof & mirrors**: body colour, black or carbon
- **Racing number** and **driver name**

The stats panel (power, weight, 0–100 km/h, top speed, grip) updates as you
change things. Specs are close to the real cars but approximate.

**24 circuits**, in calendar order: Albert Park, Shanghai, Suzuka (with the
crossover bridge), Sakhir, Jeddah, Miami, Montréal, Monaco, Barcelona, Red Bull
Ring, Silverstone, Spa-Francorchamps, Hungaroring, Zandvoort, Monza, Madring,
Baku, Marina Bay, Circuit of the Americas, Mexico City, Interlagos, Las Vegas,
Lusail and Yas Marina. Night races (Singapore, Las Vegas, Bahrain, Jeddah,
Qatar, Abu Dhabi) are run at night. Street circuits have walls close to the
road; permanent circuits have grass run-off.

The layouts are the real ones, traced from GPS, so every corner is where it
should be. Elevation isn't included, so the circuits are flat apart from
Suzuka's bridge.

**Racing**: an F1-style five-light start, 1–10 laps, 0–9 rivals, three
difficulty levels, a timing tower, mini-map, lap times and a best lap saved
for each circuit. Your rivals get the same performance as your car (scaled
for difficulty), so any car can win.

## Controls

| | Siri Remote | Game controller |
| --- | --- | --- |
| Steer | Slide your thumb left/right on the touch surface | Left stick or d-pad |
| Accelerate | Automatic | Right trigger or A |
| Brake / reverse | Press the clickpad | Left trigger or X |
| Change camera | Play/Pause | Y |
| Pause | Back (Menu) | Menu / B |

**Driving help** (on by default, in the race setup screen) keeps the car on
the road, brakes for corners and accelerates for you, so you only have to
steer to overtake. Turn it off for full control. A car that gets stuck or
turned around is put back on the track after a few seconds.

Any Xbox, PlayStation or MFi controller paired with the Apple TV works.

## Building it

You need a Mac with **Xcode 15 or later** and an Apple TV running
**tvOS 17 or later** (or the Apple TV simulator in Xcode).

```sh
brew install xcodegen
cd ApexGP
xcodegen generate
open ApexGP.xcodeproj
```

In `project.yml`, change `BASE_BUNDLE_ID` to something unique, such as
`com.yourname.apexgp`, and run `xcodegen generate` again. Then choose your
**Team** under **Signing & Capabilities**.

To run it on the Apple TV, pair it with Xcode first. On the Apple TV, go to
**Settings → Remotes and Devices → Remote App and Devices**. In Xcode, go to
**Window → Devices and Simulators**, choose the Apple TV and click **Pair**.
Then pick it as the run destination and press Run.

## TestFlight from GitHub (no Mac needed)

This works like the Bus Times setup in the main README and reuses the same
App Store Connect API key. You need a paid Apple Developer account.

1. **Register the bundle ID** on [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list):
   Identifiers → **+** → App IDs → App, e.g. `com.yourname.apexgp`.
2. **Create the app record** in [App Store Connect](https://appstoreconnect.apple.com/apps):
   **+ → New App**, tick **tvOS**, give it a unique name (e.g. "Apex GP
   Family Edition") and choose the bundle ID from step 1.
3. **Add a repository variable** under **Settings → Secrets and variables →
   Actions → Variables**: `APEXGP_BUNDLE_ID` = your bundle ID. `TEAM_ID` and
   the `ASC_*` secrets are already there from Bus Times.
4. Run **Actions → Apex GP TestFlight → Run workflow**.
5. When Apple has processed it, add yourself as an internal tester in App Store
   Connect. Then install it from the **TestFlight** app on the Apple TV.

## Changing things

| To change… | Edit |
| --- | --- |
| Cars, trims, colours | `Game/CarCatalog.swift` |
| How cars handle | `Game/CarPhysics.swift` |
| How rivals drive, difficulty | `Game/AIDriver.swift`, `Game/RaceController.swift` (`Difficulty`) |
| Car shapes, wheels, stripes | `Game/CarNode.swift` |
| Scenery, kerbs, walls, night races | `Game/TrackScene.swift` |
| Circuits | `Tools/make_tracks.py`, then run it to rebuild `Resources/tracks.json` |
| App icon and Top Shelf image | `Tools/make_icons.py`, then run it |

## Project layout

```
App/        App entry point, screens and saved settings, icon
Game/       Cars, tracks, physics, AI, race logic, HUD and sound
Garage/     The garage screen and 3D car preview
UI/         Menu, circuit picker, race and results screens
Resources/  tracks.json (circuit layouts)
Tools/      Scripts that build the track data and icons
```

Everything is drawn in code, including the cars, circuits, scenery, textures
and engine sound, so there are no 3D model or sound files to license.

## Credits and notes

- Circuit layouts: [f1-circuits](https://github.com/bacinger/f1-circuits)
  by Tomislav Bacinger, MIT licence.
- Car makes, models and paint names belong to their manufacturers. Using them
  is fine for a family game on your own Apple TV or with TestFlight testers.
  You'd need licences from the carmakers (and to drop "Grand Prix"/F1
  branding) before publishing it on the App Store.
