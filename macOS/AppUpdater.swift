import Sparkle

@MainActor
final class AppUpdater {
    static let shared = AppUpdater()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func start() {
        #if !DEBUG
        controller.startUpdater()
        #endif
    }
}
