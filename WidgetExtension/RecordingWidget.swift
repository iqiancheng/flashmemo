import ActivityKit
import WidgetKit
import SwiftUI

struct RecordingWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlashMemoAttributes.self) { context in
            // Lock Screen / Banner UI
            VStack {
                Text("Recording...")
                    .font(.headline)
                Text(Date(timeIntervalSinceNow: context.state.duration), style: .timer)
            }
            .padding()
            .activityBackgroundTint(Color.red)
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Date(timeIntervalSinceNow: context.state.duration), style: .timer)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Recording")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Button("Stop") {
                        // Intent to stop would go here
                    }
                    .buttonStyle(.borderedProminent)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            } compactTrailing: {
                Text(Date(timeIntervalSinceNow: context.state.duration), style: .timer)
            } minimal: {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            }
        }
    }
}
