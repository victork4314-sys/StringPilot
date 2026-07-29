# StringPilot

StringPilot is a native macOS performance app that lets an Xbox controller replace the picking or plucking hand while the player's other hand remains on a real fretboard.

The instrument connects through an iRig or another audio interface. StringPilot listens for fret contact, hammer-ons, pull-offs, slides, and other small string vibrations. The pressed controller button identifies the physical string, allowing the pitch detector to constrain the result to that string's real fret range. The app then produces the requested attack internally and, when enabled, sends recordable MIDI to Logic Pro, GarageBand, or another MIDI-capable host.

## What is implemented

- Native SwiftUI macOS application; no web wrapper or Electron runtime.
- Xbox controller support through Apple's Game Controller framework, including background controller events.
- Direct mappings for up to six strings: A, B, X, Y, LB, and RB.
- Single-pick, held tremolo, right-stick strum, and saved-pattern modes.
- Controller-only mode changes and tempo changes.
- Right-trigger attack strength.
- Adjustable tempo from 30–300 BPM and quarter through thirty-second-note repeat divisions.
- Live iRig/interface monitoring with selectable system input and output devices.
- Adjustable input sensitivity and noise gate.
- YIN pitch detection with confidence scoring, low-frequency bass support, octave correction, and per-string fret constraints.
- Per-string pitch latching so chords, strums, and patterns can reuse already detected fret states.
- Internal Karplus–Strong plucked-string attack with palm mute, drive, reverb, and live-input blending.
- A named StringPilot virtual MIDI source plus selectable CoreMIDI destinations.
- MIDI channels 1–6 assigned per physical string, including per-string pitch bend.
- Logic Pro Virtual In routing and GarageBand virtual-controller routing.
- Standard guitar, Drop D guitar, four- and five-string bass, ukulele, and mandolin profiles.
- Persistent settings and pattern data.
- Automated detector, fret resolver, pattern, timing, profile, and synthesis tests.

## Controller layout

| Control | Action |
|---|---|
| A | String 1 |
| B | String 2 |
| X | String 3 |
| Y | String 4 |
| LB | String 5 |
| RB | String 6 |
| D-pad left/right | Previous/next mode |
| D-pad up/down | Tempo ±2 BPM |
| Right trigger | Attack strength |
| Right stick up/down | Upstroke/downstroke in Strum mode |
| Menu | Start/stop the saved pattern |

In Tremolo mode, hold a string button to repeat that string until release. The repeat rate follows the selected tempo and subdivision.

## Signal model

A normal guitar pickup is a summed mono source, so software cannot reliably infer six simultaneous physical string positions from silence. StringPilot avoids pretending otherwise:

1. The controller button labels the intended string.
2. A valid fret transient is resolved only against that string's open note and fret range.
3. The result is latched for that string.
4. Held buttons keep updating their string while the left hand moves.
5. Strums and patterns use the six latched string states.

This preserves the practical behavior of the proposed instrument while preventing a mixed pickup signal from silently assigning a note to the wrong string.

## Requirements

- macOS 14 or newer.
- Xcode 16 or newer to build from source.
- Xbox Wireless Controller or compatible extended Xbox gamepad, connected by Bluetooth or USB.
- Guitar, bass, ukulele, or mandolin with a usable pickup/interface signal.
- iRig or another Core Audio input device.

## Build and run

1. Open `StringPilot.xcodeproj` in Xcode.
2. Select the `StringPilot` scheme and `My Mac` destination.
3. Build and run.
4. Approve microphone/input access when macOS asks.
5. In the Sound tab, choose the iRig as input and the desired speakers, headphones, or interface as output.
6. Connect the Xbox controller and verify that its name appears in the Play tab.

The project uses no third-party runtime packages.

## Logic Pro

1. In Logic Pro, open **Settings → MIDI → Inputs** and enable **Logic Pro Virtual In**.
2. In StringPilot's Routing tab, refresh MIDI destinations and select **Logic Pro Virtual In**.
3. Record-enable a software-instrument track in Logic.
4. Play with the controller. Each physical string uses its own MIDI channel.

## GarageBand

Leave StringPilot on **Virtual source only**. GarageBand receives the StringPilot virtual MIDI source as a controller. Use a software-instrument track for the generated notes. The iRig's real input can also be recorded on a separate audio track for fret noise, slides, and an amp plug-in chain.

## Verification

Run the portable signal-engine tests:

```bash
swift test
```

Run the native macOS build and tests:

```bash
xcodebuild \
  -project StringPilot.xcodeproj \
  -scheme StringPilot \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The GitHub Actions workflow runs both checks on every push and pull request.

See `docs/ARCHITECTURE.md` and `docs/HARDWARE_VALIDATION.md` for the exact runtime pipeline and physical test matrix.
