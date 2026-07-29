#if os(macOS)
import SwiftUI

@main
struct StringPilotApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear { model.start() }
                .onDisappear { model.stop() }
        }
        .commands {
            CommandMenu("Performance") {
                Button("Single mode") { model.setMode(.single) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Tremolo mode") { model.setMode(.tremolo) }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Strum mode") { model.setMode(.strum) }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Pattern mode") { model.setMode(.pattern) }
                    .keyboardShortcut("4", modifiers: [.command])
                Divider()
                Button(model.isPatternPlaying ? "Stop pattern" : "Start pattern") {
                    model.togglePattern()
                }
            }
        }
    }
}
#endif
