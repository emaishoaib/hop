import Sparkle

@MainActor
final class AppUpdater {
    static let shared = AppUpdater()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private(set) var hasStarted = false

    func start() {
        #if !DEBUG
        controller.startUpdater()
        hasStarted = true
        #endif
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
