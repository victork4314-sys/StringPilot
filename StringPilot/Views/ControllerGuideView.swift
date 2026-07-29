#if os(macOS)
import SwiftUI

struct ControllerGuideView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var controller: XboxControllerManager

    init(model: AppModel) {
        self.model = model
        controller = model.controller
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label(controller.controllerName, systemImage: "gamecontroller.fill")
                        .font(.title3)
                    Spacer()
                    Text(controller.isConnected ? "Connected" : "Connect over Bluetooth or USB")
                        .foregroundStyle(controller.isConnected ? .green : .orange)
                }

                GroupBox("Direct string buttons") {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                        ForEach(Array(model.profile.strings.enumerated()), id: \.element.id) { index, string in
                            GridRow {
                                Text(index < AppModel.directButtons.count ? AppModel.directButtons[index].rawValue : "—")
                                    .font(.headline.monospaced())
                                    .frame(width: 42)
                                Text(string.name)
                                Text(model.settings.mode == .tremolo ? "Hold to tremolo-pick" : "Press to pick")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                GroupBox("Performance controls") {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                        controlRow("D-pad left / right", "Previous or next mode")
                        controlRow("D-pad up / down", "Tempo +2 / −2 BPM")
                        controlRow("Right trigger", "Attack strength")
                        controlRow("Right stick up / down", "Upstroke / downstroke in Strum mode")
                        controlRow("Menu ☰", "Start or stop the saved pattern")
                    }
                }

                GroupBox("How pitch capture works") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keep the guitar or bass connected through the iRig. Press or hold the controller button for the string you are fretting. That button labels the incoming fret vibration as that physical string.")
                        Text("The app latches the most recent valid fret for each string. When several strings are already fretted, each saved string state remains available for strums and patterns instead of guessing from one mixed pickup signal.")
                        Text("For the cleanest capture, make a small normal fret contact, hammer-on, pull-off, or slide while that string’s button is active. Sensitivity and the noise gate are adjustable in Sound.")
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func controlRow(_ control: String, _ action: String) -> some View {
        GridRow {
            Text(control).font(.headline)
            Text(action)
        }
    }
}
#endif
