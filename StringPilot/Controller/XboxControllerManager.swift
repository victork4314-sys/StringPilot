#if os(macOS)
import Foundation
import GameController

@MainActor
final class XboxControllerManager: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var controllerName = "No Xbox controller"
    @Published private(set) var rightTriggerValue: Float = 0

    var onStringButton: ((Int, Bool) -> Void)?
    var onModeCycle: ((Int) -> Void)?
    var onTempoChange: ((Double) -> Void)?
    var onStrum: ((Bool) -> Void)?
    var onPatternToggle: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private weak var activeController: GCController?
    private var strumLatch = false

    init() {
        GCController.shouldMonitorBackgroundEvents = true
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            Task { @MainActor in self?.configure(controller) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            Task { @MainActor in self?.disconnect(controller) }
        })

        if let existing = GCController.controllers().first(where: { $0.extendedGamepad != nil }) {
            configure(existing)
        } else {
            GCController.startWirelessControllerDiscovery(completionHandler: nil)
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func configure(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        activeController = controller
        isConnected = true
        controllerName = controller.vendorName ?? "Xbox controller"

        bind(gamepad.buttonA, stringIndex: 0)
        bind(gamepad.buttonB, stringIndex: 1)
        bind(gamepad.buttonX, stringIndex: 2)
        bind(gamepad.buttonY, stringIndex: 3)
        bind(gamepad.leftShoulder, stringIndex: 4)
        bind(gamepad.rightShoulder, stringIndex: 5)

        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onModeCycle?(-1) }
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onModeCycle?(1) }
        }
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onTempoChange?(2) }
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onTempoChange?(-2) }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in self?.rightTriggerValue = value }
        }
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, _, y in
            Task { @MainActor in self?.handleStrumAxis(y) }
        }
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onPatternToggle?() }
        }
    }

    private func bind(_ button: GCControllerButtonInput, stringIndex: Int) {
        button.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in self?.onStringButton?(stringIndex, pressed) }
        }
    }

    private func handleStrumAxis(_ y: Float) {
        if abs(y) < 0.22 {
            strumLatch = false
            return
        }
        guard !strumLatch, abs(y) > 0.68 else { return }
        strumLatch = true
        onStrum?(y > 0)
    }

    private func disconnect(_ controller: GCController) {
        guard activeController === controller else { return }
        activeController = nil
        isConnected = false
        controllerName = "No Xbox controller"
        rightTriggerValue = 0
        if let replacement = GCController.controllers().first(where: { $0.extendedGamepad != nil }) {
            configure(replacement)
        }
    }
}
#endif
