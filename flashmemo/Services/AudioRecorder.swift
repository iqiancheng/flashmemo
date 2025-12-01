import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    // AVAudioRecorder for high-quality AAC recording (hardware accelerated, smooth playback)
    private var audioRecorder: AVAudioRecorder?
    
    private var currentAudioURL: URL?
    
    @Published var isRecording = false
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 5) // 5 bars for waveform
    private var meteringTimer: Timer?
    
    // Async version to avoid blocking UI thread
    func startRecording(filename: String) async -> URL? {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let audioSession = AVAudioSession.sharedInstance()
                do {
                    try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                    try audioSession.setActive(true)
                } catch {
                    print("Failed to set up audio session: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                var docDir: URL?
                if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier) {
                    docDir = groupURL
                } else {
                    docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                }
                
                guard let storageDir = docDir else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let audioFilename = storageDir.appendingPathComponent(filename)
                
                // Setup AVAudioRecorder for high-quality AAC recording (hardware accelerated)
                let recorderSettings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100.0,  // Standard sample rate for playback
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                    AVEncoderBitRateKey: 128000  // 128 kbps for good quality
                ]
                
                do {
                    let recorder = try AVAudioRecorder(url: audioFilename, settings: recorderSettings)
                    recorder.delegate = self
                    
                    // Enable metering for real-time audio level monitoring
                    recorder.isMeteringEnabled = true
                    
                    // Prepare recording synchronously to minimize delay
                    guard recorder.prepareToRecord() else {
                        print("Failed to prepare AVAudioRecorder")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Start recording immediately after preparation to avoid losing initial audio
                    guard recorder.record() else {
                        print("Failed to start AVAudioRecorder")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Update state on main thread
                    await MainActor.run {
                        self.audioRecorder = recorder
                        self.currentAudioURL = audioFilename
                        self.isRecording = true
                        self.startMetering()
                    }
                    
                    continuation.resume(returning: audioFilename)
                } catch {
                    print("Failed to create AVAudioRecorder: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func stopRecording() {
        // Stop metering timer
        stopMetering()
        
        // Stop AVAudioRecorder (saves the AAC file)
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            // Reset audio levels
            self.audioLevels = Array(repeating: 0.0, count: 5)
        }
    }
    
    private func startMetering() {
        // Ensure timer runs on main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update audio levels every 0.05 seconds (20 times per second) for smooth visualization
            self.meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder else { return }
                
                // Update metering values (must be called before reading power values)
                recorder.updateMeters()
                
                // Get both average and peak power for channel 0 (mono recording)
                let averagePower = recorder.averagePower(forChannel: 0)
                let peakPower = recorder.peakPower(forChannel: 0)
                
                // Convert dB to linear scale (0.0 to 1.0)
                // Typical range: -160 dB (silence) to 0 dB (maximum)
                // We'll map -60 dB to 0.0 and 0 dB to 1.0 for better visualization
                let minDB: Float = -60.0
                let maxDB: Float = 0.0
                let normalizedAverage = max(0.0, min(1.0, (averagePower - minDB) / (maxDB - minDB)))
                let normalizedPeak = max(0.0, min(1.0, (peakPower - minDB) / (maxDB - minDB)))
                
                // Create waveform pattern that reflects real audio characteristics
                // Use a combination of average and peak power with natural variations
                var levels: [Float] = []
                let time = Float(Date().timeIntervalSince1970)
                
                for i in 0..<5 {
                    // Create a wave pattern that reflects audio frequency characteristics
                    // Each bar represents a different "frequency band" with slight phase differences
                    let phase = Float(i) * 0.5 + time * 3.0
                    let frequencyVariation = sin(phase) * 0.15
                    
                    // Combine average power (overall level) with peak power (transients)
                    // and frequency variation for a more realistic waveform
                    let baseLevel = normalizedAverage * 0.7 + normalizedPeak * 0.3
                    let barLevel = max(0.15, min(1.0, baseLevel + frequencyVariation))
                    
                    levels.append(barLevel)
                }
                
                // Update audio levels on main thread to trigger view refresh
                self.audioLevels = levels
            }
            
            // Add timer to RunLoop to ensure it fires
            if let timer = self.meteringTimer {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }
    
    /// Convert AAC file to 16kHz PCM buffers for transcription
    func convertAACToPCMBuffers(audioURL: URL, completion: @escaping ([AVAudioPCMBuffer]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let audioFile = try? AVAudioFile(forReading: audioURL) else {
                print("Failed to open audio file for reading")
                completion([])
                return
            }
            
            // Target format: 16kHz mono Float32 for transcription
            guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                  sampleRate: 16000.0,
                                                  channels: 1,
                                                  interleaved: false) else {
                print("Failed to create target format")
                completion([])
                return
            }
            
            var buffers: [AVAudioPCMBuffer] = []
            let bufferSize: AVAudioFrameCount = 4096
            
            // Read and convert audio file
            while let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: bufferSize) {
                do {
                    try audioFile.read(into: buffer, frameCount: bufferSize)
                    let frameCount = buffer.frameLength
                    if frameCount == 0 {
                        break
                    }
                    
                    // Convert if needed
                    if !audioFile.processingFormat.isEqual(targetFormat) {
                        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat),
                              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
                            continue
                        }
                        
                        var error: NSError?
                        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                            outStatus.pointee = .haveData
                            return buffer
                        }
                        
                        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                        
                        if error == nil {
                            buffers.append(convertedBuffer)
                        }
                    } else {
                        buffers.append(buffer)
                    }
                } catch {
                    print("Error reading audio file: \(error)")
                    break
                }
            }
            
            completion(buffers)
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Audio recording finished with error")
        } else {
            print("Audio recording finished successfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio recorder encode error: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func getCurrentAudioURL() -> URL? {
        return currentAudioURL
    }
}
