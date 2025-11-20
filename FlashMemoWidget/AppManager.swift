import Foundation

final class AppManager {
    static let shared = AppManager()
    private init() {}

    func warmup() {
        // No-op in intent/widget target. Real implementation should live in the app target or shared module.
    }

    func startRecording() {
        // No-op in intent/widget target. Real implementation should live in the app target or shared module.
    }
}
