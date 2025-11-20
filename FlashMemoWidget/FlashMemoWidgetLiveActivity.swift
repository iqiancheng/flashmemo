//
//  FlashMemoWidgetLiveActivity.swift
//  FlashMemoWidget
//
//  Created by qian.cheng on 11/20/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FlashMemoWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FlashMemoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlashMemoWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FlashMemoWidgetAttributes {
    fileprivate static var preview: FlashMemoWidgetAttributes {
        FlashMemoWidgetAttributes(name: "World")
    }
}

extension FlashMemoWidgetAttributes.ContentState {
    fileprivate static var smiley: FlashMemoWidgetAttributes.ContentState {
        FlashMemoWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FlashMemoWidgetAttributes.ContentState {
         FlashMemoWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FlashMemoWidgetAttributes.preview) {
   FlashMemoWidgetLiveActivity()
} contentStates: {
    FlashMemoWidgetAttributes.ContentState.smiley
    FlashMemoWidgetAttributes.ContentState.starEyes
}
