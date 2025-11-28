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
        // Set to false to only get final complete result, ensuring we capture the entire audio
        // This prevents partial results from overwriting previous segments in long recordings
        recognitionRequest.shouldReportPartialResults = false
        recognitionRequest.taskHint = .dictation
        
        return await withCheckedContinuation { continuation in
            var finalTranscription = ""
            var hasResumed = false
            
            let recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    print("File recognition error: \(error.localizedDescription)")
                    if !hasResumed {
                        hasResumed = true
                        // Return whatever transcription we have, or empty string if none
                        continuation.resume(returning: finalTranscription.isEmpty ? "" : finalTranscription)
                    }
                    return
                }
                
                if let result = result {
                    // With shouldReportPartialResults = false, we only get final results
                    // This ensures bestTranscription contains the complete transcription of the entire audio file
                    finalTranscription = result.bestTranscription.formattedString
                    print("Transcription received: \(finalTranscription.prefix(50))... (length: \(finalTranscription.count))")
                    
                    // Since shouldReportPartialResults = false, result.isFinal should always be true
                    if result.isFinal && !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: finalTranscription.isEmpty ? "No transcription available" : finalTranscription)
                    }
                }
            }
            
            // Increase timeout for longer recordings (up to 5 minutes)
            // Calculate timeout based on estimated audio duration (roughly 2x audio length + buffer)
            Task {
                // Wait up to 5 minutes for very long recordings
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                if !hasResumed {
                    print("Transcription timeout - returning partial result")
                    recognitionTask.cancel()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: finalTranscription.isEmpty ? "" : finalTranscription)
                    }
                }
            }
        }
    }
}
