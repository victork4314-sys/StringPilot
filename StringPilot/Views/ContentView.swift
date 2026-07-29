#if os(macOS)
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            PlayView(model: model)
                .tabItem { Label("Play", systemImage: "waveform") }
            SoundSetupView(model: model)
                .tabItem { Label("Sound", systemImage: "slider.horizontal.3") }
            PatternEditorView(model: model)
                .tabItem { Label("Patterns", systemImage: "repeat") }
            RoutingView(model: model)
                .tabItem { Label("Routing", systemImage: "cable.connector") }
            ControllerGuideView(model: model)
                .tabItem { Label("Controls", systemImage: "gamecontroller") }
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 650)
        .alert("StringPilot", isPresented: Binding(
            get: { model.bannerMessage != nil },
            set: { if !$0 { model.bannerMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.bannerMessage = nil }
        } message: {
            Text(model.bannerMessage ?? "")
        }
    }
}
#endif
