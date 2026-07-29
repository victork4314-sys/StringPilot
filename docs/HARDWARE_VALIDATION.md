# Hardware validation matrix

Automated tests verify the signal mathematics and source-level behavior. The checks below require a physical Mac, audio interface, instrument, and Xbox controller because CI cannot manufacture those electrical and Bluetooth inputs.

## Required equipment

- Apple-silicon Mac running macOS 14 or newer.
- Xbox Wireless Controller connected once over USB and once over Bluetooth.
- iRig or another Core Audio interface.
- Six-string electric guitar in standard tuning.
- Four-string bass in standard tuning.
- Headphones connected to the selected output to prevent acoustic feedback.
- Logic Pro and GarageBand for routing checks.

## Audio and detection

- Launch with no interface connected: app shows a specific no-input failure and does not crash.
- Connect iRig, refresh devices, select it, and restart audio.
- Confirm input meter responds to light fret contact without strumming.
- Calibrate sensitivity from 0.5× upward until fret contact is detected.
- Raise the noise gate until idle room noise no longer produces pitch changes.
- Test open strings and frets 1, 5, 12, 17, and 24 on all six guitar strings.
- Test open strings and frets 1, 5, 12, and 20 on all four bass strings.
- Test hammer-ons, pull-offs, slides, and normal finger placement.
- Verify the same pitch on two different strings resolves according to the pressed controller button.
- Verify silence leaves the previous latched string state unchanged.

## Xbox controller

- Verify A/B/X/Y/LB/RB trigger strings 1–6 exactly once in Single mode.
- Verify all six controls report press and release over USB.
- Repeat over Bluetooth.
- Hold every string button in Tremolo mode and verify repetition stops immediately on release.
- Change BPM with D-pad up/down while a tremolo button is held; verify the timer updates without doubling.
- Cycle modes with D-pad left/right.
- Verify right-trigger pressure changes MIDI velocity and internal attack strength.
- Verify right-stick up/down produces one strum per deflection and does not retrigger until the stick returns near center.
- Put Logic Pro in front and confirm background controller events continue.

## Audio output

- Verify monitor disabled produces only the generated attack.
- Verify monitor enabled blends the real iRig input.
- Sweep output gain, palm mute, drive, and reverb through their full ranges.
- Confirm rapid thirty-second-note tremolo does not accumulate runaway volume.
- Change input and output devices while stopped and while running; restart audio and verify recovery.

## MIDI and DAWs

- Confirm StringPilot appears as a virtual MIDI source in Audio MIDI Setup.
- In Logic Pro, enable Logic Pro Virtual In and select it as StringPilot's destination.
- Record all six strings and verify channels 1–6, note-on, note-off, velocity, and pitch bend.
- Verify no stuck notes after stopping a pattern or quitting the app.
- In GarageBand, record from the StringPilot virtual source.
- Record iRig audio to a separate track and apply a GarageBand/Logic amp plug-in.

## Patterns

- Apply `1 2 1 2`, play once, loop, and stop from the UI and controller Menu button.
- Apply rests and accents with `1 - 2! -`.
- Confirm invalid strings are rejected for four- and five-string profiles.
- Change tempo and subdivision during playback and verify playback restarts at the new rate without overlapping timers.
