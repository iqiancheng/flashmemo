import Foundation
import SwiftData
internal import Combine

class FlashMemoManager: ObservableObject {
    static let shared = FlashMemoManager()
    
    @Published var isRecording = false
    @Published var currentTranscription: String = ""
    @Published var currentAudioFilename: String?
    
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
        
        // Setup audio buffer callback for real-time transcription
        setupAudioBufferCallback()
        
        // Setup transcription update callback
        senseVoiceService.onTranscriptionUpdate = { [weak self] transcription in
            DispatchQueue.main.async {
                self?.currentTranscription = transcription
            }
        }
    }
    
    private func setupAudioBufferCallback() {
        audioRecorder.onAudioBuffer = { [weak self] buffer in
            guard let self = self else { return }
            Task {
                _ = await self.senseVoiceService.transcribeStream(buffer: buffer)
            }
        }
    }
    
    func startRecording() {
        // 1. Warmup Model Immediately
        Task {
            await senseVoiceService.prepare()
        }
        
        // 2. Reset transcription
        DispatchQueue.main.async {
            self.currentTranscription = ""
        }
        
        // 3. Start Audio Recording
        let filename = "\(UUID().uuidString).m4a"
        if let url = audioRecorder.startRecording(filename: filename) {
            print("Started recording to \(url)")
            DispatchQueue.main.async {
                self.isRecording = true
                self.currentAudioFilename = url.lastPathComponent
            }
        }
    }
    
    func stopRecording() async {
        audioRecorder.stopRecording()
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // 3. Finalize Transcription
        let text = await senseVoiceService.finalize()
        
        // Use actual filename from recorder
        let audioFilename = currentAudioFilename ?? "\(UUID().uuidString).m4a"
        
        let memo = Memo(
            audioFilename: audioFilename,
            text: text.isEmpty ? currentTranscription : text,
            timestamp: Date(),
            location: locationService.currentLocation
        )
        
        // 4. Save to SwiftData
        await saveMemo(memo)
        
        // Reset state
        DispatchQueue.main.async {
            self.currentTranscription = ""
            self.currentAudioFilename = nil
        }
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
