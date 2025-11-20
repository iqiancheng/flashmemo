import AppIntents
import ActivityKit
import Foundation

struct RecordIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Flash Memo"
    static var description = IntentDescription("Starts a new audio recording.")

    func perform() async throws -> some IntentResult {
        // Start Live Activity
        let attributes = FlashMemoAttributes(recordingName: "New Memo")
        let contentState = FlashMemoAttributes.ContentState(duration: 0, isRecording: true)
        
        do {
            let activity = try Activity<FlashMemoAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("Requested Live Activity: \(activity.id)")
            
            // Trigger Warmup Immediately
            AppManager.shared.warmup()
            
            // Trigger Recording via Shared Manager
            AppManager.shared.startRecording()
            
        } catch {
            print("Error requesting Live Activity: \(error.localizedDescription)")
        }
        
        return .result()
    }
}
