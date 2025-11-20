import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    // AVAudioRecorder for high-quality AAC recording (hardware accelerated, smooth playback)
    private var audioRecorder: AVAudioRecorder?
    
    // AVAudioEngine for real-time audio buffer processing (for transcription only)
    private var audioEngine: AVAudioEngine?
    
    private var currentAudioURL: URL?
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    // Format for transcription (16kHz)
    private var transcriptionFormat: AVAudioFormat?
    
    @Published var isRecording = false
    
    func startRecording(filename: String) -> URL? {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Configure audio session to support both recording and engine
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return nil
        }
        
        var docDir: URL?
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier) {
            docDir = groupURL
        } else {
            docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        
        guard let storageDir = docDir else { return nil }
        let audioFilename = storageDir.appendingPathComponent(filename)
        currentAudioURL = audioFilename
        
        // Setup AVAudioRecorder for high-quality AAC recording (hardware accelerated)
        let recorderSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,  // Standard sample rate for playback
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000  // 128 kbps for good quality
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: recorderSettings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            
            guard audioRecorder?.record() == true else {
                print("Failed to start AVAudioRecorder")
                return nil
            }
        } catch {
            print("Failed to create AVAudioRecorder: \(error)")
            return nil
        }
        
        // Setup AVAudioEngine for real-time buffer processing (for transcription only)
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            audioRecorder?.stop()
            return nil
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Transcription format: 16kHz mono Float32 for transcription
        transcriptionFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                           sampleRate: 16000.0,
                                           channels: 1,
                                           interleaved: false)
        
        guard let transcriptionFormat = transcriptionFormat else {
            print("Failed to create transcription format")
            audioRecorder?.stop()
            return nil
        }
        
        // Install tap to get real-time audio buffers for transcription only
        // Use a smaller buffer size to reduce latency
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            
            // Convert to transcription format (16kHz) for transcription
            if let transcriptionFormat = self.transcriptionFormat,
               let convertedBuffer = self.convertBuffer(buffer, to: transcriptionFormat) {
                // Send buffer for real-time transcription (async to avoid blocking)
                DispatchQueue.global(qos: .userInitiated).async {
                    self.onAudioBuffer?(convertedBuffer)
                }
            }
        }
        
        // Start audio engine
        do {
            try audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
            }
            return audioFilename
        } catch {
            print("Could not start audio engine: \(error)")
            audioRecorder?.stop()
            return nil
        }
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.format.isEqual(format) == false else {
            return buffer
        }
        
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Buffer conversion error: \(error)")
            return nil
        }
        
        return convertedBuffer
    }
    
    func stopRecording() {
        // Stop AVAudioRecorder (saves the AAC file)
        audioRecorder?.stop()
        audioRecorder = nil
        
        // Stop AVAudioEngine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
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
