import ActivityKit
import Foundation

struct FlashMemoAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state variables
        var duration: TimeInterval
        var isRecording: Bool
    }

    // Fixed non-changing properties
    var recordingName: String
}
