import AVFoundation
import Foundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    
    func startRecording(filename: String) -> URL? {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
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
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000, // SenseVoice usually likes 16k
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
            return audioFilename
        } catch {
            print("Could not start recording: \(error)")
            return nil
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        audioRecorder = nil
    }
}
