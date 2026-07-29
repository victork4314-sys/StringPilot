# Hardware validation matrix

Automated tests verify the signal mathematics, source-level behavior, native Xcode build, and synthetic capture processing. The checks below require a physical Mac, audio interface, instrument, and Xbox controller because CI cannot manufacture those electrical, acoustic, USB, and Bluetooth inputs.

Do not describe a hardware row as passed until it has been performed on the listed equipment.

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
- Confirm selecting the iRig does not change the Mac's system-default input or output.
- Confirm input meter responds to light fret contact without conventional picking or strumming.
- Calibrate sensitivity from 0.5× upward until fret contact is detected.
- Raise the noise gate until idle electrical/room noise no longer produces pitch changes.
- Test open strings and frets 1, 5, 12, 17, and 24 on all six guitar strings.
- Test open strings and frets 1, 5, 12, and 20 on all four bass strings.
- Test hammer-ons, pull-offs, slides, vibrato, and normal finger placement.
- Verify the first controller attack uses the newly pressed fret rather than the previous latched fret.
- Verify the same pitch on two different strings resolves according to the pressed controller button.
- Verify silence leaves the previous latched string state unchanged and uses it only after the adaptive fallback delay.
- Verify a new controller press excludes audio that occurred before that press.
- Measure button-to-audio latency separately for high E guitar, low E guitar, low E bass, and low B bass.

## Real attack capture

- With input monitoring enabled, press a fret and its controller button together. Confirm the first sound includes the live pickup transient.
- Repeat the controller attack after the physical vibration decays. Confirm later attacks retain the captured pickup/fret character instead of becoming only a fixed synthetic click.
- Repeat the same note with deliberately different finger pressure and contact position. Confirm a new valid capture replaces the previous attack for that string.
- Move to a different fret after a valid capture. Confirm the captured attack is pitch-shifted with the newly resolved note and is replaced after the next valid fret transient.
- Confirm silence, cable hum, and sub-gate noise do not overwrite a valid captured attack.
- Switch instrument profiles and confirm captured attacks from the previous instrument are cleared.
- Change audio devices and confirm captures are cleared rather than replayed with an unrelated interface level or sample rate.
- Test rapid thirty-second-note tremolo and confirm capture blending does not clip, accumulate volume, or allocate enough work to cause audible dropouts.

## Xbox controller

- Verify A/B/X/Y/LB/RB trigger strings 1–6 exactly once in Single mode.
- Verify all six controls report press and release over USB.
- Repeat over Bluetooth.
- Hold every string button in Tremolo mode and verify repetition stops immediately on release.
- While tremolo is held, unplug the USB controller. Confirm all held strings release and no timer remains running.
- While tremolo is held over Bluetooth, turn off the controller. Confirm all held strings release and no timer remains running.
- Connect a replacement controller after disconnect and confirm stale press state is not inherited.
- Change BPM with D-pad up/down while a tremolo button is held; verify the timer updates without adding an immediate doubled attack.
- Cycle modes with D-pad left/right while a string button is held.
- Verify right-trigger pressure changes MIDI velocity and internal attack strength.
- Verify right-stick up/down produces one strum per deflection and does not retrigger until the stick returns near center.
- Put Logic Pro in front and confirm background controller events continue.

## Audio output

- Verify monitor disabled produces only the hybrid generated/captured attack path.
- Verify monitor enabled blends the direct real iRig input with that attack path.
- Sweep output gain, palm mute, drive, and reverb through their full ranges.
- Confirm rapid thirty-second-note tremolo does not accumulate runaway volume.
- Change input and output devices while stopped and while running; verify the graph rebuilds and resumes.
- Confirm changing StringPilot's input or output does not alter the Mac's defaults used by other apps.
- Disconnect and reconnect the iRig while running; refresh devices and verify a controlled error and successful recovery rather than a crash.

## MIDI and DAWs

- Confirm StringPilot appears as a virtual MIDI source in Audio MIDI Setup.
- In Logic Pro, enable Logic Pro Virtual In and select it as StringPilot's destination.
- Record all six strings and verify channels 1–6, note-on, note-off, velocity, and pitch bend.
- Retrigger bent notes repeatedly and verify every new note starts from the intended bend rather than inheriting stale channel bend.
- Verify no stuck notes after stopping a pattern, disabling MIDI, changing destination, changing profile, closing the window, or quitting the app.
- In GarageBand, record from the StringPilot virtual source.
- Record iRig audio to a separate track and apply a GarageBand/Logic amp plug-in.
- Put each DAW in front and confirm the Xbox controller continues to drive StringPilot in the background.

## Patterns

- Apply `1 2 1 2`, play once, loop, and stop from the UI and controller Menu button.
- Apply rests and accents with `1 - 2! -`.
- Confirm invalid strings are rejected for four- and five-string profiles.
- Change tempo and subdivision during playback and verify playback restarts at the new rate without overlapping timers.
- Stop a pattern during an active note and confirm note-off plus pitch-bend reset are sent immediately.

## Sign-off record

Record the Mac model, macOS version, controller firmware, connection type, interface model, instrument, pickup type, buffer/sample rate, and pass/fail notes for every hardware session. Keep failed rows open until the exact failure has been repaired and rerun.
