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
        
        // Setup transcription update callback (for UI updates if needed)
        senseVoiceService.onTranscriptionUpdate = { [weak self] transcription in
            DispatchQueue.main.async {
                self?.currentTranscription = transcription
            }
        }
    }
    
    func startRecording() {
        // Request fresh location update when starting recording
        locationService.requestLocation()
        
        // Optimistically update UI immediately to avoid lag
        DispatchQueue.main.async {
            self.currentTranscription = ""
            self.isRecording = true
        }
        
        // Start Audio Recording asynchronously (AAC format, hardware accelerated)
        let filename = "\(UUID().uuidString).m4a"
        Task {
            if let url = await audioRecorder.startRecording(filename: filename) {
                print("Started recording to \(url)")
                await MainActor.run {
                    self.isRecording = true
                    self.currentAudioFilename = url.lastPathComponent
                }
            } else {
                // If recording failed, revert UI state
                await MainActor.run {
                    self.isRecording = false
                    self.currentAudioFilename = nil
                }
            }
        }
    }
    
    func stopRecording() async {
        // Stop recording (saves AAC file)
        audioRecorder.stopRecording()
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Get audio file URL
        guard let audioURL = audioRecorder.getCurrentAudioURL(),
              let audioFilename = currentAudioFilename else {
            print("No audio file URL available")
            return
        }
        
        // Save memo immediately without transcription (will be updated later)
        let memo = Memo(
            audioFilename: audioFilename,
            text: "",  // Empty initially, will be updated after transcription
            timestamp: Date(),
            location: locationService.currentLocation
        )
        
        await saveMemo(memo)
        
        // Start async transcription in background
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Prepare transcription service
            await self.senseVoiceService.prepare()
            
            // Transcribe the complete audio file (better accuracy)
            let transcription = await self.senseVoiceService.transcribeFile(url: audioURL)
            
            // Update memo with transcription
            await MainActor.run {
                guard let container = self.modelContainer else { return }
                let context = container.mainContext
                
                // Find the memo by audio filename
                let descriptor = FetchDescriptor<Memo>(
                    predicate: #Predicate<Memo> { $0.audioFilename == audioFilename }
                )
                
                if let memos = try? context.fetch(descriptor),
                   let memo = memos.first {
                    memo.text = transcription.isEmpty ? "No transcription available" : transcription
                    try? context.save()
                    
                    // Update UI
                    self.currentTranscription = transcription
                }
            }
        }
        
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
