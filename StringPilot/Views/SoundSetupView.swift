#if os(macOS)
import SwiftUI

struct SoundSetupView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var devices: AudioDeviceManager

    init(model: AppModel) {
        self.model = model
        settingsStore = model.settingsStore
        devices = model.devices
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GroupBox("Instrument") {
                    Picker("Instrument profile", selection: Binding(
                        get: { settingsStore.settings.profileID },
                        set: { model.selectProfile(id: $0) }
                    )) {
                        ForEach(InstrumentProfile.all) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .frame(maxWidth: 420)
                }

                GroupBox("Audio devices") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            Text("Input")
                            Picker("Input", selection: Binding(
                                get: { devices.defaultInputID },
                                set: { model.chooseInputDevice($0) }
                            )) {
                                ForEach(devices.inputDevices) { device in
                                    Text(device.name).tag(device.id)
                                }
                            }
                        }
                        GridRow {
                            Text("Output")
                            Picker("Output", selection: Binding(
                                get: { devices.defaultOutputID },
                                set: { model.chooseOutputDevice($0) }
                            )) {
                                ForEach(devices.outputDevices) { device in
                                    Text(device.name).tag(device.id)
                                }
                            }
                        }
                    }
                    HStack {
                        Button("Refresh devices") { devices.refresh() }
                        Button("Restart audio") { model.audio.restart() }
                    }
                    .padding(.top, 8)
                    Text("A single interface with both input and headphone/output channels is the most reliable setup. If macOS cannot open two different devices together, combine them as one Aggregate Device in Audio MIDI Setup, then select that aggregate for both fields.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error = devices.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }

                GroupBox("Detection") {
                    SettingSlider(
                        title: "Input sensitivity",
                        value: $settingsStore.settings.inputSensitivity,
                        range: 0.5...15,
                        format: "%.1f×"
                    )
                    SettingSlider(
                        title: "Noise gate",
                        value: $settingsStore.settings.noiseGateDB,
                        range: -85 ... -25,
                        format: "%.0f dB"
                    )
                    Text("Raise sensitivity until fret taps register. Lower the noise gate only enough to catch the signal without tracking room noise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GroupBox("Sound") {
                    Toggle("Monitor the real instrument input", isOn: $settingsStore.settings.monitorInput)
                    SettingSlider(
                        title: "Generated attack level",
                        value: $settingsStore.settings.outputGain,
                        range: 0...1.5,
                        format: "%.2f"
                    )
                    SettingSlider(
                        title: "Palm mute",
                        value: $settingsStore.settings.palmMute,
                        range: 0...1,
                        format: "%.0f%%",
                        multiplier: 100
                    )
                    SettingSlider(
                        title: "Drive",
                        value: $settingsStore.settings.drive,
                        range: 0...24,
                        format: "%.1f dB"
                    )
                    SettingSlider(
                        title: "Reverb",
                        value: $settingsStore.settings.reverbMix,
                        range: 0...65,
                        format: "%.0f%%"
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    var multiplier: Double = 1

    var body: some View {
        HStack {
            Text(title).frame(width: 180, alignment: .leading)
            Slider(value: $value, in: range)
            Text(String(format: format, value * multiplier))
                .monospacedDigit()
                .frame(width: 82, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}
#endif
