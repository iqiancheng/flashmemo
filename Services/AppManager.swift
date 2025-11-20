import Foundation
internal import Combine
import SwiftData

class AppManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    static let shared = AppManager()
    
    let audioRecorder = AudioRecorder()
    let locationService = LocationService()
    let senseVoiceService = LocalSenseVoiceService()
    
    // SwiftData Container for background saving
    var modelContainer: ModelContainer?
    
    private init() {
        // Initialize ModelContainer with App Group for shared access
        do {
            let schema = Schema([Memo.self])
            let modelConfiguration: ModelConfiguration
            
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier) {
                let databaseURL = containerURL.appendingPathComponent("FlashMemo.store")
                modelConfiguration = ModelConfiguration(schema: schema, url: databaseURL)
            } else {
                print("WARNING: App Group not configured. Falling back to default container.")
                modelConfiguration = ModelConfiguration(schema: schema)
            }
            
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Failed to create ModelContainer: \(error)")
        }
    }
    
    func startRecording() {
        // 1. Warmup Model Immediately
        Task {
            await senseVoiceService.prepare()
        }
        
        // 2. Start Audio Recording
        let filename = "\(UUID().uuidString).m4a"
        if let url = audioRecorder.startRecording(filename: filename) {
            print("Started recording to \(url)")
        }
    }
    
    func stopRecording() async {
        audioRecorder.stopRecording()
        
        // 3. Finalize Transcription (Instant)
        let text = await senseVoiceService.finalize()
        
        let memo = Memo(
            audioFilename: "mock.m4a", // In real app, use actual filename
            text: text,
            timestamp: Date(),
            location: locationService.currentLocation
        )
        
        // 4. Save to SwiftData
        saveMemo(memo)
    }
    
    @MainActor
    private func saveMemo(_ memo: Memo) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        context.insert(memo)
        // Auto-save is implicit in SwiftData main context, but explicit save is safer for background contexts
        try? context.save()
    }
    
    // Helper for Intent to trigger warmup even before recording starts
    func warmup() {
        Task {
            await senseVoiceService.prepare()
        }
    }
}

