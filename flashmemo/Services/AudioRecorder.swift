import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    // AVAudioRecorder for high-quality AAC recording (hardware accelerated, smooth playback)
    private var audioRecorder: AVAudioRecorder?
    
    private var currentAudioURL: URL?
    
    @Published var isRecording = false
    
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
        // Stop AVAudioRecorder (saves the AAC file)
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
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
