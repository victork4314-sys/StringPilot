# Architecture

## Runtime pipeline

1. `AudioEngineController` binds its own input and output audio units to the devices chosen in StringPilot. It does not change the Mac's system-default devices.
2. The selected Core Audio input is observed with a 512-frame tap. Audio is copied off the real-time callback before analysis or allocation-heavy processing.
3. A new controller string press opens a short detection focus for that physical string. The focus begins with an empty buffer so an older latched note cannot be mistaken for the new fret contact.
4. The focused detector chooses a window from the string's lowest possible frequency. High strings can resolve from a shorter window; low guitar and bass strings receive the longer window required for several waveform cycles.
5. `YINPitchDetector` downsamples by two, applies an RMS gate, computes the cumulative mean normalized difference function, rejects weak periodicity, and interpolates the selected period.
6. `AppModel` accepts the focused result only for the controller-labelled string. `StringPitchResolver` tests every valid fret on that string and also evaluates octave-shifted detector candidates. Results beyond the cents tolerance are rejected.
7. The accepted fret, MIDI note, frequency, cents offset, confidence, and timestamp are latched into that string's state. The pending first attack fires as soon as a valid focused result arrives; if no usable transient arrives, an adaptive timeout uses the previously latched state.
8. After detection, StringPilot records a short tail from the real iRig signal for the labelled string. `CapturedAttackProcessor` removes DC, rejects silence, finds the transient onset, trims, normalizes, fades, and stores the result by physical string.
9. A controller attack blends the string's latest real pickup transient with a newly seeded Karplus–Strong tail. If no valid real transient has been captured yet, the physical model remains a deterministic fallback rather than producing silence.
10. CoreMIDI output is optional. MIDI channels 1–6 remain separated by string. Active-string pitch updates produce pitch bend on that string's channel, and bend is reset after note-off.

## Audio graph

```text
Core Audio input ──> monitor mixer ─┐
                                     ├─> tone mixer -> distortion -> EQ -> reverb -> output
six player nodes ──> synth mixer ───┘
```

The player nodes render a hybrid attack:

```text
captured iRig fret transient ─┐
                              ├─> soft-clipped blend -> player node
new seeded string model ──────┘
```

The real transient preserves pickup character, finger contact, fret noise, and small performance differences. The physical model supplies a controllable tail for repeated controller attacks, including attacks that occur after the original physical string vibration has decayed. Palm mute changes damping and duration rather than merely reducing volume.

## Controller behavior

The controller is discovered with `GCController` and read through `GCExtendedGamepad`. StringPilot enables background controller monitoring so the controller remains active while Logic Pro or GarageBand is frontmost.

String buttons are direct and do not depend on a menu focus state. Mode and tempo controls are separate from string attacks, preventing one face button from changing meaning unexpectedly. Press state is tracked explicitly. Disconnecting or replacing the controller synthesizes release events for every held string so a tremolo timer cannot remain stuck.

## Timing

Held tremolo and pattern playback use `DispatchSourceTimer` on a user-interactive serial queue with one millisecond leeway. The interval is calculated from BPM and events per beat. Each callback returns to the main actor before changing performance state.

The first attack is separate from the repeat timer. Focused pitch detection can release it early. Otherwise, its fallback delay is based on the open-string period, allowing high strings to respond quickly while giving low guitar and bass strings enough time to produce several measurable cycles. Tremolo begins one repeat interval after that initial attack, preventing an accidental doubled first note.

## Failure handling

- Audio does not start when the selected input has a zero sample rate or channel count.
- Input and output selection stays local to StringPilot and rebuilds the graph after a device change.
- Pitch below the RMS gate is ignored rather than converted to a random note.
- Low-confidence periodicity is ignored.
- A focused detection buffer starts at the controller press, so stale pre-press audio is excluded.
- A detected pitch is never assigned to an unlabelled string.
- Silent or unusable capture audio is rejected and does not overwrite a valid real attack.
- Out-of-range pattern strings are rejected with a specific message.
- MIDI note-off and pitch-bend reset are sent before retriggering an already active note on the same string.
- Stopping, changing profiles, disabling MIDI, switching destinations, closing the window, or disconnecting the controller clears the relevant timers and notes.
- CoreMIDI broadcasts through the StringPilot virtual source and optionally sends to one selected destination.
