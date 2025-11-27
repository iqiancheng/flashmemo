import SwiftUI

struct SoundWaveView: View {
    @State private var animationPhase: Double = 0
    @State private var timer: Timer?
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
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        // Create a wave pattern with different phases for each bar
        let baseDelay = Double(index) * 0.2
        let phase = (animationPhase + baseDelay).truncatingRemainder(dividingBy: 2.0 * .pi)
        let normalized = (sin(phase) + 1.0) / 2.0 // Normalize to 0-1
        
        return minHeight + (maxHeight - minHeight) * CGFloat(normalized)
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                animationPhase += 0.2
                if animationPhase >= 2.0 * .pi {
                    animationPhase = 0
                }
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

