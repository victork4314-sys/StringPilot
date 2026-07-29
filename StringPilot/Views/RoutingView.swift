#if os(macOS)
import CoreMIDI
import SwiftUI

struct RoutingView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var midi: MIDIOutput

    init(model: AppModel) {
        self.model = model
        settingsStore = model.settingsStore
        midi = model.midi
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("MIDI output") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Send notes and per-string pitch bend", isOn: $settingsStore.settings.sendMIDI)
                    HStack {
                        Text("Destination")
                        Picker("Destination", selection: Binding<MIDIUniqueID?>(
                            get: { midi.selectedDestinationID },
                            set: { model.selectMIDIDestination($0) }
                        )) {
                            Text("Virtual source only").tag(MIDIUniqueID?.none)
                            ForEach(midi.destinations) { destination in
                                Text(destination.name).tag(Optional(destination.id))
                            }
                        }
                        .frame(maxWidth: 420)
                        Button("Refresh") { midi.refreshDestinations() }
                    }

                    Label(
                        midi.isAvailable ? "StringPilot virtual MIDI source is active" : "CoreMIDI is unavailable",
                        systemImage: midi.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(midi.isAvailable ? .green : .red)

                    if let error = midi.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }

            GroupBox("Logic Pro") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Open Logic Pro and enable Logic Pro Virtual In under Settings → MIDI → Inputs.")
                    Text("2. Return here, refresh destinations, and select Logic Pro Virtual In.")
                    Text("3. Record-enable a software-instrument track. StringPilot sends strings 1–6 on MIDI channels 1–6.")
                }
            }

            GroupBox("GarageBand") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keep “Virtual source only” selected. GarageBand receives the StringPilot virtual MIDI source as a MIDI controller.")
                    Text("Choose a software-instrument track for generated sound. The iRig’s real audio can be recorded on a separate audio track when you want the fret noise and amp chain as well.")
                }
            }

            Spacer()
        }
    }
}
#endif
