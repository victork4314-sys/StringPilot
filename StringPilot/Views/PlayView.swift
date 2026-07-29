#if os(macOS)
import SwiftUI

struct PlayView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var audio: AudioEngineController
    @ObservedObject private var controller: XboxControllerManager

    init(model: AppModel) {
        self.model = model
        settingsStore = model.settingsStore
        audio = model.audio
        controller = model.controller
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusRow
            performanceControls
            Divider()
            stringGrid
            Spacer(minLength: 0)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            StatusBadge(
                title: "Audio",
                value: audio.state.label,
                good: audio.state == .running
            )
            StatusBadge(
                title: "Controller",
                value: controller.controllerName,
                good: controller.isConnected
            )
            StatusBadge(
                title: "Pitch",
                value: pitchLabel,
                good: audio.latestPitch != nil
            )
            Spacer()
            inputMeter
        }
    }

    private var performanceControls: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Mode").font(.caption).foregroundStyle(.secondary)
                Picker("Mode", selection: Binding(
                    get: { settingsStore.settings.mode },
                    set: { model.setMode($0) }
                )) {
                    ForEach(PerformanceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 420)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tempo").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button { model.adjustTempo(-1) } label: { Image(systemName: "minus") }
                    Text("\(Int(settingsStore.settings.bpm)) BPM")
                        .monospacedDigit()
                        .frame(minWidth: 84)
                    Button { model.adjustTempo(1) } label: { Image(systemName: "plus") }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Repeat division").font(.caption).foregroundStyle(.secondary)
                Picker("Repeat division", selection: $settingsStore.settings.subdivision) {
                    ForEach(NoteSubdivision.allCases) { division in
                        Text(division.rawValue).tag(division)
                    }
                }
                .frame(width: 100)
            }
            Spacer()
        }
    }

    private var stringGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 12)], spacing: 12) {
            ForEach(Array(model.stringStates.enumerated()), id: \.element.id) { index, state in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(model.profile.strings[index].name)
                            .font(.headline)
                        Spacer()
                        Text(buttonName(index))
                            .font(.headline.monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.quaternary, in: Capsule())
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(PitchMath.noteName(forMIDINote: state.midiNote))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text("fret \(state.fret)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if state.isHeld {
                            Label("held", systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    HStack {
                        Text(String(format: "%.1f Hz", state.frequency))
                        Text(String(format: "%+.0f cents", state.centsOffset))
                        Spacer()
                        Button("Test") { model.testPick(index: index) }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(state.isHeld ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: state.isHeld ? 2 : 1)
                }
            }
        }
    }

    private var inputMeter: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Input \(Int(audio.inputLevelDB)) dB")
                .font(.caption.monospacedDigit())
            ProgressView(value: min(1, max(0, (audio.inputLevelDB + 80) / 80)))
                .frame(width: 140)
        }
    }

    private var pitchLabel: String {
        guard let pitch = audio.latestPitch else { return "Waiting for fret signal" }
        let note = Int(round(PitchMath.midiNote(forFrequency: pitch.frequency)))
        return "\(PitchMath.noteName(forMIDINote: note)) · \(Int(pitch.confidence * 100))%"
    }

    private func buttonName(_ index: Int) -> String {
        guard AppModel.directButtons.indices.contains(index) else { return "—" }
        return AppModel.directButtons[index].rawValue
    }
}

private struct StatusBadge: View {
    let title: String
    let value: String
    let good: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle().fill(good ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(value).lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
#endif
