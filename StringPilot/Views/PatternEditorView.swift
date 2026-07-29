#if os(macOS)
import SwiftUI

struct PatternEditorView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settingsStore: SettingsStore
    @State private var patternText: String
    @State private var errorMessage: String?

    init(model: AppModel) {
        self.model = model
        settingsStore = model.settingsStore
        _patternText = State(initialValue: PatternParser().render(model.settings.pattern.steps))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Patterns are optional. Free playing and held tremolo work without one.")
                .foregroundStyle(.secondary)

            GroupBox("Pattern") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Example: 1 2 1 2 - 3!", text: $patternText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { apply() }

                    HStack {
                        Button("Apply pattern") { apply() }
                        Button(model.isPatternPlaying ? "Stop" : "Play") { model.togglePattern() }
                            .keyboardShortcut(.space, modifiers: [])
                        Toggle("Loop", isOn: $settingsStore.settings.pattern.loops)
                        Spacer()
                    }

                    Text("Use 1–\(model.profile.strings.count) for strings, “-” for a rest, and “!” after a string number for an accent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }

            GroupBox("Playback") {
                HStack(spacing: 18) {
                    Stepper("\(Int(settingsStore.settings.bpm)) BPM", value: $settingsStore.settings.bpm, in: 30...300, step: 1)
                    Picker("Division", selection: $settingsStore.settings.subdivision) {
                        ForEach(NoteSubdivision.allCases) { division in
                            Text(division.rawValue).tag(division)
                        }
                    }
                    .frame(width: 150)
                    Spacer()
                }
            }

            GroupBox("Steps") {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(settingsStore.settings.pattern.steps.enumerated()), id: \.element.id) { index, step in
                            VStack(spacing: 4) {
                                Text(step.stringNumber.map(String.init) ?? "—")
                                    .font(.title2.monospaced())
                                if step.accent { Text("accent").font(.caption2) }
                            }
                            .frame(width: 54, height: 52)
                            .background(index == model.patternStepIndex - 1 && model.isPatternPlaying ? Color.accentColor.opacity(0.24) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Spacer()
        }
    }

    private func apply() {
        do {
            try model.applyPatternText(patternText)
            patternText = PatternParser().render(model.settings.pattern.steps)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
