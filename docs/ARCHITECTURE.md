# Architecture

## Runtime pipeline

1. `AudioEngineController` opens the current Core Audio input and installs a 512-frame observation tap.
2. Input frames are copied off the audio callback and processed on a dedicated user-interactive queue.
3. `YINPitchDetector` downsamples by two, applies an RMS gate, computes the cumulative mean normalized difference function, rejects weak periodicity, and interpolates the selected period.
4. `AppModel` accepts a detected pitch only when one controller-labelled string is active or within the short capture window created by a new string press.
5. `StringPitchResolver` tests every valid fret for that physical string and also evaluates octave-shifted detector candidates. Results beyond the cents tolerance are rejected.
6. The accepted fret, MIDI note, frequency, cents offset, confidence, and timestamp are latched into that string's state.
7. A controller attack triggers both the internal plucked-string engine and CoreMIDI output, depending on settings.
8. MIDI channels 1–6 remain separated by string. Active-string pitch updates produce pitch bend on that string's channel.

## Audio graph

```text
Core Audio input ──> monitor mixer ─┐
                                    ├─> tone mixer -> distortion -> EQ -> reverb -> output
six player nodes ──> synth mixer ───┘
```

The internal attack uses a seeded Karplus–Strong delay-line model. Every attack gets a new excitation seed. Palm mute changes damping and duration rather than merely reducing volume.

## Controller behavior

The controller is discovered with `GCController` and read through `GCExtendedGamepad`. StringPilot enables background controller monitoring so the controller remains active while Logic Pro or GarageBand is frontmost.

String buttons are direct and do not depend on a menu focus state. Mode and tempo controls are separate from string attacks, preventing one face button from changing meaning unexpectedly.

## Timing

Held tremolo and pattern playback use `DispatchSourceTimer` on a user-interactive serial queue with one millisecond leeway. The interval is calculated from BPM and events per beat. Each callback returns to the main actor before changing performance state.

## Failure handling

- Audio does not start when the selected input has a zero sample rate or channel count.
- Pitch below the RMS gate is ignored rather than converted to a random note.
- Low-confidence periodicity is ignored.
- A detected pitch is never assigned to an unlabelled string.
- Out-of-range pattern strings are rejected with a specific message.
- MIDI note-off is sent before retriggering an already active note on the same string.
- CoreMIDI broadcasts through the StringPilot virtual source and optionally sends to one selected destination.
