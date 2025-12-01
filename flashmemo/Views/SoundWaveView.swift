import SwiftUI

struct SoundWaveView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    let barCount: Int = 5
    let barWidth: CGFloat = 4
    let barSpacing: CGFloat = 3
    let minHeight: CGFloat = 8
    let maxHeight: CGFloat = 30
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: barWidth, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.05), value: audioRecorder.audioLevels)
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        // Use real audio level if available, otherwise use minimum height
        let level: Float
        if index < audioRecorder.audioLevels.count {
            level = audioRecorder.audioLevels[index]
        } else {
            level = 0.0
        }
        
        // Convert normalized level (0.0-1.0) to height
        let height = minHeight + (maxHeight - minHeight) * CGFloat(level)
        return max(minHeight, height) // Ensure minimum height
    }
}

