# StringPilot

StringPilot is a native macOS performance app that lets an Xbox controller replace the picking or plucking hand while the player's other hand remains on a real fretboard.

The instrument connects through an iRig or another audio interface. StringPilot listens for fret contact, hammer-ons, pull-offs, slides, and other small string vibrations. The pressed controller button identifies the physical string, allowing the pitch detector to constrain the result to that string's real fret range. The app then creates the requested attack, preserves part of the real pickup transient, and, when enabled, sends recordable MIDI to Logic Pro, GarageBand, or another MIDI-capable host.

## What is implemented

- Native SwiftUI macOS application; no web wrapper or Electron runtime.
- Xbox controller support through Apple's Game Controller framework, including background controller events.
- Direct mappings for up to six strings: A, B, X, Y, LB, and RB.
- Single-pick, held tremolo, right-stick strum, and saved-pattern modes.
- Controller-only mode changes and tempo changes.
- Right-trigger attack strength.
- Adjustable tempo from 30–300 BPM and quarter through thirty-second-note repeat divisions.
- Live iRig/interface monitoring with app-local input and output selection; choosing a device does not replace the Mac's system defaults.
- Adjustable input sensitivity and noise gate.
- String-focused YIN pitch detection with confidence scoring, adaptive window size, low-frequency bass support, octave correction, and per-string fret constraints.
- A pending first-attack gate that waits for the simultaneous fret transient and fires early when it resolves, instead of playing the previous/open note first.
- Per-string pitch latching so later attacks, strums, and patterns can reuse already detected fret states.
- Per-string capture of the real iRig fret transient, including DC removal, silence rejection, onset detection, trimming, normalization, fades, and pitch-aware replay.
- A hybrid internal attack that blends the latest real pickup transient with a newly seeded Karplus–Strong tail for every controller attack.
- Palm mute, drive, reverb, output gain, and live-input blending.
- A named StringPilot virtual MIDI source plus selectable CoreMIDI destinations.
- MIDI channels 1–6 assigned per physical string, including per-string pitch bend and bend reset after note-off.
- Logic Pro Virtual In routing and GarageBand virtual-controller routing.
- Standard guitar, Drop D guitar, four- and five-string bass, ukulele, and mandolin profiles.
- Persistent settings and pattern data.
- Controller-disconnect cleanup, app-close cleanup, stuck-note cleanup, and safe audio-graph rebuilding after a device change.
- Automated detector, fret resolver, pattern, timing, profile, synthesis, real-transient preparation, resampling, and blend tests.
- Native Xcode compilation on a macOS 15 GitHub runner with Xcode 16.4.

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

In Tremolo mode, hold a string button to repeat that string until release. The first attack resolves the new fret contact; later attacks follow the selected tempo and subdivision. Disconnecting the controller releases every held string.

## Signal model

A normal guitar pickup is a summed mono source, so software cannot reliably infer six simultaneous physical string positions from silence. StringPilot avoids pretending otherwise:

1. A controller button labels the intended physical string.
2. A fresh focused buffer begins at that button press, excluding older audio.
3. A valid fret transient is resolved only against that string's open note and fret range.
4. The result is latched for that string.
5. A short real pickup transient is stored for that string and blended into later attacks.
6. Held buttons keep updating pitch while the left hand moves.
7. Strums and patterns use the six latched string states.

Several nearly simultaneous presses can still be performed, but one ordinary mono pickup cannot independently describe several silent fret positions at the exact same instant. Reliable true polyphonic left-hand detection would require per-string pickup channels or another sensor. StringPilot does not disguise that physical limitation.

## Requirements

- macOS 14 or newer.
- Xcode 16 or newer to build from source.
- Xbox Wireless Controller or compatible extended Xbox gamepad, connected by Bluetooth or USB.
- Guitar, bass, ukulele, or mandolin with a usable pickup/interface signal.
- iRig or another Core Audio input device.
- Headphones are strongly recommended during setup to avoid the output re-entering the pickup or interface input.

## Install from the DMG

1. Download `StringPilot.dmg` from a successful **Build macOS DMG** workflow artifact.
2. Open the disk image.
3. Drag `StringPilot.app` onto the included **Applications** shortcut.
4. On the first launch, Control-click the app and choose **Open**.
5. Approve microphone/input access when macOS asks.

The public GitHub Actions package is ad-hoc signed because the repository does not contain an Apple Developer ID certificate or notarization credentials. The build script verifies the app signature and the mounted disk image, but macOS may still show the normal warning for an app that has not been Apple-notarized.

## Build and run

1. Open `StringPilot.xcodeproj` in Xcode.
2. Select the `StringPilot` scheme and `My Mac` destination.
3. Build and run.
4. Approve microphone/input access when macOS asks.
5. In the Sound tab, choose the iRig as input and the desired speakers, headphones, or interface as output.
6. Connect the Xbox controller and verify that its name appears in the Play tab.
7. Start with headphones, increase sensitivity until light fret contact registers, then raise the noise gate until idle noise stops producing detections.

The project uses no third-party runtime packages.

To build and verify the distributable disk image locally:

```bash
bash scripts/build-dmg.sh
```

The finished files are written to `dist/StringPilot.dmg` and `dist/StringPilot.dmg.sha256`.

## Logic Pro

1. In Logic Pro, open **Settings → MIDI → Inputs** and enable **Logic Pro Virtual In**.
2. In StringPilot's Routing tab, refresh MIDI destinations and select **Logic Pro Virtual In**.
3. Record-enable a software-instrument track in Logic.
4. Play with the controller. Each physical string uses its own MIDI channel.
5. For the real pickup/amp layer, record the iRig on a separate audio track and apply Logic's amp and pedal plug-ins.

## GarageBand

Leave StringPilot on **Virtual source only**. GarageBand receives the StringPilot virtual MIDI source as a controller. Use a software-instrument track for the generated notes. The iRig's real input can also be recorded on a separate audio track for fret contact, slides, pickup character, and an amp plug-in chain.

## Verification

Run the portable signal-engine tests:

```bash
swift test
```

Compile the complete native macOS application without launching its hardware-dependent runtime:

```bash
xcodebuild \
  -project StringPilot.xcodeproj \
  -scheme StringPilot \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

The GitHub Actions workflows run the signal tests, native app compilation, and verified DMG packaging on every pull request. Physical iRig, Xbox controller, instrument, USB/Bluetooth, and DAW checks follow `docs/HARDWARE_VALIDATION.md` because a hosted runner cannot manufacture those inputs. Those rows must be completed on real hardware before claiming hardware sign-off.

See `docs/ARCHITECTURE.md` and `docs/HARDWARE_VALIDATION.md` for the exact runtime pipeline and physical test matrix.
