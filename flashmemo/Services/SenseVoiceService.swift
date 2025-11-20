import Foundation
import Speech
import AVFoundation

protocol SenseVoiceServiceProtocol {
    func prepare() async
    func transcribeStream(buffer: AVAudioPCMBuffer) async -> String
    func finalize() async -> String
    func transcribeFile(url: URL) async -> String
    var currentTranscription: String { get }
    var onTranscriptionUpdate: ((String) -> Void)? { get set }
}

class LocalSenseVoiceService: SenseVoiceServiceProtocol {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isModelLoaded = false
    
    private(set) var currentTranscription: String = ""
    var onTranscriptionUpdate: ((String) -> Void)?
    
    init() {
        // Initialize speech recognizer with Chinese Simplified (zh_CN) as default
        let chineseLocale = Locale(identifier: "zh_CN")
        speechRecognizer = SFSpeechRecognizer(locale: chineseLocale)
        
        // If Chinese is not available, fallback to device locale
        if speechRecognizer == nil || !(speechRecognizer?.isAvailable ?? false) {
            print("Chinese Simplified not available, falling back to device locale")
            speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        }
        
        // Check authorization
        Task {
            await requestAuthorization()
        }
    }
    
    private func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized: \(status)")
                @unknown default:
                    print("Unknown speech recognition authorization status")
                }
                continuation.resume()
            }
        }
    }
    
    func prepare() async {
        guard !isModelLoaded else { return }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        // Request authorization if needed
        await requestAuthorization()
        
        isModelLoaded = true
        print("Speech recognition ready")
    }
    
    func transcribeStream(buffer: AVAudioPCMBuffer) async -> String {
        guard isModelLoaded else { 
            await prepare()
            return ""
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return ""
        }
        
        // Create recognition request if not exists
        if recognitionRequest == nil {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest?.shouldReportPartialResults = true
            recognitionRequest?.taskHint = .dictation
            
            guard let recognitionRequest = recognitionRequest else { return "" }
            
            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Recognition error: \(error.localizedDescription)")
                    return
                }
                
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.currentTranscription = transcription
                        self.onTranscriptionUpdate?(transcription)
                    }
                }
            }
        }
        
        // Append audio buffer to recognition request
        recognitionRequest?.append(buffer)
        
        return currentTranscription
    }
    
    func finalize() async -> String {
        // Finish recognition
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Wait a bit for final results
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        let finalResult = currentTranscription
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset for next recording
        currentTranscription = ""
        
        return finalResult.isEmpty ? "No transcription available" : finalResult
    }
    
    /// Transcribe audio file directly (better accuracy than streaming)
    func transcribeFile(url: URL) async -> String {
        // Ensure speech recognizer is available
        if speechRecognizer == nil || !(speechRecognizer?.isAvailable ?? false) {
            await prepare()
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return ""
        }
        
        // Request authorization if needed
        await requestAuthorization()
        
        // Create file recognition request
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        recognitionRequest.shouldReportPartialResults = true  // Get partial results too
        recognitionRequest.taskHint = .dictation
        
        return await withCheckedContinuation { continuation in
            var finalTranscription = ""
            var hasResumed = false
            
            let recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    print("File recognition error: \(error.localizedDescription)")
                    if !hasResumed {
                        hasResumed = true
                        // Return partial result if available, otherwise empty string
                        continuation.resume(returning: finalTranscription.isEmpty ? "" : finalTranscription)
                    }
                    return
                }
                
                if let result = result {
                    finalTranscription = result.bestTranscription.formattedString
                    
                    // Resume when final result is available
                    if result.isFinal && !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: finalTranscription)
                    }
                }
            }
            
            // Cancel task after timeout (60 seconds for longer recordings)
            Task {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if !hasResumed {
                    recognitionTask.cancel()
                    // If cancelled, return whatever transcription we have so far
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: finalTranscription)
                    }
                }
            }
        }
    }
}
