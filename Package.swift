// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StringPilotCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StringPilotCore", targets: ["StringPilotCore"])
    ],
    targets: [
        .target(
            name: "StringPilotCore",
            path: "StringPilot",
            exclude: ["App", "Controller", "MIDI", "Views", "Resources", "Info.plist", "Audio/AudioDeviceManager.swift", "Audio/AudioEngineController.swift", "Utilities/RepeatScheduler.swift", "Utilities/SettingsStore.swift"],
            sources: [
                "Models/PerformanceModels.swift",
                "Models/PatternParser.swift",
                "Utilities/PitchMath.swift",
                "Audio/YINPitchDetector.swift",
                "Audio/StringPitchResolver.swift",
                "Audio/PluckedStringGenerator.swift"
            ]
        ),
        .testTarget(
            name: "StringPilotCoreTests",
            dependencies: ["StringPilotCore"],
            path: "StringPilotTests"
        )
    ]
)
