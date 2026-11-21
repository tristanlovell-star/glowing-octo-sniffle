# Spotter

A personal gym coach for iPhone. It builds a training program around **you** and
the **equipment your gym actually has**, coaches you through each session, and
adapts on the spot when the machine you want is taken.

Set up by default for **Snap Fitness New Farm** (you confirm the equipment on
your first walk-through).

## What it does

| | |
| --- | --- |
| **Learns your gym** | Photograph the equipment and the AI coach works out what's there, or tick it off a checklist. Your photos are kept, so exercises show *your* machine. |
| **Designs your program** | From your experience, goal, days per week, session length, injuries and anything else you tell it. |
| **Machine busy?** | One tap during a workout: swap to an alternative that trains the same muscles on free equipment, or re-order the session and come back to it. |
| **Shows you how** | Every exercise has start/finish demonstration photos and step-by-step instructions. |
| **Equipment help** | A plain-English guide for each kind of machine: how to set it up, tips, common mistakes, and what you can do on it. Or send the coach a photo and ask. |
| **Tracks and coaches** | Log weight, reps and effort for each set. Next session it tells you what to lift, spots plateaus and personal bests, and flags when recovery looks poor. |
| **Apple Health** | Reads weight, resting heart rate, sleep, steps, VO2 max and workouts; saves each session as a strength workout; picks up your Apple Watch heart rate for the session. |
| **Travel mode** | Photograph a hotel gym and get a temporary program that mirrors your usual one with what's available. Your home program resumes where you left off. |

## The AI coach (optional)

Three features use Claude: recognising equipment in photos, designing the
program, and the Coach chat tab. They need a Claude API key, which you paste
into the app (Settings › AI coach). Create one at
[console.anthropic.com](https://console.anthropic.com) › API keys.

- The key is stored in the iPhone Keychain and sent only to Anthropic's API.
- Your photos, profile and training log are sent to the API only when you use
  those three features.
- Usage is billed to your Anthropic account: typically a few cents per photo
  scan or program design.

**Without a key everything else still works**: equipment checklist, a built-in
program planner, machine-busy alternatives and re-ordering, progression
targets, coach insights, Apple Health and travel mode all run on the phone.

## Getting it onto your iPhone (TestFlight from GitHub, no Mac needed)

This uses the same setup as Bus Times (see the main README for the one-time
Apple steps). You need an Apple Developer account and the `TEAM_ID` variable
and `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` secrets already in this repo.

1. **Register a bundle ID** at
   [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list):
   Identifiers → **+** → App IDs → App, e.g. `com.yourname.spotter`.
   Tick the **HealthKit** capability.
2. **Create the app record** in
   [App Store Connect](https://appstoreconnect.apple.com/apps): **+ → New App**,
   iOS, a unique name (e.g. "Spotter Gym Coach"), that bundle ID, any SKU.
3. **Add a repository variable** in GitHub (Settings → Secrets and variables →
   Actions → Variables): `SPOTTER_BUNDLE_ID` = your bundle ID.
4. In GitHub, go to **Actions → Spotter TestFlight → Run workflow**. About 15
   minutes later, plus Apple's processing time, the build appears in the
   TestFlight app on your iPhone.

## First run

1. **AI coach**: paste your Claude API key, or skip.
2. **Apple Health**: connect, and allow the categories it asks for.
3. **Your gym**: go to the gym and photograph the equipment (wide shots are
   fine), tap *Identify equipment*, then check the list. No key? Use the
   *Typical 24/7 gym* preset and untick what isn't there.
4. **About you**: experience, goal, schedule, injuries, and anything else.
5. **Build my program.**

## Building from a Mac

```sh
cd Spotter
brew install xcodegen
xcodegen generate
open Spotter.xcodeproj
```

Set `BASE_BUNDLE_ID` in `project.yml` and pick your Team under Signing &
Capabilities. Needs Xcode 15+ and iOS 17+. HealthKit needs a real iPhone.

## Project layout

```
App/         App entry point, icon, HealthKit entitlement
Core/        Data model, exercise library, program builder, coaching logic,
             Claude API client, Apple Health, storage
UI/          SwiftUI screens
Resources/   exercises.json and demonstration photos (bundled in the app)
Tools/       build_library.py (rebuilds Resources), make_icon.py
```

## Exercise library

139 exercises with photos and instructions, curated from the public-domain
[Free Exercise DB](https://github.com/yuhonas/free-exercise-db) (Unlicense) and
tagged with a movement pattern and the equipment each one needs. To add or
change exercises, edit the `CURATED` table in `Tools/build_library.py` and run:

```sh
python3 Tools/build_library.py
```

## Not medical advice

Spotter gives general training guidance. If something hurts in a way that
isn't normal training soreness, stop and see a professional.
